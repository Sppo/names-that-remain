class_name PreparedStrike
extends RefCounted

## One stored strike for the whole battle. CombatState.prepared is null when none is waiting.
## Strings start empty. amount is the stored damage and starts at 0.

var actor_id: String
var ability_id: String
var target_id: String
var amount: int


func _init() -> void:
	actor_id = ""
	ability_id = ""
	target_id = ""
	amount = 0
