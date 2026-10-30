class_name EnemyUtility
extends RefCounted

## Scores one legal command for the active enemy.
## 100 points is 1 health. Every division truncates.
## Does not roll and does not write the passed CombatState.
## Strike numbers come from CombatRules.strike_outcome, the same table the battle rolls on.
## An option whose numbers fail to compute is left out, never scored as 0.

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

	for ability_id: String in actor.ability_ids:
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
			var score: Variant = _score_ability(state, actor, ability, target)
			if score == null:
				continue
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


## Null when the numbers for this option could not be computed.
func _score_ability(
	state: CombatState,
	actor: CombatantState,
	ability: AbilityDefinition,
	target: CombatantState
) -> Variant:
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
) -> Variant:
	var blow := _blow_for(actor, ability, target, target.guard_reduction)
	var threat: Variant = _threat(state, target)
	if blow == null or threat == null:
		return null
	var expected := _expected_blow_points(blow, target.hp)
	var death := _death_percent(target.hp, [blow])
	return expected + death * threat


## The rite is scored on its listed number, as if stored now, against the target's current cover.
func _rite_points(
	state: CombatState,
	actor: CombatantState,
	ability: AbilityDefinition,
	target: CombatantState
) -> Variant:
	var blow := _blow_for(actor, ability, target, target.guard_reduction)
	var threat: Variant = _threat(state, target)
	var dying: Variant = _death_until_turn(state, actor, actor.guard_reduction)
	if blow == null or threat == null or dying == null:
		return null
	var expected := _expected_blow_points(blow, target.hp)
	var death := _death_percent(target.hp, [blow])
	var future: int = expected + death * threat
	var survival: int = 100 - dying
	return int(float(survival) * float(future) / 100.0)


func _guard_points(state: CombatState, ability: AbilityDefinition, target: CombatantState) -> Variant:
	if target.guard_reduction >= ability.amount:
		return 0
	var without: Variant = _death_until_turn(state, target, target.guard_reduction)
	var covered: Variant = _death_until_turn(state, target, ability.amount)
	var threat: Variant = _threat(state, target)
	if without == null or covered == null or threat == null:
		return null
	return (without - covered) * threat


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


## Null when a hero's blow could not be computed.
func _death_until_turn(state: CombatState, subject: CombatantState, first_guard: int) -> Variant:
	var blows: Array = []
	for combatant_id: String in _ids_before(state, subject.id):
		var hero := _find(state, combatant_id)
		if hero == null or hero.hp <= 0 or hero.side != CombatantState.Side.HEROES:
			continue
		var guard_value := 0
		if blows.is_empty():
			guard_value = first_guard
		var blow: Blow = _best_blow(hero, subject, guard_value)
		if blow == null:
			continue
		if blow.on_hit.is_empty():
			return null
		blows.append(blow)
	return _death_percent(subject.hp, blows)


## Null when no strike of this hero reaches the subject.
## A blow with no outcomes means a reaching strike could not be computed.
func _best_blow(
	hero: CombatantState,
	subject: CombatantState,
	guard_value: int
) -> Blow:
	var best: Blow = null
	var best_expected := -1
	for ability_id: String in hero.ability_ids:
		var ability := AbilityCatalog.definition(ability_id)
		if not _strike_reaches(hero, ability, subject):
			continue
		var blow := _blow_for(hero, ability, subject, guard_value)
		if blow == null:
			return Blow.new(0, 0, [], [])
		var expected := _expected_blow_points(blow, subject.hp)
		if best == null or expected > best_expected:
			best = blow
			best_expected = expected
	return best


## guard_value is the cover counted on the target, which may differ from the cover it has now.
## Null when the strike could not be computed.
func _blow_for(
	actor: CombatantState,
	ability: AbilityDefinition,
	target: CombatantState,
	guard_value: int
) -> Blow:
	var outcome := _rules.strike_outcome(actor, target, ability, guard_value)
	if outcome == null:
		return null
	return Blow.new(outcome.hit_chance, outcome.block_chance, outcome.on_hit, outcome.if_blocked)


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


