class CheatKitDriveInput extends IScriptable {
  public let controller: wref<CheatKitDriveController>;
  protected cb func OnAction(action: ListenerAction, consumer: ListenerActionConsumer) -> Bool {
    if !IsDefined(this.controller) { return false; }
    let name = ListenerAction.GetName(action);
    let value = ListenerAction.GetValue(action);
    if Equals(name, n"Accelerate") { this.controller.throttle = ClampF(value, 0.0, 1.0); }
    if Equals(name, n"Decelerate") { this.controller.brake = ClampF(value, 0.0, 1.0); }
    if Equals(name, n"TurnX") { this.controller.steering = ClampF(value, -1.0, 1.0); }
    if Equals(name, n"Handbrake") { this.controller.handbrake = ClampF(value, 0.0, 1.0); }
    return false;
  }
}

class CheatKitDriveController extends IScriptable {
  public let maxSpeed: Float = 250.0;
  public let reverseSpeed: Float = 40.0;
  public let accelerationTime: Float = 2.0;
  public let brakingTime: Float = 1.5;
  public let turnRate: Float = 120.0;
  public let grip: Float = 25.0;
  public let downforce: Float;
  public let motorcycle: Bool;
  public let verticalSpeed: Float;
  public let status: CName = n"WAITING";
  public let currentSpeed: Float;
  public let lastCorrection: Vector4;
  private let suspendedUntil: Float;
  public let throttle: Float;
  public let brake: Float;
  public let steering: Float;
  public let handbrake: Float;
  private let input: ref<CheatKitDriveInput>;
  private let player: wref<PlayerPuppet>;
  private let vehicle: wref<VehicleObject>;
  private let previousTime: Float;
  private let previousForward: Vector4;
  private let targetSpeed: Float;
  private let initialized: Bool;

  public final func Parameter(key: CName, value: Float) -> Bool {
    if Equals(key, n"vehicle_speed") && value >= 20.0 && value <= 600.0 { this.maxSpeed = value; return true; }
    if Equals(key, n"vehicle_reverse") && value >= 5.0 && value <= 150.0 { this.reverseSpeed = value; return true; }
    if Equals(key, n"vehicle_accel") && value >= 0.25 && value <= 30.0 { this.accelerationTime = value; return true; }
    if Equals(key, n"vehicle_brake") && value >= 0.25 && value <= 15.0 { this.brakingTime = value; return true; }
    if Equals(key, n"vehicle_turn") && value >= 0.0 && value <= 360.0 { this.turnRate = value; return true; }
    if Equals(key, n"vehicle_grip") && value >= 0.0 && value <= 60.0 { this.grip = value; return true; }
    if Equals(key, n"vehicle_downforce") && value >= 0.0 && value <= 5.0 { this.downforce = value; return true; }
    return false;
  }

  public final func Release() {
    if IsDefined(this.player) && IsDefined(this.input) { this.player.UnregisterInputListener(this.input); }
    if IsDefined(this.input) { this.input.controller = null; }
    this.input = null;
    this.player = null;
    this.vehicle = null;
    this.throttle = 0.0;
    this.brake = 0.0;
    this.steering = 0.0;
    this.handbrake = 0.0;
    this.initialized = false;
    this.status = n"OFF";
  }

  public final func Suspend() {
    if IsDefined(this.player) { this.suspendedUntil = EngineTime.ToFloat(GameInstance.GetSimTime(this.player.GetGame())) + 1.0; }
    this.initialized = false;
  }

  public final func Diagnostic() -> String {
    return "state=" + NameToString(this.status) + ";kind=" + (this.motorcycle ? "BIKE" : "CAR")
      + ";speed=" + FloatToString(this.currentSpeed * 3.6) + ";throttle=" + FloatToString(this.throttle)
      + ";brake=" + FloatToString(this.brake) + ";steering=" + FloatToString(this.steering)
      + ";correction=" + FloatToString(Vector4.Length(this.lastCorrection));
  }

