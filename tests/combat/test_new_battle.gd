extends GutTest

## Phase 8. The separate new-model 3 v 3 battle through the real rules, enemy AI and the test harness.
## A few seeds only: the long sweep lives in tests/simulation.

const Simulator = preload("res://tests/simulation/battle_simulator.gd")

var rules: CombatRules
var simulator


func before_each() -> void:
	rules = CombatRules.new()
	simulator = Simulator.new()


func _find(state: CombatState, id: String) -> CombatantState:
	for fighter: CombatantState in state.combatants:
		if fighter.id == id:
			return fighter
	return null


func _snapshot(state: CombatState) -> String:
	var lines := PackedStringArray()
	lines.append("round=%d outcome=%d queue=%s prepared=%s" % [state.round_number, state.outcome, ",".join(state.turn_queue), str(state.prepared)])
	for fighter: CombatantState in state.combatants:
		lines.append("%s %d %d %d %d/%d %d %d %d %d %s %d/%d/%d/%d/%d %s %d" % [
			fighter.id, fighter.side, fighter.position, fighter.speed, fighter.hp, fighter.max_hp, fighter.accuracy,
			fighter.dodge, fighter.block, fighter.guard_reduction, str(fighter.cooldown_left), fighter.strength,
			fighter.armor, fighter.dexterity, fighter.knowledge, fighter.health, ",".join(fighter.ability_ids), fighter.effects.size(),
		])
	return "\n".join(lines)


# --- Opening state -----------------------------------------------------------------


func test_opening_state_matches_the_approved_start() -> void:
	var state := BattleSetup.create_new_model_battle()
	assert_eq(state.round_number, 1)
	assert_eq(state.outcome, CombatState.Outcome.ONGOING)
	assert_null(state.prepared)
	# id, side, slot, speed, max hp, base accuracy, base dodge, block, STR/ARM/DEX/KNO/HEALTH, final accuracy, final dodge
	var rows: Array = [
		["warrior", CombatantState.Side.HEROES, 1, 5, 22, 80, 10, 25, [5, 5, 3, 2, 4], 80, 10],
		["hunter", CombatantState.Side.HEROES, 2, 8, 20, 84, 12, 0, [3, 2, 6, 2, 3], 90, 15],
		["medic", CombatantState.Side.HEROES, 3, 3, 20, 68, 4, 0, [2, 2, 4, 6, 3], 70, 5],
		["guardian", CombatantState.Side.ENEMIES, 1, 4, 20, 77, 11, 50, [4, 4, 2, 1, 5], 75, 10],
		["shadowclaw", CombatantState.Side.ENEMIES, 2, 6, 12, 77, 11, 0, [4, 1, 7, 1, 3], 85, 15],
		["cultist", CombatantState.Side.ENEMIES, 3, 7, 10, 78, 19, 0, [2, 1, 4, 6, 3], 80, 20],
	]
	assert_eq(state.combatants.size(), 6)
	for row: Array in rows:
		var fighter := _find(state, row[0])
		assert_not_null(fighter, row[0])
		assert_eq([fighter.side, fighter.position, fighter.speed], [row[1], row[2], row[3]], row[0])
		assert_eq([fighter.hp, fighter.max_hp], [row[4], row[4]], row[0])
		assert_eq([fighter.accuracy, fighter.dodge, fighter.block], [row[5], row[6], row[7]], row[0])
		assert_eq([fighter.strength, fighter.armor, fighter.dexterity, fighter.knowledge, fighter.health], row[8], row[0])
		assert_eq(CombatMath.accuracy_x100(fighter.accuracy, fighter.dexterity * 100, 0), row[9] * 100, row[0])
		assert_eq(CombatMath.dodge_x100(fighter.dodge, fighter.dexterity * 100, 0), row[10] * 100, row[0])
		assert_eq(fighter.guard_reduction, 0, row[0])
		assert_true(fighter.cooldown_left.is_empty(), row[0])
		assert_true(fighter.effects.is_empty(), row[0])
	# Nobody on slot 4.
	for fighter: CombatantState in state.combatants:
		assert_lt(fighter.position, 4, fighter.id)
	assert_eq(state.turn_queue, ["hunter", "cultist", "shadowclaw", "warrior", "guardian", "medic"])