## Branches in order: miss, then a block per base, then a clean hit per base. Each base is equally likely.
## The last branch takes what truncation left, so the weights always sum to the parent's.
func _apply_blow(branches: Array, blow: Blow) -> Array:
	var count := blow.on_hit.size()
	var part_weights: Array[int] = [(100 - blow.hit) * 100]
	var part_damage: Array[int] = [0]
	for index in count:
		part_weights.append(blow.hit * blow.block)
		part_damage.append(blow.blocked[index])
	for index in count:
		part_weights.append(blow.hit * (100 - blow.block))
		part_damage.append(blow.on_hit[index])
	var last := part_weights.size() - 1
	var next: Array = []
	for branch_index in branches.size():
		var branch: HpWeight = branches[branch_index]
		var given := 0
		for part in part_weights.size():
			var weight := 0
			if part == 0:
				weight = int(float(branch.weight) * float(part_weights[part]) / 10000.0)
				given += weight
			elif part < last:
				weight = int(float(branch.weight) * float(part_weights[part]) / (10000.0 * count))
				given += weight
			else:
				weight = branch.weight - given
			var next_hp := branch.hp
			if next_hp > 0 and part_damage[part] > 0:
				next_hp -= mini(part_damage[part], next_hp)
			next.append(HpWeight.new(next_hp, weight))
	return next


## Expected health removed, in points, averaged over the equally likely bases. Removal stops at hp.
func _expected_blow_points(blow: Blow, hp: int) -> int:
	var weighted := 0
	for index in blow.on_hit.size():
		weighted += (100 - blow.block) * mini(blow.on_hit[index], hp) + blow.block * mini(blow.blocked[index], hp)
	return int(float(blow.hit) * float(weighted) / (100.0 * blow.on_hit.size()))


## Largest damage this fighter's strike or rite can list before armor, or its stored blow, or its heal.
## Null when a strike could not be computed.
func _threat(state: CombatState, fighter: CombatantState) -> Variant:
	var prepared := state.prepared
	if prepared != null and prepared.actor_id == fighter.id:
		var target := _find(state, prepared.target_id)
		var stored := AbilityCatalog.definition(prepared.ability_id)
		if target != null and target.hp > 0 and stored != null:
			if stored.damage_type == AbilityDefinition.DamageType.SPECIAL:
				var outcome := _rules.strike_outcome(fighter, target, stored, target.guard_reduction)
				if outcome == null or outcome.listed.is_empty():
					return null
				return outcome.listed.max()
			# Same unit as the strikes below: damage before armor, scaled by this fighter's stats.
			return _rules.damage_before_armor_for(fighter, stored, prepared.amount)

	var best := 0
	var heal := 0
	for ability_id: String in fighter.ability_ids:
		var ability := AbilityCatalog.definition(ability_id)
		if ability == null:
			continue
		if ability.kind == AbilityDefinition.Kind.STRIKE or ability.kind == AbilityDefinition.Kind.RITE:
			var highest_base := maxi(ability.amount, ability.finish_amount)
			if ability.base_max > 0:
				highest_base = ability.base_max
			var listed: Variant = _rules.damage_before_armor_for(fighter, ability, highest_base)
			if listed == null:
				return null
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


## One strike as the scoring sees it. One entry per possible base, each equally likely.
class Blow:
	var hit: int
	var block: int
	var on_hit: Array[int] = []
	var blocked: Array[int] = []

	func _init(p_hit: int, p_block: int, p_on_hit: Array[int], p_blocked: Array[int]) -> void:
		hit = p_hit
		block = p_block
		on_hit.assign(p_on_hit)
		blocked.assign(p_blocked)


class HpWeight:
	var hp: int
	var weight: int

	func _init(p_hp: int, p_weight: int) -> void:
		hp = p_hp
		weight = p_weight
