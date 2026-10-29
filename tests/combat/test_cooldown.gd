extends GutTest

## Cooldown counts only the user's own later turns. Basic attacks stay ready and hit for less.


var rules: CombatRules


func before_each() -> void:
	rules = CombatRules.new()


func test_each_fighter_has_a_weaker_basic_attack() -> void:
	var basics := {
		"hero-1": "warrior_basic",
		"hero-2": "hunter_basic",
		"hero-3": "doctor_basic",
		"enemy-1": "guardian_basic",
		"enemy-2": "cultist_basic",
	}
	for fighter_id: String in basics:
		var basic_id: String = basics[fighter_id]
		var basic := AbilityCatalog.definition(basic_id)
		assert_eq(basic.cooldown_turns, 0)
		assert_eq(basic.kind, AbilityDefinition.Kind.STRIKE)
		assert_true(AbilityCatalog.ids_for(fighter_id).has(basic_id))
		if fighter_id == "hero-3":
			assert_eq(basic.amount, 2)
		else:
			assert_eq(basic.amount, 3)
		for ability_id: String in AbilityCatalog.ids_for(fighter_id):
			var ability := AbilityCatalog.definition(ability_id)
			assert_lte(ability.cooldown_turns, 2)
			if ability_id == basic_id:
				continue
			if ability.kind == AbilityDefinition.Kind.STRIKE:
				assert_gt(ability.amount, basic.amount)
	assert_eq(AbilityCatalog.definition("doctor_heal").cooldown_turns, 2)


func test_heal_cooldown_counts_only_the_doctors_turns() -> void:
	var doctor := _fighter("hero-3", 3, 9, 10)
	var warrior := _fighter("hero-1", 1, 1, 20)
	var guardian := _fighter("enemy-1", 1, 2, 16)
	guardian.side = CombatantState.Side.ENEMIES
	var state := _ongoing([doctor, warrior, guardian])
	state.turn_queue = ["hero-3", "enemy-1", "hero-1"]
	var healed := rules.resolve_ability(_ability("hero-3", "doctor_heal", "hero-1"), state, _rng(1))
	assert_true(healed.accepted)
	assert_eq(int(_find(healed.state, "hero-3").cooldown_left["doctor_heal"]), 2)

	var enemy := rules.resolve_ability(
		_ability("enemy-1", "guard_strike", "hero-1"),
		healed.state,
		_rng(1)
	)
	assert_eq(int(_find(enemy.state, "hero-3").cooldown_left["doctor_heal"]), 2)
	var warrior_turn := rules.resolve_ability(
		_ability("hero-1", "warrior_basic", "enemy-1"),
		enemy.state,
		_rng(1)
	)
	assert_eq(int(_find(warrior_turn.state, "hero-3").cooldown_left["doctor_heal"]), 2)

	var blocked := rules.validate_ability(
		_ability("hero-3", "doctor_heal", "hero-1"),
		warrior_turn.state
	)
	assert_eq(blocked, CombatResult.Rejection.ON_COOLDOWN)
	var first_poke := rules.resolve_ability(
		_ability("hero-3", "doctor_basic", "enemy-1"),
		warrior_turn.state,
		_rng(1)
	)
	assert_true(first_poke.accepted)
	assert_eq(int(_find(first_poke.state, "hero-3").cooldown_left["doctor_heal"]), 1)

	var after_enemy := _skip_to(first_poke.state, "hero-3")
	var second_poke := rules.resolve_ability(
		_ability("hero-3", "doctor_basic", "enemy-1"),
		after_enemy,
		_rng(1)
	)
	assert_true(second_poke.accepted)
	assert_false(_find(second_poke.state, "hero-3").cooldown_left.has("doctor_heal"))

	var ready := _skip_to(second_poke.state, "hero-3")
	var again := rules.resolve_ability(_ability("hero-3", "doctor_heal", "hero-1"), ready, _rng(1))
	assert_true(again.accepted)
	assert_eq(int(_find(again.state, "hero-3").cooldown_left["doctor_heal"]), 2)


func test_a_ready_rite_still_resolves_on_the_cultists_turn() -> void:
	var state := BattleSetup.create_opening_battle()
	var kept: Array[CombatantState] = []
	for combatant: CombatantState in state.combatants:
		if combatant.id != "hero-2":
			kept.append(combatant)
	state.combatants = kept
	state.turn_queue = ["enemy-2"]
	var declared := rules.resolve_ability(_ability("enemy-2", "cultist_rite", "hero-3"), state, _rng(2))
	assert_true(declared.accepted)
	assert_eq(int(_find(declared.state, "enemy-2").cooldown_left["cultist_rite"]), 2)
	assert_eq(declared.state.turn_queue[0], "enemy-2")
	var released := EnemyAi.new(rules).take_turn(declared.state, _rng(2))
	assert_true(released.accepted)
	assert_eq(released.events[0].ability_id, "cultist_rite")
	assert_eq(int(_find(released.state, "enemy-2").cooldown_left["cultist_rite"]), 1)


func _skip_to(state: CombatState, actor_id: String) -> CombatState:
	var guard := 0
	var current := state
	while current.turn_queue[0] != actor_id and guard < 8:
		var actor := _find(current, current.turn_queue[0])
		var command := _ability(actor.id, _basic_for(actor.id), _enemy_of(actor))
		var result := rules.resolve_ability(command, current, _rng(1))
		assert_true(result.accepted)
		current = result.state
		guard += 1
	assert_eq(current.turn_queue[0], actor_id)
	return current


func _basic_for(actor_id: String) -> String:
	match actor_id:
		"hero-1":
			return "warrior_basic"
		"hero-2":
			return "hunter_basic"
		"hero-3":
			return "doctor_basic"
		"enemy-1":
			return "guardian_basic"
		_:
			return "cultist_basic"


func _enemy_of(actor: CombatantState) -> String:
	if actor.side == CombatantState.Side.HEROES:
		return "enemy-1"
	return "hero-1"


func _fighter(id: String, position: int, speed: int, hp: int) -> CombatantState:
	var fighter := CombatantState.new()
	fighter.id = id
	fighter.side = CombatantState.Side.HEROES
	fighter.position = position
	fighter.speed = speed
	fighter.hp = hp
	fighter.max_hp = 20 if id.begins_with("hero") else hp
	fighter.accuracy = 100
	fighter.dodge = 0
	fighter.block = 0
	return fighter


func _ongoing(fighters: Array[CombatantState]) -> CombatState:
	var state := CombatState.new()
	state.round_number = 1
	state.outcome = CombatState.Outcome.ONGOING
	state.combatants = fighters
	state.turn_queue = []
	state.prepared = null
	return state


func _find(state: CombatState, id: String) -> CombatantState:
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


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng
