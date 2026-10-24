struct CKOwnedModifier {
  public let group: CName;
  public let owner: StatsObjectID;
  public let value: ref<gameStatModifierData>;
}

struct CKInventoryTarget {
  public let item: ItemID;
  public let quantity: Int32;
}

class CheatKitState extends ScriptableSystem {
  public let travel: ref<CheatKitTravel>;
  public let travelSerial: Int32;
  public final func TravelStatus() -> String {
    return IsDefined(this.travel) ? this.travel.Diagnostic() : "TRAVEL_IDLE";
  }
  public final func CancelTravel() {
    if IsDefined(this.travel) { this.travel.Cancel(); }
  }
  public let drive: ref<CheatKitDriveController>;

  public final func DriveTick() {
    if this.Has(n"vehicle_tuning") {
      if !IsDefined(this.drive) { this.drive = new CheatKitDriveController(); }
      this.drive.Tick(this.player);
    }
  }
  public final func DriveStatus() -> String {
    if !this.Has(n"vehicle_tuning") { return "state=OFF"; }
    if !IsDefined(this.drive) { return "state=WAITING"; }
    return this.drive.Diagnostic();
  }
  public let ckAppearance: ref<CheatKitAppearanceRequest>;
  public let ckScanTarget: wref<ScanningComponent>;
  public let ckScanComponents: array<wref<ScanningComponent>>;

  public final func ReleaseInstantScanning() {
    while ArraySize(this.ckScanComponents) > 0 {
      let component = ArrayPop(this.ckScanComponents);
      if IsDefined(component) { component.CheatKitRestoreScanTime(); }
    }
  }

  public let ckTraces: array<wref<UploadFromNPCToPlayerListener>>;

  public final func CancelNetrunnerTraces() {
    let i = ArraySize(this.ckTraces) - 1;
    while i >= 0 {
      if IsDefined(this.ckTraces[i]) { this.ckTraces[i].CheatKitCancelTrace(); }
      ArrayErase(this.ckTraces, i);
      i -= 1;
    }
  }

  public let ckOffDevices: array<wref<ScriptableDeviceComponentPS>>;

  public let ckDeviceTimers: array<wref<QuickHackDurationListener>>;

  public final func ReleaseNetrunner(key: CName) {
    let i = 0;
    if Equals(key, n"device_off") {
      while i < ArraySize(this.ckOffDevices) {
        if IsDefined(this.ckOffDevices[i]) { this.ckOffDevices[i].CheatKitReleaseOff(); }
        i += 1;
      }
      ArrayClear(this.ckOffDevices);
    }
    if Equals(key, n"device_friendly") || Equals(key, n"device_off") {
      i = ArraySize(this.ckDeviceTimers) - 1;
      while i >= 0 {
        if !IsDefined(this.ckDeviceTimers[i]) {
          ArrayErase(this.ckDeviceTimers, i);
        } else if this.ckDeviceTimers[i].CheatKitResumeDuration(key) {
          ArrayErase(this.ckDeviceTimers, i);
        }
        i -= 1;
      }
    }
  }

  public func OnAttach() {
    this.player = null;
    this.gameSpeedOwned = false;
    this.dialoguePauseOwned = false;
    this.dialogueInputPlayer = null;
    this.dialogueProvider = null;
    this.dialogueSkippedProvider = null;
    this.stealthVisibilityOwned = false;
    this.ghostApplied = false;
    ArrayClear(this.dialogueTimers);
    this.staminaHud = null;
  }

  public func OnDetach() {
    this.CancelTravel();
    if IsDefined(this.drive) { this.drive.Release(); this.drive = null; }
    if IsDefined(this.ckAppearance) { this.ckAppearance.Release(); }
    this.ReleaseInstantScanning();
    this.ckScanTarget = null;
    this.ReleaseNetrunner(n"device_off");
    this.ReleaseNetrunner(n"device_friendly");
    this.ReleaseBlackwallAnimation();
    this.blackwallGeneration += 1;
    if IsDefined(this.blackwallInputPlayer) && IsDefined(this.blackwallInput) { this.blackwallInputPlayer.UnregisterInputListener(this.blackwallInput); }
    if IsDefined(this.blackwallInput) { this.blackwallInput.state = null; }
    this.blackwallInput = null;
    this.blackwallInputPlayer = null;
    this.blackwallDrawn = false;
    this.blackwallBusy = false;
    this.collisionOwned = false;
    this.flightVelocity = Vector4(0.0, 0.0, 0.0, 0.0);
    this.player = null;
    this.gameSpeedOwned = false;
    ArrayClear(this.flags);
    ArrayClear(this.mods);
    this.dialoguePauseOwned = false;
    this.dialogueInputPlayer = null;
    this.dialogueProvider = null;
    this.dialogueSkippedProvider = null;
    this.stealthVisibilityOwned = false;
    ArrayClear(this.dialogueTimers);
    this.staminaHud = null;
  }

  public let flags: array<CName>;
  public let parameterGeneration: Int32;
  public let mods: array<CKOwnedModifier>;
  public let player: wref<PlayerPuppet>;
  public let weapon: wref<WeaponObject>;
  public let leftWeapon: wref<WeaponObject>;
  public let vehicles: array<wref<VehicleObject>>;
  public let xpMul: Float = 1.0;
  public let credMul: Float = 1.0;
  public let skillMul: Float = 1.0;
  public let frozenTime: Int32;
  public let wasInvisible: Bool;
  public let camoOwned: Bool;
  public let ammoOwned: Bool;
  public let previousWeapon: ItemID;
  public let blackwallDrawn: Bool;
  public let blackwallWasArmed: Bool;
  public let blackwallGeneration: Int32;
  public let blackwallBusy: Bool;
  public let blackwallAnimationOwned: Bool;
  public let blackwallInput: ref<CheatKitBlackwallInput>;
  public let blackwallInputPlayer: wref<PlayerPuppet>;
  public let sandyActive: Bool;
  public let hackController: wref<HackingMinigameGameController>;
  public let inventory: array<CKInventoryTarget>;
  public let flightVelocity: Vector4;
  public let flightUpdatedAt: Float;
  public let fireRate: Float = 1.0;
  public let collisionOwned: Bool;
  public let pendingMarker: NewMappinID;
  public let pendingPosition: Vector4;
  public let pendingTicks: Int32;
  public let sandyRefresh: Float;
  public let sandyWorldScale: Float = 1.0;
  public let gameSpeedOwned: Bool;
  public let lastError: String;
  public let breachSerial: Int32;
  public let blackwallHeld: Bool;
  public let blackwallTargets: Int32 = 5;
  public let blackwallRange: Float = 75.0;
  public let stealthVisibilityOwned: Bool;
  public let ghostApplied: Bool;
  public let dashStrength: Float = 1.0;
  public let quickhackAvailabilityDepth: Int32;
  public let dialoguePauseOwned: Bool;
  public let dialogueInputPlayer: wref<PlayerPuppet>;
  public let dialogueSkippedProvider: wref<IVisualizerTimeProvider>;
  public let dialogueProvider: wref<IVisualizerTimeProvider>;
  public let dialogueTimers: array<wref<DialogChoiceTimerController>>;
  public let godBlockedHits: Int32;
  public let staminaHud: wref<StaminabarWidgetGameController>;

  private final func UpdateDialogueTimers() {
    let i = ArraySize(this.dialogueTimers) - 1;
    while i >= 0 {
      if IsDefined(this.dialogueTimers[i]) { this.dialogueTimers[i].CheatKitPauseDialogueTimer(this.dialoguePauseOwned); }
      else { ArrayErase(this.dialogueTimers, i); }
      i -= 1;
    }
  }

  private final func UpdateStealthVisibility() {
    if !IsDefined(this.player) { return; }
    if this.Has(n"stealth") || this.GhostActive() {
      if !this.stealthVisibilityOwned {
        this.wasInvisible = this.player.IsInvisible();
        this.stealthVisibilityOwned = true;
        this.player.SetInvisible(true);
      }
    } else if this.stealthVisibilityOwned {
      this.player.SetInvisible(this.wasInvisible);
      this.stealthVisibilityOwned = false;
    }
  }

  public final func GhostActive() -> Bool {
    return this.Has(n"ghost") || (this.Has(n"ghost_crouch") && IsDefined(this.player) && this.player.IsAttached() && this.player.CheatKitIsCrouched());
  }

  public final func UpdateGhostMode() {
    if !IsDefined(this.player) { return; }
    let active = this.GhostActive();
    this.UpdateStealthVisibility();
    if active != this.ghostApplied {
      this.ghostApplied = active;
      this.DropModifiers(n"ghost_effective");
      if active { this.Modifier(n"ghost_effective", Cast<StatsObjectID>(this.player.GetEntityID()), gamedataStatType.IsIgnoredByEnemyNPC, gameStatModifierType.Additive, 1.0); }
      this.WeaponTick(true);
    }
  }

  public final func UnlimitedDash() -> Bool {
    return this.Has(n"dash_free") || this.Has(n"infinite_air");
  }

  public final func ClearDashCooldown() {
    if !IsDefined(this.player) || !this.UnlimitedDash() { return; }
    StatusEffectHelper.RemoveStatusEffect(this.player, t"BaseStatusEffect.DodgeCooldown");
    StatusEffectHelper.RemoveStatusEffect(this.player, t"BaseStatusEffect.DodgeAirCooldown");
  }

  public final func ReleaseDialoguePause() {
    if !this.dialoguePauseOwned { return; }
    this.dialoguePauseOwned = false;
    let current = GetPlayer(this.GetGameInstance());
    if IsDefined(current) && current.IsAttached() {
      let time = GameInstance.GetTimeSystem(this.GetGameInstance());
      if IsDefined(time) { time.UnsetTimeDilation(n"CheatKit.Dialogue"); }
      this.UpdateDialogueTimers();
    }
  }

  public final func DialogueTick() {
    let game = this.GetGameInstance();
    let current = GetPlayer(game);
    if !this.Has(n"dialogue_timer") || !IsDefined(current) || !current.IsAttached() {
      this.ReleaseDialoguePause();
      if IsDefined(this.dialogueInputPlayer) { this.dialogueInputPlayer.UnregisterInputListener(this); }
      this.dialogueInputPlayer = null;
      this.dialogueProvider = null;
      this.dialogueSkippedProvider = null;
      return;
    }
    if this.dialogueInputPlayer != current {
      if IsDefined(this.dialogueInputPlayer) { this.dialogueInputPlayer.UnregisterInputListener(this); }
      this.dialogueInputPlayer = current;
      current.RegisterInputListener(this, n"Choice1");
      current.RegisterInputListener(this, n"Choice2");
      current.RegisterInputListener(this, n"Choice3");
      current.RegisterInputListener(this, n"Choice4");
      current.RegisterInputListener(this, n"DialogConfirm");
    }
    let board = GameInstance.GetBlackboardSystem(game).Get(GetAllBlackboardDefs().UIInteractions);
    if !IsDefined(board) { this.ReleaseDialoguePause(); return; }
    let data = FromVariant<DialogChoiceHubs>(board.GetVariant(GetAllBlackboardDefs().UIInteractions.DialogChoiceHubs));
    let provider: wref<IVisualizerTimeProvider>;
    let i = 0;
    while i < ArraySize(data.choiceHubs) && !IsDefined(provider) {
      let hub = data.choiceHubs[i];
      if ArraySize(hub.choices) > 0 {
        provider = hub.timeProvider;
        let j = 0;
        while j < ArraySize(hub.choices) && !IsDefined(provider) {
          provider = hub.choices[j].timeProvider;
          j += 1;
        }
      }
      i += 1;
    }
    this.dialogueProvider = provider;
    if !IsDefined(provider) {
      this.ReleaseDialoguePause();
      this.dialogueSkippedProvider = null;
      return;
    }
    if provider == this.dialogueSkippedProvider || provider.GetCurrentProgress() >= 1.0 {
      this.ReleaseDialoguePause();
      return;
    }
    if !this.dialoguePauseOwned {
      GameInstance.GetTimeSystem(game).SetTimeDilation(n"CheatKit.Dialogue", 0.0);
      this.dialoguePauseOwned = true;
    }
    this.UpdateDialogueTimers();
  }

  protected cb func OnAction(action: ListenerAction, consumer: ListenerActionConsumer) -> Bool {
    if this.dialoguePauseOwned && (ListenerAction.IsButtonJustPressed(action) || ListenerAction.IsButtonJustReleased(action)) {
      let menu = GameInstance.GetBlackboardSystem(this.GetGameInstance()).Get(GetAllBlackboardDefs().UI_System);
      if !IsDefined(menu) || !menu.GetBool(GetAllBlackboardDefs().UI_System.IsInMenu) {
        this.dialogueSkippedProvider = this.dialogueProvider;
        this.ReleaseDialoguePause();
      }
    }
  }

  public final func Has(key: CName) -> Bool {
    return ArrayContains(this.flags, key);
  }

  public final func DropModifiers(group: CName) {
    let i = ArraySize(this.mods) - 1;
    while i >= 0 {
      if Equals(this.mods[i].group, group) {
        GameInstance.GetStatsSystem(this.GetGameInstance()).RemoveModifier(this.mods[i].owner, this.mods[i].value);
        ArrayErase(this.mods, i);
      }
      i -= 1;
    }
  }

  public final func Modifier(group: CName, owner: StatsObjectID, stat: gamedataStatType, type: gameStatModifierType, value: Float) -> Bool {
    let entry: CKOwnedModifier;
    entry.group = group;
    entry.owner = owner;
    entry.value = RPGManager.CreateStatModifier(stat, type, value);
    if GameInstance.GetStatsSystem(this.GetGameInstance()).AddModifier(owner, entry.value) {
      ArrayPush(this.mods, entry);
      return true;
    }
    return false;
  }

  public final func RefillStamina(force: Bool) -> Bool {
    if !IsDefined(this.player) || !this.player.IsAttached() { this.lastError = "E_NO_PLAYER"; return false; }
    let pools = GameInstance.GetStatPoolsSystem(this.GetGameInstance());
    let id = Cast<StatsObjectID>(this.player.GetEntityID());
    if !IsDefined(pools) || !pools.IsStatPoolAdded(id, gamedataStatPoolType.Stamina) {
      this.lastError = "E_STAMINA_LOADING";
      return false;
    }
    if pools.GetStatPoolMaxPointValue(id, gamedataStatPoolType.Stamina) <= 0.0 {
      this.lastError = "E_NO_STAMINA_POOL";
      return false;
    }
    if force || pools.GetStatPoolValue(id, gamedataStatPoolType.Stamina, true) < 100.0 {
      pools.RequestSettingStatPoolValueIgnoreChangeMode(id, gamedataStatPoolType.Stamina, 100.0, this.player, true);
    }
    this.player.CheatKitSyncStaminaCache();
    if IsDefined(this.staminaHud) { this.staminaHud.CheatKitSyncStaminaBar(this.Has(n"stamina")); }
    return true;
  }

  private final func MaintainGodMode() -> Bool {
    if !IsDefined(this.player) || !this.player.IsAttached() { return false; }
    let gm = GameInstance.GetGodModeSystem(this.GetGameInstance());
    if !IsDefined(gm) { return false; }
    let id = this.player.GetEntityID();
    let sources = gm.GetGodModeSources(id, gameGodModeType.Invulnerable);
    if ArrayContains(sources, n"CheatKit.God") { return true; }
    return gm.AddGodMode(id, gameGodModeType.Invulnerable, n"CheatKit.God");
  }

