extends GutTest

## Phase 3. CombatMath inside the battle, the preview and enemy scoring.
## Real paths are used wherever the frozen catalog allows. A ranged or scaled card does not exist yet,
## so those cases go through CombatRules.strike_outcome and the same roll code with a test-only card.


var rules: CombatRules


func before_each() -> void:
	rules = CombatRules.new()


# --- Helpers ---------------------------------------------------------------


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


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## First seed whose first roll 1–100 passes the check. Keeps forced hits and misses deterministic.
func _seed_where(check: Callable) -> int:
	for seed_value in range(1, 1000):
		if check.call(_rng(seed_value).randi_range(1, 100)):
			return seed_value
	return -1


## Opening battle with the cultist's rite stored on the doctor and the cultist to act.
func _rite_on_doctor(amount: int) -> CombatState:
	var state := BattleSetup.create_opening_battle()
	state.turn_queue = ["enemy-2", "enemy-3", "hero-1", "enemy-1", "hero-3"]
	var prepared := PreparedStrike.new()
	prepared.actor_id = "enemy-2"
	prepared.ability_id = "cultist_rite"
	prepared.target_id = "hero-3"
	prepared.amount = amount
	state.prepared = prepared
	# Sure hit: 100 against 0 is the 95% bound.
	_find(state, "enemy-2").accuracy = 100
	_find(state, "hero-3").dodge = 0
	return state


## Every field of the battle and its fighters as text, to prove nothing was written.
func _snapshot(state: CombatState) -> String:
	var lines := PackedStringArray()
	lines.append("round=%d outcome=%d queue=%s" % [state.round_number, state.outcome, ",".join(state.turn_queue)])
	if state.prepared == null:
		lines.append("prepared=null")
	else:
		var prepared := state.prepared
		lines.append("prepared=%s/%s/%s/%d" % [prepared.actor_id, prepared.ability_id, prepared.target_id, prepared.amount])
	for index in state.combatants.size():
		var fighter: CombatantState = state.combatants[index]
		lines.append("%s %d %d %d %d/%d %d %d %d %d %s %d/%d/%d/%d/%d %s" % [
			fighter.id,
			fighter.side,
			fighter.position,
			fighter.speed,
			fighter.hp,
			fighter.max_hp,
			fighter.accuracy,
			fighter.dodge,
			fighter.block,
			fighter.guard_reduction,
			str(fighter.cooldown_left),
			fighter.strength,
			fighter.armor,
			fighter.dexterity,
			fighter.knowledge,
			fighter.health,
			",".join(fighter.ability_ids),
		])
	return "\n".join(lines)


## Test-only card: base 4–6, strength scaling, +15 accuracy. Not in the catalog.
func _ranged_card() -> AbilityDefinition:
	var card := AbilityDefinition.new()
	card.id = "test_ranged_strike"
	card.amount = 0
	card.base_min = 4
	card.base_max = 6
	card.strength_percent = 100
	card.accuracy_bonus = 15
	return card


# --- 13. The control battle keeps its numbers --------------------------------


func test_control_cards_keep_their_numbers_through_the_strike_table() -> void:
	var state := BattleSetup.create_opening_battle()
	var checked := 0
	for attacker: CombatantState in state.combatants:
		for ability_id: String in attacker.ability_ids:
			var ability := AbilityCatalog.definition(ability_id)
			if ability.kind != AbilityDefinition.Kind.STRIKE and ability.kind != AbilityDefinition.Kind.RITE:
				continue
			for target: CombatantState in state.combatants:
				if target.side == attacker.side:
					continue
				var outcome := rules.strike_outcome(attacker, target, ability, target.guard_reduction)
				assert_not_null(outcome)
				# Everyone starts at full health, so the finishing number does not apply.
				var listed := ability.amount
				assert_eq(outcome.bases, [listed] as Array[int])
				assert_eq(outcome.listed, [listed] as Array[int])
				assert_eq(outcome.on_hit, [listed] as Array[int])
				assert_eq(outcome.if_blocked, [listed / 2] as Array[int])
				assert_eq(outcome.hit_chance, clampi(attacker.accuracy - target.dodge, 5, 95))
				assert_eq(outcome.block_chance, target.block)
				checked += 1
	assert_gt(checked, 0)


