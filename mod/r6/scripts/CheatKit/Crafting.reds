@wrapMethod(CraftingSystem)
public const final func GetItemCraftingCost(record: wref<Item_Record>, const craftingData: script_ref<array<wref<RecipeElement_Record>>>) -> array<IngredientData> {
  if CheatKitAPI.Flag(n"free_craft", this.GetGameInstance()) {
    let empty: array<IngredientData>;
    return empty;
  }
  return wrappedMethod(record, craftingData);
}

@wrapMethod(CraftingSystem)
public const final func GetItemFinalUpgradeCost(itemData: wref<gameItemData>) -> array<IngredientData> {
  if CheatKitAPI.Flag(n"free_upgrade", this.GetGameInstance()) {
    let empty: array<IngredientData>;
    return empty;
  }
  return wrappedMethod(itemData);
}

@wrapMethod(CraftingSystem)
public const final func GetMaxCraftingAmount(itemData: wref<gameItemData>) -> Int32 {
  if CheatKitAPI.Flag(n"free_craft", this.GetGameInstance()) {
    let record = TweakDBInterface.GetItemRecord(ItemID.GetTDBID(itemData.GetID()));
    if record.TagsContains(n"Ammo") {
      let bulletAmount = Max(1, CraftingSystem.GetAmmoBulletAmount(record.GetID()));
      let current = GameInstance.GetTransactionSystem(this.GetGameInstance()).GetItemQuantity(this.m_playerCraftBook.GetOwner(), itemData.GetID());
      return Clamp((Cast<Int32>(itemData.GetStatValueByType(gamedataStatType.Quantity)) - current) / bulletAmount, 0, 999);
    }
    return 999;
  }
  return wrappedMethod(itemData);
}

@wrapMethod(RPGManager)
public final static func CanAffordAndPerformCyberwareUpgrade(owner: ref<GameObject>, currentQuality: gamedataQuality, upgradeItemRecord: ref<Item_Record>, out costData: CyberwareUpgradeCostData) -> Bool {
  if !CheatKitCrafting.FreeCyberware(owner) { return wrappedMethod(owner, currentQuality, upgradeItemRecord, costData); }
  if !IsDefined(upgradeItemRecord) || !IsDefined(upgradeItemRecord.QualityHandle()) { return false; }
  let quality = upgradeItemRecord.QualityHandle().Type();
  let plus = RPGManager.ConvertQualityToItemPlusValue(quality);
  let nonPlus = RPGManager.ConvertQualityToNonPlusQuality(quality);
  if plus > 0 && (NotEquals(RPGManager.ConvertQualityToNonPlusQuality(currentQuality), nonPlus)
    || plus - RPGManager.ConvertQualityToItemPlusValue(currentQuality) != 1) { return false; }
  costData.materialRecordID = RPGManager.GetCraftingMaterialRecord(nonPlus).GetID();
  costData.materialCount = 0;
  costData.moneyRequired = 0;
  return true;
}

@wrapMethod(RPGManager)
public final static func HandleBuyShardPopupClosed(owner: ref<GameObject>, equippedItemId: ItemID, resultData: ref<RipperdocTokenPopupCloseData>) {
  if !CheatKitCrafting.FreeCyberware(owner) || !IsDefined(resultData) || !resultData.confirm || !IsDefined(resultData.chosenOptionData) {
    wrappedMethod(owner, equippedItemId, resultData);
    return;
  }
  resultData.costData.materialCount = 0;
  resultData.costData.moneyRequired = 0;
  let statsShardData: InnerItemData;
  let statsShardItemID: ItemID;
  if resultData.chosenOptionData.HasPartInSlot(t"AttachmentSlots.StatsShardSlot") {
    resultData.chosenOptionData.GetItemPart(statsShardData, t"AttachmentSlots.StatsShardSlot");
    statsShardItemID = InnerItemData.GetItemID(statsShardData);
  }
  RPGManager.CreateReplaceEquipmentRequest(owner, equippedItemId, resultData.chosenOptionData.GetID(), statsShardItemID);
  GameInstance.GetInventoryManager(owner.GetGame()).IncrementCyberwareUpgradeSeed(3u);
}

@wrapMethod(RipperDocGameController)
protected cb func OnBuyShardPopupClosed(data: ref<inkGameNotificationData>) -> Bool {
  let result = data as RipperdocTokenPopupCloseData;
  if IsDefined(result) && result.confirm && !CheatKitCrafting.FreeCyberware(this.m_player) && result.costData.materialCount == 0 && IsDefined(this.m_hoveredItem) && IsDefined(result.chosenOptionData) {
    let current = RPGManager.ConvertCombinedValueToQuality(RPGManager.GetCombinedItemQualityValue(this.m_player.GetGame(), this.m_hoveredItem.GetID()));
    let cost: CyberwareUpgradeCostData;
    result.confirm = RPGManager.CanAffordAndPerformCyberwareUpgrade(this.m_player, current, RPGManager.GetItemRecord(result.chosenOptionData.GetID()), cost);
    result.costData = cost;
  }
  return wrappedMethod(data);
}

@wrapMethod(InventoryTooltiData_CyberwareUpgradeData)
public final func IsValid() -> Bool {
  if this.isUpgradable && this.upgradeCost.materialCount == 0 && TDBID.IsValid(this.upgradeCost.materialRecordID) { return true; }
  return wrappedMethod();
}

@addField(UIInventoryItem)
private let ckFreeUpgradeView: Bool;

@wrapMethod(UIInventoryItem)
public final func GetCyberwareUpgradeData(player: wref<GameObject>, opt force: Bool) -> ref<InventoryTooltiData_CyberwareUpgradeData> {
  let free = CheatKitCrafting.FreeCyberware(player);
  let changed = free != this.ckFreeUpgradeView;
  this.ckFreeUpgradeView = free;
  return wrappedMethod(player, force || changed);
}

class CheatKitCrafting {
public static func FreeCyberware(owner: wref<GameObject>) -> Bool {
  return IsDefined(owner) && owner.IsPlayer() && CheatKitAPI.Flag(n"free_upgrade", owner.GetGame());
}
public static func LearnRecipe(recipe: TweakDBID, game: GameInstance) -> Bool {
  let system = CraftingSystem.GetInstance(game);
  if !IsDefined(system) { return false; }
  let book = system.GetPlayerCraftBook();
  let record = TweakDBInterface.GetItemRecipeRecord(recipe);
  if !IsDefined(book) || !IsDefined(record) || !IsDefined(record.CraftingResult()) { return false; }
  let result = record.CraftingResult();
  let item = result.Item();
  if !IsDefined(item) || !IsDefined(item.CraftingData()) || item.TagsContains(n"Quest") || item.TagsContains(n"QuestItem") { return false; }
  let ignored: array<wref<Item_Record>>;
  book.AddRecipe(item.GetID(), ignored, Max(1, result.Amount()));
  book.HideRecipe(item.GetID(), false);
  return book.KnowsRecipe(item.GetID());
}
}
