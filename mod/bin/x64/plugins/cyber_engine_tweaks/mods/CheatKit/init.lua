local ready = false
local elapsed = 0
local blinkDistance = 60
local flightSpeed = 10
local runtimeFault = false
local desiredToggles = {}
local desiredParams = {}
local appliedState, appliedGeneration = nil, nil
local ammoFloorOriginal = nil
local function ammoFloor(enable)
  local path = "BaseStats.NumShotsToFire.min"
  if enable then
    if ammoFloorOriginal ~= nil then return true end
    local original = TweakDB:GetFlat(path)
    if type(original) ~= "number" then return false end
    if original <= 0 then return true end
    if not TweakDB:SetFlat(path, 0.0) then return false end
    ammoFloorOriginal = original
    return TweakDB:GetFlat(path) == 0
  end
  if ammoFloorOriginal ~= nil then
    if TweakDB:GetFlat(path) == 0 and not TweakDB:SetFlat(path, ammoFloorOriginal) then return false end
    ammoFloorOriginal = nil
  end
  return true
end
local toggles = {}
toggles.ultra_autodrive = true
toggles.police_ignore = true
toggles.auto_breach = true
toggles.ghost = true
toggles.ghost_crouch = true
toggles.dash_free = true
toggles.vehicle_tuning = true
toggles.dialogue_timer = true
toggles.melee_combo = true
for _, key in ipairs({"god", "stamina", "items_ammo", "items_no_decrease", "heal_cd", "grenade_cd", "launcher_cd", "no_reload", "accuracy", "no_recoil", "one_hit", "stealth", "unlimited_xp", "unlimited_cred", "cyber_capacity", "ram", "breach_timer", "components", "qh_components", "multijump", "freeze_time", "noclip", "auto_locks", "vehicle_god", "sandevistan", "sandy_freeze", "free_craft", "free_upgrade", "no_cyberpsychosis", "infinite_air", "fall", "oxygen", "massive_carry", "blink", "blackwall", "skills_cd", "quickhack_cd", "device_off", "device_friendly", "quickhack_fast", "netrunner_stealth", "dialogue_lifepath", "dialogue_skills", "instant_scan"}) do toggles[key] = true end
local params = {
  xp_mul={1,10000}, cred_mul={1,10000}, skill_mul={1,10000},
  game_speed={0.01,10}, carry={0,10000000}, speed={0.1,50}, jump={0.1,100}, fire_rate={0.1,20},
  blink_distance={2,500}, flight_speed={1,500}, blackwall_targets={1,50}, blackwall_range={5,500}, dash_strength={0.25,10},
  vehicle_speed={20,600},vehicle_reverse={5,150},vehicle_accel={0.25,30},vehicle_brake={0.25,15},vehicle_turn={0,360},vehicle_grip={0,60},vehicle_downforce={0,5}
}
local paramDefaults = {xp_mul=1,cred_mul=1,skill_mul=1,game_speed=1,carry=0,speed=1,jump=1,fire_rate=1,blink_distance=60,flight_speed=10,blackwall_targets=5,blackwall_range=75,dash_strength=1,
  vehicle_speed=250,vehicle_reverse=40,vehicle_accel=2,vehicle_brake=1.5,vehicle_turn=120,vehicle_grip=25,vehicle_downforce=0}
local proficiencies = {level="Level", streetlevel="StreetCred", headhunter="CoolSkill", netrunner="IntelligenceSkill", shinobi="ReflexesSkill", solo="StrengthSkill", engineer="TechnicalAbilitySkill"}
local points = {attribute_points="Attribute", perk_points="Primary", relic_points="Espionage"}
local slotAreas = {SystemReplacementCW=true,FrontalCortexCW=true,EyesCW=true,HandsCW=true,NervousSystemCW=true,CardiovascularSystemCW=true,MusculoskeletalSystemCW=true,IntegumentarySystemCW=true,LegsCW=true}
local function number(value, min, max, integer)
  local n = tonumber(value)
  if not n or n ~= n or n < min or n > max or (integer and n ~= math.floor(n)) then return nil end
  return n
end
local function startBreach(s)
  if not Game.CK_BreachComplete then return "E_BREACH_NATIVE" end
  local result = Game.CK_BreachComplete()
  if result < 0 then return "E_BREACH_NATIVE" end
  if result == 0 then return "E_NO_BREACH" end
  return nil
end
local function updateBreach(dt, s)
  if Game.CK_BreachConfigure then
    Game.CK_BreachConfigure(s and s:Has(CName.new("auto_breach")) or false, s and s:Has(CName.new("breach_timer")) or false)
  end
