class_name EnemyUtility
extends RefCounted

## Scores one legal command for the active enemy.
## 100 points is 1 health. Every division truncates.
## Does not roll and does not write the passed CombatState.

const _STEP_RANK := 3

var _rules: CombatRules


func _init(rules: CombatRules) -> void:
	_rules = rules


func choose(state: CombatState) -> Variant:
	var actor := _active(state)
	if actor == null:
		return null

	var found := false
	var best_score := 0
	var best_rank := 0
	var best_position := 0
	var best_target_id := ""
	var best_command: Variant = null

	for ability_id: String in AbilityCatalog.ids_for(actor.id):
		var ability := AbilityCatalog.definition(ability_id)
		if ability == null or not _is_scored_kind(ability.kind):
			continue
		for index in state.combatants.size():
			var target: CombatantState = state.combatants[index]
			if target.hp <= 0:
				continue
			var command := _ability(actor.id, ability.id, target.id)
			if _rules.validate_ability(command, state) != CombatResult.Rejection.NONE:
				continue
			var score := _score_ability(state, actor, ability, target)
			if _beats(found, best_score, best_rank, best_position, best_target_id, score, _kind_rank(ability.kind), target.position, target.id):
				found = true
				best_score = score
				best_rank = _kind_rank(ability.kind)
				best_position = target.position
				best_target_id = target.id
				best_command = command

	var front := actor.position - 1
	var rear := actor.position + 1
	var destinations: Array[int] = []
	if front >= CombatantState.FRONT_POSITION:
		destinations.append(front)
	if rear <= CombatantState.REAR_POSITION:
		destinations.append(rear)
	for index in destinations.size():
		var destination := destinations[index]
		var step := _step(actor.id, destination)
		if _rules.validate(step, state) != CombatResult.Rejection.NONE:
			continue
		if _beats(found, best_score, best_rank, best_position, best_target_id, 0, _STEP_RANK, destination, ""):
			found = true
			best_score = 0
			best_rank = _STEP_RANK
			best_position = destination
			best_target_id = ""
			best_command = step

	return best_command


func _score_ability(
	state: CombatState,
	actor: CombatantState,
	ability: AbilityDefinition,
	target: CombatantState
) -> int:
	match ability.kind:
		AbilityDefinition.Kind.STRIKE:
			return _strike_points(state, actor, ability, target)
		AbilityDefinition.Kind.RITE:
			return _rite_points(state, actor, ability, target)
		AbilityDefinition.Kind.GUARD:
			return _guard_points(state, ability, target)
		_:
			return 0


func _strike_points(
	state: CombatState,
	actor: CombatantState,
	ability: AbilityDefinition,
	target: CombatantState
) -> int:
	var shown := _rules.preview(actor.id, ability.id, target.id, state)
	var blow := Blow.new(shown.hit_chance, shown.block_chance, shown.damage_on_hit, shown.damage_if_blocked)
	var expected := _expected_points(
		shown.hit_chance,
		shown.block_chance,
		mini(shown.damage_on_hit, target.hp),
		mini(shown.damage_if_blocked, target.hp)
	)
	var death := _death_percent(target.hp, [blow])
	return expected + death * _threat(state, target)


func _rite_points(
	state: CombatState,
	actor: CombatantState,
	ability: AbilityDefinition,
	target: CombatantState
) -> int:
	var shown := _preview_listed_blow(state, actor.id, ability.id, target.id, ability.amount)
	var blow := Blow.new(shown.hit_chance, shown.block_chance, shown.damage_on_hit, shown.damage_if_blocked)
	var expected := _expected_points(
		shown.hit_chance,
		shown.block_chance,
		mini(shown.damage_on_hit, target.hp),
		mini(shown.damage_if_blocked, target.hp)
	)
	var death := _death_percent(target.hp, [blow])
	var future := expected + death * _threat(state, target)
	var survival := 100 - _death_until_turn(state, actor, actor.guard_reduction)
	return int(float(survival) * float(future) / 100.0)


func _guard_points(state: CombatState, ability: AbilityDefinition, target: CombatantState) -> int:
	if target.guard_reduction >= ability.amount:
		return 0
	var without := _death_until_turn(state, target, target.guard_reduction)
	var covered := _death_until_turn(state, target, ability.amount)
	return (without - covered) * _threat(state, target)