func test_loadouts_are_the_approved_cards() -> void:
	var state := BattleSetup.create_new_model_battle()
	var wanted := {
		"warrior": ["warrior_sword", "warrior_guard", "warrior_shield_push", "warrior_battle_stance"],
		"hunter": ["hunter_bow_shot", "hunter_dagger", "hunter_aimed_shot", "hunter_maneuver"],
		"medic": ["medic_crossbow", "medic_healing", "medic_tincture", "medic_stimulant"],
		"guardian": ["guardian_shield_bash", "warrior_guard"],
		"shadowclaw": ["shadowclaw_claw_strike", "shadowclaw_finisher"],
		"cultist": ["cultist_prepared_rite", "cultist_arrow_shot", "cultist_strike"],
	}
	for id: String in wanted.keys():
		var ids: Array = wanted[id]
		assert_eq(_find(state, id).ability_ids, ids, id)
		for ability_id: String in ids:
			assert_not_null(AbilityCatalog.definition(ability_id), ability_id)


func test_new_battle_leaves_the_control_battle_alone() -> void:
	var before := _snapshot(BattleSetup.create_opening_battle())
	BattleSetup.create_new_model_battle()
	assert_eq(_snapshot(BattleSetup.create_opening_battle()), before)
	for fighter: CombatantState in BattleSetup.create_opening_battle().combatants:
		assert_true(fighter.id.begins_with("hero-") or fighter.id.begins_with("enemy-"))
	# Two calls give separate objects.
	var first := BattleSetup.create_new_model_battle()
	var second := BattleSetup.create_new_model_battle()
	first.combatants[0].hp = 1
	assert_eq(second.combatants[0].hp, 22)


func test_at_the_start_the_rite_can_aim_only_at_the_medic() -> void:
	var state := BattleSetup.create_new_model_battle()
	state.turn_queue = ["cultist", "hunter", "shadowclaw", "warrior", "guardian", "medic"]
	for hero_id: String in ["warrior", "hunter", "medic"]:
		var command := AbilityCommand.new()
		command.actor_id = "cultist"
		command.ability_id = "cultist_prepared_rite"
		command.target_id = hero_id
		var wanted := CombatResult.Rejection.NONE if hero_id == "medic" else CombatResult.Rejection.ILLEGAL_TARGET
		assert_eq(rules.validate_ability(command, state), wanted, hero_id)


# --- Whole battles --------------------------------------------------------------------


func test_every_policy_plays_whole_battles_without_breaking_a_rule() -> void:
	var checked := [0]
	var check := func(before: CombatState, result: CombatResult) -> void:
		checked[0] += 1
		_assert_battle_invariants(before, result)
	for policy: String in Simulator.POLICIES:
		for seed_value in range(1, 6):
			var record: Dictionary = simulator.run_from(BattleSetup.create_new_model_battle(), policy, seed_value, Simulator.ROUND_LIMIT, check)
			assert_eq(record["rejected"], 0, "%s %d" % [policy, seed_value])
			assert_true(record["stop"] == "finished" or record["stop"] == "round_limit", "%s %d %s" % [policy, seed_value, record["stop"]])
	assert_gt(checked[0], 100)


func _assert_battle_invariants(before: CombatState, result: CombatResult) -> void:
	var next := result.state
	assert_ne(next, before)
	var slots := {}
	var ids := {}
	for fighter: CombatantState in next.combatants:
		assert_false(ids.has(fighter.id), "duplicate %s" % fighter.id)
		ids[fighter.id] = true
		assert_gt(fighter.hp, 0, "%s listed at hp %d" % [fighter.id, fighter.hp])
		assert_lte(fighter.hp, fighter.max_hp, fighter.id)
		assert_between(fighter.position, 1, 4, fighter.id)
		var key := "%d:%d" % [fighter.side, fighter.position]
		assert_false(slots.has(key), "two fighters on %s" % key)
		slots[key] = true
		assert_true(fighter.guard_reduction == 0 or fighter.guard_reduction == 10, fighter.id)
	# Removal never moves the survivors: positions change only through step, swap, push or maneuver events.
	var moved := {}
	for event: CombatEvent in result.events:
		match event.kind:
			CombatEvent.Kind.STEPPED:
				moved[event.actor_id] = true
			CombatEvent.Kind.SWAPPED:
				moved[event.actor_id] = true
				moved[event.other_id] = true
			CombatEvent.Kind.FORMATION_SHIFTED:
				for shift: PositionShift in event.shifts:
					moved[shift.combatant_id] = true
	for fighter: CombatantState in next.combatants:
		var old := _find(before, fighter.id)
		if old != null and not moved.has(fighter.id):
			assert_eq(fighter.position, old.position, "%s moved without an event" % fighter.id)
	# At most one fighter carries cover.
	var covered := 0
	for fighter: CombatantState in next.combatants:
		if fighter.guard_reduction > 0:
			covered += 1
	assert_lte(covered, 1)
	# The queue moved on unless the battle ended or a new round started with the same fighter.
	if next.outcome == CombatState.Outcome.ONGOING and next.round_number == before.round_number:
		assert_ne(next.turn_queue[0], before.turn_queue[0])


func test_same_seed_and_policy_give_the_same_battle() -> void:
	for policy: String in Simulator.POLICIES:
		var first: Dictionary = simulator.run(policy, 7)
		var second: Dictionary = Simulator.new().run(policy, 7)
		for key: String in ["outcome", "rounds", "turns", "rng_state", "journal_hash", "final", "usage", "stop"]:
			assert_eq(str(first[key]), str(second[key]), "%s %s" % [policy, key])
	# Different seeds lead somewhere else.
	assert_ne(simulator.run("focus", 1)["journal_hash"], simulator.run("focus", 2)["journal_hash"])


func test_the_harness_does_not_write_the_battle_or_roll_while_choosing() -> void:
	var state := BattleSetup.create_new_model_battle()
	var before := _snapshot(state)
	var choice_rng := RandomNumberGenerator.new()
	choice_rng.seed = 3
	for policy: String in ["attack", "focus", "defensive", "tactical"]:
		var choice_state := choice_rng.state
		var command: Variant = simulator.hero_command(policy, state, _find(state, "hunter"), choice_rng)
		assert_not_null(command, policy)
		assert_eq(choice_rng.state, choice_state, policy)
		assert_eq(_snapshot(state), before, policy)
	simulator.run_from(state, "tactical", 3)
	assert_eq(_snapshot(state), before)


func test_the_round_limit_stops_without_naming_a_winner() -> void:
	var record: Dictionary = simulator.run("defensive", 1, 2)
	assert_eq(record["stop"], "round_limit")
	assert_eq(record["outcome"], CombatState.Outcome.ONGOING)
	assert_eq(record["rounds"], 2)
	assert_eq(record["rejected"], 0)


func test_a_mutual_standoff_is_tactical_and_the_queue_keeps_moving() -> void:
	# Warrior on slot 3 who only passes, cultist alone on slot 1: no card reaches either way.
	var state := BattleSetup.create_new_model_battle()
	for id: String in ["hunter", "medic", "guardian", "shadowclaw"]:
		state.combatants.erase(_find(state, id))
	_find(state, "warrior").position = 3
	_find(state, "cultist").position = 1
	state.turn_queue = rules.build_turn_queue(state.combatants)
	var rounds_seen := {}
	var check := func(before: CombatState, result: CombatResult) -> void:
		rounds_seen[result.state.round_number] = true
		for event: CombatEvent in result.events:
			assert_ne(event.kind, CombatEvent.Kind.DAMAGE_APPLIED)
	var record: Dictionary = simulator.run_from(state, "attack", 1, 10, check)
	assert_eq(record["stop"], "round_limit")
	assert_eq(record["rejected"], 0)
	assert_eq(record["no_damage_turns"], record["turns"])
	assert_eq(record["usage"].get("pass:warrior", 0) + record["usage"].get("pass:cultist", 0), record["turns"])
	assert_eq(record["end_reach"], {"warrior": false, "cultist": false})
	assert_gt(rounds_seen.size(), 8)


func test_a_pushed_shadowclaw_behind_the_cultist_passes_and_does_not_swap() -> void:
	# The push lock seen in the sweep: shadowclaw on 3, cultist on 2, nothing reaches from 3 and the slot ahead is held.
	var state := BattleSetup.create_new_model_battle()
	_find(state, "shadowclaw").position = 3
	_find(state, "cultist").position = 2
	state.turn_queue = ["shadowclaw", "hunter", "cultist", "warrior", "guardian", "medic"]
	var result := EnemyAi.new(rules).take_turn(state, RandomNumberGenerator.new())
	assert_true(result.accepted)
	assert_eq(result.events[0].kind, CombatEvent.Kind.TURN_PASSED)
	assert_eq(_find(result.state, "shadowclaw").position, 3)
	assert_eq(_find(result.state, "cultist").position, 2)


func test_the_harness_reports_a_rejected_command_instead_of_hanging() -> void:
	var broken := BrokenSimulator.new()
	var record: Dictionary = broken.run("attack", 1)
	assert_eq(record["stop"], "rejected")
	assert_eq(record["rejected"], 1)
	assert_eq(record["turns"], 1)
	assert_true(record["trace_tail"].contains("REJECTED hunter"))


## A harness whose heroes aim at nobody, to prove the stop on a rejected command.
class BrokenSimulator extends "res://tests/simulation/battle_simulator.gd":
	func hero_command(_policy: String, _state: CombatState, actor: CombatantState, _choice_rng: RandomNumberGenerator) -> Variant:
		var command := AbilityCommand.new()
		command.actor_id = actor.id
		command.ability_id = "hunter_bow_shot"
		command.target_id = "nobody"
		return command

