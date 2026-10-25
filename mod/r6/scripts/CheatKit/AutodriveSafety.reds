class CheatKitAutodriveSafety extends IScriptable {
  public let vehicle: wref<VehicleObject>;
  public let limit: Float;
  public let reason: CName = n"AD_WAIT";
  public let speed: Float;
  public let braking: Float;
  public let clearDistance: Float;
  public let stopDistance: Float;
  public let calibrated: Bool;
  public let updatedAt: Float;
  private let previousTime: Float;
  private let previousSpeed: Float;
  private let previousForward: Vector4;
  private let previousPosition: Vector4;
  private let forcedLast: Bool;
  private let sampleTime: Float;
  private let sampleLoss: Float;
  private let weakBrakes: Bool;
  private let mode: Int32;

  public final func Release() {
    this.vehicle = null;
    this.limit = 0.0;
    this.calibrated = false;
    this.sampleTime = 0.0;
    this.sampleLoss = 0.0;
    this.forcedLast = false;
    this.weakBrakes = false;
    this.updatedAt = 0.0;
    this.reason = n"AD_WAIT";
  }

  public final func Tick(state: ref<CheatKitState>) {
    let game = state.GetGameInstance();
    let player = GetPlayer(game);
    let system = GameInstance.GetScriptableSystemsContainer(game).Get(n"AutoDriveSystem") as AutoDriveSystem;
    if !IsDefined(player) || !player.IsAttached() || !IsDefined(system) || !system.GetAutodriveEnabled() || system.GetAutodriveIsDelamain() || system.GetFreeRoamEnabled() { this.Release(); return; }
    let vehicle = system.GetAutodriveVehicle();
    if !IsDefined(vehicle) || vehicle != player.GetMountedVehicle() || VehicleComponent.GetDriver(game, vehicle, vehicle.GetEntityID()) != player || vehicle.IsDestroyed() || vehicle.IsInQuestOrScenePhysicsState() || vehicle.IsPerformingSceneAnimation() || !state.autodrivePrepared || vehicle.GetRecord().GetID() != state.autodriveRecord {
      this.Release(); return;
    }
    let now = EngineTime.ToFloat(GameInstance.GetSimTime(game));
    let position = vehicle.GetWorldPosition();
    let forward = vehicle.GetWorldForward(); forward.Z = 0.0; forward.W = 0.0;
    let forwardLength = Vector4.Length(forward);
    if forwardLength != forwardLength || forwardLength < 0.2 || forwardLength > 2.0 { this.vehicle = vehicle; this.updatedAt = now; this.limit = 0.1; this.reason = n"AD_SENSOR"; return; }
    forward = Vector4.Normalize(forward);
    let velocity = vehicle.GetLinearVelocity(); let verticalSpeed = velocity.Z; velocity.Z = 0.0; velocity.W = 0.0;
    let speed = Vector4.Length(velocity);
    if speed != speed || speed > 500.0 || now != now || position.X != position.X || position.Y != position.Y || position.Z != position.Z {
      this.vehicle = vehicle; this.updatedAt = now; this.limit = 0.1; this.reason = n"AD_SENSOR"; return;
    }
    if this.vehicle != vehicle || this.mode != state.autodriveMode {
      this.Release(); this.vehicle = vehicle; this.mode = state.autodriveMode;
      this.previousTime = now; this.previousSpeed = speed; this.previousForward = forward; this.previousPosition = position;
      this.limit = MinF(state.autodriveLimit / 3.6, 50.0 / 3.6);
      this.braking = MaxF(0.8, MinF(state.autodriveBaseDecel, CheatKitAutodriveModel.Deceleration(this.mode)));
      this.reason = n"AD_CALIBRATING"; this.updatedAt = now; return;
    }
    let dt = now - this.previousTime;
    let loss = this.previousSpeed - speed;
    let travelled = Vector4.Distance(position, this.previousPosition);
    let angle = AbsF(Deg2Rad(Vector4.GetAngleDegAroundAxis(this.previousForward, forward, Vector4.UP())));
    this.previousTime = now; this.previousSpeed = speed; this.previousForward = forward; this.previousPosition = position;
    this.speed = speed;
    let board = GameInstance.GetBlackboardSystem(game).Get(GetAllBlackboardDefs().UI_System);
    if GameInstance.GetTimeSystem(game).IsPausedState() || (IsDefined(board) && board.GetBool(GetAllBlackboardDefs().UI_System.IsInMenu)) {
      this.reason = n"AD_PAUSED"; this.forcedLast = false; return;
    }
    if dt < 0.02 || dt > 0.35 || travelled > MaxF(speed * dt * 2.0, 12.0) {
      this.reason = n"AD_TIMESTEP"; this.limit = MinF(this.limit, 30.0 / 3.6); this.forcedLast = false; this.updatedAt = now;
      if !vehicle.IsInAir() && speed > 10.0 { vehicle.ForceBrakesFor(0.22); }
      return;
    }
    this.updatedAt = now;
    let up = vehicle.GetWorldUp();
    let right = Vector4(forward.Y, -forward.X, 0.0, 0.0);
    let lateral = AbsF(Vector4.Dot(velocity, right));
    let supported = up.Z > 0.85 && !vehicle.IsInAir() && AbsF(verticalSpeed) < MaxF(8.0, speed * 0.15);
    let stable = supported && up.Z > 0.9 && AbsF(verticalSpeed) < 1.5 && angle < 0.035 && lateral < 1.0;
    if this.forcedLast && stable && this.previousSpeed > 5.0 {
      this.sampleTime += dt;
      this.sampleLoss += loss;
      if this.sampleTime >= 0.4 {
        let observed = this.sampleLoss / this.sampleTime;
        if observed >= 0.5 {
          this.braking = MaxF(0.5, MinF(this.braking, observed * 0.6));
          this.calibrated = true;
          this.weakBrakes = false;
        } else { this.braking = 0.5; this.weakBrakes = true; }
        this.sampleTime = 0.0; this.sampleLoss = 0.0;
      }
    } else if !stable { this.sampleTime = 0.0; this.sampleLoss = 0.0; }
    this.forcedLast = false;
    let reaction = CheatKitAutodriveModel.Reaction(this.mode) + 0.35;
    let reserve = CheatKitAutodriveModel.Buffer(this.mode);
    this.stopDistance = CheatKitAutodriveModel.StoppingDistance(speed, this.braking, reaction, reserve);
    let desired = ClampF(state.autodriveLimit, 60.0, 300.0) / 3.6;
    this.reason = n"AD_CLEAR";
    if !supported {
      desired = MinF(desired, 30.0 / 3.6); this.reason = n"AD_UNSTABLE";
    }
    if !this.calibrated {
      desired = MinF(desired, this.weakBrakes ? 30.0 / 3.6 : 50.0 / 3.6); this.reason = this.weakBrakes ? n"AD_WEAK_BRAKES" : n"AD_CALIBRATING";
      if stable && speed >= 8.3 {
        vehicle.ForceBrakesFor(0.22); this.forcedLast = true;
      }
    }
    let curvature = travelled > 0.3 ? angle / travelled : 0.0;
    let curveLimit = CheatKitAutodriveModel.CurveSpeed(curvature, CheatKitAutodriveModel.Lateral(this.mode));
    if curveLimit < desired { desired = curveLimit; this.reason = n"AD_CURVE"; }
    let queries = GameInstance.GetSpatialQueriesSystem(game);
    if !IsDefined(queries) { this.limit = 0.1; this.reason = n"AD_SENSOR"; vehicle.ForceBrakesFor(0.22); this.forcedLast = true; return; }
    let ground: QueryFilter;
    QueryFilter.AddGroup(ground, n"Static"); QueryFilter.AddGroup(ground, n"Terrain");
    let hit: TraceResult;
    let horizon = MinF(1152.0, MaxF(this.stopDistance * 1.25, 90.0));
    let clear = 0.0;
    let i = 0;
    while i < 96 {
      let distance = MinF(CheatKitAutodriveModel.ProbeDistance(i), horizon);
      let point = position + forward * distance;
      if !queries.SyncRaycastByQueryFilter(point + Vector4(0.0, 0.0, 8.0, 0.0), point - Vector4(0.0, 0.0, 12.0, 0.0), ground, hit, true, false) || hit.normal.Z < 0.75 { break; }
      clear = distance;
      if distance >= horizon { break; }
      i += 1;
    }
    this.clearDistance = clear;
    let visibleLimit = CheatKitAutodriveModel.SpeedForDistance(clear, this.braking, reaction, reserve);
    if visibleLimit < desired { desired = visibleLimit; this.reason = n"AD_VISIBILITY"; }
    let obstacle: QueryFilter;
    QueryFilter.AddGroup(obstacle, n"Static"); QueryFilter.AddGroup(obstacle, n"Dynamic"); QueryFilter.AddGroup(obstacle, n"Terrain"); QueryFilter.AddGroup(obstacle, n"Collider"); QueryFilter.AddGroup(obstacle, n"Destructible");
    let obstacleDistance = horizon;
    let j = -1;
    while j <= 1 {
      let start = position + forward * 5.0 + right * Cast<Float>(j) * 0.8 + Vector4(0.0, 0.0, 0.65, 0.0);
      if queries.SyncRaycastByQueryFilter(start, start + forward * horizon, obstacle, hit, true, false) {
        obstacleDistance = MinF(obstacleDistance, Vector4.Distance(position, Vector4(hit.position.X, hit.position.Y, hit.position.Z, 1.0)));
      }
      j += 1;
    }
    let obstacleLimit = CheatKitAutodriveModel.SpeedForDistance(obstacleDistance, this.braking, reaction, reserve);
    if obstacleLimit < desired { desired = obstacleLimit; this.reason = n"AD_OBSTACLE"; }
    let destination = Cast<Vector4>(system.GetAutodriveDestination());
    let destinationLimit = CheatKitAutodriveModel.SpeedForDistance(Vector4.Distance(position, destination), this.braking, reaction, reserve);
    if destinationLimit < desired { desired = destinationLimit; this.reason = n"AD_DESTINATION"; }
    if lateral > 2.0 { desired = MinF(desired, 30.0 / 3.6); this.reason = n"AD_SLIP"; }
    this.limit = MaxF(0.1, MinF(desired, this.limit + CheatKitAutodriveModel.Ramp(this.mode) * dt));
    if stable && speed > this.limit + 1.5 {
      vehicle.ForceBrakesFor(0.22); this.forcedLast = true;
    }
  }
}
