extends Control

## Battle presentation. Commands go to combat rules; this scene only displays the result.

## Visual order only: position 1 is the column nearest the center.
const HERO_COLUMNS: Array[int] = [4, 3, 2, 1]
const ENEMY_COLUMNS: Array[int] = [1, 2, 3, 4]

const COLOR_EMPTY := Color(0.14, 0.13, 0.16, 1)
const COLOR_HERO := Color(0.33, 0.28, 0.18, 1)
const COLOR_ENEMY := Color(0.34, 0.18, 0.2, 1)
const COLOR_BORDER := Color(0.45, 0.4, 0.34, 1)
const COLOR_VALID := Color(0.62, 0.78, 0.5, 1)
const COLOR_REFUSED := Color(0.82, 0.38, 0.32, 1)
const COLOR_ACTIVE := Color(0.93, 0.78, 0.42, 1)
const COLOR_TARGET := Color(0.86, 0.55, 0.32, 1)
const COLOR_TEXT := Color(0.95, 0.91, 0.84, 1)
const COLOR_TEXT_DIM := Color(0.68, 0.64, 0.58, 1)
const LOG_ALLY_COLOR := "#f7f4ee"
const LOG_ENEMY_COLOR := "#e23b3b"
const LOG_NOTE_COLOR := "#cfc6ba"
const COLOR_HP := Color(0.82, 0.22, 0.2, 1)
const COLOR_HP_TRACK := Color(0.08, 0.07, 0.09, 1)
const COLOR_OUTLINE := Color(0.93, 0.9, 0.84, 1)
const COLOR_ACCENT := Color(0.95, 0.48, 0.16, 1)
const TURN_BLUE := "#3d8cff"
const PORTRAIT_PATHS := {
	"hero-1": "res://assets/combat/warrior.png",
	"hero-2": "res://assets/combat/hunter.png",
	"hero-3": "res://assets/combat/doctor.png",
	"enemy-1": "res://assets/combat/guardian.png",
	"enemy-2": "res://assets/combat/cultist.png",
	"enemy-3": "res://assets/combat/shadowclaw.png",
}
## One already-resolved action, in order. The same gaps for heroes and enemies.
const AIM_SECONDS := 0.3
const FLASH_SECONDS := 0.4
const RESULT_SECONDS := 0.5
const CLEAR_SECONDS := 0.2

class FormationCell extends RefCounted:
	var side: CombatantState.Side
	var slot: int
	var button: Button
	var portrait: TextureRect
	var name_label: Label
	var hp_track: ColorRect
	var hp_fill: ColorRect
	var accent: ColorRect
	var damage_label: Label
	var damage_tween: Tween
	var mark_label: Label
	var mark_tween: Tween
	var shake_tween: Tween

	func _init(cell_side: CombatantState.Side, cell_slot: int, cell_button: Button) -> void:
		side = cell_side
		slot = cell_slot
		button = cell_button


@onready var _turn_label: RichTextLabel = %TurnLabel
@onready var _notice_label: Label = %NoticeLabel
@onready var _prepared_label: Label = %PreparedLabel
@onready var _preview_label: Label = %PreviewLabel
@onready var _event_log: RichTextLabel = %EventLog
@onready var _heroes_row: HBoxContainer = %HeroesRow
@onready var _enemies_row: HBoxContainer = %EnemiesRow
@onready var _restart_button: Button = %RestartButton
@onready var _ability_row: HBoxContainer = %AbilityRow

var _state: CombatState
var _rng: RandomNumberGenerator
var _rules: CombatRules
var _enemy_ai: EnemyAi
var _cells: Array[FormationCell] = []
var _log_entries: Array[Dictionary] = []
var _notice: String = ""
var _refused_slot: int = -1
var _refused_side: CombatantState.Side = CombatantState.Side.HEROES
var _input_locked: bool = false
var _selected_ability_id: String = ""
var _action_owner_id: String = ""
var _actions_key: String = "~"
var _names: Dictionary = {}
var _sides: Dictionary = {}
var _hits: Dictionary = {}
var _misses: Dictionary = {}
var _heals: Dictionary = {}
var _playing: bool = false
var _focus_actor_id: String = ""
var _focus_target_id: String = ""
var _shake_id: String = ""
var _flash_ids: Dictionary = {}
var _position_override: Dictionary = {}
var _hp_override: Dictionary = {}
var _guard_override: Dictionary = {}
var _hidden: Dictionary = {}
var _prepared_line: String = ""
var _prepared_line_set: bool = false
var _portraits: Dictionary = {}
var _hover_cell: FormationCell = null
var _command_held: bool = false
var _stats_panel: PanelContainer
var _stats_label: Label


func _ready() -> void:
	_ability_row.custom_minimum_size = Vector2(0, 48)
	_load_portraits()
	_build_stats_window()
	_build_cells()
	_restart_button.pressed.connect(_on_restart_pressed)
	_start_battle()


func _input(event: InputEvent) -> void:
	var changed := false
	if event is InputEventKey and event.keycode == KEY_META and not event.echo:
		_command_held = event.pressed
		changed = true
	elif event is InputEventMouseMotion:
		var next := _cell_under_mouse()
		if next != _hover_cell:
			_hover_cell = next
			changed = true
	if changed:
		_refresh_stats_window()


func _on_restart_pressed() -> void:
	if _input_locked:
		return
	_start_battle()


func _start_battle() -> void:
	_input_locked = true
	_playing = false
	_focus_actor_id = ""
	_focus_target_id = ""
	_flash_ids.clear()
	_reset_shown_board()
	_notice = ""
	_refused_slot = -1
	_selected_ability_id = ""
	_action_owner_id = ""
	_actions_key = "~"
	_names = {}
	_sides = {}
	_hits = {}
	_misses = {}
	_heals = {}
	_log_entries = []
	_rng = RandomNumberGenerator.new()
	_rng.randomize()
	_rules = CombatRules.new()
	_enemy_ai = EnemyAi.new(_rules)
	_state = BattleSetup.create_opening_battle()
	_remember_names()
	_refresh()
	_log_startup()
	await _play_enemy_turns()
	_release_input()


func _build_cells() -> void:
	for slot: int in HERO_COLUMNS:
		_add_cell(CombatantState.Side.HEROES, slot, _heroes_row)
	for slot: int in ENEMY_COLUMNS:
		_add_cell(CombatantState.Side.ENEMIES, slot, _enemies_row)