  public final func Pool(pool: gamedataStatPoolType) {
    let system = GameInstance.GetStatPoolsSystem(this.GetGameInstance());
    let id = Cast<StatsObjectID>(this.player.GetEntityID());
    if system.IsStatPoolAdded(id, pool) {
      system.RequestSettingStatPoolMaxValue(id, pool, this.player);
    }
  }

  public final func Set(key: CName, on: Bool) -> Bool {
    let id: StatsObjectID;
    let gm = GameInstance.GetGodModeSystem(this.GetGameInstance());
    if this.Has(key) == on { return true; }
    if on {
      this.player = GetPlayer(this.GetGameInstance());
      if !IsDefined(this.player) || !this.player.IsAttached() { return false; }
      if (Equals(key, n"sandevistan") || Equals(key, n"sandy_freeze")) && !this.HasInstalledSandevistan() {
        this.lastError = "E_NO_SANDEVISTAN";
        return false;
      }
      ArrayPush(this.flags, key);
    } else {
      ArrayRemove(this.flags, key);
    }
    this.DropModifiers(key);
    if Equals(key, n"instant_scan") && !on { this.ReleaseInstantScanning(); }
    if on && Equals(key, n"netrunner_stealth") { this.CancelNetrunnerTraces(); }
    if on && (Equals(key, n"quickhack_fast") || Equals(key, n"quickhack_cd")) { CheatKitQuickhacks.ClearEquippedCooldowns(this.player); }
    if !on { this.ReleaseNetrunner(key); }
    if !IsDefined(this.player) { return !on; }
    id = Cast<StatsObjectID>(this.player.GetEntityID());
    if Equals(key, n"netrunner_stealth") || Equals(key, n"quickhack_fast") { this.player.QueueEvent(new RefreshQuickhackMenuEvent()); }
    switch key {
      case n"cyber_capacity":
        if on {
          let applied = this.Modifier(key, id, gamedataStatType.HumanityTotalMaxValue, gameStatModifierType.Additive, 10000.0);
          applied = this.Modifier(key, id, gamedataStatType.HumanityAvailable, gameStatModifierType.Additive, 10000.0) && applied;
          applied = this.Modifier(key, id, gamedataStatType.HumanityOverallocated, gameStatModifierType.Multiplier, 0.0) && applied;
          if !applied { this.DropModifiers(key); ArrayRemove(this.flags, key); this.lastError = "E_CAPACITY"; return false; }
        }
        break;
      case n"no_cyberpsychosis":
        if on {
          this.Modifier(key, id, gamedataStatType.HumanityOverallocated, gameStatModifierType.Multiplier, 0.0);
          StatusEffectHelper.RemoveStatusEffect(this.player, t"BaseStatusEffect.Tech_Master_Perk_3_Buff");
        }
        break;
      case n"noclip":
        this.flightVelocity = Vector4(0.0, 0.0, 0.0, 0.0);
        break;
      case n"items_ammo":
      case n"items_no_decrease":
      case n"components":
      case n"qh_components":
        ArrayClear(this.inventory);
        this.InventoryTick();
        break;
      case n"god":
        if on {
          let nativeApplied = this.MaintainGodMode();
          let statApplied = this.Modifier(key, id, gamedataStatType.IsInvulnerable, gameStatModifierType.Additive, 1.0);
          if !nativeApplied && !statApplied { ArrayRemove(this.flags, key); this.lastError = "E_GOD_APPLY"; return false; }
        } else if IsDefined(gm) { gm.RemoveGodMode(this.player.GetEntityID(), gameGodModeType.Invulnerable, n"CheatKit.God"); }
        break;
      case n"stamina":
        if !this.RefillStamina(true) && on { ArrayRemove(this.flags, key); return false; }
        break;
      case n"fall":
        if on { this.Modifier(key, id, gamedataStatType.FallDamageReduction, gameStatModifierType.Additive, 1.0); }
        break;
      case n"massive_carry":
        if on { this.Modifier(key, id, gamedataStatType.CarryCapacity, gameStatModifierType.Additive, 100000.0); }
        break;
      case n"multijump":
      case n"infinite_air":
        if on {
          this.Modifier(key, id, gamedataStatType.HasDoubleJump, gameStatModifierType.Additive, 1.0);
          if Equals(key, n"infinite_air") {
            this.Modifier(key, id, gamedataStatType.HasDodge, gameStatModifierType.Additive, 1.0);
            this.Modifier(key, id, gamedataStatType.HasDodgeAir, gameStatModifierType.Additive, 1.0);
            this.Modifier(key, id, gamedataStatType.IsDodgeStaminaFree, gameStatModifierType.Additive, 1.0);
          }
        }
        this.ClearDashCooldown();
        break;
      case n"dash_free":
        if on {
          this.Modifier(key, id, gamedataStatType.HasDodge, gameStatModifierType.Additive, 1.0);
          this.Modifier(key, id, gamedataStatType.HasDodgeAir, gameStatModifierType.Additive, 1.0);
          this.Modifier(key, id, gamedataStatType.IsDodgeStaminaFree, gameStatModifierType.Additive, 1.0);
          this.ClearDashCooldown();
        }
        break;
      case n"stealth":
        this.UpdateStealthVisibility();
        if on {
          this.camoOwned = !GameInstance.GetStatusEffectSystem(this.GetGameInstance()).HasStatusEffect(this.player.GetEntityID(), t"BaseStatusEffect.OpticalCamoPlayerBuffBase");
          if this.camoOwned { StatusEffectHelper.ApplyStatusEffect(this.player, t"BaseStatusEffect.OpticalCamoPlayerBuffBase"); }
        } else {
          if this.camoOwned { StatusEffectHelper.RemoveStatusEffect(this.player, t"BaseStatusEffect.OpticalCamoPlayerBuffBase"); }
          this.camoOwned = false;
        }
        break;
      case n"ghost":
      case n"ghost_crouch":
        this.UpdateGhostMode();
        break;
      case n"dialogue_timer":
        this.DialogueTick();
    if this.Has(n"instant_scan") && IsDefined(this.ckScanTarget) { this.ckScanTarget.CheatKitInstantScan(); }
    if this.Has(n"netrunner_stealth") { this.CancelNetrunnerTraces(); }
        break;
      case n"freeze_time":
        if on { this.frozenTime = GameTime.GetSeconds(GameInstance.GetTimeSystem(this.GetGameInstance()).GetGameTime()); }
        break;
      case n"sandevistan":
        if on {
          this.Modifier(key, id, gamedataStatType.PlayerSandevistanChargesDecayEnabled, gameStatModifierType.Multiplier, 0.0);
          this.Modifier(key, id, gamedataStatType.PlayerCorruptedSandevistanChargesDecayEnabled, gameStatModifierType.Multiplier, 0.0);
          this.Modifier(key, id, gamedataStatType.PlayerSandevistanChargesDecayPerSecond, gameStatModifierType.Multiplier, 0.0);
          this.Modifier(key, id, gamedataStatType.TimeDilationSandevistanEnterCost, gameStatModifierType.Multiplier, 0.0);
          this.Modifier(key, id, gamedataStatType.TimeDilationSandevistanCooldownBase, gameStatModifierType.Multiplier, 0.0);
          this.Pool(gamedataStatPoolType.SandevistanCharge);
        } else { this.Sandy(false); }
        break;
      case n"blackwall":
        if !this.Blackwall(on) && on { ArrayRemove(this.flags, key); return false; }
        break;
      case n"vehicle_god":
        if !on {
          let i = 0;
          while i < ArraySize(this.vehicles) {
            if IsDefined(this.vehicles[i]) { gm.RemoveGodMode(this.vehicles[i].GetEntityID(), gameGodModeType.Invulnerable, n"CheatKit.Vehicle"); }
            i += 1;
          }
          ArrayClear(this.vehicles);
        }
        break;
      case n"vehicle_tuning":
        if !on && IsDefined(this.drive) { this.drive.Release(); }
        break;
      case n"police_ignore":
        if on { CheatKitPolice.Maintain(this.GetGameInstance()); }
        break;
      case n"accuracy":
      case n"no_recoil":
      case n"no_reload":
        this.DropModifiers(n"accuracy");
        this.DropModifiers(n"no_recoil");
        this.DropModifiers(n"no_reload");
        this.WeaponTick(true);
        if Equals(key, n"no_reload") && on {
          let stats = GameInstance.GetStatsSystem(this.GetGameInstance());
          if (IsDefined(this.weapon) && stats.GetStatValue(Cast<StatsObjectID>(this.weapon.GetEntityID()), gamedataStatType.NumShotsToFire) > 0.01) || (IsDefined(this.leftWeapon) && stats.GetStatValue(Cast<StatsObjectID>(this.leftWeapon.GetEntityID()), gamedataStatType.NumShotsToFire) > 0.01) {
            ArrayRemove(this.flags, key);
            this.WeaponTick(true);
            this.lastError = "E_AMMO_COST";
            return false;
          }
        }
        break;
    }
    return true;
  }

  public final func Parameter(key: CName, value: Float) -> Bool {
    let id: StatsObjectID;
    if Equals(key, n"vehicle_speed") || Equals(key, n"vehicle_reverse") || Equals(key, n"vehicle_accel") || Equals(key, n"vehicle_brake") || Equals(key, n"vehicle_turn") || Equals(key, n"vehicle_grip") || Equals(key, n"vehicle_downforce") {
      if !IsDefined(this.drive) { this.drive = new CheatKitDriveController(); }
      return this.drive.Parameter(key, value);
    }
    if Equals(key, n"dash_strength") {
      if value < 0.25 || value > 10.0 { return false; }
      this.dashStrength = value;
      return true;
    }
    if Equals(key, n"fire_rate") {
      if value < 0.1 || value > 20.0 { return false; }
      this.fireRate = value;
      this.WeaponTick(true);
      return true;
    }
    if Equals(key, n"blackwall_targets") {
      if value < 1.0 || value > 50.0 { return false; }
      this.blackwallTargets = Cast<Int32>(value);
      return true;
    }
    if Equals(key, n"blackwall_range") {
      if value < 5.0 || value > 500.0 { return false; }
      this.blackwallRange = value;
      return true;
    }
    if Equals(key, n"xp_mul") { this.xpMul = value; return true; }
    if Equals(key, n"cred_mul") { this.credMul = value; return true; }
    if Equals(key, n"skill_mul") { this.skillMul = value; return true; }
    if Equals(key, n"game_speed") {
      if value == 1.0 && !this.gameSpeedOwned { return true; }
      let current = GetPlayer(this.GetGameInstance());
      if !IsDefined(current) || !current.IsAttached() { return false; }
      let time = GameInstance.GetTimeSystem(this.GetGameInstance());
      if !IsDefined(time) { return false; }
      if this.gameSpeedOwned { time.UnsetTimeDilation(n"CheatKit.Speed"); }
      this.gameSpeedOwned = value != 1.0;
      if this.gameSpeedOwned { time.SetTimeDilation(n"CheatKit.Speed", value); }
      return true;
    }
    if !IsDefined(this.player) { this.player = GetPlayer(this.GetGameInstance()); }
    if !IsDefined(this.player) { return false; }
    id = Cast<StatsObjectID>(this.player.GetEntityID());
    this.DropModifiers(key);
    switch key {
      case n"carry":
        if value > 0.0 {
          let current = GameInstance.GetStatsSystem(this.GetGameInstance()).GetStatValue(id, gamedataStatType.CarryCapacity);
          this.Modifier(key, id, gamedataStatType.CarryCapacity, gameStatModifierType.Additive, value - current);
        }
        return true;
      case n"speed":
        if value != 1.0 { this.Modifier(key, id, gamedataStatType.MaxSpeed, gameStatModifierType.Multiplier, value); }
        return true;
      case n"jump":
        if value != 1.0 { this.Modifier(key, id, gamedataStatType.JumpHeight, gameStatModifierType.Multiplier, value); }
        return true;
    }
    return false;
  }

  public final func HasInstalledSandevistan() -> Bool {
    if !IsDefined(this.player) || !this.player.IsAttached() { return false; }
    if GameInstance.GetStatsSystem(this.GetGameInstance()).GetStatValue(Cast<StatsObjectID>(this.player.GetEntityID()), gamedataStatType.HasSandevistan) < 1.0 { return false; }
    let data = EquipmentSystem.GetData(this.player);
    if !IsDefined(data) { return false; }
    let area = gamedataEquipmentArea.SystemReplacementCW;
    let count = data.GetNumberOfSlots(area);
    let i = 0;
    while i < count {
      let item = data.GetItemInEquipSlot(area, i);
      if ItemID.IsValid(item) {
        let record = TweakDBInterface.GetItemRecord(ItemID.GetTDBID(item));
        if IsDefined(record) && record.TagsContains(n"Sandevistan") && GameInstance.GetTransactionSystem(this.GetGameInstance()).HasItem(this.player, item) { return true; }
      }
      i += 1;
    }
    return false;
  }

  public final func Sandy(on: Bool, opt force: Bool) -> Bool {
    if on && !this.Has(n"sandevistan") && !this.Has(n"sandy_freeze") { this.lastError = "E_ENABLE_SANDEVISTAN"; return false; }
    if !IsDefined(this.player) { return false; }
    if on && !this.HasInstalledSandevistan() { this.lastError = "E_NO_SANDEVISTAN"; return false; }
    if !on && !this.sandyActive && !force && !GameInstance.GetTimeSystem(this.GetGameInstance()).IsTimeDilationActive(n"sandevistan") { return true; }
    if on { this.Pool(gamedataStatPoolType.SandevistanCharge); }
    let event = new PSMPostponedParameterBool();
    event.id = on ? n"requestSandevistanActivation" : n"requestSandevistanDeactivation";
    event.value = true;
    this.player.QueueEvent(event);
    this.sandyActive = on;
    return true;
  }

  public final func Blackwall(on: Bool) -> Bool {
    let eq = GameInstance.GetScriptableSystemsContainer(this.GetGameInstance()).Get(n"EquipmentSystem") as EquipmentSystem;
    if on {
      if this.blackwallDrawn { return true; }
      if !IsDefined(eq) || !this.CanFly() || StatusEffectSystem.ObjectHasStatusEffectWithTag(this.player, n"BodyCarrying") { this.lastError = "E_SCENE"; return false; }
      if !IsDefined(TweakDBInterface.GetStatusEffectRecord(t"BaseStatusEffect.SoMi_Q306_BlackwallHackUpload")) { this.lastError = "E_NO_BLACKWALL"; return false; }
      let active = ScriptedPuppet.GetActiveWeapon(this.player);
      this.previousWeapon = IsDefined(active) ? active.GetItemID() : ItemID.None();
      this.blackwallWasArmed = IsDefined(active);
      this.blackwallGeneration += 1;
      this.blackwallBusy = false;
      let holster = new EquipmentSystemWeaponManipulationRequest();
      holster.owner = this.player;
      holster.requestType = EquipmentManipulationAction.UnequipWeapon;
      holster.equipAnimType = gameEquipAnimationType.Default;
      eq.QueueRequest(holster);
      this.blackwallInput = new CheatKitBlackwallInput();
      this.blackwallInput.state = this;
      this.blackwallInputPlayer = this.player;
      this.player.RegisterInputListener(this.blackwallInput, n"RangedAttack");
      this.blackwallDrawn = true;
    } else {
      if IsDefined(this.blackwallInputPlayer) && IsDefined(this.blackwallInput) { this.blackwallInputPlayer.UnregisterInputListener(this.blackwallInput); }
      if IsDefined(this.blackwallInput) { this.blackwallInput.state = null; }
      this.blackwallInput = null;
      this.blackwallInputPlayer = null;
      this.ReleaseBlackwallAnimation();
      this.blackwallGeneration += 1;
      this.blackwallBusy = false;
      this.blackwallHeld = false;
      if this.blackwallDrawn && this.blackwallWasArmed && IsDefined(eq) && this.CanFly() && !IsDefined(ScriptedPuppet.GetActiveWeapon(this.player)) {
        let draw = new DrawItemRequest();
        draw.owner = this.player;
        draw.itemID = this.previousWeapon;
        draw.equipAnimationType = gameEquipAnimationType.Default;
        if GameInstance.GetTransactionSystem(this.GetGameInstance()).HasItem(this.player, this.previousWeapon) { eq.QueueRequest(draw); }
      }
      this.blackwallDrawn = false;
    }
    return true;
  }

