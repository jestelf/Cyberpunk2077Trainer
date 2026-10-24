@wrapMethod(PlayerPuppet)
protected cb func OnStatusEffectApplied(evt: ref<ApplyStatusEffectEvent>) -> Bool {
  let state = CheatKitAPI.State(this.GetGame());
  if IsDefined(state) && state.UnlimitedDash() && IsDefined(evt.staticData)
    && (evt.staticData.GetID() == t"BaseStatusEffect.DodgeCooldown" || evt.staticData.GetID() == t"BaseStatusEffect.DodgeAirCooldown") {
    StatusEffectHelper.RemoveStatusEffect(this, evt.staticData.GetID());
    return true;
  }
  if CheatKitAPI.Flag(n"no_cyberpsychosis", this.GetGame()) && IsDefined(evt.staticData) && evt.staticData.GetID() == t"BaseStatusEffect.Tech_Master_Perk_3_Buff" {
    StatusEffectHelper.RemoveStatusEffect(this, evt.staticData.GetID());
    return true;
  }
  return wrappedMethod(evt);
}
