extends GutTest

## Phase 5. Special damage, the new prepared rite, and the tincture already stored as an effect.
## The medic's card is not added here. The control cultist_rite stays on the control list.


const RITE := "cultist_prepared_rite"

var rules: CombatRules


func before_each() -> void:
	rules = CombatRules.new()


func test_special_damage_ignores_armor_and_physical_dealt_bonuses() -> void:
	var state := _battle()
	var doctor := _find(state, "hero-3")
	doctor.armor = 20
	var boosted := rules.grant_effect(state, "enemy-2", "enemy-2", _dealt(30))
	var cultist := _find(boosted.state, "enemy-2")
	var outcome := rules.strike_outcome(cultist, _find(boosted.state, "hero-3"), _rite(), doctor.guard_reduction)
	assert_not_null(outcome)
	assert_eq(outcome.listed, [14] as Array[int])
	assert_eq(outcome.on_hit, [14] as Array[int])
	var physical := rules.strike_outcome(cultist, doctor, AbilityCatalog.definition("cultist_basic"), 0)
	assert_lt(physical.listed[0], 3)


func test_special_damage_ignores_block_and_consumes_no_roll() -> void:
	var state := _battle()
	_find(state, "hero-3").block = 100
	var prepared := _prepare(state)
	_at_cultist(prepared.state)
	var rng := _rng(4)
	var before := rng.state
	var result := rules.resolve_prepared_strike(prepared.state, rng)
	var hit := _damage(result)
	assert_eq(hit.amount, 14)
	assert_eq(hit.mitigation, CombatEvent.Mitigation.NONE)
	assert_eq(rng.state, before)


func test_special_damage_does_not_spend_cover() -> void:
	var state := _battle()
	_find(state, "hero-3").guard_reduction = 10
	var prepared := _prepare(state)
	_at_cultist(prepared.state)
	var result := rules.resolve_prepared_strike(prepared.state, _rng(1))
	assert_eq(_damage(result).amount, 14)
	assert_eq(_find(result.state, "hero-3").guard_reduction, 10)


func test_physical_damage_still_uses_armor_block_and_cover() -> void:
	var state := BattleSetup.create_opening_battle()
	state.turn_queue = ["enemy-2", "hero-3"]
	var doctor := _find(state, "hero-3")
	doctor.armor = 5
	doctor.block = 100
	doctor.guard_reduction = 10
	var prepared := rules.resolve_ability(_ability("enemy-2", "cultist_rite", "hero-3"), state, _rng(1))
	assert_eq(prepared.state.prepared.amount, 14)
	_at_cultist(prepared.state)
	var released := rules.resolve_prepared_strike(prepared.state, _rng(2))
	var hit := _damage(released)
	assert_eq(hit.ability_id, "cultist_rite")
	assert_eq(hit.listed_amount, 11)
	assert_eq(hit.amount, 0)
	assert_eq(hit.mitigation, CombatEvent.Mitigation.BLOCK_AND_GUARD)
	assert_eq(_find(released.state, "hero-3").guard_reduction, 0)


func test_tincture_turns_14_into_8_and_leaves_physical_damage_alone() -> void:
	var state := _battle()
	var plain := rules.strike_outcome(_find(state, "enemy-2"), _find(state, "hero-3"), _rite(), 0)
	assert_eq(plain.listed[0], 14)
	var warded := _grant(state)
	var cultist := _find(warded, "enemy-2")
	var doctor := _find(warded, "hero-3")
	var special := rules.strike_outcome(cultist, doctor, _rite(), 0)
	assert_eq(special.listed[0], 8)
	assert_eq(special.hit_chance, 100)
	assert_eq(special.block_chance, 0)
	assert_true(special.guaranteed)
	var physical := rules.strike_outcome(cultist, doctor, AbilityCatalog.definition("cultist_basic"), 0)
	assert_eq(physical.listed[0], 3)