  public final func BlackwallAttack() -> Bool {
    if !this.Has(n"blackwall") || !this.blackwallDrawn || this.blackwallBusy || !this.BlackwallInputAllowed() { return false; }
    if IsDefined(ScriptedPuppet.GetActiveWeapon(this.player)) { return false; }
    if !StatusEffectSystem.ObjectHasStatusEffect(this.player, t"GameplayRestriction.BodyCarryingWoundedSoldier") {
      AnimationControllerComponent.SetAnimWrapperWeight(this.player, n"carry_woundedSoldier", 1.0);
      this.blackwallAnimationOwned = true;
    }
    this.blackwallBusy = true;
    let board = GameInstance.GetBlackboardSystem(this.GetGameInstance()).Get(GetAllBlackboardDefs().BlackwallDeathAnim);
    let count = Max(1, TweakDBInterface.GetInt(t"Items.BlackwallForce.numberOfHandAnims", 4));
    let index = board.GetInt(GetAllBlackboardDefs().BlackwallDeathAnim.handGestureAnimNumber);
    if index < 0 || index >= count { index = 0; }
    let anim = new AdHocAnimationEvent();
    anim.animationIndex = index;
    anim.useBothHands = true;
    anim.unequipWeapon = false;
    anim.animationDuration = 2.0;
    this.player.QueueEvent(anim);
    board.SetInt(GetAllBlackboardDefs().BlackwallDeathAnim.handGestureAnimNumber, (index + 1) % count);
    let targets = this.BlackwallTargets();
    GameInstance.GetDelaySystem(this.GetGameInstance()).DelayCallback(this.BlackwallStrikeCallback(null, true), 1.0, false);
    let i = 0;
    while i < ArraySize(targets) {
      GameInstance.GetDelaySystem(this.GetGameInstance()).DelayCallback(this.BlackwallStrikeCallback(targets[i], false), 1.0 + 0.12 * Cast<Float>(i), false);
      i += 1;
    }
    let finish = new CheatKitBlackwallFinish();
    finish.state = this;
    finish.player = this.player;
    finish.generation = this.blackwallGeneration;
    GameInstance.GetDelaySystem(this.GetGameInstance()).DelayCallback(finish, 2.0, false);
    return true;
  }

  public final func ReleaseBlackwallAnimation() {
    if IsDefined(this.player) && this.blackwallBusy {
      GameObjectEffectHelper.StopEffectEvent(this.player, n"blackwall_use_force");
    }
    if this.blackwallAnimationOwned && IsDefined(this.player) && !StatusEffectSystem.ObjectHasStatusEffect(this.player, t"GameplayRestriction.BodyCarryingWoundedSoldier") {
      AnimationControllerComponent.SetAnimWrapperWeight(this.player, n"carry_woundedSoldier", 0.0);
    }
    this.blackwallAnimationOwned = false;
  }

  private final func BlackwallStrikeCallback(target: wref<NPCPuppet>, effect: Bool) -> ref<CheatKitBlackwallStrike> {
    let strike = new CheatKitBlackwallStrike();
    strike.state = this;
    strike.player = this.player;
    strike.target = target;
    strike.effect = effect;
    strike.generation = this.blackwallGeneration;
    return strike;
  }

  private final func BlackwallTargetValid(npc: ref<NPCPuppet>) -> Bool {
    if !IsDefined(npc) || !ScriptedPuppet.IsActive(npc) || PlayerPuppet.IsTargetFriendlyNPC(this.player, npc) || PlayerPuppet.IsTargetChildNPC(this.player, npc) { return false; }
    if Vector4.Distance(this.player.GetWorldPosition(), npc.GetWorldPosition()) > this.blackwallRange || !GameInstance.GetTargetingSystem(this.GetGameInstance()).IsVisibleTarget(this.player, npc) { return false; }
    if GameInstance.GetGodModeSystem(this.GetGameInstance()).HasGodMode(npc.GetEntityID(), gameGodModeType.Invulnerable) { return false; }
    return !StatusEffectSystem.ObjectHasStatusEffectWithTag(npc, n"BlackwallHack") && !StatusEffectSystem.ObjectHasStatusEffect(npc, t"BaseStatusEffect.SoMi_Q306_BlackwallHackQuestForceKill");
  }

  public final func BlackwallTargets() -> array<wref<NPCPuppet>> {
    let result: array<wref<NPCPuppet>>;
    let angles: array<Float>;
    let first = GameInstance.GetTargetingSystem(this.GetGameInstance()).GetLookAtObject(this.player, false, false) as NPCPuppet;
    if this.BlackwallTargetValid(first) { ArrayPush(result, first); ArrayPush(angles, -1.0); }
    let forward = Vector4.Normalize(GameInstance.GetCameraSystem(this.GetGameInstance()).GetActiveCameraForward());
    let origin = this.player.GetWorldPosition();
    let found = this.player.GetEntitiesAroundObject(this.blackwallRange, TSF_NPC());
    let i = 0;
    while i < ArraySize(found) {
      let npc = found[i] as NPCPuppet;
      if npc != first && this.BlackwallTargetValid(npc) {
        let angle = Vector4.GetAngleBetween(forward, Vector4.Normalize(npc.GetWorldPosition() - origin));
        let at = 0;
        while at < ArraySize(angles) && angles[at] <= angle { at += 1; }
        ArrayInsert(result, at, npc);
        ArrayInsert(angles, at, angle);
      }
      i += 1;
    }
    while ArraySize(result) > this.blackwallTargets { ArrayPop(result); }
    return result;
  }

  public final func BlackwallEffect() {
    if !this.BlackwallInputAllowed() { return; }
    GameObjectEffectHelper.StartEffectEvent(this.player, n"blackwall_use_force");
    GameInstance.GetAudioSystem(this.GetGameInstance()).SetTriggerEffectModeTimed(n"te_wea_somi_blackwall_charge_attack", 3.0);
  }

  public final func BlackwallStrike(npc: wref<NPCPuppet>) {
    if !this.BlackwallInputAllowed() || !this.BlackwallTargetValid(npc) { return; }
    StatusEffectHelper.ApplyStatusEffect(npc, t"BaseStatusEffect.SoMi_Q306_BlackwallHackUpload");
    let cleanup = new CheatKitBlackwallTargetCleanup();
    cleanup.target = npc;
    GameInstance.GetDelaySystem(this.GetGameInstance()).DelayCallback(cleanup, 4.0, false);
  }

  private final func BlackwallInputAllowed() -> Bool {
    if !this.CanFly() || GameInstance.GetTimeSystem(this.GetGameInstance()).IsPausedState() || StatusEffectSystem.ObjectHasStatusEffectWithTag(this.player, n"NoCombat") { return false; }
    let boards = GameInstance.GetBlackboardSystem(this.GetGameInstance());
    let ui = boards.Get(GetAllBlackboardDefs().UI_System);
    if IsDefined(ui) && ui.GetBool(GetAllBlackboardDefs().UI_System.IsInMenu) { return false; }
    let interactions = boards.Get(GetAllBlackboardDefs().UIInteractions);
    let choices = FromVariant<DialogChoiceHubs>(interactions.GetVariant(GetAllBlackboardDefs().UIInteractions.DialogChoiceHubs));
    return ArraySize(choices.choiceHubs) == 0;
  }

  public final func Tick() {
    let current = GetPlayer(this.GetGameInstance());
    if !IsDefined(current) || !current.IsAttached() { this.Reset(); return; }
    if IsDefined(this.player) && this.player != current { this.Reset(); }
    this.player = current;
    if IsDefined(this.travel) { this.travel.Tick(this); }
    this.UpdateGhostMode();
    this.ClearDashCooldown();
    if this.Has(n"police_ignore") { CheatKitPolice.Maintain(this.GetGameInstance()); }
    this.DialogueTick();
    if (this.Has(n"sandevistan") || this.Has(n"sandy_freeze")) && !this.HasInstalledSandevistan() {
      this.Set(n"sandevistan", false);
      this.Set(n"sandy_freeze", false);
      this.Sandy(false, true);
    }

    if this.pendingTicks > 0 {
      if Vector4.Distance(current.GetWorldPosition(), this.pendingPosition) < 4.0 {
        let maps = GameInstance.GetMappinSystem(this.GetGameInstance());
        if maps.GetManuallyTrackedMappinID() == this.pendingMarker { maps.UntrackMappin(); }
        maps.UnregisterMappin(this.pendingMarker);
        this.pendingTicks = 0;
      } else { this.pendingTicks -= 1; }
    }
    this.InventoryTick();
    this.WeaponTick();
    if this.Has(n"auto_locks") { this.UnlockLookedDoor(); }
    if this.Has(n"god") { this.MaintainGodMode(); }
    if this.Has(n"stamina") { this.RefillStamina(false); }
    if this.Has(n"ram") { this.Pool(gamedataStatPoolType.Memory); }
    if this.Has(n"oxygen") { this.Pool(gamedataStatPoolType.Oxygen); }
    if this.Has(n"heal_cd") || this.Has(n"skills_cd") { this.Pool(gamedataStatPoolType.HealingItemsCharges); }
    if this.Has(n"grenade_cd") || this.Has(n"skills_cd") { this.Pool(gamedataStatPoolType.GrenadesCharges); }
    if this.Has(n"launcher_cd") || this.Has(n"skills_cd") { this.Pool(gamedataStatPoolType.ProjectileLauncherCharges); }
    if this.Has(n"sandevistan") || this.Has(n"skills_cd") { this.Pool(gamedataStatPoolType.SandevistanCharge); }
    if this.Has(n"skills_cd") {
      this.Pool(gamedataStatPoolType.BerserkCharge);
      this.Pool(gamedataStatPoolType.OpticalCamoCharges);
      this.ClearCooldownEffects();
    }
    if this.Has(n"freeze_time") { GameInstance.GetTimeSystem(this.GetGameInstance()).SetGameTimeBySeconds(this.frozenTime); }
    if this.Has(n"vehicle_god") {
      let mount = GameInstance.GetMountingFacility(this.GetGameInstance()).GetMountingInfoSingleWithObjects(this.player);
      let vehicle = GameInstance.FindEntityByID(this.GetGameInstance(), mount.parentId) as VehicleObject;
      if IsDefined(vehicle) && vehicle.IsPlayerVehicle() && !ArrayContains(this.vehicles, vehicle) {
        GameInstance.GetGodModeSystem(this.GetGameInstance()).AddGodMode(vehicle.GetEntityID(), gameGodModeType.Invulnerable, n"CheatKit.Vehicle");
        ArrayPush(this.vehicles, vehicle);
        if CheatKitVehicle.Protected(vehicle) {
          vehicle.DestructionResetGrid();
          vehicle.DestructionResetGlass();
          vehicle.QueueEvent(new VehicleRepairEvent());
        }
      }
    }
  }

  public final func ClearCooldownEffects() {
    let effects: array<ref<StatusEffect>>;
    let sys = GameInstance.GetStatusEffectSystem(this.GetGameInstance());
    sys.GetAppliedEffectsOfType(this.player.GetEntityID(), gamedataStatusEffectType.PlayerCooldown, effects);
    let i = 0;
    while i < ArraySize(effects) {
      let rec = effects[i].GetRecord();
      if rec.GameplayTagsContains(n"PlayerCyberwareCooldown") || rec.GameplayTagsContains(n"CyberwareCooldown") {
        sys.RemoveStatusEffect(this.player.GetEntityID(), rec.GetID());
      }
      i += 1;
    }
  }

  public final func Reset() {
    this.CancelTravel();
    this.parameterGeneration += 1;
    if IsDefined(this.drive) { this.drive.Release(); this.drive = null; }
    this.ReleaseDialoguePause();
    if IsDefined(this.dialogueInputPlayer) { this.dialogueInputPlayer.UnregisterInputListener(this); }
    this.dialogueInputPlayer = null;
    this.dialogueProvider = null;
    this.dialogueSkippedProvider = null;
    if IsDefined(this.player) && this.player.IsAttached() {
      let system = GameInstance.GetScriptableSystemsContainer(this.GetGameInstance()).Get(n"EquipmentSystem") as EquipmentSystem;
      if IsDefined(system) {
        let equipment = system.GetPlayerData(this.player);
        if IsDefined(equipment) { equipment.CheatKitRemoveExtras(); }
      }
    }
    while ArraySize(this.flags) > 0 { this.Set(this.flags[ArraySize(this.flags) - 1], false); }
    while ArraySize(this.mods) > 0 { this.DropModifiers(this.mods[0].group); }
    this.Parameter(n"game_speed", 1.0);
    this.Sandy(false);
    this.xpMul = 1.0;
    this.credMul = 1.0;
    this.skillMul = 1.0;
    this.fireRate = 1.0;
    this.dashStrength = 1.0;
    this.blackwallTargets = 5;
    this.blackwallRange = 75.0;
    this.blackwallHeld = false;
    this.pendingTicks = 0;
    this.RestoreCollision();
    ArrayClear(this.inventory);
    this.weapon = null;
    this.leftWeapon = null;
  }

  public final func WeaponTick(opt force: Bool) {
    if !IsDefined(this.player) { return; }
    let gun = ScriptedPuppet.GetWeaponRight(this.player);
    let left = ScriptedPuppet.GetWeaponLeft(this.player);
    if !force && gun == this.weapon && left == this.leftWeapon { return; }
    this.DropModifiers(n"accuracy"); this.DropModifiers(n"no_recoil"); this.DropModifiers(n"no_reload"); this.DropModifiers(n"fire_rate"); this.DropModifiers(n"ghost_weapon");
    this.weapon = gun;
    this.leftWeapon = left;
    this.ApplyWeaponModifiers(gun);
    if IsDefined(gun) { gun.QueueEvent(new UpdateWeaponStatsEvent()); }
    if left != gun { this.ApplyWeaponModifiers(left); if IsDefined(left) { left.QueueEvent(new UpdateWeaponStatsEvent()); } }
  }

