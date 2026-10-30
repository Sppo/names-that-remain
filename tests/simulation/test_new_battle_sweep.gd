extends GutTest

## Phase 8 seed sweep of the new 3 v 3 battle. Prints the statistics; does not ask for a winner.
## Run on its own: -gdir=res://tests/simulation. Not part of the tests/combat check, it takes minutes.
## Asserts only technical health: no rejected command, no stalled queue, no turn cap.

const Simulator = preload("res://tests/simulation/battle_simulator.gd")
const FIRST_SEED := 1
const SEEDS := 250


func test_sweep_every_policy_over_the_seeds() -> void:
	var simulator := Simulator.new()
	var report := PackedStringArray()
	report.append("# Phase 8 sweep: seeds %d–%d, round limit %d" % [FIRST_SEED, FIRST_SEED + SEEDS - 1, Simulator.ROUND_LIMIT])
	var limit_examples := PackedStringArray()
	# Formation and health invariants after every action of every battle. Counted, then required to be 0.
	var broken := {"actions": 0, "violations": 0}
	var check := func(before: CombatState, result: CombatResult) -> void:
		broken["actions"] += 1
		broken["violations"] += _violations(before, result)
	for policy: String in Simulator.POLICIES:
		var records: Array[Dictionary] = []
		for seed_value in range(FIRST_SEED, FIRST_SEED + SEEDS):
			var record: Dictionary = simulator.run_from(BattleSetup.create_new_model_battle(), policy, seed_value, Simulator.ROUND_LIMIT, check)
			records.append(record)
			assert_eq(record["rejected"], 0, "%s seed %d rejected" % [policy, seed_value])
			assert_true(record["stop"] == "finished" or record["stop"] == "round_limit", "%s seed %d stop %s" % [policy, seed_value, record["stop"]])
			if record["stop"] == "round_limit" and limit_examples.size() < 12:
				limit_examples.append("## %s seed %d\nend reach %s\n%s\n%s" % [policy, seed_value, str(record["end_reach"]), record["final"], record["trace_tail"]])
		report.append(_policy_summary(policy, records))
	assert_eq(broken["violations"], 0)
	report.append("# Invariants: %d actions checked, %d violations" % [broken["actions"], broken["violations"]])
	report.append("# Round-limit traces (first 12)")
	report.append_array(limit_examples)
	var text := "\n".join(report)
	print(text)
	gut.p("sweep finished: %d policies × %d seeds" % [Simulator.POLICIES.size(), SEEDS])


func _policy_summary(policy: String, records: Array[Dictionary]) -> String:
	var lines := PackedStringArray()
	var count := records.size()
	var wins := 0
	var losses := 0
	var limits := 0
	var rounds_finished: Array[int] = []
	var survivors_at_win := {}
	var alive := {"warrior": 0, "hunter": 0, "medic": 0}
	var hp_left := {"warrior": 0, "hunter": 0, "medic": 0}
	var totals := {}
	var usage := {}
	var killers := {}
	var limit_reach := {}
	var seeds_by_outcome := {"win": PackedStringArray(), "loss": PackedStringArray(), "limit": PackedStringArray()}
	for record: Dictionary in records:
		if record["stop"] == "round_limit":
			limits += 1
			seeds_by_outcome["limit"].append(str(record["seed"]))
			var key := _reach_key(record["end_reach"])
			limit_reach[key] = int(limit_reach.get(key, 0)) + 1
		elif record["outcome"] == CombatState.Outcome.HEROES_VICTORIOUS:
			wins += 1
			rounds_finished.append(record["rounds"])
			var survivors := str(record["hero_survivors"])
			survivors_at_win[survivors] = int(survivors_at_win.get(survivors, 0)) + 1
			seeds_by_outcome["win"].append(str(record["seed"]))
		else:
			losses += 1
			rounds_finished.append(record["rounds"])
			seeds_by_outcome["loss"].append(str(record["seed"]))
		for hero_id: String in alive.keys():
			var hp: int = record["hero_hp"][hero_id]
			if hp > 0:
				alive[hero_id] += 1
				hp_left[hero_id] += hp
		for key: String in ["heal_uses", "healed", "cover_placed", "covered_hits", "absorbed", "rite_prepared", "rite_released",
				"rite_cancelled", "rite_damage", "finisher_hits", "finisher_misses", "finisher_kills", "steps", "swaps", "pushes",
				"push_swaps", "maneuvers", "no_damage_turns", "turns", "rejected"]:
			totals[key] = int(totals.get(key, 0)) + int(record[key])
		for side: String in ["heroes", "enemies"]:
			for key: String in ["hits", "misses", "passes", "stuck_turns", "side_turns"]:
				var name := "%s_%s" % [key, side]
				totals[name] = int(totals.get(name, 0)) + int(record[key][side])
		for ability_id: String in record["usage"].keys():
			usage[ability_id] = int(usage.get(ability_id, 0)) + int(record["usage"][ability_id])
		for ability_id: String in record["hero_killers"].keys():
			killers[ability_id] = int(killers.get(ability_id, 0)) + int(record["hero_killers"][ability_id])

	rounds_finished.sort()
	lines.append("## Policy %s" % policy)
	lines.append("battles %d | hero wins %d (%s) | enemy wins %d (%s) | round limit %d (%s)" % [
		count, wins, _percent(wins, count), losses, _percent(losses, count), limits, _percent(limits, count)])
	lines.append("rounds of finished battles: average %s, median %s, min %s, max %s" % [
		_average(rounds_finished), _median(rounds_finished),
		str(rounds_finished[0]) if not rounds_finished.is_empty() else "-",
		str(rounds_finished[rounds_finished.size() - 1]) if not rounds_finished.is_empty() else "-"])
	for hero_id: String in ["warrior", "hunter", "medic"]:
		lines.append("survival %s: %s, average hp of survivors %s" % [
			hero_id, _percent(alive[hero_id], count), _ratio(hp_left[hero_id], alive[hero_id])])
	lines.append("heroes alive at victory: %s" % str(survivors_at_win))
	lines.append("hero killing blows: %s" % str(killers))
	lines.append("usage: %s" % str(_sorted(usage)))
	lines.append("totals: %s" % str(_sorted(totals)))
	lines.append("round-limit end reach (who can strike from where they stand): %s" % str(limit_reach))
	lines.append("seeds won: %s" % _short(seeds_by_outcome["win"]))
	lines.append("seeds lost: %s" % _short(seeds_by_outcome["loss"]))
	lines.append("seeds at limit: %s" % ",".join(seeds_by_outcome["limit"]))
	return "\n".join(lines)