func test_tincture_applied_after_preparation_reduces_the_resolution() -> void:
	var state := _battle()
	var prepared := _prepare(state)
	assert_eq(prepared.state.prepared.amount, 11)
	assert_eq(prepared.events[0].kind, CombatEvent.Kind.PREPARED_STRIKE)
	assert_eq(prepared.events[0].amount, 11)
	var warded := _grant(prepared.state)
	_at_cultist(warded)
	var rng := _rng(9)
	var before := rng.state
	var result := rules.resolve_prepared_strike(warded, rng)
	assert_eq(_damage(result).amount, 8)
	assert_eq(_find(result.state, "hero-3").hp, 12)
	assert_eq(rng.state, before)
	assert_null(result.state.prepared)


func test_resolution_uses_current_knowledge_not_the_stored_number() -> void:
	var state := _battle()
	var prepared := _prepare(state)
	var cultist := _find(prepared.state, "enemy-2")
	cultist.knowledge = 3
	prepared.state.prepared.amount = 99
	var shown := rules.preview("enemy-2", RITE, "hero-3", prepared.state)
	_at_cultist(prepared.state)
	var result := rules.resolve_prepared_strike(prepared.state, _rng(1))
	assert_eq(shown.damage_on_hit, 11)
	assert_eq(_damage(result).amount, 11)


func test_a_tincture_that_expires_before_resolution_leaves_14() -> void:
	var state := _battle()
	state.turn_queue = ["enemy-2", "hero-1"]
	var prepared := _prepare(state)
	var warded := _grant(prepared.state)
	assert_false(_find(warded, "hero-3").effects[0].skips_next_tick)
	warded.turn_queue = ["hero-3", "hero-1"]
	var once := _basic(warded, "hero-3", "enemy-1")
	assert_eq(_find(once, "hero-3").effects[0].turns_left, 1)
	once.turn_queue = ["hero-3", "hero-1"]
	var twice := _basic(once, "hero-3", "enemy-1")
	assert_eq(_find(twice, "hero-3").effects.size(), 0)
	twice.turn_queue = ["enemy-2", "hero-1"]
	var result := rules.resolve_prepared_strike(twice, _rng(1))
	assert_eq(_damage(result).amount, 14)


func test_the_rite_resolves_on_the_cultists_next_own_turn() -> void:
	var state := _battle()
	state.turn_queue = ["enemy-2", "hero-1"]
	var prepared := _prepare(state)
	assert_eq(prepared.state.turn_queue[0], "hero-1")
	assert_not_null(prepared.state.prepared)
	var waited := _basic(prepared.state, "hero-1", "enemy-1")
	assert_not_null(waited.prepared)
	waited.turn_queue = ["enemy-2", "hero-1"]
	var result := rules.resolve_ability(_ability("enemy-2", "cultist_basic", "hero-1"), waited, _rng(1))
	assert_eq(_damage(result).ability_id, RITE)
	assert_eq(_damage(result).amount, 14)


func test_a_dead_target_cancels_the_rite_without_hitting_someone_else() -> void:
	var state := _battle()
	var prepared := _prepare(state)
	_find(prepared.state, "hero-3").hp = 0
	_at_cultist(prepared.state)
	var hunter_hp := _find(prepared.state, "hero-2").hp
	var result := EnemyAi.new(rules).take_turn(prepared.state, _rng(2))
	assert_true(result.accepted)
	assert_null(result.state.prepared)
	assert_eq(_find(result.state, "hero-2").hp, hunter_hp)
	assert_false(_dealt_rite(result))
	assert_null(_find(result.state, "hero-3"))


func test_the_cultists_death_clears_the_preparation() -> void:
	var state := _battle()
	var prepared := _prepare(state)
	_find(prepared.state, "enemy-2").hp = 0
	prepared.state.turn_queue = ["hero-1", "hero-2"]
	var result := _basic(prepared.state, "hero-1", "enemy-1")
	assert_null(result.prepared)
	assert_null(_find(result, "enemy-2"))


