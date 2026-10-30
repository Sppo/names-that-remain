extends RefCounted

## Test harness for BattleSetup.create_new_model_battle(). Not game logic and not a player AI.
## Heroes follow one documented policy; enemies use EnemyAi.take_turn. Every action goes through CombatRules.
## The combat generator is the only one the rules see. The random policy has its own generator.
##
## Hero policies, all choosing only commands that validate_ability, validate or validate_pass accept:
## - attack: the strike with the highest expected damage on any enemy; else a pass.
## - focus: the weakest enemy a strike can reach (lowest hp, then slot, then id), best expected strike on it;
##   else a step forward into an empty slot; else a pass.
## - defensive: tincture on the hero a stored rite aims at; heal the lowest hero at or below half health;
##   warrior covers the lowest hero at or below half health without cover; warrior takes the stance when it is not active;
##   else as focus.
## - tactical: tincture as defensive; heal as defensive; medic gives the stimulant to a hunter without it;
##   a strike that can kill on its largest outcome, highest hit chance first; warrior pushes the shadowclaw from slot 1–2;
##   hunter without a strike maneuvers toward slot 2; else as focus.
## - random: one legal command at random, steps and pass included. A baseline, not a strategy.
## Expected damage = hit chance × average over bases of (no block × min(hit, hp) + block × min(blocked, hp)).

const POLICIES: Array[String] = ["attack", "focus", "defensive", "tactical", "random"]
const ROUND_LIMIT := 40
const TURN_CAP := 2000
const TRACE_LINES := 40

var rules: CombatRules
var ai: EnemyAi


func _init() -> void:
	rules = CombatRules.new()
	ai = EnemyAi.new(rules)


## One battle from the opening state. The returned record is plain data.
func run(policy: String, seed_value: int, round_limit: int = ROUND_LIMIT) -> Dictionary:
	return run_from(BattleSetup.create_new_model_battle(), policy, seed_value, round_limit)


## Same from any ongoing state. The passed state is never written: every step is a copy made by CombatRules.
## check, when valid, is called as check.call(before, result) after every accepted action.
func run_from(
	start: CombatState,
	policy: String,
	seed_value: int,
	round_limit: int = ROUND_LIMIT,
	check: Callable = Callable()
) -> Dictionary:
	var state := start
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var choice_rng := RandomNumberGenerator.new()
	choice_rng.seed = seed_value + 100000
	var record := _blank(policy, seed_value)
	var journal := PackedStringArray()
	var turns := 0
	while state.outcome == CombatState.Outcome.ONGOING:
		if state.round_number > round_limit:
			record["stop"] = "round_limit"
			break
		turns += 1
		if turns > TURN_CAP:
			record["stop"] = "turn_cap"
			break
		var actor := _find(state, state.turn_queue[0])
		_note_reach(state, actor, record)
		var result: CombatResult = null
		var label := ""
		if actor.side == CombatantState.Side.HEROES:
			var command: Variant = hero_command(policy, state, actor, choice_rng)
			label = _label(command)
			result = _resolve(command, state, rng)
		else:
			result = ai.take_turn(state, rng)
			label = _enemy_label(state, actor, result)
		if not result.accepted:
			record["rejected"] += 1
			record["stop"] = "rejected"
			journal.append("REJECTED %s %s %d" % [actor.id, label, result.rejection])
			break
		# Moves and passes are kept per fighter, abilities per card.
		var usage_key := label
		if label == "pass" or label == "step" or label == "swap":
			usage_key = "%s:%s" % [label, actor.id]
		_add(record["usage"], usage_key, 1)
		record["side_turns"]["heroes" if actor.side == CombatantState.Side.HEROES else "enemies"] += 1
		_count_events(record, state, result, actor)
		if check.is_valid():
			check.call(state, result)
		journal.append("T%d R%d %s %s" % [turns, state.round_number, actor.id, label])
		for event: CombatEvent in result.events:
			journal.append("  " + _line(event))
		var next := result.state
		if (
			next.outcome == CombatState.Outcome.ONGOING
			and next.round_number == state.round_number
			and not next.turn_queue.is_empty()
			and next.turn_queue[0] == actor.id
		):
			record["stop"] = "stalled"
			break
		state = next

	if record["stop"] == "":
		record["stop"] = "finished"
	record["outcome"] = state.outcome
	record["rounds"] = mini(state.round_number, round_limit)
	record["turns"] = turns
	record["rng_state"] = rng.state
	record["journal_hash"] = "\n".join(journal).sha256_text()
	record["final"] = _snapshot(state)
	var trace_from := maxi(0, journal.size() - TRACE_LINES)
	record["trace_tail"] = "\n".join(journal.slice(trace_from))
	for hero_id: String in ["warrior", "hunter", "medic"]:
		var hero := _find(state, hero_id)
		record["hero_hp"][hero_id] = hero.hp if hero != null else 0
	var survivors := 0
	for fighter: CombatantState in state.combatants:
		if fighter.side == CombatantState.Side.HEROES:
			survivors += 1
		record["end_reach"][fighter.id] = _can_reach(state, fighter)
	record["hero_survivors"] = survivors
	return record


# --- Hero policies ------------------------------------------------------------------


func hero_command(policy: String, state: CombatState, actor: CombatantState, choice_rng: RandomNumberGenerator) -> Variant:
	match policy:
		"attack":
			var best: Variant = _best_strike(state, actor, "")
			return best if best != null else _pass(actor)
		"focus":
			return _focus(state, actor)
		"defensive":
			var support: Variant = _defensive_support(state, actor)
			return support if support != null else _focus(state, actor)
		"tactical":
			return _tactical(state, actor)
		"random":
			var options := legal_commands(state, actor)
			return options[choice_rng.randi_range(0, options.size() - 1)]
	push_error("battle_simulator: unknown policy %s" % policy)
	return _pass(actor)


func _focus(state: CombatState, actor: CombatantState) -> Variant:
	var weakest: CombatantState = null
	for enemy: CombatantState in _side(state, CombatantState.Side.ENEMIES):
		if _best_strike(state, actor, enemy.id) == null:
			continue
		if weakest == null or _weaker(enemy, weakest):
			weakest = enemy
	if weakest != null:
		return _best_strike(state, actor, weakest.id)
	var forward: Variant = _forward_step(state, actor)
	return forward if forward != null else _pass(actor)


func _defensive_support(state: CombatState, actor: CombatantState) -> Variant:
	var tincture: Variant = _tincture_on_rite_target(state, actor)
	if tincture != null:
		return tincture
	var lowest := _lowest_hero(state)
	var low := lowest != null and lowest.hp * 2 <= lowest.max_hp
	if low:
		var heal := _legal(state, actor, "medic_healing", lowest.id)
		if heal != null:
			return heal
		if lowest.guard_reduction == 0:
			var cover := _legal(state, actor, "warrior_guard", lowest.id)
			if cover != null:
				return cover
	if not _has_effect(actor, "battle_stance"):
		var stance := _legal(state, actor, "warrior_battle_stance", actor.id)
		if stance != null:
			return stance
	return null


func _tactical(state: CombatState, actor: CombatantState) -> Variant:
	var tincture: Variant = _tincture_on_rite_target(state, actor)
	if tincture != null:
		return tincture
	var lowest := _lowest_hero(state)
	if lowest != null and lowest.hp * 2 <= lowest.max_hp:
		var heal := _legal(state, actor, "medic_healing", lowest.id)
		if heal != null:
			return heal
	var hunter := _find(state, "hunter")
	if hunter != null and not _has_effect(hunter, "combat_stimulant"):
		var stimulant := _legal(state, actor, "medic_stimulant", hunter.id)
		if stimulant != null:
			return stimulant
	var lethal: Variant = _lethal_strike(state, actor)
	if lethal != null:
		return lethal
	var shadowclaw := _find(state, "shadowclaw")
	if shadowclaw != null:
		var push := _legal(state, actor, "warrior_shield_push", shadowclaw.id)
		if push != null:
			return push
	if actor.id == "hunter" and actor.position != 2 and _best_strike(state, actor, "") == null:
		var toward := 2 if actor.position < 2 else actor.position - 1
		var maneuver := _legal(state, actor, "hunter_maneuver", actor.id, toward)
		if maneuver != null:
			return maneuver
	return _focus(state, actor)


func _tincture_on_rite_target(state: CombatState, actor: CombatantState) -> Variant:
	if state.prepared == null:
		return null
	var aimed := _find(state, state.prepared.target_id)
	if aimed == null or _has_effect(aimed, "resilience_tincture"):
		return null
	return _legal(state, actor, "medic_tincture", aimed.id)


## Highest expected damage among legal strikes, on one target or on any when target_id is empty.
## Ties keep the first in loadout order, then fighter order. Null when there is no legal strike.
func _best_strike(state: CombatState, actor: CombatantState, target_id: String) -> Variant:
	var best: Variant = null
	var best_points := -1
	for ability_id: String in actor.ability_ids:
		var ability := AbilityCatalog.definition(ability_id)
		if ability.kind != AbilityDefinition.Kind.STRIKE:
			continue
		for target: CombatantState in _side(state, CombatantState.Side.ENEMIES):
			if target_id != "" and target.id != target_id:
				continue
			var command := _legal(state, actor, ability_id, target.id)
			if command == null:
				continue
			var points := expected_points(actor, ability, target)
			if points > best_points:
				best_points = points
				best = command
	return best


func _lethal_strike(state: CombatState, actor: CombatantState) -> Variant:
	var best: Variant = null
	var best_hit := -1
	for ability_id: String in actor.ability_ids:
		var ability := AbilityCatalog.definition(ability_id)
		if ability.kind != AbilityDefinition.Kind.STRIKE:
			continue
		for target: CombatantState in _side(state, CombatantState.Side.ENEMIES):
			var command := _legal(state, actor, ability_id, target.id)
			if command == null:
				continue
			var outcome := rules.strike_outcome(actor, target, ability, target.guard_reduction)
			if outcome == null or outcome.on_hit.max() < target.hp:
				continue
			if outcome.hit_chance > best_hit:
				best_hit = outcome.hit_chance
				best = command
	return best


## Expected HP removed in 1/10000 HP. -1 when the numbers fail.
func expected_points(actor: CombatantState, ability: AbilityDefinition, target: CombatantState) -> int:
	var outcome := rules.strike_outcome(actor, target, ability, target.guard_reduction)
	if outcome == null:
		return -1
	var total := 0
	for index in outcome.on_hit.size():
		total += (100 - outcome.block_chance) * mini(outcome.on_hit[index], target.hp)
		total += outcome.block_chance * mini(outcome.if_blocked[index], target.hp)
	return outcome.hit_chance * total / outcome.on_hit.size()


## Every legal command of the active hero: abilities on every fighter, maneuvers, both steps, and the pass.
func legal_commands(state: CombatState, actor: CombatantState) -> Array:
	var options: Array = []
	for ability_id: String in actor.ability_ids:
		for target: CombatantState in state.combatants:
			for destination in [0, actor.position - 1, actor.position + 1]:
				var command := _legal(state, actor, ability_id, target.id, destination)
				if command == null:
					continue
				var ability := AbilityCatalog.definition(ability_id)
				if destination == 0 and ability.target_mode == AbilityDefinition.TargetMode.OWN_ADJACENT:
					continue
				if destination != 0 and ability.target_mode != AbilityDefinition.TargetMode.OWN_ADJACENT:
					continue
				options.append(command)
	for destination in [actor.position - 1, actor.position + 1]:
		var step := StepCommand.new()
		step.actor_id = actor.id
		step.destination_position = destination
		if rules.validate(step, state) == CombatResult.Rejection.NONE:
			options.append(step)
	options.append(_pass(actor))
	return options


func _legal(
	state: CombatState,
	actor: CombatantState,
	ability_id: String,
	target_id: String,
	destination: int = 0
) -> AbilityCommand:
	if not actor.ability_ids.has(ability_id):
		return null
	var command := AbilityCommand.new()
	command.actor_id = actor.id
	command.ability_id = ability_id
	command.target_id = target_id
	command.destination_position = destination
	if rules.validate_ability(command, state) != CombatResult.Rejection.NONE:
		return null
	return command


func _forward_step(state: CombatState, actor: CombatantState) -> Variant:
	var forward := actor.position - 1
	if forward < CombatantState.FRONT_POSITION or _at(state, actor.side, forward) != null:
		return null
	var step := StepCommand.new()
	step.actor_id = actor.id
	step.destination_position = forward
	if rules.validate(step, state) != CombatResult.Rejection.NONE:
		return null
	return step


func _pass(actor: CombatantState) -> PassCommand:
	var command := PassCommand.new()
	command.actor_id = actor.id
	return command


func _resolve(command: Variant, state: CombatState, rng: RandomNumberGenerator) -> CombatResult:
	if command is AbilityCommand:
		return rules.resolve_ability(command, state, rng)
	if command is StepCommand:
		return rules.resolve(command, state, rng)
	return rules.resolve_pass(command, state, rng)


# --- Records ------------------------------------------------------------------------


func _blank(policy: String, seed_value: int) -> Dictionary:
	return {
		"policy": policy,
		"seed": seed_value,
		"stop": "",
		"rejected": 0,
		"usage": {},
		"hits": {"heroes": 0, "enemies": 0},
		"misses": {"heroes": 0, "enemies": 0},
		"heal_uses": 0,
		"healed": 0,
		"cover_placed": 0,
		"covered_hits": 0,
		"absorbed": 0,
		"rite_prepared": 0,
		"rite_released": 0,
		"rite_cancelled": 0,
		"rite_damage": 0,
		"finisher_hits": 0,
		"finisher_misses": 0,
		"finisher_kills": 0,
		"steps": 0,
		"swaps": 0,
		"pushes": 0,
		"push_swaps": 0,
		"maneuvers": 0,
		"passes": {"heroes": 0, "enemies": 0},
		"hero_deaths": {},
		"hero_killers": {},
		"no_damage_turns": 0,
		"side_turns": {"heroes": 0, "enemies": 0},
		"stuck_turns": {"heroes": 0, "enemies": 0},
		"hero_hp": {},
		"end_reach": {},
	}


func _count_events(record: Dictionary, before: CombatState, result: CombatResult, actor: CombatantState) -> void:
	var side := "heroes" if actor.side == CombatantState.Side.HEROES else "enemies"
	var last_blow := {}
	var released := false
	for event: CombatEvent in result.events:
		match event.kind:
			CombatEvent.Kind.DAMAGE_APPLIED:
				record["hits"][_side_name(before, event.actor_id)] += 1
				last_blow[event.other_id] = event.ability_id
				if event.ability_id == "cultist_prepared_rite":
					record["rite_released"] += 1
					record["rite_damage"] += event.amount
					released = true
				if event.ability_id == "shadowclaw_finisher":
					record["finisher_hits"] += 1
				if event.mitigation == CombatEvent.Mitigation.GUARD or event.mitigation == CombatEvent.Mitigation.BLOCK_AND_GUARD:
					var reaching := event.listed_amount
					if event.mitigation == CombatEvent.Mitigation.BLOCK_AND_GUARD:
						reaching = event.listed_amount / 2
					record["covered_hits"] += 1
					record["absorbed"] += mini(reaching, 10)
			CombatEvent.Kind.MISSED:
				record["misses"][_side_name(before, event.actor_id)] += 1
				if event.ability_id == "shadowclaw_finisher":
					record["finisher_misses"] += 1
			CombatEvent.Kind.HEALED:
				record["heal_uses"] += 1
				record["healed"] += event.amount
			CombatEvent.Kind.GUARD_PLACED:
				record["cover_placed"] += 1
			CombatEvent.Kind.PREPARED_STRIKE:
				record["rite_prepared"] += 1
			CombatEvent.Kind.STEPPED:
				record["steps"] += 1
			CombatEvent.Kind.SWAPPED:
				record["swaps"] += 1
			CombatEvent.Kind.FORMATION_SHIFTED:
				record["pushes"] += 1
				if event.shifts.size() == 2:
					record["push_swaps"] += 1
			CombatEvent.Kind.TURN_PASSED:
				record["passes"][side] += 1
			CombatEvent.Kind.REMOVED_FROM_BATTLE:
				if event.side == CombatantState.Side.HEROES:
					_add(record["hero_deaths"], event.actor_id, 1)
					_add(record["hero_killers"], str(last_blow.get(event.actor_id, "unknown")), 1)
				if last_blow.get(event.actor_id, "") == "shadowclaw_finisher":
					record["finisher_kills"] += 1
	if actor.id == "hunter" and _maneuvered(result):
		record["maneuvers"] += 1
	if before.prepared != null and result.state.prepared == null and not released:
		record["rite_cancelled"] += 1


func _maneuvered(result: CombatResult) -> bool:
	for event: CombatEvent in result.events:
		if event.kind == CombatEvent.Kind.EFFECT_APPLIED and event.effect_id == "maneuver_dodge":
			return true
	return false


## Turn-start reach, cooldowns ignored: who could ever strike from where they stand.
func _note_reach(state: CombatState, actor: CombatantState, record: Dictionary) -> void:
	var heroes_reach := false
	var enemies_reach := false
	for fighter: CombatantState in state.combatants:
		if _can_reach(state, fighter):
			if fighter.side == CombatantState.Side.HEROES:
				heroes_reach = true
			else:
				enemies_reach = true
	if not heroes_reach and not enemies_reach:
		record["no_damage_turns"] += 1
	if not _can_reach(state, actor):
		record["stuck_turns"]["heroes" if actor.side == CombatantState.Side.HEROES else "enemies"] += 1


## True when some strike or rite of this fighter has a living target from the current slots, cooldowns ignored.
func _can_reach(state: CombatState, fighter: CombatantState) -> bool:
	for ability_id: String in fighter.ability_ids:
		var ability := AbilityCatalog.definition(ability_id)
		if ability.kind != AbilityDefinition.Kind.STRIKE and ability.kind != AbilityDefinition.Kind.RITE:
			continue
		if fighter.position < ability.from_min or fighter.position > ability.from_max:
			continue
		for target: CombatantState in state.combatants:
			if target.side == fighter.side or target.hp <= 0:
				continue
			if target.position < ability.target_min or target.position > ability.target_max:
				continue
			if rules.target_health_allows(ability, target):
				return true
	return false


func _label(command: Variant) -> String:
	if command is AbilityCommand:
		return command.ability_id
	if command is StepCommand:
		return "step"
	return "pass"


func _enemy_label(before: CombatState, actor: CombatantState, result: CombatResult) -> String:
	for event: CombatEvent in result.events:
		if event.actor_id != actor.id:
			continue
		match event.kind:
			CombatEvent.Kind.DAMAGE_APPLIED, CombatEvent.Kind.MISSED:
				if event.ability_id == "cultist_prepared_rite" and before.prepared != null:
					return "cultist_prepared_rite:release"
				return event.ability_id
			CombatEvent.Kind.GUARD_PLACED, CombatEvent.Kind.PREPARED_STRIKE:
				return event.ability_id
			CombatEvent.Kind.STEPPED:
				return "step"
			CombatEvent.Kind.SWAPPED:
				return "swap"
			CombatEvent.Kind.TURN_PASSED:
				return "pass"
			CombatEvent.Kind.PREPARED_STRIKE_CANCELLED:
				return "cultist_prepared_rite:cancelled"
	return "other"


func _line(event: CombatEvent) -> String:
	var shifts := PackedStringArray()
	for shift: PositionShift in event.shifts:
		shifts.append("%s:%d>%d" % [shift.combatant_id, shift.from_position, shift.to_position])
	return "%d %s %s %s a%d hp%d L%d m%d %d>%d e%s r%d q%s %s" % [
		event.kind,
		event.actor_id,
		event.ability_id,
		event.other_id,
		event.amount,
		event.resulting_hp,
		event.listed_amount,
		event.mitigation,
		event.from_position,
		event.to_position,
		event.effect_id,
		event.round_number,
		",".join(event.turn_queue),
		",".join(shifts),
	]


func _snapshot(state: CombatState) -> String:
	var lines := PackedStringArray()
	lines.append("round=%d outcome=%d queue=%s" % [state.round_number, state.outcome, ",".join(state.turn_queue)])
	for fighter: CombatantState in state.combatants:
		var effects := PackedStringArray()
		for effect: ActiveEffect in fighter.effects:
			effects.append("%s:%d:%d" % [effect.effect_id, effect.magnitude, effect.turns_left])
		lines.append("%s p%d hp%d/%d g%d cd%s [%s]" % [
			fighter.id, fighter.position, fighter.hp, fighter.max_hp, fighter.guard_reduction, str(fighter.cooldown_left), ",".join(effects)
		])
	return "\n".join(lines)


# --- Small helpers -------------------------------------------------------------------


func _find(state: CombatState, id: String) -> CombatantState:
	for fighter: CombatantState in state.combatants:
		if fighter.id == id:
			return fighter
	return null


func _at(state: CombatState, side: CombatantState.Side, position: int) -> CombatantState:
	for fighter: CombatantState in state.combatants:
		if fighter.side == side and fighter.position == position:
			return fighter
	return null


func _side(state: CombatState, side: CombatantState.Side) -> Array[CombatantState]:
	var fighters: Array[CombatantState] = []
	for fighter: CombatantState in state.combatants:
		if fighter.side == side:
			fighters.append(fighter)
	return fighters


func _side_name(state: CombatState, id: String) -> String:
	var fighter := _find(state, id)
	if fighter != null and fighter.side == CombatantState.Side.HEROES:
		return "heroes"
	return "enemies"


func _lowest_hero(state: CombatState) -> CombatantState:
	var lowest: CombatantState = null
	for hero: CombatantState in _side(state, CombatantState.Side.HEROES):
		if lowest == null or hero.hp * lowest.max_hp < lowest.hp * hero.max_hp:
			lowest = hero
	return lowest


func _weaker(a: CombatantState, b: CombatantState) -> bool:
	if a.hp != b.hp:
		return a.hp < b.hp
	if a.position != b.position:
		return a.position < b.position
	return a.id < b.id


func _has_effect(fighter: CombatantState, effect_id: String) -> bool:
	for effect: ActiveEffect in fighter.effects:
		if effect.effect_id == effect_id:
			return true
	return false


func _add(counts: Dictionary, key: String, amount: int) -> void:
	counts[key] = int(counts.get(key, 0)) + amount
