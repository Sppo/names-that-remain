extends GutTest

## Shadowclaw joins the opening 3v3. Execute's second number is chosen before block and cover.


var rules: CombatRules


func before_each() -> void:
	rules = CombatRules.new()


func test_opening_queue_gives_all_three_enemies_a_turn() -> void:
	var state := BattleSetup.create_opening_battle()
	assert_eq(state.turn_queue, ["hero-2", "enemy-2", "enemy-3", "hero-1", "enemy-1", "hero-3"])
	assert_eq(AbilityCatalog.ids_for("enemy-3"), ["shadowclaw_claws", "shadowclaw_execute"])
	var claws := AbilityCatalog.definition("shadowclaw_claws")
	var execute := AbilityCatalog.definition("shadowclaw_execute")
	assert_eq(claws.amount, 5)
	assert_eq(claws.cooldown_turns, 0)
	assert_eq(claws.finish_amount, 0)
	assert_eq(execute.amount, 5)
	assert_eq(execute.finish_amount, 8)
	assert_eq(execute.finish_below_percent, 50)
	assert_eq(execute.cooldown_turns, 2)
	assert_eq(AbilityCatalog.definition("guard_strike").amount, 5)
	assert_eq(AbilityCatalog.definition("cultist_rite").amount, 14)


func test_execute_uses_eight_only_at_half_health_or_below() -> void:
	var above := _duel(11)
	var at_half := _duel(10)
	var below := _duel(9)
	assert_eq(rules.preview("enemy-3", "shadowclaw_execute", "hero-1", above).damage_on_hit, 5)
	assert_eq(rules.preview("enemy-3", "shadowclaw_execute", "hero-1", at_half).damage_on_hit, 8)
	assert_eq(rules.preview("enemy-3", "shadowclaw_execute", "hero-1", below).damage_on_hit, 8)
	assert_eq(rules.preview("enemy-3", "shadowclaw_claws", "hero-1", below).damage_on_hit, 5)

	var healthy := rules.resolve_ability(_ability("enemy-3", "shadowclaw_execute", "hero-1"), _duel(20), _rng(2))
	assert_eq(healthy.events[0].listed_amount, 5)
	assert_eq(healthy.events[0].amount, 5)
	assert_eq(_find(healthy.state, "hero-1").hp, 15)
	assert_gt(_find(healthy.state, "hero-1").hp, 0)

	var wounded := rules.resolve_ability(_ability("enemy-3", "shadowclaw_execute", "hero-1"), _duel(10), _rng(2))
	assert_eq(wounded.events[0].listed_amount, 8)
	assert_eq(wounded.events[0].amount, 8)
	assert_eq(_find(wounded.state, "hero-1").hp, 2)


func test_block_and_cover_still_reduce_the_chosen_number() -> void:
	var blocked := _duel(10)
	_find(blocked, "hero-1").block = 100
	var blocked_hit := rules.resolve_ability(
		_ability("enemy-3", "shadowclaw_execute", "hero-1"),
		blocked,
		_rng(2)
	)
	assert_eq(blocked_hit.events[0].listed_amount, 8)
	assert_eq(blocked_hit.events[0].amount, 4)
	assert_eq(blocked_hit.events[0].mitigation, CombatEvent.Mitigation.BLOCK)
	assert_eq(_find(blocked_hit.state, "hero-1").hp, 6)

	var covered := _duel(10)
	_find(covered, "hero-1").guard_reduction = 10
	var covered_hit := rules.resolve_ability(
		_ability("enemy-3", "shadowclaw_execute", "hero-1"),
		covered,
		_rng(2)
	)
	assert_eq(covered_hit.events[0].listed_amount, 8)
	assert_eq(covered_hit.events[0].amount, 0)
	assert_eq(covered_hit.events[0].mitigation, CombatEvent.Mitigation.GUARD)
	assert_eq(_find(covered_hit.state, "hero-1").hp, 10)
	assert_eq(_find(covered_hit.state, "hero-1").guard_reduction, 0)

	var missed := _duel(10)
	_find(missed, "hero-1").guard_reduction = 10
	_find(missed, "enemy-3").accuracy = 0
	_find(missed, "hero-1").dodge = 100
	var miss := rules.resolve_ability(
		_ability("enemy-3", "shadowclaw_claws", "hero-1"),
		missed,
		_rng(1)
	)
	assert_eq(miss.events[0].kind, CombatEvent.Kind.MISSED)
	assert_eq(_find(miss.state, "hero-1").guard_reduction, 10)
	assert_eq(_find(miss.state, "hero-1").hp, 10)


func test_execute_cooldown_counts_only_shadowclaws_turns() -> void:
	var state := _duel(20)
	var used := rules.resolve_ability(_ability("enemy-3", "shadowclaw_execute", "hero-1"), state, _rng(2))
	assert_eq(int(_find(used.state, "enemy-3").cooldown_left["shadowclaw_execute"]), 2)
	var hero_turn := rules.resolve_ability(
		_ability("hero-1", "warrior_basic", "enemy-3"),
		used.state,
		_rng(2)
	)
	assert_eq(int(_find(hero_turn.state, "enemy-3").cooldown_left["shadowclaw_execute"]), 2)
	assert_eq(
		rules.validate_ability(_ability("enemy-3", "shadowclaw_execute", "hero-1"), hero_turn.state),
		CombatResult.Rejection.ON_COOLDOWN
	)
	var claws := rules.resolve_ability(
		_ability("enemy-3", "shadowclaw_claws", "hero-1"),
		hero_turn.state,
		_rng(2)
	)
	assert_true(claws.accepted)
	assert_eq(int(_find(claws.state, "enemy-3").cooldown_left["shadowclaw_execute"]), 1)


func test_ai_saves_execute_until_it_is_stronger() -> void:
	var full := _three_heroes()
	var opening: Variant = EnemyUtility.new(rules).choose(full)
	assert_true(opening is AbilityCommand)
	var claws := opening as AbilityCommand
	assert_eq(claws.ability_id, "shadowclaw_claws")
	assert_eq(rules.validate_ability(claws, full), CombatResult.Rejection.NONE)

	var wounded_hunter := _three_heroes()
	_find(wounded_hunter, "hero-2").hp = 8
	var finish: Variant = EnemyUtility.new(rules).choose(wounded_hunter)
	assert_true(finish is AbilityCommand)
	var execute := finish as AbilityCommand
	assert_eq(execute.ability_id, "shadowclaw_execute")
	assert_eq(execute.target_id, "hero-2")

	var slightly_hurt := _three_heroes()
	_find(slightly_hurt, "hero-2").hp = 15
	var still_claws: Variant = EnemyUtility.new(rules).choose(slightly_hurt)
	var command := still_claws as AbilityCommand
	assert_eq(command.ability_id, "shadowclaw_claws")
	assert_ne(command.target_id, "hero-2")


func test_guardian_may_cover_shadowclaw_and_the_side_ends_only_when_empty() -> void:
	var state := BattleSetup.create_opening_battle()
	state.turn_queue = ["enemy-1"]
	assert_eq(
		rules.validate_ability(_ability("enemy-1", "warrior_guard", "enemy-3"), state),
		CombatResult.Rejection.NONE
	)

	var one_down := _duel(20)
	var removed := rules.resolve_ability(_ability("hero-1", "warrior_basic", "enemy-3"), _almost_dead(one_down), _rng(2))
	assert_eq(removed.state.outcome, CombatState.Outcome.HEROES_VICTORIOUS)

	var heroes_fall := _duel(5)
	_find(heroes_fall, "hero-1").hp = 5
	var lost := rules.resolve_ability(_ability("enemy-3", "shadowclaw_claws", "hero-1"), heroes_fall, _rng(2))
	assert_eq(lost.events[0].listed_amount, 5)
	assert_eq(lost.events[0].amount, 5)
	assert_eq(lost.state.outcome, CombatState.Outcome.HEROES_DEFEATED)

	var crowded := BattleSetup.create_opening_battle()
	crowded.turn_queue = ["hero-2"]
	_find(crowded, "enemy-2").hp = 1
	var still_going := rules.resolve_ability(_ability("hero-2", "hunter_basic", "enemy-2"), crowded, _rng(2))
	assert_null(_find(still_going.state, "enemy-2"))
	assert_eq(still_going.state.outcome, CombatState.Outcome.ONGOING)
	assert_not_null(_find(still_going.state, "enemy-3"))
	assert_not_null(_find(still_going.state, "enemy-1"))


func _duel(hero_hp: int) -> CombatState:
	var hero := _fighter("hero-1", CombatantState.Side.HEROES, 1, 5, 20)
	hero.hp = hero_hp
	var claw := _fighter("enemy-3", CombatantState.Side.ENEMIES, 3, 6, 12)
	claw.accuracy = 100
	hero.dodge = 0
	hero.block = 0
	var state := _ongoing([claw, hero])
	state.turn_queue = ["enemy-3", "hero-1"]
	return state


func _almost_dead(state: CombatState) -> CombatState:
	_find(state, "enemy-3").hp = 1
	state.turn_queue = ["hero-1", "enemy-3"]
	return state


func _three_heroes() -> CombatState:
	var warrior := _fighter("hero-1", CombatantState.Side.HEROES, 1, 5, 20)
	warrior.accuracy = 80
	warrior.dodge = 10
	warrior.block = 25
	var hunter := _fighter("hero-2", CombatantState.Side.HEROES, 2, 8, 20)
	hunter.accuracy = 90
	hunter.dodge = 15
	hunter.block = 0
	var doctor := _fighter("hero-3", CombatantState.Side.HEROES, 3, 3, 20)
	doctor.accuracy = 70
	doctor.dodge = 5
	doctor.block = 0
	var claw := _fighter("enemy-3", CombatantState.Side.ENEMIES, 3, 6, 12)
	claw.accuracy = 85
	claw.dodge = 15
	claw.block = 0
	var state := _ongoing([warrior, hunter, doctor, claw])
	state.turn_queue = ["enemy-3", "hero-2", "hero-1", "hero-3"]
	return state


func _ongoing(fighters: Array) -> CombatState:
	var combatants: Array[CombatantState] = []
	for fighter: CombatantState in fighters:
		combatants.append(fighter)
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
	fighter.display_name = id
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


func _find(state: CombatState, id: String) -> CombatantState:
	for combatant: CombatantState in state.combatants:
		if combatant.id == id:
			return combatant
	return null


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng
