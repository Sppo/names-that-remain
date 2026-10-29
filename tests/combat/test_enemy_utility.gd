extends GutTest

## Utility scores from docs/COMBAT_SPEC.md, "Вибір дій ворогів".
## No new damage numbers. choose_action does not roll and does not write the state.

var rules: CombatRules


func before_each() -> void:
	rules = CombatRules.new()


func test_guard_has_the_same_cover_as_the_warrior() -> void:
	assert_eq(AbilityCatalog.ids_for("enemy-1"), ["guard_strike", "warrior_guard", "guardian_basic"])
	var cover := AbilityCatalog.definition("warrior_guard")
	assert_eq(cover.amount, 10)
	assert_eq(cover.kind, AbilityDefinition.Kind.GUARD)


func test_guard_covers_the_cultist_when_a_hero_can_remove_him() -> void:
	var state := _guard_and_cultist(5)
	var hunter := _find(state, "hero-2")
	var cultist := _find(state, "enemy-2")
	var shot := rules.preview("hero-2", "hunter_shot", "enemy-2", state)
	var strike := rules.preview("enemy-1", "guard_strike", "hero-2", state)
	assert_true(shot.damage_on_hit >= cultist.hp)
	assert_gt(hunter.hp, strike.damage_on_hit)
	assert_eq(
		rules.validate_ability(_ability("enemy-1", "guard_strike", "hero-2"), state),
		CombatResult.Rejection.NONE
	)

	var before := _picture(state)
	var chosen: Variant = EnemyAi.new(rules).choose_action(state)
	assert_eq(_picture(state), before)
	assert_true(chosen is AbilityCommand)
	var command := chosen as AbilityCommand
	assert_eq(command.actor_id, "enemy-1")
	assert_eq(command.ability_id, "warrior_guard")
	assert_eq(command.target_id, "enemy-2")
	assert_eq(rules.validate_ability(command, state), CombatResult.Rejection.NONE)
	assert_gt(cultist.hp, 0)


func test_guard_strikes_when_the_cultist_is_at_full_health() -> void:
	var state := _guard_and_cultist(10)
	assert_eq(_find(state, "enemy-2").hp, _find(state, "enemy-2").max_hp)
	var shot := rules.preview("hero-2", "hunter_shot", "enemy-2", state)
	assert_lt(shot.damage_on_hit, _find(state, "enemy-2").hp)

	var chosen: Variant = EnemyAi.new(rules).choose_action(state)
	assert_true(chosen is AbilityCommand)
	var command := chosen as AbilityCommand
	assert_eq(command.ability_id, "guard_strike")
	assert_eq(command.target_id, "hero-2")
	assert_eq(rules.validate_ability(command, state), CombatResult.Rejection.NONE)


func test_guard_does_not_cover_again_when_the_reserve_is_already_ten() -> void:
	var state := _guard_and_cultist(5)
	_find(state, "enemy-2").guard_reduction = 10
	var chosen: Variant = EnemyAi.new(rules).choose_action(state)
	assert_true(chosen is AbilityCommand)
	var command := chosen as AbilityCommand
	assert_eq(command.ability_id, "guard_strike")
	assert_ne(command.ability_id, "warrior_guard")
	assert_eq(rules.validate_ability(command, state), CombatResult.Rejection.NONE)
	assert_eq(_find(state, "enemy-2").guard_reduction, 10)


func test_chosen_command_always_validates() -> void:
	var samples: Array[CombatState] = [
		_guard_and_cultist(5),
		_guard_and_cultist(10),
		_cultist_opening(10),
		_cultist_opening(5),
		_guard_out_of_position(),
		_without_cultist(),
	]
	var guarded := _guard_and_cultist(5)
	_find(guarded, "enemy-2").guard_reduction = 10
	samples.append(guarded)
	var ai := EnemyAi.new(rules)
	for index in samples.size():
		var state := samples[index]
		var chosen: Variant = ai.choose_action(state)
		assert_not_null(chosen, "sample %s" % index)
		_assert_command_is_legal(chosen, state)