func test_moving_the_living_cultist_or_the_target_does_not_cancel_or_redirect() -> void:
	var state := _battle()
	var prepared := _prepare(state)
	prepared.state.turn_queue = ["enemy-1", "enemy-2"]
	var step := StepCommand.new()
	step.actor_id = "enemy-1"
	step.destination_position = 2
	var moved := rules.resolve(step, prepared.state, _rng(1))
	assert_true(moved.accepted)
	assert_eq(_find(moved.state, "enemy-2").position, 1)
	assert_eq(moved.state.prepared.target_id, "hero-3")
	moved.state.turn_queue = ["enemy-2", "hero-1"]
	var fired := rules.resolve_prepared_strike(moved.state, _rng(1))
	assert_eq(_damage(fired).amount, 14)
	assert_eq(_damage(fired).other_id, "hero-3")

	var again := _battle()
	var stored := _prepare(again)
	stored.state.turn_queue = ["hero-3", "enemy-2"]
	var swap := StepCommand.new()
	swap.actor_id = "hero-3"
	swap.destination_position = 2
	var swapped := rules.resolve(swap, stored.state, _rng(1))
	assert_true(swapped.accepted)
	assert_eq(_find(swapped.state, "hero-3").position, 2)
	assert_eq(_find(swapped.state, "hero-2").position, 3)
	swapped.state.turn_queue = ["enemy-2", "hero-1"]
	var result := rules.resolve_prepared_strike(swapped.state, _rng(1))
	assert_eq(_damage(result).other_id, "hero-3")
	assert_eq(_find(result.state, "hero-3").hp, 6)
	assert_eq(_find(result.state, "hero-2").hp, 20)


func test_rite_accepts_only_positions_2_to_4_against_heroes_3_to_4() -> void:
	var state := _battle()
	_find(state, "enemy-2").position = 1
	assert_eq(_rejection(state, "hero-3"), CombatResult.Rejection.ACTOR_OUT_OF_POSITION)
	_find(state, "enemy-2").position = 2
	assert_eq(_rejection(state, "hero-2"), CombatResult.Rejection.ILLEGAL_TARGET)
	_find(state, "hero-3").position = 4
	var accepted := _prepare(state)
	assert_true(accepted.accepted)
	assert_eq(accepted.state.prepared.target_id, "hero-3")


func test_cooldown_covers_the_release_and_the_following_own_turn() -> void:
	var state := _battle()
	_find(state, "enemy-2").ability_ids = [RITE, "cultist_basic"]
	var prepared := _prepare(state)
	assert_eq(int(_find(prepared.state, "enemy-2").cooldown_left[RITE]), 2)
	prepared.state.turn_queue = ["enemy-2", "hero-1"]
	var released := rules.resolve_prepared_strike(prepared.state, _rng(1))
	assert_eq(int(_find(released.state, "enemy-2").cooldown_left[RITE]), 1)
	released.state.turn_queue = ["enemy-2", "hero-1"]
	assert_eq(
		rules.validate_ability(_ability("enemy-2", RITE, "hero-3"), released.state),
		CombatResult.Rejection.ON_COOLDOWN
	)
	var ticked := _basic(released.state, "enemy-2", "hero-1")
	assert_eq(int(_find(ticked, "enemy-2").cooldown_left.get(RITE, 0)), 0)
	ticked.turn_queue = ["enemy-2", "hero-1"]
	assert_eq(rules.validate_ability(_ability("enemy-2", RITE, "hero-3"), ticked), CombatResult.Rejection.NONE)


func test_preview_and_ai_match_the_strike_and_do_not_write_or_roll() -> void:
	var state := _battle()
	var warded := _grant(state)
	var rng := _rng(3)
	var before_rng := rng.state
	var before_hp := _find(warded, "hero-3").hp
	var shown := rules.preview("enemy-2", RITE, "hero-3", warded)
	var outcome := rules.strike_outcome(_find(warded, "enemy-2"), _find(warded, "hero-3"), _rite(), 0)
	var chosen: Variant = EnemyUtility.new(rules).choose(warded)
	assert_eq(rng.state, before_rng)
	assert_eq(_find(warded, "hero-3").hp, before_hp)
	assert_eq(_find(warded, "hero-3").effects.size(), 1)
	assert_true(chosen is AbilityCommand)
	var command: AbilityCommand = chosen
	assert_eq(command.ability_id, RITE)
	assert_eq(shown.damage_on_hit, 8)
	assert_eq(shown.hit_chance, 100)
	assert_eq(shown.block_chance, 0)
	assert_eq(outcome.listed[0], shown.damage_on_hit)
	var prepared := _prepare(warded)
	prepared.state.prepared.amount = 99
	var stored := rules.preview("enemy-2", RITE, "hero-3", prepared.state)
	assert_eq(stored.damage_on_hit, 8)


