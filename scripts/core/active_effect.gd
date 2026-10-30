class_name ActiveEffect
extends RefCounted

## One effect active on one fighter. Not a definition resource and not a campaign record.
## Same effect_id is the same effect, whoever applied it. Strength is magnitude, with a sign.

enum Kind {
	## Percentage points added to dodge. Not a percent category.
	DODGE_POINTS,
	## Percentage points added to block. The roll caps the total at 95.
	BLOCK_POINTS,
	## Percent added to physical damage dealt, before armor.
	PHYSICAL_DEALT_PERCENT,
	## Percent added to special damage received. Physical strikes do not read it.
	SPECIAL_RECEIVED_PERCENT,
}

var effect_id: String
var kind: ActiveEffect.Kind
var magnitude: int
var turns_left: int
## Applied during the target's current own turn, so that turn's end does not count.
var skips_next_tick: bool


func _init() -> void:
	effect_id = ""
	kind = ActiveEffect.Kind.DODGE_POINTS
	magnitude = 0
	turns_left = 0
	skips_next_tick = false


func duplicate_effect() -> ActiveEffect:
	var copy := ActiveEffect.new()
	copy.effect_id = effect_id
	copy.kind = kind
	copy.magnitude = magnitude
	copy.turns_left = turns_left
	copy.skips_next_tick = skips_next_tick
	return copy
