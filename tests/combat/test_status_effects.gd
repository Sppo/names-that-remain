extends GutTest

## Phase 4. Effects count the target's own turns, refresh without stacking, and feed CombatMath.
## No new ability is granted here: tests call CombatRules.grant_effect directly.


var rules: CombatRules


func before_each() -> void:
	rules = CombatRules.new()


func test_opening_battle_has_no_effects() -> void:
	for fighter: CombatantState in BattleSetup.create_opening_battle().combatants:
		assert_eq(fighter.effects.size(), 0, fighter.id)


func test_grant_copies_state_and_ignores_later_edits_of_the_template() -> void:
	var state := _pair()
	state.turn_queue = ["hero-1", "hero-2", "enemy-1"]
	var template := _effect("stance", ActiveEffect.Kind.BLOCK_POINTS, 50, 2)
	var granted := rules.grant_effect(state, "hero-1", "hero-1", template)
	assert_true(granted.accepted)
	assert_ne(granted.state, state)
	assert_eq(state.combatants[0].effects.size(), 0)
	assert_eq(granted.events.size(), 1)
	assert_eq(granted.events[0].kind, CombatEvent.Kind.EFFECT_APPLIED)
	assert_eq(granted.events[0].effect_id, "stance")
	assert_eq(granted.events[0].amount, 50)
	assert_eq(granted.events[0].resulting_hp, 2)
	template.magnitude = 1
	template.turns_left = 9
	var stored := _only(_find(granted.state, "hero-1"))
	assert_eq(stored.magnitude, 50)
	assert_eq(stored.turns_left, 2)
	assert_true(stored.skips_next_tick)


func test_invalid_grant_returns_the_same_state() -> void:
	var state := _pair()
	var missing := rules.grant_effect(state, "hero-1", "nobody", _effect("stance", ActiveEffect.Kind.BLOCK_POINTS, 50, 2))
	assert_eq(missing.rejection, CombatResult.Rejection.ILLEGAL_TARGET)
	assert_eq(missing.state, state)
	var blank := rules.grant_effect(state, "hero-1", "hero-1", _effect("", ActiveEffect.Kind.BLOCK_POINTS, 50, 2))
	assert_eq(blank.rejection, CombatResult.Rejection.INVALID_EFFECT)
	assert_eq(blank.state, state)
	var zero := rules.grant_effect(state, "hero-1", "hero-1", _effect("stance", ActiveEffect.Kind.BLOCK_POINTS, 50, 0))
	assert_eq(zero.rejection, CombatResult.Rejection.INVALID_EFFECT)
	var changed_kind := rules.grant_effect(state, "hero-1", "hero-1", _effect("stance", ActiveEffect.Kind.BLOCK_POINTS, 50, 2))
	var mismatch := rules.grant_effect(changed_kind.state, "hero-1", "hero-1", _effect("stance", ActiveEffect.Kind.DODGE_POINTS, 20, 2))
	assert_eq(mismatch.rejection, CombatResult.Rejection.INVALID_EFFECT)
	assert_eq(mismatch.state, changed_kind.state)
	state.outcome = CombatState.Outcome.HEROES_VICTORIOUS
	var finished := rules.grant_effect(state, "hero-1", "hero-1", _effect("stance", ActiveEffect.Kind.BLOCK_POINTS, 50, 2))
	assert_eq(finished.rejection, CombatResult.Rejection.BATTLE_FINISHED)
	assert_eq(finished.state, state)


