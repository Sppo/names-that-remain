extends GutTest

var rules: CombatRules
var rng: RandomNumberGenerator

## randi_range(1, 100) for seed 2 starts 51, 84, 19, 37.
## 51 hits a chance of 70 or more. 84 misses a 50% block and hits a 100% block.
## Seed 1 starts at 98, which misses a 5% chance.
const HIT_SEED := 2
const MISS_SEED := 1


func before_each() -> void:
	rules = CombatRules.new()
	rng = RandomNumberGenerator.new()
	# Seed 2 rolls 51, then 84, then 19. A 95% hit connects. A block of 0 does not.
	rng.seed = 2


func test_opening_battle_is_three_heroes_against_three_enemies() -> void:
	var state := BattleSetup.create_opening_battle()
	assert_eq(state.round_number, 1)
	assert_eq(state.outcome, CombatState.Outcome.ONGOING)
	assert_eq(state.combatants.size(), 6)
	assert_eq(state.turn_queue, ["hero-2", "enemy-2", "enemy-3", "hero-1", "enemy-1", "hero-3"])
	assert_eq(_find(state, "hero-2").speed, 8)
	assert_eq(_find(state, "hero-2").hp, 20)
	assert_eq(_find(state, "hero-2").max_hp, 20)
	assert_eq(_find(state, "enemy-2").speed, 7)
	assert_eq(_find(state, "enemy-2").hp, 10)
	assert_eq(_find(state, "enemy-2").max_hp, 10)
	assert_eq(_find(state, "hero-1").speed, 5)
	assert_eq(_find(state, "hero-1").hp, 20)
	assert_eq(_find(state, "enemy-1").speed, 4)
	assert_eq(_find(state, "enemy-1").hp, 16)
	assert_eq(_find(state, "enemy-1").max_hp, 16)
	assert_eq(_find(state, "hero-3").speed, 3)
	assert_eq(_find(state, "hero-3").hp, 20)
	assert_eq(_find(state, "hero-2").accuracy, 90)
	assert_eq(_find(state, "hero-2").dodge, 15)
	assert_eq(_find(state, "hero-2").block, 0)
	assert_eq(_find(state, "hero-1").accuracy, 80)
	assert_eq(_find(state, "hero-1").dodge, 10)
	assert_eq(_find(state, "hero-1").block, 25)
	assert_eq(_find(state, "hero-3").accuracy, 70)
	assert_eq(_find(state, "hero-3").dodge, 5)
	assert_eq(_find(state, "hero-3").block, 0)
	assert_eq(_find(state, "enemy-1").accuracy, 75)
	assert_eq(_find(state, "enemy-1").dodge, 10)
	assert_eq(_find(state, "enemy-1").block, 50)
	assert_eq(_find(state, "enemy-2").accuracy, 80)
	assert_eq(_find(state, "enemy-2").dodge, 20)
	assert_eq(_find(state, "enemy-2").block, 0)
	assert_eq(_find(state, "enemy-3").display_name, "Тіньокіготь")
	assert_eq(_find(state, "enemy-3").speed, 6)
	assert_eq(_find(state, "enemy-3").hp, 12)
	assert_eq(_find(state, "enemy-3").max_hp, 12)
	assert_eq(_find(state, "enemy-3").accuracy, 85)
	assert_eq(_find(state, "enemy-3").dodge, 15)
	assert_eq(_find(state, "enemy-3").block, 0)
	assert_null(state.prepared)
	assert_eq(AbilityCatalog.ids_for("hero-1"), ["warrior_shield", "warrior_guard", "warrior_basic"])
	assert_eq(AbilityCatalog.ids_for("enemy-2"), ["cultist_arrow", "cultist_rite", "cultist_basic"])

	assert_eq(_find(state, "hero-1").side, CombatantState.Side.HEROES)
	assert_eq(_find(state, "hero-1").position, 1)
	assert_eq(_find(state, "hero-2").position, 2)
	assert_eq(_find(state, "hero-3").position, 3)
	assert_eq(_find(state, "enemy-1").side, CombatantState.Side.ENEMIES)
	assert_eq(_find(state, "enemy-1").position, 1)
	assert_eq(_find(state, "enemy-2").position, 2)
	assert_eq(_find(state, "enemy-3").position, 3)
	assert_null(_occupant(state, CombatantState.Side.HEROES, 4))
	assert_null(_occupant(state, CombatantState.Side.ENEMIES, 4))


func test_rejected_command_does_not_change_state() -> void:
	_assert_rejected(_opening(), _step("missing", 1), CombatResult.Rejection.UNKNOWN_ACTOR)
	_assert_rejected(_opening(), _step("hero-1", 2), CombatResult.Rejection.NOT_ACTIVE_TURN)
	_assert_rejected(_opening(), _step("hero-2", 0), CombatResult.Rejection.POSITION_OUT_OF_RANGE)
	_assert_rejected(_opening(), _step("hero-2", 5), CombatResult.Rejection.POSITION_OUT_OF_RANGE)
	_assert_rejected(_opening(), _step("hero-2", 2), CombatResult.Rejection.NOT_ADJACENT)
	_assert_rejected(_opening(), _step("hero-2", 4), CombatResult.Rejection.NOT_ADJACENT)
	var finished := _opening()
	finished.outcome = CombatState.Outcome.HEROES_VICTORIOUS
	_assert_rejected(finished, _step("hero-2", 1), CombatResult.Rejection.BATTLE_FINISHED)


func test_step_into_empty_neighbor() -> void:
	var state := _ongoing([
		_fighter("hero-1", CombatantState.Side.HEROES, 1, 1, 5),
		_fighter("hero-2", CombatantState.Side.HEROES, 3, 1, 5),
		_fighter("enemy-1", CombatantState.Side.ENEMIES, 1, 1, 5),
	])
	var before := _picture(state)
	var result := rules.resolve(_step("hero-1", 2), state, rng)

	assert_true(result.accepted)
	assert_eq(result.rejection, CombatResult.Rejection.NONE)
	assert_eq(_picture(state), before)
	assert_not_same(result.state, state)
	assert_not_same(_find(result.state, "hero-1"), _find(state, "hero-1"))
	assert_eq(_find(result.state, "hero-1").position, 2)
	assert_eq(_find(result.state, "hero-2").position, 3)
	assert_eq(_find(result.state, "enemy-1").position, 1)
	assert_null(_occupant(result.state, CombatantState.Side.HEROES, 1))
	assert_eq(result.state.turn_queue, ["hero-2", "enemy-1"])
	assert_eq(result.state.round_number, 1)
	assert_eq(result.events.size(), 1)
	assert_eq(result.events[0].kind, CombatEvent.Kind.STEPPED)
	assert_eq(result.events[0].actor_id, "hero-1")
	assert_eq(result.events[0].from_position, 1)
	assert_eq(result.events[0].to_position, 2)
	assert_eq(_find(result.state, "hero-1").hp, 5)


func test_swap_with_ally_does_not_reorder_queue() -> void:
	var state := _ongoing([
		_fighter("hero-1", CombatantState.Side.HEROES, 1, 1, 5),
		_fighter("hero-2", CombatantState.Side.HEROES, 2, 1, 5),
		_fighter("hero-3", CombatantState.Side.HEROES, 4, 1, 5),
		_fighter("enemy-1", CombatantState.Side.ENEMIES, 1, 1, 5),
	])
	var before := _picture(state)
	var result := rules.resolve(_step("hero-1", 2), state, rng)

	assert_true(result.accepted)
	assert_eq(_picture(state), before)
	assert_not_same(result.state, state)
	assert_not_same(_find(result.state, "hero-1"), _find(state, "hero-1"))
	assert_not_same(_find(result.state, "hero-2"), _find(state, "hero-2"))
	assert_eq(_find(result.state, "hero-1").position, 2)
	assert_eq(_find(result.state, "hero-2").position, 1)
	assert_eq(_find(result.state, "hero-3").position, 4)
	assert_eq(_find(result.state, "enemy-1").position, 1)
	assert_eq(result.state.turn_queue, ["hero-2", "hero-3", "enemy-1"])
	assert_eq(result.state.round_number, 1)
	assert_eq(result.events.size(), 1)
	assert_eq(result.events[0].kind, CombatEvent.Kind.SWAPPED)
	assert_eq(result.events[0].actor_id, "hero-1")
	assert_eq(result.events[0].other_id, "hero-2")
	assert_eq(result.events[0].from_position, 1)
	assert_eq(result.events[0].to_position, 2)
	assert_eq(_find(state, "hero-1").position, 1)
	assert_eq(_find(state, "hero-2").position, 2)


