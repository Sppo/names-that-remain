extends Control

const COMBAT_SCENE := preload("res://scenes/combat/combat_screen.tscn")
## Development entry to the separate new-model battle. The control battle stays on the first button.
const NEW_BATTLE_SCENE := preload("res://scenes/combat/battle/battle_scene.tscn")


func _ready() -> void:
	$EnterBattle.pressed.connect(_on_enter_battle_pressed)
	$EnterNewBattle.pressed.connect(_on_enter_new_battle_pressed)


func _on_enter_battle_pressed() -> void:
	get_tree().change_scene_to_packed(COMBAT_SCENE)


func _on_enter_new_battle_pressed() -> void:
	get_tree().change_scene_to_packed(NEW_BATTLE_SCENE)