func test_a_failed_prepared_strike_cancels_and_the_turn_continues() -> void:
	var state := _battle()
	var prepared := _prepare(state)
	_find(prepared.state, "enemy-2").knowledge = -1
	prepared.state.turn_queue = ["hero-1", "enemy-2"]
	var worn := rules.grant_effect(prepared.state, "enemy-2", "enemy-2", _mark("worn_mark", ActiveEffect.Kind.DODGE_POINTS, 10))
	assert_true(worn.accepted)
	assert_false(_effect_on(worn.state, "enemy-2", "worn_mark").skips_next_tick)
	worn.state.turn_queue = ["enemy-2", "hero-1"]
	var fresh := rules.grant_effect(worn.state, "enemy-2", "enemy-2", _mark("fresh_mark", ActiveEffect.Kind.BLOCK_POINTS, 5))
	var warded := rules.grant_effect(fresh.state, "hero-3", "hero-3", _tincture())
	var ready := warded.state
	var doctor_hp := _find(ready, "hero-3").hp
	assert_eq(int(_find(ready, "enemy-2").cooldown_left[RITE]), 2)
	assert_eq(_effect_on(ready, "enemy-2", "worn_mark").turns_left, 2)
	assert_true(_effect_on(ready, "enemy-2", "fresh_mark").skips_next_tick)
	assert_eq(_effect_on(ready, "hero-3", "resilience_tincture").turns_left, 2)
	var rng := _rng(6)
	var before := rng.state
	var result := rules.resolve_prepared_strike(ready, rng)
	var ai_rng := _rng(6)
	var by_ai := EnemyAi.new(rules).take_turn(ready, ai_rng)
	assert_true(result.accepted)
	assert_eq(result.rejection, CombatResult.Rejection.NONE)
	assert_true(by_ai.accepted)
	assert_not_same(result.state, ready)
	assert_eq(ready.prepared.target_id, "hero-3")
	assert_null(result.state.prepared)
	assert_null(by_ai.state.prepared)
	assert_eq(result.state.turn_queue[0], "hero-1")
	assert_eq(by_ai.state.turn_queue[0], "hero-1")
	assert_eq(_find(result.state, "hero-3").hp, doctor_hp)
	assert_eq(_find(by_ai.state, "hero-3").hp, doctor_hp)
	assert_eq(rng.state, before)
	assert_eq(ai_rng.state, before)
	assert_eq(result.events.size(), 1)
	assert_eq(result.events[0].kind, CombatEvent.Kind.PREPARED_STRIKE_CANCELLED)
	assert_eq(result.events[0].rejection, CombatResult.Rejection.CALCULATION_FAILED)
	assert_eq(result.events[0].ability_id, RITE)
	assert_eq(result.events[0].actor_id, "enemy-2")
	assert_eq(result.events[0].other_id, "hero-3")
	assert_eq(result.events[0].amount, 0)
	assert_eq(int(_find(result.state, "enemy-2").cooldown_left[RITE]), 1)
	assert_eq(int(_find(ready, "enemy-2").cooldown_left[RITE]), 2)
	assert_eq(_effect_on(result.state, "enemy-2", "worn_mark").turns_left, 1)
	assert_false(_effect_on(result.state, "enemy-2", "fresh_mark").skips_next_tick)
	assert_eq(_effect_on(result.state, "enemy-2", "fresh_mark").turns_left, 2)
	assert_eq(_effect_on(result.state, "hero-3", "resilience_tincture").turns_left, 2)
	var continued := _basic(result.state, "hero-1", "enemy-1")
	assert_eq(continued.outcome, CombatState.Outcome.ONGOING)
	assert_eq(continued.turn_queue[0], "hero-2")
	assert_null(continued.prepared)
	assert_push_error_count(2)


