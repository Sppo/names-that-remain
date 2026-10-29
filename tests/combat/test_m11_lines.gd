extends GutTest

## Records the seed-2 lines after utility scoring. Does not change health, damage, accuracy, dodge, or block.
## Seed 2 is the shared battle seed. Seed 3 is only the isolated blocked guard strike.

const LINE_SEED := 2
const BLOCKED_GUARD_STRIKE_SEED := 3

var rules: CombatRules


func before_each() -> void:
	rules = CombatRules.new()


func test_guard_strike_of_five_is_two_when_blocked() -> void:
	var state := BattleSetup.create_opening_battle()
	var preview := rules.preview("enemy-1", "guard_strike", "hero-1", state)
	assert_eq(preview.hit_chance, 65)
	assert_eq(preview.block_chance, 25)
	assert_eq(preview.damage_on_hit, 5)
	assert_eq(preview.damage_if_blocked, 2)
	assert_eq(int(float(5) / 2.0), 2)

	state.turn_queue = ["enemy-1"]
	var result := rules.resolve_ability(
		_ability("enemy-1", "guard_strike", "hero-1"),
		state,
		_rng(BLOCKED_GUARD_STRIKE_SEED)
	)
	assert_true(result.accepted)
	assert_eq(result.events[0].kind, CombatEvent.Kind.DAMAGE_APPLIED)
	assert_eq(result.events[0].ability_id, "guard_strike")
	assert_eq(result.events[0].other_id, "hero-1")
	assert_eq(result.events[0].listed_amount, 5)
	assert_eq(result.events[0].amount, 2)
	assert_eq(result.events[0].mitigation, CombatEvent.Mitigation.BLOCK)
	assert_eq(result.events[0].resulting_hp, 18)
	assert_eq(_find(result.state, "hero-1").hp, 18)


func test_cultist_prepares_the_rite_when_the_hunter_does_not_kill_him() -> void:
	var aimed_at_guard := BattleSetup.create_opening_battle()
	var shot_guard := rules.resolve_ability(
		_ability("hero-2", "hunter_shot", "enemy-1"),
		aimed_at_guard,
		_rng(LINE_SEED)
	)
	assert_eq(_find(shot_guard.state, "enemy-2").hp, 10)
	_assert_opening_rite(shot_guard.state)

	var aimed_at_cultist := BattleSetup.create_opening_battle()
	var shot_cultist := rules.resolve_ability(
		_ability("hero-2", "hunter_shot", "enemy-2"),
		aimed_at_cultist,
		_rng(LINE_SEED)
	)
	assert_eq(_find(shot_cultist.state, "enemy-2").hp, 5)
	_assert_wounded_cultist_strikes_now(shot_cultist.state)


func test_one_shot_and_one_shield_can_remove_the_cultist_before_the_rite() -> void:
	var opening := BattleSetup.create_opening_battle()
	var shot := rules.preview("hero-2", "hunter_shot", "enemy-2", opening)
	var shield := rules.preview("hero-1", "warrior_shield", "enemy-2", opening)
	assert_eq(_find(opening, "enemy-2").hp, 10)
	assert_eq(shot.hit_chance, 70)
	assert_eq(shot.block_chance, 0)
	assert_eq(shot.damage_on_hit, 5)
	assert_eq(shield.hit_chance, 60)
	assert_eq(shield.block_chance, 0)
	assert_eq(shield.damage_on_hit, 6)
	assert_eq(shot.hit_chance * shield.hit_chance / 100, 42)
	assert_true(shot.damage_on_hit < 10)
	assert_true(shield.damage_on_hit < 10)
	assert_true(shot.damage_on_hit + shield.damage_on_hit >= 10)

	var rng := _rng(LINE_SEED)
	var hunted := rules.resolve_ability(_ability("hero-2", "hunter_shot", "enemy-2"), opening, rng)
	assert_eq(_find(hunted.state, "enemy-2").hp, 5)
	var chosen: Variant = EnemyAi.new(rules).choose_action(hunted.state)
	assert_true(chosen is AbilityCommand)
	var immediate := chosen as AbilityCommand
	assert_eq(immediate.ability_id, "cultist_arrow")
	assert_ne(immediate.ability_id, "cultist_rite")
	# The rite would not roll, so the shield still sees the two rolls after the shot.
	hunted.state.turn_queue = ["hero-1", "enemy-1", "hero-3", "enemy-2"]
	var finished := rules.resolve_ability(
		_ability("hero-1", "warrior_shield", "enemy-2"),
		hunted.state,
		rng
	)
	assert_true(finished.accepted)
	assert_null(_find(finished.state, "enemy-2"))
	assert_null(finished.state.prepared)
	assert_eq(finished.state.round_number, 1)
	assert_eq(finished.state.outcome, CombatState.Outcome.ONGOING)
	assert_eq(_find(finished.state, "hero-3").hp, 20)
	assert_eq(finished.events[0].kind, CombatEvent.Kind.DAMAGE_APPLIED)
	assert_eq(finished.events[0].listed_amount, 6)
	assert_eq(finished.events[0].amount, 5)
	assert_eq(finished.events[0].mitigation, CombatEvent.Mitigation.NONE)
	for event: CombatEvent in finished.events:
		assert_ne(event.ability_id, "cultist_rite")


