class CheatKitQuickhacks extends IScriptable {
  public static func IsPlayerHack(action: ref<BaseScriptableAction>) -> Bool {
    if !IsDefined(action) || !IsDefined(action.GetExecutor()) || !action.GetExecutor().IsPlayer() { return false; }
    let deviceAction = action as ScriptableDeviceAction;
    let record = action.GetObjectActionRecord();
    if !IsDefined(deviceAction) || !deviceAction.IsQuickHack() || IsDefined(action as AccessBreach)
      || !IsDefined(record) || !IsDefined(record.ObjectActionType()) { return false; }
    let type = record.ObjectActionType().Type();
    return Equals(type, gamedataObjectActionType.PuppetQuickHack)
      || Equals(type, gamedataObjectActionType.DeviceQuickHack)
      || Equals(type, gamedataObjectActionType.VehicleQuickHack);
  }

  public static func Enabled(action: ref<BaseScriptableAction>, key: CName) -> Bool {
    return CheatKitQuickhacks.IsPlayerHack(action) && CheatKitAPI.Flag(key, action.GetExecutor().GetGame());
  }

  public static func FreeRAM(action: ref<BaseScriptableAction>) -> Bool {
    if !CheatKitQuickhacks.Enabled(action, n"ram") { return false; }
    let costs: array<wref<ObjectActionCost_Record>>;
    action.GetObjectActionRecord().Costs(costs);
    if ArraySize(costs) == 0 { return false; }
    let i = 0;
    while i < ArraySize(costs) {
      let pool = costs[i] as StatPoolCost_Record;
      if !IsDefined(pool) || !IsDefined(pool.StatPool())
        || NotEquals(pool.StatPool().StatPoolType(), gamedataStatPoolType.Memory) { return false; }
      i += 1;
    }
    return true;
  }

  public static func ClearCooldown(player: wref<PlayerPuppet>, record: wref<ObjectAction_Record>) {
    if !IsDefined(player) || !IsDefined(record) { return; }
    let effects: array<wref<ObjectActionEffect_Record>>;
    record.StartEffects(effects);
    let i = 0;
    while i < ArraySize(effects) {
      let effect = effects[i].StatusEffect();
      if IsDefined(effect) && IsDefined(effect.StatusEffectType())
        && Equals(effect.StatusEffectType().Type(), gamedataStatusEffectType.PlayerCooldown) {
        StatusEffectHelper.RemoveStatusEffect(player, effect.GetID());
      }
      i += 1;
    }
  }

  public static func ClearEquippedCooldowns(player: wref<PlayerPuppet>) {
    if !IsDefined(player) { return; }
    let hacks = RPGManager.GetPlayerQuickHackListWithQuality(player);
    let i = 0;
    while i < ArraySize(hacks) {
      CheatKitQuickhacks.ClearCooldown(player, hacks[i].actionRecord);
      i += 1;
    }
  }

  public static func Quiet(player: wref<GameObject>) -> Bool {
    return IsDefined(player) && player.IsPlayer() && CheatKitAPI.Flag(n"netrunner_stealth", player.GetGame());
  }

  public static func RepeatedEffectPrereq(prereq: wref<IPrereq_Record>, player: wref<PlayerPuppet>) -> Bool {
    let status = prereq as StatusEffectPrereq_Record;
    if !IsDefined(status) || !status.Invert() || !IsDefined(player) { return false; }
    let effects: array<wref<ObjectActionEffect_Record>>;
    let hacks = RPGManager.GetPlayerQuickHackListWithQuality(player);
    let i = 0;
    while i < ArraySize(hacks) {
      ArrayClear(effects);
      hacks[i].actionRecord.StartEffects(effects);
      if CheatKitQuickhacks.MatchesRepeatedEffect(status, effects) { return true; }
      ArrayClear(effects);
      hacks[i].actionRecord.CompletionEffects(effects);
      if CheatKitQuickhacks.MatchesRepeatedEffect(status, effects) { return true; }
      i += 1;
    }
    return false;
  }

  public static func MatchesRepeatedEffect(prereq: wref<StatusEffectPrereq_Record>, effects: array<wref<ObjectActionEffect_Record>>) -> Bool {
    let required = prereq.StatusEffect();
    let tag = prereq.TagToCheck();
    let i = 0;
    while i < ArraySize(effects) {
      let effect = effects[i].StatusEffect();
      if IsDefined(effect) && ((IsDefined(required) && TDBID.IsValid(required.GetID()) && effect.GetID() == required.GetID())
        || (NotEquals(tag, n"") && effect.GameplayTagsContains(tag))) { return true; }
      i += 1;
    }
    return false;
  }
}

@wrapMethod(RPGManager)
public final static func CheckPrereq(prereqRecord: wref<IPrereq_Record>, target: wref<GameObject>, opt referenceStatsID: StatsObjectID) -> Bool {
  if IsDefined(target) {
    let state = CheatKitAPI.State(target.GetGame());
    if IsDefined(state) && state.quickhackAvailabilityDepth > 0 && state.Has(n"quickhack_fast")
      && CheatKitQuickhacks.RepeatedEffectPrereq(prereqRecord, GetPlayer(target.GetGame())) { return true; }
  }
  return wrappedMethod(prereqRecord, target, referenceStatsID);
}