# --- 4–8. Armor, minimum, block and cover in the real battle ------------------


func test_armor_comes_before_block_and_cover() -> void:
	var hit_seed := _seed_where(func(roll: int) -> bool: return roll <= 95)
	# 14 through ARM 5 is 11, block 5, cover 10 → 0. Cover first would leave 4 → armor 3, then block 1.
	var state := _rite_on_doctor(14)
	var doctor := _find(state, "hero-3")
	doctor.armor = 5
	doctor.block = 100
	doctor.guard_reduction = 10
	var result := rules.resolve_prepared_strike(state, _rng(hit_seed))
	assert_true(result.accepted)
	var event: CombatEvent = result.events[0]
	assert_eq(event.kind, CombatEvent.Kind.DAMAGE_APPLIED)
	assert_eq(event.listed_amount, 11)
	assert_eq(event.amount, 0)
	assert_eq(event.mitigation, CombatEvent.Mitigation.BLOCK_AND_GUARD)
	assert_eq(_find(result.state, "hero-3").guard_reduction, 0)

	# Without block: 11 − 10 = 1. Cover before armor would give round_half_up(4 × 0.8) = 3.
	var unblocked := _rite_on_doctor(14)
	_find(unblocked, "hero-3").armor = 5
	_find(unblocked, "hero-3").block = 0
	_find(unblocked, "hero-3").guard_reduction = 10
	var plain := rules.resolve_prepared_strike(unblocked, _rng(hit_seed))
	assert_eq(plain.events[0].listed_amount, 11)
	assert_eq(plain.events[0].amount, 1)
	assert_eq(plain.events[0].mitigation, CombatEvent.Mitigation.GUARD)
	assert_eq(_find(plain.state, "hero-3").hp, 19)


func test_minimum_one_after_armor_only_for_positive_damage() -> void:
	var hit_seed := _seed_where(func(roll: int) -> bool: return roll <= 95)
	# 1 through ARM 100 rounds to 0, the minimum lifts it to 1; a block takes it back to 0.
	var state := _rite_on_doctor(1)
	_find(state, "hero-3").armor = 100
	var result := rules.resolve_prepared_strike(state, _rng(hit_seed))
	assert_eq(result.events[0].listed_amount, 1)
	assert_eq(result.events[0].amount, 1)
	var blocked_state := _rite_on_doctor(1)
	_find(blocked_state, "hero-3").armor = 100
	_find(blocked_state, "hero-3").block = 100
	var blocked := rules.resolve_prepared_strike(blocked_state, _rng(hit_seed))
	assert_eq(blocked.events[0].listed_amount, 1)
	assert_eq(blocked.events[0].amount, 0)
	# 0 stays 0: armor does not create damage.
	var zero_state := _rite_on_doctor(0)
	_find(zero_state, "hero-3").armor = 5
	var zero := rules.resolve_prepared_strike(zero_state, _rng(hit_seed))
	assert_eq(zero.events[0].listed_amount, 0)
	assert_eq(zero.events[0].amount, 0)


func test_block_halves_the_damage_after_armor() -> void:
	var hit_seed := _seed_where(func(roll: int) -> bool: return roll <= 95)
	# 13 through ARM 3 is round_half_up(11.30) = 11; the block drops the fraction: 5.
	var state := _rite_on_doctor(13)
	_find(state, "hero-3").armor = 3
	_find(state, "hero-3").block = 100
	var result := rules.resolve_prepared_strike(state, _rng(hit_seed))
	assert_eq(result.events[0].listed_amount, 11)
	assert_eq(result.events[0].amount, 5)
	assert_eq(result.events[0].mitigation, CombatEvent.Mitigation.BLOCK)
	# Order check: 2 through ARM 100 is 1 (minimum), block → 0.
	# Blocking first would give 1 → armor rounds to 0 → minimum 1, so the order shows.
	var ordered := _rite_on_doctor(2)
	_find(ordered, "hero-3").armor = 100
	_find(ordered, "hero-3").block = 100
	var ordered_hit := rules.resolve_prepared_strike(ordered, _rng(hit_seed))
	assert_eq(ordered_hit.events[0].listed_amount, 1)
	assert_eq(ordered_hit.events[0].amount, 0)


