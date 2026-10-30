extends GutTest

## Phase 9A. BattleController without nodes, and the new 2D battle scene on top of it.
## The scene runs with zero wait so every turn plays in the same frame.

const SCENE := preload("res://scenes/combat/battle/battle_scene.tscn")
const MAIN := preload("res://scenes/main/main.tscn")

var rules: CombatRules


func before_each() -> void:
	rules = CombatRules.new()


# --- Helpers ---------------------------------------------------------------


func _scene(step_seconds: float = 0.0) -> BattleScene:
	var scene: BattleScene = SCENE.instantiate()
	scene.auto_start = false
	add_child_autofree(scene)
	scene.player.step_seconds = step_seconds
	return scene


func _find(state: CombatState, id: String) -> CombatantState:
	for fighter: CombatantState in state.combatants:
		if fighter.id == id:
			return fighter
	return null


func _pass_command(actor_id: String) -> PassCommand:
	var command := PassCommand.new()
	command.actor_id = actor_id
	return command


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


func _seed_where(check: Callable) -> int:
	for seed_value in range(1, 5000):
		if check.call(_rng(seed_value)):
			return seed_value
	return -1


func _snapshot(state: CombatState) -> String:
	var lines := PackedStringArray()
	lines.append("round=%d outcome=%d queue=%s" % [state.round_number, state.outcome, ",".join(state.turn_queue)])
	for fighter: CombatantState in state.combatants:
		lines.append("%s p%d hp%d g%d cd%s e%d" % [fighter.id, fighter.position, fighter.hp, fighter.guard_reduction, str(fighter.cooldown_left), fighter.effects.size()])
	return "\n".join(lines)


## Battle with the warrior to act, so the test can send its command.
func _warrior_turn() -> CombatState:
	var state := BattleSetup.create_new_model_battle()
	state.turn_queue = ["warrior", "guardian", "medic"]
	return state


func _assert_view_matches(scene: BattleScene) -> void:
	var state := scene.controller.state
	assert_eq(scene.unit_count(), state.combatants.size())
	assert_eq(scene.get_node("Units").get_child_count(), state.combatants.size())
	var active := scene.controller.active()
	for fighter: CombatantState in state.combatants:
		var unit := scene.unit_of(fighter.id)
		assert_not_null(unit, fighter.id)
		if unit == null:
			continue
		assert_eq(unit.position, scene.slot_position(fighter.side, fighter.position), fighter.id)
		assert_eq(unit.shown_hp_text(), "%d / %d" % [fighter.hp, fighter.max_hp], fighter.id)
		var marked: bool = unit.get_node("ActiveMarker").visible
		assert_eq(marked, active != null and active.id == fighter.id and state.outcome == CombatState.Outcome.ONGOING, fighter.id)


# --- Controller ------------------------------------------------------------------


func test_controller_starts_and_reports_the_active_fighter() -> void:
	var battle := BattleSetup.create_new_model_battle()
	var controller := BattleController.new()
	controller.start(battle, 5)
	assert_eq(controller.state, battle)
	assert_eq(controller.active().id, "hunter")
	assert_true(controller.is_player_turn())
	assert_false(controller.failed)


func test_controller_takes_player_commands_only_on_a_hero_turn() -> void:
	var controller := BattleController.new()
	controller.start(BattleSetup.create_new_model_battle(), 5)
	var before := controller.state
	var early := controller.advance_enemy()
	assert_eq(early.rejection, CombatResult.Rejection.NOT_ACTIVE_TURN)
	assert_eq(controller.state, before)
	assert_false(controller.failed)
	var passed := controller.submit(_pass_command("hunter"))
	assert_true(passed.accepted)
	assert_eq(controller.state, passed.state)
	assert_eq(controller.active().id, "cultist")
	var refused := controller.submit(_pass_command("cultist"))
	assert_eq(refused.rejection, CombatResult.Rejection.NOT_ACTIVE_TURN)
	assert_eq(controller.state, passed.state)
	var illegal := BattleController.new()
	illegal.start(BattleSetup.create_new_model_battle(), 5)
	var bad := illegal.submit(_ability("hunter", "hunter_dagger", "cultist"))
	assert_false(bad.accepted)
	assert_eq(illegal.active().id, "hunter")