func test_self_applied_effect_lasts_two_following_own_turns() -> void:
	var warrior := _fighter("hero-1", 1, 5, 22)
	warrior.block = 25
	var doctor := _fighter("hero-3", 3, 3, 20)
	var state := _ongoing([warrior, doctor, _enemy("enemy-1", 4, 16)])
	state.turn_queue = ["hero-1", "enemy-1", "hero-3"]
	var granted := rules.grant_effect(state, "hero-1", "hero-1", _effect("stance", ActiveEffect.Kind.BLOCK_POINTS, 50, 2))
	assert_true(_only(_find(granted.state, "hero-1")).skips_next_tick)
	var applied_turn := _act(granted.state, "hero-1", "enemy-1")
	var stance := _only(_find(applied_turn, "hero-1"))
	assert_eq(stance.turns_left, 2)
	assert_false(stance.skips_next_tick)
	assert_eq(_block_of(applied_turn, "hero-1"), 75)

	var after_others := _act(_act(applied_turn, "enemy-1", "hero-1"), "hero-3", "enemy-1")
	assert_eq(_only(_find(after_others, "hero-1")).turns_left, 2)

	var first := _act(after_others, "hero-1", "enemy-1")
	assert_eq(_only(_find(first, "hero-1")).turns_left, 1)
	assert_eq(_block_of(first, "hero-1"), 75)
	var between := _act(_act(first, "enemy-1", "hero-1"), "hero-3", "enemy-1")
	assert_eq(_only(_find(between, "hero-1")).turns_left, 1)

	var second := _turn(between, "hero-1", "enemy-1", 1)
	assert_eq(_find(second.state, "hero-1").effects.size(), 0)
	assert_eq(_block_of(second.state, "hero-1"), 25)
	assert_true(_expired(second, "stance"))


func test_effect_applied_before_the_targets_turn_ticks_on_that_turn() -> void:
	var doctor := _fighter("hero-3", 3, 3, 20)
	var hunter := _fighter("hero-2", 2, 8, 20)
	var guardian := _enemy("enemy-1", 4, 16)
	var state := _ongoing([doctor, hunter, guardian])
	state.turn_queue = ["hero-3", "enemy-1", "hero-2"]
	var granted := rules.grant_effect(
		state,
		"hero-3",
		"hero-2",
		_effect("stimulant", ActiveEffect.Kind.PHYSICAL_DEALT_PERCENT, 30, 2)
	)
	var stored := _only(_find(granted.state, "hero-2"))
	assert_false(stored.skips_next_tick)
	assert_eq(_shot_damage(granted.state), 7)

	var waiting := _act(_act(granted.state, "hero-3", "enemy-1"), "enemy-1", "hero-2")
	assert_eq(_only(_find(waiting, "hero-2")).turns_left, 2)
	var first := _act(waiting, "hero-2", "enemy-1")
	assert_eq(_only(_find(first, "hero-2")).turns_left, 1)
	assert_eq(_shot_damage(first), 7)
	var second := _turn(first, "hero-2", "enemy-1", 1)
	assert_eq(_find(second.state, "hero-2").effects.size(), 0)
	assert_eq(_shot_damage(second.state), 5)
	assert_true(_expired(second, "stimulant"))


func test_duration_of_one_applied_on_the_own_turn_is_not_spent_immediately() -> void:
	var warrior := _fighter("hero-1", 1, 5, 22)
	warrior.block = 25
	var state := _ongoing([warrior, _enemy("enemy-1", 4, 16)])
	state.turn_queue = ["hero-1", "enemy-1"]
	var granted := rules.grant_effect(state, "hero-1", "hero-1", _effect("stance", ActiveEffect.Kind.BLOCK_POINTS, 50, 1))
	var same_turn := _act(granted.state, "hero-1", "enemy-1")
	assert_eq(_only(_find(same_turn, "hero-1")).turns_left, 1)
	var next := _turn(_act(same_turn, "enemy-1", "hero-1"), "hero-1", "enemy-1", 1)
	assert_eq(_find(next.state, "hero-1").effects.size(), 0)
	assert_true(_expired(next, "stance"))


func test_same_effect_refreshes_duration_without_stacking() -> void:
	var state := _pair()
	var once := rules.grant_effect(state, "hero-3", "hero-2", _effect("stimulant", ActiveEffect.Kind.PHYSICAL_DEALT_PERCENT, 30, 2))
	var twice := rules.grant_effect(once.state, "hero-3", "hero-2", _effect("stimulant", ActiveEffect.Kind.PHYSICAL_DEALT_PERCENT, 30, 2))
	assert_eq(_find(twice.state, "hero-2").effects.size(), 1)
	assert_eq(_only(_find(twice.state, "hero-2")).magnitude, 30)
	assert_eq(_shot_damage(twice.state), 7)

	var reduced := rules.grant_effect(state, "hero-3", "hero-2", _effect("tincture", ActiveEffect.Kind.PHYSICAL_DEALT_PERCENT, -40, 2))
	var again := rules.grant_effect(reduced.state, "hero-3", "hero-2", _effect("tincture", ActiveEffect.Kind.PHYSICAL_DEALT_PERCENT, -40, 2))
	assert_eq(_only(_find(again.state, "hero-2")).magnitude, -40)
	assert_eq(_shot_damage(again.state), 3)