func _load_portraits() -> void:
	for fighter_id: String in PORTRAIT_PATHS:
		_portraits[fighter_id] = load(str(PORTRAIT_PATHS[fighter_id]))


func _add_cell(side: CombatantState.Side, slot: int, row: HBoxContainer) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(168, 220)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.clip_contents = true
	button.pressed.connect(_on_cell_pressed.bind(side, slot))
	button.resized.connect(_center_card.bind(button))

	var cell := FormationCell.new(side, slot, button)
	var portrait := TextureRect.new()
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait.offset_left = 4
	portrait.offset_top = 14
	portrait.offset_right = -4
	portrait.offset_bottom = -34
	button.add_child(portrait)
	cell.portrait = portrait

	var track := ColorRect.new()
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.color = COLOR_HP_TRACK
	track.set_anchors_preset(Control.PRESET_TOP_WIDE)
	track.offset_left = 4
	track.offset_top = 4
	track.offset_right = -4
	track.offset_bottom = 12
	var fill := ColorRect.new()
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.color = COLOR_HP
	fill.anchor_left = 0.0
	fill.anchor_top = 0.0
	fill.anchor_bottom = 1.0
	fill.anchor_right = 0.0
	fill.offset_right = 0.0
	track.add_child(fill)
	button.add_child(track)
	cell.hp_track = track
	cell.hp_fill = fill

	var name_label := _cell_label("", 18, COLOR_TEXT)
	name_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	name_label.offset_left = 4
	name_label.offset_top = -32
	name_label.offset_right = -4
	name_label.offset_bottom = -8
	button.add_child(name_label)
	cell.name_label = name_label

	var accent := ColorRect.new()
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	accent.color = COLOR_ACCENT
	accent.visible = false
	accent.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	accent.offset_left = 4
	accent.offset_top = -7
	accent.offset_right = -4
	accent.offset_bottom = -3
	button.add_child(accent)
	cell.accent = accent

	var damage_label := _cell_label("", 42, Color(0.96, 0.16, 0.12, 1))
	_prepare_floater(damage_label)
	button.add_child(damage_label)
	cell.damage_label = damage_label

	var mark_label := _cell_label("", 36, COLOR_TEXT)
	_prepare_floater(mark_label)
	button.add_child(mark_label)
	cell.mark_label = mark_label

	row.add_child(button)
	_cells.append(cell)


func _build_stats_window() -> void:
	var panel := PanelContainer.new()
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = 20
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.09, 0.12, 0.96)
	style.border_color = Color(0.62, 0.56, 0.46, 1)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", COLOR_TEXT)
	margin.add_child(label)
	panel.add_child(margin)
	add_child(panel)
	_stats_panel = panel
	_stats_label = label


func _cell_under_mouse() -> FormationCell:
	var point := get_viewport().get_mouse_position()
	var found: FormationCell = null
	for cell: FormationCell in _cells:
		if cell.button.get_global_rect().has_point(point):
			found = cell
	return found


func _refresh_stats_window() -> void:
	if _stats_panel == null:
		return
	var fighter := _hovered_fighter()
	if not _command_held or fighter == null:
		_stats_panel.visible = false
		return
	_stats_label.text = _stats_sentence(fighter)
	_stats_panel.visible = true
	_stats_panel.reset_size()
	_place_stats_window()


func _hovered_fighter() -> CombatantState:
	if _hover_cell == null:
		return null
	return _fighter_at(_hover_cell.side, _hover_cell.slot)


func _stats_sentence(fighter: CombatantState) -> String:
	var hp := _shown_hp(fighter)
	var ceiling := fighter.max_hp
	if ceiling < hp:
		ceiling = hp
	var lines := PackedStringArray()
	lines.append(_name_of(fighter.id))
	lines.append("Позиція %d" % _shown_position(fighter))
	lines.append("Здоров'я %d / %d" % [hp, ceiling])
	lines.append("Швидкість %d" % fighter.speed)
	lines.append("Точність %d" % fighter.accuracy)
	lines.append("Ухилення %d" % fighter.dodge)
	lines.append("Блок %d" % fighter.block)
	var cover := _shown_guard(fighter)
	if cover > 0:
		lines.append("Під захистом %d" % cover)
	return "\n".join(lines)


func _place_stats_window() -> void:
	var rect := _hover_cell.button.get_global_rect()
	var panel_size := _stats_panel.get_combined_minimum_size()
	var screen_size := get_viewport_rect().size
	var x := rect.end.x + 12.0
	if x + panel_size.x > screen_size.x - 12.0:
		x = rect.position.x - panel_size.x - 12.0
	var y := clampf(rect.position.y, 12.0, maxf(screen_size.y - panel_size.y - 12.0, 12.0))
	_stats_panel.global_position = Vector2(x, y)


func _cell_label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _on_cell_pressed(side: CombatantState.Side, slot: int) -> void:
	if _input_locked:
		return
	var active := _active_fighter()
	if active == null or active.side != CombatantState.Side.HEROES:
		return
	if _selected_ability_id == "" and side != CombatantState.Side.HEROES:
		return
	_input_locked = true
	var result: CombatResult = null
	if _selected_ability_id == "":
		result = _rules.resolve(_step_command(active.id, slot), _state, _rng)
	else:
		var target := _fighter_at(side, slot)
		if target == null:
			_notice = "Тут немає цілі."
			_refused_side = side
			_refused_slot = slot
			_release_input()
			return
		result = _rules.resolve_ability(
			_ability_command(active.id, _selected_ability_id, target.id),
			_state,
			_rng
		)
	if result == null or not result.accepted:
		if result == null:
			_notice = "resolve не повернув результат бою."
		else:
			_notice = _rejection_sentence(result.rejection)
			_refused_side = side
			_refused_slot = slot
		_release_input()
		return
	await _show_accepted(result)


func _show_accepted(result: CombatResult) -> void:
	if not await _present_result(result):
		_release_input()
		return
	await _play_enemy_turns()
	_release_input()


func _release_input() -> void:
	_input_locked = false
	if is_inside_tree():
		_refresh()


func _play_enemy_turns() -> void:
	while is_inside_tree():
		var active := _active_fighter()
		if active == null or active.side != CombatantState.Side.ENEMIES:
			return
		var head_id := _state.turn_queue[0]
		var result := _enemy_ai.take_turn(_state, _rng)
		if result == null:
			_notice = "Правила не дали команду для активного ворога."
			return
		if not result.accepted:
			_notice = _rejection_sentence(result.rejection)
			return
		if not await _present_result(result):
			return
		if _state == null or _state.outcome != CombatState.Outcome.ONGOING or _state.turn_queue.is_empty():
			return
		if _state.turn_queue[0] == head_id:
			_notice = "Хід ворога зупинено: черга не перейшла далі."
			return


func _step_command(actor_id: String, destination: int) -> StepCommand:
	var command := StepCommand.new()
	command.actor_id = actor_id
	command.destination_position = destination
	return command


func _ability_command(actor_id: String, ability_id: String, target_id: String) -> AbilityCommand:
	var command := AbilityCommand.new()
	command.actor_id = actor_id
	command.ability_id = ability_id
	command.target_id = target_id
	return command


func _on_action_pressed(ability_id: String) -> void:
	if _input_locked:
		return
	_selected_ability_id = ability_id
	_notice = ""
	_refused_slot = -1
	_refresh()


## Shows one accepted turn, then stores its state. Does not resolve again.
func _present_result(result: CombatResult) -> bool:
	if result.state == null:
		_notice = "Прийнятий хід не містить стану."
		return false
	_remember_names()
	_notice = ""
	_refused_slot = -1
	_selected_ability_id = ""
	_reset_shown_board()
	_clear_strike_marks()
	_flash_ids.clear()
	_playing = true
	_focus_target_id = ""
	_focus_actor_id = ""
	var actor_id := _presentation_actor(result.events)
	_refresh()
	if result.events.is_empty():
		if not await _play_shown_step(actor_id, "", _show_empty_turn):
			return false
	else:
		for event: CombatEvent in result.events:
			if not await _present_event(event):
				return false
	if not is_inside_tree():
		return false
	_record_exchange(result.events)
	_playing = false
	_focus_actor_id = ""
	_focus_target_id = ""
	_flash_ids.clear()
	_clear_strike_marks()
	_reset_shown_board()
	_state = result.state
	_remember_names()
	_refresh()
	return true


func _present_event(event: CombatEvent) -> bool:
	match event.kind:
		CombatEvent.Kind.DAMAGE_APPLIED, CombatEvent.Kind.MISSED, CombatEvent.Kind.HEALED:
			return await _present_health_event(event)
		CombatEvent.Kind.GUARD_PLACED:
			return await _present_guard(event)
		CombatEvent.Kind.STEPPED:
			return await _present_step(event)
		CombatEvent.Kind.SWAPPED:
			return await _present_swap(event)
		CombatEvent.Kind.PREPARED_STRIKE:
			return await _present_prepared(event)
		CombatEvent.Kind.REMOVED_FROM_BATTLE:
			return await _present_removal(event)
		CombatEvent.Kind.FORMATION_SHIFTED:
			return await _present_shift(event)
		_:
			_refresh()
			return is_inside_tree()


func _present_health_event(event: CombatEvent) -> bool:
	if not await _play_shown_step(event.actor_id, event.other_id, _show_health_result.bind(event)):
		return false
	# Rite warning outlives the strike text. It clears only after that text is already gone.
	_hide_resolved_rite(event)
	if is_inside_tree():
		_refresh()
	return is_inside_tree()


func _show_health_result(event: CombatEvent) -> void:
	_remember_reaction(event)
	if event.kind == CombatEvent.Kind.MISSED:
		_hide_floater(event.other_id, false)
		_float_word(event.other_id, "Промах", Color(0.93, 0.9, 0.84, 1), true)
		return
	if event.kind == CombatEvent.Kind.HEALED:
		_hide_floater(event.other_id, true)
		_float_number(event.other_id, "+%d" % event.amount, Color(0.55, 0.86, 0.48, 1))
	elif event.kind == CombatEvent.Kind.DAMAGE_APPLIED:
		if _hit_was_blocked(event.mitigation):
			_shake_id = event.other_id
			_float_word(event.other_id, "Блок", Color(0.72, 0.84, 0.98, 1), false)
		else:
			_hide_floater(event.other_id, true)
		_float_number(event.other_id, "−%d" % event.amount, Color(0.96, 0.16, 0.12, 1))
	_hp_override[event.other_id] = event.resulting_hp
	if (
		event.mitigation == CombatEvent.Mitigation.GUARD
		or event.mitigation == CombatEvent.Mitigation.BLOCK_AND_GUARD
	):
		_guard_override[event.other_id] = 0


func _show_empty_turn() -> void:
	pass


func _hide_floater(fighter_id: String, word: bool) -> void:
	var cell := _cell_of(fighter_id)
	if cell == null:
		return
	var label := cell.mark_label if word else cell.damage_label
	var tween := cell.mark_tween if word else cell.damage_tween
	if tween != null and is_instance_valid(tween):
		tween.kill()
	if label != null:
		label.visible = false


func _prepare_floater(label: Label) -> void:
	label.visible = false
	label.z_index = 6
	label.add_theme_constant_override("outline_size", 10)
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.02, 0.02, 1))
	label.set_anchors_preset(Control.PRESET_CENTER)


## Already-resolved HP change. Rises and fades so the number reads as the blow.
func _float_number(fighter_id: String, text: String, color: Color) -> void:
	var cell := _cell_of(fighter_id)
	if cell == null or cell.damage_label == null:
		return
	var label := cell.damage_label
	label.add_theme_color_override("font_color", color)
	_play_floater(label, text, 72.0, 16.0, false)
	cell.damage_tween = _bind_tween(cell.damage_tween, label)


## "Промах" slides aside. "Блок" pops above the number and the card shakes.
func _float_word(fighter_id: String, text: String, color: Color, slide: bool) -> void:
	var cell := _cell_of(fighter_id)
	if cell == null or cell.mark_label == null:
		return
	var label := cell.mark_label
	label.add_theme_color_override("font_color", color)
	var top := 8.0 if not slide else 48.0
	_play_floater(label, text, top, top - 8.0, slide)
	cell.mark_tween = _bind_tween(cell.mark_tween, label)


func _play_floater(label: Label, text: String, from_top: float, to_top: float, slide: bool) -> void:
	label.text = text
	label.visible = true
	label.modulate = Color.WHITE
	label.scale = Vector2(0.55, 0.55)
	label.pivot_offset = Vector2(80, 32)
	label.offset_left = -80
	label.offset_right = 80
	label.offset_top = from_top
	label.offset_bottom = from_top + 64.0
	var tween := label.create_tween()
	label.set_meta("floater_tween", tween)
	tween.set_parallel(true)
	tween.tween_property(label, "scale", Vector2(1.16, 1.16), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if slide:
		tween.tween_property(label, "offset_left", -36.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(label, "offset_right", 124.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		tween.tween_property(label, "offset_top", to_top, 0.72).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(label, "offset_bottom", to_top + 64.0, 0.72).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.4).set_delay(0.28)
	tween.set_parallel(false)
	tween.tween_callback(label.hide)


func _bind_tween(previous: Tween, label: Label) -> Tween:
	if previous != null and is_instance_valid(previous):
		previous.kill()
	return label.get_meta("floater_tween") as Tween


func _nudge_block(cell: FormationCell) -> void:
	var button := cell.button
	if cell.shake_tween != null and is_instance_valid(cell.shake_tween):
		cell.shake_tween.kill()
	var base := button.rotation
	var tween := button.create_tween()
	cell.shake_tween = tween
	tween.tween_property(button, "rotation", base + deg_to_rad(8.0), 0.05)
	tween.tween_property(button, "rotation", base - deg_to_rad(7.0), 0.06)
	tween.tween_property(button, "rotation", base + deg_to_rad(3.0), 0.05)
	tween.tween_property(button, "rotation", base, 0.07)


func _cell_of(fighter_id: String) -> FormationCell:
	var fighter := _fighter_by_id(fighter_id)
	if fighter == null:
		return null
	var slot := _shown_position(fighter)
	for cell: FormationCell in _cells:
		if cell.side == fighter.side and cell.slot == slot:
			return cell
	return null


func _present_guard(event: CombatEvent) -> bool:
	return await _play_shown_step(event.actor_id, event.other_id, _show_guard_result.bind(event))


func _show_guard_result(event: CombatEvent) -> void:
	if _state != null:
		for fighter: CombatantState in _state.combatants:
			_guard_override[fighter.id] = 0
	_guard_override[event.other_id] = event.amount


func _present_step(event: CombatEvent) -> bool:
	return await _play_shown_step(event.actor_id, "", _show_step_result.bind(event))


func _show_step_result(event: CombatEvent) -> void:
	_position_override[event.actor_id] = event.to_position


func _present_swap(event: CombatEvent) -> bool:
	return await _play_shown_step(event.actor_id, event.other_id, _show_swap_result.bind(event))


func _show_swap_result(event: CombatEvent) -> void:
	_position_override[event.actor_id] = event.to_position
	_position_override[event.other_id] = event.from_position


func _present_prepared(event: CombatEvent) -> bool:
	return await _play_shown_step(event.actor_id, event.other_id, _show_prepared_result.bind(event))


func _show_prepared_result(event: CombatEvent) -> void:
	_prepared_line = _event_line(event)
	_prepared_line_set = true


func _present_removal(event: CombatEvent) -> bool:
	return await _play_shown_step(event.actor_id, "", _show_removal_result.bind(event))


func _show_removal_result(event: CombatEvent) -> void:
	_hidden[event.actor_id] = true
	if _focus_target_id == event.actor_id:
		_focus_target_id = ""
	if _focus_actor_id == event.actor_id:
		_focus_actor_id = ""


func _present_shift(event: CombatEvent) -> bool:
	var ids: Array[String] = []
	for shift: PositionShift in event.shifts:
		ids.append(shift.combatant_id)
	return await _play_shown_step("", "", _show_shift_result.bind(event), ids)


func _show_shift_result(event: CombatEvent) -> void:
	for shift: PositionShift in event.shifts:
		_position_override[shift.combatant_id] = shift.to_position


## Highlight, flash the card in place, show the result, then clear this strike.
## The next actor is highlighted only by the following call.
func _play_shown_step(
	actor_id: String,
	target_id: String,
	apply_result: Callable,
	flash_ids: Array[String] = []
) -> bool:
	_clear_strike_marks()
	_flash_ids.clear()
	_focus_actor_id = actor_id
	_focus_target_id = target_id
	_refresh()
	if not await _hold(AIM_SECONDS):
		return false
	_arm_flash(target_id, actor_id, flash_ids)
	_refresh()
	if not await _hold(FLASH_SECONDS):
		return false
	apply_result.call()
	_refresh()
	if not await _hold(RESULT_SECONDS):
		return false
	_clear_strike_marks()
	_flash_ids.clear()
	_refresh()
	return await _hold(CLEAR_SECONDS)


func _arm_flash(target_id: String, actor_id: String, flash_ids: Array[String]) -> void:
	_flash_ids.clear()
	if not flash_ids.is_empty():
		for fighter_id: String in flash_ids:
			if fighter_id != "":
				_flash_ids[fighter_id] = true
		return
	var card_id := target_id if target_id != "" else actor_id
	if card_id != "":
		_flash_ids[card_id] = true


func _clear_strike_marks() -> void:
	_hits.clear()
	_misses.clear()
	_heals.clear()


func _hold(seconds: float) -> bool:
	if not is_inside_tree():
		return false
	await get_tree().create_timer(seconds).timeout
	return is_inside_tree()


func _presentation_actor(events: Array[CombatEvent]) -> String:
	for event: CombatEvent in events:
		match event.kind:
			CombatEvent.Kind.STEPPED, CombatEvent.Kind.SWAPPED, CombatEvent.Kind.DAMAGE_APPLIED, CombatEvent.Kind.HEALED, CombatEvent.Kind.MISSED, CombatEvent.Kind.GUARD_PLACED, CombatEvent.Kind.PREPARED_STRIKE:
				return event.actor_id
			_:
				pass
	var active := _active_fighter()
	if active == null:
		return ""
	return active.id


func _hide_resolved_rite(event: CombatEvent) -> void:
	if _state == null or _state.prepared == null:
		return
	var prepared: PreparedStrike = _state.prepared
	if prepared.actor_id != event.actor_id:
		return
	if prepared.ability_id != event.ability_id:
		return
	if prepared.target_id != event.other_id:
		return
	_prepared_line = ""
	_prepared_line_set = true


func _reset_shown_board() -> void:
	_position_override.clear()
	_hp_override.clear()
	_guard_override.clear()
	_hidden.clear()
	_prepared_line = ""
	_prepared_line_set = false


func _refresh_actions(active: CombatantState, player_turn: bool) -> void:
	var key := _actions_signature(active, player_turn)
	if key == _actions_key:
		return
	_actions_key = key
	for child in _ability_row.get_children():
		child.queue_free()
	if not player_turn or active == null:
		return
	_add_action_button("Крок", "", _selected_ability_id == "", true)
	for ability_id: String in active.ability_ids:
		var ability := AbilityCatalog.definition(ability_id)
		if ability == null:
			continue
		var left := int(active.cooldown_left.get(ability_id, 0))
		var usable := left == 0 and not _legal_targets_for(active, ability_id).is_empty()
		var caption := ability.label if left == 0 else "%s · %d" % [ability.label, left]
		_add_action_button(caption, ability_id, _selected_ability_id == ability_id, usable, ability.hint)


func _actions_signature(active: CombatantState, player_turn: bool) -> String:
	if not player_turn or active == null:
		return ""
	var parts := PackedStringArray()
	parts.append(active.id)
	parts.append(_selected_ability_id)
	var slots := PackedStringArray()
	for slot: int in _allowed_slots(active):
		slots.append(str(slot))
	parts.append(",".join(slots))
	for ability_id: String in active.ability_ids:
		var left := int(active.cooldown_left.get(ability_id, 0))
		if left > 0 or _legal_targets_for(active, ability_id).is_empty():
			parts.append("%s:off:%d" % [ability_id, left])
		else:
			parts.append(ability_id)
	return "|".join(parts)


func _add_action_button(label: String, ability_id: String, selected: bool, enabled: bool, hint: String = "") -> void:
	var button := Button.new()
	button.text = label
	button.disabled = not enabled
	button.tooltip_text = hint
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(156, 40)
	button.pressed.connect(_on_action_pressed.bind(ability_id))
	var fill := Color(0.24, 0.2, 0.16, 1) if selected else COLOR_EMPTY
	var border := COLOR_ACTIVE if selected else COLOR_BORDER
	_apply_style(button, fill, border, 3 if selected else 2, COLOR_TEXT, 18)
	_ability_row.add_child(button)


func _legal_targets(active: CombatantState) -> Array[Vector2i]:
	return _legal_targets_for(active, _selected_ability_id)


func _legal_targets_for(active: CombatantState, ability_id: String) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	if ability_id == "" or _state == null:
		return found
	for fighter: CombatantState in _state.combatants:
		var command := _ability_command(active.id, ability_id, fighter.id)
		if _rules.validate_ability(command, _state) == CombatResult.Rejection.NONE:
			found.append(Vector2i(int(fighter.side), fighter.position))
	return found


func _prepared_sentence() -> String:
	if _prepared_line_set:
		return _prepared_line
	if _state == null or _state.prepared == null:
		return ""
	var strike: PreparedStrike = _state.prepared
	return "%s готує удар по %s на %d." % [
		_name_of(strike.actor_id),
		_name_of(strike.target_id),
		strike.amount,
	]


func _attack_preview_sentence(active: CombatantState) -> String:
	if active == null or _selected_ability_id == "" or _state == null:
		return ""
	var ability := AbilityCatalog.definition(_selected_ability_id)
	if ability == null or not ability.hits_enemies:
		return ""
	var lines := PackedStringArray()
	for cell: FormationCell in _cells:
		var fighter := _fighter_at(cell.side, cell.slot)
		if fighter == null:
			continue
		var command := _ability_command(active.id, _selected_ability_id, fighter.id)
		if _rules.validate_ability(command, _state) != CombatResult.Rejection.NONE:
			continue
		var preview: AttackPreview = _rules.preview_attack(command, _state)
		if preview == null or _preview_is_blank(preview):
			continue
		lines.append("%s: влучання %d%%, шкода %d, блок %d%%" % [
			_name_of(fighter.id),
			preview.hit_chance,
			preview.damage_on_hit,
			preview.block_chance,
		])
	return "\n".join(lines)


func _preview_is_blank(preview: AttackPreview) -> bool:
	return (
		preview.hit_chance == 0
		and preview.block_chance == 0
		and preview.damage_on_hit == 0
		and preview.damage_if_blocked == 0
		and preview.guard_reduction == 0
	)


func _remember_reaction(event: CombatEvent) -> void:
	_hits.erase(event.other_id)
	_misses.erase(event.other_id)
	_heals.erase(event.other_id)
	match event.kind:
		CombatEvent.Kind.DAMAGE_APPLIED:
			if _hit_was_blocked(event.mitigation):
				_hits[event.other_id] = "Блок −%d" % event.amount
			else:
				_hits[event.other_id] = "−%d" % event.amount
		CombatEvent.Kind.MISSED:
			_misses[event.other_id] = "Промах"
		CombatEvent.Kind.HEALED:
			_heals[event.other_id] = "+%d" % event.amount


func _hit_was_blocked(mitigation: CombatEvent.Mitigation) -> bool:
	return (
		mitigation == CombatEvent.Mitigation.BLOCK
		or mitigation == CombatEvent.Mitigation.BLOCK_AND_GUARD
	)


func _allowed_slots(active: CombatantState) -> Array[int]:
	var allowed: Array[int] = []
	for slot: int in HERO_COLUMNS:
		var rejection := _rules.validate(_step_command(active.id, slot), _state)
		if rejection == CombatResult.Rejection.NONE:
			allowed.append(slot)
	return allowed


func _refresh() -> void:
	var active := _active_fighter()
	var active_id := ""
	if active != null:
		active_id = active.id
	if active_id != _action_owner_id:
		_action_owner_id = active_id
		_selected_ability_id = ""
	var player_turn := (
		not _playing
		and not _input_locked
		and active != null
		and active.side == CombatantState.Side.HEROES
	)
	_refresh_actions(active, player_turn)
	_turn_label.text = _turn_markup()
	_notice_label.text = _notice
	_notice_label.visible = not _notice_label.text.is_empty()
	_prepared_label.text = _prepared_sentence()
	_prepared_label.visible = not _prepared_label.text.is_empty()
	var preview_text := ""
	if player_turn:
		preview_text = _attack_preview_sentence(active)
	_preview_label.text = preview_text
	_preview_label.visible = not preview_text.is_empty()
	_event_log.text = _log_markup()
	_scroll_log_to_end.call_deferred()
	var allowed: Array[int] = []
	var targets: Array[Vector2i] = []
	if player_turn and _selected_ability_id == "":
		allowed = _allowed_slots(active)
	elif player_turn:
		targets = _legal_targets(active)
	for cell: FormationCell in _cells:
		_paint_cell(cell, active, player_turn, allowed, targets)
	_refresh_stats_window()


func _paint_cell(
	cell: FormationCell,
	active: CombatantState,
	player_turn: bool,
	allowed: Array[int],
	targets: Array[Vector2i]
) -> void:
	var fighter := _fighter_at(cell.side, cell.slot)
	var is_active := active != null and fighter != null and fighter.id == active.id
	var is_target := targets.has(Vector2i(int(cell.side), cell.slot))
	var is_allowed := cell.side == CombatantState.Side.HEROES and allowed.has(cell.slot)
	var is_refused := _refused_slot == cell.slot and _refused_side == cell.side
	if _playing:
		is_active = fighter != null and fighter.id == _focus_actor_id
		is_target = fighter != null and fighter.id == _focus_target_id and not is_active
		is_allowed = false
		is_refused = false
	_fill_cell(cell, fighter, is_active)
	if not player_turn:
		cell.button.disabled = true
	elif _selected_ability_id == "":
		cell.button.disabled = cell.side != CombatantState.Side.HEROES
	else:
		cell.button.disabled = not is_target
	var fill := COLOR_EMPTY
	var font := COLOR_TEXT_DIM
	if fighter != null:
		font = COLOR_TEXT
		if fighter.side == CombatantState.Side.HEROES:
			fill = COLOR_HERO
		else:
			fill = COLOR_ENEMY
	if is_allowed:
		fill = fill.lerp(Color(0.22, 0.34, 0.2, 1), 0.65)
	var border := COLOR_BORDER
	var width := 2
	if is_active:
		border = COLOR_OUTLINE
		width = 3
	if is_allowed:
		border = COLOR_VALID
		width = 3
	if is_target:
		border = COLOR_TARGET
		width = 3
	if is_refused:
		border = COLOR_REFUSED
		width = 3
	var flashing := fighter != null and _flash_ids.has(fighter.id)
	if flashing:
		fill = fill.lightened(0.48)
	_apply_style(cell.button, fill, border, width, font)
	cell.button.modulate = Color(1.35, 1.28, 1.05, 1) if flashing else Color.WHITE
	_pose_card(cell, is_active and fighter != null)
	if fighter != null and fighter.id == _shake_id:
		_shake_id = ""
		_nudge_block(cell)


func _center_card(button: Button) -> void:
	var next := button.size * 0.5
	if button.pivot_offset.distance_to(next) < 0.5:
		return
	button.pivot_offset = next


func _pose_card(cell: FormationCell, lifted: bool) -> void:
	var button := cell.button
	_center_card(button)
	button.scale = Vector2(1.08, 1.08) if lifted else Vector2.ONE
	button.rotation = deg_to_rad(-6.0) if lifted else 0.0
	button.z_index = 4 if lifted else 0
	cell.accent.visible = lifted


func _fill_cell(cell: FormationCell, fighter: CombatantState, _is_active: bool) -> void:
	cell.button.text = ""
	cell.hp_fill.color = COLOR_HP
	if fighter == null:
		cell.portrait.texture = null
		cell.portrait.visible = false
		cell.name_label.text = ""
		cell.hp_fill.anchor_right = 0.0
		return
	cell.portrait.visible = true
	cell.portrait.texture = _portraits.get(fighter.id) as Texture2D
	cell.name_label.text = _name_of(fighter.id)
	cell.name_label.add_theme_color_override("font_color", COLOR_TEXT)
	var hp := _shown_hp(fighter)
	var ceiling := fighter.max_hp
	if ceiling < hp:
		ceiling = hp
	var ratio := 0.0
	if ceiling > 0:
		ratio = clampf(float(hp) / float(ceiling), 0.0, 1.0)
	cell.hp_fill.anchor_right = ratio


func _apply_style(button: Button, fill: Color, border: Color, width: int, font: Color, font_size: int = 22) -> void:
	button.add_theme_stylebox_override("normal", _stylebox(fill, border, width))
	button.add_theme_stylebox_override("hover", _stylebox(fill.lightened(0.08), border, width))
	button.add_theme_stylebox_override("pressed", _stylebox(fill.darkened(0.08), border, width))
	button.add_theme_stylebox_override("disabled", _stylebox(fill.darkened(0.05), border.darkened(0.15), width))
	button.add_theme_stylebox_override("focus", _stylebox(fill, border, width))
	button.add_theme_color_override("font_color", font)
	button.add_theme_color_override("font_hover_color", font)
	button.add_theme_color_override("font_pressed_color", font)
	button.add_theme_color_override("font_disabled_color", font.darkened(0.15))
	button.add_theme_font_size_override("font_size", font_size)


func _stylebox(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(6)
	box.set_content_margin_all(0)
	return box


func _turn_markup() -> String:
	if _state == null:
		return "Бій ще не зібрано."
	var round_text := "Раунд %d" % _state.round_number
	if _state.outcome != CombatState.Outcome.ONGOING:
		return "[center]%s. %s[/center]" % [round_text, _outcome_sentence(_state.outcome)]
	if _state.turn_queue.is_empty():
		return "[center]%s. Черга порожня.[/center]" % round_text
	var active_id := ""
	if _playing and _focus_actor_id != "":
		active_id = _focus_actor_id
	else:
		var active := _active_fighter()
		if active != null:
			active_id = active.id
		else:
			active_id = _state.turn_queue[0]
	var names := PackedStringArray()
	for fighter_id: String in _state.turn_queue:
		var shown := _bbcode_escape(_name_of(fighter_id))
		if fighter_id == active_id:
			names.append("[color=%s][u]%s[/u][/color]" % [TURN_BLUE, shown])
		else:
			var color := LOG_ENEMY_COLOR if _side_of(fighter_id) == CombatantState.Side.ENEMIES else LOG_ALLY_COLOR
			names.append("[color=%s]%s[/color]" % [color, shown])
	return "[center]%s    %s[/center]" % [round_text, "    ".join(names)]


func _record_exchange(events: Array[CombatEvent]) -> void:
	if events.is_empty():
		_append_bbcode("[color=%s]Хід прийнято.[/color]" % LOG_NOTE_COLOR)
		return
	var allies := PackedStringArray()
	var enemies := PackedStringArray()
	var notes := PackedStringArray()
	for event: CombatEvent in events:
		match event.kind:
			CombatEvent.Kind.DAMAGE_APPLIED:
				_note_damage(event, allies, enemies)
			CombatEvent.Kind.MISSED:
				_note_miss(event, allies, enemies)
			CombatEvent.Kind.HEALED:
				allies.append("%s: %s +%d, здоров'я %d" % [
					_name_of(event.actor_id),
					_ability_label(event.ability_id),
					event.amount,
					event.resulting_hp,
				])
			CombatEvent.Kind.GUARD_PLACED:
				allies.append("%s: %s для %s" % [
					_name_of(event.actor_id),
					_ability_label(event.ability_id),
					_name_of(event.other_id),
				])
			CombatEvent.Kind.PREPARED_STRIKE:
				allies.append(_name_of(event.other_id))
				enemies.append("%s готує удар на %d" % [_name_of(event.actor_id), event.amount])
			CombatEvent.Kind.STEPPED:
				_put_for_actor(event.actor_id, "%s на позицію %d" % [_name_of(event.actor_id), event.to_position], allies, enemies)
			CombatEvent.Kind.SWAPPED:
				allies.append("%s міняється з %s" % [_name_of(event.actor_id), _name_of(event.other_id)])
			CombatEvent.Kind.REMOVED_FROM_BATTLE:
				_note_exit(event, allies, enemies)
			CombatEvent.Kind.ROUND_STARTED:
				notes.append("Раунд %d" % event.round_number)
			CombatEvent.Kind.BATTLE_ENDED:
				notes.append(_outcome_sentence(event.outcome))
			_:
				pass
	if not allies.is_empty() or not enemies.is_empty():
		_append_bbcode(_paint_exchange(allies, enemies))
	for note: String in notes:
		_append_bbcode("[color=%s]%s[/color]" % [LOG_NOTE_COLOR, _bbcode_escape(note)])


func _note_damage(event: CombatEvent, allies: PackedStringArray, enemies: PackedStringArray) -> void:
	var wound := "−%d, здоров'я %d" % [event.amount, event.resulting_hp]
	if _hit_was_blocked(event.mitigation):
		wound = "блок −%d, здоров'я %d" % [event.amount, event.resulting_hp]
	var attack := "%s: %s%s" % [_name_of(event.actor_id), _ability_label(event.ability_id), _listed_reason(event)]
	var victim := "%s %s" % [_name_of(event.other_id), wound]
	if _side_of(event.actor_id) == CombatantState.Side.ENEMIES:
		allies.append(victim)
		enemies.append(attack)
	else:
		allies.append(attack)
		enemies.append(victim)


func _note_miss(event: CombatEvent, allies: PackedStringArray, enemies: PackedStringArray) -> void:
	var attack := "%s: %s" % [_name_of(event.actor_id), _ability_label(event.ability_id)]
	var victim := "%s, промах" % _name_of(event.other_id)
	if _side_of(event.actor_id) == CombatantState.Side.ENEMIES:
		allies.append(victim)
		enemies.append(attack)
	else:
		allies.append(attack)
		enemies.append(victim)


func _note_exit(event: CombatEvent, allies: PackedStringArray, enemies: PackedStringArray) -> void:
	var bucket := enemies if event.side == CombatantState.Side.ENEMIES else allies
	if bucket.is_empty():
		bucket.append("%s вибуває" % _name_of(event.actor_id))
		return
	bucket[bucket.size() - 1] = "%s, вибуває" % str(bucket[bucket.size() - 1])


func _put_for_actor(actor_id: String, text: String, allies: PackedStringArray, enemies: PackedStringArray) -> void:
	if _side_of(actor_id) == CombatantState.Side.ENEMIES:
		enemies.append(text)
	else:
		allies.append(text)


func _paint_exchange(allies: PackedStringArray, enemies: PackedStringArray) -> String:
	var left := _bbcode_escape(", ".join(allies))
	var right := _bbcode_escape(", ".join(enemies))
	if not left.is_empty() and not right.is_empty():
		return "[color=%s]%s[/color] — [color=%s]%s[/color]" % [LOG_ALLY_COLOR, left, LOG_ENEMY_COLOR, right]
	if not left.is_empty():
		return "[color=%s]%s[/color]" % [LOG_ALLY_COLOR, left]
	return "[color=%s]%s[/color]" % [LOG_ENEMY_COLOR, right]


func _append_bbcode(bbcode: String) -> void:
	_log_entries.append({"bbcode": bbcode})


func _log_markup() -> String:
	if _log_entries.is_empty():
		return "[color=%s]Поки що подій немає.[/color]" % LOG_NOTE_COLOR
	var parts := PackedStringArray()
	for entry: Dictionary in _log_entries:
		parts.append(str(entry["bbcode"]))
	return "\n".join(parts)


func _bbcode_escape(text: String) -> String:
	return text.replace("[", "[lb]")


func _scroll_log_to_end() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_inside_tree() or not is_instance_valid(_event_log):
		return
	var lines := _event_log.get_line_count()
	if lines > 0:
		_event_log.scroll_to_line(lines - 1)


func _event_line(event: CombatEvent) -> String:
	match event.kind:
		CombatEvent.Kind.STEPPED:
			return "%s ступає з позиції %d на %d." % [
				_name_of(event.actor_id),
				event.from_position,
				event.to_position,
			]
		CombatEvent.Kind.SWAPPED:
			return "%s міняється з %s: %s тепер на %d, %s на %d." % [
				_name_of(event.actor_id),
				_name_of(event.other_id),
				_name_of(event.actor_id),
				event.to_position,
				_name_of(event.other_id),
				event.from_position,
			]
		CombatEvent.Kind.DAMAGE_APPLIED:
			return "%s: %s%s по %s на %d. Здоров'я %d." % [
				_name_of(event.actor_id),
				_ability_label(event.ability_id),
				_listed_reason(event),
				_name_of(event.other_id),
				event.amount,
				event.resulting_hp,
			]
		CombatEvent.Kind.HEALED:
			return "%s: %s для %s на %d. Здоров'я %d." % [
				_name_of(event.actor_id),
				_ability_label(event.ability_id),
				_name_of(event.other_id),
				event.amount,
				event.resulting_hp,
			]
		CombatEvent.Kind.REMOVED_FROM_BATTLE:
			return "%s (%s) вибуває з бою з позиції %d." % [
				_name_of(event.actor_id),
				_side_name(event.side),
				event.from_position,
			]
		CombatEvent.Kind.FORMATION_SHIFTED:
			return _formation_line(event)
		CombatEvent.Kind.ROUND_STARTED:
			return "Починається раунд %d. Черга: %s." % [
				event.round_number,
				_names_of(event.turn_queue),
			]
		CombatEvent.Kind.BATTLE_ENDED:
			return "Бій закінчено. %s" % _outcome_sentence(event.outcome)
		CombatEvent.Kind.PREPARED_STRIKE:
			return "%s готує удар по %s на %d." % [
				_name_of(event.actor_id),
				_name_of(event.other_id),
				event.amount,
			]
		CombatEvent.Kind.MISSED:
			return "%s промахується: «%s» по %s." % [
				_name_of(event.actor_id),
				_ability_label(event.ability_id),
				_name_of(event.other_id),
			]
		CombatEvent.Kind.GUARD_PLACED:
			return "%s: %s для %s. Запас %d." % [
				_name_of(event.actor_id),
				_ability_label(event.ability_id),
				_name_of(event.other_id),
				event.amount,
			]
		_:
			return "Подія бою."


func _formation_line(event: CombatEvent) -> String:
	var parts := PackedStringArray()
	for shift: PositionShift in event.shifts:
		parts.append("%s з %d на %d" % [_name_of(shift.combatant_id), shift.from_position, shift.to_position])
	var detail := ", ".join(parts)
	if detail.is_empty():
		detail = "позиції без переліку"
	return "Лава (%s) зсувається: %s." % [_side_name(event.side), detail]


func _rejection_sentence(reason: CombatResult.Rejection) -> String:
	match reason:
		CombatResult.Rejection.BATTLE_FINISHED:
			return "Дію відхилено: бій уже завершено."
		CombatResult.Rejection.UNKNOWN_ACTOR:
			return "Дію відхилено: цього учасника немає в бою."
		CombatResult.Rejection.NOT_ACTIVE_TURN:
			return "Дію відхилено: зараз хід іншого учасника."
		CombatResult.Rejection.POSITION_OUT_OF_RANGE:
			return "Дію відхилено: позиція поза полем."
		CombatResult.Rejection.NOT_ADJACENT:
			return "Дію відхилено: ця клітина не є сусідньою."
		CombatResult.Rejection.UNKNOWN_ABILITY:
			return "Дію відхилено: цієї здібності немає."
		CombatResult.Rejection.ACTOR_OUT_OF_POSITION:
			return "Дію відхилено: з цієї позиції здібність недоступна."
		CombatResult.Rejection.ILLEGAL_TARGET:
			return "Дію відхилено: ця ціль недоступна."
		CombatResult.Rejection.ON_COOLDOWN:
			return "Дію відхилено: здібність ще перезаряджається."
		CombatResult.Rejection.CALCULATION_FAILED:
			return "Дію відхилено: бій не зміг порахувати цей удар."
		_:
			return "Дію відхилено."


func _outcome_sentence(outcome: CombatState.Outcome) -> String:
	match outcome:
		CombatState.Outcome.HEROES_VICTORIOUS:
			return "Перемога героїв."
		CombatState.Outcome.HEROES_DEFEATED:
			return "Поразка героїв."
		_:
			return "Бій триває."


func _remember_names() -> void:
	if _state == null:
		return
	for fighter: CombatantState in _state.combatants:
		if fighter.display_name != "":
			_names[fighter.id] = fighter.display_name
		_sides[fighter.id] = fighter.side


func _side_of(fighter_id: String) -> CombatantState.Side:
	if _sides.has(fighter_id):
		return _sides[fighter_id] as CombatantState.Side
	var fighter := _fighter_by_id(fighter_id)
	if fighter != null:
		return fighter.side
	return CombatantState.Side.HEROES


func _name_of(fighter_id: String) -> String:
	if _names.has(fighter_id):
		return str(_names[fighter_id])
	var fighter := _fighter_by_id(fighter_id)
	if fighter != null and fighter.display_name != "":
		return fighter.display_name
	return fighter_id


func _names_of(ids: Array[String]) -> String:
	var parts := PackedStringArray()
	for fighter_id: String in ids:
		parts.append(_name_of(fighter_id))
	return ", ".join(parts)


## Reads the listed number the rules already chose. Does not decide the threshold again.
func _listed_reason(event: CombatEvent) -> String:
	var ability := AbilityCatalog.definition(event.ability_id)
	if ability == null or ability.finish_amount <= 0:
		return ""
	if event.listed_amount == ability.finish_amount:
		return ", %d бо здоров'я було не вище половини" % event.listed_amount
	if event.listed_amount == ability.amount:
		return ", %d бо здоров'я було вище половини" % event.listed_amount
	return ""


func _ability_label(ability_id: String) -> String:
	var ability := AbilityCatalog.definition(ability_id)
	if ability == null or ability.label == "":
		return ability_id
	return ability.label


func _side_name(side: CombatantState.Side) -> String:
	if side == CombatantState.Side.HEROES:
		return "герої"
	return "вороги"


func _active_fighter() -> CombatantState:
	if _state == null or _state.outcome != CombatState.Outcome.ONGOING:
		return null
	if _state.turn_queue.is_empty():
		return null
	return _fighter_by_id(_state.turn_queue[0])


func _fighter_by_id(fighter_id: String) -> CombatantState:
	if _state == null:
		return null
	for fighter: CombatantState in _state.combatants:
		if fighter.id == fighter_id:
			return fighter
	return null


func _fighter_at(side: CombatantState.Side, slot: int) -> CombatantState:
	if _state == null:
		return null
	for fighter: CombatantState in _state.combatants:
		if _hidden.has(fighter.id):
			continue
		if fighter.side == side and _shown_position(fighter) == slot:
			return fighter
	return null


func _shown_position(fighter: CombatantState) -> int:
	if _position_override.has(fighter.id):
		return int(_position_override[fighter.id])
	return fighter.position


func _shown_hp(fighter: CombatantState) -> int:
	if _hp_override.has(fighter.id):
		return int(_hp_override[fighter.id])
	return fighter.hp


func _shown_guard(fighter: CombatantState) -> int:
	if _guard_override.has(fighter.id):
		return int(_guard_override[fighter.id])
	return fighter.guard_reduction


func _log_startup() -> void:
	print("Combat UI turn: ", _turn_label.text)
	if _state != null:
		print("Combat UI queue: ", ", ".join(_state.turn_queue))
	if not _notice.is_empty():
		print("Combat UI notice: ", _notice)