## Listed hp in 1..max, slots 1–4, one fighter per slot and id, moves only through events, at most one cover.
func _violations(before: CombatState, result: CombatResult) -> int:
	var count := 0
	var next := result.state
	var slots := {}
	var ids := {}
	var covered := 0
	var moved := {}
	for event: CombatEvent in result.events:
		match event.kind:
			CombatEvent.Kind.STEPPED:
				moved[event.actor_id] = true
			CombatEvent.Kind.SWAPPED:
				moved[event.actor_id] = true
				moved[event.other_id] = true
			CombatEvent.Kind.FORMATION_SHIFTED:
				for shift: PositionShift in event.shifts:
					moved[shift.combatant_id] = true
	for fighter: CombatantState in next.combatants:
		var key := "%d:%d" % [fighter.side, fighter.position]
		if ids.has(fighter.id) or slots.has(key):
			count += 1
		ids[fighter.id] = true
		slots[key] = true
		if fighter.hp <= 0 or fighter.hp > fighter.max_hp or fighter.position < 1 or fighter.position > 4:
			count += 1
		if fighter.guard_reduction > 0:
			covered += 1
		for old: CombatantState in before.combatants:
			if old.id == fighter.id and old.position != fighter.position and not moved.has(fighter.id):
				count += 1
	if covered > 1:
		count += 1
	return count


func _reach_key(end_reach: Dictionary) -> String:
	var parts := PackedStringArray()
	var ids: Array = end_reach.keys()
	ids.sort()
	for id: String in ids:
		parts.append("%s=%s" % [id, "y" if end_reach[id] else "n"])
	return " ".join(parts)


func _percent(part: int, whole: int) -> String:
	if whole == 0:
		return "-"
	return "%.1f%%" % (100.0 * part / whole)


func _ratio(total: int, count: int) -> String:
	if count == 0:
		return "-"
	return "%.1f" % (float(total) / count)


func _average(values: Array[int]) -> String:
	if values.is_empty():
		return "-"
	var total := 0
	for value in values:
		total += value
	return "%.2f" % (float(total) / values.size())


func _median(values: Array[int]) -> String:
	if values.is_empty():
		return "-"
	var middle := values.size() / 2
	if values.size() % 2 == 1:
		return str(values[middle])
	return "%.1f" % ((values[middle - 1] + values[middle]) / 2.0)


func _sorted(counts: Dictionary) -> Dictionary:
	var keys: Array = counts.keys()
	keys.sort()
	var ordered := {}
	for key in keys:
		ordered[key] = counts[key]
	return ordered


func _short(seeds: PackedStringArray) -> String:
	if seeds.size() <= 30:
		return ",".join(seeds)
	return "%s … (%d seeds)" % [",".join(seeds.slice(0, 30)), seeds.size()]
