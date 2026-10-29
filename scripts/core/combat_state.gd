class_name CombatState
extends RefCounted

## Battle snapshot owned by the combat module. UI reads it and does not mutate it.

enum Outcome {
	ONGOING,
	HEROES_VICTORIOUS,
	HEROES_DEFEATED,
}

## Opening round is 1. A new round rebuilds turn_queue.
var round_number: int

## Fighters still in this battle. An empty slot is a missing entry, not a placeholder.
## At most CombatantState.POSITIONS_PER_SIDE per side. A short side is valid.
var combatants: Array[CombatantState]

## Ids that have not acted yet this round, earliest first.
## The first id is the active turn. Removed fighters are absent.
var turn_queue: Array[String]

## ONGOING only while both sides still have someone left.
var outcome: CombatState.Outcome

## The one prepared strike in this battle. Null means none is stored.
var prepared: PreparedStrike


func _init() -> void:
	round_number = 1
	combatants = []
	turn_queue = []
	outcome = CombatState.Outcome.ONGOING
	prepared = null
