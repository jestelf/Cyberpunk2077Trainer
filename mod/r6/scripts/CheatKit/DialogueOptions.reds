class CheatKitDialogue extends IScriptable {
  public static func Enabled(playerObject: wref<GameObject>, key: CName) -> Bool {
    if !IsDefined(playerObject) { return false; }
    let game = playerObject.GetGame();
    let player = GetPlayer(game);
    if !IsDefined(player) { return false; }
    let controlled = GameInstance.GetPlayerSystem(game).GetLocalPlayerControlledGameObject();
    return (playerObject == player || playerObject == controlled) && CheatKitAPI.Flag(key, game);
  }
}

@wrapMethod(LifePath_ScriptConditionType)
public const func Evaluate(playerObject: ref<GameObject>) -> Bool {
  if !this.m_inverted && CheatKitDialogue.Enabled(playerObject, n"dialogue_lifepath") { return true; }
  return wrappedMethod(playerObject);
}

@wrapMethod(Build_ScriptConditionType)
public const func Evaluate(playerObject: ref<GameObject>) -> Bool {
  if CheatKitDialogue.Enabled(playerObject, n"dialogue_skills") { return true; }
  return wrappedMethod(playerObject);
}
