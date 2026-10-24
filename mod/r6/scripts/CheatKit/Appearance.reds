public native func CK_AppearanceGender(state: ref<gameuiICharacterCustomizationState>, body: Bool, male: Bool) -> Bool;

class CheatKitAppearanceRequest extends MorphMenuUserData {
  public let requester: wref<CheatKitState>;
  public let player: wref<PlayerPuppet>;
  public let valid: Bool;
  public let entered: Bool;
  public let snapshotReady: Bool;
  public let applied: Bool;
  public let bodySwitchPending: Bool;
  public let originalState: ref<gameuiICharacterCustomizationState>;
  public let bodyMale: Bool;
  public let voiceMale: Bool;
  public let lifePath: TweakDBID;
  public let attributePoints: Uint32;
  public let attributes: array<CharacterCustomizationAttribute>;
  public let expansionStandalone: Bool;

  public final func CaptureIdentity(customization: ref<gameuiICharacterCustomizationState>) {
    if !this.valid || this.snapshotReady || !IsDefined(customization) { return; }
    this.originalState = customization;
    this.bodyMale = customization.IsBodyGenderMale();
    this.voiceMale = customization.IsBrainGenderMale();
    this.lifePath = customization.GetLifePath();
    this.attributePoints = customization.GetAttributePointsAvailable();
    this.attributes = customization.GetAttributes();
    this.expansionStandalone = customization.IsExpansionStandalone();
    this.snapshotReady = true;
  }

  public final func RestoreProtected(customization: ref<gameuiICharacterCustomizationState>, opt restoreGender: Bool) -> Bool {
    if !this.valid || !this.snapshotReady || !IsDefined(customization) || customization != this.originalState
      || !IsDefined(this.player) || !this.player.IsAttached() { return false; }
    if restoreGender {
      if customization.IsBodyGenderMale() != this.bodyMale && !CK_AppearanceGender(customization, true, this.bodyMale) { return false; }
      if customization.IsBrainGenderMale() != this.voiceMale && !CK_AppearanceGender(customization, false, this.voiceMale) { return false; }
    }
    if customization.GetLifePath() != this.lifePath { customization.SetLifePath(this.lifePath); }
    if customization.GetAttributePointsAvailable() != this.attributePoints { customization.SetAttributePointsAvailable(this.attributePoints); }
    if customization.IsExpansionStandalone() != this.expansionStandalone { customization.SetIsExpansionStandalone(this.expansionStandalone); }
    let i = 0;
    while i < ArraySize(this.attributes) {
      let attribute = this.attributes[i];
      if customization.GetAttribute(attribute.type) != attribute.value { customization.SetAttribute(attribute.type, attribute.value); }
      if customization.GetAttribute(attribute.type) != attribute.value { return false; }
      i += 1;
    }
    return customization.GetLifePath() == this.lifePath && customization.GetAttributePointsAvailable() == this.attributePoints
      && customization.IsExpansionStandalone() == this.expansionStandalone;
  }

  public final func Release() {
    this.valid = false;
    this.originalState = null;
    ArrayClear(this.attributes);
    if IsDefined(this.requester) && this.requester.ckAppearance == this { this.requester.ckAppearance = null; }
  }
}

class CheatKitAppearanceTimeout extends DelayCallback {
  public let request: ref<CheatKitAppearanceRequest>;
  public func Call() {
    if IsDefined(this.request) && this.request.valid && !this.request.entered {
      if IsDefined(this.request.requester) { this.request.requester.lastError = "E_APPEARANCE_MENU"; }
      this.request.Release();
    }
  }
}

class CheatKitAppearance extends IScriptable {
  public static func BodyLabel(widget: wref<inkWidget>) {
    let text = widget as inkText;
    if IsDefined(text) && (Equals(text.GetText(), GetLocalizedText("LocKey#23208")) || Equals(text.GetText(), "LocKey#23208")) {
      text.SetText(GetLocalizedText("LocKey#35479"));
    }
    let compound = widget as inkCompoundWidget;
    if IsDefined(compound) {
      let i = 0;
      while i < compound.GetNumChildren() {
        CheatKitAppearance.BodyLabel(compound.GetWidgetByIndex(i));
        i += 1;
      }
    }
  }

  public static func CanOpen(player: wref<PlayerPuppet>) -> Bool {
    if !IsDefined(player) || !player.IsAttached() || player.IsReplacer() || player.IsDead() || player.IsInCombat() { return false; }
    let game = player.GetGame();
    if player != GetPlayer(game) || player != GameInstance.GetPlayerSystem(game).GetLocalPlayerControlledGameObject()
      || PlayerPuppet.GetSceneTier(player) >= 2 || VehicleComponent.IsMountedToVehicle(game, player)
      || GameInstance.GetWorkspotSystem(game).IsActorInWorkspot(player)
      || GameInstance.GetPhotoModeSystem(game).IsPhotoModeActive()
      || StatusEffectSystem.ObjectHasStatusEffectWithTag(player, n"Braindance")
      || StatusEffectSystem.ObjectHasStatusEffectWithTag(player, n"BlockAllHubMenu")
      || StatusEffectSystem.ObjectHasStatusEffectWithTag(player, n"LockInHubMenu") { return false; }
    let boards = GameInstance.GetBlackboardSystem(game);
    let ui = boards.Get(GetAllBlackboardDefs().UI_System);
    if IsDefined(ui) && ui.GetBool(GetAllBlackboardDefs().UI_System.IsInMenu) { return false; }
    let interactions = boards.Get(GetAllBlackboardDefs().UIInteractions);
    if IsDefined(interactions) {
      let choices = FromVariant<DialogChoiceHubs>(interactions.GetVariant(GetAllBlackboardDefs().UIInteractions.DialogChoiceHubs));
      if ArraySize(choices.choiceHubs) > 0 { return false; }
    }
    let state = CheatKitAPI.State(game);
    return IsDefined(state) && !state.Has(n"noclip");
  }

  public static func Open(game: GameInstance) -> Bool {
    let state = CheatKitAPI.State(game);
    if !IsDefined(state) { return false; }
    if IsDefined(state.ckAppearance) && state.ckAppearance.valid { return CheatKitAPI.Fail("E_APPEARANCE_BUSY", game); }
    let player = GetPlayer(game);
    if !CheatKitAppearance.CanOpen(player) { return CheatKitAPI.Fail("E_APPEARANCE_STATE", game); }
    let request = new CheatKitAppearanceRequest();
    request.requester = state;
    request.player = player;
    request.valid = true;
    request.m_editMode = gameuiCharacterCustomizationEditTag.Ripperdoc;
    request.m_updatingFinalizedState = true;
    state.ckAppearance = request;
    let timeout = new CheatKitAppearanceTimeout();
    timeout.request = request;
    GameInstance.GetDelaySystem(game).DelayCallback(timeout, 3.0, false);
    GameInstance.GetUISystem(game).QueueMenuEvent(n"OnCheatKitAppearance", request);
    return true;
  }
}

@addMethod(MenuScenario_Idle)
protected cb func OnCheatKitAppearance(userData: ref<IScriptable>) -> Bool {
  let request = userData as CheatKitAppearanceRequest;
  if !IsDefined(request) || !request.valid || request.entered { return false; }
  if this.GetMenusState().IsHubMenuBlocked() || !CheatKitAppearance.CanOpen(request.player) {
    if IsDefined(request.requester) { request.requester.lastError = "E_APPEARANCE_STATE"; }
    request.Release();
    return false;
  }
  this.SwitchToScenario(n"MenuScenario_CharacterCustomizationMirror", request);
  return true;
}

@addField(MenuScenario_CharacterCustomizationMirror)
private let ckAppearanceRequest: ref<CheatKitAppearanceRequest>;

@wrapMethod(MenuScenario_CharacterCustomizationMirror)
protected cb func OnEnterScenario(prevScenario: CName, userData: ref<IScriptable>) -> Bool {
  this.ckAppearanceRequest = userData as CheatKitAppearanceRequest;
  if IsDefined(this.ckAppearanceRequest) { this.ckAppearanceRequest.entered = true; }
  return wrappedMethod(prevScenario, userData);
}

