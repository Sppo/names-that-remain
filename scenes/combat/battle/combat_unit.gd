class_name CombatUnit
extends Node2D

## One visible fighter. Shows numbers it is given and never calculates them.
## Placeholder shapes until art arrives; the scene and the rules do not depend on them.

const EFFECT_NAMES := {
	"battle_stance": "Стійка",
	"maneuver_dodge": "Ухилення",
	"resilience_tincture": "Настоянка",
	"combat_stimulant": "Стимулятор",
}

@export var hero_color := Color(0.36, 0.5, 0.72, 1)
@export var enemy_color := Color(0.72, 0.3, 0.28, 1)

var fighter_id: String = ""

@onready var _body: Polygon2D = $Body
@onready var _active_marker: Node2D = $ActiveMarker
@onready var _name_label: Label = $NameLabel
@onready var _hp_bar: ProgressBar = $HpBar
@onready var _hp_label: Label = $HpLabel
@onready var _status_label: Label = $StatusLabel
@onready var _floater: Label = $Floater

var _move_tween: Tween
var _float_tween: Tween
var _max_hp := 0


func setup(id: String, display_name: String, side: CombatantState.Side) -> void:
	fighter_id = id
	name = id
	_name_label.text = display_name if display_name != "" else id
	_body.color = hero_color if side == CombatantState.Side.HEROES else enemy_color
	_floater.visible = false
	_active_marker.visible = false


## Whole state of this fighter as the battle now has it.
func show_fighter(fighter: CombatantState, is_active: bool, rite_target: bool) -> void:
	show_hp(fighter.hp, fighter.max_hp)
	_active_marker.visible = is_active
	var parts := PackedStringArray()
	if fighter.guard_reduction > 0:
		parts.append("Прикрито %d" % fighter.guard_reduction)
	for effect: ActiveEffect in fighter.effects:
		parts.append("%s %+d (%d)" % [EFFECT_NAMES.get(effect.effect_id, effect.effect_id), effect.magnitude, effect.turns_left])
	if rite_target:
		parts.append("Ціль обряду")
	_status_label.text = "\n".join(parts)


func show_hp(hp: int, max_hp: int) -> void:
	_max_hp = max_hp
	_hp_bar.max_value = max_hp
	_hp_bar.value = hp
	_hp_label.text = "%d / %d" % [hp, max_hp]


## Health from an event, against the maximum already shown.
func show_current_hp(hp: int) -> void:
	show_hp(hp, _max_hp)


func shown_hp_text() -> String:
	return _hp_label.text


func move_to(target: Vector2, seconds: float) -> void:
	if _move_tween != null:
		_move_tween.kill()
	if seconds <= 0.0:
		position = target
		return
	_move_tween = create_tween()
	_move_tween.tween_property(self, "position", target, seconds)


func float_text(text: String, color: Color, seconds: float) -> void:
	if _float_tween != null:
		_float_tween.kill()
	# Without time to show it, a word would only stay stuck over the unit.
	if seconds <= 0.0:
		_floater.visible = false
		return
	_floater.text = text
	_floater.modulate = color
	_floater.visible = true
	_floater.position.y = -182.0
	_float_tween = create_tween()
	_float_tween.tween_property(_floater, "position:y", -214.0, seconds)
	_float_tween.tween_callback(_floater.hide)


func show_removed(seconds: float) -> void:
	_active_marker.visible = false
	if seconds <= 0.0:
		modulate.a = 0.0
		return
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, seconds)
