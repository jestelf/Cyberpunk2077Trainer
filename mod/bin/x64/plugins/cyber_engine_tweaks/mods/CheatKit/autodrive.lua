local M = {}
local lease = nil
local signature = nil
local specs = {
  {decel=3.0, reaction=1.55, reserve=12, traction=0.20},
  {decel=3.5, reaction=1.45, reserve=16, traction=0.25},
  {decel=4.0, reaction=1.35, reserve=20, traction=0.30},
  {decel=4.0, reaction=1.35, reserve=25, traction=0.35}
}
local function same(a, b) return a == b end
local function restore()
  if not lease then return true end
  local current = TweakDB:GetFlat(lease.path)
  if same(current, lease.owned) then
    if not TweakDB:SetFlat(lease.path, lease.original) or not same(TweakDB:GetFlat(lease.path), lease.original) then return false end
  end
  lease, signature = nil, nil
  return true
end
function M.release(s)
  if s then CheatKitAutodrive.Release(s) end
  local ok = restore()
  if s then s:AutodrivePolicy(false, TweakDBID.new(""), 0.5, CName.new(ok and "AD_STOCK" or "AD_CONFIG_ERROR")) end
  return ok
end
local function clone(name, source)
  if not TweakDB:GetRecord(name) and not TweakDB:CloneRecord(name, source:GetID()) then error("clone") end
  return TweakDB:GetRecord(name)
end
local function put(path, value)
  if not TweakDB:SetFlat(path, value) then error("flat") end
  local actual = TweakDB:GetFlat(path)
  if type(value) == "number" then
    if type(actual) ~= "number" or math.abs(actual - value) > 0.02 then error("readback") end
  elseif not same(actual, value) then error("readback") end
end
local function number(value, fallback)
  if type(value) ~= "number" or value ~= value or value <= 0 then return fallback end
  return value
end
local function prepare(record, mode, ceiling)
  local source = record:DrivingParamsAutodrive()
  if not source then return nil, "AD_UNSUPPORTED" end
  local vision, traction = source:Vision(), source:Traction()
  if not vision or not traction then return nil, "AD_UNSUPPORTED" end
  local spec = specs[mode]
  local nativeDecel = number(vision:SpeedLimitDeceleration(), 0)
  if nativeDecel < 0.5 then return nil, "AD_UNSUPPORTED" end
  local a = math.min(spec.decel, nativeDecel * 0.75)
  local v = ceiling / 3.6
  local horizon = math.min(1800, math.max(120, (v*v/(2*a) + v*spec.reaction + spec.reserve) * 1.25))
  local id = record:GetID()
  local name = id.value
  if type(name) ~= "string" or not name:match("^Vehicle%.[%w_%.]+$") then return nil, "AD_UNSUPPORTED" end
  local prefix = "CheatKit_AD_" .. tostring(id.hash) .. "_" .. tostring(id.length) .. "_" .. tostring(mode)
  local baseName, visionName, tractionName = prefix .. "_Base", prefix .. "_Vision", prefix .. "_Traction"
  local base = clone(baseName, source)
  clone(visionName, vision)
  clone(tractionName, traction)
  put(visionName .. ".maxDistance", horizon)
  put(visionName .. ".maxStraightPathExtension", horizon)
  put(visionName .. ".numSweeps", math.max(vision:NumSweeps(), math.min(96, math.ceil(horizon/16))))
  put(visionName .. ".speedLimitDeceleration", a)
  put(visionName .. ".useSpeedLimit", true)
  put(visionName .. ".useAdvancedSpeedLimit", true)
  put(tractionName .. ".turningAccelFactor", math.min(number(traction:TurningAccelFactor(),1), spec.traction))
  put(baseName .. ".vision", TweakDBID.new(visionName))
  put(baseName .. ".traction", TweakDBID.new(tractionName))
  local path = name .. ".drivingParamsAutodrive"
  local original = TweakDB:GetFlat(path)
  if not original or not same(original, source:GetID()) then return nil, "AD_CONFIG_CONFLICT" end
  lease = {path=path, original=original, owned=base:GetID(), record=id, decel=a, vision=visionName, horizon=horizon}
  put(path, base:GetID())
  local rebound = record:DrivingParamsAutodrive()
  if not rebound or not same(rebound:GetID(), base:GetID()) or math.abs(rebound:Vision():MaxDistance() - horizon) > 0.02 then error("binding") end
  return lease, "AD_READY"
end
function M.tick(s, player)
  local mode = s and tonumber(s.autodriveMode) or 0
  if not s or not player or not player:IsAttached() or not s:Has(CName.new("ultra_autodrive")) or mode == 0 then
    if lease then M.release(s) end
    return
  end
  local vehicle = player:GetMountedVehicle()
  if not vehicle or not CheatKitAutodrive.CanPrepare(s, vehicle) then
    if lease then M.release(s) end
    s:AutodrivePolicy(false, TweakDBID.new(""), 0.5, CName.new("AD_WAIT_VEHICLE"))
    return
  end
  local ceiling = tonumber(s.autodriveLimit)
  if not specs[mode] or not ceiling or ceiling < 60 or ceiling > 300 then
    M.release(s); return
  end
  local record = vehicle:GetRecord()
  local id = record:GetID()
  local key = tostring(id.hash) .. ":" .. tostring(id.length) .. ":" .. tostring(mode) .. ":" .. tostring(ceiling)
  if signature ~= key then
    if lease and not M.release(s) then return end
    local ok, result, status = pcall(prepare, record, mode, ceiling)
    if not ok or not result then
      restore()
      s:AutodrivePolicy(false, id, 0.5, CName.new(ok and status or "AD_CONFIG_ERROR"))
      return
    end
    signature = key
  elseif not same(TweakDB:GetFlat(lease.path), lease.owned) or math.abs(number(TweakDB:GetFlat(lease.vision .. ".maxDistance"), 0) - lease.horizon) > 0.02 or math.abs(number(TweakDB:GetFlat(lease.vision .. ".speedLimitDeceleration"), 0) - lease.decel) > 0.02 then
    M.release(s)
    s:AutodrivePolicy(false, id, 0.5, CName.new("AD_CONFIG_CONFLICT"))
    return
  end
  s:AutodrivePolicy(true, id, lease.decel, CName.new("AD_READY"))
end
return M
