@addField(ScanningComponent)
private let ckScanningTimeOwned: Bool;

@addField(ScanningComponent)
private let ckOriginalScanningTime: Float;

@addMethod(ScanningComponent)
public final func CheatKitInstantScan() {
  let owner = this.GetOwner();
  if !IsDefined(owner) || !this.m_isBeingScanned || this.IsBlocked() || this.IsBraindanceBlocked()
    || this.IsScanningCluesBlocked() || this.IsPhotoModeBlocked()
    || !CheatKitAPI.Flag(n"instant_scan", owner.GetGame()) { return; }
  if this.ckScanningTimeOwned { return; }
  let time = this.GetTimeNeeded();
  if time <= 0.001 { return; }
  let state = CheatKitAPI.State(owner.GetGame());
  if !IsDefined(state) { return; }
  this.ckOriginalScanningTime = time;
  this.ckScanningTimeOwned = true;
  if !ArrayContains(state.ckScanComponents, this) { ArrayPush(state.ckScanComponents, this); }
  let evt = new SetScanningTimeEvent();
  evt.time = 0.001;
  owner.QueueEvent(evt);
}

@addMethod(ScanningComponent)
public final func CheatKitRestoreScanTime() {
  if !this.ckScanningTimeOwned { return; }
  this.ckScanningTimeOwned = false;
  let owner = this.GetOwner();
  if IsDefined(owner) {
    let state = CheatKitAPI.State(owner.GetGame());
    if IsDefined(state) { ArrayRemove(state.ckScanComponents, this); }
    let evt = new SetScanningTimeEvent();
    evt.time = this.ckOriginalScanningTime;
    owner.QueueEvent(evt);
  }
}

@wrapMethod(ScanningComponent)
protected cb func OnScanningLookedAt(evt: ref<ScanningLookAtEvent>) -> Bool {
  let result = wrappedMethod(evt);
  let owner = this.GetOwner();
  if IsDefined(owner) {
    let state = CheatKitAPI.State(owner.GetGame());
    if IsDefined(state) {
      if evt.state {
        if IsDefined(state.ckScanTarget) && state.ckScanTarget != this { state.ckScanTarget.CheatKitRestoreScanTime(); }
        state.ckScanTarget = this;
      } else if state.ckScanTarget == this {
        state.ckScanTarget = null;
      }
    }
  }
  if evt.state { this.CheatKitInstantScan(); } else { this.CheatKitRestoreScanTime(); }
  return result;
}

@wrapMethod(ScanningComponent)
private final func ResolveScannerAvailability() {
  wrappedMethod();
  if this.IsBlocked() || this.IsBraindanceBlocked() { this.CheatKitRestoreScanTime(); }
  else { this.CheatKitInstantScan(); }
}

@wrapMethod(ScanningComponent)
protected final func OnGameDetach() {
  this.CheatKitRestoreScanTime();
  wrappedMethod();
}