## Tail after the active fighter, then one new round, stopping at subject_id.
func _ids_before(state: CombatState, subject_id: String) -> Array[String]:
	var sequence: Array[String] = []
	for index in range(1, state.turn_queue.size()):
		var queued_id: String = state.turn_queue[index]
		if queued_id == subject_id:
			return sequence
		sequence.append(queued_id)

	var living: Array[CombatantState] = []
	for index in state.combatants.size():
		var combatant: CombatantState = state.combatants[index]
		if combatant.hp > 0:
			living.append(combatant)
	var round_queue := _rules.build_turn_queue(living)
	for index in round_queue.size():
		var queued_id: String = round_queue[index]
		if queued_id == subject_id:
			return sequence
		sequence.append(queued_id)
	return sequence


func _death_until_turn(state: CombatState, subject: CombatantState, first_guard: int) -> int:
	var blows: Array = []
	for combatant_id: String in _ids_before(state, subject.id):
		var hero := _find(state, combatant_id)
		if hero == null or hero.hp <= 0 or hero.side != CombatantState.Side.HEROES:
			continue
		var guard_value := 0
		if blows.is_empty():
			guard_value = first_guard
		var blow: Blow = _best_blow(state, hero, subject, guard_value)
		if blow == null:
			continue
		blows.append(blow)
	return _death_percent(subject.hp, blows)


func _best_blow(
	state: CombatState,
	hero: CombatantState,
	subject: CombatantState,
	guard_value: int
) -> Blow:
	var best: Blow = null
	var best_expected := -1
	for ability_id: String in AbilityCatalog.ids_for(hero.id):
		var ability := AbilityCatalog.definition(ability_id)
		if not _strike_reaches(hero, ability, subject):
			continue
		var blow := _blow_for(state, hero, ability, subject, guard_value)
		var expected := _expected_points(
			blow.hit,
			blow.block,
			mini(blow.on_hit, subject.hp),
			mini(blow.blocked, subject.hp)
		)
		if best == null or expected > best_expected:
			best = blow
			best_expected = expected
	return best


func _blow_for(
	state: CombatState,
	actor: CombatantState,
	ability: AbilityDefinition,
	target: CombatantState,
	guard_value: int
) -> Blow:
	var shown := _rules.preview(actor.id, ability.id, target.id, state)
	var on_hit := shown.damage_on_hit
	var blocked := shown.damage_if_blocked
	if guard_value != shown.guard_reduction:
		on_hit = maxi(ability.amount - guard_value, 0)
		blocked = maxi(_halve(ability.amount) - guard_value, 0)
	return Blow.new(shown.hit_chance, shown.block_chance, on_hit, blocked)


## Stored-rite preview of a listed blow. The original state is left untouched.
func _preview_listed_blow(
	state: CombatState,
	actor_id: String,
	ability_id: String,
	target_id: String,
	listed: int
) -> AttackPreview:
	var prepared := PreparedStrike.new()
	prepared.actor_id = actor_id
	prepared.ability_id = ability_id
	prepared.target_id = target_id
	prepared.amount = listed
	var copy := CombatState.new()
	copy.round_number = state.round_number
	copy.outcome = state.outcome
	copy.turn_queue.assign(state.turn_queue)
	copy.combatants.assign(state.combatants)
	copy.prepared = prepared
	return _rules.preview(actor_id, ability_id, target_id, copy)


func _death_percent(hp: int, blows: Array) -> int:
	if hp <= 0 or blows.is_empty():
		return 0
	var branches: Array = [HpWeight.new(hp, 10000)]
	for blow_index in blows.size():
		var blow: Blow = blows[blow_index]
		branches = _apply_blow(branches, blow)
	var dead_weight := 0
	for branch_index in branches.size():
		var branch: HpWeight = branches[branch_index]
		if branch.hp <= 0:
			dead_weight += branch.weight
	return int(float(dead_weight) / 100.0)


func _apply_blow(branches: Array, blow: Blow) -> Array:
	var part_weights: Array[int] = [
		(100 - blow.hit) * 100,
		blow.hit * blow.block,
		blow.hit * (100 - blow.block),
	]
	var part_damage: Array[int] = [0, blow.blocked, blow.on_hit]
	var next: Array = []
	for branch_index in branches.size():
		var branch: HpWeight = branches[branch_index]
		var given := 0
		for part in 3:
			var weight := 0
			if part < 2:
				weight = int(float(branch.weight) * float(part_weights[part]) / 10000.0)
				given += weight
			else:
				weight = branch.weight - given
			var next_hp := branch.hp
			if next_hp > 0 and part_damage[part] > 0:
				next_hp -= mini(part_damage[part], next_hp)
			next.append(HpWeight.new(next_hp, weight))
	return next