func test_opening_active_step_swaps_with_the_ally_in_front() -> void:
	var state := _opening()
	var result := rules.resolve(_step("hero-2", 1), state, rng)
	assert_true(result.accepted)
	assert_eq(result.events[0].kind, CombatEvent.Kind.SWAPPED)
	assert_eq(_find(result.state, "hero-2").position, 1)
	assert_eq(_find(result.state, "hero-1").position, 2)
	assert_eq(_find(result.state, "hero-3").position, 3)
	assert_eq(_find(result.state, "enemy-1").position, 1)
	assert_eq(_find(result.state, "enemy-2").position, 2)
	assert_eq(result.state.turn_queue, ["enemy-2", "enemy-3", "hero-1", "enemy-1", "hero-3"])
	assert_eq(result.state.round_number, 1)
	assert_eq(_find(result.state, "hero-1").accuracy, 80)
	assert_eq(_find(result.state, "hero-1").block, 25)
	assert_eq(_find(result.state, "hero-2").dodge, 15)
	assert_eq(_find(result.state, "enemy-2").hp, 10)
	assert_null(result.state.prepared)


func test_hunter_shot_damages_any_living_enemy() -> void:
	var state := _opening()
	_reliable_hit(state, "hero-2", "enemy-1")
	var before := _picture(state)
	var result := rules.resolve_ability(_ability("hero-2", "hunter_shot", "enemy-1"), state, rng)

	assert_true(result.accepted)
	assert_eq(_picture(state), before)
	assert_not_same(result.state, state)
	assert_eq(_find(result.state, "enemy-1").hp, 11)
	assert_eq(_find(result.state, "enemy-1").position, 1)
	assert_eq(result.events.size(), 1)
	assert_eq(result.events[0].kind, CombatEvent.Kind.DAMAGE_APPLIED)
	assert_eq(result.events[0].actor_id, "hero-2")
	assert_eq(result.events[0].ability_id, "hunter_shot")
	assert_eq(result.events[0].other_id, "enemy-1")
	assert_eq(result.events[0].amount, 5)
	assert_eq(result.events[0].listed_amount, 5)
	assert_eq(result.events[0].mitigation, CombatEvent.Mitigation.NONE)
	assert_eq(result.events[0].resulting_hp, 11)
	assert_eq(result.state.turn_queue, ["enemy-2", "enemy-3", "hero-1", "enemy-1", "hero-3"])


func test_rejected_ability_does_not_change_state() -> void:
	_assert_rejected_ability(
		_opening(),
		_ability("hero-2", "hunter_shot", "missing"),
		CombatResult.Rejection.ILLEGAL_TARGET
	)
	_assert_rejected_ability(
		_opening(),
		_ability("hero-2", "hunter_shot", "hero-1"),
		CombatResult.Rejection.ILLEGAL_TARGET
	)
	_assert_rejected_ability(
		_opening(),
		_ability("hero-2", "missing_shot", "enemy-1"),
		CombatResult.Rejection.UNKNOWN_ABILITY
	)
	_assert_rejected_ability(
		_opening(),
		_ability("hero-1", "warrior_shield", "enemy-1"),
		CombatResult.Rejection.NOT_ACTIVE_TURN
	)
	var finished := _opening()
	finished.outcome = CombatState.Outcome.HEROES_VICTORIOUS
	_assert_rejected_ability(
		finished,
		_ability("hero-2", "hunter_shot", "enemy-1"),
		CombatResult.Rejection.BATTLE_FINISHED
	)


func test_hunter_knife_hits_front_ranks_from_the_opening_position() -> void:
	var state := _opening()
	_reliable_hit(state, "hero-2", "enemy-2")
	var result := rules.resolve_ability(_ability("hero-2", "hunter_knife", "enemy-2"), state, rng)
	assert_true(result.accepted)
	assert_eq(_find(result.state, "enemy-2").hp, 6)
	assert_eq(result.events[0].ability_id, "hunter_knife")
	assert_eq(result.events[0].amount, 4)
	assert_eq(result.events[0].listed_amount, 4)

	var rear := _ongoing([
		_fighter("hero-2", CombatantState.Side.HEROES, 2, 8, 20),
		_fighter("enemy-1", CombatantState.Side.ENEMIES, 3, 1, 16),
	])
	_assert_rejected_ability(
		rear,
		_ability("hero-2", "hunter_knife", "enemy-1"),
		CombatResult.Rejection.ILLEGAL_TARGET
	)


func test_doctor_cannot_heal_from_the_second_rank() -> void:
	var doctor := _fighter("hero-3", CombatantState.Side.HEROES, 2, 5, 20)
	var warrior := _fighter("hero-1", CombatantState.Side.HEROES, 1, 1, 10)
	warrior.max_hp = 20
	var state := _ongoing([
		doctor,
		warrior,
		_fighter("enemy-1", CombatantState.Side.ENEMIES, 1, 1, 16),
	])
	_assert_rejected_ability(
		state,
		_ability("hero-3", "doctor_heal", "hero-1"),
		CombatResult.Rejection.ACTOR_OUT_OF_POSITION
	)


func test_front_rank_closes_the_shot_and_keeps_the_knife() -> void:
	var moved := rules.resolve(_step("hero-2", 1), _opening(), rng)
	var state := moved.state
	_reliable_hit(state, "hero-2", "enemy-2")
	state.turn_queue = ["hero-2", "enemy-2", "hero-1", "enemy-1", "hero-3"]
	assert_eq(
		rules.validate_ability(_ability("hero-2", "hunter_shot", "enemy-1"), state),
		CombatResult.Rejection.ACTOR_OUT_OF_POSITION
	)
	var result := rules.resolve_ability(_ability("hero-2", "hunter_knife", "enemy-2"), state, rng)
	assert_true(result.accepted)
	assert_eq(_find(result.state, "enemy-2").hp, 6)
	assert_eq(result.events[0].ability_id, "hunter_knife")
	assert_eq(result.events[0].amount, 4)


func test_heal_stops_at_max_hp() -> void:
	var doctor := _fighter("hero-3", CombatantState.Side.HEROES, 3, 5, 12)
	doctor.max_hp = 20
	var warrior := _fighter("hero-1", CombatantState.Side.HEROES, 1, 1, 18)
	warrior.max_hp = 20
	var enemy := _fighter("enemy-1", CombatantState.Side.ENEMIES, 1, 1, 16)
	var state := _ongoing([doctor, warrior, enemy])
	var before := _picture(state)
	var result := rules.resolve_ability(_ability("hero-3", "doctor_heal", "hero-1"), state, rng)

	assert_true(result.accepted)
	assert_eq(_picture(state), before)
	assert_eq(_find(result.state, "hero-1").hp, 20)
	assert_eq(_find(result.state, "hero-3").hp, 12)
	assert_eq(result.events[0].kind, CombatEvent.Kind.HEALED)
	assert_eq(result.events[0].amount, 2)
	assert_eq(result.events[0].resulting_hp, 20)
	assert_eq(result.state.turn_queue, ["hero-1", "enemy-1"])


func test_full_heal_still_spends_the_turn() -> void:
	var doctor := _fighter("hero-3", CombatantState.Side.HEROES, 3, 5, 20)
	var enemy := _fighter("enemy-1", CombatantState.Side.ENEMIES, 1, 1, 16)
	var state := _ongoing([doctor, enemy])
	var result := rules.resolve_ability(_ability("hero-3", "doctor_heal", "hero-3"), state, rng)
	assert_true(result.accepted)
	assert_eq(_find(result.state, "hero-3").hp, 20)
	assert_eq(result.events[0].amount, 0)
	assert_eq(result.state.turn_queue, ["enemy-1"])


func test_killing_the_middle_does_not_pull_the_rear_forward() -> void:
	var warrior := _fighter("hero-1", CombatantState.Side.HEROES, 1, 9, 20)
	warrior.accuracy = 100
	var front := _fighter("enemy-1", CombatantState.Side.ENEMIES, 1, 1, 16)
	var middle := _fighter("enemy-2", CombatantState.Side.ENEMIES, 2, 1, 3)
	middle.dodge = 0
	middle.block = 0
	var rear := _fighter("enemy-3", CombatantState.Side.ENEMIES, 3, 1, 12)
	var state := _ongoing([warrior, front, middle, rear])
	state.turn_queue = ["hero-1", "enemy-1", "enemy-2", "enemy-3"]
	var result := rules.resolve_ability(_ability("hero-1", "warrior_basic", "enemy-2"), state, rng)
	assert_true(result.accepted)
	assert_null(_find(result.state, "enemy-2"))
	assert_eq(_find(result.state, "enemy-1").position, 1)
	assert_eq(_find(result.state, "enemy-3").position, 3)
	assert_null(_occupant(result.state, CombatantState.Side.ENEMIES, 2))
	for event: CombatEvent in result.events:
		assert_ne(event.kind, CombatEvent.Kind.FORMATION_SHIFTED)