func test_controller_enemy_turn_is_the_real_enemy_ai() -> void:
	var controller := BattleController.new()
	controller.start(BattleSetup.create_new_model_battle(), 11)
	controller.submit(_pass_command("hunter"))
	var start := controller.state
	var by_controller := controller.advance_enemy()
	var rng := _rng(11)
	var by_ai := EnemyAi.new(rules).take_turn(start, rng)
	assert_true(by_controller.accepted)
	assert_eq(_snapshot(by_controller.state), _snapshot(by_ai.state))
	assert_eq(controller.rng_state(), rng.state)


func test_a_rejected_enemy_turn_puts_the_controller_into_failure() -> void:
	# Phase 5 debt: a stored strike with an unknown id is rejected. The controller must stop, not loop.
	var battle := BattleSetup.create_new_model_battle()
	battle.turn_queue = ["cultist", "hunter"]
	var prepared := PreparedStrike.new()
	prepared.actor_id = "cultist"
	prepared.ability_id = "no_such_ability"
	prepared.target_id = "medic"
	battle.prepared = prepared
	var controller := BattleController.new()
	controller.start(battle, 1)
	var result := controller.advance_enemy()
	assert_false(result.accepted)
	assert_true(controller.failed)
	assert_eq(controller.failure, CombatResult.Rejection.CALCULATION_FAILED)
	assert_eq(controller.state, battle)
	assert_false(controller.is_player_turn())
	assert_eq(controller.advance_enemy().rejection, CombatResult.Rejection.NOT_ACTIVE_TURN)
	for error in get_errors():
		error.handled = true


# --- Scene -------------------------------------------------------------------------


func test_scene_shows_eight_slots_and_six_fighters_on_their_opening_slots() -> void:
	var scene := _scene()
	scene.start_battle(BattleSetup.create_new_model_battle(), 3)
	var positions := {}
	for side in [CombatantState.Side.HEROES, CombatantState.Side.ENEMIES]:
		for slot in range(1, 5):
			var marker := scene.slot_marker(side, slot)
			assert_not_null(marker)
			positions[marker.position] = true
	assert_eq(positions.size(), 8)
	assert_eq(scene.unit_count(), 6)
	var wanted := {"warrior": 1, "hunter": 2, "medic": 3, "guardian": 1, "shadowclaw": 2, "cultist": 3}
	for id: String in wanted.keys():
		var unit := scene.unit_of(id)
		assert_eq(unit.fighter_id, id)
		assert_eq(unit.position, scene.slot_position(scene.side_of(id), wanted[id]), id)
	for unit: Node in scene.get_node("Units").get_children():
		for side in [CombatantState.Side.HEROES, CombatantState.Side.ENEMIES]:
			assert_ne(unit.position, scene.slot_position(side, 4))
	assert_ne(scene.unit_of("warrior").get_node("Body").color, scene.unit_of("guardian").get_node("Body").color)
	assert_eq(scene.unit_of("cultist").get_node("NameLabel").text, "Культист")
	_assert_view_matches(scene)
	assert_true(scene.hud.is_pass_enabled())
	assert_true(scene.hud.log_lines()[0].contains("зерно 3"))


func test_scene_has_no_3d_nodes() -> void:
	var scene := _scene()
	scene.start_battle(BattleSetup.create_new_model_battle(), 3)
	var stack: Array[Node] = [scene]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		assert_false(node is Node3D, node.name)
		stack.append_array(node.get_children())


func test_pass_plays_enemy_turns_and_the_view_follows_the_state() -> void:
	var scene := _scene()
	scene.start_battle(BattleSetup.create_new_model_battle(), 21)
	scene.hud.pass_pressed.emit()
	var active := scene.controller.active()
	assert_true(active == null or active.side == CombatantState.Side.HEROES or scene.controller.state.outcome != CombatState.Outcome.ONGOING)
	_assert_view_matches(scene)
	var log_text := "\n".join(scene.hud.log_lines())
	assert_true(log_text.contains("Мисливець пропускає хід"))
	# Cultist and shadowclaw acted after the pass.
	assert_true(log_text.contains("Культист"))


func test_a_death_leaves_the_slot_empty_and_moves_nobody() -> void:
	var battle := _warrior_turn()
	_find(battle, "guardian").hp = 1
	var table := rules.strike_outcome(_find(battle, "warrior"), _find(battle, "guardian"), AbilityCatalog.definition("warrior_sword"), 0)
	var seed_value := _seed_where(func(r: RandomNumberGenerator) -> bool: return r.randi_range(1, 100) <= table.hit_chance)
	var scene := _scene()
	scene.start_battle(battle, seed_value)
	var result := scene.controller.submit(_ability("warrior", "warrior_sword", "guardian"))
	assert_true(result.accepted)
	await scene.show_result(result)
	assert_null(scene.unit_of("guardian"))
	assert_eq(scene.unit_count(), 5)
	assert_eq(scene.unit_of("shadowclaw").position, scene.slot_position(CombatantState.Side.ENEMIES, 2))
	assert_true("\n".join(scene.hud.log_lines()).contains("Вартовий вибуває з бою"))
	_assert_view_matches(scene)
	await wait_physics_frames(1)


func test_step_swap_and_push_move_the_right_units() -> void:
	var scene := _scene()
	scene.start_battle(_warrior_turn(), 1)
	var step := StepCommand.new()
	step.actor_id = "warrior"
	step.destination_position = 2
	var swapped := scene.controller.submit(step)
	assert_true(swapped.accepted)
	await scene.show_result(swapped)
	assert_eq(scene.unit_of("warrior").position, scene.slot_position(CombatantState.Side.HEROES, 2))
	assert_eq(scene.unit_of("hunter").position, scene.slot_position(CombatantState.Side.HEROES, 1))
	_assert_view_matches(scene)

	var battle := _warrior_turn()
	var push := AbilityCatalog.definition("warrior_shield_push")
	var table := rules.strike_outcome(_find(battle, "warrior"), _find(battle, "shadowclaw"), push, 0)
	var seed_value := _seed_where(func(r: RandomNumberGenerator) -> bool: return r.randi_range(1, 100) <= table.hit_chance)
	scene.start_battle(battle, seed_value)
	var pushed := scene.controller.submit(_ability("warrior", "warrior_shield_push", "shadowclaw"))
	assert_true(pushed.accepted)
	await scene.show_result(pushed)
	assert_eq(scene.unit_of("shadowclaw").position, scene.slot_position(CombatantState.Side.ENEMIES, 3))
	assert_eq(scene.unit_of("cultist").position, scene.slot_position(CombatantState.Side.ENEMIES, 2))
	assert_true("\n".join(scene.hud.log_lines()).contains("Поштовх"))
	_assert_view_matches(scene)
	await wait_physics_frames(1)


func test_restart_rebuilds_the_units_without_duplicates() -> void:
	var scene := _scene()
	scene.start_battle(BattleSetup.create_new_model_battle(), 2)
	scene.hud.pass_pressed.emit()
	var first_warrior := scene.unit_of("warrior")
	scene.restart()
	scene.restart()
	assert_eq(scene.unit_count(), 6)
	assert_eq(scene.get_node("Units").get_child_count(), 6)
	assert_ne(scene.unit_of("warrior"), first_warrior)
	var names := {}
	for unit: Node in scene.get_node("Units").get_children():
		assert_false(names.has(unit.name), str(unit.name))
		names[unit.name] = true
	assert_eq(scene.hud.result_text(), "")
	await wait_physics_frames(2)
	assert_false(is_instance_valid(first_warrior))


