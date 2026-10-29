class_name PositionShift
extends RefCounted

## One living fighter whose position number changed when a side compacted forward.

var combatant_id: String
var from_position: int
var to_position: int


func _init() -> void:
	combatant_id = ""
	from_position = 0
	to_position = 0
