class CheatKitPolice extends IScriptable {
  public static func Ignore(owner: wref<GameObject>, source: wref<GameObject>) -> Bool {
    if !IsDefined(owner) || !owner.IsPrevention() || !IsDefined(source) { return false; }
    let player = GetPlayer(owner.GetGame());
    if !IsDefined(player) { return false; }
    let grenade = source as BaseGrenade;
    if IsDefined(grenade) { source = grenade.GetUser(); }
    let vehicle = source as VehicleObject;
    if IsDefined(vehicle) && VehicleComponent.GetDriver(owner.GetGame(), vehicle, vehicle.GetEntityID()) == player { source = player; }
    return source == player && CheatKitAPI.Flag(n"police_ignore", owner.GetGame());
  }

  public static func Maintain(game: GameInstance) {
    let prevention = GameInstance.GetScriptableSystemsContainer(game).Get(n"PreventionSystem") as PreventionSystem;
    if IsDefined(prevention) { prevention.CheatKitMaintainPoliceIgnore(); }
  }
}

@addMethod(PreventionSystem)
public final func CheatKitMaintainPoliceIgnore() {
  this.m_totalCrimeScore = 0.0;
  if this.IsChasingPlayer() && !this.IsSystemLocked() {
    let wasEnabled = this.m_systemEnabled;
    this.execInstructionSafe("CheatKitPoliceIgnore");
    if NotEquals(this.m_systemEnabled, wasEnabled) { this.TogglePreventionSystem(wasEnabled); }
  }
}

@wrapMethod(PreventionSystem)
public const final func CanPreventionReactToInput() -> Bool {
  if CheatKitAPI.Flag(n"police_ignore", this.GetGameInstance()) { return false; }
  return wrappedMethod();
}

@wrapMethod(PreventionSystem)
private final func ChangeHeatStage(newHeatStage: EPreventionHeatStage, heatChangeReason: String) {
  if !CheatKitAPI.Flag(n"police_ignore", this.GetGameInstance()) { wrappedMethod(newHeatStage, heatChangeReason); return; }
  this.m_totalCrimeScore = 0.0;
  if NotEquals(newHeatStage, EPreventionHeatStage.Heat_0) { return; }
  let originalDefault = this.m_defaultHeatLevels;
  this.m_defaultHeatLevels = true;
  wrappedMethod(EPreventionHeatStage.Heat_0, heatChangeReason);
  this.m_defaultHeatLevels = originalDefault;
}