func test_presenting_never_rolls_and_matches_a_battle_without_a_view() -> void:
	var scene := _scene()
	scene.start_battle(BattleSetup.create_new_model_battle(), 41)
	var bare := BattleController.new()
	bare.start(BattleSetup.create_new_model_battle(), 41)
	var guard := 0
	while scene.controller.state.outcome == CombatState.Outcome.ONGOING and guard < 400:
		guard += 1
		var before := scene.controller.rng_state()
		scene.sync_view()
		assert_eq(scene.controller.rng_state(), before)
		scene.hud.pass_pressed.emit()
	# The same commands without nodes: heroes pass, enemies play.
	while bare.state.outcome == CombatState.Outcome.ONGOING and guard > 0:
		if bare.is_player_turn():
			bare.submit(_pass_command(bare.active().id))
		else:
			assert_true(bare.advance_enemy().accepted)
	assert_eq(_snapshot(scene.controller.state), _snapshot(bare.state))
	assert_eq(scene.controller.rng_state(), bare.rng_state())
	assert_eq(scene.controller.state.outcome, CombatState.Outcome.HEROES_DEFEATED)
	assert_eq(scene.hud.result_text(), "Поразка героїв")
	assert_false(scene.hud.is_pass_enabled())
	_assert_view_matches(scene)
	await wait_physics_frames(1)


func test_leaving_mid_turn_stops_cleanly() -> void:
	var scene: BattleScene = SCENE.instantiate()
	scene.auto_start = false
	add_child(scene)
	scene.player.step_seconds = 0.05
	scene.start_battle(BattleSetup.create_new_model_battle(), 9)
	scene.hud.pass_pressed.emit()
	scene.queue_free()
	await wait_seconds(0.6)
	assert_false(is_instance_valid(scene))
	assert_eq(get_errors().size(), 0)


func test_restart_mid_turn_drops_the_old_turn() -> void:
	var scene := _scene(0.05)
	scene.start_battle(BattleSetup.create_new_model_battle(), 9)
	scene.hud.pass_pressed.emit()
	scene.restart()
	await wait_seconds(0.8)
	assert_eq(scene.unit_count(), 6)
	_assert_view_matches(scene)
	assert_eq(scene.controller.state.round_number, 1)
	# Nothing from the dropped turn reached the new log.
	assert_eq(scene.hud.log_lines().size(), 1)
	assert_true(scene.hud.log_lines()[0].begins_with("Новий бій 3×3"))
	assert_true(scene.hud.is_pass_enabled())


func test_main_menu_keeps_the_control_battle_and_adds_the_new_one() -> void:
	var menu: Control = MAIN.instantiate()
	add_child_autofree(menu)
	assert_eq(menu.get_node("EnterBattle").text, "До бою")
	assert_eq(menu.get_node("EnterNewBattle").text, "Новий бій 3×3 (розробка)")
	assert_eq(menu.COMBAT_SCENE.resource_path, "res://scenes/combat/combat_screen.tscn")
	assert_eq(menu.NEW_BATTLE_SCENE.resource_path, "res://scenes/combat/battle/battle_scene.tscn")
	# The control screen still builds the control battle.
	assert_true(FileAccess.get_file_as_string("res://scenes/combat/combat_screen.gd").contains("BattleSetup.create_opening_battle()"))


func test_a_failed_enemy_turn_is_shown_and_stops_the_battle() -> void:
	var battle := BattleSetup.create_new_model_battle()
	battle.turn_queue = ["cultist", "hunter"]
	var prepared := PreparedStrike.new()
	prepared.actor_id = "cultist"
	prepared.ability_id = "no_such_ability"
	prepared.target_id = "medic"
	battle.prepared = prepared
	var scene := _scene()
	scene.start_battle(battle, 1)
	assert_true(scene.controller.failed)
	assert_true(scene.hud.result_text().begins_with("Хід ворога відхилено"))
	assert_false(scene.hud.is_pass_enabled())
	assert_eq(scene.unit_count(), 6)
	for error in get_errors():
		error.handled = true