func test_refresh_during_the_own_turn_restarts_the_two_turns() -> void:
	var state := _trio()
	state.turn_queue = ["hero-3", "enemy-1", "hero-2"]
	var granted := rules.grant_effect(state, "hero-3", "hero-2", _effect("stimulant", ActiveEffect.Kind.PHYSICAL_DEALT_PERCENT, 30, 2))
	var ready := _act(_act(granted.state, "hero-3", "enemy-1"), "enemy-1", "hero-2")
	var after_first := _act(ready, "hero-2", "enemy-1")
	assert_eq(_only(_find(after_first, "hero-2")).turns_left, 1)
	var refreshed := rules.grant_effect(after_first, "hero-2", "hero-2", _effect("stimulant", ActiveEffect.Kind.PHYSICAL_DEALT_PERCENT, 30, 2))
	assert_eq(_only(_find(refreshed.state, "hero-2")).turns_left, 2)
	assert_true(_only(_find(refreshed.state, "hero-2")).skips_next_tick)
	var spent := _act(refreshed.state, "hero-2", "enemy-1")
	assert_eq(_only(_find(spent, "hero-2")).turns_left, 2)
	assert_eq(_shot_damage(spent), 7)


func test_weaker_repeat_does_not_displace_and_stronger_replaces() -> void:
	var state := _pair()
	state.turn_queue = ["hero-2", "hero-1", "enemy-1"]
	var strong := rules.grant_effect(state, "hero-1", "hero-1", _effect("stance", ActiveEffect.Kind.BLOCK_POINTS, 50, 2))
	var worn := _act(_act(strong.state, "hero-2", "enemy-1"), "hero-1", "enemy-1")
	assert_eq(_only(_find(worn, "hero-1")).turns_left, 1)
	var weaker := rules.grant_effect(worn, "hero-1", "hero-1", _effect("stance", ActiveEffect.Kind.BLOCK_POINTS, 20, 2))
	assert_true(weaker.accepted)
	assert_eq(weaker.events.size(), 0)
	assert_eq(_only(_find(weaker.state, "hero-1")).magnitude, 50)
	assert_eq(_only(_find(weaker.state, "hero-1")).turns_left, 1)
	assert_false(_only(_find(weaker.state, "hero-1")).skips_next_tick)

	var mild := rules.grant_effect(state, "hero-1", "hero-2", _effect("tincture", ActiveEffect.Kind.SPECIAL_RECEIVED_PERCENT, -20, 1))
	var deeper := rules.grant_effect(mild.state, "hero-3", "hero-2", _effect("tincture", ActiveEffect.Kind.SPECIAL_RECEIVED_PERCENT, -40, 2))
	assert_eq(_only(_find(deeper.state, "hero-2")).magnitude, -40)
	assert_eq(_only(_find(deeper.state, "hero-2")).turns_left, 2)
	var ignored := rules.grant_effect(deeper.state, "hero-3", "hero-2", _effect("tincture", ActiveEffect.Kind.SPECIAL_RECEIVED_PERCENT, -20, 2))
	assert_eq(ignored.events.size(), 0)
	assert_eq(_only(_find(ignored.state, "hero-2")).magnitude, -40)
	assert_eq(rules.special_received_multiplier_percent(_find(ignored.state, "hero-2")), 60)