func test_killing_blow_removes_the_target_and_leaves_the_gap() -> void:
	var warrior := _fighter("hero-1", CombatantState.Side.HEROES, 1, 9, 20)
	warrior.accuracy = 100
	var guard := _fighter("enemy-1", CombatantState.Side.ENEMIES, 1, 1, 6)
	guard.dodge = 0
	guard.block = 0
	var cultist := _fighter("enemy-2", CombatantState.Side.ENEMIES, 2, 1, 16)
	var state := _ongoing([warrior, guard, cultist])
	rng.seed = HIT_SEED
	var result := rules.resolve_ability(_ability("hero-1", "warrior_shield", "enemy-1"), state, rng)

	assert_true(result.accepted)
	assert_null(_find(result.state, "enemy-1"))
	assert_eq(_find(result.state, "enemy-2").position, 2)
	assert_null(_occupant(result.state, CombatantState.Side.ENEMIES, 1))
	assert_eq(result.state.outcome, CombatState.Outcome.ONGOING)
	assert_eq(result.events[0].kind, CombatEvent.Kind.DAMAGE_APPLIED)
	assert_eq(result.events[0].amount, 6)
	assert_eq(result.events[0].listed_amount, 6)
	assert_eq(result.events[0].mitigation, CombatEvent.Mitigation.NONE)
	assert_eq(result.events[0].resulting_hp, 0)
	assert_eq(result.events[1].kind, CombatEvent.Kind.REMOVED_FROM_BATTLE)
	assert_eq(result.events[1].actor_id, "enemy-1")
	assert_eq(result.events.size(), 2)
	assert_eq(result.state.turn_queue, ["enemy-2"])


func test_killing_the_last_enemy_ends_the_battle() -> void:
	var warrior := _fighter("hero-1", CombatantState.Side.HEROES, 1, 5, 20)
	warrior.accuracy = 100
	var guard := _fighter("enemy-1", CombatantState.Side.ENEMIES, 1, 1, 6)
	guard.dodge = 0
	guard.block = 0
	var state := _ongoing([warrior, guard])
	rng.seed = HIT_SEED
	var result := rules.resolve_ability(_ability("hero-1", "warrior_shield", "enemy-1"), state, rng)

	assert_true(result.accepted)
	assert_eq(result.state.outcome, CombatState.Outcome.HEROES_VICTORIOUS)
	assert_eq(result.state.turn_queue.size(), 0)
	assert_eq(result.state.round_number, 1)
	assert_eq(result.events.size(), 3)
	assert_eq(result.events[0].kind, CombatEvent.Kind.DAMAGE_APPLIED)
	assert_eq(result.events[0].amount, 6)
	assert_eq(result.events[0].listed_amount, 6)
	assert_eq(result.events[1].kind, CombatEvent.Kind.REMOVED_FROM_BATTLE)
	assert_eq(result.events[2].kind, CombatEvent.Kind.BATTLE_ENDED)
	assert_eq(result.events[2].outcome, CombatState.Outcome.HEROES_VICTORIOUS)


func test_cultist_arrow_misses_the_front_rank_and_hits_the_rear() -> void:
	var state := _opening()
	state.turn_queue = ["enemy-2", "hero-2", "hero-1", "enemy-1", "hero-3"]
	_reliable_hit(state, "enemy-2", "hero-3")
	_assert_rejected_ability(
		state,
		_ability("enemy-2", "cultist_arrow", "hero-1"),
		CombatResult.Rejection.ILLEGAL_TARGET
	)
	rng.seed = HIT_SEED
	var result := rules.resolve_ability(_ability("enemy-2", "cultist_arrow", "hero-3"), state, rng)
	assert_true(result.accepted)
	assert_eq(_find(result.state, "hero-3").hp, 16)
	assert_eq(result.events[0].ability_id, "cultist_arrow")
	assert_eq(result.events[0].amount, 4)


func test_enemy_ai_shoots_the_nearest_legal_hero() -> void:
	var state := _ongoing([
		_fighter("hero-1", CombatantState.Side.HEROES, 1, 5, 20),
		_fighter("hero-2", CombatantState.Side.HEROES, 2, 8, 20),
		_fighter("enemy-2", CombatantState.Side.ENEMIES, 2, 7, 10),
	])
	state.turn_queue = ["enemy-2", "hero-2", "hero-1"]
	var before := _picture(state)
	var result := EnemyAi.new(rules).take_turn(state, rng)
	assert_eq(_picture(state), before)
	assert_true(result.accepted)
	assert_eq(result.events[0].kind, CombatEvent.Kind.DAMAGE_APPLIED)
	assert_eq(result.events[0].actor_id, "enemy-2")
	assert_eq(result.events[0].ability_id, "cultist_arrow")
	assert_eq(result.events[0].other_id, "hero-2")
	assert_eq(result.events[0].amount, 4)
	assert_eq(_find(result.state, "hero-2").hp, 16)
	assert_eq(_find(result.state, "hero-1").hp, 20)


func test_enemy_steps_when_no_attack_is_legal() -> void:
	var state := _ongoing([
		_fighter("hero-1", CombatantState.Side.HEROES, 1, 1, 20),
		_fighter("enemy-2", CombatantState.Side.ENEMIES, 1, 7, 16),
	])
	var result := EnemyAi.new(rules).take_turn(state, rng)
	assert_true(result.accepted)
	assert_eq(result.events[0].kind, CombatEvent.Kind.DAMAGE_APPLIED)
	assert_eq(result.events[0].ability_id, "cultist_basic")
	assert_eq(_find(result.state, "enemy-2").position, 1)
	assert_eq(_find(result.state, "hero-1").hp, 17)


func test_queue_orders_higher_speed_first() -> void:
	var queue := rules.build_turn_queue(_fighters([
		_fighter("hero-1", CombatantState.Side.HEROES, 1, 1, 5),
		_fighter("enemy-1", CombatantState.Side.ENEMIES, 4, 9, 5),
		_fighter("hero-2", CombatantState.Side.HEROES, 2, 5, 5),
	]))
	assert_eq(queue, ["enemy-1", "hero-2", "hero-1"])


func test_tied_speed_heroes_act_before_enemies() -> void:
	var queue := rules.build_turn_queue(_fighters([
		_fighter("enemy-1", CombatantState.Side.ENEMIES, 1, 4, 5),
		_fighter("hero-1", CombatantState.Side.HEROES, 4, 4, 5),
	]))
	assert_eq(queue, ["hero-1", "enemy-1"])


func test_tied_speed_same_side_acts_front_to_back() -> void:
	var queue := rules.build_turn_queue(_fighters([
		_fighter("hero-2", CombatantState.Side.HEROES, 4, 3, 5),
		_fighter("hero-1", CombatantState.Side.HEROES, 2, 3, 5),
		_fighter("enemy-1", CombatantState.Side.ENEMIES, 1, 3, 5),
	]))
	assert_eq(queue, ["hero-1", "hero-2", "enemy-1"])


func test_empty_queue_starts_next_round() -> void:
	var state := _ongoing([
		_fighter("hero-1", CombatantState.Side.HEROES, 2, 5, 5),
		_fighter("hero-2", CombatantState.Side.HEROES, 3, 1, 5),
		_fighter("enemy-1", CombatantState.Side.ENEMIES, 1, 1, 5),
	])
	assert_eq(state.turn_queue, ["hero-1", "hero-2", "enemy-1"])

	var first := rules.resolve(_step("hero-1", 1), state, rng)
	assert_true(first.accepted)
	assert_eq(first.state.round_number, 1)
	assert_eq(first.state.turn_queue, ["hero-2", "enemy-1"])
	assert_eq(first.events.size(), 1)
	assert_eq(first.events[0].kind, CombatEvent.Kind.STEPPED)
	assert_eq(_find(first.state, "hero-1").position, 1)

	var second := rules.resolve(_step("hero-2", 4), first.state, rng)
	assert_true(second.accepted)
	assert_eq(second.state.round_number, 1)
	assert_eq(second.state.turn_queue, ["enemy-1"])
	assert_eq(second.events.size(), 1)

	var third := rules.resolve(_step("enemy-1", 2), second.state, rng)
	assert_true(third.accepted)
	assert_eq(third.state.round_number, 2)
	assert_eq(third.events.size(), 2)
	assert_eq(third.events[0].kind, CombatEvent.Kind.STEPPED)
	assert_eq(third.events[1].kind, CombatEvent.Kind.ROUND_STARTED)
	assert_eq(third.events[1].round_number, 2)
	assert_eq(_find(third.state, "hero-1").position, 1)
	assert_eq(_find(third.state, "hero-2").position, 4)
	assert_eq(_find(third.state, "enemy-1").position, 2)
	var expected_queue := rules.build_turn_queue(third.state.combatants)
	assert_eq(third.state.turn_queue, expected_queue)
	assert_eq(third.events[1].turn_queue, expected_queue)
	assert_eq(third.state.turn_queue, ["hero-1", "hero-2", "enemy-1"])


