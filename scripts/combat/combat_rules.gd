class_name CombatRules
extends RefCounted

## First-battle rules: one adjacent step or one ability, a speed queue, and removal at hp <= 0.
## Hit and block rolls use only the passed RandomNumberGenerator.
## resolve and resolve_ability do not read scenes.


func validate(command: StepCommand, state: CombatState) -> CombatResult.Rejection:
	if state.outcome != CombatState.Outcome.ONGOING:
		return CombatResult.Rejection.BATTLE_FINISHED

	var actor := _find(state, command.actor_id)
	if actor == null:
		return CombatResult.Rejection.UNKNOWN_ACTOR

	if state.turn_queue.is_empty() or state.turn_queue[0] != actor.id:
		return CombatResult.Rejection.NOT_ACTIVE_TURN

	var destination := command.destination_position
	if destination < CombatantState.FRONT_POSITION or destination > CombatantState.REAR_POSITION:
		return CombatResult.Rejection.POSITION_OUT_OF_RANGE

	if absi(destination - actor.position) != 1:
		return CombatResult.Rejection.NOT_ADJACENT

	return CombatResult.Rejection.NONE


## Copies state on success. A rejection returns the same state object.
## Fighters already at hp <= 0 leave before the step. The step runs only if it is still legal.
## A battle that ends during removal does not spend the command.
## A prepared strike for this actor replaces the command while its target is still alive.
func resolve(command: StepCommand, state: CombatState, rng: RandomNumberGenerator) -> CombatResult:
	if _prepared_consumes_turn(state, command.actor_id):
		return resolve_prepared_strike(state, rng)

	var rejection := validate(command, state)
	if rejection != CombatResult.Rejection.NONE:
		return CombatResult.rejected(state, rejection)

	var next := _copy_state(state)
	var events: Array[CombatEvent] = []
	if _has_non_positive_hp(next):
		_expel_non_positive_hp(next, events)

	_clear_stale_prepared(next, command.actor_id)
	if validate(command, next) == CombatResult.Rejection.NONE:
		_apply_step(next, command, events)

	return CombatResult.resolved(next, events)


func validate_ability(command: AbilityCommand, state: CombatState) -> CombatResult.Rejection:
	if state.outcome != CombatState.Outcome.ONGOING:
		return CombatResult.Rejection.BATTLE_FINISHED

	var actor := _find(state, command.actor_id)
	if actor == null:
		return CombatResult.Rejection.UNKNOWN_ACTOR

	if state.turn_queue.is_empty() or state.turn_queue[0] != actor.id:
		return CombatResult.Rejection.NOT_ACTIVE_TURN

	var ability := AbilityCatalog.definition(command.ability_id)
	if ability == null or not actor.ability_ids.has(command.ability_id):
		return CombatResult.Rejection.UNKNOWN_ABILITY

	if int(actor.cooldown_left.get(command.ability_id, 0)) > 0:
		return CombatResult.Rejection.ON_COOLDOWN

	if actor.position < ability.from_min or actor.position > ability.from_max:
		return CombatResult.Rejection.ACTOR_OUT_OF_POSITION

	var target := _find(state, command.target_id)
	if target == null:
		return CombatResult.Rejection.ILLEGAL_TARGET

	var wanted_side := actor.side
	if ability.hits_enemies:
		wanted_side = CombatantState.Side.ENEMIES if actor.side == CombatantState.Side.HEROES else CombatantState.Side.HEROES
	if target.side != wanted_side:
		return CombatResult.Rejection.ILLEGAL_TARGET

	if target.position < ability.target_min or target.position > ability.target_max:
		return CombatResult.Rejection.ILLEGAL_TARGET

	return CombatResult.Rejection.NONE


## Copies state on success. A rejection returns the same state object.
## A strike may miss, be blocked, or be reduced by cover. Healing, cover, and a rite do not roll.
## Health at 0 then uses the same expulsion as a step.
## A prepared strike for this actor replaces the command while its target is still alive.
func resolve_ability(command: AbilityCommand, state: CombatState, rng: RandomNumberGenerator) -> CombatResult:
	if _prepared_consumes_turn(state, command.actor_id):
		return resolve_prepared_strike(state, rng)

	var rejection := validate_ability(command, state)
	if rejection != CombatResult.Rejection.NONE:
		return CombatResult.rejected(state, rejection)

	var next := _copy_state(state)
	var events: Array[CombatEvent] = []
	if _has_non_positive_hp(next):
		_expel_non_positive_hp(next, events)

	_clear_stale_prepared(next, command.actor_id)
	if validate_ability(command, next) == CombatResult.Rejection.NONE:
		_apply_ability(next, command, events, rng)

	return CombatResult.resolved(next, events)


## Plays the active actor's stored strike with the same hit and block rolls as a strike.
## The strike spends the turn. If the actor was removed first, the record is already clear.
func resolve_prepared_strike(state: CombatState, rng: RandomNumberGenerator) -> CombatResult:
	var next := _copy_state(state)
	var events: Array[CombatEvent] = []
	if _has_non_positive_hp(next):
		_expel_non_positive_hp(next, events)

	var prepared := next.prepared
	if prepared == null or next.outcome != CombatState.Outcome.ONGOING:
		return CombatResult.resolved(next, events)
	if next.turn_queue.is_empty() or next.turn_queue[0] != prepared.actor_id:
		return CombatResult.resolved(next, events)

	var actor := _find(next, prepared.actor_id)
	var target := _find(next, prepared.target_id)
	if actor == null or target == null or target.hp <= 0:
		next.prepared = null
		return CombatResult.resolved(next, events)

	_resolve_hit(actor, target, prepared.ability_id, prepared.amount, rng, events)
	next.prepared = null
	if _has_non_positive_hp(next):
		_expel_non_positive_hp(next, events)
	_close_actor_turn(next, actor.id, events, "")
	return CombatResult.resolved(next, events)


## Copy with the stored strike removed. Does not spend the turn and does not emit events.
func discard_prepared(state: CombatState) -> CombatState:
	var copy := _copy_state(state)
	copy.prepared = null
	return copy


## Numbers for the screen. Does not roll and does not change state.
## A strike fills the hit chance, both damage outcomes, and the target's current cover.
## Healing, a step, and the rite report hit chance 0. The rite's damage_on_hit is the stored blow.
func preview(actor_id: String, ability_id: String, target_id: String, state: CombatState) -> AttackPreview:
	var shown := AttackPreview.new()
	var ability := AbilityCatalog.definition(ability_id)
	if ability == null:
		return shown
	if ability.kind == AbilityDefinition.Kind.RITE:
		if _stored_rite(state, actor_id, ability_id, target_id):
			return _strike_preview(state, actor_id, target_id, state.prepared.amount)
		shown.damage_on_hit = ability.amount
		return shown
	if ability.kind != AbilityDefinition.Kind.STRIKE:
		return shown
	return _strike_preview(state, actor_id, target_id, _listed_strike(ability, _find(state, target_id)))


## The scene asks for a preview from the command it is about to send.
func preview_attack(command: AbilityCommand, state: CombatState) -> AttackPreview:
	return preview(command.actor_id, command.ability_id, command.target_id, state)


## Orders whoever is still listed. Higher speed, then heroes, then front to back.
## Callers remove hp <= 0 before starting a new round.
func build_turn_queue(combatants: Array[CombatantState]) -> Array[String]:
	var ordered: Array[CombatantState] = []
	ordered.assign(combatants)
	ordered.sort_custom(_acts_before)
	var queue: Array[String] = []
	for index in ordered.size():
		var combatant: CombatantState = ordered[index]
		queue.append(combatant.id)
	return queue


func _acts_before(a: CombatantState, b: CombatantState) -> bool:
	if a.speed != b.speed:
		return a.speed > b.speed
	if a.side != b.side:
		return a.side == CombatantState.Side.HEROES
	return a.position < b.position


func _apply_step(state: CombatState, command: StepCommand, events: Array[CombatEvent]) -> void:
	var actor := _find(state, command.actor_id)
	var from_position := actor.position
	var occupant := _find_at(state, actor.side, command.destination_position)
	if occupant == null:
		actor.position = command.destination_position
		events.append(CombatEvent.stepped(actor.id, from_position, command.destination_position))
	else:
		occupant.position = from_position
		actor.position = command.destination_position
		events.append(CombatEvent.swapped(
			actor.id,
			occupant.id,
			from_position,
			command.destination_position
		))

	_close_actor_turn(state, actor.id, events, "")