func _expected_points(hit: int, block: int, removed: int, removed_blocked: int) -> int:
	var weighted := (100 - block) * removed + block * removed_blocked
	return int(float(hit) * float(weighted) / 100.0)


func _threat(state: CombatState, fighter: CombatantState) -> int:
	var prepared := state.prepared
	if prepared != null and prepared.actor_id == fighter.id:
		var target := _find(state, prepared.target_id)
		if target != null and target.hp > 0:
			return prepared.amount

	var best := 0
	var heal := 0
	for ability_id: String in AbilityCatalog.ids_for(fighter.id):
		var ability := AbilityCatalog.definition(ability_id)
		if ability == null:
			continue
		if ability.kind == AbilityDefinition.Kind.STRIKE or ability.kind == AbilityDefinition.Kind.RITE:
			var listed := ability.amount
			if ability.finish_amount > listed:
				listed = ability.finish_amount
			if listed > best:
				best = listed
		elif ability.kind == AbilityDefinition.Kind.HEAL and ability.amount > heal:
			heal = ability.amount
	return maxi(best, heal)


func _strike_reaches(hero: CombatantState, ability: AbilityDefinition, target: CombatantState) -> bool:
	if ability == null or ability.kind != AbilityDefinition.Kind.STRIKE:
		return false
	if hero.hp <= 0 or target.hp <= 0:
		return false
	if hero.position < ability.from_min or hero.position > ability.from_max:
		return false
	if target.position < ability.target_min or target.position > ability.target_max:
		return false
	var wanted := hero.side
	if ability.hits_enemies:
		wanted = CombatantState.Side.ENEMIES if hero.side == CombatantState.Side.HEROES else CombatantState.Side.HEROES
	return target.side == wanted


func _beats(
	found: bool,
	best_score: int,
	best_rank: int,
	best_position: int,
	best_target_id: String,
	score: int,
	rank: int,
	position: int,
	target_id: String
) -> bool:
	if not found:
		return true
	if score != best_score:
		return score > best_score
	if rank != best_rank:
		return rank < best_rank
	if position != best_position:
		return position < best_position
	return target_id < best_target_id


func _is_scored_kind(kind: AbilityDefinition.Kind) -> bool:
	return (
		kind == AbilityDefinition.Kind.STRIKE
		or kind == AbilityDefinition.Kind.RITE
		or kind == AbilityDefinition.Kind.GUARD
	)


func _kind_rank(kind: AbilityDefinition.Kind) -> int:
	match kind:
		AbilityDefinition.Kind.STRIKE:
			return 0
		AbilityDefinition.Kind.RITE:
			return 1
		AbilityDefinition.Kind.GUARD:
			return 2
		_:
			return _STEP_RANK


func _active(state: CombatState) -> CombatantState:
	if state.turn_queue.is_empty():
		return null
	return _find(state, state.turn_queue[0])


func _find(state: CombatState, combatant_id: String) -> CombatantState:
	for index in state.combatants.size():
		var combatant: CombatantState = state.combatants[index]
		if combatant.id == combatant_id:
			return combatant
	return null


func _ability(actor_id: String, ability_id: String, target_id: String) -> AbilityCommand:
	var command := AbilityCommand.new()
	command.actor_id = actor_id
	command.ability_id = ability_id
	command.target_id = target_id
	return command


func _step(actor_id: String, destination: int) -> StepCommand:
	var command := StepCommand.new()
	command.actor_id = actor_id
	command.destination_position = destination
	return command


func _halve(value: int) -> int:
	return int(float(value) / 2.0)


class Blow:
	var hit: int
	var block: int
	var on_hit: int
	var blocked: int

	func _init(p_hit: int, p_block: int, p_on_hit: int, p_blocked: int) -> void:
		hit = p_hit
		block = p_block
		on_hit = p_on_hit
		blocked = p_blocked


class HpWeight:
	var hp: int
	var weight: int

	func _init(p_hp: int, p_weight: int) -> void:
		hp = p_hp
		weight = p_weight
