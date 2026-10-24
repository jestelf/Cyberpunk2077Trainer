class CheatKitTravel extends IScriptable {
  public let active: Bool;
  public let status: CName = n"TRAVEL_IDLE";
  public let target: Vector4;
  public let preferred: Float;
  public let marker: NewMappinID;
  public let waypoint: Bool;
  public let questHash: Uint32;
  public let rider: wref<PlayerPuppet>;
  public let hops: Int32;
  public let serial: Int32;
  public let remaining: Float;
  private let finalProbe: Int32;
  private let hopProbe: Int32;
  private let failures: Int32;
  private let ticks: Int32;
  private let cooldown: Int32;
  private let waiting: Bool;
  private let waitTicks: Int32;
  private let finalHop: Bool;
  private let expected: Vector4;

  public static func Begin(point: Vector4, preferred: Float, marker: NewMappinID, waypoint: Bool, questHash: Uint32, game: GameInstance) -> Bool {
    let state = CheatKitAPI.State(game);
    let player = GetPlayer(game);
    if !IsDefined(state) || !IsDefined(player) || !player.IsAttached() { return CheatKitAPI.Fail("E_NO_PLAYER", game); }
    if IsDefined(state.travel) && state.travel.active { return CheatKitAPI.Fail("E_TRAVEL_BUSY", game); }
    if VehicleComponent.IsMountedToVehicle(game, player) { return CheatKitAPI.Fail("E_EXIT_VEHICLE", game); }
    if !state.CanFly() || state.Has(n"noclip") { return CheatKitAPI.Fail("E_TRAVEL_CONTEXT", game); }
    if point.X != point.X || point.Y != point.Y || point.Z != point.Z || AbsF(point.X) > 100000.0 || AbsF(point.Y) > 100000.0 || AbsF(point.Z) > 10000.0 { return CheatKitAPI.Fail("E_VALUE", game); }
    let request = new CheatKitTravel();
    state.travelSerial += 1;
    request.serial = state.travelSerial;
    request.target = point;
    request.preferred = preferred;
    request.marker = marker;
    request.waypoint = waypoint;
    request.questHash = questHash;
    request.rider = player;
    request.active = true;
    request.status = n"TRAVEL_SEARCHING";
    state.travel = request;
    return true;
  }

  public final func Cancel() {
    if this.active { this.status = n"TRAVEL_CANCELLED"; }
    this.active = false;
    this.waiting = false;
  }

  public final func Diagnostic() -> String {
    return NameToString(this.status) + " · TRAVEL_REQUEST " + IntToString(this.serial) + " · " + IntToString(this.hops) + " TRAVEL_HOPS · " + IntToString(Cast<Int32>(this.remaining)) + " TRAVEL_METERS";
  }

  private final func Stop(reason: CName) {
    this.status = reason;
    this.active = false;
    this.waiting = false;
  }

  private final func TryPoint(sample: Vector4, currentHeight: Float, out result: Vector4, game: GameInstance) -> Bool {
    if CheatKitAPI.TryLanding(sample, 160.0, 240.0, result, game) { return true; }
    if this.waypoint && AbsF(sample.Z - currentHeight) > 100.0 {
      sample.Z = currentHeight;
      return CheatKitAPI.TryLanding(sample, 160.0, 240.0, result, game);
    }
    return false;
  }

  private final func Move(position: Vector4, finalHop: Bool, game: GameInstance) -> Bool {
    if !CheatKitAPI.Teleport(position, game) { return false; }
    this.expected = position;
    this.finalHop = finalHop;
    this.waiting = true;
    this.waitTicks = 0;
    this.status = n"TRAVEL_MOVING";
    return true;
  }

  public final func Tick(state: ref<CheatKitState>) {
    if !this.active { return; }
    let game = state.GetGameInstance();
    let player = GetPlayer(game);
    if !IsDefined(player) || player != this.rider || !player.IsAttached() { this.Cancel(); return; }
    if !state.CanFly() || state.Has(n"noclip") { this.Stop(n"TRAVEL_CONTEXT"); return; }
    let ui = GameInstance.GetBlackboardSystem(game).Get(GetAllBlackboardDefs().UI_System);
    if GameInstance.GetTimeSystem(game).IsPausedState() || (IsDefined(ui) && ui.GetBool(GetAllBlackboardDefs().UI_System.IsInMenu)) { this.status = n"TRAVEL_PAUSED"; return; }
    let maps = GameInstance.GetMappinSystem(game);
    if this.waypoint && maps.GetManuallyTrackedMappinID() != this.marker { this.Cancel(); return; }
    if this.questHash != 0u {
      let journal = GameInstance.GetJournalManager(game);
      let entry = journal.GetTrackedEntry();
      if !IsDefined(entry) || Cast<Uint32>(journal.GetEntryHash(entry)) != this.questHash { this.Cancel(); return; }
    }
    this.ticks += 1;
    if this.ticks > 600 { this.Stop(n"TRAVEL_TIMEOUT"); return; }
    let current = player.GetWorldPosition();
    let delta = current - this.target;
    delta.Z = 0.0; delta.W = 0.0;
    this.remaining = Vector4.Length(delta);
    if this.waiting {
      if Vector4.Distance(current, this.expected) < 4.0 {
        this.waiting = false;
        this.hops += 1;
        this.finalProbe = 0; this.hopProbe = 0; this.failures = 0;
        this.cooldown = 1;
        if this.finalHop {
          if this.waypoint { state.pendingMarker = this.marker; state.pendingPosition = this.expected; state.pendingTicks = 50; }
          this.Stop(n"TRAVEL_DONE");
        } else { this.status = n"TRAVEL_LOADING"; }
      } else {
        this.waitTicks += 1;
        if this.waitTicks > 20 { this.Stop(n"TRAVEL_NO_ARRIVAL"); }
      }
      return;
    }
    if this.cooldown > 0 { this.cooldown -= 1; this.status = n"TRAVEL_LOADING"; return; }
    let direction = Vector4.Length(delta) > 0.1 ? Vector4.Normalize(delta) : Vector4(0.0, -1.0, 0.0, 0.0);
    let destination: Vector4;
    if this.remaining <= 160.0 && this.finalProbe >= 0 {
      let ring = this.finalProbe / 8;
      let radius = ring == 0 ? this.preferred : ring == 1 ? 8.0 : ring == 2 ? 14.0 : ring == 3 ? 28.0 : ring == 4 ? 40.0 : ring == 5 ? 60.0 : 90.0;
      let finalAngle = Cast<Float>(this.finalProbe % 8) * 0.7853982;
      let offset = Vector4(direction.X * CosF(finalAngle) - direction.Y * SinF(finalAngle), direction.X * SinF(finalAngle) + direction.Y * CosF(finalAngle), 0.0, 0.0);
      let finalSample = this.target + offset * radius;
      this.finalProbe += (radius < 0.1 ? 8 : 1);
      this.status = n"TRAVEL_SEARCHING";
      if this.TryPoint(finalSample, current.Z, destination, game) && (this.waypoint || AbsF(destination.Z - this.target.Z) < 40.0) && this.Move(destination, true, game) { return; }
      if this.finalProbe >= 56 { this.finalProbe = -1; }
      return;
    }
    if this.remaining < this.preferred + 8.0 { this.Stop(n"TRAVEL_NO_ROUTE"); return; }
    let lengthIndex = this.hopProbe / 5;
    let angleIndex = this.hopProbe % 5;
    let length = MinF(lengthIndex == 0 ? 96.0 : lengthIndex == 1 ? 64.0 : 32.0, MaxF(8.0, this.remaining - this.preferred));
    let angle = angleIndex == 0 ? 0.0 : angleIndex == 1 ? 0.35 : angleIndex == 2 ? -0.35 : angleIndex == 3 ? 0.7 : -0.7;
    let toward = direction * -1.0;
    let heading = Vector4(toward.X * CosF(angle) - toward.Y * SinF(angle), toward.X * SinF(angle) + toward.Y * CosF(angle), 0.0, 0.0);
    let sample = current + heading * length;
    this.hopProbe = (this.hopProbe + 1) % 15;
    this.status = n"TRAVEL_LOADING";
    if this.TryPoint(sample, current.Z, destination, game) {
      let progress = destination - this.target;
      progress.Z = 0.0; progress.W = 0.0;
      if Vector4.Length(progress) < this.remaining - 4.0 && this.Move(destination, false, game) { return; }
    }
    this.failures += 1;
    if this.failures >= 90 { this.Stop(n"TRAVEL_NO_ROUTE"); }
  }
}
