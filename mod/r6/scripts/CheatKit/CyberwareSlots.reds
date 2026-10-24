struct CheatKitSlotCount {
  public persistent let area: gamedataEquipmentArea;
  public persistent let count: Int32;
}

class CheatKitCyberwareSlots extends IScriptable {
  public static func Supported(area: gamedataEquipmentArea) -> Bool {
    return Equals(area, gamedataEquipmentArea.SystemReplacementCW) || Equals(area, gamedataEquipmentArea.FrontalCortexCW)
      || Equals(area, gamedataEquipmentArea.EyesCW) || Equals(area, gamedataEquipmentArea.HandsCW)
      || Equals(area, gamedataEquipmentArea.NervousSystemCW) || Equals(area, gamedataEquipmentArea.CardiovascularSystemCW)
      || Equals(area, gamedataEquipmentArea.MusculoskeletalSystemCW) || Equals(area, gamedataEquipmentArea.IntegumentarySystemCW)
      || Equals(area, gamedataEquipmentArea.LegsCW);
  }

  public static func Configure(area: gamedataEquipmentArea, count: Int32, game: GameInstance) -> Bool {
    let player = GetPlayer(game);
    if !IsDefined(player) || !player.IsAttached() || player.IsReplacer() || player.IsInCombat()
      || PlayerPuppet.GetSceneTier(player) >= 2 { return CheatKitAPI.Fail("E_CYBER_SLOTS_STATE", game); }
    let ui = GameInstance.GetBlackboardSystem(game).Get(GetAllBlackboardDefs().UI_System);
    if IsDefined(ui) && ui.GetBool(GetAllBlackboardDefs().UI_System.IsInMenu) { return CheatKitAPI.Fail("E_CYBER_SLOTS_MENU", game); }
    let data = EquipmentSystem.GetData(player);
    if !IsDefined(data) { return CheatKitAPI.Fail("E_NO_EQUIPMENT", game); }
    return data.CheatKitConfigureSlots(area, count);
  }

  public static func Count(area: gamedataEquipmentArea, game: GameInstance) -> Int32 {
    let player = GetPlayer(game);
    if !IsDefined(player) { return -1; }
    if !CheatKitCyberwareSlots.Supported(area) { CheatKitAPI.Fail("E_CYBER_SLOTS_AREA", game); return -1; }
    let data = EquipmentSystem.GetData(player);
    if !IsDefined(data) { CheatKitAPI.Fail("E_NO_EQUIPMENT", game); return -1; }
    let count = data.CheatKitSlotCount(area);
    if count < 0 { CheatKitAPI.Fail("E_NO_EQUIP_AREA", game); }
    return count;
  }

  public static func NextAbility(game: GameInstance) -> Bool {
    let player = GetPlayer(game);
    if !IsDefined(player) { return false; }
    let data = EquipmentSystem.GetData(player);
    if !IsDefined(data) { return CheatKitAPI.Fail("E_NO_EQUIPMENT", player.GetGame()); }
    return data.CheatKitNextOSAbility();
  }
}

@addField(EquipmentSystemPlayerData)
private persistent let ckSlotCounts: array<CheatKitSlotCount>;

@addField(EquipmentSystemPlayerData)
private persistent let ckOSAbility: ItemID;

@addMethod(EquipmentSystemPlayerData)
public final func CheatKitSlotCount(area: gamedataEquipmentArea) -> Int32 {
  let index = this.GetEquipAreaIndex(area);
  if index < 0 || index >= ArraySize(this.m_equipment.equipAreas) { return -1; }
  return ArraySize(this.m_equipment.equipAreas[index].equipSlots);
}

@addMethod(EquipmentSystemPlayerData)
private final func CheatKitConfiguredSlots(area: gamedataEquipmentArea) -> Int32 {
  let i = 0;
  while i < ArraySize(this.ckSlotCounts) {
    if Equals(this.ckSlotCounts[i].area, area) { return this.ckSlotCounts[i].count; }
    i += 1;
  }
  return 0;
}

@addMethod(EquipmentSystemPlayerData)
private final func CheatKitExtendSlots(out area: SEquipArea) {
  let count = this.CheatKitConfiguredSlots(area.areaType);
  if count < 1 || count > 8 || !CheatKitCyberwareSlots.Supported(area.areaType) || ArraySize(area.equipSlots) == 0 { return; }
  while ArraySize(area.equipSlots) < count {
    let slot = area.equipSlots[0];
    slot.itemID = ItemID.None();
    ArrayPush(area.equipSlots, slot);
  }
}