func test_fixed_seed_lines_record_three_focuses() -> void:
	var guard_line := _play_line(false)
	assert_eq(guard_line["outcome"], CombatState.Outcome.HEROES_VICTORIOUS)
	assert_eq(guard_line["round"], 6)
	assert_eq(guard_line["hero-1"], 20)
	assert_eq(guard_line["hero-2"], 10)
	assert_eq(guard_line["hero-3"], 0)

	var cultist_line := _play_line(true)
	assert_eq(cultist_line["outcome"], CombatState.Outcome.HEROES_VICTORIOUS)
	assert_eq(cultist_line["round"], 9)
	assert_eq(cultist_line["hero-1"], 10)
	assert_eq(cultist_line["hero-2"], 0)
	assert_eq(cultist_line["hero-3"], 0)

	var claw_line := _play_focus("enemy-3")
	assert_eq(claw_line["outcome"], CombatState.Outcome.HEROES_DEFEATED)
	assert_eq(claw_line["round"], 7)
	assert_eq(claw_line["hero-1"], 0)
	assert_eq(claw_line["hero-2"], 0)
	assert_eq(claw_line["hero-3"], 0)


## Both lines over seeds 1..20. Records the result and does not require a winner.
func test_seeds_one_through_twenty_finish_both_lines() -> void:
	for focus_id in ["enemy-1", "enemy-2", "enemy-3"]:
		var hero_wins := 0
		var enemy_wins := 0
		var rounds := 0
		var hero_1 := 0
		var hero_2 := 0
		var hero_3 := 0
		var covers := 0
		var rite_damage := 0
		var executes := 0
		var claws := 0
		for seed_value in range(1, 21):
			var line := _play_focus(focus_id, seed_value)
			assert_ne(line["outcome"], CombatState.Outcome.ONGOING)
			if line["outcome"] == CombatState.Outcome.HEROES_VICTORIOUS:
				hero_wins += 1
			else:
				enemy_wins += 1
			rounds += int(line["round"])
			hero_1 += int(line["hero-1"])
			hero_2 += int(line["hero-2"])
			hero_3 += int(line["hero-3"])
			covers += int(line["covered"])
			rite_damage += int(line["rite_damage"])
			executes += int(line["executes"])
			claws += int(line["claws"])
		assert_eq(hero_wins + enemy_wins, 20)
		print(
			"UTILITY_SWEEP focus=%s hero_wins=%s enemy_wins=%s avg_round=%.2f avg_hp_hero1=%.2f avg_hp_hero2=%.2f avg_hp_hero3=%.2f avg_hp_sum=%.2f guard_covers=%s rite_damage=%s executes=%s claws=%s"
			% [
				focus_id,
				hero_wins,
				enemy_wins,
				float(rounds) / 20.0,
				float(hero_1) / 20.0,
				float(hero_2) / 20.0,
				float(hero_3) / 20.0,
				float(hero_1 + hero_2 + hero_3) / 20.0,
				covers,
				rite_damage,
				executes,
				claws,
			]
		)


func _assert_opening_rite(state: CombatState) -> void:
	var result := EnemyAi.new(rules).take_turn(state, _rng(LINE_SEED))
	assert_true(result.accepted)
	assert_eq(result.events.size(), 1)
	assert_eq(result.events[0].kind, CombatEvent.Kind.PREPARED_STRIKE)
	assert_eq(result.events[0].actor_id, "enemy-2")
	assert_eq(result.events[0].ability_id, "cultist_rite")
	assert_eq(result.events[0].other_id, "hero-3")
	assert_eq(result.events[0].amount, 14)
	assert_eq(result.state.prepared.amount, 14)
	assert_eq(_find(result.state, "hero-3").hp, 20)
	assert_eq(_find(result.state, "hero-1").hp, 20)
	assert_eq(_find(result.state, "hero-2").hp, 20)


## At 5 health a legal hero strike can remove the cultist before his next turn, so he deals damage now.
func _assert_wounded_cultist_strikes_now(state: CombatState) -> void:
	var result := EnemyAi.new(rules).take_turn(state, _rng(LINE_SEED))
	assert_true(result.accepted)
	assert_eq(result.events.size(), 1)
	assert_eq(result.events[0].kind, CombatEvent.Kind.DAMAGE_APPLIED)
	assert_eq(result.events[0].actor_id, "enemy-2")
	assert_eq(result.events[0].ability_id, "cultist_arrow")
	assert_eq(result.events[0].other_id, "hero-3")
	assert_eq(result.events[0].amount, 4)
	assert_null(result.state.prepared)
	assert_eq(_find(result.state, "hero-3").hp, 16)
	assert_eq(_find(result.state, "enemy-2").hp, 5)
	assert_eq(_find(result.state, "hero-1").hp, 20)
	assert_eq(_find(result.state, "hero-2").hp, 20)