  private final func ApplyWeaponModifiers(gun: wref<WeaponObject>) {
    if !IsDefined(gun) { return; }
    let id = Cast<StatsObjectID>(gun.GetEntityID());
    if this.Has(n"no_reload") { this.Modifier(n"no_reload", id, gamedataStatType.NumShotsToFire, gameStatModifierType.Multiplier, 0.0); }
    if this.fireRate != 1.0 {
      this.Modifier(n"fire_rate", id, gamedataStatType.CycleTime, gameStatModifierType.Multiplier, 1.0 / this.fireRate);
      this.Modifier(n"fire_rate", id, gamedataStatType.CycleTime_Burst, gameStatModifierType.Multiplier, 1.0 / this.fireRate);
      this.Modifier(n"fire_rate", id, gamedataStatType.CycleTime_BurstSecondary, gameStatModifierType.Multiplier, 1.0 / this.fireRate);
      this.Modifier(n"fire_rate", id, gamedataStatType.PreFireTime, gameStatModifierType.Multiplier, 1.0 / this.fireRate);
    }
    if this.GhostActive() { this.ZeroStat(n"ghost_weapon", id, gamedataStatType.WeaponNoise); }
    if this.Has(n"accuracy") {
      this.ZeroStat(n"accuracy", id, gamedataStatType.Spread);
      this.ZeroStat(n"accuracy", id, gamedataStatType.SpreadDefaultX);
      this.ZeroStat(n"accuracy", id, gamedataStatType.SpreadDefaultY);
      this.ZeroStat(n"accuracy", id, gamedataStatType.SpreadMinX);
      this.ZeroStat(n"accuracy", id, gamedataStatType.SpreadMinY);
      this.ZeroStat(n"accuracy", id, gamedataStatType.SpreadMaxX);
      this.ZeroStat(n"accuracy", id, gamedataStatType.SpreadMaxY);
      this.ZeroStat(n"accuracy", id, gamedataStatType.SpreadAdsMinX);
      this.ZeroStat(n"accuracy", id, gamedataStatType.SpreadAdsMinY);
      this.ZeroStat(n"accuracy", id, gamedataStatType.SpreadAdsMaxX);
      this.ZeroStat(n"accuracy", id, gamedataStatType.SpreadAdsMaxY);
      this.ZeroStat(n"accuracy", id, gamedataStatType.SpreadChangePerShot);
      this.ZeroStat(n"accuracy", id, gamedataStatType.SpreadAdsChangePerShot);
      this.ZeroStat(n"accuracy", id, gamedataStatType.Sway);
    }
    if this.Has(n"no_recoil") {
      this.ZeroStat(n"no_recoil", id, gamedataStatType.Recoil);
      this.ZeroStat(n"no_recoil", id, gamedataStatType.RecoilAnimation);
      this.ZeroStat(n"no_recoil", id, gamedataStatType.RecoilKickMin);
      this.ZeroStat(n"no_recoil", id, gamedataStatType.RecoilKickMax);
      this.ZeroStat(n"no_recoil", id, gamedataStatType.RecoilKickMinADS);
      this.ZeroStat(n"no_recoil", id, gamedataStatType.RecoilKickMaxADS);
      this.ZeroStat(n"no_recoil", id, gamedataStatType.RecoilMaxLength);
      this.ZeroStat(n"no_recoil", id, gamedataStatType.RecoilMaxLengthADS);
    }
  }

  private final func ZeroStat(group: CName, id: StatsObjectID, stat: gamedataStatType) {
    this.Modifier(group, id, stat, gameStatModifierType.Multiplier, 0.0);
  }

  private final func ProtectItem(data: wref<gameItemData>) -> Bool {
    if !IsDefined(data) || data.HasTag(n"Quest") || data.HasTag(n"QuestItem") { return false; }
    let type = data.GetItemType();
    if Equals(type, gamedataItemType.Gen_CraftingMaterial) {
      let qh = data.HasTag(n"QuickhackCraftingMaterials");
      return this.Has(n"items_no_decrease") || this.Has(n"items_ammo") || this.Has(qh ? n"qh_components" : n"components");
    }
    return (this.Has(n"items_ammo") || this.Has(n"items_no_decrease")) && (
      Equals(type, gamedataItemType.Con_Ammo) || Equals(type, gamedataItemType.Con_Edible) ||
      Equals(type, gamedataItemType.Con_Inhaler) || Equals(type, gamedataItemType.Con_Injector) ||
      Equals(type, gamedataItemType.Con_LongLasting) || Equals(type, gamedataItemType.Gad_Grenade));
  }

  public final func InventoryTick() {
    if !IsDefined(this.player) { return; }
    let manager = GameInstance.GetInventoryManager(this.GetGameInstance());
    if this.Has(n"items_ammo") {
      if !manager.HasEquipmentStateFlag(gameEEquipmentManagerState.InfiniteAmmo) { manager.AddEquipmentStateFlag(gameEEquipmentManagerState.InfiniteAmmo); this.ammoOwned = true; }
    } else if this.ammoOwned { manager.RemoveEquipmentStateFlag(gameEEquipmentManagerState.InfiniteAmmo); this.ammoOwned = false; }
    if !this.Has(n"items_ammo") && !this.Has(n"items_no_decrease") && !this.Has(n"components") && !this.Has(n"qh_components") { return; }
    let ts = GameInstance.GetTransactionSystem(this.GetGameInstance());
    let items: array<wref<gameItemData>>;
    ts.GetItemList(this.player, items);
    let i = 0;
    while i < ArraySize(items) {
      if this.ProtectItem(items[i]) {
        let id = items[i].GetID(); let j = 0;
        while j < ArraySize(this.inventory) && this.inventory[j].item != id { j += 1; }
        if j == ArraySize(this.inventory) {
          let entry: CKInventoryTarget; entry.item = id; entry.quantity = items[i].GetQuantity(); ArrayPush(this.inventory, entry);
        } else { this.inventory[j].quantity = Max(this.inventory[j].quantity, items[i].GetQuantity()); }
      }
      i += 1;
    }
    i = 0;
    while i < ArraySize(this.inventory) {
      let count = ts.GetItemQuantity(this.player, this.inventory[i].item);
      if count < this.inventory[i].quantity { ts.GiveItem(this.player, this.inventory[i].item, this.inventory[i].quantity - count); }
      i += 1;
    }
  }

  private final func UnlockLookedDoor() {
    let target = GameInstance.GetTargetingSystem(this.GetGameInstance()).GetLookAtObject(this.player, true, true) as Door;
    if !IsDefined(target) || Vector4.Distance(target.GetWorldPosition(), this.player.GetWorldPosition()) > 4.0 { return; }
    let ps = target.GetDevicePS() as DoorControllerPS;
    if !IsDefined(ps) || !ps.IsLocked() || ps.IsSealed() || ps.IsDisabled() || ps.IsUnpowered() { return; }
    ps.MasterUserAuthorizationAttempt(this.player.GetEntityID());
    let action = ps.ActionToggleLock(); action.SetExecutor(this.player); ps.OnToggleLock(action);
  }

  public final func QueueFlight(velocity: Vector4) -> Bool {
    if !this.Has(n"noclip") || !this.CanFly() || velocity.X != velocity.X || velocity.Y != velocity.Y || velocity.Z != velocity.Z || Vector4.Length(velocity) > 301.0 { return false; }
    this.flightVelocity = velocity;
    this.flightUpdatedAt = EngineTime.ToFloat(GameInstance.GetSimTime(this.GetGameInstance()));
    return true;
  }

  public final func CaptureMovement(ctx: ref<StateContext>, si: ref<StateGameScriptInterface>) {
    if this.Has(n"noclip") && this.CanFly() {
      if !si.SetStateVectorParameter(physicsStateValue.SimulationFilter, ToVariant(SimulationFilter.ZERO())) { this.lastError = "E_FLIGHT_PHYSICS"; return; }
      this.collisionOwned = true;
      let parameters = ctx.GetTemporaryScriptableParameter(n"locomotionParameters") as LocomotionParameters;
      if !IsDefined(parameters) { parameters = new LocomotionParameters(); }
      parameters.SetUpwardsGravity(0.0);
      parameters.SetDownwardsGravity(0.0);
      parameters.SetDoJump(false);
      ctx.SetTemporaryScriptableParameter(n"locomotionParameters", parameters, true);
      let velocity = this.flightVelocity;
      if EngineTime.ToFloat(GameInstance.GetSimTime(this.GetGameInstance())) - this.flightUpdatedAt > 0.15 { velocity = Vector4(0.0, 0.0, 0.0, 0.0); }
      if !si.SetStateVectorParameter(physicsStateValue.LinearVelocity, ToVariant(velocity)) { this.lastError = "E_FLIGHT_PHYSICS"; }
    } else if this.collisionOwned {
      let filter: SimulationFilter;
      SimulationFilter.SimulationFilter_BuildFromPreset(filter, n"Player Collision");
      if si.SetStateVectorParameter(physicsStateValue.SimulationFilter, ToVariant(filter)) {
        si.SetStateVectorParameter(physicsStateValue.LinearVelocity, ToVariant(Vector4(0.0, 0.0, 0.0, 0.0)));
        this.collisionOwned = false;
        this.flightVelocity = Vector4(0.0, 0.0, 0.0, 0.0);
      } else { this.lastError = "E_FLIGHT_PHYSICS"; }
    }
  }

  public final func CanFly() -> Bool {
    return IsDefined(this.player) && this.player == GetPlayer(this.GetGameInstance()) && this.player.IsAttached() && !this.player.IsReplacer()
      && !VehicleComponent.IsMountedToVehicle(this.GetGameInstance(), this.player)
      && PlayerPuppet.GetSceneTier(this.player) < 2
      && !GameInstance.GetWorkspotSystem(this.GetGameInstance()).IsActorInWorkspot(this.player);
  }

  public final func FlightReady() -> Bool {
    return this.Has(n"noclip") && this.collisionOwned && this.CanFly();
  }

  public final func RestoreCollision() {
    this.flightVelocity = Vector4(0.0, 0.0, 0.0, 0.0);
  }

}

class CheatKitBlackwallInput extends IScriptable {
  public let state: wref<CheatKitState>;
  protected cb func OnAction(action: ListenerAction, consumer: ListenerActionConsumer) -> Bool {
    if !IsDefined(this.state) || !Equals(ListenerAction.GetName(action), n"RangedAttack") { return false; }
    if ListenerAction.IsButtonJustPressed(action) { this.state.blackwallHeld = true; this.state.BlackwallAttack(); }
    else if ListenerAction.IsButtonJustReleased(action) { this.state.blackwallHeld = false; }
  }
}

class CheatKitBlackwallStrike extends DelayCallback {
  public let state: wref<CheatKitState>;
  public let player: wref<PlayerPuppet>;
  public let target: wref<NPCPuppet>;
  public let effect: Bool;
  public let generation: Int32;
  public func Call() {
    if IsDefined(this.state) && this.state.player == this.player && this.state.Has(n"blackwall") && this.state.blackwallGeneration == this.generation {
      if this.effect { this.state.BlackwallEffect(); } else { this.state.BlackwallStrike(this.target); }
    }
  }
}

class CheatKitBlackwallFinish extends DelayCallback {
  public let state: wref<CheatKitState>;
  public let player: wref<PlayerPuppet>;
  public let generation: Int32;
  public func Call() {
    if IsDefined(this.state) && this.state.player == this.player && this.state.blackwallGeneration == this.generation {
      this.state.ReleaseBlackwallAnimation();
      this.state.blackwallBusy = false;
      if this.state.blackwallHeld { this.state.BlackwallAttack(); }
    }
  }
}

class CheatKitBlackwallTargetCleanup extends DelayCallback {
  public let target: wref<NPCPuppet>;
  public func Call() {
    if IsDefined(this.target) && StatusEffectSystem.ObjectHasStatusEffect(this.target, t"BaseStatusEffect.SoMi_Q306_BlackwallHackQuestForceKill") {
      StatusEffectHelper.RemoveStatusEffect(this.target, t"BaseStatusEffect.SoMi_Q306_BlackwallHackQuestForceKill");
    }
  }
}

@wrapMethod(UpperBodyTransition)
protected final func CheckRangedAttackInput(scriptInterface: ref<StateGameScriptInterface>) -> Bool {
  if CheatKitAPI.Flag(n"blackwall", scriptInterface.GetGame()) && scriptInterface.executionOwner.IsPlayer() { return false; }
  return wrappedMethod(scriptInterface);
}

@wrapMethod(WeaponTransition)
protected const final func ShouldShoot(scriptInterface: ref<StateGameScriptInterface>) -> Bool {
  let state = CheatKitAPI.State(scriptInterface.GetGame());
  if IsDefined(state) && state.Has(n"blackwall") {
    if scriptInterface.executionOwner.IsPlayer() { return false; }
  }
  return wrappedMethod(scriptInterface);
}

