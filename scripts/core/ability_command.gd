class_name AbilityCommand
extends RefCounted

## One ability use. It does not move the actor.
## actor_id must be the id at the front of CombatState.turn_queue.

var actor_id: String
var ability_id: String
var target_id: String
## Own-side position for an ability that moves the actor. 0 means unused. Not read by the rules yet.
var destination_position: int


func _init() -> void:
	actor_id = ""
	ability_id = ""
	target_id = ""
	destination_position = 0