func test_different_effects_add_inside_one_category_and_then_cap() -> void:
	var state := _pair()
	var first := rules.grant_effect(state, "hero-3", "hero-2", _effect("stimulant", ActiveEffect.Kind.PHYSICAL_DEALT_PERCENT, 30, 2))
	var second := rules.grant_effect(first.state, "hero-3", "hero-2", _effect("other-stimulant", ActiveEffect.Kind.PHYSICAL_DEALT_PERCENT, 30, 2))
	assert_eq(_find(second.state, "hero-2").effects.size(), 2)
	assert_eq(_shot_damage(second.state), 8)

	state.turn_queue = ["enemy-1", "hero-2", "hero-1"]
	var heavy := rules.grant_effect(state, "hero-3", "hero-2", _effect("a", ActiveEffect.Kind.PHYSICAL_DEALT_PERCENT, 80, 2))
	var capped := rules.grant_effect(heavy.state, "hero-3", "hero-2", _effect("b", ActiveEffect.Kind.PHYSICAL_DEALT_PERCENT, 40, 1))
	assert_eq(_shot_damage(capped.state), 10)
	var hunter_turn := _act(_act(capped.state, "enemy-1", "hero-1"), "hero-2", "enemy-1")
	assert_eq(_find(hunter_turn, "hero-2").effects.size(), 1)
	assert_eq(_only(_find(hunter_turn, "hero-2")).effect_id, "a")
	assert_eq(_shot_damage(hunter_turn), 9)

	var down := rules.grant_effect(state, "hero-3", "hero-2", _effect("cut", ActiveEffect.Kind.PHYSICAL_DEALT_PERCENT, -40, 2))
	var floored := rules.grant_effect(down.state, "hero-3", "hero-2", _effect("cut-more", ActiveEffect.Kind.PHYSICAL_DEALT_PERCENT, -30, 2))
	assert_eq(_shot_damage(floored.state), 2)


func test_block_points_and_the_cap_of_95() -> void:
	var warrior := _fighter("hero-1", 1, 5, 20)
	warrior.block = 25
	var state := _ongoing([warrior, _enemy("enemy-1", 4, 16)])
	state.turn_queue = ["enemy-1", "hero-1"]
	var stance := rules.grant_effect(state, "hero-1", "hero-1", _effect("stance", ActiveEffect.Kind.BLOCK_POINTS, 50, 2))
	assert_eq(_block_of(stance.state, "hero-1"), 75)
	warrior.block = 50
	var high := _ongoing([warrior, _enemy("enemy-1", 4, 16)])
	high.turn_queue = ["enemy-1", "hero-1"]
	var both := rules.grant_effect(high, "hero-1", "hero-1", _effect("stance", ActiveEffect.Kind.BLOCK_POINTS, 50, 2))
	var extra := rules.grant_effect(both.state, "hero-1", "hero-1", _effect("other-stance", ActiveEffect.Kind.BLOCK_POINTS, 50, 2))
	assert_eq(_block_of(extra.state, "hero-1"), 95)
	_find(extra.state, "hero-1").block = 100
	assert_eq(_block_of(extra.state, "hero-1"), 95)


func test_a_block_roll_of_95_succeeds_and_96_fails_under_the_cap() -> void:
	var state := _block_boundary_state()
	var guard := _find(state, "enemy-1")
	var warrior := _find(state, "hero-1")
	var outcome := rules.strike_outcome(guard, warrior, AbilityCatalog.definition("guardian_basic"), 0)
	assert_not_null(outcome)
	assert_eq(outcome.bases.size(), 1)
	assert_eq(outcome.hit_chance, 95)
	assert_eq(outcome.block_chance, 95)
	assert_gt(warrior.block, outcome.block_chance)
	assert_eq(outcome.on_hit[0], 3)
	assert_eq(outcome.if_blocked[0], 1)

	var seed_block := _seed_for_second_roll(outcome.hit_chance, 95)
	var seed_fail := _seed_for_second_roll(outcome.hit_chance, 96)
	assert_gt(seed_block, 0)
	assert_gt(seed_fail, 0)

	var blocked := _resolve_basic(state, seed_block)
	var unblocked := _resolve_basic(state, seed_fail)
	var blocked_hit := _damage_event(blocked)
	var open_hit := _damage_event(unblocked)
	assert_eq(blocked_hit.mitigation, CombatEvent.Mitigation.BLOCK)
	assert_eq(blocked_hit.amount, 1)
	assert_eq(_find(blocked.state, "hero-1").hp, 15)
	assert_eq(open_hit.mitigation, CombatEvent.Mitigation.NONE)
	assert_eq(open_hit.amount, 3)
	assert_eq(_find(unblocked.state, "hero-1").hp, 13)
	assert_eq(_rng_after_strike(seed_block), _rng_after_calls(seed_block, 2))
	assert_eq(_rng_after_strike(seed_fail), _rng_after_calls(seed_fail, 2))


func test_stored_block_above_95_is_capped_even_without_an_effect() -> void:
	var guard := _enemy("enemy-1", 4, 16)
	guard.block = 100
	var hunter := _fighter("hero-2", 2, 8, 20)
	var outcome := rules.strike_outcome(hunter, guard, AbilityCatalog.definition("hunter_shot"), 0)
	assert_eq(outcome.block_chance, 95)


func test_dodge_points_are_not_a_percent_of_dodge() -> void:
	var hunter := _fighter("hero-2", 2, 8, 20)
	hunter.dodge = 15
	var guard := _enemy("enemy-1", 4, 16)
	guard.accuracy = 75
	var plain := rules.strike_outcome(guard, hunter, AbilityCatalog.definition("guardian_basic"), 0)
	assert_eq(plain.hit_chance, 60)
	var state := _ongoing([hunter, guard])
	state.turn_queue = ["enemy-1", "hero-2"]
	var moved := rules.grant_effect(state, "hero-2", "hero-2", _effect("maneuver", ActiveEffect.Kind.DODGE_POINTS, 20, 2))
	var dodging := _find(moved.state, "hero-2")
	var boosted := rules.strike_outcome(_find(moved.state, "enemy-1"), dodging, AbilityCatalog.definition("guardian_basic"), 0)
	assert_eq(boosted.hit_chance, 40)


func test_special_received_does_not_change_a_physical_strike() -> void:
	var state := _pair()
	var granted := rules.grant_effect(
		state,
		"hero-3",
		"hero-2",
		_effect("tincture", ActiveEffect.Kind.SPECIAL_RECEIVED_PERCENT, -40, 2)
	)
	var hunter := _find(granted.state, "hero-2")
	assert_eq(rules.special_received_multiplier_percent(hunter), 60)
	assert_eq(_shot_damage(granted.state), 5)
	var second := rules.grant_effect(
		granted.state,
		"hero-3",
		"hero-2",
		_effect("ward", ActiveEffect.Kind.SPECIAL_RECEIVED_PERCENT, -30, 2)
	)
	assert_eq(rules.special_received_multiplier_percent(_find(second.state, "hero-2")), 40)
	assert_eq(_shot_damage(second.state), 5)


func test_a_negative_block_total_rejects_the_strike_before_any_roll() -> void:
	var state := _pair()
	var granted := rules.grant_effect(state, "hero-1", "enemy-1", _effect("hex", ActiveEffect.Kind.BLOCK_POINTS, -30, 2))
	var rng := _rng(2)
	var before := rng.state
	var result := rules.resolve_ability(_ability("hero-2", "hunter_shot", "enemy-1"), granted.state, rng)
	assert_eq(result.rejection, CombatResult.Rejection.CALCULATION_FAILED)
	assert_eq(result.state, granted.state)
	assert_eq(rng.state, before)
	assert_null(rules.strike_outcome(
		_find(granted.state, "hero-2"),
		_find(granted.state, "enemy-1"),
		AbilityCatalog.definition("hunter_shot"),
		0
	))
	assert_push_error_count(2)


func test_copy_is_isolated_and_death_drops_only_that_fighters_effects() -> void:
	var warrior := _fighter("hero-1", 1, 5, 22)
	var hunter := _fighter("hero-2", 2, 8, 20)
	var doctor := _fighter("hero-3", 3, 3, 20)
	var state := _ongoing([warrior, hunter, doctor, _enemy("enemy-1", 4, 16)])
	state.turn_queue = ["hero-3", "hero-2", "enemy-1"]
	var granted := rules.grant_effect(state, "hero-3", "hero-2", _effect("stimulant", ActiveEffect.Kind.PHYSICAL_DEALT_PERCENT, 30, 2))
	var also := rules.grant_effect(granted.state, "hero-3", "enemy-1", _effect("stance", ActiveEffect.Kind.BLOCK_POINTS, 50, 2))
	var passed := _act(also.state, "hero-3", "enemy-1")
	var copied := _only(_find(passed, "hero-2"))
	copied.magnitude = 999
	copied.skips_next_tick = true
	assert_eq(_only(_find(also.state, "hero-2")).magnitude, 30)
	assert_false(_only(_find(also.state, "hero-2")).skips_next_tick)

	_find(passed, "enemy-1").hp = 1
	var killed := _turn(passed, "hero-2", "enemy-1", 2)
	assert_null(_find(killed.state, "enemy-1"))
	assert_eq(_only(_find(killed.state, "hero-2")).effect_id, "stimulant")
	assert_false(_expired(killed, "stance"))


