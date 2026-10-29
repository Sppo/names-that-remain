class_name CombatantState
extends RefCounted

## One fighter inside a single battle. This is not a campaign hero record.

enum Side {
	HEROES,
	ENEMIES,
}

## Position 1 is the front. Position 4 is the rear.
const FRONT_POSITION: int = 1
const REAR_POSITION: int = 4
const POSITIONS_PER_SIDE: int = 4

## Stable id within the battle. Not a display name and not a node path.
var id: String

var side: CombatantState.Side

## Slot on this fighter's own side, from FRONT_POSITION to REAR_POSITION.
var position: int

## Turn-order input. Higher acts first. Role numbers live in the battle setup.
var speed: int

## Health in this battle. A fighter listed in the battle has hp above 0.
## Reaching 0 removes them from this battle and is not campaign death.
var hp: int

## Heal stops at this value. Damage does not read it.
var max_hp: int

## Name shown for this battle. Empty means the screen may show id.
var display_name: String

## Percentage from 0 to 100 used for the hit chance.
var accuracy: int

## Percentage from 0 to 100 used for the hit chance.
var dodge: int

## Percentage chance to halve damage after a hit lands.
var block: int

## Subtracted from the next hit after block. 0 means this fighter has no cover.
var guard_reduction: int

## Ability id to remaining own turns before it can be used again. Missing or 0 means ready.
var cooldown_left: Dictionary


func _init() -> void:
	id = ""
	side = CombatantState.Side.HEROES
	position = FRONT_POSITION
	speed = 0
	hp = 0
	max_hp = 0
	display_name = ""
	accuracy = 0
	dodge = 0
	block = 0
	guard_reduction = 0
	cooldown_left = {}
