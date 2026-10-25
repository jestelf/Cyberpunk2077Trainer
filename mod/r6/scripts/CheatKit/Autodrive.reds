class CheatKitAutodrive extends IScriptable {
  public static func CanPrepare(state: ref<CheatKitState>, vehicle: wref<VehicleObject>) -> Bool {
    let game = state.GetGameInstance();
    let player = GetPlayer(game);
    return IsDefined(player) && player.IsAttached() && IsDefined(vehicle) && vehicle == player.GetMountedVehicle() && vehicle.IsPlayerVehicle() && !vehicle.IsDestroyed() && !vehicle.IsInQuestOrScenePhysicsState() && !vehicle.IsPerformingSceneAnimation() && VehicleComponent.GetDriver(game, vehicle, vehicle.GetEntityID()) == player;
  }
  public static func Diagnostic(state: ref<CheatKitState>) -> String {
    if !state.Has(n"ultra_autodrive") { return "AUTODRIVE_OFF"; }
    if state.autodriveMode == 0 { return "AD_STOCK"; }
    if !state.autodrivePrepared { return NameToString(state.autodriveConfigStatus); }
    let system = GameInstance.GetScriptableSystemsContainer(state.GetGameInstance()).Get(n"AutoDriveSystem") as AutoDriveSystem;
    if !IsDefined(system) || !system.GetAutodriveEnabled() { return "AUTODRIVE_WAIT_G"; }
    if system.GetFreeRoamEnabled() || system.GetAutodriveIsDelamain() { return "AUTODRIVE_DESTINATION"; }
    let i = ArraySize(state.ckAutodriveDelegates) - 1;
    while i >= 0 {
      if IsDefined(state.ckAutodriveDelegates[i]) && state.ckAutodriveDelegates[i].CheatKitAutodriveLimit(system.GetAutodriveVehicle()) > 0.0 {
        let status = "AUTODRIVE_ACTIVE " + FloatToString(state.ckAutodriveDelegates[i].CheatKitAutodriveLimit(system.GetAutodriveVehicle()) * 3.6) + " AUTODRIVE_KMH";
        if IsDefined(state.autodriveSafety) {
          status += " · " + NameToString(state.autodriveSafety.reason) + " · AD_BRAKE " + FloatToString(state.autodriveSafety.braking) + " AD_MPS2 · AD_STOP " + FloatToString(state.autodriveSafety.stopDistance) + " AD_METERS · AD_CLEAR_DISTANCE " + FloatToString(state.autodriveSafety.clearDistance) + " AD_METERS";
        }
        return status;
      }
      i -= 1;
    }
    return "AUTODRIVE_WAIT_AI";
  }

  public static func Limit(context: ScriptExecutionContext) -> Float {
    let owner = ScriptExecutionContext.GetOwner(context);
    if !IsDefined(owner) { return 0.0; }
    let game = owner.GetGame();
    let player = GetPlayer(game);
    let state = CheatKitAPI.State(game);
    if !IsDefined(state) || !state.Has(n"ultra_autodrive") || state.autodriveMode == 0 || !state.autodrivePrepared || !IsDefined(player) || !player.IsAttached() { return 0.0; }
    let system = GameInstance.GetScriptableSystemsContainer(game).Get(n"AutoDriveSystem") as AutoDriveSystem;
    if !IsDefined(system) || !system.GetAutodriveEnabled() || system.GetAutodriveIsDelamain() || system.GetFreeRoamEnabled() { return 0.0; }
    let vehicle = system.GetAutodriveVehicle();
    if !IsDefined(vehicle) || vehicle != player.GetMountedVehicle() || !vehicle.IsPlayerVehicle() || vehicle.IsDestroyed() || vehicle.IsInQuestOrScenePhysicsState() || vehicle.IsPerformingSceneAnimation() { return 0.0; }
    if owner != player && owner != vehicle { return 0.0; }
    if VehicleComponent.GetDriver(game, vehicle, vehicle.GetEntityID()) != player { return 0.0; }
    if vehicle.GetRecord().GetID() != state.autodriveRecord { return 0.0; }
    if IsDefined(state.autodriveSafety) && state.autodriveSafety.vehicle == vehicle {
      let age = EngineTime.ToFloat(GameInstance.GetSimTime(game)) - state.autodriveSafety.updatedAt;
      if age >= 0.0 && age < 0.35 && state.autodriveSafety.limit == state.autodriveSafety.limit {
        return ClampF(state.autodriveSafety.limit, 0.1, MinF(state.autodriveLimit, 300.0) / 3.6);
      }
      return 0.1;
    }
    return MinF(state.autodriveLimit / 3.6, 30.0 / 3.6);
  }

  public static func Release(state: ref<CheatKitState>) {
    if ArraySize(state.ckAutodriveDelegates) == 0 {
      if IsDefined(state.autodriveSafety) { state.autodriveSafety.Release(); }
      return;
    }
    let touched = false;
    let game = state.GetGameInstance();
    let system = GameInstance.GetScriptableSystemsContainer(game).Get(n"AutoDriveSystem") as AutoDriveSystem;
    let i = ArraySize(state.ckAutodriveDelegates) - 1;
    while i >= 0 {
      if IsDefined(state.ckAutodriveDelegates[i]) {
        if IsDefined(system) && state.ckAutodriveDelegates[i].CheatKitAutodriveLimit(system.GetAutodriveVehicle()) > 0.0 { touched = true; }
        state.ckAutodriveDelegates[i].CheatKitReleaseAutodrive();
      }
      i -= 1;
    }
    ArrayClear(state.ckAutodriveDelegates);
    if IsDefined(state.autodriveSafety) { state.autodriveSafety.Release(); }
    if touched {
      let player = GetPlayer(game);
      if IsDefined(player) && IsDefined(system) && system.GetAutodriveEnabled() && !system.GetAutodriveIsDelamain() && system.GetAutodriveVehicle() == player.GetMountedVehicle() {
        system.SetAutodriveEnabled(false);
      }
    }
  }
}

