class_name EnemyAi
extends RefCounted

## Enemy turn. A due prepared strike is played before any other choice.
## Every other legal strike, rite, guard, and step is scored in whole points. Without any offense the turn may be a pass.
## 100 points is 1 health. The chosen command is one validate already accepts.
## choose_action does not roll and does not change the passed state.

const _Utility = preload("res://scripts/combat/enemy_utility.gd")

var _rules: CombatRules


func _init(rules: CombatRules = null) -> void:
	if rules == null:
		_rules = CombatRules.new()
	else:
		_rules = rules


## First legal neighboring step. Not used by take_turn: it is not a fallback for a turn without a choice.
func choose_step(state: CombatState) -> StepCommand:
	var actor := _active_combatant(state)
	var toward_front := actor.position - 1
	var toward_rear := actor.position + 1
	var destinations: Array[int] = []
	if toward_front >= CombatantState.FRONT_POSITION:
		destinations.append(toward_front)
	if toward_rear <= CombatantState.REAR_POSITION:
		destinations.append(toward_rear)

	for index in destinations.size():
		var command := _command(actor.id, destinations[index])
		if _rules.validate(command, state) == CombatResult.Rejection.NONE:
			return command

	# Every slot has a neighbor, so this is not reached. take_turn no longer falls back to a step.
	return null


## Null only when the active fighter's prepared strike still has a living target.
## take_turn plays that strike before this is asked to choose.
func choose_action(state: CombatState) -> Variant:
	var actor := _active_combatant(state)
	if actor == null:
		return null
	if _prepared_will_fire(state, actor):
		return null
	return _Utility.new(_rules).choose(state)


func take_turn(state: CombatState, rng: RandomNumberGenerator) -> CombatResult:
	var actor := _active_combatant(state)
	if actor != null and _prepared_will_fire(state, actor):
		return _rules.resolve_prepared_strike(state, rng)
	if actor != null and state.prepared != null and state.prepared.actor_id == actor.id:
		return _resolve_chosen(_rules.discard_prepared(state), rng)
	return _resolve_chosen(state, rng)


func _prepared_will_fire(state: CombatState, actor: CombatantState) -> bool:
	if state.prepared == null or state.prepared.actor_id != actor.id:
		return false
	return _is_alive(state, state.prepared.target_id)


func _resolve_chosen(state: CombatState, rng: RandomNumberGenerator) -> CombatResult:
	var action: Variant = choose_action(state)
	if action is AbilityCommand:
		return _rules.resolve_ability(action, state, rng)
	if action is StepCommand:
		return _rules.resolve(action, state, rng)
	if action is PassCommand:
		return _rules.resolve_pass(action, state, rng)
	# No active fighter: the pass is rejected without changes.
	var nobody := PassCommand.new()
	if not state.turn_queue.is_empty():
		nobody.actor_id = state.turn_queue[0]
	return _rules.resolve_pass(nobody, state, rng)


func _is_alive(state: CombatState, combatant_id: String) -> bool:
	for index in state.combatants.size():
		var combatant: CombatantState = state.combatants[index]
		if combatant.id == combatant_id:
			return combatant.hp > 0
	return false


func _active_combatant(state: CombatState) -> CombatantState:
	if state.turn_queue.is_empty():
		return null
	var actor_id := state.turn_queue[0]
	for index in state.combatants.size():
		var combatant: CombatantState = state.combatants[index]
		if combatant.id == actor_id:
			return combatant
	return null


func _command(actor_id: String, destination: int) -> StepCommand:
	var command := StepCommand.new()
	command.actor_id = actor_id
	command.destination_position = destination
	return command