func test_zero_hp_leaves_the_gap_for_a_later_step() -> void:
	var state := _ongoing([
		_fighter("hero-1", CombatantState.Side.HEROES, 1, 1, 0),
		_fighter("hero-2", CombatantState.Side.HEROES, 2, 1, 5),
		_fighter("hero-3", CombatantState.Side.HEROES, 3, 1, 5),
		_fighter("enemy-1", CombatantState.Side.ENEMIES, 1, 1, 5),
		_fighter("enemy-2", CombatantState.Side.ENEMIES, 2, 1, 5),
	])
	var before := _picture(state)
	var result := rules.resolve(_step("hero-1", 2), state, rng)

	assert_true(result.accepted)
	assert_eq(_picture(state), before)
	assert_eq(_find(state, "hero-1").hp, 0)
	assert_eq(result.state.outcome, CombatState.Outcome.ONGOING)
	assert_null(_find(result.state, "hero-1"))
	assert_eq(_find(result.state, "hero-2").position, 2)
	assert_eq(_find(result.state, "hero-3").position, 3)
	assert_null(_occupant(result.state, CombatantState.Side.HEROES, 1))
	assert_eq(_find(result.state, "enemy-1").position, 1)
	assert_eq(_find(result.state, "enemy-2").position, 2)
	assert_eq(result.state.turn_queue, ["hero-2", "hero-3", "enemy-1", "enemy-2"])
	assert_eq(result.events.size(), 1)
	assert_eq(result.events[0].kind, CombatEvent.Kind.REMOVED_FROM_BATTLE)
	assert_eq(result.events[0].actor_id, "hero-1")
	assert_eq(result.events[0].side, CombatantState.Side.HEROES)
	assert_eq(result.events[0].from_position, 1)
	var approach := rules.resolve(_step("hero-2", 1), result.state, rng)
	assert_true(approach.accepted)
	assert_eq(approach.events[0].kind, CombatEvent.Kind.STEPPED)
	assert_eq(_find(approach.state, "hero-2").position, 1)
	assert_eq(_find(approach.state, "hero-3").position, 3)


func test_zero_hp_at_rear_emits_no_shift_when_others_keep_positions() -> void:
	var state := _ongoing([
		_fighter("hero-1", CombatantState.Side.HEROES, 1, 1, 5),
		_fighter("hero-2", CombatantState.Side.HEROES, 2, 1, 5),
		_fighter("hero-3", CombatantState.Side.HEROES, 3, 9, 0),
		_fighter("enemy-1", CombatantState.Side.ENEMIES, 1, 1, 5),
	])
	var result := rules.resolve(_step("hero-3", 4), state, rng)

	assert_true(result.accepted)
	assert_eq(result.events.size(), 1)
	assert_eq(result.events[0].kind, CombatEvent.Kind.REMOVED_FROM_BATTLE)
	assert_eq(result.events[0].actor_id, "hero-3")
	assert_eq(result.events[0].from_position, 3)
	assert_eq(_find(result.state, "hero-1").position, 1)
	assert_eq(_find(result.state, "hero-2").position, 2)
	assert_null(_find(result.state, "hero-3"))
	assert_eq(result.state.turn_queue, ["hero-1", "hero-2", "enemy-1"])
	assert_eq(result.state.outcome, CombatState.Outcome.ONGOING)


func test_living_actor_steps_after_another_fighter_hits_zero_hp() -> void:
	var state := _ongoing([
		_fighter("enemy-1", CombatantState.Side.ENEMIES, 2, 10, 5),
		_fighter("enemy-2", CombatantState.Side.ENEMIES, 4, 1, 5),
		_fighter("hero-1", CombatantState.Side.HEROES, 1, 1, 0),
		_fighter("hero-2", CombatantState.Side.HEROES, 2, 1, 5),
		_fighter("hero-3", CombatantState.Side.HEROES, 3, 1, 5),
	])
	var result := rules.resolve(_step("enemy-1", 1), state, rng)

	assert_true(result.accepted)
	assert_null(_find(result.state, "hero-1"))
	assert_eq(_find(result.state, "hero-2").position, 2)
	assert_eq(_find(result.state, "hero-3").position, 3)
	assert_eq(_find(result.state, "enemy-1").position, 1)
	assert_eq(_find(result.state, "enemy-2").position, 4)
	assert_eq(result.state.turn_queue, ["hero-2", "hero-3", "enemy-2"])
	assert_eq(result.events.size(), 2)
	assert_eq(result.events[0].kind, CombatEvent.Kind.REMOVED_FROM_BATTLE)
	assert_eq(result.events[1].kind, CombatEvent.Kind.STEPPED)
	assert_eq(result.events[1].actor_id, "enemy-1")
	assert_eq(result.events[1].from_position, 2)
	assert_eq(result.events[1].to_position, 1)


func test_invalid_command_does_not_remove_zero_hp() -> void:
	var state := _ongoing([
		_fighter("hero-1", CombatantState.Side.HEROES, 1, 1, 0),
		_fighter("hero-2", CombatantState.Side.HEROES, 2, 1, 5),
		_fighter("enemy-1", CombatantState.Side.ENEMIES, 1, 1, 5),
	])
	var before := _picture(state)
	var result := rules.resolve(_step("hero-2", 1), state, rng)

	assert_false(result.accepted)
	assert_eq(result.rejection, CombatResult.Rejection.NOT_ACTIVE_TURN)
	assert_same(result.state, state)
	assert_eq(result.events.size(), 0)
	assert_eq(_picture(state), before)
	assert_eq(_find(state, "hero-1").hp, 0)
	assert_eq(_find(state, "hero-1").position, 1)


func test_battle_ends_in_defeat_without_an_extra_step() -> void:
	var state := _ongoing([
		_fighter("hero-1", CombatantState.Side.HEROES, 1, 1, 0),
		_fighter("hero-2", CombatantState.Side.HEROES, 2, 1, 0),
		_fighter("enemy-1", CombatantState.Side.ENEMIES, 1, 1, 5),
	])
	var before := _picture(state)
	var result := rules.resolve(_step("hero-1", 2), state, rng)

	assert_true(result.accepted)
	assert_eq(_picture(state), before)
	assert_eq(result.state.outcome, CombatState.Outcome.HEROES_DEFEATED)
	assert_eq(result.state.turn_queue.size(), 0)
	assert_eq(result.state.combatants.size(), 1)
	assert_eq(_find(result.state, "enemy-1").position, 1)
	assert_eq(result.events.size(), 3)
	assert_eq(result.events[0].kind, CombatEvent.Kind.REMOVED_FROM_BATTLE)
	assert_eq(result.events[0].actor_id, "hero-1")
	assert_eq(result.events[0].from_position, 1)
	assert_eq(result.events[1].kind, CombatEvent.Kind.REMOVED_FROM_BATTLE)
	assert_eq(result.events[1].actor_id, "hero-2")
	assert_eq(result.events[1].from_position, 2)
	assert_eq(result.events[2].kind, CombatEvent.Kind.BATTLE_ENDED)
	assert_eq(result.events[2].outcome, CombatState.Outcome.HEROES_DEFEATED)
	_assert_no_step_or_shift(result.events)

	var follow := rules.resolve(_step("enemy-1", 2), result.state, rng)
	assert_false(follow.accepted)
	assert_eq(follow.rejection, CombatResult.Rejection.BATTLE_FINISHED)
	assert_same(follow.state, result.state)
	assert_eq(follow.events.size(), 0)
	assert_eq(result.state.outcome, CombatState.Outcome.HEROES_DEFEATED)
	assert_eq(_find(result.state, "enemy-1").position, 1)


func test_battle_ends_in_victory_without_an_extra_step() -> void:
	var state := _ongoing([
		_fighter("hero-1", CombatantState.Side.HEROES, 2, 1, 5),
		_fighter("enemy-1", CombatantState.Side.ENEMIES, 1, 1, 0),
		_fighter("enemy-2", CombatantState.Side.ENEMIES, 3, 1, 0),
	])
	var result := rules.resolve(_step("hero-1", 1), state, rng)

	assert_true(result.accepted)
	assert_eq(result.state.outcome, CombatState.Outcome.HEROES_VICTORIOUS)
	assert_eq(result.state.turn_queue.size(), 0)
	assert_eq(_find(result.state, "hero-1").position, 2)
	assert_null(_find(result.state, "enemy-1"))
	assert_null(_find(result.state, "enemy-2"))
	assert_eq(result.events.size(), 3)
	assert_eq(result.events[0].kind, CombatEvent.Kind.REMOVED_FROM_BATTLE)
	assert_eq(result.events[0].actor_id, "enemy-1")
	assert_eq(result.events[0].from_position, 1)
	assert_eq(result.events[1].kind, CombatEvent.Kind.REMOVED_FROM_BATTLE)
	assert_eq(result.events[1].actor_id, "enemy-2")
	assert_eq(result.events[1].from_position, 3)
	assert_eq(result.events[2].kind, CombatEvent.Kind.BATTLE_ENDED)
	assert_eq(result.events[2].outcome, CombatState.Outcome.HEROES_VICTORIOUS)
	_assert_no_step_or_shift(result.events)

	var follow := rules.resolve(_step("hero-1", 1), result.state, rng)
	assert_false(follow.accepted)
	assert_eq(follow.rejection, CombatResult.Rejection.BATTLE_FINISHED)
	assert_same(follow.state, result.state)
	assert_eq(_find(result.state, "hero-1").position, 2)