func _battle() -> CombatState:
	var state := BattleSetup.create_opening_battle()
	var cultist := _find(state, "enemy-2")
	cultist.knowledge = 6
	cultist.ability_ids = [RITE]
	state.turn_queue = ["enemy-2", "hero-3", "hero-1", "hero-2", "enemy-1", "enemy-3"]
	return state


func _at_cultist(state: CombatState) -> void:
	state.turn_queue = ["enemy-2", "hero-1"]


func _prepare(state: CombatState) -> CombatResult:
	var result := rules.resolve_ability(_ability("enemy-2", RITE, "hero-3"), state, _rng(1))
	assert_true(result.accepted)
	return result


func _grant(state: CombatState) -> CombatState:
	var result := rules.grant_effect(state, "hero-3", "hero-3", _tincture())
	assert_true(result.accepted)
	return result.state


func _basic(state: CombatState, actor_id: String, target_id: String) -> CombatState:
	var ability_id := "cultist_basic"
	if actor_id == "hero-3":
		ability_id = "doctor_basic"
	elif actor_id == "hero-1":
		ability_id = "warrior_basic"
	var result := rules.resolve_ability(_ability(actor_id, ability_id, target_id), state, _rng(1))
	assert_true(result.accepted, actor_id)
	return result.state


func _rejection(state: CombatState, target_id: String) -> CombatResult.Rejection:
	return rules.validate_ability(_ability("enemy-2", RITE, target_id), state)


func _damage(result: CombatResult) -> CombatEvent:
	for event: CombatEvent in result.events:
		if event.kind == CombatEvent.Kind.DAMAGE_APPLIED:
			return event
	assert_true(false, "no damage")
	return null


func _dealt_rite(result: CombatResult) -> bool:
	for event: CombatEvent in result.events:
		if event.ability_id == RITE and event.kind == CombatEvent.Kind.DAMAGE_APPLIED:
			return true
	return false


func _prepared_snapshot(state: CombatState) -> String:
	var prepared := state.prepared
	return "%s/%s/%s/%d|%s" % [
		prepared.actor_id,
		prepared.ability_id,
		prepared.target_id,
		prepared.amount,
		",".join(state.turn_queue),
	]


func _rite() -> AbilityDefinition:
	return AbilityCatalog.definition(RITE)


func _mark(effect_id: String, kind: ActiveEffect.Kind, magnitude: int) -> ActiveEffect:
	var effect := ActiveEffect.new()
	effect.effect_id = effect_id
	effect.kind = kind
	effect.magnitude = magnitude
	effect.turns_left = 2
	return effect


func _effect_on(state: CombatState, combatant_id: String, effect_id: String) -> ActiveEffect:
	for effect: ActiveEffect in _find(state, combatant_id).effects:
		if effect.effect_id == effect_id:
			return effect
	return null


func _tincture() -> ActiveEffect:
	var effect := ActiveEffect.new()
	effect.effect_id = "resilience_tincture"
	effect.kind = ActiveEffect.Kind.SPECIAL_RECEIVED_PERCENT
	effect.magnitude = -40
	effect.turns_left = 2
	return effect


func _dealt(magnitude: int) -> ActiveEffect:
	var effect := ActiveEffect.new()
	effect.effect_id = "stimulant"
	effect.kind = ActiveEffect.Kind.PHYSICAL_DEALT_PERCENT
	effect.magnitude = magnitude
	effect.turns_left = 2
	return effect


func _find(state: CombatState, combatant_id: String) -> CombatantState:
	for combatant: CombatantState in state.combatants:
		if combatant.id == combatant_id:
			return combatant
	return null


func _ability(actor_id: String, ability_id: String, target_id: String) -> AbilityCommand:
	var command := AbilityCommand.new()
	command.actor_id = actor_id
	command.ability_id = ability_id
	command.target_id = target_id
	return command


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng
