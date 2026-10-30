class_name AbilityDefinition
extends RefCounted

## Prototype ability from docs/COMBAT_SPEC.md. Not campaign balance.

enum Kind {
	STRIKE,
	HEAL,
	GUARD,
	RITE,
	## Puts the card's effect on the target. No rolls.
	EFFECT,
	## Moves the actor to the command's destination_position, then puts the card's effect on the actor. No rolls.
	MANEUVER,
}

## SLOTS: a fighter in the target slots. SELF: the actor only.
## OWN_ADJACENT: the actor only, moving to a neighboring slot of its own side, empty or held by an ally.
enum TargetMode {
	SLOTS,
	SELF,
	OWN_ADJACENT,
}

enum DamageType {
	PHYSICAL,
	SPECIAL,
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

## Fields below feed the strike table in CombatRules. Defaults keep the control card unchanged.
## Heal and guard do not read damage_type. A heal with a knowledge share uses the healing formula on amount.
var damage_type: AbilityDefinition.DamageType
## Both 0: fixed base amount, no roll. Otherwise 1 <= base_min <= base_max.
var base_min: int
var base_max: int
## Stat shares in P, in whole percent. All 0 means no stat scaling, otherwise they sum to 100.
var strength_percent: int
var dexterity_percent: int
var knowledge_percent: int
## Ability multiplier A in whole percent. 100 means 1.0.
var multiplier_percent: int
## Percentage points added to this attack's hit chance before the 5–95 bound.
var accuracy_bonus: int
## A prepared strike lands on a living target without rolls.
var guaranteed_hit: bool

var target_mode: AbilityDefinition.TargetMode
## Effect put on the target by EFFECT and MANEUVER. Empty effect_id means none.
var effect_id: String
var effect_kind: ActiveEffect.Kind
var effect_magnitude: int
## Own turns of the target.
var effect_turns: int
## A landed hit moves a target that is still alive one slot back, swapping with whoever stands there.
var pushes_target: bool


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
	damage_type = AbilityDefinition.DamageType.PHYSICAL
	base_min = 0
	base_max = 0
	strength_percent = 0
	dexterity_percent = 0
	knowledge_percent = 0
	multiplier_percent = 100
	accuracy_bonus = 0
	guaranteed_hit = false
	target_mode = AbilityDefinition.TargetMode.SLOTS
	effect_id = ""
	effect_kind = ActiveEffect.Kind.DODGE_POINTS
	effect_magnitude = 0
	effect_turns = 0
	pushes_target = false
