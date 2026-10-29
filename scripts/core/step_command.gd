class_name StepCommand
extends RefCounted

## One step to a neighboring slot on the actor's own side. It never attacks.

## Must be the id at the front of CombatState.turn_queue.
var actor_id: String

## Neighboring position on the actor's side.
## An ally standing there swaps places. The old slot stays empty when nobody does.
var destination_position: int


func _init() -> void:
	actor_id = ""
	destination_position = 0