@wrapMethod(BaseScriptableAction)
public func GetCost() -> Int32 {
  if CheatKitQuickhacks.FreeRAM(this) { return 0; }
  return wrappedMethod();
}

@wrapMethod(BaseScriptableAction)
public final func CanPayCost(opt user: ref<GameObject>, opt checkForOverclockedState: Bool) -> Bool {
  if (!IsDefined(user) || user == this.GetExecutor()) && CheatKitQuickhacks.FreeRAM(this) { return true; }
  return wrappedMethod(user, checkForOverclockedState);
}

@wrapMethod(BaseScriptableAction)
public func PayCost(opt checkForOverclockedState: Bool) -> Bool {
  if CheatKitQuickhacks.FreeRAM(this) { return true; }
  return wrappedMethod(checkForOverclockedState);
}

@wrapMethod(BaseScriptableAction)
public func GetActivationTime() -> Float {
  if CheatKitQuickhacks.Enabled(this, n"quickhack_fast") { return 0.001; }
  return wrappedMethod();
}

@wrapMethod(BaseScriptableAction)
public func ProcessRPGAction(gameInstance: GameInstance, opt gameplayRoleComponent: ref<GameplayRoleComponent>) {
  let action = this as ScriptableDeviceAction;
  if !CheatKitQuickhacks.Enabled(this, n"quickhack_fast") || this.m_isQueuedAction || this.m_isTargetDead {
    wrappedMethod(gameInstance, gameplayRoleComponent);
    return;
  }
  let target = GameInstance.FindEntityByID(gameInstance, this.GetRequesterID()) as GameObject;
  if !IsDefined(target) || GameInstance.GetStatPoolsSystem(gameInstance).IsStatPoolAdded(
    Cast<StatsObjectID>(this.GetRequesterID()), gamedataStatPoolType.QuickHackUpload) {
    wrappedMethod(gameInstance, gameplayRoleComponent);
    return;
  }
  this.SetProxyExecutor(this.GetExecutor().TryGetControlledProxy());
  if !this.CanSkipPayCost(false) && !this.PayCost(true) { return; }
  this.m_calculatedBaseCost = this.GetBaseCost();
  this.m_isActionQueueingUsed = false;
  target.SetCurrentlyUploadingAction(action);
  GameInstance.GetBlackboardSystem(gameInstance).Get(GetAllBlackboardDefs().HackingMinigame).SetVector4(
    GetAllBlackboardDefs().HackingMinigame.LastPlayerHackPosition, this.GetExecutor().GetWorldPosition());
  let attempt = new SetQuickHackAttemptEvent();
  attempt.wasQuickHackAttempt = true;
  GameInstance.GetPersistencySystem(gameInstance).QueuePSEvent(this.GetPersistentID(), this.GetDeviceClassName(), attempt);
  RPGManager.IncrementQuickHackBlackboard(gameInstance, this.GetObjectActionID());
  let listener = new QuickHackUploadListener();
  listener.m_action = action;
  listener.m_gameInstance = gameInstance;
  listener.CheatKitDeliverImmediately();
}

@addMethod(QuickHackUploadListener)
public final func CheatKitDeliverImmediately() {
  this.SendUploadStartedEvent(this.m_action);
  this.m_action.StartAction(this.m_gameInstance);
  this.m_action.CompleteAction(this.m_gameInstance);
  this.SendUploadFinishedEvent();
}

@wrapMethod(QuickHackUploadListener)
protected func SetRegenBehavior() {
  wrappedMethod();
  if CheatKitQuickhacks.Enabled(this.m_action, n"quickhack_fast") {
    GameInstance.GetStatPoolsSystem(this.m_gameInstance).RequestSettingStatPoolValue(
      Cast<StatsObjectID>(this.m_action.GetRequesterID()), gamedataStatPoolType.QuickHackUpload,
      100.0, this.m_action.GetExecutor(), true);
  }
}

@wrapMethod(BaseScriptableAction)
protected func ProcessStatusEffects(const actionEffects: script_ref<array<wref<ObjectActionEffect_Record>>>, gameInstance: GameInstance) {
  if !CheatKitQuickhacks.Enabled(this, n"quickhack_fast") && !CheatKitQuickhacks.Enabled(this, n"quickhack_cd") {
    wrappedMethod(actionEffects, gameInstance);
    return;
  }
  let filtered: array<wref<ObjectActionEffect_Record>>;
  let i = 0;
  while i < ArraySize(Deref(actionEffects)) {
    let effect = actionEffects[i].StatusEffect();
    if !IsDefined(effect) || !IsDefined(effect.StatusEffectType())
      || NotEquals(effect.StatusEffectType().Type(), gamedataStatusEffectType.PlayerCooldown) {
      ArrayPush(filtered, actionEffects[i]);
    }
    i += 1;
  }
  wrappedMethod(filtered, gameInstance);
}