func test_cover_survives_a_miss_and_goes_on_a_hit() -> void:
	var miss_seed := _seed_where(func(roll: int) -> bool: return roll > 5)
	var missed_state := _rite_on_doctor(5)
	_find(missed_state, "enemy-2").accuracy = 0
	_find(missed_state, "hero-3").dodge = 100
	_find(missed_state, "hero-3").armor = 5
	_find(missed_state, "hero-3").guard_reduction = 10
	var missed := rules.resolve_prepared_strike(missed_state, _rng(miss_seed))
	assert_eq(missed.events[0].kind, CombatEvent.Kind.MISSED)
	assert_eq(_find(missed.state, "hero-3").guard_reduction, 10)
	assert_eq(_find(missed.state, "hero-3").hp, 20)

	var hit_seed := _seed_where(func(roll: int) -> bool: return roll <= 95)
	# 5 through ARM 5 is 4; cover takes all 4 and is spent even though 6 of it is left over.
	var hit_state := _rite_on_doctor(5)
	_find(hit_state, "hero-3").armor = 5
	_find(hit_state, "hero-3").guard_reduction = 10
	var hit := rules.resolve_prepared_strike(hit_state, _rng(hit_seed))
	assert_eq(hit.events[0].listed_amount, 4)
	assert_eq(hit.events[0].amount, 0)
	assert_eq(hit.events[0].mitigation, CombatEvent.Mitigation.GUARD)
	assert_eq(_find(hit.state, "hero-3").guard_reduction, 0)


# --- 9. Rolls --------------------------------------------------------------


func test_miss_rolls_once_and_fixed_hit_rolls_twice() -> void:
	var miss_seed := _seed_where(func(roll: int) -> bool: return roll > 5)
	var missed_state := _rite_on_doctor(14)
	_find(missed_state, "enemy-2").accuracy = 0
	_find(missed_state, "hero-3").dodge = 100
	var rng := _rng(miss_seed)
	rules.resolve_prepared_strike(missed_state, rng)
	var expected := _rng(miss_seed)
	expected.randi_range(1, 100)
	assert_eq(rng.state, expected.state)

	# Block 0% still rolls the block.
	var hit_seed := _seed_where(func(roll: int) -> bool: return roll <= 95)
	var hit_state := _rite_on_doctor(14)
	assert_eq(_find(hit_state, "hero-3").block, 0)
	var hit_rng := _rng(hit_seed)
	rules.resolve_prepared_strike(hit_state, hit_rng)
	var expected_hit := _rng(hit_seed)
	expected_hit.randi_range(1, 100)
	expected_hit.randi_range(1, 100)
	assert_eq(hit_rng.state, expected_hit.state)


func test_ranged_hit_rolls_hit_then_base_then_block() -> void:
	var state := BattleSetup.create_opening_battle()
	var warrior := _find(state, "hero-1")
	warrior.strength = 5
	var guard := _find(state, "enemy-1")
	guard.armor = 4
	guard.accuracy = 77
	guard.dodge = 0
	var outcome := rules.strike_outcome(warrior, guard, _ranged_card(), 0)
	assert_not_null(outcome)
	assert_eq(outcome.bases, [4, 5, 6] as Array[int])

	var hit_seed := _seed_where(func(roll: int) -> bool: return roll <= outcome.hit_chance)
	var rng := _rng(hit_seed)
	var events: Array[CombatEvent] = []
	rules._resolve_hit(warrior, guard, "test_ranged_strike", outcome, rng, events)

	var expected := _rng(hit_seed)
	expected.randi_range(1, 100)
	var base := expected.randi_range(4, 6)
	var block_roll := expected.randi_range(1, 100)
	assert_eq(rng.state, expected.state)
	var index := base - 4
	assert_eq(events[0].listed_amount, outcome.listed[index])
	var shown: int = outcome.if_blocked[index] if block_roll <= 50 else outcome.on_hit[index]
	assert_eq(events[0].amount, shown)


# --- 1–3. One table for the battle, the preview and the AI -------------------


func test_preview_battle_and_math_agree() -> void:
	var hunter_id := "hero-2"
	var state := BattleSetup.create_opening_battle()
	var guard := _find(state, "enemy-1")
	guard.armor = 3
	guard.guard_reduction = 1
	var preview := rules.preview(hunter_id, "hunter_shot", "enemy-1", state)
	# CombatMath chain: 5 through ARM 3 is 4, cover 1 → 3; blocked 2 − 1 → 1. Hit 90 − 10 = 80.
	var after_armor: int = CombatMath.damage_after_armor(CombatMath.damage_before_armor(5, 100, 30000, 100, 100), 300)
	assert_eq(after_armor, 4)
	assert_eq(preview.hit_chance, CombatMath.hit_chance(9000, 1000))
	assert_eq(preview.damage_on_hit, CombatMath.damage_after_guard(after_armor, 1))
	assert_eq(preview.damage_if_blocked, CombatMath.damage_after_guard(CombatMath.blocked_damage(after_armor), 1))
	assert_eq(preview.damage_on_hit, 3)
	assert_eq(preview.damage_if_blocked, 1)
	assert_eq(preview.damage_on_hit_max, 3)
	assert_eq(preview.damage_if_blocked_max, 1)
	assert_eq(preview.guard_reduction, 1)

	var hit_seed := _seed_where(func(roll: int) -> bool: return roll <= 80)
	guard.block = 0
	var clean := rules.resolve_ability(_ability(hunter_id, "hunter_shot", "enemy-1"), state, _rng(hit_seed))
	assert_eq(clean.events[0].amount, preview.damage_on_hit)
	assert_eq(clean.events[0].listed_amount, after_armor)
	guard.block = 100
	var blocked := rules.resolve_ability(_ability(hunter_id, "hunter_shot", "enemy-1"), state, _rng(hit_seed))
	assert_eq(blocked.events[0].amount, preview.damage_if_blocked)

	# The AI reads the same table.
	var utility := EnemyUtility.new(rules)
	var blow = utility._blow_for(_find(state, hunter_id), AbilityCatalog.definition("hunter_shot"), guard, 1)
	assert_eq(blow.hit, preview.hit_chance)
	assert_eq(blow.on_hit, [preview.damage_on_hit] as Array[int])
	assert_eq(blow.blocked, [preview.damage_if_blocked] as Array[int])


func test_scaled_range_card_matches_combat_math() -> void:
	var state := BattleSetup.create_opening_battle()
	var warrior := _find(state, "hero-1")
	warrior.strength = 5
	var guard := _find(state, "enemy-1")
	guard.armor = 4
	guard.dexterity = 2
	guard.dodge = 11
	var outcome := rules.strike_outcome(warrior, guard, _ranged_card(), 0)
	assert_not_null(outcome)
	var weighted: int = CombatMath.weighted_stat_x10000(500, 300, 300, 100, 0, 0)
	for index in outcome.bases.size():
		var before: int = CombatMath.damage_before_armor(outcome.bases[index], 100, weighted, 100, 100)
		assert_eq(outcome.listed[index], CombatMath.damage_after_armor(before, 400))
	# Bases 4 / 5 / 6 at STR 5 are 5 / 6 / 7, through ARM 4 → 4 / 5 / 6.
	assert_eq(outcome.listed, [4, 5, 6] as Array[int])
	# Accuracy 80 + 15 against dodge 11 + (2 − 3) = 10: 85.
	assert_eq(outcome.hit_chance, 85)

	# Preview reports the range; the AI averages the three equally likely bases.
	var shown := rules._strike_preview(outcome)
	assert_eq(shown.damage_on_hit, 4)
	assert_eq(shown.damage_on_hit_max, 6)
	assert_eq(shown.damage_if_blocked, 2)
	assert_eq(shown.damage_if_blocked_max, 3)
	var utility := EnemyUtility.new(rules)
	var blow = utility._blow_for(warrior, _ranged_card(), guard, 0)
	assert_eq(blow.on_hit, [4, 5, 6] as Array[int])
	assert_eq(blow.blocked, [2, 2, 3] as Array[int])
	# 85 × (50·4 + 50·2 + 50·5 + 50·2 + 50·6 + 50·3) / 300 = 311.67 → 311.
	assert_eq(utility._expected_blow_points(blow, 20), 311)