@wrapMethod(EquipmentSystemPlayerData)
private final func InitializeEquipmentArea(equipAreaRecord: ref<EquipmentArea_Record>, out equipArea: SEquipArea) {
  wrappedMethod(equipAreaRecord, equipArea);
  this.CheatKitExtendSlots(equipArea);
}

@addMethod(EquipmentSystemPlayerData)
public final func CheatKitConfigureSlots(area: gamedataEquipmentArea, count: Int32) -> Bool {
  let game = this.m_owner.GetGame();
  if !CheatKitCyberwareSlots.Supported(area) || count < 0 || count > 8 { return CheatKitAPI.Fail("E_CYBER_SLOTS_AREA", game); }
  let native = this.CheatKitNativeSlotCount(area);
  let index = this.GetEquipAreaIndex(area);
  if native < 1 || index < 0 { return CheatKitAPI.Fail("E_NO_EQUIP_AREA", game); }
  if ArraySize(this.m_equipment.equipAreas[index].equipSlots) < native { return CheatKitAPI.Fail("E_NO_EQUIP_AREA", game); }
  let target = count == 0 ? native : count;
  if target < native { return CheatKitAPI.Fail("E_CYBER_SLOTS_MIN", game); }
  let i = target;
  while i < ArraySize(this.m_equipment.equipAreas[index].equipSlots) {
    if ItemID.IsValid(this.m_equipment.equipAreas[index].equipSlots[i].itemID) { return CheatKitAPI.Fail("E_CYBER_SLOTS_OCCUPIED", game); }
    i += 1;
  }
  i = ArraySize(this.ckSlotCounts) - 1;
  while i >= 0 {
    if Equals(this.ckSlotCounts[i].area, area) { ArrayErase(this.ckSlotCounts, i); }
    i -= 1;
  }
  if target > native {
    let setting: CheatKitSlotCount;
    setting.area = area;
    setting.count = target;
    ArrayPush(this.ckSlotCounts, setting);
  }
  while ArraySize(this.m_equipment.equipAreas[index].equipSlots) > target { ArrayPop(this.m_equipment.equipAreas[index].equipSlots); }
  this.CheatKitExtendSlots(this.m_equipment.equipAreas[index]);
  this.CheatKitSyncOS();
  this.UpdateUIBBAreaChanged(area, 0);
  return true;
}

@addMethod(EquipmentSystemPlayerData)
private final func CheatKitMultiOS() -> Bool {
  let index = this.GetEquipAreaIndex(gamedataEquipmentArea.SystemReplacementCW);
  return IsDefined(this.m_owner) && this.m_owner.IsPlayer() && index >= 0 && ArraySize(this.m_equipment.equipAreas[index].equipSlots) > 1;
}

@addMethod(EquipmentSystemPlayerData)
public final func CheatKitOSAbility() -> ItemID {
  let none: ItemID;
  if !this.CheatKitMultiOS() { return none; }
  let area = this.m_equipment.equipAreas[this.GetEquipAreaIndex(gamedataEquipmentArea.SystemReplacementCW)];
  let first: ItemID;
  let i = 0;
  while i < ArraySize(area.equipSlots) {
    let item = area.equipSlots[i].itemID;
    if ItemID.IsValid(item) {
      let type = TweakDBInterface.GetCName(ItemID.GetTDBID(item) + t".cyberwareType", n"None");
      if Equals(type, n"Sandevistan") || Equals(type, n"Berserk") {
        if item == this.ckOSAbility { return item; }
        if !ItemID.IsValid(first) { first = item; }
      }
    }
    i += 1;
  }
  return first;
}

@addMethod(EquipmentSystemPlayerData)
public final func CheatKitNextOSAbility() -> Bool {
  let areaType = gamedataEquipmentArea.SystemReplacementCW;
  let index = this.GetEquipAreaIndex(areaType);
  if !this.CheatKitMultiOS() { return CheatKitAPI.Fail("E_NO_OS_ABILITY", this.m_owner.GetGame()); }
  let items: array<ItemID>;
  let i = 0;
  while i < ArraySize(this.m_equipment.equipAreas[index].equipSlots) {
    let item = this.m_equipment.equipAreas[index].equipSlots[i].itemID;
    let type = TweakDBInterface.GetCName(ItemID.GetTDBID(item) + t".cyberwareType", n"None");
    if ItemID.IsValid(item) && (Equals(type, n"Sandevistan") || Equals(type, n"Berserk")) { ArrayPush(items, item); }
    i += 1;
  }
  if ArraySize(items) == 0 { return CheatKitAPI.Fail("E_NO_OS_ABILITY", this.m_owner.GetGame()); }
  let current = this.CheatKitOSAbility();
  i = ArrayFindFirst(items, current);
  this.ckOSAbility = items[(i + 1) % ArraySize(items)];
  this.CheatKitSyncOS();
  return true;
}

