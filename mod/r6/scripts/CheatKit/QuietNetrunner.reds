class CheatKitTrace extends IScriptable {
  public static func IsTrace(action: ref<ScriptableDeviceAction>, player: wref<ScriptedPuppet>) -> Bool {
    if !IsDefined(action) || !IsDefined(player) || !player.IsPlayer() || action.GetRequesterID() != player.GetEntityID() { return false; }
    let id = action.GetObjectActionID();
    return id == t"AIQuickHack.HackRevealPosition" || id == t"AIQuickHack.PreventionHackRevealPosition";
  }
}

@wrapMethod(ScriptableDeviceAction)
public final func GetAwarenessCost(gameInstance: GameInstance) -> Float {
  if CheatKitQuickhacks.Enabled(this, n"netrunner_stealth") { return 0.0; }
  return wrappedMethod(gameInstance);
}

@wrapMethod(QuickHackableHelper)
public final static func WillHackRevealPlayer(playerRef: ref<PlayerPuppet>, targetRecordId: TweakDBID, action: ref<ScriptableDeviceAction>, opt programItemID: ItemID) -> Bool {
  if CheatKitQuickhacks.Quiet(playerRef) { return false; }
  return wrappedMethod(playerRef, targetRecordId, action, programItemID);
}

@wrapMethod(QuickHackableHelper)
public final static func ShouldShowRevealInfo(playerRef: ref<PlayerPuppet>, awarenessCost: Float) -> Bool {
  if CheatKitQuickhacks.Quiet(playerRef) { return false; }
  return wrappedMethod(playerRef, awarenessCost);
}

@wrapMethod(QuickHackableHelper)
public final static func ShouldShowRevealInfoWithTarget(playerRef: ref<PlayerPuppet>, target: ref<ScriptedPuppet>, awarenessCost: Float) -> Bool {
  if CheatKitQuickhacks.Quiet(playerRef) { return false; }
  return wrappedMethod(playerRef, target, awarenessCost);
}

@wrapMethod(NPCPuppet)
public final static func RevealPlayerPositionIfNeeded(ownerPuppet: wref<ScriptedPuppet>, playerID: EntityID, opt isPrevention: Bool) -> Bool {
  if IsDefined(ownerPuppet) && CheatKitQuickhacks.Quiet(GameInstance.FindEntityByID(ownerPuppet.GetGame(), playerID) as GameObject) { return false; }
  return wrappedMethod(ownerPuppet, playerID, isPrevention);
}

@wrapMethod(NPCPuppet)
protected cb func OnNonStealthQuickHackVictimEvent(evt: ref<NonStealthQuickHackVictimEvent>) -> Bool {
  if CheatKitQuickhacks.Quiet(GameInstance.FindEntityByID(this.GetGame(), evt.instigatorID) as GameObject) { return false; }
  return wrappedMethod(evt);
}

@wrapMethod(PlayerPuppet)
protected cb func OnHackTargetEvent(evt: ref<HackTargetEvent>) -> Bool {
  if evt.settings.isRevealPositionAction && CheatKitQuickhacks.Quiet(this) { return false; }
  return wrappedMethod(evt);
}

@addField(UploadFromNPCToPlayerListener)
private let ckTraceCancelled: Bool;

@addField(UploadFromNPCToPlayerListener)
private let ckTraceActive: Bool;

@addMethod(UploadFromNPCToPlayerListener)
public final func CheatKitCancelTrace() {
  if this.ckTraceCancelled || !this.ckTraceActive || !CheatKitTrace.IsTrace(this.m_action, this.m_playerPuppet) { return; }
  if !(this.m_playerPuppet as PlayerPuppet).IsBeingRevealed() { this.ckTraceActive = false; return; }
  this.ckTraceCancelled = true;
  this.ckTraceActive = false;
  PreventionSystemHackerLoop.UpdateOtherProgressBarReference(this.m_gameInstance, null);
  (this.m_playerPuppet as PlayerPuppet).SetIsBeingRevealed(false);
  this.RemoveLink(this.m_npcPuppet);
  this.RemoveLinkedStatusEffects(this.m_npcPuppet, true);
  SaveLocksManager.RequestSaveLockRemove(this.m_gameInstance, n"PlayerBeingHacked");
  StatusEffectHelper.RemoveStatusEffect(this.m_playerPuppet, t"AIQuickHackStatusEffect.BeingHacked");
  StatusEffectHelper.RemoveStatusEffect(this.m_playerPuppet, t"BaseStatusEffect.ForcedQHUploadAwarenessBumps");
  this.m_HUDData.active = false;
  if IsDefined(this.m_hudBlackboard) {
    this.m_hudBlackboard.SetBool(GetAllBlackboardDefs().UI_HUDProgressBar.Active, false);
  }
  let pools = GameInstance.GetStatPoolsSystem(this.m_gameInstance);
  let id = Cast<StatsObjectID>(this.m_action.GetRequesterID());
  pools.RequestUnregisteringListener(id, gamedataStatPoolType.QuickHackUpload, this);
  pools.RequestRemovingStatPool(id, gamedataStatPoolType.QuickHackUpload);
  let evt = new UploadProgramProgressEvent();
  evt.state = EUploadProgramState.COMPLETED;
  GameInstance.GetPersistencySystem(this.m_gameInstance).QueueEntityEvent(this.m_action.GetRequesterID(), evt);
}

@wrapMethod(UploadFromNPCToPlayerListener)
public func Initialize() {
  wrappedMethod();
  if CheatKitTrace.IsTrace(this.m_action, this.m_playerPuppet) {
    let state = CheatKitAPI.State(this.m_gameInstance);
    if IsDefined(state) && !ArrayContains(state.ckTraces, this) { ArrayPush(state.ckTraces, this); }
  }
}

@wrapMethod(UploadFromNPCToPlayerListener)
protected cb func OnStatPoolAdded() -> Bool {
  this.ckTraceActive = CheatKitTrace.IsTrace(this.m_action, this.m_playerPuppet);
  if this.ckTraceCancelled || (CheatKitTrace.IsTrace(this.m_action, this.m_playerPuppet) && CheatKitQuickhacks.Quiet(this.m_playerPuppet)) {
    this.CheatKitCancelTrace();
    return false;
  }
  return wrappedMethod();
}

@wrapMethod(UploadFromNPCToPlayerListener)
public func OnStatPoolValueChanged(oldValue: Float, newValue: Float, percToPoints: Float) {
  if this.ckTraceCancelled || (CheatKitTrace.IsTrace(this.m_action, this.m_playerPuppet) && CheatKitQuickhacks.Quiet(this.m_playerPuppet)) {
    this.CheatKitCancelTrace();
    return;
  }
  wrappedMethod(oldValue, newValue, percToPoints);
  if this.ckTraceActive && !(this.m_playerPuppet as PlayerPuppet).IsBeingRevealed() { this.ckTraceActive = false; }
}

@wrapMethod(UploadFromNPCToPlayerListener)
protected cb func OnStatPoolMaxValueReached(value: Float) -> Bool {
  if this.ckTraceCancelled || (CheatKitTrace.IsTrace(this.m_action, this.m_playerPuppet) && CheatKitQuickhacks.Quiet(this.m_playerPuppet)) {
    this.CheatKitCancelTrace();
    return false;
  }
  this.ckTraceActive = false;
  return wrappedMethod(value);
}
