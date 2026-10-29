extends GutTest

## Phase 1 data frame. New fields carry data only and leave the control battle unchanged.

const FIGHTER_IDS: Array[String] = ["hero-1", "hero-2", "hero-3", "enemy-1", "enemy-2", "enemy-3"]


var rules: CombatRules


func before_each() -> void:
	rules = CombatRules.new()


func test_control_fighters_keep_their_ability_lists() -> void:
	var state := BattleSetup.create_opening_battle()
	assert_eq(state.combatants.size(), FIGHTER_IDS.size())
	for index in state.combatants.size():
		var fighter: CombatantState = state.combatants[index]
		assert_eq(fighter.ability_ids, AbilityCatalog.ids_for(fighter.id))


func test_control_fighters_have_neutral_stats() -> void:
	var state := BattleSetup.create_opening_battle()
	for index in state.combatants.size():
		var fighter: CombatantState = state.combatants[index]
		assert_eq(fighter.strength, 3)
		assert_eq(fighter.armor, 0)
		assert_eq(fighter.dexterity, 3)
		assert_eq(fighter.knowledge, 3)
		assert_eq(fighter.health, 3)


func test_control_cards_keep_default_new_fields() -> void:
	var checked := 0
	for fighter_id: String in FIGHTER_IDS:
		for ability_id: String in AbilityCatalog.ids_for(fighter_id):
			var ability := AbilityCatalog.definition(ability_id)
			assert_eq(ability.damage_type, AbilityDefinition.DamageType.PHYSICAL)
			assert_eq(ability.base_min, 0)
			assert_eq(ability.base_max, 0)
			assert_eq(ability.strength_percent, 0)
			assert_eq(ability.dexterity_percent, 0)
			assert_eq(ability.knowledge_percent, 0)
			assert_eq(ability.multiplier_percent, 100)
			assert_eq(ability.accuracy_bonus, 0)
			assert_false(ability.guaranteed_hit)
			checked += 1
	# warrior_guard is listed for both the warrior and the guardian.
	assert_eq(checked, 16)


func test_ability_command_destination_starts_unused() -> void:
	assert_eq(AbilityCommand.new().destination_position, 0)


func test_accepted_command_copies_new_fields_into_a_new_state() -> void:
	var state := BattleSetup.create_opening_battle()
	var hunter := _find(state, "hero-2")
	hunter.strength = 3
	hunter.armor = 2
	hunter.dexterity = 6
	hunter.knowledge = 2
	hunter.health = 4

	var step := StepCommand.new()
	step.actor_id = "hero-2"
	step.destination_position = 3
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var result := rules.resolve(step, state, rng)
	assert_true(result.accepted)

	var copied := _find(result.state, "hero-2")
	assert_ne(copied, hunter)
	assert_eq(copied.strength, 3)
	assert_eq(copied.armor, 2)
	assert_eq(copied.dexterity, 6)
	assert_eq(copied.knowledge, 2)
	assert_eq(copied.health, 4)
	assert_eq(copied.ability_ids, hunter.ability_ids)

	copied.ability_ids.append("doctor_heal")
	assert_eq(hunter.ability_ids, AbilityCatalog.ids_for("hero-2"))


func test_ability_outside_the_fighters_list_is_rejected() -> void:
	var state := BattleSetup.create_opening_battle()
	var hunter := _find(state, "hero-2")
	hunter.ability_ids.erase("hunter_shot")
	var before_ids := hunter.ability_ids.duplicate()

	var command := AbilityCommand.new()
	command.actor_id = "hero-2"
	command.ability_id = "hunter_shot"
	command.target_id = "enemy-1"
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var rng_state := rng.state
	var result := rules.resolve_ability(command, state, rng)

	assert_false(result.accepted)
	assert_eq(result.rejection, CombatResult.Rejection.UNKNOWN_ABILITY)
	assert_eq(result.state, state)
	assert_true(result.events.is_empty())
	assert_eq(hunter.ability_ids, before_ids)
	assert_eq(rng.state, rng_state)


func _find(state: CombatState, combatant_id: String) -> CombatantState:
	for index in state.combatants.size():
		var combatant: CombatantState = state.combatants[index]
		if combatant.id == combatant_id:
			return combatant
	return null
