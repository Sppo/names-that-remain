class_name BattleScene
extends Node2D

## The new 3 v 3 battle on a 2D field with an isometric look. Phase 9A: development view.
## The controller owns the battle; this scene shows its state, plays its events and sends the hero's pass.
## Units are keyed by combatant id; slots are the eight Marker2D under Slots. Nothing here rolls or calculates.

const UNIT_SCENE := preload("res://scenes/combat/battle/combat_unit.tscn")
const MENU_SCENE := "res://scenes/main/main.tscn"

## Off in tests that start the battle themselves.
@export var auto_start := true

var controller: BattleController
var seed_value := 0

var _units := {}
var _names := {}
var _sides := {}
var _generation := 0
var _busy := false

@onready var hud: BattleHUD = $BattleHUD
@onready var player: BattleEventPlayer = $EventPlayer
@onready var _slots: Node2D = $Slots
@onready var _units_root: Node2D = $Units


func _ready() -> void:
	hud.pass_pressed.connect(_on_pass_pressed)
	hud.restart_pressed.connect(restart)
	hud.menu_pressed.connect(_on_menu_pressed)
	if auto_start:
		restart()


func restart() -> void:
	start_battle(BattleSetup.create_new_model_battle(), randi())


## Any ongoing state; the scene keeps no other copy of the battle.
func start_battle(battle: CombatState, seed_number: int) -> void:
	_generation += 1
	_busy = false
	seed_value = seed_number
	controller = BattleController.new()
	controller.start(battle, seed_number)
	for unit: CombatUnit in _units.values():
		_units_root.remove_child(unit)
		unit.queue_free()
	_units.clear()
	_names.clear()
	_sides.clear()
	for fighter: CombatantState in battle.combatants:
		_names[fighter.id] = fighter.display_name if fighter.display_name != "" else fighter.id
		_sides[fighter.id] = fighter.side
		var unit: CombatUnit = UNIT_SCENE.instantiate()
		_units_root.add_child(unit)
		unit.setup(fighter.id, _names[fighter.id], fighter.side)
		_units[fighter.id] = unit
	hud.clear_log()
	hud.hide_result()
	hud.add_log("Новий бій 3×3, зерно %d" % seed_number)
	sync_view()
	_continue(_generation)


## Matches every unit to the controller state: slot, health, cover, effects, active marker. Removes the fallen.
func sync_view() -> void:
	var state := controller.state
	var present := {}
	var active := controller.active()
	for fighter: CombatantState in state.combatants:
		present[fighter.id] = true
		var unit := unit_of(fighter.id)
		if unit == null:
			continue
		unit.move_to(slot_position(fighter.side, fighter.position), 0.0)
		var rite_target := state.prepared != null and state.prepared.target_id == fighter.id
		unit.show_fighter(fighter, active != null and active.id == fighter.id and state.outcome == CombatState.Outcome.ONGOING, rite_target)
	for id: String in _units.keys():
		if not present.has(id):
			var gone: CombatUnit = _units[id]
			_units.erase(id)
			_units_root.remove_child(gone)
			gone.queue_free()
	if state.outcome != CombatState.Outcome.ONGOING:
		hud.set_turn("Раунд %d · бій завершено" % state.round_number)
	elif controller.failed:
		hud.set_turn("Хід ворога відхилено")
	elif active != null:
		hud.set_turn("Раунд %d · хід: %s" % [state.round_number, name_of(active.id)])
	hud.set_pass_enabled(not _busy and controller.is_player_turn())


## Plays one accepted result and then matches the view. False when the scene moved on meanwhile.
func show_result(result: CombatResult) -> bool:
	var generation := _generation
	if not await player.play(result, self, generation):
		return false
	sync_view()
	return true


func is_current(generation: int) -> bool:
	return is_inside_tree() and generation == _generation


func unit_of(id: String) -> CombatUnit:
	return _units.get(id, null)


func unit_count() -> int:
	return _units.size()


func slot_position(side: CombatantState.Side, slot: int) -> Vector2:
	return slot_marker(side, slot).position


func slot_marker(side: CombatantState.Side, slot: int) -> Marker2D:
	var prefix := "Hero" if side == CombatantState.Side.HEROES else "Enemy"
	return _slots.get_node("%s%d" % [prefix, slot])


func side_of(id: String) -> CombatantState.Side:
	return _sides.get(id, CombatantState.Side.HEROES)


func name_of(id: String) -> String:
	return str(_names.get(id, id))


func outcome_sentence(outcome: CombatState.Outcome) -> String:
	match outcome:
		CombatState.Outcome.HEROES_VICTORIOUS:
			return "Перемога героїв"
		CombatState.Outcome.HEROES_DEFEATED:
			return "Поразка героїв"
	return ""


## Enemy turns until a hero must act, the battle ends, or the controller fails.
func _continue(generation: int) -> void:
	while is_current(generation):
		var state := controller.state
		if controller.failed:
			_busy = false
			hud.show_result("Хід ворога відхилено (%d). Перезапустіть бій." % controller.failure)
			sync_view()
			return
		if state.outcome != CombatState.Outcome.ONGOING:
			_busy = false
			hud.show_result(outcome_sentence(state.outcome))
			sync_view()
			return
		if controller.is_player_turn():
			_busy = false
			sync_view()
			return
		_busy = true
		sync_view()
		var result := controller.advance_enemy()
		if not result.accepted:
			continue
		if not await show_result(result):
			return


## Temporary until phase 9: the hero's whole turn is a pass.
func _on_pass_pressed() -> void:
	if _busy or not controller.is_player_turn():
		return
	var command := PassCommand.new()
	command.actor_id = controller.active().id
	_busy = true
	hud.set_pass_enabled(false)
	var result := controller.submit(command)
	if not result.accepted:
		_busy = false
		hud.add_log("Команду відхилено (%d)" % result.rejection)
		sync_view()
		return
	var generation := _generation
	if not await show_result(result):
		return
	_continue(generation)


func _on_menu_pressed() -> void:
	_generation += 1
	get_tree().change_scene_to_file(MENU_SCENE)