  private final func Bind(player: wref<PlayerPuppet>) {
    if this.player == player && IsDefined(this.input) { return; }
    this.Release();
    this.player = player;
    this.input = new CheatKitDriveInput();
    this.input.controller = this;
    player.RegisterInputListener(this.input, n"Accelerate");
    player.RegisterInputListener(this.input, n"Decelerate");
    player.RegisterInputListener(this.input, n"TurnX");
    player.RegisterInputListener(this.input, n"Handbrake");
  }

  public final func Tick(player: wref<PlayerPuppet>) {
    if !IsDefined(player) || !player.IsAttached() { this.Release(); this.status = n"NO_PLAYER"; return; }
    let game = player.GetGame();
    let mount = GameInstance.GetMountingFacility(game).GetMountingInfoSingleWithObjects(player);
    let vehicle = GameInstance.FindEntityByID(game, mount.parentId) as VehicleObject;
    if !IsDefined(vehicle) { this.Release(); this.status = n"NO_VEHICLE"; return; }
    if !IsDefined(vehicle as CarObject) && !IsDefined(vehicle as BikeObject) { this.Release(); this.status = n"UNSUPPORTED"; return; }
    if VehicleComponent.GetDriver(game, vehicle, vehicle.GetEntityID()) != player { this.Release(); this.status = n"PASSENGER"; return; }
    if vehicle.IsInQuestOrScenePhysicsState() || vehicle.IsPerformingSceneAnimation() || vehicle.IsExecutingAnyCommand() || vehicle.IsAutoDriveModeEnabled() {
      this.Release(); this.status = n"SCENE"; return;
    }
    if vehicle.IsDestroyed() || !vehicle.IsEngineTurnedOn() { this.Release(); this.status = n"ENGINE_OFF"; return; }
    this.Bind(player);
    this.motorcycle = IsDefined(vehicle as BikeObject);
    let now = EngineTime.ToFloat(GameInstance.GetSimTime(game));
    if now < this.suspendedUntil { this.status = n"RECOVERY"; this.initialized = false; return; }
    let forward = vehicle.GetWorldForward();
    forward.Z = 0.0;
    forward.W = 0.0;
    if Vector4.Length(forward) < 0.1 { this.status = n"TILTED"; this.initialized = false; return; }
    forward = Vector4.Normalize(forward);
    let velocity = vehicle.GetLinearVelocity();
    let speed = Vector4.Dot(velocity, forward);
    this.currentSpeed = speed;
    this.verticalSpeed = velocity.Z;
    if this.vehicle != vehicle || !this.initialized {
      this.vehicle = vehicle;
      this.previousTime = now;
      this.previousForward = forward;
      this.targetSpeed = speed;
      this.initialized = true;
      this.status = n"WAITING";
      return;
    }
    let dt = now - this.previousTime;
    let previousForward = this.previousForward;
    this.previousForward = forward;
    this.previousTime = now;
    if dt <= 0.0 || dt > 0.1 { this.status = n"TIMESTEP"; this.targetSpeed = speed; return; }
    dt = MinF(dt, 0.05);
    let ui = GameInstance.GetBlackboardSystem(game).Get(GetAllBlackboardDefs().UI_System);
    let up = vehicle.GetWorldUp();
    if GameInstance.GetTimeSystem(game).IsPausedState() || (IsDefined(ui) && ui.GetBool(GetAllBlackboardDefs().UI_System.IsInMenu)) {
      this.status = n"PAUSED";
      this.targetSpeed = speed;
      return;
    }
    let bike = vehicle as BikeObject;
    if up.Z < (this.motorcycle ? 0.45 : 0.75) || (IsDefined(bike) && bike.IsPerformingAWheelieOrEndo(0.25, 20.0)) {
      this.status = n"TILTED";
      this.targetSpeed = speed;
      return;
    }
    let filter: QueryFilter;
    QueryFilter.AddGroup(filter, n"Static");
    QueryFilter.AddGroup(filter, n"Terrain");
    let hit: TraceResult;
    let position = vehicle.GetWorldPosition();
    if vehicle.IsInAir() || !GameInstance.GetSpatialQueriesSystem(game).SyncRaycastByQueryFilter(position + Vector4(0.0, 0.0, 0.2, 0.0), position - Vector4(0.0, 0.0, 1.8, 0.0), filter, hit, true, false) || hit.normal.Z < 0.65 {
      this.status = n"NO_GROUND";
      this.targetSpeed = speed;
      return;
    }
    let mass = vehicle.GetTotalMass();
    if mass < 50.0 || mass > 60000.0 { this.status = n"MASS"; return; }
    let right = Vector4(forward.Y, -forward.X, 0.0, 0.0);
    let delta = this.VelocityCorrection(speed, Vector4.Dot(velocity, right), dt, forward, right);
    this.lastCorrection = delta;
    this.status = n"ACTIVE";
    let center = position;
    CheatKitDriveController.Impulse(vehicle, center, delta * mass);
    let yawRate = Deg2Rad(Vector4.GetAngleDegAroundAxis(previousForward, forward, Vector4.UP())) / dt;
    if this.turnRate > 0.0 && this.handbrake < 0.1 {
      let yawChange = this.YawCorrection(speed, yawRate, dt);
      let arm = this.motorcycle ? 1.0 : 2.0;
      let side = right * (-mass * (this.motorcycle ? 0.15 : 0.45) * yawChange);
      CheatKitDriveController.Impulse(vehicle, center + forward * arm, side);
      CheatKitDriveController.Impulse(vehicle, center - forward * arm, side * -1.0);
    }
  }