@addField(AIDriveCommandsDelegate)
private let ckAutodriveOwned: Bool;

@addField(AIDriveCommandsDelegate)
private let ckAutodriveOriginalMax: Float;

@addField(AIDriveCommandsDelegate)
private let ckAutodriveAppliedMax: Float;

@addField(AIDriveCommandsDelegate)
private let ckAutodriveVehicle: wref<VehicleObject>;

@addMethod(AIDriveCommandsDelegate)
public final func CheatKitAutodriveLimit(vehicle: wref<VehicleObject>) -> Float {
  return this.ckAutodriveOwned && this.ckAutodriveVehicle == vehicle ? this.maxSpeed : 0.0;
}

@addMethod(AIDriveCommandsDelegate)
public final func CheatKitReleaseAutodrive() -> Bool {
  if !this.ckAutodriveOwned { return false; }
  if this.maxSpeed == this.ckAutodriveAppliedMax { this.maxSpeed = this.ckAutodriveOriginalMax; }
  this.ckAutodriveOwned = false;
  this.ckAutodriveVehicle = null;
  return true;
}

@addMethod(AIDriveCommandsDelegate)
private final func CheatKitUpdateAutodrive(context: ScriptExecutionContext) {
  let limit = CheatKitAutodrive.Limit(context);
  if limit <= 0.0 { this.CheatKitReleaseAutodrive(); return; }
  let owner = ScriptExecutionContext.GetOwner(context);
  let game = owner.GetGame();
  let state = CheatKitAPI.State(game);
  let system = GameInstance.GetScriptableSystemsContainer(game).Get(n"AutoDriveSystem") as AutoDriveSystem;
  if !this.ckAutodriveOwned {
    this.ckAutodriveOriginalMax = this.maxSpeed;
    this.ckAutodriveOwned = true;
    if !ArrayContains(state.ckAutodriveDelegates, this) { ArrayPush(state.ckAutodriveDelegates, this); }
  }
  this.ckAutodriveVehicle = system.GetAutodriveVehicle();
  this.ckAutodriveAppliedMax = limit;
  this.maxSpeed = limit;
  let update = new DriveToPointAutonomousUpdate();
  update.maxSpeed = limit;
  update.targetPosition = Cast<Vector4>(system.GetAutodriveDestination());
  system.GetAutodriveVehicle().GetAIComponent().SetDriveToPointAutonomousUpdate(update);
}

@wrapMethod(AIDriveCommandsDelegate)
public final func DoStartDriveToPointAutonomousAutodrive(context: ScriptExecutionContext) -> Bool {
  let result = wrappedMethod(context);
  if result { this.CheatKitUpdateAutodrive(context); }
  return result;
}

@wrapMethod(AIDriveCommandsDelegate)
public final func DoUpdateDriveToPointAutonomousAutodrive(context: ScriptExecutionContext) -> Bool {
  let result = wrappedMethod(context);
  if result { this.CheatKitUpdateAutodrive(context); }
  return result;
}

@wrapMethod(AIDriveCommandsDelegate)
public final func DoStopDriveToPointAutonomous(context: ScriptExecutionContext) -> Bool {
  this.CheatKitReleaseAutodrive();
  return wrappedMethod(context);
}
