@addField(ScriptableDeviceComponentPS)
private let ckHoldOff: Bool;

@addMethod(ScriptableDeviceComponentPS)
public final func CheatKitReleaseOff() {
  this.ckHoldOff = false;
}

@addMethod(ScriptableDeviceComponentPS)
private final func CheatKitIsHeldOff() -> Bool {
  return this.ckHoldOff && CheatKitAPI.Flag(n"device_off", this.GetGameInstance());
}

@wrapMethod(ScriptableDeviceComponentPS)
public func OnQuickHackToggleOn(evt: QuickHackToggleON) -> EntityNotificationType {
  if this.CheatKitIsHeldOff() && !this.IsON() && !evt.Repeat { return EntityNotificationType.DoNotNotifyEntity; }
  let wasOn = this.IsON();
  this.ckHoldOff = false;
  let result = wrappedMethod(evt);
  if wasOn && this.IsOFF() && evt.IsQuickHack() && IsDefined(evt.GetExecutor()) && evt.GetExecutor().IsPlayer()
    && (IsDefined(this as SecurityTurretControllerPS) || IsDefined(this as SurveillanceCameraControllerPS)) {
    let state = CheatKitAPI.State(this.GetGameInstance());
    if IsDefined(state) && state.Has(n"device_off") {
      this.ckHoldOff = true;
      if !ArrayContains(state.ckOffDevices, this) { ArrayPush(state.ckOffDevices, this); }
    }
  }
  return result;
}

@wrapMethod(ScriptableDeviceComponentPS)
protected func SetDeviceState(state: EDeviceStatus) {
  if Equals(state, EDeviceStatus.ON) && this.CheatKitIsHeldOff() { return; }
  wrappedMethod(state);
}

@wrapMethod(ScriptableDeviceComponentPS)
protected func WakeUpDevice() -> Bool {
  if this.CheatKitIsHeldOff() { return false; }
  return wrappedMethod();
}

@wrapMethod(ScriptableDeviceComponentPS)
public func OnToggleON(evt: ToggleON) -> EntityNotificationType {
  this.ckHoldOff = false;
  return wrappedMethod(evt);
}

@wrapMethod(ScriptableDeviceComponentPS)
protected func OnSetDeviceON(evt: SetDeviceON) -> EntityNotificationType {
  this.ckHoldOff = false;
  return wrappedMethod(evt);
}

@wrapMethod(ScriptableDeviceComponentPS)
public func OnQuestForceON(evt: QuestForceON) -> EntityNotificationType {
  this.ckHoldOff = false;
  return wrappedMethod(evt);
}

@wrapMethod(ScriptableDeviceComponentPS)
public func OnQuestResetDeviceToInitialState(evt: QuestResetDeviceToInitialState) -> EntityNotificationType {
  this.ckHoldOff = false;
  return wrappedMethod(evt);
}

@wrapMethod(ScriptableDeviceComponentPS)
public func OnQuestForceEnabled(evt: QuestForceEnabled) -> EntityNotificationType {
  this.ckHoldOff = false;
  return wrappedMethod(evt);
}

@wrapMethod(ScriptableDeviceComponentPS)
public final func OnQuestForceDisabled(evt: QuestForceDisabled) -> EntityNotificationType {
  this.ckHoldOff = false;
  return wrappedMethod(evt);
}

@wrapMethod(ScriptableDeviceComponentPS)
protected func OnQuestForcePower(evt: QuestForcePower) -> EntityNotificationType {
  this.ckHoldOff = false;
  return wrappedMethod(evt);
}

@wrapMethod(ScriptableDeviceComponentPS)
protected func OnQuestForceUnpower(evt: QuestForceUnpower) -> EntityNotificationType {
  this.ckHoldOff = false;
  return wrappedMethod(evt);
}

@wrapMethod(ScriptableDeviceComponentPS)
protected func OnQuestForceOFF(evt: QuestForceOFF) -> EntityNotificationType {
  this.ckHoldOff = false;
  return wrappedMethod(evt);
}

@addField(QuickHackDurationListener)
private let ckDurationHeld: Bool;

@addField(QuickHackDurationListener)
private let ckDurationKey: CName;

@addMethod(QuickHackDurationListener)
public final func CheatKitResumeDuration(key: CName) -> Bool {
  if NotEquals(key, this.ckDurationKey) { return false; }
  if !this.ckDurationHeld { return true; }
  this.ckDurationHeld = false;
  let pools = GameInstance.GetStatPoolsSystem(this.m_gameInstance);
  let id = Cast<StatsObjectID>(this.m_action.GetRequesterID());
  let duration = this.m_action.GetDurationValue();
  if duration <= 0.0 || !pools.IsStatPoolAdded(id, gamedataStatPoolType.QuickHackDuration) { return true; }
  let regen: StatPoolModifier;
  regen.enabled = true;
  regen.valuePerSec = 100.0 / duration;
  regen.rangeEnd = 100.0;
  pools.RequestSettingModifier(id, gamedataStatPoolType.QuickHackDuration,
    gameStatPoolModificationTypes.Regeneration, regen);
  return true;
}

@wrapMethod(QuickHackDurationListener)
protected func SetRegenBehavior() {
  wrappedMethod();
  this.ckDurationHeld = false;
  let state = CheatKitAPI.State(this.m_gameInstance);
  let action = this.m_action;
  if !IsDefined(state) || !IsDefined(action) || !action.IsQuickHack() || action.GetDurationValue() <= 0.0
    || !IsDefined(action.GetExecutor()) || !action.GetExecutor().IsPlayer() { return; }
  let device = GameInstance.FindEntityByID(this.m_gameInstance, action.GetRequesterID()) as SensorDevice;
  if !IsDefined(device) || (!IsDefined(device as SecurityTurret) && !IsDefined(device as SurveillanceCamera)) { return; }
  if IsDefined(action as QuickHackToggleON) && device.GetDevicePS().IsOFF() {
    this.ckDurationKey = n"device_off";
  } else if IsDefined(action as SetDeviceAttitude) && Equals(device.GetAttitudeTowards(action.GetExecutor()), EAIAttitude.AIA_Friendly) {
    this.ckDurationKey = n"device_friendly";
  } else { return; }
  if !state.Has(this.ckDurationKey) { return; }
  this.ckDurationHeld = true;
  if !ArrayContains(state.ckDeviceTimers, this) { ArrayPush(state.ckDeviceTimers, this); }
  let regen: StatPoolModifier;
  regen.enabled = false;
  regen.valuePerSec = 0.0;
  regen.rangeEnd = 100.0;
  GameInstance.GetStatPoolsSystem(this.m_gameInstance).RequestSettingModifier(
    Cast<StatsObjectID>(this.m_action.GetRequesterID()), gamedataStatPoolType.QuickHackDuration,
    gameStatPoolModificationTypes.Regeneration, regen);
}