@wrapMethod(SprintDecisions)
protected const func EnterCondition(const stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool {
  if CheatKitAPI.Flag(n"noclip", scriptInterface.GetGame()) && scriptInterface.executionOwner.IsPlayer() { return false; }
  return wrappedMethod(stateContext, scriptInterface);
}

@wrapMethod(SprintDecisions)
protected const func ToStand(stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool {
  if CheatKitAPI.Flag(n"noclip", scriptInterface.GetGame()) && scriptInterface.executionOwner.IsPlayer() { return true; }
  return wrappedMethod(stateContext, scriptInterface);
}

@addField(DialogChoiceTimerController)
private let cheatKitVisualPauseOwned: Bool;

@addField(DialogChoiceTimerController)
private let cheatKitDuration: Float;

@addField(DialogChoiceTimerController)
private let cheatKitProgress: Float;

@addMethod(DialogChoiceTimerController)
public final func CheatKitPauseDialogueTimer(paused: Bool) {
  let state = CheatKitAPI.State(GetGameInstance());
  let menu = GameInstance.GetBlackboardSystem(GetGameInstance()).Get(GetAllBlackboardDefs().UI_System);
  let inMenu = IsDefined(menu) && menu.GetBool(GetAllBlackboardDefs().UI_System.IsInMenu);
  if paused {
    if !this.cheatKitVisualPauseOwned {
      let provider = IsDefined(state) ? state.dialogueProvider : null;
      if IsDefined(provider) && provider.GetDuration() > 0.0 {
        this.cheatKitDuration = provider.GetDuration();
        this.cheatKitProgress = ClampF(provider.GetCurrentProgress(), 0.0, 1.0);
      } else if IsDefined(this.m_timerBarAnimProxy) {
        this.cheatKitProgress += (1.0 - this.cheatKitProgress) * ClampF(this.m_timerBarAnimProxy.GetProgression(), 0.0, 1.0);
      }
      this.cheatKitVisualPauseOwned = true;
    }
  }
  if this.cheatKitVisualPauseOwned {
    if paused || inMenu {
      if IsDefined(this.m_timerAnimProxy) {
        this.m_timerAnimProxy.UnregisterFromCallback(inkanimEventType.OnEndLoop, this, n"OnTimerEndLoop");
        this.m_timerAnimProxy.UnregisterFromCallback(inkanimEventType.OnFinish, this, n"OnTimerEndLoop");
        this.m_timerAnimProxy.Stop(true);
      }
      if IsDefined(this.m_timerBarAnimProxy) { this.m_timerBarAnimProxy.Stop(true); }
      inkWidgetRef.SetScale(this.m_bar, Vector2(1.0 - this.cheatKitProgress, 1.0));
      this.time = MaxF(0.0, (1.0 - this.cheatKitProgress) * this.cheatKitDuration - 1.0);
      this.SetTime();
    } else {
      this.cheatKitVisualPauseOwned = false;
      this.SetupAnimation();
      this.StartProgressBarAnim(this.cheatKitDuration, this.cheatKitProgress);
      this.SetTime();
    }
  }
}

@wrapMethod(DialogChoiceTimerController)
public final func StartProgressBarAnim(timeDuration: Float, timedProgress: Float) {
  this.cheatKitDuration = timeDuration;
  this.cheatKitProgress = ClampF(timedProgress, 0.0, 1.0);
  this.cheatKitVisualPauseOwned = false;
  wrappedMethod(timeDuration, timedProgress);
  let state = CheatKitAPI.State(GetGameInstance());
  if IsDefined(state) {
    if !ArrayContains(state.dialogueTimers, this) { ArrayPush(state.dialogueTimers, this); }
    if state.dialoguePauseOwned { this.CheatKitPauseDialogueTimer(true); }
  }
}

@wrapMethod(DialogChoiceTimerController)
public final func OnMenuVisibilityChange(isMenuVisible: Bool) {
  let state = CheatKitAPI.State(GetGameInstance());
  wrappedMethod(isMenuVisible || IsDefined(state) && state.dialoguePauseOwned);
  this.CheatKitPauseDialogueTimer(IsDefined(state) && state.dialoguePauseOwned);
}

@wrapMethod(DialogChoiceTimerController)
protected cb func OnTimerEndLoop(proxy: ref<inkAnimProxy>) -> Bool {
  if this.cheatKitVisualPauseOwned { return true; }
  return wrappedMethod(proxy);
}

@wrapMethod(DialogChoiceTimerController)
protected cb func OnUninitialize() -> Bool {
  let state = CheatKitAPI.State(GetGameInstance());
  if IsDefined(state) { ArrayRemove(state.dialogueTimers, this); }
  this.cheatKitVisualPauseOwned = false;
  wrappedMethod();
}

@wrapMethod(dialogWidgetGameController)
protected func UpdateDialogsData(const data: script_ref<DialogChoiceHubs>) {
  wrappedMethod(data);
  let state = CheatKitAPI.State(GetGameInstance());
  if IsDefined(state) { state.DialogueTick(); }
}

@wrapMethod(dialogWidgetGameController)
protected cb func OnUninitialize() -> Bool {
  let state = CheatKitAPI.State(GetGameInstance());
  if IsDefined(state) {
    state.dialogueSkippedProvider = state.dialogueProvider;
    state.ReleaseDialoguePause();
  }
  wrappedMethod();
}

abstract class CheatKitAPI {
  public static func Vitals(game: GameInstance) -> String {
    let player = GetPlayer(game);
    if !IsDefined(player) || !player.IsAttached() { return "E_NO_PLAYER"; }
    let id = Cast<StatsObjectID>(player.GetEntityID());
    let pools = GameInstance.GetStatPoolsSystem(game);
    let stats = GameInstance.GetStatsSystem(game);
    let gm = GameInstance.GetGodModeSystem(game);
    let state = CheatKitAPI.State(game);
    return "HP=" + ToString(pools.GetStatPoolValue(id, gamedataStatPoolType.Health, true))
      + "% STA=" + ToString(pools.GetStatPoolValue(id, gamedataStatPoolType.Stamina, true))
      + "% STA_MAX=" + ToString(pools.GetStatPoolMaxPointValue(id, gamedataStatPoolType.Stamina))
      + " GOD_FLAG=" + ToString(IsDefined(state) && state.Has(n"god"))
      + " GOD_NATIVE=" + ToString(gm.HasGodMode(player.GetEntityID(), gameGodModeType.Invulnerable))
      + " GOD_STAT=" + ToString(stats.GetStatValue(id, gamedataStatType.IsInvulnerable))
      + " BLOCKED_HITS=" + ToString(IsDefined(state) ? state.godBlockedHits : 0)
      + " STAMINA_FLAG=" + ToString(IsDefined(state) && state.Has(n"stamina"))
      + " IGNORE_STAMINA=" + ToString(stats.GetStatValue(id, gamedataStatType.CanIgnoreStamina))
      + " STA_CACHE=" + ToString(player.GetStaminaPercUnsafe())
      + " STA_CACHE_POINTS=" + ToString(player.GetStaminaValueUnsafe())
      + " EXHAUSTED=" + ToString(player.IsExhausted())
      + " COMBO_FLAG=" + ToString(IsDefined(state) && state.Has(n"melee_combo"));
  }
  public static func InstallAlongside(record: String, game: GameInstance) -> Bool {
    let player = GetPlayer(game);
    let items: array<wref<gameItemData>>;
    if !IsDefined(player) { return false; }
    let equipment = EquipmentSystem.GetData(player);
    if !IsDefined(equipment) { return CheatKitAPI.Fail("E_NO_EQUIPMENT", game); }
    GameInstance.GetTransactionSystem(game).GetItemList(player, items);
    let i = 0;
    while i < ArraySize(items) {
      if ItemID.GetTDBID(items[i].GetID()) == TDBID.Create(record) { return equipment.CheatKitInstallAlongside(items[i].GetID()); }
      i += 1;
    }
    return CheatKitAPI.Fail("E_ITEM_NOT_OWNED", game);
  }

  public static func RemoveExtras(game: GameInstance) -> Bool {
    let player = GetPlayer(game);
    if !IsDefined(player) { return false; }
    let equipment = EquipmentSystem.GetData(player);
    if !IsDefined(equipment) { return CheatKitAPI.Fail("E_NO_EQUIPMENT", game); }
    equipment.CheatKitRemoveExtras();
    return true;
  }
  public static func Fail(reason: String, game: GameInstance) -> Bool {
    let state = CheatKitAPI.State(game);
    if IsDefined(state) { state.lastError = reason; }
    return false;
  }
  public static func State(game: GameInstance) -> ref<CheatKitState> {
    let player = GetPlayer(game);
    if !IsDefined(player) || !player.IsAttached() { return null; }
    let systems = GameInstance.GetScriptableSystemsContainer(game);
    if !IsDefined(systems) { return null; }
    return systems.Get(n"CheatKitState") as CheatKitState;
  }

  public static func Flag(key: CName, game: GameInstance) -> Bool {
    let state = CheatKitAPI.State(game);
    return IsDefined(state) && state.Has(key);
  }

  public static func SafeLanding(si: ref<StateGameScriptInterface>) -> Bool {
    if !IsDefined(si) || !IsDefined(si.executionOwner) || !si.executionOwner.IsPlayer() { return false; }
    let state = CheatKitAPI.State(si.executionOwner.GetGame());
    return IsDefined(state) && (state.Has(n"fall") || state.Has(n"noclip") || state.collisionOwned);
  }

  public static func GhostSource(source: wref<GameObject>) -> Bool {
    if !IsDefined(source) { return false; }
    let grenade = source as BaseGrenade;
    if IsDefined(grenade) { source = grenade.GetUser(); }
    if !IsDefined(source) || source != GetPlayer(source.GetGame()) { return false; }
    let state = CheatKitAPI.State(source.GetGame());
    return IsDefined(state) && state.GhostActive();
  }

  public static func ForgetGhost(owner: wref<GameObject>, target: wref<GameObject>) {
    let puppet = owner as ScriptedPuppet;
    if !IsDefined(puppet) || puppet.IsPlayer() || !IsDefined(target) { return; }
    let tracker = puppet.GetTargetTrackerComponent();
    let tracked: TrackedLocation;
    if IsDefined(tracker) && tracker.ThreatFromEntity(target, tracked) { tracker.RemoveThreat(tracker.MapThreat(target)); }
  }

  public static func IgnoredBy(owner: wref<GameObject>, source: wref<GameObject>) -> Bool {
    return CheatKitAPI.GhostSource(source) || CheatKitPolice.Ignore(owner, source);
  }

  public static func Development(game: GameInstance) -> ref<PlayerDevelopmentData> {
    let player = GetPlayer(game);
    if !IsDefined(player) { return null; }
    return PlayerDevelopmentSystem.GetInstance(player).CheatKitData(player);
  }

  public static func SetPoints(type: gamedataDevelopmentPointType, value: Int32, game: GameInstance) -> Bool {
    let data = CheatKitAPI.Development(game);
    if !IsDefined(data) { return CheatKitAPI.Fail("E_NO_DEVELOPMENT", game); }
    if value < 0 || value > 100000 { return CheatKitAPI.Fail("E_VALUE", game); }
    data.SetDevelopmentsPoint(type, value);
    return data.GetDevPoints(type) == value;
  }

  public static func SetLevel(type: gamedataProficiencyType, value: Int32, game: GameInstance) -> Bool {
    let data = CheatKitAPI.Development(game);
    if !IsDefined(data) { return CheatKitAPI.Fail("E_NO_DEVELOPMENT", game); }
    if value < 1 || value > data.GetProficiencyAbsoluteMaxLevel(type) { return CheatKitAPI.Fail("E_LEVEL_LIMIT", game); }
    let old = data.GetProficiencyLevel(type);
    if old != value { data.ModifyProficiencyLevel(type, false, value - old); }
    return data.GetProficiencyLevel(type) == value;
  }

  public static func MaxSkills(game: GameInstance) -> Bool {
    let ok = CheatKitAPI.SetLevel(gamedataProficiencyType.CoolSkill, 60, game);
    ok = CheatKitAPI.SetLevel(gamedataProficiencyType.IntelligenceSkill, 60, game) && ok;
    ok = CheatKitAPI.SetLevel(gamedataProficiencyType.ReflexesSkill, 60, game) && ok;
    ok = CheatKitAPI.SetLevel(gamedataProficiencyType.StrengthSkill, 60, game) && ok;
    return CheatKitAPI.SetLevel(gamedataProficiencyType.TechnicalAbilitySkill, 60, game) && ok;
  }

  public static func MaxAll(game: GameInstance) -> Bool {
    let data = CheatKitAPI.Development(game);
    if !IsDefined(data) { return false; }
    data.SetAttribute(gamedataStatType.Strength, 20.0);
    data.SetAttribute(gamedataStatType.Reflexes, 20.0);
    data.SetAttribute(gamedataStatType.TechnicalAbility, 20.0);
    data.SetAttribute(gamedataStatType.Intelligence, 20.0);
    data.SetAttribute(gamedataStatType.Cool, 20.0);
    let complete = CheatKitAPI.MaxSkills(game);
    let i = 0;
    while i < EnumInt(gamedataNewPerkType.Count) {
      let perk = IntEnum<gamedataNewPerkType>(i);
      data.UnlockNewPerk(perk);
      let max = data.GetNewPerkMaxLevel(perk);
      let step = 0;
      while data.IsNewPerkBought(perk) < max && step < 10 {
        if !data.BuyNewPerk(perk, true) { break; }
        step += 1;
      }
      if max > 0 && data.IsNewPerkBought(perk) < max { complete = false; }
      i += 1;
    }
    if !complete { return CheatKitAPI.Fail("E_PERK_PARTIAL", game); }
    return true;
  }

  public static func Money(value: Int32, game: GameInstance) -> Bool {
    let player = GetPlayer(game);
    if !IsDefined(player) || value < 0 || value > 1000000000 { return false; }
    let sys = GameInstance.GetTransactionSystem(player.GetGame());
    let item = ItemID.FromTDBID(t"Items.money");
    let old = sys.GetItemQuantity(player, item);
    if old < value { return sys.GiveItem(player, item, value - old); }
    if old > value { return sys.RemoveItem(player, item, old - value); }
    return true;
  }

  public static func Give(record: String, quantity: Int32, game: GameInstance) -> Bool {
    let player = GetPlayer(game);
    let id = TDBID.Create(record);
    if !IsDefined(player) || quantity < 1 || quantity > 100000 || !IsDefined(TweakDBInterface.GetItemRecord(id)) { return false; }
    return GameInstance.GetTransactionSystem(player.GetGame()).GiveItem(player, ItemID.FromTDBID(id), quantity);
  }

  public static func Flight(velocity: Vector4, game: GameInstance) -> Bool {
    let state = CheatKitAPI.State(game);
    return IsDefined(state) && state.QueueFlight(velocity);
  }

  public static func Teleport(position: Vector4, game: GameInstance) -> Bool {
    let player = GetPlayer(game);
    if !IsDefined(player) || !player.IsAttached() || AbsF(position.X) > 100000.0 || AbsF(position.Y) > 100000.0 || AbsF(position.Z) > 10000.0 { return false; }
    if !CheatKitAPI.Clearance(position, game) { return false; }
    let orient = Quaternion.ToEulerAngles(player.GetWorldOrientation());
    GameInstance.GetTeleportationFacility(player.GetGame()).Teleport(player, position, orient);
    return true;
  }

  public static func Waypoint(game: GameInstance) -> Bool {
    let maps = GameInstance.GetMappinSystem(game);
    let marker = maps.GetMappin(maps.GetManuallyTrackedMappinID());
    if !IsDefined(marker) || NotEquals(marker.GetVariant(), gamedataMappinVariant.CustomPositionVariant) { return CheatKitAPI.Fail("E_NO_WAYPOINT", game); }
    let point = marker.GetWorldPosition();
    return CheatKitTravel.Begin(point, 0.0, marker.GetNewMappinID(), true, 0u, game);
  }

  public static func Blink(distance: Float, game: GameInstance) -> Bool {
    let player = GetPlayer(game);
    let start: Vector4;
    let forward: Vector4;
    let hit: TraceResult;
    if !IsDefined(player) { return false; }
    if !CheatKitAPI.Flag(n"blink", game) { return CheatKitAPI.Fail("E_ENABLE_BLINK", game); }
    GameInstance.GetTargetingSystem(player.GetGame()).GetDefaultCrosshairData(player, start, forward);
    let destination = start + forward * distance;
    let sys = GameInstance.GetSpatialQueriesSystem(player.GetGame());
    if sys.SyncRaycastByCollisionGroup(start, destination, n"Static", hit, true, false) {
      destination = Vector4(hit.position.X, hit.position.Y, hit.position.Z, 1.0) - forward * 1.0;
      destination += Cast<Vector4>(hit.normal) * 0.5;
    } else { return CheatKitAPI.Fail("E_NO_SURFACE", game); }
    let landing: Vector4;
    if !CheatKitAPI.FindLanding(destination, 2.0, 20.0, landing, game) {
      if !CheatKitAPI.FindNearbyLanding(destination, forward * -1.0, 0.0, 8.0, landing, game) { return false; }
      if Vector4.Distance(landing, start) > distance + 5.0 { return CheatKitAPI.Fail("E_NO_SAFE_LANDING", game); }
    }
    return CheatKitAPI.Teleport(landing, game);
  }

  public static func QuestTeleport(game: GameInstance) -> Bool {
    let player = GetPlayer(game);
    let positions: array<Vector3>;
    if !IsDefined(player) { return false; }
    let journal = GameInstance.GetJournalManager(player.GetGame());
    let entry = journal.GetTrackedEntry();
    if !IsDefined(entry) { return CheatKitAPI.Fail("E_NO_QUEST", game); }
    let maps = GameInstance.GetMappinSystem(player.GetGame());
    if !maps.GetQuestMappinPositionsByObjective(Cast<Uint32>(journal.GetEntryHash(entry)), positions) || ArraySize(positions) == 0 { return CheatKitAPI.Fail("E_NO_QUEST_POSITION", game); }
    let pos = Vector4(positions[0].X, positions[0].Y, positions[0].Z, 1.0);
    let currentPosition = player.GetWorldPosition();
    let delta = currentPosition - pos;
    delta.Z = 0.0;
    if Vector4.Length(delta) < 20.0 && AbsF(currentPosition.Z - pos.Z) < 4.0 { return CheatKitAPI.Fail("E_QUEST_NEARBY", game); }
    let marker: NewMappinID;
    return CheatKitTravel.Begin(pos, 20.0, marker, false, Cast<Uint32>(journal.GetEntryHash(entry)), game);
  }

  public static func FindLanding(point: Vector4, above: Float, below: Float, out position: Vector4, game: GameInstance) -> Bool {
    if CheatKitAPI.TryLanding(point, above, below, position, game) { return true; }
    return CheatKitAPI.Fail("E_NO_SAFE_LANDING", game);
  }

  public static func FindNearbyLanding(point: Vector4, approach: Vector4, preferred: Float, radiusLimit: Float, out position: Vector4, game: GameInstance) -> Bool {
    approach.Z = 0.0;
    approach.W = 0.0;
    if Vector4.Length(approach) < 0.1 { approach = Vector4(0.0, -1.0, 0.0, 0.0); }
    approach = Vector4.Normalize(approach);
    let ideal = point + approach * preferred;
    let found = false;
    let best = 100000.0;
    let ring = 0;
    let navigation = GameInstance.GetAINavigationSystem(game);
    let player = GetPlayer(game);
    while ring < 7 {
      let radius = ring == 0 ? preferred : ring == 1 ? 8.0 : ring == 2 ? 14.0 : ring == 3 ? 28.0 : ring == 4 ? 40.0 : ring == 5 ? 60.0 : 90.0;
      let angleIndex = 0;
      let count = radius > radiusLimit ? 0 : radius < 0.1 ? 1 : 8;
      while angleIndex < count {
        let angle = Cast<Float>(angleIndex) * 0.7853982;
        let direction = Vector4(approach.X * CosF(angle) - approach.Y * SinF(angle), approach.X * SinF(angle) + approach.Y * CosF(angle), 0.0, 0.0);
        let sample = point + direction * radius;
        let candidate: Vector4;
        let valid = CheatKitAPI.TryLanding(sample, 160.0, 240.0, candidate, game);
        if !valid && IsDefined(navigation) && IsDefined(player) {
          let nav = navigation.FindPointInBoxForCharacter(sample, Vector4(4.0, 4.0, 6.0, 0.0), player);
          if Equals(nav.status, worldNavigationRequestStatus.OK) && AbsF(nav.point.Z - point.Z) <= 160.0 {
            valid = CheatKitAPI.TryLanding(nav.point, 2.0, 4.0, candidate, game);
          }
        }
        if valid {
          let horizontal = candidate - point;
          horizontal.Z = 0.0;
          let deviation = candidate - ideal;
          deviation.Z = 0.0;
          let score = AbsF(Vector4.Length(horizontal) - preferred) + AbsF(candidate.Z - point.Z) * 2.0 + Vector4.Length(deviation) * 0.1;
          if score < best { position = candidate; best = score; found = true; }
        }
        angleIndex += 1;
      }
      if found && (best < 8.0 || ring >= 3 && best < 25.0) { break; }
      ring += 1;
    }
    if found {
      let state = CheatKitAPI.State(game);
      if IsDefined(state) { state.lastError = ""; }
      return true;
    }
    return CheatKitAPI.Fail("E_NO_SAFE_LANDING", game);
  }

  public static func TryLanding(point: Vector4, above: Float, below: Float, out position: Vector4, game: GameInstance) -> Bool {
    let filter: QueryFilter;
    QueryFilter.AddGroup(filter, n"Static");
    QueryFilter.AddGroup(filter, n"Terrain");
    let hit: TraceResult;
    let queries = GameInstance.GetSpatialQueriesSystem(game);
    if !IsDefined(queries) { return false; }
    let found = false;
    let bestHeight = 100000.0;
    let band = 0;
    while band < 4 {
      let height = MinF(above, band == 0 ? 2.0 : band == 1 ? 16.0 : band == 2 ? 64.0 : above);
      let start = point + Vector4(0.0, 0.0, height, 0.0);
      let end = point - Vector4(0.0, 0.0, below, 0.0);
      let layer = 0;
      while layer < 4 && start.Z > end.Z {
        if !queries.SyncRaycastByQueryFilter(start, end, filter, hit, true, false) { break; }
        let candidate = Vector4(hit.position.X, hit.position.Y, hit.position.Z + 0.25, 1.0);
        let floorHeight = hit.position.Z;
        if hit.normal.Z >= 0.65 && AbsF(candidate.Z - point.Z) < bestHeight && CheatKitAPI.LandingFootprint(candidate, filter, game) && CheatKitAPI.Clearance(candidate, game) {
          position = candidate;
          bestHeight = AbsF(candidate.Z - point.Z);
          found = true;
          if bestHeight < 1.0 { return true; }
        }
        start.Z = floorHeight - 0.4;
        layer += 1;
      }
      if height >= above { break; }
      band += 1;
    }
    return found;
  }

  public static func LandingFootprint(position: Vector4, filter: QueryFilter, game: GameInstance) -> Bool {
    let queries = GameInstance.GetSpatialQueriesSystem(game);
    let hit: TraceResult;
    let i = 0;
    while i < 4 {
      let offset = i == 0 ? Vector4(0.3, 0.0, 0.0, 0.0) : i == 1 ? Vector4(-0.3, 0.0, 0.0, 0.0) : i == 2 ? Vector4(0.0, 0.3, 0.0, 0.0) : Vector4(0.0, -0.3, 0.0, 0.0);
      let start = position + offset + Vector4(0.0, 0.0, 0.5, 0.0);
      if !queries.SyncRaycastByQueryFilter(start, start - Vector4(0.0, 0.0, 1.25, 0.0), filter, hit, true, false) || hit.normal.Z < 0.65 { return false; }
      i += 1;
    }
    return true;
  }

  public static func Clearance(position: Vector4, game: GameInstance) -> Bool {
    let queries = GameInstance.GetSpatialQueriesSystem(game);
    let hit: TraceResult;
    if !IsDefined(queries) { return CheatKitAPI.Fail("E_NO_MOVEMENT", game); }
    let center = position + Vector4(0.0, 0.0, 0.95, 0.0);
    let size = Vector4(0.35, 0.35, 0.85, 0.0);
    if queries.Overlap(size, center, EulerAngles(), n"Static", hit) || queries.Overlap(size, center, EulerAngles(), n"Terrain", hit) || queries.Overlap(size, center, EulerAngles(), n"PlayerBlocker", hit) || queries.Overlap(size, center, EulerAngles(), n"Vehicle", hit) { return CheatKitAPI.Fail("E_BLOCKED_DESTINATION", game); }
    return true;
  }

  public static func PlusHour(game: GameInstance) {
    let time = GameInstance.GetTimeSystem(game);
    let seconds = GameTime.GetSeconds(time.GetGameTime()) + 3600;
    time.SetGameTimeBySeconds(seconds);
    let state = CheatKitAPI.State(game);
    if IsDefined(state) && state.Has(n"freeze_time") { state.frozenTime = seconds; }
  }

  public static func ClearWanted(game: GameInstance) -> Bool {
    let sys = GameInstance.GetScriptableSystemsContainer(game).Get(n"PreventionSystem") as PreventionSystem;
    if !IsDefined(sys) { return false; }
    sys.CheatKitClearWanted();
    return sys.GetHeatStageAsInt() == 0u;
  }
}

@wrapMethod(LocomotionEventsTransition)
public func OnEnter(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) {
  wrappedMethod(stateContext, scriptInterface);
  let state = CheatKitAPI.State(scriptInterface.GetGame());
  if IsDefined(state) && scriptInterface.executionOwner.IsPlayer() { state.player = scriptInterface.executionOwner as PlayerPuppet; state.CaptureMovement(stateContext, scriptInterface); }
}

@wrapMethod(LocomotionEventsTransition)
public func OnUpdate(timeDelta: Float, stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) {
  wrappedMethod(timeDelta, stateContext, scriptInterface);
  let state = CheatKitAPI.State(GetGameInstance());
  if IsDefined(state) && scriptInterface.executionOwner.IsPlayer() {
    if state.collisionOwned && (!state.Has(n"noclip") || !state.CanFly()) { this.SetLocomotionParameters(stateContext, scriptInterface); }
    state.CaptureMovement(stateContext, scriptInterface);
  }
}

@wrapMethod(LocomotionAirEvents)
protected func OnUpdate(timeDelta: Float, stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) {
  wrappedMethod(timeDelta, stateContext, scriptInterface);
  if CheatKitAPI.SafeLanding(scriptInterface) {
    this.ResetFallingParameters(stateContext);
    scriptInterface.localBlackboard.SetInt(GetAllBlackboardDefs().PlayerStateMachine.Fall, 0);
    let feature = new AnimFeature_Landing();
    feature.type = 0;
    feature.impactSpeed = 0.0;
    scriptInterface.SetAnimationParameterFeature(n"Landing", feature);
  }
}

@wrapMethod(LocomotionAirDecisions)
protected const func ToRegularLand(const stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool {
  if CheatKitAPI.SafeLanding(scriptInterface) { return this.IsTouchingGround(scriptInterface) && this.GetVerticalSpeed(scriptInterface) <= 0.0; }
  return wrappedMethod(stateContext, scriptInterface);
}

@wrapMethod(LocomotionAirDecisions)
protected const final func ToHardLand(const stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool {
  if CheatKitAPI.SafeLanding(scriptInterface) { return false; }
  return wrappedMethod(stateContext, scriptInterface);
}

@wrapMethod(LocomotionAirDecisions)
protected const final func ToVeryHardLand(const stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool {
  if CheatKitAPI.SafeLanding(scriptInterface) { return false; }
  return wrappedMethod(stateContext, scriptInterface);
}

@wrapMethod(LocomotionAirDecisions)
protected const func ToDeathLand(const stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool {
  if CheatKitAPI.SafeLanding(scriptInterface) { return false; }
  return wrappedMethod(stateContext, scriptInterface);
}

@wrapMethod(LocomotionTransition)
protected final func PlayHardLandingEffects(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) {
  if !CheatKitAPI.SafeLanding(scriptInterface) { wrappedMethod(stateContext, scriptInterface); }
}

@wrapMethod(LocomotionTransition)
protected final func PlayVeryHardLandingEffects(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) {
  if !CheatKitAPI.SafeLanding(scriptInterface) { wrappedMethod(stateContext, scriptInterface); }
}

@wrapMethod(LocomotionTransition)
protected final func PlayDeathLandingEffects(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) {
  if !CheatKitAPI.SafeLanding(scriptInterface) { wrappedMethod(stateContext, scriptInterface); }
}

@wrapMethod(SenseComponent)
public final func ShouldStartDetectingPlayer(player: ref<PlayerPuppet>) -> Bool {
  if CheatKitAPI.IgnoredBy(this.GetOwner(), player) {
    this.m_shouldStartDetectingPlayerCached = false;
    CheatKitAPI.ForgetGhost(this.GetOwner(), player);
    return false;
  }
  return wrappedMethod(player);
}

class CheatKitVehicle extends IScriptable {
  public static func Protected(vehicle: wref<VehicleObject>) -> Bool {
    return IsDefined(vehicle) && vehicle.IsPlayerVehicle() && !vehicle.IsInQuestOrScenePhysicsState() && CheatKitAPI.Flag(n"vehicle_god", vehicle.GetGame());
  }
}

@wrapMethod(VehicleComponent)
protected cb func OnGridDestruction(evt: ref<VehicleGridDestructionEvent>) -> Bool {
  let vehicle = this.GetVehicle();
  if CheatKitVehicle.Protected(vehicle) && IsDefined(evt) {
    let i = 0;
    while i < 16 {
      if evt.state[i] > 0.001 {
        vehicle.DestructionResetGrid();
        vehicle.DestructionResetGlass();
        break;
      }
      i += 1;
    }
  }
  return wrappedMethod(evt);
}

@wrapMethod(VehicleComponent)
private final func SendDestructionDataToGraph(gridID: Int32, gridState: Float) {
  if CheatKitVehicle.Protected(this.GetVehicle()) { gridState = 0.0; }
  wrappedMethod(gridID, gridState);
}

@wrapMethod(VehicleComponent)
private final func DetermineAdditionalEngineFX(gridID: Int32, gridState: Float) {
  if CheatKitVehicle.Protected(this.GetVehicle()) { gridState = 0.0; }
  wrappedMethod(gridID, gridState);
}

@addMethod(PlayerPuppet)
public final func CheatKitIsCrouched() -> Bool {
  let ps = this.GetPuppetPS();
  return this.m_inCrouch || (IsDefined(ps) && ps.IsCrouch());
}

@wrapMethod(PlayerPuppet)
protected cb func OnLocomotionStateChanged(newState: Int32) -> Bool {
  let result = wrappedMethod(newState);
  let state = CheatKitAPI.State(this.GetGame());
  if IsDefined(state) && state.player == this { state.UpdateGhostMode(); }
  return result;
}

@wrapMethod(ReactionManagerComponent)
protected final func HandleStimEvent(stimData: ref<StimEventTaskData>) {
  if IsDefined(stimData) && IsDefined(stimData.cachedEvt) && (CheatKitAPI.IgnoredBy(this.GetOwner(), stimData.cachedEvt.sourceObject) || CheatKitAPI.IgnoredBy(this.GetOwner(), stimData.cachedEvt.stimInvestigateData.attackInstigator as GameObject)) { return; }
  wrappedMethod(stimData);
}

@wrapMethod(StimBroadcasterComponent)
public final func TriggerSingleBroadcast(contextOwner: wref<GameObject>, gdStimType: gamedataStimType, opt radius: Float, opt investigateData: stimInvestigateData, opt propagationChange: Bool) {
  if CheatKitAPI.GhostSource(contextOwner) || CheatKitAPI.GhostSource(investigateData.attackInstigator as GameObject) { return; }
  wrappedMethod(contextOwner, gdStimType, radius, investigateData, propagationChange);
}

@wrapMethod(StimBroadcasterComponent)
public final func AddActiveStimuli(contextOwner: wref<GameObject>, gdStimType: gamedataStimType, opt lifetime: Float, opt radius: Float, opt investigateData: stimInvestigateData, opt propagationChange: Bool, opt shouldOverride: Bool) {
  if CheatKitAPI.GhostSource(contextOwner) || CheatKitAPI.GhostSource(investigateData.attackInstigator as GameObject) { return; }
  wrappedMethod(contextOwner, gdStimType, lifetime, radius, investigateData, propagationChange, shouldOverride);
}

@wrapMethod(StimBroadcasterComponent)
public final static func SendStimDirectly(sender: wref<GameObject>, gdStimType: gamedataStimType, target: ref<GameObject>, opt investigateData: stimInvestigateData, opt delay: Float) {
  if CheatKitAPI.IgnoredBy(target, sender) || CheatKitAPI.IgnoredBy(target, investigateData.attackInstigator as GameObject) { return; }
  wrappedMethod(sender, gdStimType, target, investigateData, delay);
}

@wrapMethod(ScriptedPuppet)
protected func HandleStimsOnHit(evt: ref<gameHitEvent>) {
  if IsDefined(evt) && IsDefined(evt.attackData) && CheatKitAPI.IgnoredBy(this, evt.attackData.GetInstigator()) { CheatKitAPI.ForgetGhost(this, evt.attackData.GetInstigator()); return; }
  wrappedMethod(evt);
}

@wrapMethod(ScriptedPuppet)
public final func PuppetDamagePipelineFinalized(evt: ref<gameHitEvent>) {
  if IsDefined(evt) && IsDefined(evt.attackData) && CheatKitAPI.IgnoredBy(this, evt.attackData.GetInstigator()) { CheatKitAPI.ForgetGhost(this, evt.attackData.GetInstigator()); return; }
  wrappedMethod(evt);
}

@wrapMethod(TargetTrackingExtension)
public final static func OnHit(ownerPuppet: wref<ScriptedPuppet>, evt: ref<gameHitEvent>) {
  if IsDefined(evt) && IsDefined(evt.attackData) && CheatKitAPI.IgnoredBy(ownerPuppet, evt.attackData.GetInstigator()) { CheatKitAPI.ForgetGhost(ownerPuppet, evt.attackData.GetInstigator()); return; }
  wrappedMethod(ownerPuppet, evt);
}

@wrapMethod(AICombatTargetHelper)
public final static func SetNewCombatTarget(context: ScriptExecutionContext, target: ref<GameObject>) -> Bool {
  if CheatKitAPI.IgnoredBy(ScriptExecutionContext.GetOwner(context), target) { CheatKitAPI.ForgetGhost(ScriptExecutionContext.GetOwner(context), target); return false; }
  return wrappedMethod(context, target);
}

@wrapMethod(AIBehaviorScriptBase)
public final static func GetCombatTarget(context: ScriptExecutionContext) -> ref<GameObject> {
  let target = wrappedMethod(context);
  if CheatKitAPI.IgnoredBy(ScriptExecutionContext.GetOwner(context), target) {
    CheatKitAPI.ForgetGhost(ScriptExecutionContext.GetOwner(context), target);
    ScriptExecutionContext.SetArgumentObject(context, n"CombatTarget", null);
    return null;
  }
  return target;
}

@wrapMethod(CooldownStorage)
public final func IsActionReady(action: TweakDBID) -> Bool {
  let player = GetPlayer(GetGameInstance());
  let record = TweakDBInterface.GetObjectActionRecord(action);
  if (CheatKitAPI.Flag(n"quickhack_cd", GetGameInstance()) || CheatKitAPI.Flag(n"quickhack_fast", GetGameInstance())) && IsDefined(player) && this == player.GetCooldownStorage() && IsDefined(record) && IsDefined(record.ObjectActionType()) {
    let type = record.ObjectActionType().Type();
    if Equals(type, gamedataObjectActionType.DeviceQuickHack) || Equals(type, gamedataObjectActionType.PuppetQuickHack) || Equals(type, gamedataObjectActionType.VehicleQuickHack) { return true; }
  }
  return wrappedMethod(action);
}

@wrapMethod(CooldownStorage)
public final func StartSimpleCooldown(action: ref<BaseScriptableAction>) -> CooldownStorageID {
  let record = action.GetObjectActionRecord();
  if (CheatKitAPI.Flag(n"quickhack_cd", GetGameInstance()) || CheatKitAPI.Flag(n"quickhack_fast", GetGameInstance())) && IsDefined(action.GetExecutor()) && action.GetExecutor().IsPlayer() && IsDefined(record) && IsDefined(record.ObjectActionType()) {
    let type = record.ObjectActionType().Type();
    if Equals(type, gamedataObjectActionType.DeviceQuickHack) || Equals(type, gamedataObjectActionType.PuppetQuickHack) || Equals(type, gamedataObjectActionType.VehicleQuickHack) {
      let invalid: CooldownStorageID;
      return invalid;
    }
  }
  return wrappedMethod(action);
}

@wrapMethod(StatPrereq)
public const final func IsFulfilled(game: GameInstance, context: ref<IScriptable>, itemStatsID: StatsObjectID) -> Bool {
  if CheatKitAPI.Flag(n"cyber_capacity", GetGameInstance()) && Equals(this.m_statType, gamedataStatType.HumanityAvailable) && this.GetObjectToCheck(context, game) == GetPlayer(game) { return true; }
  return wrappedMethod(game, context, itemStatsID);
}

@wrapMethod(UIInventoryItemRequirementsManager)
private final func CheckStatEquipRequirement(statToCheck: gamedataStatType, player: wref<GameObject>, statsSystem: ref<StatsSystem>) -> Bool {
  if CheatKitAPI.Flag(n"cyber_capacity", GetGameInstance()) && Equals(statToCheck, gamedataStatType.HumanityAvailable) && player.IsPlayer() { return true; }
  return wrappedMethod(statToCheck, player, statsSystem);
}

@wrapMethod(RPGManager)
public final static func GetEquipRequirements(owner: ref<GameObject>, itemData: ref<gameItemData>) -> array<SItemStackRequirementData> {
  let result = wrappedMethod(owner, itemData);
  if CheatKitAPI.Flag(n"cyber_capacity", GetGameInstance()) && IsDefined(owner) && owner.IsPlayer() {
    let i = ArraySize(result) - 1;
    while i >= 0 {
      if Equals(result[i].statType, gamedataStatType.HumanityAvailable) { ArrayErase(result, i); }
      i -= 1;
    }
  }
  return result;
}

@wrapMethod(SandevistanEvents)
protected func OnEnter(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) {
  let state = CheatKitAPI.State(scriptInterface.GetGame());
  if IsDefined(state) && state.Has(n"sandevistan") && state.HasInstalledSandevistan() { state.Pool(gamedataStatPoolType.SandevistanCharge); }
  wrappedMethod(stateContext, scriptInterface);
  if IsDefined(state) { state.sandyActive = true; state.sandyRefresh = 0.0; }
}

@wrapMethod(TimeDilationEventsTransitions)
protected final func SetTimeDilationGlobal(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>, reason: CName, timeDilation: Float, opt duration: Float, opt easeInCurve: CName, opt easeOutCurve: CName, opt listener: ref<TimeDilationListener>) {
  let state = CheatKitAPI.State(scriptInterface.GetGame());
  if Equals(reason, n"sandevistan") && scriptInterface.executionOwner.IsPlayer() && IsDefined(state) {
    if state.Has(n"sandy_freeze") && state.HasInstalledSandevistan() { timeDilation = 0.001; }
    state.sandyWorldScale = timeDilation;
  }
  wrappedMethod(stateContext, scriptInterface, reason, timeDilation, duration, easeInCurve, easeOutCurve, listener);
}

@wrapMethod(SandevistanEvents)
protected final func OnUpdate(timeDelta: Float, stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) {
  wrappedMethod(timeDelta, stateContext, scriptInterface);
  let state = CheatKitAPI.State(scriptInterface.GetGame());
  if IsDefined(state) && scriptInterface.executionOwner.IsPlayer() {
    if (state.Has(n"sandevistan") || state.Has(n"sandy_freeze")) && !state.HasInstalledSandevistan() { state.Sandy(false, true); return; }
    state.sandyRefresh += timeDelta;
    let scale = scriptInterface.GetStatsSystem().GetStatValue(Cast<StatsObjectID>(scriptInterface.executionOwnerEntityID), gamedataStatType.TimeDilationSandevistanTimeScale);
    let desired = state.Has(n"sandy_freeze") ? 0.001 : scale;
    if state.sandyWorldScale != desired || (state.Has(n"sandevistan") && state.sandyRefresh >= 20.0) {
      state.sandyRefresh = 0.0;
      this.SetTimeDilationGlobal(stateContext, scriptInterface, n"sandevistan", scale, 999.0);
    }
  }
}

@wrapMethod(SandevistanEvents)
protected func OnExit(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) {
  wrappedMethod(stateContext, scriptInterface);
  let state = CheatKitAPI.State(scriptInterface.GetGame());
  if IsDefined(state) { state.sandyActive = false; state.sandyRefresh = 0.0; state.sandyWorldScale = 1.0; }
}

@wrapMethod(SandevistanEvents)
protected final func OnForcedExit(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) {
  wrappedMethod(stateContext, scriptInterface);
  let state = CheatKitAPI.State(scriptInterface.GetGame());
  if IsDefined(state) { state.sandyActive = false; state.sandyRefresh = 0.0; state.sandyWorldScale = 1.0; }
}

@addMethod(PlayerDevelopmentSystem)
public final func CheatKitData(owner: ref<GameObject>) -> ref<PlayerDevelopmentData> {
  return this.GetDevelopmentData(owner);
}

@addField(EquipmentSystemPlayerData)
private persistent let cheatKitExtras: array<ItemID>;

@addField(EquipmentSystemPlayerData)
private persistent let cheatKitExtraActiveIndices: array<Int32>;

@addField(EquipmentSystemPlayerData)
private persistent let cheatKitExtraSlotIndices: array<Int32>;

@addField(EquipmentSystemPlayerData)
private persistent let cheatKitExtraActiveItems: array<ItemID>;

@addMethod(EquipmentSystemPlayerData)
private final func CheatKitNativeSlotCount(area: gamedataEquipmentArea) -> Int32 {
  let record = this.GetEquipAreaRecordByType(area);
  if !IsDefined(record) { return -1; }
  let slots: array<wref<EquipSlot_Record>>;
  record.EquipSlots(slots);
  return ArraySize(slots);
}

@wrapMethod(EquipmentSystemPlayerData)
private final func RestoreEquipSlotsData(out equipArea: SEquipArea) {
  wrappedMethod(equipArea);
  if ArraySize(equipArea.equipSlots) == 0 { return; }
  let i = this.CheatKitNativeSlotCount(equipArea.areaType);
  if i < 1 { return; }
  while i < ArraySize(equipArea.equipSlots) {
    let item = equipArea.equipSlots[i].itemID;
    if ArrayContains(this.cheatKitExtras, item) {
      let restored = equipArea.equipSlots[0];
      restored.itemID = item;
      equipArea.equipSlots[i] = restored;
    }
    i += 1;
  }
}

@addMethod(EquipmentSystemPlayerData)
public final func CheatKitInstallAlongside(item: ItemID) -> Bool {
  return this.CheatKitInstallInSlot(item, -1);
}

@addMethod(EquipmentSystemPlayerData)
public final func CheatKitInstallInSlot(item: ItemID, requestedSlot: Int32) -> Bool {
  let game = this.m_owner.GetGame();
  let area = EquipmentSystem.GetEquipAreaType(item);
  let data = RPGManager.GetItemData(game, this.m_owner, item);
  if !IsDefined(data) || !this.IsItemOfCategory(item, gamedataItemCategory.Cyberware) && !Equals(area, gamedataEquipmentArea.SystemReplacementCW) { return CheatKitAPI.Fail("E_NOT_CYBERWARE", game); }
  if Equals(area, gamedataEquipmentArea.ArmsCW) || Equals(area, gamedataEquipmentArea.RightArm) { return CheatKitAPI.Fail("E_ARM_CONFLICT", game); }
  if this.IsEquipped(item) { return true; }
  let index = this.GetEquipAreaIndex(area);
  if index < 0 || ArraySize(this.m_equipment.equipAreas[index].equipSlots) == 0 { return CheatKitAPI.Fail("E_NO_EQUIP_AREA", game); }
  let nativeCount = this.CheatKitNativeSlotCount(area);
  if nativeCount < 1 || ArraySize(this.m_equipment.equipAreas[index].equipSlots) < nativeCount { return CheatKitAPI.Fail("E_NO_EQUIP_AREA", game); }
  let target = requestedSlot;
  if target < 0 {
    target = nativeCount;
    while target < ArraySize(this.m_equipment.equipAreas[index].equipSlots) && ItemID.IsValid(this.m_equipment.equipAreas[index].equipSlots[target].itemID) { target += 1; }
  }
  if target < nativeCount || target > ArraySize(this.m_equipment.equipAreas[index].equipSlots) || target >= 8 { return CheatKitAPI.Fail("E_CYBER_SLOTS_FULL", game); }
  if target < ArraySize(this.m_equipment.equipAreas[index].equipSlots) && ItemID.IsValid(this.m_equipment.equipAreas[index].equipSlots[target].itemID) {
    this.UnequipItem(index, target);
    if ItemID.IsValid(this.m_equipment.equipAreas[index].equipSlots[target].itemID) { return CheatKitAPI.Fail("E_EQUIP_FAILED", game); }
  }
  let slot = this.m_equipment.equipAreas[index].equipSlots[0];
  slot.itemID = item;
  slot.slotID = this.m_equipment.equipAreas[index].equipSlots[0].slotID;
  ArrayPush(this.cheatKitExtraActiveIndices, this.m_equipment.equipAreas[index].activeIndex);
  while ArraySize(this.cheatKitExtraSlotIndices) < ArraySize(this.cheatKitExtras) { ArrayPush(this.cheatKitExtraSlotIndices, -1); }
  while ArraySize(this.cheatKitExtraActiveItems) < ArraySize(this.cheatKitExtras) { ArrayPush(this.cheatKitExtraActiveItems, ItemID.None()); }
  ArrayPush(this.cheatKitExtraSlotIndices, target);
  ArrayPush(this.cheatKitExtraActiveItems, this.GetActiveItem(area));
  if target == ArraySize(this.m_equipment.equipAreas[index].equipSlots) { ArrayPush(this.m_equipment.equipAreas[index].equipSlots, slot); }
  else { this.m_equipment.equipAreas[index].equipSlots[target] = slot; }
  ArrayPush(this.cheatKitExtras, item);
  this.ApplyEquipGLPs(item);
  this.ApplySlotGLPs(slot.slotID);
  if data.UsesVariants() { data.AddStatsOnEquip(this.m_owner); }
  GameInstance.GetTransactionSystem(game).OnItemAddedToEquipmentSlot(this.m_owner, item);
  if EquipmentSystem.IsItemCyberdeck(item) && !EquipmentSystem.IsItemCyberdeck(this.GetActiveItem(area)) {
    this.m_equipment.equipAreas[index].activeIndex = target;
    let ts = GameInstance.GetTransactionSystem(game);
    let placement = EquipmentSystem.GetPlacementSlot(item);
    ts.RemoveItemFromSlot(this.m_owner, placement);
    ts.AddItemToSlot(this.m_owner, placement, item);
  }
  this.TryFillCyberwareHotkey();
  this.CheatKitSyncOS();
  this.UpdateUIBBAreaChanged(area, this.GetSlotIndex(item));
  PlayerPuppet.ChacheQuickHackListCleanup(this.m_owner);
  return this.IsEquipped(item);
}

@addMethod(EquipmentSystemPlayerData)
public final func CheatKitRemoveExtras() {
  if ArraySize(this.cheatKitExtras) == 0 { this.CheatKitRestoreConfiguredSlots(); return; }
  let i = ArraySize(this.cheatKitExtras) - 1;
  while i >= 0 {
    let item = this.cheatKitExtras[i];
    let area = EquipmentSystem.GetEquipAreaType(item);
    let index = this.GetEquipAreaIndex(area);
    let slotIndex = this.GetSlotIndex(item);
    let nativeCount = this.CheatKitNativeSlotCount(area);
    let equipped = index >= 0 && slotIndex >= nativeCount && nativeCount > 0 && this.IsEquipped(item);
    if !equipped && index >= 0 && nativeCount > 0 && i < ArraySize(this.cheatKitExtraSlotIndices) {
      let tracked = this.cheatKitExtraSlotIndices[i];
      if tracked >= nativeCount && tracked < ArraySize(this.m_equipment.equipAreas[index].equipSlots) && !ItemID.IsValid(this.m_equipment.equipAreas[index].equipSlots[tracked].itemID) { slotIndex = tracked; }
      else { slotIndex = -1; }
    }
    if index >= 0 && nativeCount > 0 && slotIndex >= nativeCount && slotIndex < ArraySize(this.m_equipment.equipAreas[index].equipSlots) && (equipped || !ItemID.IsValid(this.m_equipment.equipAreas[index].equipSlots[slotIndex].itemID)) {
      if equipped {
        this.RemoveEquipGLPs(item);
        this.RemoveSlotGLPs(this.m_equipment.equipAreas[index].equipSlots[slotIndex].slotID);
        let data = RPGManager.GetItemData(this.m_owner.GetGame(), this.m_owner, item);
        if IsDefined(data) && data.UsesVariants() { data.SubtractStatsOnUnequip(this.m_owner); }
      }
      let activeIndex = this.m_equipment.equipAreas[index].activeIndex;
      ArrayErase(this.m_equipment.equipAreas[index].equipSlots, slotIndex);
      if activeIndex == slotIndex {
        activeIndex = i < ArraySize(this.cheatKitExtraActiveItems) ? this.GetSlotIndex(this.cheatKitExtraActiveItems[i]) : -1;
        if activeIndex < 0 { activeIndex = i < ArraySize(this.cheatKitExtraActiveIndices) ? this.cheatKitExtraActiveIndices[i] : 0; }
      }
      else if activeIndex > slotIndex { activeIndex -= 1; }
      if activeIndex < 0 || activeIndex >= ArraySize(this.m_equipment.equipAreas[index].equipSlots) { activeIndex = 0; }
      this.m_equipment.equipAreas[index].activeIndex = activeIndex;
      let j = 0;
      while j < ArraySize(this.cheatKitExtras) {
        if j != i && Equals(EquipmentSystem.GetEquipAreaType(this.cheatKitExtras[j]), area) {
          if j < ArraySize(this.cheatKitExtraSlotIndices) && this.cheatKitExtraSlotIndices[j] > slotIndex { this.cheatKitExtraSlotIndices[j] -= 1; }
          if j < ArraySize(this.cheatKitExtraActiveIndices) && this.cheatKitExtraActiveIndices[j] > slotIndex { this.cheatKitExtraActiveIndices[j] -= 1; }
        }
        j += 1;
      }
      let ts = GameInstance.GetTransactionSystem(this.m_owner.GetGame());
      let placement = EquipmentSystem.GetPlacementSlot(item);
      if equipped && ts.HasItemInSlot(this.m_owner, placement, item) {
        ts.RemoveItemFromSlot(this.m_owner, placement);
        let primary = this.GetActiveItem(area);
        if ItemID.IsValid(primary) { ts.AddItemToSlot(this.m_owner, placement, primary); }
      }
      this.UpdateUIBBAreaChanged(area, 0);
      if equipped { ts.OnItemRemovedFromEquipmentSlot(this.m_owner, item); }
    }
    ArrayErase(this.cheatKitExtras, i);
    if i < ArraySize(this.cheatKitExtraActiveIndices) { ArrayErase(this.cheatKitExtraActiveIndices, i); }
    if i < ArraySize(this.cheatKitExtraSlotIndices) { ArrayErase(this.cheatKitExtraSlotIndices, i); }
    if i < ArraySize(this.cheatKitExtraActiveItems) { ArrayErase(this.cheatKitExtraActiveItems, i); }
    i -= 1;
  }
  this.TryFillCyberwareHotkey();
  this.CheatKitRestoreConfiguredSlots();
  PlayerPuppet.ChacheQuickHackListCleanup(this.m_owner);
}

@addMethod(PreventionSystem)
public final func CheatKitClearWanted() {
  this.execInstructionSafe("ResetOnPlayerChoice");
}

@wrapMethod(PlayerDevelopmentData)
public const final func AddExperience(amount: Int32, type: gamedataProficiencyType, telemetryGainReason: telemetryLevelGainReason, opt isDebug: Bool) {
  let state = CheatKitAPI.State(GetGameInstance());
  if IsDefined(state) && this.GetOwner() == GetPlayer(GetGameInstance()) && amount > 0 && !isDebug {
    if Equals(type, gamedataProficiencyType.Level) {
      amount = state.Has(n"unlimited_xp") ? 10000000 : Cast<Int32>(MinF(Cast<Float>(amount) * state.xpMul, 10000000.0));
    } else if Equals(type, gamedataProficiencyType.StreetCred) {
      amount = state.Has(n"unlimited_cred") ? 10000000 : Cast<Int32>(MinF(Cast<Float>(amount) * state.credMul, 10000000.0));
    } else {
      amount = Cast<Int32>(MinF(Cast<Float>(amount) * state.skillMul, 10000000.0));
    }
  }
  wrappedMethod(amount, type, telemetryGainReason, isDebug);
}

@wrapMethod(DamageSystem)
private final func DealDamages(hitEvent: ref<gameHitEvent>) {
  if IsDefined(hitEvent) && IsDefined(hitEvent.target) && hitEvent.target == GetPlayer(hitEvent.target.GetGame()) && CheatKitAPI.Flag(n"god", hitEvent.target.GetGame()) && !hitEvent.attackData.HasFlag(hitFlag.IgnoreImmortalityModes) {
    let state = CheatKitAPI.State(hitEvent.target.GetGame());
    if IsDefined(state) { state.godBlockedHits += 1; }
    hitEvent.attackData.AddFlag(hitFlag.DealNoDamage, n"CheatKit.God");
    return;
  }
  if CheatKitAPI.Flag(n"one_hit", GetGameInstance()) && IsDefined(hitEvent.attackData.GetInstigator()) && hitEvent.attackData.GetInstigator().IsPlayer() && IsDefined(hitEvent.target) && hitEvent.target.IsNPC() && !PlayerPuppet.IsTargetFriendlyNPC(GetPlayer(GetGameInstance()), hitEvent.target) {
    hitEvent.attackComputed.SetAttackValue(10000000.0, gamedataDamageType.Physical);
  }
  wrappedMethod(hitEvent);
}

@wrapMethod(PlayerStaminaHelpers)
public final static func ModifyStamina(player: ref<PlayerPuppet>, delta: Float, opt perc: Bool) {
  if delta < 0.0 && IsDefined(player) && player == GetPlayer(player.GetGame()) && CheatKitAPI.Flag(n"stamina", player.GetGame()) { return; }
  wrappedMethod(player, delta, perc);
}

@addMethod(PlayerPuppet)
public final func CheatKitSyncStaminaCache() {
  if !IsDefined(this.m_staminaListener) || !this.IsAttached() { return; }
  let pools = GameInstance.GetStatPoolsSystem(this.GetGame());
  let id = Cast<StatsObjectID>(this.GetEntityID());
  if !IsDefined(pools) || !pools.IsStatPoolAdded(id, gamedataStatPoolType.Stamina) { return; }
  let maximum = pools.GetStatPoolMaxPointValue(id, gamedataStatPoolType.Stamina);
  if maximum <= 0.0 { return; }
  let current = pools.GetStatPoolValue(id, gamedataStatPoolType.Stamina, true);
  let previous = this.m_staminaListener.GetStaminaPerc();
  if AbsF(previous - current) > 0.01 || AbsF(this.m_staminaListener.GetStaminaValue() - current * maximum / 100.0) > 0.01 || current >= 100.0 && this.IsExhausted() {
    this.m_staminaListener.OnStatPoolValueChanged(previous, current, maximum / 100.0);
  }
}

@addMethod(StaminabarWidgetGameController)
public final func CheatKitSyncStaminaBar(active: Bool) {
  if !IsDefined(this.m_playerPuppet) || !IsDefined(this.m_staminaController) || !IsDefined(this.m_RootWidget) { return; }
  let pools = GameInstance.GetStatPoolsSystem(this.m_playerPuppet.GetGame());
  let id = Cast<StatsObjectID>(this.m_playerPuppet.GetEntityID());
  if !IsDefined(pools) || !pools.IsStatPoolAdded(id, gamedataStatPoolType.Stamina) { return; }
  let maximum = pools.GetStatPoolMaxPointValue(id, gamedataStatPoolType.Stamina);
  if maximum <= 0.0 { return; }
  let current = pools.GetStatPoolValue(id, gamedataStatPoolType.Stamina, true);
  if AbsF(this.m_currentBarValue * 100.0 - current) > 0.01 {
    this.UpdateStaminaValue(this.m_currentBarValue * 100.0, current, maximum / 100.0, gamedataStatPoolType.Stamina);
  }
  if active { this.m_staminaController.SetNameplateBarProgress(current / 100.0, true); }
  this.EvaluateStaminaBarVisibility();
}

@wrapMethod(StaminabarWidgetGameController)
protected cb func OnPlayerAttach(playerGameObject: ref<GameObject>) -> Bool {
  wrappedMethod(playerGameObject);
  let state = CheatKitAPI.State(playerGameObject.GetGame());
  if IsDefined(state) {
    state.staminaHud = this;
    this.CheatKitSyncStaminaBar(state.Has(n"stamina"));
  }
}

@wrapMethod(StaminabarWidgetGameController)
protected cb func OnPlayerDetach(playerGameObject: ref<GameObject>) -> Bool {
  let state = CheatKitAPI.State(playerGameObject.GetGame());
  if IsDefined(state) && state.staminaHud == this { state.staminaHud = null; }
  wrappedMethod(playerGameObject);
}

@wrapMethod(StaminabarWidgetGameController)
public final func UpdateStaminaValue(oldValue: Float, newValue: Float, percToPoints: Float, statPoolType: gamedataStatPoolType) {
  wrappedMethod(oldValue, newValue, percToPoints, statPoolType);
  if IsDefined(this.m_playerPuppet) && IsDefined(this.m_staminaController) && CheatKitAPI.Flag(n"stamina", this.m_playerPuppet.GetGame()) {
    this.m_staminaController.SetNameplateBarProgress(newValue / 100.0, true);
  }
}

@wrapMethod(StaminabarWidgetGameController)
public final func EvaluateStaminaBarVisibility() {
  wrappedMethod();
  if IsDefined(this.m_playerPuppet) && IsDefined(this.m_RootWidget) && !this.m_forceHidden && this.m_RootWidget.IsVisible() && CheatKitAPI.Flag(n"stamina", this.m_playerPuppet.GetGame()) {
    this.m_RootWidget.SetOpacity(1.0);
  }
}

@wrapMethod(MeleeTransition)
protected const final func CheckIfInfiniteCombo(const stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool {
  if IsDefined(scriptInterface.executionOwner) && scriptInterface.executionOwner == GetPlayer(scriptInterface.GetGame()) && CheatKitAPI.Flag(n"melee_combo", scriptInterface.GetGame()) {
    let pools = scriptInterface.GetStatPoolsSystem();
    if pools.GetStatPoolValue(Cast<StatsObjectID>(scriptInterface.executionOwner.GetEntityID()), gamedataStatPoolType.Stamina, true) > 0.0 { return true; }
  }
  return wrappedMethod(stateContext, scriptInterface);
}

@wrapMethod(DoubleJumpDecisions)
protected const func EnterCondition(const stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool {
  if CheatKitAPI.Flag(n"multijump", scriptInterface.GetGame()) || CheatKitAPI.Flag(n"infinite_air", scriptInterface.GetGame()) {
    stateContext.SetPermanentIntParameter(n"currentNumberOfJumps", 0, true);
    let state = CheatKitAPI.State(scriptInterface.GetGame());
    if IsDefined(state) && state.CanFly() && scriptInterface.IsActionJustPressed(n"Jump") { return true; }
  }
  return wrappedMethod(stateContext, scriptInterface);
}

@wrapMethod(DodgeAirDecisions)
protected const func EnterCondition(const stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool {
  let state = CheatKitAPI.State(scriptInterface.GetGame());
  if IsDefined(state) && state.UnlimitedDash() {
    stateContext.SetPermanentIntParameter(n"currentNumberOfAirDodges", 0, true);
    stateContext.SetPermanentBoolParameter(n"disableAirDash", false, true);
    if IsDefined(state) && state.CanFly() && this.WantsToDodge(stateContext, scriptInterface) { return true; }
  }
  return wrappedMethod(stateContext, scriptInterface);
}

@wrapMethod(LocomotionTransition)
protected const final func WantsToDodge(const stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool {
  let state = CheatKitAPI.State(scriptInterface.GetGame());
  if !IsDefined(state) || !state.UnlimitedDash() || !state.CanFly() { return wrappedMethod(stateContext, scriptInterface); }
  if StatusEffectSystem.ObjectHasStatusEffect(scriptInterface.executionOwner, t"BaseStatusEffect.HealFood3") { return false; }
  state.ClearDashCooldown();
  stateContext.SetPermanentBoolParameter(n"disableAirDash", false, true);
  if scriptInterface.IsActionJustTapped(n"Dodge") || scriptInterface.IsPatternJustActivated(n"Dodge") {
    if scriptInterface.IsMoveInputConsiderable() {
      stateContext.SetConditionFloatParameter(n"DodgeDirection", scriptInterface.GetInputHeading(), true);
      return true;
    }
  }
  return this.WantsToDodgeFromMovementInput(stateContext, scriptInterface) && GameplaySettingsSystem.GetMovementDodgeEnabled(scriptInterface.executionOwner);
}

@addField(LocomotionTransition)
protected let ckDashImpulseScale: Float;

@wrapMethod(LocomotionTransition)
protected final func AddImpulse(stateContext: ref<StateContext>, impulse: Vector4) {
  if this.ckDashImpulseScale > 0.0 { impulse *= this.ckDashImpulseScale; }
  wrappedMethod(stateContext, impulse);
}

@wrapMethod(DodgeEvents)
protected final func Dodge(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>, isExhausted: Bool) {
  let state = CheatKitAPI.State(scriptInterface.GetGame());
  this.ckDashImpulseScale = IsDefined(state) ? state.dashStrength : 1.0;
  wrappedMethod(stateContext, scriptInterface, isExhausted);
  this.ckDashImpulseScale = 0.0;
}

@wrapMethod(DodgeEvents)
protected final func Dash(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>, isExhausted: Bool, treatDashAsAirDash: Bool) {
  let state = CheatKitAPI.State(scriptInterface.GetGame());
  this.ckDashImpulseScale = IsDefined(state) ? state.dashStrength : 1.0;
  wrappedMethod(stateContext, scriptInterface, isExhausted, treatDashAsAirDash);
  this.ckDashImpulseScale = 0.0;
}

@wrapMethod(DodgeAirEvents)
protected final func Dodge(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) {
  let state = CheatKitAPI.State(scriptInterface.GetGame());
  this.ckDashImpulseScale = IsDefined(state) ? state.dashStrength : 1.0;
  wrappedMethod(stateContext, scriptInterface);
  this.ckDashImpulseScale = 0.0;
}