func test_absent_ally_is_not_a_cover_target() -> void:
	var removed := _without_cultist()
	var removed_choice: Variant = EnemyAi.new(rules).choose_action(removed)
	_assert_command_is_legal(removed_choice, removed)
	_assert_target_is_not(removed_choice, "enemy-2")

	var listed := BattleSetup.create_opening_battle()
	_find(listed, "enemy-2").hp = 0
	listed.turn_queue = ["enemy-1", "hero-2", "hero-1", "hero-3"]
	var listed_choice: Variant = EnemyAi.new(rules).choose_action(listed)
	_assert_command_is_legal(listed_choice, listed)
	_assert_target_is_not(listed_choice, "enemy-2")
	assert_eq(_find(listed, "enemy-2").hp, 0)


func test_cultist_prepares_the_rite_until_heroes_can_remove_him() -> void:
	var full := _cultist_opening(10)
	assert_eq(_find(full, "enemy-2").hp, _find(full, "enemy-2").max_hp)
	var rite: Variant = EnemyAi.new(rules).choose_action(full)
	assert_true(rite is AbilityCommand)
	var rite_command := rite as AbilityCommand
	assert_eq(rite_command.ability_id, "cultist_rite")
	assert_eq(rite_command.target_id, "hero-3")
	assert_eq(rules.validate_ability(rite_command, full), CombatResult.Rejection.NONE)

	var wounded := _cultist_opening(5)
	var strike: Variant = EnemyAi.new(rules).choose_action(wounded)
	assert_true(strike is AbilityCommand)
	var strike_command := strike as AbilityCommand
	assert_eq(strike_command.ability_id, "cultist_arrow")
	assert_ne(strike_command.ability_id, "cultist_rite")
	assert_eq(rules.validate_ability(strike_command, wounded), CombatResult.Rejection.NONE)

	var ready := _cultist_opening(10)
	ready.prepared = _prepared("enemy-2", "cultist_rite", "hero-3", 14)
	var ai := EnemyAi.new(rules)
	assert_null(ai.choose_action(ready))
	var played := ai.take_turn(ready, _rng(2))
	assert_true(played.accepted)
	assert_eq(played.events[0].kind, CombatEvent.Kind.DAMAGE_APPLIED)
	assert_eq(played.events[0].ability_id, "cultist_rite")
	assert_eq(played.events[0].other_id, "hero-3")
	assert_null(played.state.prepared)
	assert_eq(ready.prepared.amount, 14)
	assert_eq(_find(ready, "hero-3").hp, 20)


func test_unavailable_position_and_foreign_ability_are_not_chosen() -> void:
	var rear := _guard_out_of_position()
	var chosen_rear: Variant = EnemyAi.new(rules).choose_action(rear)
	assert_true(chosen_rear is AbilityCommand)
	var basic := chosen_rear as AbilityCommand
	assert_eq(basic.actor_id, "enemy-1")
	assert_eq(basic.ability_id, "guardian_basic")
	assert_eq(rules.validate_ability(basic, rear), CombatResult.Rejection.NONE)
	assert_ne(
		rules.validate_ability(_ability("enemy-1", "guard_strike", "hero-1"), rear),
		CombatResult.Rejection.NONE
	)
	assert_ne(
		rules.validate_ability(_ability("enemy-1", "warrior_guard", "enemy-2"), rear),
		CombatResult.Rejection.NONE
	)

	var cultist := _cultist_opening(10)
	var chosen: Variant = EnemyAi.new(rules).choose_action(cultist)
	assert_true(chosen is AbilityCommand)
	var ability := chosen as AbilityCommand
	assert_true(AbilityCatalog.ids_for("enemy-2").has(ability.ability_id))
	assert_ne(ability.ability_id, "warrior_shield")
	assert_ne(ability.ability_id, "hunter_shot")
	assert_ne(ability.ability_id, "guard_strike")
	assert_eq(rules.validate_ability(ability, cultist), CombatResult.Rejection.NONE)