  public final func YawCorrection(speed: Float, yawRate: Float, dt: Float) -> Float {
    let lateralLimit = this.motorcycle ? 6.0 : 9.0;
    let maximum = MinF(Deg2Rad(this.turnRate), lateralLimit / MaxF(AbsF(speed), 3.0));
    let desired = -this.steering * maximum * ClampF(AbsF(speed) / 5.0, 0.0, 1.0) * (speed < 0.0 ? -1.0 : 1.0);
    let rate = this.motorcycle ? 1.0 : 2.0;
    return ClampF((desired - yawRate) * MinF(3.0 * dt, 1.0), -rate * dt, rate * dt);
  }

  public final func VelocityCorrection(speed: Float, lateral: Float, dt: Float, forward: Vector4, right: Vector4) -> Vector4 {
    let limit = this.maxSpeed / 3.6;
    let reverseLimit = this.reverseSpeed / 3.6;
    let wanted = speed;
    let rate = 100.0 / 3.6 / this.accelerationTime;
    if this.throttle > 0.01 && this.brake <= 0.01 {
      wanted = limit * this.throttle;
      if speed < -0.1 { rate = 100.0 / 3.6 / this.brakingTime; }
    } else if this.brake > 0.01 || this.handbrake > 0.01 {
      wanted = speed > 0.5 || this.handbrake > 0.01 ? 0.0 : -reverseLimit * this.brake;
      rate = 100.0 / 3.6 / (speed > 0.5 || this.handbrake > 0.01 ? this.brakingTime : this.accelerationTime);
    } else {
      this.targetSpeed = speed;
    }
    let maximum = this.motorcycle ? 12.0 : 18.0;
    rate = MinF(rate, maximum);
    this.targetSpeed += ClampF(wanted - this.targetSpeed, -rate * dt, rate * dt);
    this.targetSpeed = ClampF(this.targetSpeed, -reverseLimit, limit);
    let longitudinal = ClampF(this.targetSpeed - speed, -maximum * dt, maximum * dt);
    let lateralLimit = this.motorcycle ? 6.0 : 9.0;
    let side = ClampF(-lateral * ClampF(MinF(this.grip, 12.0) * dt, 0.0, 1.0), -lateralLimit * dt, lateralLimit * dt);
    if this.handbrake > 0.1 { side = 0.0; }
    let vertical = this.verticalSpeed > 0.4 ? -MinF(this.verticalSpeed - 0.4, MinF(this.downforce, 2.0) * 0.981 * dt) : 0.0;
    return forward * longitudinal + right * side + Vector4(0.0, 0.0, vertical, 0.0);
  }

  public static func Upright(game: GameInstance) -> Bool {
    let player = GetPlayer(game);
    if !IsDefined(player) { return CheatKitAPI.Fail("E_NO_PLAYER", game); }
    let mount = GameInstance.GetMountingFacility(game).GetMountingInfoSingleWithObjects(player);
    let vehicle = GameInstance.FindEntityByID(game, mount.parentId) as VehicleObject;
    if !IsDefined(vehicle) { vehicle = GameInstance.GetTargetingSystem(game).GetLookAtObject(player) as VehicleObject; }
    if !IsDefined(vehicle) || (!IsDefined(vehicle as CarObject) && !IsDefined(vehicle as BikeObject)) || Vector4.Distance(player.GetWorldPosition(), vehicle.GetWorldPosition()) > 12.0 {
      return CheatKitAPI.Fail("E_NO_VEHICLE", game);
    }
    if vehicle.IsInQuestOrScenePhysicsState() || vehicle.IsPerformingSceneAnimation() || vehicle.IsExecutingAnyCommand() || vehicle.IsAutoDriveModeEnabled() || vehicle.IsDestroyed() {
      return CheatKitAPI.Fail("E_VEHICLE_SCENE", game);
    }
    let driver = VehicleComponent.GetDriver(game, vehicle, vehicle.GetEntityID());
    if IsDefined(driver) && driver != player { return CheatKitAPI.Fail("E_VEHICLE_SCENE", game); }
    if Vector4.Length(vehicle.GetLinearVelocity()) > 1.38 { return CheatKitAPI.Fail("E_VEHICLE_MOVING", game); }
    let filter: QueryFilter;
    QueryFilter.AddGroup(filter, n"Static"); QueryFilter.AddGroup(filter, n"Terrain");
    let hit: TraceResult;
    let position = vehicle.GetWorldPosition();
    let queries = GameInstance.GetSpatialQueriesSystem(game);
    if !queries.SyncRaycastByQueryFilter(position + Vector4(0.0, 0.0, 1.0, 0.0), position - Vector4(0.0, 0.0, 4.0, 0.0), filter, hit, true, false) || hit.normal.Z < 0.75 {
      return CheatKitAPI.Fail("E_NO_SAFE_LANDING", game);
    }
    let orientation = Quaternion.ToEulerAngles(vehicle.GetWorldOrientation());
    orientation.Pitch = 0.0; orientation.Roll = 0.0;
    position.Z = hit.position.Z + 0.6;
    let overlap: TraceResult;
    let size = IsDefined(vehicle as BikeObject) ? Vector4(0.4, 1.1, 0.65, 0.0) : Vector4(1.0, 2.3, 0.65, 0.0);
    let center = position + Vector4(0.0, 0.0, 0.4, 0.0);
    if queries.Overlap(size, center, orientation, n"Static", overlap) || queries.Overlap(size, center, orientation, n"Terrain", overlap) {
      return CheatKitAPI.Fail("E_BLOCKED_DESTINATION", game);
    }
    let state = CheatKitAPI.State(game);
    if IsDefined(state.drive) { state.drive.Suspend(); }
    GameInstance.GetTeleportationFacility(game).Teleport(vehicle, position, orientation);
    return true;
  }

  public static func Impulse(vehicle: wref<VehicleObject>, position: Vector4, impulse: Vector4) {
    if Vector4.Length(impulse) < 0.001 { return; }
    let event = new PhysicalImpulseEvent();
    event.worldPosition = Vector4.Vector4To3(position);
    event.worldImpulse = Vector4.Vector4To3(impulse);
    event.radius = 1.0;
    vehicle.QueueEvent(event);
  }
}
