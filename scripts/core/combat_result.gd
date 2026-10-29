class_name CombatResult
extends RefCounted

## Accepted work carries a new state and events.
## A rejection carries a reason, the same state object, and no events.

enum Rejection {
	NONE,
	BATTLE_FINISHED,
	UNKNOWN_ACTOR,
	NOT_ACTIVE_TURN,
	POSITION_OUT_OF_RANGE,
	NOT_ADJACENT,
	UNKNOWN_ABILITY,
	ACTOR_OUT_OF_POSITION,
	ILLEGAL_TARGET,
	ON_COOLDOWN,
}

var accepted: bool
var rejection: CombatResult.Rejection
var state: CombatState
var events: Array[CombatEvent]


func _init() -> void:
	accepted = false
	rejection = CombatResult.Rejection.NONE
	state = null
	events = []


static func rejected(state: CombatState, rejection: CombatResult.Rejection) -> CombatResult:
	assert(state != null)
	assert(rejection != CombatResult.Rejection.NONE)
	var result := CombatResult.new()
	result.accepted = false
	result.rejection = rejection
	result.state = state
	return result


static func resolved(state: CombatState, events: Array[CombatEvent]) -> CombatResult:
	assert(state != null)
	var result := CombatResult.new()
	result.accepted = true
	result.rejection = CombatResult.Rejection.NONE
	result.state = state
	result.events.assign(events)
	return result