func _apply_ability(
	state: CombatState,
	command: AbilityCommand,
	events: Array[CombatEvent],
	rng: RandomNumberGenerator
) -> void:
	var actor := _find(state, command.actor_id)
	var ability := AbilityCatalog.definition(command.ability_id)
	var target := _find(state, command.target_id)
	match ability.kind:
		AbilityDefinition.Kind.HEAL:
			_apply_heal(actor, ability, target, events)
		AbilityDefinition.Kind.GUARD:
			_apply_guard(state, actor, ability, target, events)
		AbilityDefinition.Kind.RITE:
			_apply_rite(state, actor, ability, target, events)
		_:
			_resolve_hit(actor, target, ability.id, _listed_strike(ability, target), rng, events)

	if _has_non_positive_hp(state):
		_expel_non_positive_hp(state, events)

	_close_actor_turn(state, actor.id, events, ability.id)


func _apply_heal(
	actor: CombatantState,
	ability: AbilityDefinition,
	target: CombatantState,
	events: Array[CombatEvent]
) -> void:
	var room := maxi(target.max_hp - target.hp, 0)
	var gained := mini(ability.amount, room)
	target.hp += gained
	events.append(CombatEvent.healed(actor.id, ability.id, target.id, gained, target.hp))


func _apply_guard(
	state: CombatState,
	actor: CombatantState,
	ability: AbilityDefinition,
	target: CombatantState,
	events: Array[CombatEvent]
) -> void:
	for index in state.combatants.size():
		var combatant: CombatantState = state.combatants[index]
		if combatant.id == target.id:
			combatant.guard_reduction = ability.amount
		else:
			combatant.guard_reduction = 0
	events.append(CombatEvent.guard_placed(actor.id, ability.id, target.id, ability.amount))


func _apply_rite(
	state: CombatState,
	actor: CombatantState,
	ability: AbilityDefinition,
	target: CombatantState,
	events: Array[CombatEvent]
) -> void:
	var prepared := PreparedStrike.new()
	prepared.actor_id = actor.id
	prepared.ability_id = ability.id
	prepared.target_id = target.id
	prepared.amount = ability.amount
	state.prepared = prepared
	events.append(CombatEvent.prepared_strike(actor.id, ability.id, target.id, ability.amount))


## The second listed number applies only at or below the ability's HP percent. Block and cover come later.
func _listed_strike(ability: AbilityDefinition, target: CombatantState) -> int:
	if ability == null:
		return 0
	if (
		ability.finish_amount > 0
		and ability.finish_below_percent > 0
		and target != null
		and target.max_hp > 0
		and target.hp * 100 <= target.max_hp * ability.finish_below_percent
	):
		return ability.finish_amount
	return ability.amount


func _resolve_hit(
	actor: CombatantState,
	target: CombatantState,
	ability_id: String,
	listed: int,
	rng: RandomNumberGenerator,
	events: Array[CombatEvent]
) -> void:
	var hit_roll := rng.randi_range(1, 100)
	if hit_roll > _hit_chance(actor, target):
		events.append(CombatEvent.missed(actor.id, ability_id, target.id))
		return

	var damage := listed
	var blocked := false
	var block_roll := rng.randi_range(1, 100)
	if block_roll <= target.block:
		blocked = true
		damage = _halve(damage)

	var guarded := target.guard_reduction > 0
	if guarded:
		damage = maxi(damage - target.guard_reduction, 0)
		target.guard_reduction = 0

	var removed := mini(maxi(damage, 0), target.hp)
	target.hp -= removed
	events.append(CombatEvent.damage_applied(
		actor.id,
		ability_id,
		target.id,
		removed,
		target.hp,
		listed,
		_mitigation(blocked, guarded)
	))


func _mitigation(blocked: bool, guarded: bool) -> CombatEvent.Mitigation:
	if blocked and guarded:
		return CombatEvent.Mitigation.BLOCK_AND_GUARD
	if blocked:
		return CombatEvent.Mitigation.BLOCK
	if guarded:
		return CombatEvent.Mitigation.GUARD
	return CombatEvent.Mitigation.NONE


func _hit_chance(actor: CombatantState, target: CombatantState) -> int:
	return clampi(actor.accuracy - target.dodge, 5, 95)


func _stored_rite(state: CombatState, actor_id: String, ability_id: String, target_id: String) -> bool:
	var prepared := state.prepared
	if prepared == null:
		return false
	return (
		prepared.actor_id == actor_id
		and prepared.ability_id == ability_id
		and prepared.target_id == target_id
	)


func _strike_preview(state: CombatState, actor_id: String, target_id: String, listed: int) -> AttackPreview:
	var shown := AttackPreview.new()
	var actor := _find(state, actor_id)
	var target := _find(state, target_id)
	if actor == null or target == null:
		return shown
	var guard := target.guard_reduction
	shown.hit_chance = _hit_chance(actor, target)
	shown.block_chance = target.block
	shown.guard_reduction = guard
	shown.damage_on_hit = maxi(listed - guard, 0)
	shown.damage_if_blocked = maxi(_halve(listed) - guard, 0)
	return shown


## Drops the fraction. Block halves 5 into 2 and 14 into 7.
func _halve(value: int) -> int:
	return int(float(value) / 2.0)


func _prepared_consumes_turn(state: CombatState, actor_id: String) -> bool:
	if state.outcome != CombatState.Outcome.ONGOING:
		return false
	if state.turn_queue.is_empty() or state.turn_queue[0] != actor_id:
		return false
	if state.prepared == null or state.prepared.actor_id != actor_id:
		return false
	var actor := _find(state, actor_id)
	if actor == null or actor.hp <= 0:
		return false
	var target := _find(state, state.prepared.target_id)
	return target != null and target.hp > 0


func _clear_stale_prepared(state: CombatState, actor_id: String) -> void:
	if state.prepared == null or state.prepared.actor_id != actor_id:
		return
	if _find(state, state.prepared.target_id) == null:
		state.prepared = null


## Other fighters' turns do not reduce this. The ability just used is armed after the tick.
func _close_actor_turn(
	state: CombatState,
	actor_id: String,
	events: Array[CombatEvent],
	used_ability_id: String
) -> void:
	var actor := _find(state, actor_id)
	if actor != null:
		_tick_cooldowns(actor, used_ability_id)
		_arm_cooldown(actor, used_ability_id)
	_spend_active_turn(state, actor_id, events)


func _tick_cooldowns(actor: CombatantState, used_ability_id: String) -> void:
	var keys: Array = actor.cooldown_left.keys()
	for index in keys.size():
		var ability_id: String = str(keys[index])
		if ability_id == used_ability_id:
			continue
		var left := int(actor.cooldown_left[ability_id]) - 1
		if left > 0:
			actor.cooldown_left[ability_id] = left
		else:
			actor.cooldown_left.erase(ability_id)


func _arm_cooldown(actor: CombatantState, used_ability_id: String) -> void:
	if used_ability_id == "":
		return
	var ability := AbilityCatalog.definition(used_ability_id)
	if ability == null or ability.cooldown_turns <= 0:
		actor.cooldown_left.erase(used_ability_id)
		return
	actor.cooldown_left[used_ability_id] = ability.cooldown_turns


func _spend_active_turn(state: CombatState, actor_id: String, events: Array[CombatEvent]) -> void:
	if state.outcome != CombatState.Outcome.ONGOING:
		return
	if state.turn_queue.is_empty() or state.turn_queue[0] != actor_id:
		return
	state.turn_queue.remove_at(0)
	if state.turn_queue.is_empty():
		_begin_next_round(state, events)


func _expel_non_positive_hp(state: CombatState, events: Array[CombatEvent]) -> void:
	var expelled: Array[CombatantState] = []
	var kept: Array[CombatantState] = []
	for index in state.combatants.size():
		var combatant: CombatantState = state.combatants[index]
		if combatant.hp <= 0:
			expelled.append(combatant)
		else:
			kept.append(combatant)

	expelled.sort_custom(_expelled_before)
	var heroes_expelled := false
	var enemies_expelled := false
	for index in expelled.size():
		var combatant: CombatantState = expelled[index]
		events.append(CombatEvent.removed_from_battle(combatant.id, combatant.side, combatant.position))
		if combatant.side == CombatantState.Side.HEROES:
			heroes_expelled = true
		else:
			enemies_expelled = true

	state.combatants = kept
	_drop_absent_from_queue(state)
	if state.prepared != null and _find(state, state.prepared.actor_id) == null:
		state.prepared = null

	var heroes_left := _count_side(state, CombatantState.Side.HEROES)
	var enemies_left := _count_side(state, CombatantState.Side.ENEMIES)
	if heroes_left == 0 or enemies_left == 0:
		state.turn_queue.clear()
		if heroes_left == 0:
			state.outcome = CombatState.Outcome.HEROES_DEFEATED
		else:
			state.outcome = CombatState.Outcome.HEROES_VICTORIOUS
		events.append(CombatEvent.battle_ended(state.outcome))
		return

	if state.turn_queue.is_empty():
		_begin_next_round(state, events)


func _expelled_before(a: CombatantState, b: CombatantState) -> bool:
	if a.side != b.side:
		return a.side == CombatantState.Side.HEROES
	return a.position < b.position


func _drop_absent_from_queue(state: CombatState) -> void:
	var present := {}
	for index in state.combatants.size():
		var combatant: CombatantState = state.combatants[index]
		present[combatant.id] = true

	var queue: Array[String] = []
	for index in state.turn_queue.size():
		var queued_id: String = state.turn_queue[index]
		if present.has(queued_id):
			queue.append(queued_id)
	state.turn_queue = queue


func _begin_next_round(state: CombatState, events: Array[CombatEvent]) -> void:
	state.round_number += 1
	var queue := build_turn_queue(state.combatants)
	state.turn_queue = queue
	events.append(CombatEvent.round_started(state.round_number, queue))


func _has_non_positive_hp(state: CombatState) -> bool:
	for index in state.combatants.size():
		var combatant: CombatantState = state.combatants[index]
		if combatant.hp <= 0:
			return true
	return false


func _count_side(state: CombatState, side: CombatantState.Side) -> int:
	var count := 0
	for index in state.combatants.size():
		var combatant: CombatantState = state.combatants[index]
		if combatant.side == side:
			count += 1
	return count


func _find(state: CombatState, id: String) -> CombatantState:
	for index in state.combatants.size():
		var combatant: CombatantState = state.combatants[index]
		if combatant.id == id:
			return combatant
	return null


func _find_at(state: CombatState, side: CombatantState.Side, position: int) -> CombatantState:
	for index in state.combatants.size():
		var combatant: CombatantState = state.combatants[index]
		if combatant.side == side and combatant.position == position:
			return combatant
	return null


func _copy_state(source: CombatState) -> CombatState:
	var copy := CombatState.new()
	copy.round_number = source.round_number
	copy.outcome = source.outcome
	copy.turn_queue.assign(source.turn_queue)
	copy.prepared = _copy_prepared(source.prepared)
	for index in source.combatants.size():
		copy.combatants.append(_copy_combatant(source.combatants[index]))
	return copy


func _copy_prepared(source: PreparedStrike) -> PreparedStrike:
	if source == null:
		return null
	var copy := PreparedStrike.new()
	copy.actor_id = source.actor_id
	copy.ability_id = source.ability_id
	copy.target_id = source.target_id
	copy.amount = source.amount
	return copy


func _copy_combatant(source: CombatantState) -> CombatantState:
	var copy := CombatantState.new()
	copy.id = source.id
	copy.side = source.side
	copy.position = source.position
	copy.speed = source.speed
	copy.hp = source.hp
	copy.max_hp = source.max_hp
	copy.display_name = source.display_name
	copy.accuracy = source.accuracy
	copy.dodge = source.dodge
	copy.block = source.block
	copy.guard_reduction = source.guard_reduction
	copy.cooldown_left = source.cooldown_left.duplicate()
	copy.strength = source.strength
	copy.armor = source.armor
	copy.dexterity = source.dexterity
	copy.knowledge = source.knowledge
	copy.health = source.health
	copy.ability_ids.assign(source.ability_ids)
	return copy