func test_preview_and_ai_read_effects_without_rolling_or_writing() -> void:
	var state := _pair()
	state.turn_queue = ["enemy-1", "hero-2"]
	var granted := rules.grant_effect(
		state,
		"hero-3",
		"enemy-1",
		_effect("stimulant", ActiveEffect.Kind.PHYSICAL_DEALT_PERCENT, 30, 2)
	)
	var enemy := _find(granted.state, "enemy-1")
	var basic := AbilityCatalog.definition("guardian_basic")
	var before_turns := _only(enemy).turns_left
	var rng := _rng(2)
	var untouched := rng.state
	var shown := rules.preview("enemy-1", "guardian_basic", "hero-2", granted.state)
	var outcome := rules.strike_outcome(enemy, _find(granted.state, "hero-2"), basic, 0)
	var utility := EnemyUtility.new(rules)
	var chosen: Variant = utility.choose(granted.state)
	assert_eq(rng.state, untouched)
	assert_eq(_only(enemy).turns_left, before_turns)
	assert_eq(_only(enemy).magnitude, 30)
	assert_ne(chosen, null)
	assert_eq(shown.damage_on_hit, outcome.on_hit[0])
	var scaled: Variant = rules.damage_before_armor_for(enemy, basic, basic.amount)
	assert_eq(outcome.listed[0], scaled)
	assert_eq(outcome.listed[0], 4)
	var plain: Variant = rules.damage_before_armor_for(_find(state, "enemy-1"), basic, basic.amount)
	assert_eq(plain, 3)


func test_an_active_effect_does_not_add_rng_calls() -> void:
	var plain_state := _pair()
	var boosted := rules.grant_effect(
		plain_state,
		"hero-3",
		"hero-2",
		_effect("stimulant", ActiveEffect.Kind.PHYSICAL_DEALT_PERCENT, 30, 2)
	)
	var plain_rng := _rng(2)
	var boosted_rng := _rng(2)
	var plain := rules.resolve_ability(_ability("hero-2", "hunter_shot", "enemy-1"), plain_state, plain_rng)
	var hit := rules.resolve_ability(_ability("hero-2", "hunter_shot", "enemy-1"), boosted.state, boosted_rng)
	assert_true(plain.accepted)
	assert_true(hit.accepted)
	assert_eq(plain.events[0].amount, 5)
	assert_eq(hit.events[0].amount, 7)
	assert_eq(plain_rng.state, boosted_rng.state)


func _block_boundary_state() -> CombatState:
	var guard := _enemy("enemy-1", 4, 16)
	guard.accuracy = 100
	var warrior := _fighter("hero-1", 1, 5, 16)
	warrior.block = 100
	var state := _ongoing([guard, warrior])
	state.turn_queue = ["enemy-1", "hero-1"]
	return state


func _resolve_basic(state: CombatState, seed_value: int) -> CombatResult:
	var result := rules.resolve_ability(_ability("enemy-1", "guardian_basic", "hero-1"), state, _rng(seed_value))
	assert_true(result.accepted)
	assert_eq(result.events.size(), 1)
	return result


func _damage_event(result: CombatResult) -> CombatEvent:
	var event := result.events[0]
	assert_eq(event.kind, CombatEvent.Kind.DAMAGE_APPLIED)
	return event


func _seed_for_second_roll(hit_chance: int, block_roll: int) -> int:
	for seed_value in range(1, 10001):
		var probe := _rng(seed_value)
		var hit := probe.randi_range(1, 100)
		var block := probe.randi_range(1, 100)
		if hit <= hit_chance and block == block_roll:
			return seed_value
	return -1


func _rng_after_strike(seed_value: int) -> int:
	var rng := _rng(seed_value)
	var result := rules.resolve_ability(
		_ability("enemy-1", "guardian_basic", "hero-1"),
		_block_boundary_state(),
		rng
	)
	assert_true(result.accepted)
	return rng.state


func _rng_after_calls(seed_value: int, calls: int) -> int:
	var rng := _rng(seed_value)
	for _index in calls:
		rng.randi_range(1, 100)
	return rng.state


