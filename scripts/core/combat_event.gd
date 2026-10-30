class_name CombatEvent
extends RefCounted

## One fact the battle already resolved. UI plays these and does not decide them.
## Build events with the static methods. Fields that belong to another kind stay unused.

enum Kind {
	STEPPED,
	SWAPPED,
	REMOVED_FROM_BATTLE,
	FORMATION_SHIFTED,
	ROUND_STARTED,
	BATTLE_ENDED,
	DAMAGE_APPLIED,
	HEALED,
	PREPARED_STRIKE,
	MISSED,
	GUARD_PLACED,
	EFFECT_APPLIED,
	EFFECT_EXPIRED,
}

## How a landed hit was reduced. NONE means the listed hit was not reduced.
enum Mitigation {
	NONE,
	BLOCK,
	GUARD,
	BLOCK_AND_GUARD,
}

var kind: CombatEvent.Kind
var actor_id: String
var other_id: String
var ability_id: String
var amount: int
var resulting_hp: int
var side: CombatantState.Side
var from_position: int
var to_position: int
var shifts: Array[PositionShift]
var round_number: int
var turn_queue: Array[String]
var outcome: CombatState.Outcome
var mitigation: CombatEvent.Mitigation
## Ability damage after armor, before block, cover, and the remaining-health cap. 0 when unused.
## With armor 0 and neutral stats this is the number from the ability card.
var listed_amount: int
## Set on EFFECT_APPLIED and EFFECT_EXPIRED. Empty for every other kind.
var effect_id: String


func _init() -> void:
	kind = CombatEvent.Kind.STEPPED
	actor_id = ""
	other_id = ""
	ability_id = ""
	amount = 0
	resulting_hp = 0
	side = CombatantState.Side.HEROES
	from_position = 0
	to_position = 0
	shifts = []
	round_number = 0
	turn_queue = []
	outcome = CombatState.Outcome.ONGOING
	mitigation = CombatEvent.Mitigation.NONE
	listed_amount = 0
	effect_id = ""


static func stepped(actor_id: String, from_position: int, to_position: int) -> CombatEvent:
	var event := CombatEvent.new()
	event.kind = CombatEvent.Kind.STEPPED
	event.actor_id = actor_id
	event.from_position = from_position
	event.to_position = to_position
	return event


static func swapped(
	actor_id: String,
	other_id: String,
	from_position: int,
	to_position: int
) -> CombatEvent:
	var event := CombatEvent.new()
	event.kind = CombatEvent.Kind.SWAPPED
	event.actor_id = actor_id
	event.other_id = other_id
	event.from_position = from_position
	event.to_position = to_position
	return event


## Leaving this battle because hp reached 0. Not campaign death.
static func removed_from_battle(
	actor_id: String,
	side: CombatantState.Side,
	from_position: int
) -> CombatEvent:
	var event := CombatEvent.new()
	event.kind = CombatEvent.Kind.REMOVED_FROM_BATTLE
	event.actor_id = actor_id
	event.side = side
	event.from_position = from_position
	return event


static func formation_shifted(side: CombatantState.Side, shifts: Array[PositionShift]) -> CombatEvent:
	var event := CombatEvent.new()
	event.kind = CombatEvent.Kind.FORMATION_SHIFTED
	event.side = side
	event.shifts.assign(shifts)
	return event


static func round_started(round_number: int, turn_queue: Array[String]) -> CombatEvent:
	var event := CombatEvent.new()
	event.kind = CombatEvent.Kind.ROUND_STARTED
	event.round_number = round_number
	event.turn_queue.assign(turn_queue)
	return event


## amount is HP actually removed. listed_amount defaults to 0. mitigation defaults to NONE.
## resulting_hp is health after the hit, already at 0 when it kills.
static func damage_applied(
	actor_id: String,
	ability_id: String,
	target_id: String,
	amount: int,
	resulting_hp: int,
	listed_amount: int = 0,
	mitigation: CombatEvent.Mitigation = CombatEvent.Mitigation.NONE
) -> CombatEvent:
	var event := CombatEvent.new()
	event.kind = CombatEvent.Kind.DAMAGE_APPLIED
	event.actor_id = actor_id
	event.ability_id = ability_id
	event.other_id = target_id
	event.amount = amount
	event.resulting_hp = resulting_hp
	event.listed_amount = listed_amount
	event.mitigation = mitigation
	return event


## amount is the stored damage. No health changes on this event.
static func prepared_strike(
	actor_id: String,
	ability_id: String,
	target_id: String,
	amount: int
) -> CombatEvent:
	var event := CombatEvent.new()
	event.kind = CombatEvent.Kind.PREPARED_STRIKE
	event.actor_id = actor_id
	event.ability_id = ability_id
	event.other_id = target_id
	event.amount = amount
	return event


static func missed(actor_id: String, ability_id: String, target_id: String) -> CombatEvent:
	var event := CombatEvent.new()
	event.kind = CombatEvent.Kind.MISSED
	event.actor_id = actor_id
	event.ability_id = ability_id
	event.other_id = target_id
	return event


## amount is the cover now stored on the target.
static func guard_placed(
	actor_id: String,
	ability_id: String,
	target_id: String,
	amount: int
) -> CombatEvent:
	var event := CombatEvent.new()
	event.kind = CombatEvent.Kind.GUARD_PLACED
	event.actor_id = actor_id
	event.ability_id = ability_id
	event.other_id = target_id
	event.amount = amount
	return event


## amount is health actually gained. resulting_hp does not exceed max_hp.
static func healed(
	actor_id: String,
	ability_id: String,
	target_id: String,
	amount: int,
	resulting_hp: int
) -> CombatEvent:
	var event := CombatEvent.new()
	event.kind = CombatEvent.Kind.HEALED
	event.actor_id = actor_id
	event.ability_id = ability_id
	event.other_id = target_id
	event.amount = amount
	event.resulting_hp = resulting_hp
	return event


## amount is the magnitude. resulting_hp is the turns left after this application.
static func effect_applied(
	source_id: String,
	target_id: String,
	effect_id: String,
	magnitude: int,
	turns_left: int
) -> CombatEvent:
	var event := CombatEvent.new()
	event.kind = CombatEvent.Kind.EFFECT_APPLIED
	event.actor_id = source_id
	event.other_id = target_id
	event.effect_id = effect_id
	event.amount = magnitude
	event.resulting_hp = turns_left
	return event


## amount is the magnitude that just stopped applying.
static func effect_expired(target_id: String, effect_id: String, magnitude: int) -> CombatEvent:
	var event := CombatEvent.new()
	event.kind = CombatEvent.Kind.EFFECT_EXPIRED
	event.actor_id = target_id
	event.effect_id = effect_id
	event.amount = magnitude
	return event


static func battle_ended(outcome: CombatState.Outcome) -> CombatEvent:
	var event := CombatEvent.new()
	event.kind = CombatEvent.Kind.BATTLE_ENDED
	event.outcome = outcome
	return event