func test_enemy_ai_chooses_only_a_valid_step() -> void:
	var ai := EnemyAi.new(rules)
	rng.seed = HIT_SEED
	for position in [1, 2, 3, 4]:
		var hero := _fighter("hero-1", CombatantState.Side.HEROES, 1, 1, 5)
		hero.dodge = 0
		hero.block = 0
		var enemy := _fighter("enemy-1", CombatantState.Side.ENEMIES, position, 10, 5)
		enemy.accuracy = 100
		enemy.block = 0
		var state := _ongoing([hero, enemy])
		var before := _picture(state)
		var command := ai.choose_step(state)
		var slot: int = position
		var expected_destination: int = slot + 1
		if slot > CombatantState.FRONT_POSITION:
			expected_destination = slot - 1

		assert_eq(_picture(state), before, "position %s" % position)
		assert_eq(command.actor_id, "enemy-1")
		assert_eq(command.destination_position, expected_destination)
		assert_eq(rules.validate(command, state), CombatResult.Rejection.NONE, "position %s" % position)

		var via_ai := ai.take_turn(state, rng)
		assert_true(via_ai.accepted, "position %s" % position)
		if position <= 2:
			assert_eq(via_ai.events[0].kind, CombatEvent.Kind.DAMAGE_APPLIED)
			assert_eq(via_ai.events[0].ability_id, "guard_strike")
			assert_eq(via_ai.events[0].other_id, "hero-1")
			assert_eq(via_ai.state.outcome, CombatState.Outcome.HEROES_DEFEATED)
		else:
			assert_eq(via_ai.events[0].kind, CombatEvent.Kind.DAMAGE_APPLIED)
			assert_eq(via_ai.events[0].ability_id, "guardian_basic")
			assert_eq(via_ai.events[0].other_id, "hero-1")
			assert_eq(_find(via_ai.state, "enemy-1").position, position)
			assert_eq(_find(via_ai.state, "hero-1").hp, 2)


func test_same_seed_and_actions_produce_the_same_result() -> void:
	var first := _replay(42)
	var second := _replay(42)
	var other_seed := _replay(9001)
	assert_eq(first["state"], second["state"])
	assert_eq(first["events"], second["events"])
	assert_eq(first["state"], other_seed["state"])
	assert_eq(first["events"], other_seed["events"])
	assert_gt(first["rounds"], 1)


func test_miss_does_not_change_hp_or_guard() -> void:
	var hunter := _fighter("hero-2", CombatantState.Side.HEROES, 2, 8, 20)
	var guard := _fighter("enemy-1", CombatantState.Side.ENEMIES, 1, 4, 16)
	hunter.guard_reduction = 4
	guard.guard_reduction = 10
	var state := _ongoing([hunter, guard])
	var local := RandomNumberGenerator.new()
	# Seed 1 rolls 98 first, above the 95% hit cap.
	local.seed = 1
	assert_eq(rules.preview("hero-2", "hunter_shot", "enemy-1", state).hit_chance, 95)
	var before := _picture(state)
	var result := rules.resolve_ability(_ability("hero-2", "hunter_shot", "enemy-1"), state, local)

	assert_true(result.accepted)
	assert_eq(_picture(state), before)
	assert_eq(result.events.size(), 1)
	assert_eq(result.events[0].kind, CombatEvent.Kind.MISSED)
	assert_eq(result.events[0].actor_id, "hero-2")
	assert_eq(result.events[0].ability_id, "hunter_shot")
	assert_eq(result.events[0].other_id, "enemy-1")
	assert_eq(_find(result.state, "enemy-1").hp, 16)
	assert_eq(_find(result.state, "enemy-1").guard_reduction, 10)
	assert_eq(_find(result.state, "hero-2").guard_reduction, 4)
	assert_eq(result.state.turn_queue, ["enemy-1"])


func test_block_halves_damage() -> void:
	var hunter := _fighter("hero-2", CombatantState.Side.HEROES, 2, 8, 20)
	var guard := _fighter("enemy-1", CombatantState.Side.ENEMIES, 1, 4, 16)
	guard.block = 100
	var state := _ongoing([hunter, guard])
	var before := _picture(state)
	var result := rules.resolve_ability(_ability("hero-2", "hunter_shot", "enemy-1"), state, rng)

	assert_true(result.accepted)
	assert_eq(_picture(state), before)
	assert_eq(result.events[0].kind, CombatEvent.Kind.DAMAGE_APPLIED)
	assert_eq(result.events[0].amount, 2)
	assert_eq(result.events[0].listed_amount, 5)
	assert_eq(result.events[0].mitigation, CombatEvent.Mitigation.BLOCK)
	assert_eq(result.events[0].resulting_hp, 14)
	assert_eq(_find(result.state, "enemy-1").hp, 14)
	assert_eq(_find(result.state, "enemy-1").guard_reduction, 0)


func test_guard_reduces_the_next_hit_by_ten_and_clears() -> void:
	var cover := AbilityCatalog.definition("warrior_guard")
	assert_eq(cover.label, "Прикрити")
	assert_eq(cover.amount, 10)
	assert_eq(cover.from_min, 1)
	assert_eq(cover.from_max, 2)
	assert_eq(cover.target_min, 1)
	assert_eq(cover.target_max, 4)
	assert_false(cover.hits_enemies)

	var warrior := _fighter("hero-1", CombatantState.Side.HEROES, 1, 5, 20)
	var doctor := _fighter("hero-3", CombatantState.Side.HEROES, 4, 3, 20)
	var cultist := _fighter("enemy-2", CombatantState.Side.ENEMIES, 2, 7, 10)
	warrior.guard_reduction = 7
	cultist.guard_reduction = 2
	var state := _ongoing([warrior, doctor, cultist])
	state.turn_queue = ["hero-1", "enemy-2", "hero-3"]
	assert_eq(
		rules.validate_ability(_ability("hero-1", "warrior_guard", "hero-1"), state),
		CombatResult.Rejection.NONE
	)
	assert_eq(
		rules.validate_ability(_ability("hero-1", "warrior_guard", "enemy-2"), state),
		CombatResult.Rejection.ILLEGAL_TARGET
	)
	var placed := rules.resolve_ability(_ability("hero-1", "warrior_guard", "hero-3"), state, rng)

	assert_true(placed.accepted)
	assert_eq(placed.events.size(), 1)
	assert_eq(placed.events[0].kind, CombatEvent.Kind.GUARD_PLACED)
	assert_eq(placed.events[0].actor_id, "hero-1")
	assert_eq(placed.events[0].ability_id, "warrior_guard")
	assert_eq(placed.events[0].other_id, "hero-3")
	assert_eq(placed.events[0].amount, 10)
	assert_eq(_find(placed.state, "hero-3").guard_reduction, 10)
	assert_eq(_find(placed.state, "hero-1").guard_reduction, 0)
	assert_eq(_find(placed.state, "enemy-2").guard_reduction, 0)
	assert_eq(_find(placed.state, "hero-3").hp, 20)
	assert_eq(_find(placed.state, "hero-1").hp, 20)
	assert_eq(_find(state, "hero-3").guard_reduction, 0)
	assert_eq(int(_find(placed.state, "hero-1").cooldown_left["warrior_guard"]), 1)
	_find(placed.state, "hero-1").cooldown_left.erase("warrior_guard")

	placed.state.turn_queue = ["hero-1", "enemy-2", "hero-3"]
	var replaced := rules.resolve_ability(_ability("hero-1", "warrior_guard", "hero-1"), placed.state, rng)
	assert_true(replaced.accepted)
	assert_eq(replaced.events[0].other_id, "hero-1")
	assert_eq(_find(replaced.state, "hero-1").guard_reduction, 10)
	assert_eq(_find(replaced.state, "hero-3").guard_reduction, 0)
	assert_eq(_find(placed.state, "hero-3").guard_reduction, 10)

	var covered := placed.state
	covered.turn_queue = ["enemy-2", "hero-3"]
	covered.prepared = _prepared_strike("enemy-2", "cultist_rite", "hero-3", 14)
	var hit := rules.resolve_ability(_ability("enemy-2", "cultist_arrow", "hero-3"), covered, rng)
	assert_true(hit.accepted)
	assert_eq(hit.events[0].kind, CombatEvent.Kind.DAMAGE_APPLIED)
	assert_eq(hit.events[0].ability_id, "cultist_rite")
	assert_eq(hit.events[0].other_id, "hero-3")
	assert_eq(hit.events[0].amount, 4)
	assert_eq(hit.events[0].listed_amount, 14)
	assert_eq(hit.events[0].mitigation, CombatEvent.Mitigation.GUARD)
	assert_eq(_find(hit.state, "hero-3").hp, 16)
	assert_eq(_find(hit.state, "hero-3").guard_reduction, 0)
	assert_null(hit.state.prepared)
	assert_eq(covered.prepared.amount, 14)


func test_block_is_applied_before_guard() -> void:
	var cultist := _fighter("enemy-2", CombatantState.Side.ENEMIES, 2, 7, 10)
	var doctor := _fighter("hero-3", CombatantState.Side.HEROES, 4, 3, 20)
	doctor.block = 100
	doctor.guard_reduction = 10
	var state := _ongoing([cultist, doctor])
	state.turn_queue = ["enemy-2", "hero-3"]
	state.prepared = _prepared_strike("enemy-2", "cultist_rite", "hero-3", 14)
	var result := rules.resolve(_step("enemy-2", 3), state, rng)

	assert_true(result.accepted)
	assert_eq(result.events[0].kind, CombatEvent.Kind.DAMAGE_APPLIED)
	assert_eq(result.events[0].amount, 0)
	assert_eq(result.events[0].listed_amount, 14)
	assert_eq(result.events[0].mitigation, CombatEvent.Mitigation.BLOCK_AND_GUARD)
	assert_eq(_find(result.state, "hero-3").hp, 20)
	assert_eq(_find(result.state, "hero-3").guard_reduction, 0)
	assert_eq(_find(result.state, "enemy-2").position, 2)
	assert_null(result.state.prepared)


func test_rite_does_not_hit_until_the_cultists_next_turn() -> void:
	var rite := AbilityCatalog.definition("cultist_rite")
	assert_eq(rite.label, "Обряд")
	assert_eq(rite.amount, 14)
	assert_eq(rite.from_min, 2)
	assert_eq(rite.from_max, 4)
	assert_eq(rite.target_min, 3)
	assert_eq(rite.target_max, 4)

	var state := _ongoing([
		_fighter("hero-1", CombatantState.Side.HEROES, 1, 5, 20),
		_fighter("hero-3", CombatantState.Side.HEROES, 4, 3, 20),
		_fighter("enemy-2", CombatantState.Side.ENEMIES, 2, 7, 10),
	])
	state.turn_queue = ["enemy-2", "hero-1", "hero-3"]
	assert_eq(
		rules.validate_ability(_ability("enemy-2", "cultist_rite", "hero-1"), state),
		CombatResult.Rejection.ILLEGAL_TARGET
	)
	var before := _picture(state)
	var prepared_turn := rules.resolve_ability(_ability("enemy-2", "cultist_rite", "hero-3"), state, rng)

	assert_true(prepared_turn.accepted)
	assert_eq(_picture(state), before)
	assert_eq(prepared_turn.events.size(), 1)
	assert_eq(prepared_turn.events[0].kind, CombatEvent.Kind.PREPARED_STRIKE)
	assert_eq(prepared_turn.events[0].actor_id, "enemy-2")
	assert_eq(prepared_turn.events[0].ability_id, "cultist_rite")
	assert_eq(prepared_turn.events[0].other_id, "hero-3")
	assert_eq(prepared_turn.events[0].amount, 14)
	assert_eq(_find(prepared_turn.state, "hero-3").hp, 20)
	assert_eq(_find(prepared_turn.state, "enemy-2").hp, 10)
	assert_eq(prepared_turn.state.prepared.actor_id, "enemy-2")
	assert_eq(prepared_turn.state.prepared.ability_id, "cultist_rite")
	assert_eq(prepared_turn.state.prepared.target_id, "hero-3")
	assert_eq(prepared_turn.state.prepared.amount, 14)
	assert_null(state.prepared)
	assert_eq(prepared_turn.state.turn_queue, ["hero-1", "hero-3"])

	var warrior_step := rules.resolve(_step("hero-1", 2), prepared_turn.state, rng)
	assert_true(warrior_step.accepted)
	assert_eq(warrior_step.events[0].kind, CombatEvent.Kind.STEPPED)
	assert_not_same(warrior_step.state.prepared, prepared_turn.state.prepared)
	assert_eq(warrior_step.state.prepared.actor_id, "enemy-2")
	assert_eq(warrior_step.state.prepared.target_id, "hero-3")
	assert_eq(warrior_step.state.prepared.amount, 14)
	assert_eq(prepared_turn.state.prepared.amount, 14)
	assert_eq(_find(warrior_step.state, "hero-3").hp, 20)

	var doctor_step := rules.resolve(_step("hero-3", 3), warrior_step.state, rng)
	assert_true(doctor_step.accepted)
	assert_eq(doctor_step.state.round_number, 2)
	assert_eq(doctor_step.state.turn_queue[0], "enemy-2")
	assert_eq(doctor_step.state.prepared.amount, 14)
	assert_eq(_find(doctor_step.state, "hero-3").hp, 20)

	var fired := rules.resolve_ability(
		_ability("enemy-2", "cultist_arrow", "hero-1"),
		doctor_step.state,
		rng
	)
	assert_true(fired.accepted)
	assert_eq(fired.events[0].kind, CombatEvent.Kind.DAMAGE_APPLIED)
	assert_eq(fired.events[0].ability_id, "cultist_rite")
	assert_eq(fired.events[0].other_id, "hero-3")
	assert_eq(fired.events[0].amount, 14)
	assert_eq(fired.events[0].listed_amount, 14)
	assert_eq(fired.events[0].mitigation, CombatEvent.Mitigation.NONE)
	assert_eq(_find(fired.state, "hero-3").hp, 6)
	assert_eq(_find(fired.state, "hero-1").hp, 20)
	assert_eq(_find(fired.state, "enemy-2").position, 2)
	assert_null(fired.state.prepared)

	var via_step := rules.resolve(_step("enemy-2", 3), _cultist_ready_to_release(), _seeded(2))
	assert_true(via_step.accepted)
	assert_eq(via_step.events[0].kind, CombatEvent.Kind.DAMAGE_APPLIED)
	assert_eq(via_step.events[0].ability_id, "cultist_rite")
	assert_eq(via_step.events[0].amount, 14)
	assert_eq(_find(via_step.state, "enemy-2").position, 2)
	assert_eq(_find(via_step.state, "hero-3").hp, 6)
	assert_null(via_step.state.prepared)
	_assert_no_step_or_shift(via_step.events)

	var ai := EnemyAi.new(rules)
	var ready := _cultist_ready_to_release()
	assert_null(ai.choose_action(ready))
	var via_ai := ai.take_turn(ready, _seeded(2))
	assert_true(via_ai.accepted)
	assert_eq(via_ai.events[0].kind, CombatEvent.Kind.DAMAGE_APPLIED)
	assert_eq(via_ai.events[0].ability_id, "cultist_rite")
	assert_eq(via_ai.events[0].other_id, "hero-3")
	assert_eq(via_ai.events[0].amount, 14)
	assert_eq(_find(via_ai.state, "enemy-2").position, 2)
	assert_null(via_ai.state.prepared)


func test_cultist_death_clears_the_prepared_strike() -> void:
	var state := _ongoing([
		_fighter("hero-1", CombatantState.Side.HEROES, 1, 5, 20),
		_fighter("hero-3", CombatantState.Side.HEROES, 4, 3, 20),
		_fighter("enemy-1", CombatantState.Side.ENEMIES, 1, 1, 16),
		_fighter("enemy-2", CombatantState.Side.ENEMIES, 2, 7, 6),
	])
	state.turn_queue = ["hero-1", "enemy-2", "enemy-1", "hero-3"]
	state.prepared = _prepared_strike("enemy-2", "cultist_rite", "hero-3", 14)
	var result := rules.resolve_ability(_ability("hero-1", "warrior_shield", "enemy-2"), state, rng)

	assert_true(result.accepted)
	assert_null(_find(result.state, "enemy-2"))
	assert_null(result.state.prepared)
	assert_not_null(state.prepared)
	assert_eq(state.prepared.amount, 14)
	assert_eq(_find(result.state, "hero-3").hp, 20)
	assert_eq(_find(result.state, "enemy-1").position, 1)
	assert_eq(result.state.outcome, CombatState.Outcome.ONGOING)


func test_missing_rite_target_lets_the_cultist_act() -> void:
	var state := _ongoing([
		_fighter("hero-2", CombatantState.Side.HEROES, 2, 8, 20),
		_fighter("enemy-2", CombatantState.Side.ENEMIES, 2, 7, 10),
	])
	state.turn_queue = ["enemy-2", "hero-2"]
	state.prepared = _prepared_strike("enemy-2", "cultist_rite", "hero-3", 14)
	var ai := EnemyAi.new(rules)
	var chosen: Variant = ai.choose_action(state)
	assert_true(chosen is AbilityCommand)
	var arrow := chosen as AbilityCommand
	assert_eq(arrow.ability_id, "cultist_arrow")
	assert_eq(arrow.target_id, "hero-2")
	var result := rules.resolve_ability(arrow, state, rng)

	assert_true(result.accepted)
	assert_eq(result.events[0].kind, CombatEvent.Kind.DAMAGE_APPLIED)
	assert_eq(result.events[0].ability_id, "cultist_arrow")
	assert_eq(result.events[0].amount, 4)
	assert_eq(_find(result.state, "hero-2").hp, 16)
	assert_null(result.state.prepared)
	assert_not_null(state.prepared)


func test_enemy_does_not_return_an_illegal_command() -> void:
	var ai := EnemyAi.new(rules)
	var rite_state := _ongoing([
		_fighter("hero-1", CombatantState.Side.HEROES, 1, 1, 20),
		_fighter("hero-2", CombatantState.Side.HEROES, 2, 1, 20),
		_fighter("hero-3", CombatantState.Side.HEROES, 3, 1, 20),
		_fighter("rear-hero", CombatantState.Side.HEROES, 4, 1, 20),
		_fighter("enemy-2", CombatantState.Side.ENEMIES, 2, 10, 10),
	])
	rite_state.turn_queue = ["enemy-2"]
	var rite_command: Variant = ai.choose_action(rite_state)
	assert_true(rite_command is AbilityCommand)
	var rite_ability := rite_command as AbilityCommand
	assert_eq(rite_ability.ability_id, "cultist_rite")
	# Equal rite scores break toward the smaller target position.
	assert_eq(rite_ability.target_id, "hero-3")
	assert_eq(rules.validate_ability(rite_ability, rite_state), CombatResult.Rejection.NONE)

	var arrow_state := _ongoing([
		_fighter("hero-1", CombatantState.Side.HEROES, 1, 1, 20),
		_fighter("hero-2", CombatantState.Side.HEROES, 2, 1, 20),
		_fighter("enemy-2", CombatantState.Side.ENEMIES, 3, 10, 10),
	])
	arrow_state.turn_queue = ["enemy-2"]
	var arrow_command: Variant = ai.choose_action(arrow_state)
	assert_true(arrow_command is AbilityCommand)
	var arrow_ability := arrow_command as AbilityCommand
	assert_eq(arrow_ability.ability_id, "cultist_arrow")
	assert_eq(arrow_ability.target_id, "hero-2")
	assert_eq(rules.validate_ability(arrow_ability, arrow_state), CombatResult.Rejection.NONE)

	var step_state := _ongoing([
		_fighter("hero-1", CombatantState.Side.HEROES, 1, 1, 20),
		_fighter("enemy-2", CombatantState.Side.ENEMIES, 4, 10, 10),
	])
	step_state.turn_queue = ["enemy-2"]
	var basic_command: Variant = ai.choose_action(step_state)
	assert_true(basic_command is AbilityCommand)
	var basic := basic_command as AbilityCommand
	assert_eq(basic.ability_id, "cultist_basic")
	assert_eq(basic.target_id, "hero-1")
	assert_eq(rules.validate_ability(basic, step_state), CombatResult.Rejection.NONE)

	var guard_state := _ongoing([
		_fighter("hero-1", CombatantState.Side.HEROES, 2, 1, 20),
		_fighter("hero-2", CombatantState.Side.HEROES, 4, 1, 20),
		_fighter("enemy-1", CombatantState.Side.ENEMIES, 1, 10, 16),
	])
	guard_state.turn_queue = ["enemy-1"]
	var guard_command: Variant = ai.choose_action(guard_state)
	assert_true(guard_command is AbilityCommand)
	var strike := guard_command as AbilityCommand
	assert_eq(strike.ability_id, "guard_strike")
	assert_eq(strike.target_id, "hero-1")
	assert_eq(rules.validate_ability(strike, guard_state), CombatResult.Rejection.NONE)

	var prepared := _cultist_ready_to_release()
	assert_null(ai.choose_action(prepared))
	var played := ai.take_turn(prepared, rng)
	assert_true(played.accepted)
	assert_eq(played.events[0].kind, CombatEvent.Kind.DAMAGE_APPLIED)
	assert_eq(played.events[0].ability_id, "cultist_rite")
	assert_eq(played.events[0].other_id, "hero-3")
	assert_eq(played.events[0].amount, 14)
	assert_eq(_find(played.state, "enemy-2").position, 2)
	assert_null(played.state.prepared)
	_assert_no_step_or_shift(played.events)


func test_preview_does_not_roll_or_change_state() -> void:
	var state := _opening()
	var before := _picture(state)
	var shot := rules.preview("hero-2", "hunter_shot", "enemy-1", state)
	assert_eq(shot.hit_chance, 80)
	assert_eq(shot.block_chance, 50)
	assert_eq(shot.damage_on_hit, 5)
	assert_eq(shot.damage_if_blocked, 2)
	assert_eq(shot.guard_reduction, 0)
	assert_eq(_picture(state), before)

	_find(state, "enemy-1").guard_reduction = 10
	var covered := rules.preview("hero-2", "hunter_shot", "enemy-1", state)
	assert_eq(covered.hit_chance, 80)
	assert_eq(covered.block_chance, 50)
	assert_eq(covered.damage_on_hit, 0)
	assert_eq(covered.damage_if_blocked, 0)
	assert_eq(covered.guard_reduction, 10)
	assert_eq(_find(state, "enemy-1").hp, 16)
	assert_eq(_find(state, "enemy-1").guard_reduction, 10)

	var heal := rules.preview("hero-3", "doctor_heal", "hero-1", state)
	assert_eq(heal.hit_chance, 0)
	assert_eq(heal.damage_on_hit, 0)
	assert_eq(heal.damage_if_blocked, 0)
	var guard_preview := rules.preview("hero-1", "warrior_guard", "hero-3", state)
	assert_eq(guard_preview.hit_chance, 0)
	assert_eq(guard_preview.damage_on_hit, 0)
	var rite := rules.preview("enemy-2", "cultist_rite", "hero-3", state)
	assert_eq(rite.hit_chance, 0)
	assert_eq(rite.block_chance, 0)
	assert_eq(rite.damage_on_hit, 14)
	assert_eq(rite.damage_if_blocked, 0)
	var step_like := rules.preview("hero-2", "", "enemy-1", state)
	assert_eq(step_like.hit_chance, 0)
	assert_eq(step_like.damage_on_hit, 0)

	var low := _fighter("hero-2", CombatantState.Side.HEROES, 2, 8, 20)
	var dodger := _fighter("enemy-1", CombatantState.Side.ENEMIES, 1, 1, 16)
	low.accuracy = 0
	dodger.dodge = 100
	var clamped := _ongoing([low, dodger])
	assert_eq(rules.preview("hero-2", "hunter_shot", "enemy-1", clamped).hit_chance, 5)
	low.accuracy = 100
	dodger.dodge = 0
	assert_eq(rules.preview("hero-2", "hunter_shot", "enemy-1", clamped).hit_chance, 95)

	var left := _ongoing([
		_fighter("hero-2", CombatantState.Side.HEROES, 2, 8, 20),
		_fighter("enemy-1", CombatantState.Side.ENEMIES, 1, 1, 16),
	])
	var right := _ongoing([
		_fighter("hero-2", CombatantState.Side.HEROES, 2, 8, 20),
		_fighter("enemy-1", CombatantState.Side.ENEMIES, 1, 1, 16),
	])
	rules.preview("hero-2", "hunter_shot", "enemy-1", left)
	var with_preview := rules.resolve_ability(
		_ability("hero-2", "hunter_shot", "enemy-1"),
		left,
		_seeded(2)
	)
	var without_preview := rules.resolve_ability(
		_ability("hero-2", "hunter_shot", "enemy-1"),
		right,
		_seeded(2)
	)
	assert_eq(_picture(with_preview.state), _picture(without_preview.state))
	assert_eq(with_preview.events[0].amount, without_preview.events[0].amount)
	assert_eq(with_preview.events[0].kind, CombatEvent.Kind.DAMAGE_APPLIED)