func test_same_state_chooses_the_same_command() -> void:
	var ai := EnemyAi.new(rules)
	var samples: Array[CombatState] = [
		_guard_and_cultist(5),
		_guard_and_cultist(10),
		_cultist_opening(10),
		_cultist_opening(5),
		_guard_out_of_position(),
	]
	for index in samples.size():
		var state := samples[index]
		var before := _picture(state)
		var first: Variant = ai.choose_action(state)
		var second: Variant = ai.choose_action(state)
		assert_eq(_command_text(first), _command_text(second), "sample %s" % index)
		assert_eq(_picture(state), before, "sample %s" % index)

	var striking := _guard_and_cultist(10)
	var before_strike := _picture(striking)
	var announced: Variant = ai.choose_action(striking)
	var after_announce := ai.take_turn(striking, _rng(2))
	var direct := ai.take_turn(striking, _rng(2))
	assert_eq(_picture(striking), before_strike)
	assert_eq(_command_text(announced), _command_text(ai.choose_action(striking)))
	assert_eq(_picture(after_announce.state), _picture(direct.state))
	assert_eq(_event_text(after_announce.events), _event_text(direct.events))

	var preparing := _cultist_opening(10)
	var first_rite := ai.take_turn(preparing, _rng(2))
	var second_rite := ai.take_turn(preparing, _rng(7))
	assert_eq(_picture(first_rite.state), _picture(second_rite.state))
	assert_eq(first_rite.events[0].kind, CombatEvent.Kind.PREPARED_STRIKE)
	assert_eq(_find(preparing, "hero-3").hp, 20)


func _guard_and_cultist(cultist_hp: int) -> CombatState:
	var state := _without(["hero-1", "hero-3"])
	_find(state, "enemy-2").hp = cultist_hp
	state.turn_queue = ["enemy-1", "hero-2", "enemy-2"]
	return state


func _cultist_opening(cultist_hp: int) -> CombatState:
	var state := BattleSetup.create_opening_battle()
	_find(state, "enemy-2").hp = cultist_hp
	state.turn_queue = ["enemy-2", "hero-1", "enemy-1", "hero-3"]
	return state


func _guard_out_of_position() -> CombatState:
	var state := BattleSetup.create_opening_battle()
	_find(state, "enemy-1").position = 4
	state.turn_queue = ["enemy-1", "hero-2", "hero-1", "enemy-2", "hero-3"]
	return state


func _without_cultist() -> CombatState:
	var state := _without(["enemy-2"])
	state.turn_queue = ["enemy-1", "hero-2", "hero-1", "hero-3"]
	return state


func _without(drop_ids: Array[String]) -> CombatState:
	var state := BattleSetup.create_opening_battle()
	var kept: Array[CombatantState] = []
	for index in state.combatants.size():
		var combatant: CombatantState = state.combatants[index]
		if not drop_ids.has(combatant.id):
			kept.append(combatant)
	state.combatants = kept
	return state


func _assert_command_is_legal(command: Variant, state: CombatState) -> void:
	if command is AbilityCommand:
		var ability := command as AbilityCommand
		assert_true(AbilityCatalog.ids_for(ability.actor_id).has(ability.ability_id))
		assert_eq(rules.validate_ability(ability, state), CombatResult.Rejection.NONE)
		return
	assert_true(command is StepCommand)
	assert_eq(rules.validate(command as StepCommand, state), CombatResult.Rejection.NONE)


func _assert_target_is_not(command: Variant, target_id: String) -> void:
	if command is AbilityCommand:
		assert_ne((command as AbilityCommand).target_id, target_id)


func _prepared(actor_id: String, ability_id: String, target_id: String, amount: int) -> PreparedStrike:
	var prepared := PreparedStrike.new()
	prepared.actor_id = actor_id
	prepared.ability_id = ability_id
	prepared.target_id = target_id
	prepared.amount = amount
	return prepared


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _ability(actor_id: String, ability_id: String, target_id: String) -> AbilityCommand:
	var command := AbilityCommand.new()
	command.actor_id = actor_id
	command.ability_id = ability_id
	command.target_id = target_id
	return command


func _find(state: CombatState, id: String) -> CombatantState:
	for index in state.combatants.size():
		var combatant: CombatantState = state.combatants[index]
		if combatant.id == id:
			return combatant
	return null


func _command_text(command: Variant) -> String:
	if command == null:
		return "null"
	if command is AbilityCommand:
		var ability := command as AbilityCommand
		return "%s:%s:%s" % [ability.actor_id, ability.ability_id, ability.target_id]
	var step := command as StepCommand
	return "step:%s:%s" % [step.actor_id, step.destination_position]


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
			combatant.position,
			combatant.hp,
			combatant.guard_reduction,
		])
	return rows


func _event_text(events: Array[CombatEvent]) -> Array:
	var rows: Array = []
	for index in events.size():
		var event: CombatEvent = events[index]
		rows.append([
			event.kind,
			event.actor_id,
			event.other_id,
			event.ability_id,
			event.amount,
			event.resulting_hp,
			event.mitigation,
		])
	return rows