func test_single_base_scoring_keeps_the_old_branch_weights() -> void:
	var utility := EnemyUtility.new(rules)
	var blow = EnemyUtility.Blow.new(80, 50, [6] as Array[int], [3] as Array[int])
	# Old formula: int(80 × (50·6 + 50·3) / 100) = 360.
	assert_eq(utility._expected_blow_points(blow, 20), 360)
	# Two blows on 6 HP, each: miss 20%, block 40% (3), clean 40% (6).
	# Clean first: 40%. Block first, then any hit: 40% × 80% = 32%. Miss first, then clean: 20% × 40% = 8%. Total 80.
	var death := utility._death_percent(6, [blow, blow])
	assert_eq(death, 80)


# --- 10. Preview and AI do not roll or write ---------------------------------


func test_preview_and_enemy_choice_do_not_write_state() -> void:
	var state := BattleSetup.create_opening_battle()
	_find(state, "enemy-1").armor = 4
	_find(state, "hero-3").guard_reduction = 10
	state.turn_queue = ["enemy-3", "hero-1", "enemy-1", "hero-3", "hero-2", "enemy-2"]
	var before := _snapshot(state)
	for attacker: CombatantState in state.combatants:
		for ability_id: String in attacker.ability_ids:
			for target: CombatantState in state.combatants:
				rules.preview(attacker.id, ability_id, target.id, state)
	var ai := EnemyAi.new(rules)
	var command: Variant = ai.choose_action(state)
	assert_not_null(command)
	assert_eq(_snapshot(state), before)


func test_enemy_turn_rolls_only_for_its_strike() -> void:
	var state := BattleSetup.create_opening_battle()
	state.turn_queue = ["enemy-3", "hero-1", "enemy-1", "hero-3", "hero-2", "enemy-2"]
	var ai := EnemyAi.new(rules)
	var command: Variant = ai.choose_action(state)
	assert_true(command is AbilityCommand)
	var ai_rng := _rng(7)
	var by_ai := ai.take_turn(state, ai_rng)
	var rules_rng := _rng(7)
	var by_rules := rules.resolve_ability(command, state, rules_rng)
	assert_eq(ai_rng.state, rules_rng.state)
	assert_eq(by_ai.events.size(), by_rules.events.size())
	assert_eq(by_ai.events[0].kind, by_rules.events[0].kind)
	assert_eq(by_ai.events[0].amount, by_rules.events[0].amount)


# --- 11. Failed formulas -----------------------------------------------------


func test_failed_formula_rejects_without_rolling_or_writing() -> void:
	var state := BattleSetup.create_opening_battle()
	_find(state, "enemy-1").armor = -1
	var before := _snapshot(state)
	var rng := _rng(3)
	var rng_state := rng.state
	var result := rules.resolve_ability(_ability("hero-2", "hunter_shot", "enemy-1"), state, rng)
	assert_false(result.accepted)
	assert_eq(result.rejection, CombatResult.Rejection.CALCULATION_FAILED)
	assert_eq(result.state, state)
	assert_true(result.events.is_empty())
	assert_eq(rng.state, rng_state)
	assert_eq(_snapshot(state), before)
	assert_push_error_count(1)


func test_failed_formula_on_a_stored_rite_rejects_without_rolling() -> void:
	var state := _rite_on_doctor(14)
	_find(state, "hero-3").armor = -1
	var before := _snapshot(state)
	var rng := _rng(3)
	var rng_state := rng.state
	var result := rules.resolve_prepared_strike(state, rng)
	assert_false(result.accepted)
	assert_eq(result.rejection, CombatResult.Rejection.CALCULATION_FAILED)
	assert_eq(rng.state, rng_state)
	assert_eq(_snapshot(state), before)
	assert_push_error_count(1)


func test_failed_formula_leaves_the_preview_blank() -> void:
	var state := BattleSetup.create_opening_battle()
	_find(state, "enemy-1").armor = -1
	var shown := rules.preview("hero-2", "hunter_shot", "enemy-1", state)
	assert_eq(shown.hit_chance, 0)
	assert_eq(shown.block_chance, 0)
	assert_eq(shown.guard_reduction, 0)
	assert_eq(shown.damage_on_hit, 0)
	assert_eq(shown.damage_if_blocked, 0)
	assert_eq(shown.damage_on_hit_max, 0)
	assert_eq(shown.damage_if_blocked_max, 0)
	assert_push_error_count(1)


func test_unstored_rite_preview_lists_one_number() -> void:
	# Before it is stored the rite shows only the damage it would list; the range fields agree.
	var state := BattleSetup.create_opening_battle()
	var shown := rules.preview("enemy-2", "cultist_rite", "hero-3", state)
	assert_eq(shown.hit_chance, 0)
	assert_eq(shown.damage_on_hit, 14)
	assert_eq(shown.damage_on_hit_max, 14)


func test_special_damage_is_not_passed_off_as_physical() -> void:
	var state := BattleSetup.create_opening_battle()
	var card := _ranged_card()
	card.damage_type = AbilityDefinition.DamageType.SPECIAL
	assert_null(rules.strike_outcome(_find(state, "hero-1"), _find(state, "enemy-1"), card, 0))
	var guaranteed := _ranged_card()
	guaranteed.guaranteed_hit = true
	assert_null(rules.strike_outcome(_find(state, "hero-1"), _find(state, "enemy-1"), guaranteed, 0))
	assert_push_error_count(2)


func test_enemy_skips_options_it_cannot_compute() -> void:
	var state := BattleSetup.create_opening_battle()
	state.turn_queue = ["enemy-3", "hero-1", "enemy-1", "hero-3", "hero-2", "enemy-2"]
	_find(state, "hero-1").armor = -1
	var ai := EnemyAi.new(rules)
	var command: Variant = ai.choose_action(state)
	assert_true(command is AbilityCommand)
	var chosen := command as AbilityCommand
	assert_ne(chosen.target_id, "hero-1")
	assert_eq(rules.validate_ability(chosen, state), CombatResult.Rejection.NONE)
	var errors := get_errors()
	assert_gt(errors.size(), 0)
	for error in errors:
		error.handled = true


# --- 12. Dexterity counts once -----------------------------------------------


func test_dexterity_is_not_counted_twice() -> void:
	var state := BattleSetup.create_opening_battle()
	var hunter := _find(state, "hero-2")
	var cultist := _find(state, "enemy-2")
	var shot := AbilityCatalog.definition("hunter_shot")
	# Control numbers at DEX 3: 90 against 20.
	assert_eq(rules.strike_outcome(hunter, cultist, shot, 0).hit_chance, 70)
	# Target-model bases with their DEX give the same 90 and 20.
	hunter.accuracy = 84
	hunter.dexterity = 6
	cultist.dodge = 19
	cultist.dexterity = 4
	assert_eq(rules.strike_outcome(hunter, cultist, shot, 0).hit_chance, 70)
	# The stored control 90 with DEX 6 on top would be 96 − 20 = 76: why control fighters keep DEX 3.
	hunter.accuracy = 90
	cultist.dodge = 20
	cultist.dexterity = 3
	assert_eq(rules.strike_outcome(hunter, cultist, shot, 0).hit_chance, 76)