@addMethod(EquipmentSystemPlayerData)
public final func CheatKitSyncOS() {
  if !this.CheatKitMultiOS() { return; }
  let area = gamedataEquipmentArea.SystemReplacementCW;
  let index = this.GetEquipAreaIndex(area);
  let deck: ItemID;
  let deckIndex = -1;
  let i = 0;
  while i < ArraySize(this.m_equipment.equipAreas[index].equipSlots) {
    let item = this.m_equipment.equipAreas[index].equipSlots[i].itemID;
    if ItemID.IsValid(item) && EquipmentSystem.IsItemCyberdeck(item) { deck = item; deckIndex = i; break; }
    i += 1;
  }
  if ItemID.IsValid(deck) {
    this.m_equipment.equipAreas[index].activeIndex = deckIndex;
    let transaction = GameInstance.GetTransactionSystem(this.m_owner.GetGame());
    let placement = EquipmentSystem.GetPlacementSlot(deck);
    if !transaction.HasItemInSlot(this.m_owner, placement, deck) {
      transaction.RemoveItemFromSlot(this.m_owner, placement);
      transaction.AddItemToSlot(this.m_owner, placement, deck);
    }
  }
  let ability = this.CheatKitOSAbility();
  this.AssignItemToHotkey(ItemID.IsValid(ability) ? ability : deck, EHotkey.LBRB);
  PlayerPuppet.ChacheQuickHackListCleanup(this.m_owner);
}

@addMethod(EquipmentSystemPlayerData)
private final func CheatKitForgetExtra(item: ItemID) {
  let i = ArraySize(this.cheatKitExtras) - 1;
  while i >= 0 {
    if this.cheatKitExtras[i] == item {
      ArrayErase(this.cheatKitExtras, i);
      if i < ArraySize(this.cheatKitExtraActiveIndices) { ArrayErase(this.cheatKitExtraActiveIndices, i); }
      if i < ArraySize(this.cheatKitExtraSlotIndices) { ArrayErase(this.cheatKitExtraSlotIndices, i); }
      if i < ArraySize(this.cheatKitExtraActiveItems) { ArrayErase(this.cheatKitExtraActiveItems, i); }
    }
    i -= 1;
  }
}

@wrapMethod(EquipmentSystemPlayerData)
private final func UnequipItem(equipAreaIndex: Int32, slotIndex: Int32, opt forceRemove: Bool) {
  if equipAreaIndex < 0 || equipAreaIndex >= ArraySize(this.m_equipment.equipAreas) { return; }
  let area = this.m_equipment.equipAreas[equipAreaIndex];
  if slotIndex < 0 || slotIndex >= ArraySize(area.equipSlots) { return; }
  let item = area.equipSlots[slotIndex].itemID;
  let extra = ArrayContains(this.cheatKitExtras, item);
  if IsDefined(this.m_owner) && this.m_owner.IsPlayer() && ItemID.IsValid(item) && (extra
    || Equals(area.areaType, gamedataEquipmentArea.SystemReplacementCW) && this.CheatKitMultiOS()) {
    let game = this.m_owner.GetGame();
    let transaction = GameInstance.GetTransactionSystem(game);
    let itemData = transaction.GetItemData(this.m_owner, item);
    if !forceRemove && IsDefined(itemData) && itemData.HasTag(n"UnequipBlocked") { return; }
    this.RemoveEquipGLPs(item);
    this.RemoveSlotGLPs(area.equipSlots[slotIndex].slotID);
    if IsDefined(itemData) && itemData.UsesVariants() { itemData.SubtractStatsOnUnequip(this.m_owner); }
    this.m_equipment.equipAreas[equipAreaIndex].equipSlots[slotIndex].itemID = ItemID.None();
    this.CheatKitForgetExtra(item);
    let placement = EquipmentSystem.GetPlacementSlot(item);
    if transaction.HasItemInSlot(this.m_owner, placement, item) { transaction.RemoveItemFromSlot(this.m_owner, placement); }
    transaction.OnItemRemovedFromEquipmentSlot(this.m_owner, item);
    this.CheatKitSyncOS();
    this.UpdateUIBBAreaChanged(area.areaType, slotIndex);
    PlayerPuppet.ChacheQuickHackListCleanup(this.m_owner);
    return;
  }
  wrappedMethod(equipAreaIndex, slotIndex, forceRemove);
  if !this.IsEquipped(item) { this.CheatKitForgetExtra(item); }
  if Equals(area.areaType, gamedataEquipmentArea.SystemReplacementCW) { this.CheatKitSyncOS(); }
}