func _shot_damage(state: CombatState) -> int:
	var outcome := rules.strike_outcome(
		_find(state, "hero-2"),
		_find(state, "enemy-1"),
		AbilityCatalog.definition("hunter_shot"),
		0
	)
	assert_not_null(outcome)
	return outcome.listed[0]


func _block_of(state: CombatState, fighter_id: String) -> int:
	var fighter := _find(state, fighter_id)
	var striker := _find(state, "enemy-1")
	var outcome := rules.strike_outcome(striker, fighter, AbilityCatalog.definition("guardian_basic"), 0)
	assert_not_null(outcome)
	return outcome.block_chance


func _act(state: CombatState, actor_id: String, target_id: String) -> CombatState:
	return _turn(state, actor_id, target_id, 1).state


func _turn(state: CombatState, actor_id: String, target_id: String, seed_value: int) -> CombatResult:
	var result := rules.resolve_ability(_ability(actor_id, _basic_for(actor_id), target_id), state, _rng(seed_value))
	assert_true(result.accepted, actor_id)
	return result


func _expired(result: CombatResult, effect_id: String) -> bool:
	for event: CombatEvent in result.events:
		if event.kind == CombatEvent.Kind.EFFECT_EXPIRED and event.effect_id == effect_id:
			return true
	return false


func _only(fighter: CombatantState) -> ActiveEffect:
	assert_eq(fighter.effects.size(), 1)
	return fighter.effects[0]


func _effect(effect_id: String, kind: ActiveEffect.Kind, magnitude: int, turns_left: int) -> ActiveEffect:
	var effect := ActiveEffect.new()
	effect.effect_id = effect_id
	effect.kind = kind
	effect.magnitude = magnitude
	effect.turns_left = turns_left
	return effect


func _pair() -> CombatState:
	var hunter := _fighter("hero-2", 2, 8, 20)
	var warrior := _fighter("hero-1", 1, 5, 22)
	warrior.block = 25
	var guardian := _enemy("enemy-1", 4, 16)
	var state := _ongoing([hunter, warrior, guardian])
	state.turn_queue = ["hero-2", "hero-1", "enemy-1"]
	return state


func _trio() -> CombatState:
	var warrior := _fighter("hero-1", 1, 5, 22)
	warrior.block = 25
	var hunter := _fighter("hero-2", 2, 8, 20)
	var doctor := _fighter("hero-3", 3, 3, 20)
	var guardian := _enemy("enemy-1", 4, 16)
	return _ongoing([warrior, hunter, doctor, guardian])


func _fighter(id: String, position: int, speed: int, hp: int) -> CombatantState:
	var fighter := CombatantState.new()
	fighter.id = id
	fighter.side = CombatantState.Side.HEROES
	fighter.position = position
	fighter.speed = speed
	fighter.hp = hp
	fighter.max_hp = hp
	fighter.accuracy = 100
	fighter.dodge = 0
	fighter.block = 0
	fighter.ability_ids = AbilityCatalog.ids_for(id)
	return fighter


func _enemy(id: String, speed: int, hp: int) -> CombatantState:
	var fighter := _fighter(id, 1, speed, hp)
	fighter.side = CombatantState.Side.ENEMIES
	fighter.max_hp = hp
	return fighter


func _ongoing(fighters: Array[CombatantState]) -> CombatState:
	var state := CombatState.new()
	state.round_number = 1
	state.outcome = CombatState.Outcome.ONGOING
	state.combatants = fighters
	state.turn_queue = []
	return state


func _find(state: CombatState, id: String) -> CombatantState:
	if state == null:
		return null
	for combatant: CombatantState in state.combatants:
		if combatant.id == id:
			return combatant
	return null


func _ability(actor_id: String, ability_id: String, target_id: String) -> AbilityCommand:
	var command := AbilityCommand.new()
	command.actor_id = actor_id
	command.ability_id = ability_id
	command.target_id = target_id
	return command


func _basic_for(actor_id: String) -> String:
	match actor_id:
		"hero-1":
			return "warrior_basic"
		"hero-2":
			return "hunter_basic"
		"hero-3":
			return "doctor_basic"
		_:
			return "guardian_basic"


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng
