class_name BattleHUD
extends CanvasLayer

## Screen overlay of the new battle. Buttons only raise signals; the scene decides what they mean.
## Phase 9A: turn line, a short log, a temporary pass button for the hero, the result and a restart.

signal pass_pressed
signal restart_pressed
signal menu_pressed

const LOG_LINES := 9

@onready var _turn_label: Label = $Root/TurnLabel
@onready var _log: Label = $Root/LogPanel/Log
@onready var _pass_button: Button = $Root/Buttons/PassButton
@onready var _restart_button: Button = $Root/Buttons/RestartButton
@onready var _menu_button: Button = $Root/Buttons/MenuButton
@onready var _result_label: Label = $Root/ResultLabel

var _lines: PackedStringArray = []


func _ready() -> void:
	_pass_button.pressed.connect(func() -> void: pass_pressed.emit())
	_restart_button.pressed.connect(func() -> void: restart_pressed.emit())
	_menu_button.pressed.connect(func() -> void: menu_pressed.emit())
	set_pass_enabled(false)
	hide_result()


func set_turn(text: String) -> void:
	_turn_label.text = text


func set_pass_enabled(enabled: bool) -> void:
	_pass_button.disabled = not enabled


func is_pass_enabled() -> bool:
	return not _pass_button.disabled


func add_log(line: String) -> void:
	_lines.append(line)
	if _lines.size() > LOG_LINES:
		_lines = _lines.slice(_lines.size() - LOG_LINES)
	_log.text = "\n".join(_lines)


func clear_log() -> void:
	_lines = PackedStringArray()
	_log.text = ""


func log_lines() -> PackedStringArray:
	return _lines


func show_result(text: String) -> void:
	_result_label.text = text
	_result_label.visible = true


func hide_result() -> void:
	_result_label.visible = false


func result_text() -> String:
	return _result_label.text if _result_label.visible else ""