@addMethod(EquipmentSystemPlayerData)
public final func CheatKitRestoreConfiguredSlots() {
  let i = 0;
  while i < ArraySize(this.m_equipment.equipAreas) {
    this.CheatKitExtendSlots(this.m_equipment.equipAreas[i]);
    i += 1;
  }
  this.CheatKitSyncOS();
}

@wrapMethod(EquipmentSystemPlayerData)
public const final func GetActiveItem(equipArea: gamedataEquipmentArea, opt isLeftHandWeapon: Bool) -> ItemID {
  if Equals(equipArea, gamedataEquipmentArea.SystemReplacementCW) && this.CheatKitMultiOS() {
    let area = this.m_equipment.equipAreas[this.GetEquipAreaIndex(equipArea)];
    let i = 0;
    while i < ArraySize(area.equipSlots) {
      let item = area.equipSlots[i].itemID;
      if ItemID.IsValid(item) && EquipmentSystem.IsItemCyberdeck(item) { return item; }
      i += 1;
    }
  }
  return wrappedMethod(equipArea, isLeftHandWeapon);
}

@wrapMethod(EquipmentSystemPlayerData)
private final func EquipItem(itemID: ItemID, slotIndex: Int32, opt blockActiveSlotsUpdate: Bool, opt forceEquipWeapon: Bool) {
  let area = EquipmentSystem.GetEquipAreaType(itemID);
  let native = this.CheatKitNativeSlotCount(area);
  if IsDefined(this.m_owner) && this.m_owner.IsPlayer() && CheatKitCyberwareSlots.Supported(area)
    && this.CheatKitConfiguredSlots(area) > native && slotIndex >= native {
    this.CheatKitInstallInSlot(itemID, slotIndex);
    this.CheatKitSyncOS();
    return;
  }
  wrappedMethod(itemID, slotIndex, blockActiveSlotsUpdate, forceEquipWeapon);
  if Equals(area, gamedataEquipmentArea.SystemReplacementCW) { this.CheatKitSyncOS(); }
}

@wrapMethod(EquipmentSystemPlayerData)
public final func OnRestored() {
  wrappedMethod();
  this.CheatKitSyncOS();
}

@wrapMethod(EquipmentSystemPlayerData)
public final func OnAttach() {
  wrappedMethod();
  this.CheatKitSyncOS();
}

@wrapMethod(PlayerPuppet)
private final func ActivateIconicCyberware() {
  let data = EquipmentSystem.GetData(this);
  let ability = data.CheatKitOSAbility();
  if this != GetPlayer(this.GetGame()) || !ItemID.IsValid(ability) { wrappedMethod(); return; }
  if this.GetPlayerStateMachineBlackboard().GetInt(GetAllBlackboardDefs().PlayerStateMachine.Vision) == 1 {
    QuickHackableHelper.TryToCycleOverclockedState(this);
    return;
  }
  let type = TweakDBInterface.GetCName(ItemID.GetTDBID(ability) + t".cyberwareType", n"None");
  if Equals(type, n"Sandevistan") {
    if this.IsPhoneCallActive() { this.ShowSandevistanBlockedNotification(); return; }
    if !TimeDilationHelper.CanUseTimeDilation(this) { return; }
  }
  let success = ItemActionsHelper.UseItem(this, ability);
  let event = new DPADActionPerformed();
  event.action = EHotkey.LBRB;
  event.state = EUIActionState.COMPLETED;
  event.successful = success;
  GameInstance.GetUISystem(this.GetGame()).QueueEvent(event);
  if success && NotEquals(type, n"Sandevistan") { this.IconicCyberwareActivated(); }
}