@wrapMethod(MenuScenario_CharacterCustomizationMirror)
protected cb func OnAccept() -> Bool {
  let request = this.ckAppearanceRequest;
  let result = wrappedMethod();
  if IsDefined(request) { request.Release(); }
  this.ckAppearanceRequest = null;
  return result;
}

@wrapMethod(MenuScenario_CharacterCustomizationMirror)
protected cb func OnCancel() -> Bool {
  let request = this.ckAppearanceRequest;
  let result = wrappedMethod();
  if IsDefined(request) { request.Release(); }
  this.ckAppearanceRequest = null;
  return result;
}

@addField(characterCreationBodyMorphMenu)
private let ckAppearance: ref<CheatKitAppearanceRequest>;

@addField(characterCreationBodyMorphMenu)
private let ckBodySwitcher: wref<characterCreationVoiceOverSwitcher>;

@wrapMethod(characterCreationBodyMorphMenu)
protected cb func OnSetUserData(userData: ref<IScriptable>) -> Bool {
  this.ckAppearance = userData as CheatKitAppearanceRequest;
  return wrappedMethod(userData);
}

@wrapMethod(characterCreationBodyMorphMenu)
protected cb func OnInitializeOptionsList(evt: ref<gameuiCharacterCustomizationSystem_OnInitializeOptionsListEvent>) -> Bool {
  let result = wrappedMethod(evt);
  if IsDefined(this.ckAppearance) { this.ckAppearance.CaptureIdentity(this.m_characterCustomizationState); }
  return result;
}

@wrapMethod(characterCreationBodyMorphMenu)
public final func InitializeList() {
  if !IsDefined(this.ckAppearance) || !this.ckAppearance.valid || !this.m_updatingFinalizedState { wrappedMethod(); return; }
  this.RequestCameraChange(this.m_defaultPreviewSlot);
  let system = this.GetCharacterCustomizationSystem();
  system.ApplyEditTag(gameuiCharacterCustomizationEditTag.NewGame);
  let options = system.GetUnitedOptions(true, true, true);
  inkCompoundRef.RemoveAllChildren(this.m_optionsList);
  if system.IsTransgenderAllowed() { this.CreateVoiceOverSwitcher(); }
  let i = 0;
  while i < ArraySize(options) {
    let option = options[i];
    if option.isEditable && option.isActive && !option.isCensored { this.CreateEntry(option); }
    i += 1;
  }
  let bodyWidget = this.SpawnFromLocal(inkWidgetRef.Get(this.m_optionsList), n"VoiceOverSwitcher");
  this.ckBodySwitcher = bodyWidget.GetController() as characterCreationVoiceOverSwitcher;
  this.ckBodySwitcher.CheatKitBodyType(this.m_characterCustomizationState.IsBodyGenderMale());
  this.ckBodySwitcher.RegisterToCallback(n"OnVoiceOverSwitched", this, n"OnCheatKitBodySwitched");
  bodyWidget.RegisterToCallback(n"OnHoverOver", this, n"OnHoverOverOption");
}

@wrapMethod(characterCreationBodyMorphMenu)
public final func RefreshList() {
  if IsDefined(this.ckAppearance) && this.ckAppearance.valid { this.InitializeList(); return; }
  wrappedMethod();
}

@addMethod(characterCreationBodyMorphMenu)
protected cb func OnCheatKitBodySwitched(widget: wref<inkWidget>) -> Bool {
  if !IsDefined(this.ckAppearance) || !this.ckAppearance.valid || !this.ckAppearance.snapshotReady { return false; }
  let male = (widget.GetController() as characterCreationVoiceOverSwitcher).IsBrainGenderMale();
  if male == this.m_characterCustomizationState.IsBodyGenderMale() { return true; }
  if this.m_inputDisabled || NotEquals(this.m_busySwitchingAppearance, BusySwitchingReason.AVAILABLE) {
    this.ckBodySwitcher.SetIsBrainGenderMale(this.m_characterCustomizationState.IsBodyGenderMale());
    return false;
  }
  this.ckAppearance.bodySwitchPending = true;
  this.m_busySwitchingAppearance = BusySwitchingReason.SWAPPING;
  if !CK_AppearanceGender(this.m_characterCustomizationState, true, male) {
    this.ckAppearance.bodySwitchPending = false;
    this.m_busySwitchingAppearance = BusySwitchingReason.AVAILABLE;
    this.ckAppearance.requester.lastError = "E_APPEARANCE_GENDER";
    this.ckBodySwitcher.SetIsBrainGenderMale(this.m_characterCustomizationState.IsBodyGenderMale());
    return false;
  }
  return true;
}

@wrapMethod(characterCreationBodyMorphMenu)
protected cb func OnAppearanceSwitched(evt: ref<gameuiCharacterCustomizationSystem_OnAppearanceSwitchedEvent>) -> Bool {
  let result = wrappedMethod(evt);
  if IsDefined(this.ckAppearance) && this.ckAppearance.valid && this.ckAppearance.bodySwitchPending {
    this.ckAppearance.bodySwitchPending = false;
    this.InitializeList();
    this.m_busySwitchingAppearance = BusySwitchingReason.AVAILABLE;
  }
  return result;
}

@wrapMethod(characterCreationBodyMorphMenu)
protected cb func OnVoiceOverSwitched(widget: wref<inkWidget>) -> Bool {
  if !IsDefined(this.ckAppearance) || !this.ckAppearance.valid { return wrappedMethod(widget); }
  let male = (widget.GetController() as characterCreationVoiceOverSwitcher).IsBrainGenderMale();
  if male == this.m_characterCustomizationState.IsBrainGenderMale() { return true; }
  if !this.ckAppearance.snapshotReady || !CK_AppearanceGender(this.m_characterCustomizationState, false, male) {
    this.ckAppearance.requester.lastError = "E_APPEARANCE_GENDER";
    (widget.GetController() as characterCreationVoiceOverSwitcher).SetIsBrainGenderMale(this.m_characterCustomizationState.IsBrainGenderMale());
    return false;
  }
  this.GetCharacterCustomizationSystem().TriggerVoiceToneSample();
  return true;
}

@addField(characterCreationVoiceOverSwitcher)
private let ckBodyType: Bool;

@addMethod(characterCreationVoiceOverSwitcher)
public final func CheatKitBodyType(male: Bool) {
  this.ckBodyType = true;
  this.SetIsBrainGenderMale(male);
  CheatKitAppearance.BodyLabel(this.GetRootWidget());
}

@wrapMethod(characterCreationVoiceOverSwitcher)
public final func SetIsBrainGenderMale(isMale: Bool) {
  if !this.ckBodyType { wrappedMethod(isMale); return; }
  this.m_isMale = isMale;
  inkTextRef.SetText(this.m_selectedLabel, GetLocalizedText(isMale ? "LocKey#43481" : "LocKey#43482"));
  inkWidgetRef.SetVisible(this.m_warningLabel, false);
  this.CallCustomCallback(n"OnVoiceOverSwitched");
}

@wrapMethod(characterCreationBodyMorphMenu)
public final func ConfirmCustomizedCharacter() {
  if IsDefined(this.ckAppearance) && !this.ckAppearance.RestoreProtected(this.m_characterCustomizationState) { return; }
  wrappedMethod();
}

@wrapMethod(characterCreationBodyMorphMenu)
public final func ConfirmBackConfirmation() {
  if IsDefined(this.ckAppearance) { this.ckAppearance.RestoreProtected(this.m_characterCustomizationState, true); }
  wrappedMethod();
}

@wrapMethod(characterCreationBodyMorphMenu)
protected cb func OnReFinalizeComplete(evt: ref<gameuiCharacterCustomizationSystem_OnReFinalizeStateCompleteEvent>) -> Bool {
  if IsDefined(this.ckAppearance) { this.ckAppearance.applied = true; }
  return wrappedMethod(evt);
}

@wrapMethod(characterCreationBodyMorphMenu)
protected cb func OnUninitialize() -> Bool {
  if IsDefined(this.ckAppearance) && !this.ckAppearance.applied { this.ckAppearance.RestoreProtected(this.m_characterCustomizationState, true); }
  let result = wrappedMethod();
  if IsDefined(this.ckAppearance) { this.ckAppearance.Release(); }
  this.ckAppearance = null;
  return result;
}