func test_opening_hunter_against_the_guard_has_hit_chance_80() -> void:
	var state := _opening()
	var preview := rules.preview_attack(_ability("hero-2", "hunter_shot", "enemy-1"), state)
	assert_eq(preview.hit_chance, 80)
	assert_eq(preview.block_chance, 50)
	assert_eq(preview.damage_on_hit, 5)
	assert_eq(preview.damage_if_blocked, 2)


func test_cultist_ai_prepares_the_rite_on_the_doctor() -> void:
	var state := _opening()
	# Opening order after the hunter has acted. The next round still counts him once.
	state.turn_queue = ["enemy-2", "hero-1", "enemy-1", "hero-3"]
	var ai := EnemyAi.new(rules)
	assert_eq(
		rules.validate_ability(_ability("enemy-2", "cultist_rite", "hero-1"), state),
		CombatResult.Rejection.ILLEGAL_TARGET
	)
	assert_eq(
		rules.validate_ability(_ability("enemy-2", "cultist_arrow", "hero-1"), state),
		CombatResult.Rejection.ILLEGAL_TARGET
	)
	var chosen: Variant = ai.choose_action(state)
	assert_true(chosen is AbilityCommand)
	var command := chosen as AbilityCommand
	assert_eq(command.actor_id, "enemy-2")
	assert_eq(command.ability_id, "cultist_rite")
	assert_eq(command.target_id, "hero-3")
	assert_eq(rules.validate_ability(command, state), CombatResult.Rejection.NONE)

	var result := ai.take_turn(state, rng)
	assert_true(result.accepted)
	assert_eq(result.events[0].kind, CombatEvent.Kind.PREPARED_STRIKE)
	assert_eq(result.events[0].ability_id, "cultist_rite")
	assert_eq(result.events[0].other_id, "hero-3")
	assert_eq(result.events[0].amount, 14)
	assert_eq(_find(result.state, "hero-3").hp, 20)
	assert_eq(_find(result.state, "hero-1").hp, 20)
	assert_eq(result.state.prepared.target_id, "hero-3")
	for event: CombatEvent in result.events:
		assert_ne(event.kind, CombatEvent.Kind.DAMAGE_APPLIED)
		assert_ne(event.kind, CombatEvent.Kind.MISSED)


func _assert_rejected_ability(
	state: CombatState,
	command: AbilityCommand,
	rejection: CombatResult.Rejection
) -> void:
	var before := _picture(state)
	var result := rules.resolve_ability(command, state, rng)
	assert_false(result.accepted, str(rejection))
	assert_eq(result.rejection, rejection)
	assert_same(result.state, state)
	assert_eq(result.events.size(), 0)
	assert_eq(_picture(state), before)


func _assert_rejected(state: CombatState, command: StepCommand, rejection: CombatResult.Rejection) -> void:
	var before := _picture(state)
	var result := rules.resolve(command, state, rng)
	assert_false(result.accepted, str(rejection))
	assert_eq(result.rejection, rejection)
	assert_same(result.state, state)
	assert_eq(result.events.size(), 0)
	assert_eq(_picture(state), before)


func _assert_no_step_or_shift(events: Array[CombatEvent]) -> void:
	for index in events.size():
		var event: CombatEvent = events[index]
		assert_ne(event.kind, CombatEvent.Kind.STEPPED)
		assert_ne(event.kind, CombatEvent.Kind.SWAPPED)
		assert_ne(event.kind, CombatEvent.Kind.FORMATION_SHIFTED)
		assert_ne(event.kind, CombatEvent.Kind.ROUND_STARTED)


func _replay(seed_value: int) -> Dictionary:
	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = seed_value
	var state := BattleSetup.create_opening_battle()
	var events: Array = []
	for _step_index in 8:
		var command := _scripted_step(state)
		var result := rules.resolve(command, state, local_rng)
		assert_true(result.accepted)
		events.append_array(_event_picture(result.events))
		state = result.state
	return {
		"state": _picture(state),
		"events": events,
		"rounds": state.round_number,
	}


func _scripted_step(state: CombatState) -> StepCommand:
	var actor := _find(state, state.turn_queue[0])
	var destination := actor.position - 1
	if destination < CombatantState.FRONT_POSITION:
		destination = actor.position + 1
	return _step(actor.id, destination)


func _opening() -> CombatState:
	return BattleSetup.create_opening_battle()


func _reliable_hit(state: CombatState, attacker_id: String, target_id: String) -> void:
	var attacker := _find(state, attacker_id)
	var target := _find(state, target_id)
	attacker.accuracy = 100
	target.dodge = 0
	target.block = 0


func _prepared_strike(actor_id: String, ability_id: String, target_id: String, amount: int) -> PreparedStrike:
	var prepared := PreparedStrike.new()
	prepared.actor_id = actor_id
	prepared.ability_id = ability_id
	prepared.target_id = target_id
	prepared.amount = amount
	return prepared


func _cultist_ready_to_release() -> CombatState:
	var state := _ongoing([
		_fighter("hero-1", CombatantState.Side.HEROES, 1, 5, 20),
		_fighter("hero-3", CombatantState.Side.HEROES, 4, 3, 20),
		_fighter("enemy-2", CombatantState.Side.ENEMIES, 2, 7, 10),
	])
	state.turn_queue = ["enemy-2", "hero-1", "hero-3"]
	state.prepared = _prepared_strike("enemy-2", "cultist_rite", "hero-3", 14)
	return state


func _seeded(seed_value: int) -> RandomNumberGenerator:
	var seeded := RandomNumberGenerator.new()
	seeded.seed = seed_value
	return seeded


func _fighters(fighters: Array) -> Array[CombatantState]:
	var combatants: Array[CombatantState] = []
	for fighter in fighters:
		combatants.append(fighter)
	return combatants


func _ongoing(fighters: Array) -> CombatState:
	var combatants := _fighters(fighters)
	var state := CombatState.new()
	state.round_number = 1
	state.outcome = CombatState.Outcome.ONGOING
	state.combatants = combatants
	state.turn_queue = rules.build_turn_queue(combatants)
	return state


func _fighter(
	id: String,
	side: CombatantState.Side,
	position: int,
	speed: int,
	hp: int
) -> CombatantState:
	var fighter := CombatantState.new()
	fighter.id = id
	fighter.side = side
	fighter.position = position
	fighter.speed = speed
	fighter.hp = hp
	fighter.max_hp = hp
	fighter.accuracy = 100
	fighter.dodge = 0
	fighter.block = 0
	fighter.ability_ids = AbilityCatalog.ids_for(id)
	return fighter


func _ability(actor_id: String, ability_id: String, target_id: String) -> AbilityCommand:
	var command := AbilityCommand.new()
	command.actor_id = actor_id
	command.ability_id = ability_id
	command.target_id = target_id
	return command


func _step(actor_id: String, destination: int) -> StepCommand:
	var command := StepCommand.new()
	command.actor_id = actor_id
	command.destination_position = destination
	return command


func _find(state: CombatState, id: String) -> CombatantState:
	for index in state.combatants.size():
		var combatant: CombatantState = state.combatants[index]
		if combatant.id == id:
			return combatant
	return null


func _occupant(state: CombatState, side: CombatantState.Side, position: int) -> CombatantState:
	for index in state.combatants.size():
		var combatant: CombatantState = state.combatants[index]
		if combatant.side == side and combatant.position == position:
			return combatant
	return null


func _picture(state: CombatState) -> Array:
	var prepared: Array = []
	if state.prepared != null:
		prepared = [
			state.prepared.actor_id,
			state.prepared.ability_id,
			state.prepared.target_id,
			state.prepared.amount,
		]
	var rows: Array = [state.round_number, state.outcome, prepared]
	var queue: Array[String] = []
	queue.assign(state.turn_queue)
	rows.append(queue)
	for index in state.combatants.size():
		var combatant: CombatantState = state.combatants[index]
		rows.append([
			combatant.id,
			combatant.side,
			combatant.position,
			combatant.speed,
			combatant.hp,
			combatant.accuracy,
			combatant.dodge,
			combatant.block,
			combatant.guard_reduction,
		])
	return rows


func _event_picture(events: Array[CombatEvent]) -> Array:
	var picture: Array = []
	for index in events.size():
		var event: CombatEvent = events[index]
		var shifts: Array = []
		for shift_index in event.shifts.size():
			var shift: PositionShift = event.shifts[shift_index]
			shifts.append([shift.combatant_id, shift.from_position, shift.to_position])
		var queue: Array[String] = []
		queue.assign(event.turn_queue)
		picture.append([
			event.kind,
			event.actor_id,
			event.other_id,
			event.side,
			event.from_position,
			event.to_position,
			event.round_number,
			queue,
			event.outcome,
			shifts,
		])
	return picture