@wrapMethod(ScriptableDeviceAction)
public final func SetInactiveWithReason(isActiveIf: Bool, const reason: script_ref<String>) {
  if !isActiveIf && (Equals(reason, "LocKey#7020") || Equals(reason, "LocKey#43809") || Equals(reason, "LocKey#7004"))
    && CheatKitQuickhacks.Enabled(this, n"quickhack_fast") { return; }
  wrappedMethod(isActiveIf, reason);
}

@wrapMethod(ScriptedPuppet)
private final func TranslateChoicesIntoQuickSlotCommands(const puppetActions: script_ref<array<ref<PuppetAction>>>, commands: script_ref<array<ref<QuickhackData>>>) {
  let state = CheatKitAPI.State(this.GetGame());
  let repeatMode = IsDefined(state) && state.Has(n"quickhack_fast");
  if repeatMode { state.quickhackAvailabilityDepth += 1; }
  let i = 0;
  while i < ArraySize(Deref(puppetActions)) {
    if CheatKitQuickhacks.Enabled(puppetActions[i], n"quickhack_fast") || CheatKitQuickhacks.Enabled(puppetActions[i], n"quickhack_cd") {
      CheatKitQuickhacks.ClearCooldown(puppetActions[i].GetExecutor() as PlayerPuppet, puppetActions[i].GetObjectActionRecord());
    }
    if repeatMode && (Equals(puppetActions[i].GetInactiveReason(), "LocKey#27694") || Equals(puppetActions[i].GetInactiveReason(), "LocKey#7019")) {
      puppetActions[i].SetActive();
      puppetActions[i].SetInactiveReason("");
    }
    i += 1;
  }
  wrappedMethod(puppetActions, commands);
  if repeatMode { state.quickhackAvailabilityDepth -= 1; }
}

@wrapMethod(QuickHackableHelper)
public final static func TranslateActionsIntoQuickSlotCommands(const actions: array<ref<DeviceAction>>, commands: script_ref<array<ref<QuickhackData>>>, gameObject: ref<GameObject>, scriptableComponentPS: ref<ScriptableDeviceComponentPS>) {
  let i = 0;
  while i < ArraySize(actions) {
    let action = actions[i] as ScriptableDeviceAction;
    if CheatKitQuickhacks.Enabled(action, n"quickhack_fast") && Equals(action.GetInactiveReason(), "LocKey#7004") {
      action.SetActive();
      action.SetInactiveReason("");
    }
    if CheatKitQuickhacks.Enabled(action, n"quickhack_fast") || CheatKitQuickhacks.Enabled(action, n"quickhack_cd") {
      CheatKitQuickhacks.ClearCooldown(action.GetExecutor() as PlayerPuppet, action.GetObjectActionRecord());
    }
    i += 1;
  }
  wrappedMethod(actions, commands, gameObject, scriptableComponentPS);
}

@wrapMethod(BaseScriptableAction)
protected final func ResetStatusEffectIfActionIsQueued(entityID: EntityID, statusEffectRecord: ref<StatusEffect_Record>, gameInstance: GameInstance) {
  if CheatKitQuickhacks.Enabled(this, n"quickhack_fast") && IsDefined(statusEffectRecord)
    && !QuickHackableQueueHelper.IsStatusEffectStackable(statusEffectRecord) {
    GameInstance.GetStatusEffectSystem(gameInstance).RemoveStatusEffect(entityID, statusEffectRecord.GetID());
    return;
  }
  wrappedMethod(entityID, statusEffectRecord, gameInstance);
}

@wrapMethod(QuickhacksListGameController)
private final func ApplyQuickHack(shouldUseUI: Bool) -> Bool {
  if shouldUseUI && IsDefined(this.m_selectedData) && !this.m_selectedData.m_isLocked
    && CheatKitQuickhacks.Enabled(this.m_selectedData.m_action, n"quickhack_fast") {
    this.SendOverclockPreviewEvent(false, 0, true);
    this.m_selectedData.m_action.m_isInactive = false;
    return wrappedMethod(false);
  }
  return wrappedMethod(shouldUseUI);
}

@addField(ScriptableDeviceComponentPS)
private let ckRepeatedDistraction: wref<QuickHackDistraction>;

@wrapMethod(ScriptableDeviceComponentPS)
public func OnQuickHackDistraction(evt: ref<QuickHackDistraction>) -> EntityNotificationType {
  if evt.IsStarted() {
    if CheatKitQuickhacks.Enabled(evt, n"quickhack_fast") || IsDefined(this.ckRepeatedDistraction) {
      this.ckRepeatedDistraction = evt;
    }
  } else if IsDefined(this.ckRepeatedDistraction) {
    if this.ckRepeatedDistraction != evt { return EntityNotificationType.DoNotNotifyEntity; }
    this.ckRepeatedDistraction = null;
  }
  return wrappedMethod(evt);
}