## Heroes strike the preferred living enemy. After that enemy is gone, they strike the other.
## The doctor heals the most wounded hero. Cover is never chosen.
## Enemies act only through EnemyAi.take_turn.
func _play_line(focus_cultist: bool, seed_value: int = LINE_SEED) -> Dictionary:
	return _play_focus("enemy-2" if focus_cultist else "enemy-1", seed_value)


func _play_focus(preferred_id: String, seed_value: int = LINE_SEED) -> Dictionary:
	var rng := _rng(seed_value)
	var state := BattleSetup.create_opening_battle()
	var ai := EnemyAi.new(rules)
	var covered := 0
	var rite_damage := 0
	var executes := 0
	var claws := 0
	var turns := 0
	while state.outcome == CombatState.Outcome.ONGOING and turns < 80:
		assert_false(state.turn_queue.is_empty())
		var actor := _find(state, state.turn_queue[0])
		var result: CombatResult
		if actor.side == CombatantState.Side.ENEMIES:
			result = ai.take_turn(state, rng)
		else:
			var command: Variant = _hero_command(state, preferred_id)
			if command is AbilityCommand:
				result = rules.resolve_ability(command, state, rng)
			else:
				result = rules.resolve(command, state, rng)
		assert_true(result.accepted)
		for event: CombatEvent in result.events:
			if event.kind == CombatEvent.Kind.GUARD_PLACED and event.actor_id == "enemy-1":
				covered += 1
			if (
				event.kind == CombatEvent.Kind.DAMAGE_APPLIED
				and event.ability_id == "cultist_rite"
				and event.amount > 0
			):
				rite_damage += 1
			if event.kind == CombatEvent.Kind.DAMAGE_APPLIED and event.ability_id == "shadowclaw_execute":
				executes += 1
			if event.kind == CombatEvent.Kind.DAMAGE_APPLIED and event.ability_id == "shadowclaw_claws":
				claws += 1
		state = result.state
		turns += 1
	assert_ne(state.outcome, CombatState.Outcome.ONGOING)
	return {
		"outcome": state.outcome,
		"round": state.round_number,
		"hero-1": _hp_of(state, "hero-1"),
		"hero-2": _hp_of(state, "hero-2"),
		"hero-3": _hp_of(state, "hero-3"),
		"covered": covered,
		"rite_damage": rite_damage,
		"executes": executes,
		"claws": claws,
	}


func _hero_command(state: CombatState, preferred_id: String) -> Variant:
	var actor := _find(state, state.turn_queue[0])
	if actor.id == "hero-3":
		var patient := _most_wounded_hero(state)
		var heal := _ability(actor.id, "doctor_heal", patient.id)
		if rules.validate_ability(heal, state) == CombatResult.Rejection.NONE:
			return heal
	for target_id: String in _focus_order(preferred_id):
		var strike := _legal_strike(state, actor, target_id)
		if strike != null:
			return strike
	var destination := actor.position - 1
	if actor.id == "hero-2" and actor.position < 2:
		destination = actor.position + 1
	if actor.id == "hero-1" and actor.position > 2:
		destination = actor.position - 1
	if actor.id == "hero-3":
		destination = actor.position + 1
	return _step_toward(state, actor, destination)


func _focus_order(preferred_id: String) -> Array[String]:
	var order: Array[String] = []
	order.append(preferred_id)
	for enemy_id: String in ["enemy-1", "enemy-2", "enemy-3"]:
		if enemy_id != preferred_id:
			order.append(enemy_id)
	return order


func _legal_strike(state: CombatState, actor: CombatantState, target_id: String) -> AbilityCommand:
	if not _alive(state, target_id):
		return null
	for ability_id: String in AbilityCatalog.ids_for(actor.id):
		var ability := AbilityCatalog.definition(ability_id)
		if ability == null or ability.kind != AbilityDefinition.Kind.STRIKE:
			continue
		var command := _ability(actor.id, ability_id, target_id)
		if rules.validate_ability(command, state) == CombatResult.Rejection.NONE:
			return command
	return null


func _most_wounded_hero(state: CombatState) -> CombatantState:
	var chosen: CombatantState = null
	for combatant: CombatantState in state.combatants:
		if combatant.side != CombatantState.Side.HEROES or combatant.hp <= 0:
			continue
		if chosen == null or combatant.hp < chosen.hp or (
			combatant.hp == chosen.hp and combatant.position < chosen.position
		):
			chosen = combatant
	return chosen


func _step_toward(state: CombatState, actor: CombatantState, destination: int) -> StepCommand:
	var command := _step(actor.id, destination)
	if rules.validate(command, state) == CombatResult.Rejection.NONE:
		return command
	var fallback := actor.position + 1 if destination < actor.position else actor.position - 1
	return _step(actor.id, fallback)


func _alive(state: CombatState, id: String) -> bool:
	var combatant := _find(state, id)
	return combatant != null and combatant.hp > 0


func _hp_of(state: CombatState, id: String) -> int:
	var combatant := _find(state, id)
	if combatant == null:
		return 0
	return combatant.hp


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


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


func _find(state: CombatState, id: String) -> CombatantState:
	for combatant: CombatantState in state.combatants:
		if combatant.id == id:
			return combatant
	return null