end
local function learnRecipes()
  local records = TweakDB:GetRecords("gamedataItemRecipe_Record")
  if not records or #records == 0 then return nil end
  local count = 0
  for _, record in ipairs(records) do
    if CheatKitCrafting.LearnRecipe(record:GetID()) then count = count + 1 end
  end
  return count
end
local function state()
  local player = Game.GetPlayer()
  if not player or not player:IsAttached() then return nil end
  local requests = Game.GetSystemRequestsHandler()
  if not requests or requests:IsPreGame() then return nil end
  return CheatKitAPI.State()
end

local catalogRecords, catalogSeen = nil, nil
local function catalogPage(offset)
  if not catalogRecords or offset == 0 then
    catalogRecords, catalogSeen = {}, {}
    for _, class in ipairs({"gamedataItem_Record", "gamedataWeaponItem_Record", "gamedataCyberwareItem_Record", "gamedataClothing_Record", "gamedataConsumableItem_Record", "gamedataItemPart_Record", "gamedataProgram_Record", "gamedataGrenade_Record", "gamedataAmmo_Record"}) do
      local records = TweakDB:GetRecords(class)
      if records then
        for _, record in ipairs(records) do catalogRecords[#catalogRecords+1] = record end
      end
    end
  end
  local function clean(value) return tostring(value or ""):gsub("[\t\r\n]", " "):sub(1, 512) end
  local lines = {}
  local last = math.min(offset + 128, #catalogRecords)
  for i = offset + 1, last do
    local record = catalogRecords[i]
    local ok, row = pcall(function()
      local id = record:GetID().value
      if type(id) ~= "string" or not id:match("^Items%.[%w_%.]+$") or catalogSeen[id] then return nil end
      local name = id:sub(7):gsub("_", " ")
      local named, localized = pcall(function() return Game.GetLocalizedTextByKey(tostring(record:DisplayName())) end)
      if named and type(localized) == "string" and #localized > 0 then name = localized end
      local typed, kind = pcall(function() return tostring(record:ItemType():Type()):match("([^%.]+)$") end)
      local equipped, area = pcall(function() return tostring(record:EquipArea():Type()):match("([^%.]+)$") end)
      catalogSeen[id] = true
      return table.concat({id, clean(name), clean(name), "", "ItemType." .. (typed and kind or "Other"), "generated", equipped and "EquipmentArea." .. area or "", ""}, "\t")
    end)
    if ok and row then lines[#lines+1] = row end
  end
  return "ok " .. (last < #catalogRecords and last or -1) .. "\n" .. table.concat(lines, "\n")
end

local function execute(command)
  if command == "ping" then return runtimeFault and "err E_RUNTIME" or "ok" end
  local s = state()
  if command == "reset" then
    desiredToggles = {}
    desiredParams = {}
    appliedState, appliedGeneration = nil, nil
    if Game.CK_BreachReset then Game.CK_BreachReset() end
    if s then s:Reset() end
    if not ammoFloor(false) then return "err E_AMMO_COST" end
    blinkDistance = 60
    flightSpeed = 10
    runtimeFault = false
    return "ok"
  end
  if runtimeFault then return "err E_RUNTIME" end
  local player = Game.GetPlayer()
  if not player then return "err E_NO_PLAYER" end
  if not player:IsAttached() then return "err E_PLAYER_DETACHED" end
  if Game.GetSystemRequestsHandler():IsPreGame() then return "err E_SESSION_LOADING" end
  if not s then return "err E_NO_STATE" end
  s.lastError = ""
  local function rejected(fallback)
    return "err " .. ((s.lastError and s.lastError ~= "") and s.lastError or fallback or "E_REJECTED")
  end
  local args = {}
  for word in command:gmatch("%S+") do args[#args+1] = word end
  local kind, key, raw = args[1], args[2], args[3]
  local catalogOffset = command:match("^get catalog (%d+)$")
  if catalogOffset then
    local offset = tonumber(catalogOffset)
    if offset > 100000 then return "err E_COMMAND" end
    return catalogPage(offset)
  end
  if command == "get ready" then return "ok" end
  if command == "get features" then
    local enabled = {}
    for name in pairs(toggles) do if s:Has(CName.new(name)) then enabled[#enabled+1] = name end end
    table.sort(enabled)
    return #enabled > 0 and "ok " .. table.concat(enabled, " ") or "ok"
  end
  if kind == "getparam" and #args == 2 and params[key] then return "ok " .. tostring(desiredParams[key] or paramDefaults[key]) end
  if kind == "slots" and #args == 3 and slotAreas[key] then
    local count = number(raw, 0, 8, true)
    if not count then return "err E_VALUE" end
    return CheatKitCyberwareSlots.Configure(gamedataEquipmentArea[key], count) and "ok" or rejected("E_EQUIP_FAILED")
  end
  if kind == "getslots" and #args == 2 and slotAreas[key] then
    local count = CheatKitCyberwareSlots.Count(gamedataEquipmentArea[key])
    if not count or count < 0 then return rejected("E_NO_EQUIP_AREA") end
    return "ok " .. tostring(count)
  end
  if kind == "set" and #args == 3 and toggles[key] and (raw == "0" or raw == "1") then
    local enabled = raw == "1"
    if enabled and (key == "auto_breach" or key == "breach_timer") then
      if not Game.CK_BreachConfigure or not Game.CK_BreachConfigure(key == "auto_breach" or s:Has(CName.new("auto_breach")), key == "breach_timer" or s:Has(CName.new("breach_timer"))) then return "err E_BREACH_NATIVE" end
    end
    if key == "no_reload" and enabled and not ammoFloor(true) then ammoFloor(false); return "err E_AMMO_COST" end
    if not s:Set(CName.new(key), enabled) then
      if key == "no_reload" then ammoFloor(false) end
      return rejected()
    end
    if key == "no_reload" and not enabled and not ammoFloor(false) then return "err E_AMMO_COST" end
    desiredToggles[key] = enabled or nil
    return "ok"
  end
  if kind == "mul" and #args == 3 and params[key] then
    local v = number(raw, params[key][1], params[key][2], false)
    if not v then return "err E_VALUE" end
    if key == "blink_distance" then blinkDistance = v
    elseif key == "flight_speed" then flightSpeed = v
    elseif not s:Parameter(CName.new(key), v) then return rejected() end
    desiredParams[key] = v
    return "ok"
  end
  if kind == "get" and #args == 2 then
    if key == "vitals" then return "ok " .. CheatKitAPI.Vitals() end
    if key == "vehicle" then return "ok " .. s:DriveStatus() end
    if key == "travel" then return "ok " .. s:TravelStatus() end
    if key == "autodrive" then return "ok " .. CheatKitAutodrive.Diagnostic(s) end
    local data = CheatKitAPI.Development()
    if key == "money" then return "ok " .. tostring(Game.GetTransactionSystem():GetItemQuantity(player, ItemID.FromTDBID(TweakDBID.new("Items.money")))) end
    if not data then return "err E_NO_DEVELOPMENT" end
    if points[key] then return "ok " .. tostring(data:GetDevPoints(gamedataDevelopmentPointType[points[key]])) end
    if proficiencies[key] then return "ok " .. tostring(data:GetProficiencyLevel(gamedataProficiencyType[proficiencies[key]])) end
    return "err E_COMMAND"
  end
  if kind == "edit" and #args == 3 then
    local v = number(raw, 0, key == "money" and 1000000000 or 100000, true)
    if not v then return "err E_VALUE" end
    local ok = false
    if key == "money" then ok = CheatKitAPI.Money(v)
    elseif points[key] then ok = CheatKitAPI.SetPoints(gamedataDevelopmentPointType[points[key]], v)
    elseif proficiencies[key] then ok = CheatKitAPI.SetLevel(gamedataProficiencyType[proficiencies[key]], v)
    else return "err E_COMMAND" end
    return ok and "ok" or rejected("E_EDIT_FAILED")
  end
  if kind == "give" and #args == 3 and key:match("^Items%.[%w_]+$") then
    local count = number(raw, 1, 100000, true)
    if not count then return "err E_VALUE" end
    return CheatKitAPI.Give(key, count) and "ok" or rejected("E_ITEM_REJECTED")
  end
  if kind == "equip" and #args == 2 and key:match("^Items%.[%w_]+$") then
    return CheatKitAPI.InstallAlongside(key) and "ok" or rejected("E_EQUIP_FAILED")
  end
  if kind == "act" and #args == 2 then
    local ok = false
    if key == "recipes" then
      local count = learnRecipes()
      if not count or count == 0 then return "err E_RECIPES" end
      print("[CheatKit] Recipes processed / Обработано рецептов: " .. tostring(count))
      return "ok " .. tostring(count)
    elseif key == "travel_cancel" then s:CancelTravel(); ok = true
    elseif key == "vehicle_upright" then ok = CheatKitDriveController.Upright()
    elseif key == "appearance" then ok = CheatKitAppearance.Open()
    elseif key == "os_next" then ok = CheatKitCyberwareSlots.NextAbility()
    elseif key == "remove_extras" then ok = CheatKitAPI.RemoveExtras()
    elseif key == "breach" then
      local failure = startBreach(s)
      if failure then return "err " .. failure end
      ok = true
    elseif key == "max_skills" then ok = CheatKitAPI.MaxSkills()
    elseif key == "max_all" then ok = CheatKitAPI.MaxAll()
    elseif key == "waypoint" then ok = CheatKitAPI.Waypoint()
    elseif key == "quest" then ok = CheatKitAPI.QuestTeleport()
    elseif key == "wanted" then ok = CheatKitAPI.ClearWanted()
    elseif key == "plus_hour" then CheatKitAPI.PlusHour(); ok = true
    elseif key == "blink" then ok = CheatKitAPI.Blink(blinkDistance)
    elseif key == "sandy" then ok = s:Sandy(not Game.GetTimeSystem():IsTimeDilationActive(CName.new("sandevistan")), true)
    elseif key == "blackwall" then
      local enabled = not s:Has(CName.new("blackwall"))
      ok = s:Set(CName.new("blackwall"), enabled)
      if ok then desiredToggles.blackwall = enabled or nil end
    else return "err E_COMMAND" end
    return ok and "ok" or rejected()
  end
  return "err E_COMMAND"
end

registerForEvent("onInit", function()
  local success, available = pcall(function() return Game.CK_Poll ~= nil and CheatKitAPI.State ~= nil end)
  ready = success and available
end)

local function updateRuntime(dt)
  elapsed = elapsed + dt
  if elapsed >= 0.1 then
    elapsed = 0
    local s = state()
    if s then
      s:Tick()
      if s ~= appliedState or s.parameterGeneration ~= appliedGeneration then
        for key, value in pairs(desiredParams) do
          if key ~= "blink_distance" and key ~= "flight_speed" then s:Parameter(CName.new(key), value) end
        end
        appliedState, appliedGeneration = s, s.parameterGeneration
      end
      for key in pairs(desiredToggles) do
        if not s:Has(CName.new(key)) then s:Set(CName.new(key), true) end
      end
    else
      appliedState, appliedGeneration = nil, nil
    end
  end
  local s = state()
  local player = Game.GetPlayer()
  if s and player and s:Has(CName.new("vehicle_tuning")) then s:DriveTick() end
  if not s or not player or not s:FlightReady() then return end
  if Game.GetSystemRequestsHandler():IsPreGame() or Game.GetTimeSystem():IsPausedState() then
    CheatKitAPI.Flight(Vector4.new(0, 0, 0, 0))
    return
  end
  local camera = Game.GetCameraSystem()
  local f, r = camera:GetActiveCameraForward(), camera:GetActiveCameraRight()
  local x = (Game.CK_Key(68) and 1 or 0) - (Game.CK_Key(65) and 1 or 0)
  local y = (Game.CK_Key(87) and 1 or 0) - (Game.CK_Key(83) and 1 or 0)
  local z = (Game.CK_Key(32) and 1 or 0) - (Game.CK_Key(17) and 1 or 0)
  local speed = flightSpeed * (Game.CK_Key(16) and 3 or 1)
  local dx, dy, dz = f.x*y+r.x*x, f.y*y+r.y*x, f.z*y+r.z*x+z
  local length = math.max(1, math.sqrt(dx*dx+dy*dy+dz*dz))
  CheatKitAPI.Flight(Vector4.new(dx*speed/length, dy*speed/length, dz*speed/length, 0))
end

registerForEvent("onUpdate", function(dt)
  if not ready then return end
  local ok, envelope = pcall(function() return Game.CK_Poll() end)
  if not ok then pcall(execute, "reset"); ready = false; return end
  if envelope and envelope ~= "" then
    local ticket, command = envelope:match("^(%d+)|(.*)$")
    if ticket then
      local success, result = pcall(execute, command)
      if not success then print("[CheatKit] " .. command .. ": " .. tostring(result)) end
      local replied = pcall(function() Game.CK_Reply(ticket .. "|" .. (success and result or "err E_SCRIPT")) end)
      if not replied then pcall(execute, "reset"); ready = false; return end
    end
  end
  if not runtimeFault then
    local breachOk, breachFault = pcall(updateBreach, dt, state())
    if not breachOk then print("[CheatKit] breach automation failed: " .. tostring(breachFault)) end
    local success, fault = pcall(updateRuntime, dt)
    if not success then
      pcall(execute, "reset")
      runtimeFault = true
      print("[CheatKit] Game update failed; reset requested / Ошибка игрового такта; отправлен сброс: " .. tostring(fault))
    end
  end
end)

registerForEvent("onShutdown", function()
  if ready then pcall(execute, "reset") end
end)
