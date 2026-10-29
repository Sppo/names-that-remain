extends Control

const COMBAT_SCENE := preload("res://scenes/combat/combat_screen.tscn")


func _ready() -> void:
	$EnterBattle.pressed.connect(_on_enter_battle_pressed)


func _on_enter_battle_pressed() -> void:
	get_tree().change_scene_to_packed(COMBAT_SCENE)
