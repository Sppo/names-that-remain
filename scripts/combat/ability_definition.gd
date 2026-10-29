class_name AbilityDefinition
extends RefCounted

## Prototype ability from docs/COMBAT_SPEC.md. Not campaign balance.

enum Kind {
	STRIKE,
	HEAL,
	GUARD,
	RITE,
}

var id: String
var label: String
var from_min: int
var from_max: int
var target_min: int
var target_max: int
var amount: int
## When above 0, this replaces amount if the target's current HP is at or below finish_below_percent of max HP.
var finish_amount: int
var finish_below_percent: int
## Shown with the ability. Empty for abilities whose one number is the whole rule.
var hint: String
## True: living enemy in the target slots. False: living ally, including the actor.
var hits_enemies: bool
var kind: AbilityDefinition.Kind
## Own turns of this fighter, after a use, before the ability can be chosen again. 0 means every turn.
var cooldown_turns: int


func _init() -> void:
	id = ""
	label = ""
	from_min = CombatantState.FRONT_POSITION
	from_max = CombatantState.REAR_POSITION
	target_min = CombatantState.FRONT_POSITION
	target_max = CombatantState.REAR_POSITION
	amount = 0
	finish_amount = 0
	finish_below_percent = 0
	hint = ""
	hits_enemies = true
	kind = AbilityDefinition.Kind.STRIKE
	cooldown_turns = 0
