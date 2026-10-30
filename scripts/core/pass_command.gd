class_name PassCommand
extends RefCounted

## Ends the active fighter's own turn without moving or using an ability.
## Cooldowns and effects count it as an own turn. It never rolls.

## Must be the id at the front of CombatState.turn_queue.
var actor_id: String


func _init() -> void:
	actor_id = ""
