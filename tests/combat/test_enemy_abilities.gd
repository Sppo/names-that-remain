extends GutTest

## Phase 7. Enemy cards of the new model and the enemy choice, through the real command path.
## Fighters are test states with the approved stats and ability_ids. The control battle is not touched.


const GUARDIAN_CARDS: Array[String] = ["guardian_shield_bash", "warrior_guard"]
const CULTIST_CARDS: Array[String] = ["cultist_prepared_rite", "cultist_arrow_shot", "cultist_strike"]
const SHADOWCLAW_CARDS: Array[String] = ["shadowclaw_claw_strike", "shadowclaw_finisher"]
const WARRIOR_CARDS: Array[String] = ["warrior_sword", "warrior_guard", "warrior_shield_push", "warrior_battle_stance"]
const HUNTER_CARDS: Array[String] = ["hunter_bow_shot", "hunter_dagger", "hunter_aimed_shot", "hunter_maneuver"]
const MEDIC_CARDS: Array[String] = ["medic_crossbow", "medic_healing", "medic_tincture", "medic_stimulant"]
const NEW_IDS: Array[String] = ["guardian_shield_bash", "cultist_arrow_shot", "cultist_strike", "shadowclaw_claw_strike", "shadowclaw_finisher"]

var rules: CombatRules


func before_each() -> void:
	rules = CombatRules.new()


# --- Helpers ---------------------------------------------------------------


## The approved new start: heroes Warrior 1, Hunter 2, Medic 3; enemies Guardian 1, Shadowclaw 2, Cultist 3.
func _battle() -> CombatState:
	var fighters: Array[CombatantState] = []
	fighters.append(_fighter("warrior", CombatantState.Side.HEROES, 1, 5, 22, 80, 10, 25, [5, 5, 3, 2, 4], WARRIOR_CARDS))
	fighters.append(_fighter("hunter", CombatantState.Side.HEROES, 2, 8, 20, 84, 12, 0, [3, 2, 6, 2, 3], HUNTER_CARDS))
	fighters.append(_fighter("medic", CombatantState.Side.HEROES, 3, 3, 20, 68, 4, 0, [2, 2, 4, 6, 3], MEDIC_CARDS))
	fighters.append(_fighter("guardian", CombatantState.Side.ENEMIES, 1, 4, 20, 77, 11, 50, [4, 4, 2, 1, 5], GUARDIAN_CARDS))
	fighters.append(_fighter("shadowclaw", CombatantState.Side.ENEMIES, 2, 6, 12, 77, 11, 0, [4, 1, 7, 1, 3], SHADOWCLAW_CARDS))
	fighters.append(_fighter("cultist", CombatantState.Side.ENEMIES, 3, 7, 10, 78, 19, 0, [2, 1, 4, 6, 3], CULTIST_CARDS))
	var state := CombatState.new()
	state.round_number = 1
	state.outcome = CombatState.Outcome.ONGOING
	state.combatants = fighters
	state.turn_queue = []
	state.prepared = null
	return state


## stats: strength, armor, dexterity, knowledge, health.
func _fighter(
	id: String,
	side: CombatantState.Side,
	position: int,
	speed: int,
	hp: int,
	accuracy: int,
	dodge: int,
	block: int,
	stats: Array[int],
	ability_ids: Array[String]
) -> CombatantState:
	var fighter := CombatantState.new()
	fighter.id = id
	fighter.display_name = id
	fighter.side = side
	fighter.position = position
	fighter.speed = speed
	fighter.hp = hp
	fighter.max_hp = hp
	fighter.accuracy = accuracy
	fighter.dodge = dodge
	fighter.block = block
	fighter.strength = stats[0]
	fighter.armor = stats[1]
	fighter.dexterity = stats[2]
	fighter.knowledge = stats[3]
	fighter.health = stats[4]
	fighter.ability_ids.assign(ability_ids)
	return fighter


## actor first, then everyone else, so one action never ends the round.
func _turn_of(state: CombatState, actor_id: String) -> void:
	var queue: Array[String] = [actor_id]
	for fighter: CombatantState in state.combatants:
		if fighter.id != actor_id:
			queue.append(fighter.id)
	state.turn_queue = queue


func _use(
	state: CombatState,
	actor_id: String,
	ability_id: String,
	target_id: String,
	rng: RandomNumberGenerator = null
) -> CombatResult:
	_turn_of(state, actor_id)
	if rng == null:
		rng = _rng(1)
	return rules.resolve_ability(_command(actor_id, ability_id, target_id), state, rng)


func _command(actor_id: String, ability_id: String, target_id: String) -> AbilityCommand:
	var command := AbilityCommand.new()
	command.actor_id = actor_id
	command.ability_id = ability_id
	command.target_id = target_id
	return command


func _step(state: CombatState, actor_id: String, destination: int) -> CombatState:
	_turn_of(state, actor_id)
	var command := StepCommand.new()
	command.actor_id = actor_id
	command.destination_position = destination
	var result := rules.resolve(command, state, _rng(1))
	assert_true(result.accepted, "step %s to %d" % [actor_id, destination])
	return result.state


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## First seed whose rolls pass the check. The check makes the same calls the rules will make.
func _seed_where(check: Callable) -> int:
	for seed_value in range(1, 5000):
		if check.call(_rng(seed_value)):
			return seed_value
	return -1


func _find(state: CombatState, combatant_id: String) -> CombatantState:
	for fighter: CombatantState in state.combatants:
		if fighter.id == combatant_id:
			return fighter
	return null


func _remove(state: CombatState, combatant_id: String) -> void:
	state.combatants.erase(_find(state, combatant_id))


func _kinds(events: Array[CombatEvent]) -> Array[CombatEvent.Kind]:
	var kinds: Array[CombatEvent.Kind] = []
	for event: CombatEvent in events:
		kinds.append(event.kind)
	return kinds


func _before_armor(actor: CombatantState, card: AbilityDefinition) -> Array[int]:
	var values: Array[int] = []
	for base in range(card.base_min, card.base_max + 1):
		values.append(rules.damage_before_armor_for(actor, card, base))
	return values


func _dealt(effect_id: String, magnitude: int) -> ActiveEffect:
	var effect := ActiveEffect.new()
	effect.effect_id = effect_id
	effect.kind = ActiveEffect.Kind.PHYSICAL_DEALT_PERCENT
	effect.magnitude = magnitude
	effect.turns_left = 2
	return effect


func _choose(state: CombatState, actor_id: String) -> Variant:
	_turn_of(state, actor_id)
	return EnemyAi.new(rules).choose_action(state)


func _snapshot(state: CombatState) -> String:
	var lines := PackedStringArray()
	lines.append("round=%d outcome=%d queue=%s" % [state.round_number, state.outcome, ",".join(state.turn_queue)])
	if state.prepared == null:
		lines.append("prepared=null")
	else:
		var prepared := state.prepared
		lines.append("prepared=%s/%s/%s/%d" % [prepared.actor_id, prepared.ability_id, prepared.target_id, prepared.amount])
	for fighter: CombatantState in state.combatants:
		var effects := PackedStringArray()
		for effect: ActiveEffect in fighter.effects:
			effects.append("%s:%d:%d:%d:%s" % [effect.effect_id, effect.kind, effect.magnitude, effect.turns_left, effect.skips_next_tick])
		lines.append("%s %d %d %d %d/%d %d %d %d %d %s %d/%d/%d/%d/%d %s [%s]" % [
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
			",".join(effects),
		])
	return "\n".join(lines)


# --- Step B. Cards -------------------------------------------------------------


func test_enemy_cards_have_the_approved_numbers() -> void:
	# id, from, to, target from, to, cooldown, base min, max, STR, DEX, hp percent, dealt bonus
	var rows: Array = [
		["guardian_shield_bash", 1, 2, 1, 2, 0, 4, 6, 100, 0, 0, 0],
		["cultist_arrow_shot", 2, 4, 1, 4, 0, 2, 4, 0, 100, 0, 0],
		["cultist_strike", 1, 2, 1, 2, 0, 2, 3, 100, 0, 0, 0],
		["shadowclaw_claw_strike", 1, 2, 1, 4, 0, 4, 6, 30, 70, 0, 0],
		["shadowclaw_finisher", 1, 2, 1, 4, 2, 4, 6, 30, 70, 50, 30],
	]
	for row: Array in rows:
		var card := AbilityCatalog.definition(row[0])
		assert_not_null(card, row[0])
		assert_eq([card.from_min, card.from_max, card.target_min, card.target_max], [row[1], row[2], row[3], row[4]], row[0])
		assert_eq(card.cooldown_turns, row[5], row[0])
		assert_eq([card.base_min, card.base_max], [row[6], row[7]], row[0])
		assert_eq([card.strength_percent, card.dexterity_percent, card.knowledge_percent], [row[8], row[9], 0], row[0])
		assert_eq([card.target_hp_max_percent, card.dealt_bonus_percent], [row[10], row[11]], row[0])
		assert_true(card.hits_enemies, row[0])
		assert_eq(card.kind, AbilityDefinition.Kind.STRIKE, row[0])
		assert_eq(card.damage_type, AbilityDefinition.DamageType.PHYSICAL, row[0])
		assert_eq(card.multiplier_percent, 100, row[0])
		assert_eq(card.accuracy_bonus, 0, row[0])
		assert_false(card.guaranteed_hit, row[0])
		assert_false(card.pushes_target, row[0])
		assert_eq(card.target_mode, AbilityDefinition.TargetMode.SLOTS, row[0])
		assert_eq(card.amount, 0, row[0])
	# Reused cards keep their numbers.
	var guard := AbilityCatalog.definition("warrior_guard")
	assert_eq([guard.from_min, guard.from_max, guard.target_min, guard.target_max, guard.amount, guard.cooldown_turns], [1, 2, 1, 4, 10, 1])
	var rite := AbilityCatalog.definition("cultist_prepared_rite")
	assert_eq([rite.from_min, rite.from_max, rite.target_min, rite.target_max, rite.amount, rite.cooldown_turns], [2, 4, 3, 4, 11, 2])
	assert_eq([rite.damage_type, rite.knowledge_percent, rite.guaranteed_hit], [AbilityDefinition.DamageType.SPECIAL, 100, true])


func test_control_cards_and_loadouts_stay_as_they_were() -> void:
	var control := BattleSetup.create_opening_battle()
	for fighter: CombatantState in control.combatants:
		assert_eq(fighter.ability_ids, AbilityCatalog.ids_for(fighter.id), fighter.id)
		for ability_id: String in fighter.ability_ids:
			var card := AbilityCatalog.definition(ability_id)
			assert_eq([card.target_hp_max_percent, card.dealt_bonus_percent], [0, 0], ability_id)
		for ability_id: String in NEW_IDS:
			assert_false(fighter.ability_ids.has(ability_id), "%s %s" % [fighter.id, ability_id])
	var execute := AbilityCatalog.definition("shadowclaw_execute")
	assert_eq([execute.amount, execute.finish_amount, execute.finish_below_percent], [5, 8, 50])


func test_damage_before_armor_matches_the_spec() -> void:
	var state := _battle()
	assert_eq(_before_armor(_find(state, "guardian"), AbilityCatalog.definition("guardian_shield_bash")), [4, 5, 7])
	assert_eq(_before_armor(_find(state, "cultist"), AbilityCatalog.definition("cultist_arrow_shot")), [2, 3, 4])
	assert_eq(_before_armor(_find(state, "cultist"), AbilityCatalog.definition("cultist_strike")), [2, 3])
	assert_eq(_before_armor(_find(state, "shadowclaw"), AbilityCatalog.definition("shadowclaw_claw_strike")), [5, 6, 7])
	assert_eq(_before_armor(_find(state, "shadowclaw"), AbilityCatalog.definition("shadowclaw_finisher")), [6, 8, 10])
	var rite := AbilityCatalog.definition("cultist_prepared_rite")
	assert_eq(rules.strike_outcome(_find(state, "cultist"), _find(state, "medic"), rite, 0).on_hit, [14])


func test_hit_chances_add_dexterity_once() -> void:
	var state := _battle()
	assert_eq(rules.preview("guardian", "guardian_shield_bash", "warrior", state).hit_chance, 65)
	assert_eq(rules.preview("cultist", "cultist_arrow_shot", "medic", state).hit_chance, 75)
	assert_eq(rules.preview("shadowclaw", "shadowclaw_claw_strike", "medic", state).hit_chance, 80)
	assert_eq(rules.preview("shadowclaw", "shadowclaw_claw_strike", "hunter", state).hit_chance, 70)


func test_caster_and_target_position_limits() -> void:
	var owners := {
		"guardian_shield_bash": "guardian",
		"warrior_guard": "guardian",
		"cultist_prepared_rite": "cultist",
		"cultist_arrow_shot": "cultist",
		"cultist_strike": "cultist",
		"shadowclaw_claw_strike": "shadowclaw",
		"shadowclaw_finisher": "shadowclaw",
	}
	for ability_id: String in owners.keys():
		var card := AbilityCatalog.definition(ability_id)
		var owner_id: String = owners[ability_id]
		for position in range(1, 5):
			var state := _battle()
			_find(state, owner_id).position = position
			var target := _find(state, "medic" if card.hits_enemies else "cultist")
			target.hp = 5
			target.position = card.target_min
			_turn_of(state, owner_id)
			var allowed := position >= card.from_min and position <= card.from_max
			var wanted := CombatResult.Rejection.NONE if allowed else CombatResult.Rejection.ACTOR_OUT_OF_POSITION
			assert_eq(rules.validate_ability(_command(owner_id, ability_id, target.id), state), wanted, "%s from %d" % [ability_id, position])
		for position in range(1, 5):
			var state := _battle()
			_find(state, owner_id).position = card.from_min
			var target := _find(state, "medic" if card.hits_enemies else "cultist")
			target.hp = 5
			target.position = position
			_turn_of(state, owner_id)
			var allowed := position >= card.target_min and position <= card.target_max
			var wanted := CombatResult.Rejection.NONE if allowed else CombatResult.Rejection.ILLEGAL_TARGET
			assert_eq(rules.validate_ability(_command(owner_id, ability_id, target.id), state), wanted, "%s at %d" % [ability_id, position])


# --- Step C. Finisher, cover, rite -------------------------------------------------


func test_finisher_needs_half_health_or_less_exactly() -> void:
	# max hp, hp, allowed
	for row: Array in [[20, 10, true], [20, 11, false], [21, 10, true], [21, 11, false], [22, 11, true], [22, 12, false], [20, 1, true]]:
		var state := _battle()
		var medic := _find(state, "medic")
		medic.max_hp = row[0]
		medic.hp = row[1]
		_turn_of(state, "shadowclaw")
		var wanted := CombatResult.Rejection.NONE if row[2] else CombatResult.Rejection.ILLEGAL_TARGET
		assert_eq(rules.validate_ability(_command("shadowclaw", "shadowclaw_finisher", "medic"), state), wanted, "%d/%d" % [row[1], row[0]])
		# Claws have no health condition.
		assert_eq(rules.validate_ability(_command("shadowclaw", "shadowclaw_claw_strike", "medic"), state), CombatResult.Rejection.NONE)


func test_finisher_above_half_rejects_atomically() -> void:
	var state := _battle()
	_find(state, "medic").hp = 11
	_turn_of(state, "shadowclaw")
	var before := _snapshot(state)
	var rng := _rng(4)
	var rng_state := rng.state
	var result := rules.resolve_ability(_command("shadowclaw", "shadowclaw_finisher", "medic"), state, rng)
	assert_false(result.accepted)
	assert_eq(result.rejection, CombatResult.Rejection.ILLEGAL_TARGET)
	assert_eq(result.state, state)
	assert_eq(result.events.size(), 0)
	assert_eq(rng.state, rng_state)
	assert_eq(_snapshot(state), before)


func test_finisher_bonus_joins_the_dealt_category_and_is_bounded() -> void:
	var state := _battle()
	var shadowclaw := _find(state, "shadowclaw")
	var finisher := AbilityCatalog.definition("shadowclaw_finisher")
	var claws := AbilityCatalog.definition("shadowclaw_claw_strike")
	# P = 0.7 × 7 + 0.3 × 4 = 6.1, held as 61000 in CombatMath units.
	for row: Array in [[0, 130], [30, 160], [70, 200], [-60, 70], [-100, 40]]:
		shadowclaw.effects.clear()
		if row[0] != 0:
			shadowclaw.effects.append(_dealt("dealt_test", row[0]))
		var values := _before_armor(shadowclaw, finisher)
		for index in values.size():
			var wanted: int = CombatMath.damage_before_armor(4 + index, 100, 61000, row[1], 100)
			assert_eq(values[index], wanted, "effect %d base %d" % [row[0], 4 + index])
	# +30 stimulant and +30 finisher: ×1.6.
	shadowclaw.effects.clear()
	shadowclaw.effects.append(_dealt("combat_stimulant", 30))
	assert_eq(_before_armor(shadowclaw, finisher), [8, 10, 12])
	# The bonus belongs to the card, not to the fighter.
	shadowclaw.effects.clear()
	assert_eq(_before_armor(shadowclaw, claws), [5, 6, 7])
	assert_eq(shadowclaw.effects.size(), 0)


func test_dealt_bonus_does_not_touch_special_damage() -> void:
	var state := _battle()
	var rite := AbilityCatalog.definition("cultist_prepared_rite")
	rite.dealt_bonus_percent = 30
	assert_eq(rules.damage_before_armor_for(_find(state, "cultist"), rite, 11, _find(state, "medic")), 14)


func test_finisher_goes_through_armor_block_and_cover() -> void:
	var state := _battle()
	var warrior := _find(state, "warrior")
	warrior.hp = 11
	var finisher := AbilityCatalog.definition("shadowclaw_finisher")
	var table := rules.strike_outcome(_find(state, "shadowclaw"), warrior, finisher, 0)
	# 6/8/10 through armor 5: 4.8, 6.4, 8 → 5, 6, 8. Block halves to 2, 3, 4.
	assert_eq(table.listed, [5, 6, 8])
	assert_eq(table.on_hit, [5, 6, 8])
	assert_eq(table.if_blocked, [2, 3, 4])
	assert_eq(table.block_chance, 25)
	var covered := rules.strike_outcome(_find(state, "shadowclaw"), warrior, finisher, 10)
	assert_eq(covered.on_hit, [0, 0, 0])
	assert_eq(covered.if_blocked, [0, 0, 0])

	# Through the command: hit, base 6, block → 4, three rolls.
	var seed_value := _seed_where(func(r: RandomNumberGenerator) -> bool:
		return r.randi_range(1, 100) <= table.hit_chance and r.randi_range(4, 6) == 6 and r.randi_range(1, 100) <= 25)
	var rng := _rng(seed_value)
	var result := _use(state, "shadowclaw", "shadowclaw_finisher", "warrior", rng)
	var replay := _rng(seed_value)
	replay.randi_range(1, 100)
	replay.randi_range(4, 6)
	replay.randi_range(1, 100)
	assert_eq(rng.state, replay.state)
	assert_eq(result.events[0].kind, CombatEvent.Kind.DAMAGE_APPLIED)
	assert_eq(result.events[0].listed_amount, 8)
	assert_eq(result.events[0].amount, 4)
	assert_eq(result.events[0].mitigation, CombatEvent.Mitigation.BLOCK)
	assert_eq(_find(result.state, "shadowclaw").cooldown_left["shadowclaw_finisher"], 2)


func test_finisher_cooldown_two_counts_own_turns() -> void:
	var state := _battle()
	_find(state, "medic").hp = 6
	_find(state, "shadowclaw").accuracy = 0
	var current := _use(state, "shadowclaw", "shadowclaw_finisher", "medic").state
	for own_turn in range(1, 4):
		_turn_of(current, "shadowclaw")
		var wanted := CombatResult.Rejection.ON_COOLDOWN if own_turn <= 2 else CombatResult.Rejection.NONE
		assert_eq(rules.validate_ability(_command("shadowclaw", "shadowclaw_finisher", "medic"), current), wanted, "turn %d" % own_turn)
		current = _step(current, "shadowclaw", 1 if _find(current, "shadowclaw").position == 2 else 2)


func test_physical_strikes_roll_once_on_a_miss_and_three_times_on_a_hit() -> void:
	for row: Array in [
		["guardian", "guardian_shield_bash", "warrior", 4, 6],
		["cultist", "cultist_arrow_shot", "medic", 2, 4],
		["shadowclaw", "shadowclaw_claw_strike", "hunter", 4, 6],
	]:
		var state := _battle()
		var table := rules.strike_outcome(_find(state, row[0]), _find(state, row[2]), AbilityCatalog.definition(row[1]), 0)
		var low: int = row[3]
		var high: int = row[4]
		var hit_seed := _seed_where(func(r: RandomNumberGenerator) -> bool:
			return r.randi_range(1, 100) <= table.hit_chance and r.randi_range(low, high) == low and r.randi_range(1, 100) > table.block_chance)
		var rng := _rng(hit_seed)
		var hit := _use(state, row[0], row[1], row[2], rng)
		var replay := _rng(hit_seed)
		replay.randi_range(1, 100)
		replay.randi_range(low, high)
		replay.randi_range(1, 100)
		assert_eq(rng.state, replay.state, row[1])
		assert_eq(hit.events[0].listed_amount, table.listed[0], row[1])
		var miss_seed := _seed_where(func(r: RandomNumberGenerator) -> bool: return r.randi_range(1, 100) > table.hit_chance)
		var miss_rng := _rng(miss_seed)
		var missed := _use(_battle(), row[0], row[1], row[2], miss_rng)
		var miss_replay := _rng(miss_seed)
		miss_replay.randi_range(1, 100)
		assert_eq(miss_rng.state, miss_replay.state, row[1])
		assert_eq(missed.events[0].kind, CombatEvent.Kind.MISSED, row[1])
	# Cultist's basic strike from slot 2 on the warrior, through the command.
	var close := _battle()
	_find(close, "cultist").position = 2
	_find(close, "shadowclaw").position = 3
	var strike_table := rules.strike_outcome(_find(close, "cultist"), _find(close, "warrior"), AbilityCatalog.definition("cultist_strike"), 0)
	# 2/3 through armor 5: 1.6, 2.4 → 2, 2.
	assert_eq(strike_table.listed, [2, 2])
	var strike_seed := _seed_where(func(r: RandomNumberGenerator) -> bool:
		return r.randi_range(1, 100) <= strike_table.hit_chance and r.randi_range(2, 3) == 3 and r.randi_range(1, 100) > strike_table.block_chance)
	var strike_rng := _rng(strike_seed)
	var struck := _use(close, "cultist", "cultist_strike", "warrior", strike_rng)
	var strike_replay := _rng(strike_seed)
	strike_replay.randi_range(1, 100)
	strike_replay.randi_range(2, 3)
	strike_replay.randi_range(1, 100)
	assert_eq(strike_rng.state, strike_replay.state)
	assert_eq([struck.events[0].listed_amount, struck.events[0].amount], [2, 2])


func test_guardian_cover_on_self_and_ally_stops_physical_and_not_special() -> void:
	var self_covered := _use(_battle(), "guardian", "warrior_guard", "guardian")
	assert_eq(_kinds(self_covered.events), [CombatEvent.Kind.GUARD_PLACED])
	assert_eq(_find(self_covered.state, "guardian").guard_reduction, 10)
	assert_eq(_find(self_covered.state, "guardian").cooldown_left["warrior_guard"], 1)

	var ally := _use(_battle(), "guardian", "warrior_guard", "cultist")
	assert_eq(_find(ally.state, "cultist").guard_reduction, 10)
	assert_eq(_find(ally.state, "guardian").guard_reduction, 0)
	var shot := AbilityCatalog.definition("hunter_bow_shot")
	var table := rules.strike_outcome(_find(ally.state, "hunter"), _find(ally.state, "cultist"), shot, 10)
	assert_eq(table.on_hit, [0, 0, 0])
	var seed_value := _seed_where(func(r: RandomNumberGenerator) -> bool: return r.randi_range(1, 100) <= table.hit_chance)
	var hit := _use(ally.state, "hunter", "hunter_bow_shot", "cultist", _rng(seed_value))
	assert_eq(hit.events[0].amount, 0)
	assert_eq(_find(hit.state, "cultist").guard_reduction, 0)
	assert_eq(_find(hit.state, "cultist").hp, 10)

	# The rite ignores cover on the medic and leaves it in place.
	var medic_covered := _battle()
	_find(medic_covered, "medic").guard_reduction = 10
	var prepared := _use(medic_covered, "cultist", "cultist_prepared_rite", "medic").state
	var released := _use(prepared, "cultist", "cultist_arrow_shot", "warrior")
	assert_eq(released.events[0].amount, 14)
	assert_eq(_find(released.state, "medic").guard_reduction, 10)


func test_rite_lifecycle_with_the_new_loadout() -> void:
	# Preparation: no damage, cooldown 2, target kept.
	var prepared := _use(_battle(), "cultist", "cultist_prepared_rite", "medic")
	assert_eq(_kinds(prepared.events), [CombatEvent.Kind.PREPARED_STRIKE])
	assert_eq(_find(prepared.state, "cultist").cooldown_left["cultist_prepared_rite"], 2)
	assert_eq(_find(prepared.state, "medic").hp, 20)

	# Release on the next own turn: 14, no rolls, whatever the AI would choose.
	var waiting := prepared.state
	_turn_of(waiting, "cultist")
	assert_null(EnemyAi.new(rules).choose_action(waiting))
	var rng := _rng(8)
	var rng_state := rng.state
	var released := EnemyAi.new(rules).take_turn(waiting, rng)
	assert_eq(rng.state, rng_state)
	assert_eq(released.events[0].amount, 14)
	assert_null(released.state.prepared)

	# Tincture after preparation: 8.
	var protected := _use(prepared.state, "medic", "medic_tincture", "medic").state
	_turn_of(protected, "cultist")
	assert_eq(EnemyAi.new(rules).take_turn(protected, _rng(8)).events[0].amount, 8)

	# A pushed cultist keeps the preparation.
	var forward := _battle()
	_find(forward, "cultist").position = 2
	_find(forward, "shadowclaw").position = 3
	var ready := _use(forward, "cultist", "cultist_prepared_rite", "medic").state
	var push := AbilityCatalog.definition("warrior_shield_push")
	var push_table := rules.strike_outcome(_find(ready, "warrior"), _find(ready, "cultist"), push, 0)
	var push_seed := _seed_where(func(r: RandomNumberGenerator) -> bool:
		return r.randi_range(1, 100) <= push_table.hit_chance)
	var pushed := _use(ready, "warrior", "warrior_shield_push", "cultist", _rng(push_seed))
	assert_eq(_find(pushed.state, "cultist").position, 3)
	assert_not_null(pushed.state.prepared)
	_turn_of(pushed.state, "cultist")
	assert_eq(EnemyAi.new(rules).take_turn(pushed.state, _rng(1)).events[0].other_id, "medic")

	# The target's death cancels without retargeting; the cultist then chooses an ordinary action.
	var lost_target := prepared.state
	_remove(lost_target, "medic")
	_turn_of(lost_target, "cultist")
	var after_loss := EnemyAi.new(rules).take_turn(lost_target, _rng(3))
	assert_true(after_loss.accepted)
	assert_null(after_loss.state.prepared)
	for event: CombatEvent in after_loss.events:
		assert_ne(event.ability_id, "cultist_prepared_rite")

	# The cultist's death clears the preparation.
	var dying := _use(_battle(), "cultist", "cultist_prepared_rite", "medic").state
	_find(dying, "cultist").hp = 0
	var expelled := _step(dying, "hunter", 3)
	assert_null(expelled.prepared)
	assert_null(_find(expelled, "cultist"))


# --- Step D. Enemy choice ------------------------------------------------------------


func test_ai_returns_only_legal_commands_and_never_rolls_or_writes() -> void:
	var states: Array[CombatState] = []
	states.append(_battle())
	var weak := _battle()
	_find(weak, "medic").hp = 6
	_find(weak, "hunter").hp = 9
	states.append(weak)
	var rear := _battle()
	_find(rear, "guardian").position = 4
	_find(rear, "cultist").position = 1
	states.append(rear)
	var buffed := _use(_battle(), "medic", "medic_tincture", "medic").state
	buffed = _use(buffed, "warrior", "warrior_battle_stance", "warrior").state
	states.append(buffed)
	for state: CombatState in states:
		for enemy_id: String in ["guardian", "shadowclaw", "cultist"]:
			_turn_of(state, enemy_id)
			var before := _snapshot(state)
			var first: Variant = EnemyAi.new(rules).choose_action(state)
			var second: Variant = EnemyAi.new(rules).choose_action(state)
			assert_eq(_snapshot(state), before, enemy_id)
			assert_not_null(first, enemy_id)
			if first is AbilityCommand:
				assert_eq(rules.validate_ability(first, state), CombatResult.Rejection.NONE, enemy_id)
				assert_eq([first.ability_id, first.target_id], [second.ability_id, second.target_id], enemy_id)
			elif first is PassCommand:
				assert_eq(rules.validate_pass(first, state), CombatResult.Rejection.NONE, enemy_id)
				assert_true(second is PassCommand, enemy_id)
			else:
				assert_eq(rules.validate(first, state), CombatResult.Rejection.NONE, enemy_id)
				assert_eq(first.destination_position, second.destination_position, enemy_id)
			var ai_rng := _rng(17)
			var rules_rng := _rng(17)
			var by_ai := EnemyAi.new(rules).take_turn(state, ai_rng)
			var by_rules: CombatResult = null
			if first is AbilityCommand:
				by_rules = rules.resolve_ability(first, state, rules_rng)
			elif first is PassCommand:
				by_rules = rules.resolve_pass(first, state, rules_rng)
			else:
				by_rules = rules.resolve(first, state, rules_rng)
			assert_true(by_ai.accepted, enemy_id)
			assert_eq(ai_rng.state, rules_rng.state, enemy_id)
			assert_eq(_snapshot(by_ai.state), _snapshot(by_rules.state), enemy_id)


func test_shadowclaw_takes_the_finisher_on_a_weak_hero_and_never_above_half() -> void:
	var weak := _battle()
	_find(weak, "medic").hp = 6
	var chosen: Variant = _choose(weak, "shadowclaw")
	assert_true(chosen is AbilityCommand)
	assert_eq([chosen.ability_id, chosen.target_id], ["shadowclaw_finisher", "medic"])
	var utility := EnemyUtility.new(rules)
	var shadowclaw := _find(weak, "shadowclaw")
	var medic := _find(weak, "medic")
	var finisher_points: int = utility._strike_points(weak, shadowclaw, AbilityCatalog.definition("shadowclaw_finisher"), medic)
	var claw_points: int = utility._strike_points(weak, shadowclaw, AbilityCatalog.definition("shadowclaw_claw_strike"), medic)
	assert_gt(finisher_points, claw_points)

	var healthy := _battle()
	for hp in range(11, 21):
		_find(healthy, "medic").hp = hp
		var pick: Variant = _choose(healthy, "shadowclaw")
		assert_true(pick is AbilityCommand)
		assert_ne(pick.ability_id, "shadowclaw_finisher", "hp %d" % hp)


func test_cultist_compares_the_rite_with_ordinary_strikes() -> void:
	var utility := EnemyUtility.new(rules)
	var state := _battle()
	var cultist := _find(state, "cultist")
	var medic := _find(state, "medic")
	var rite := AbilityCatalog.definition("cultist_prepared_rite")
	var plain: int = utility._rite_points(state, cultist, rite, medic)
	var protected := _use(state, "medic", "medic_tincture", "medic").state
	_turn_of(protected, "cultist")
	var lowered: int = utility._rite_points(protected, _find(protected, "cultist"), rite, _find(protected, "medic"))
	assert_gt(plain, lowered)
	assert_gt(lowered, 0)

	# Nobody on hero slots 3–4: the rite is not offered.
	var no_rear := _battle()
	_find(no_rear, "medic").position = 2
	_find(no_rear, "hunter").position = 3
	_find(no_rear, "hunter").hp = 0
	_remove(no_rear, "hunter")
	var pick: Variant = _choose(no_rear, "cultist")
	assert_true(pick is AbilityCommand)
	assert_ne(pick.ability_id, "cultist_prepared_rite")

	# The chosen command scores at least as much as every other legal option.
	_turn_of(state, "cultist")
	var chosen: Variant = EnemyAi.new(rules).choose_action(state)
	assert_true(chosen is AbilityCommand)
	var chosen_points: int = utility._score_ability(state, cultist, AbilityCatalog.definition(chosen.ability_id), _find(state, chosen.target_id))
	for ability_id: String in CULTIST_CARDS:
		for target: CombatantState in state.combatants:
			if rules.validate_ability(_command("cultist", ability_id, target.id), state) != CombatResult.Rejection.NONE:
				continue
			var points: int = utility._score_ability(state, cultist, AbilityCatalog.definition(ability_id), target)
			assert_true(points <= chosen_points, "%s on %s" % [ability_id, target.id])


func test_cover_scores_zero_on_a_fighter_already_covered() -> void:
	var utility := EnemyUtility.new(rules)
	var state := _battle()
	_turn_of(state, "guardian")
	var guard := AbilityCatalog.definition("warrior_guard")
	_find(state, "cultist").guard_reduction = 10
	assert_eq(utility._guard_points(state, guard, _find(state, "cultist")), 0)


func test_without_offense_the_enemy_advances_into_an_empty_slot() -> void:
	# Guardian pushed to 3, slot 2 empty: one step forward, not a strike, not cover.
	var state := _battle()
	_find(state, "guardian").position = 3
	_find(state, "cultist").position = 4
	_find(state, "shadowclaw").position = 1
	var chosen: Variant = _choose(state, "guardian")
	assert_true(chosen is StepCommand)
	assert_eq(chosen.destination_position, 2)
	var result := EnemyAi.new(rules).take_turn(state, _rng(1))
	assert_eq(_kinds(result.events), [CombatEvent.Kind.STEPPED])

	# A rite on cooldown is not offense: the cultist alone with that card advances.
	var waiting := _battle()
	_remove(waiting, "shadowclaw")
	_find(waiting, "cultist").ability_ids.assign(["cultist_prepared_rite"])
	_find(waiting, "cultist").cooldown_left["cultist_prepared_rite"] = 1
	var advance: Variant = _choose(waiting, "cultist")
	assert_true(advance is StepCommand)
	assert_eq(advance.destination_position, 2)


func test_without_offense_and_a_held_slot_the_enemy_covers_and_never_swaps() -> void:
	# Guardian at 1, heroes only on 3–4: no strike, no slot ahead, cover is chosen.
	var state := _battle()
	_find(state, "warrior").position = 3
	_find(state, "hunter").position = 4
	_remove(state, "medic")
	var chosen: Variant = _choose(state, "guardian")
	assert_true(chosen is AbilityCommand)
	assert_eq(chosen.ability_id, "warrior_guard")
	assert_eq(rules.validate_ability(chosen, state), CombatResult.Rejection.NONE)

	# Guardian at 3 behind the shadowclaw at 2: no swap and no cover from slot 3, so a pass.
	var behind := _battle()
	_find(behind, "guardian").position = 3
	_find(behind, "cultist").position = 4
	var idle: Variant = _choose(behind, "guardian")
	assert_true(idle is PassCommand)
	assert_eq(idle.actor_id, "guardian")

	# Cultist at 1 with heroes only on 3–4, no cover card: nothing to do.
	var stuck := _battle()
	_find(stuck, "cultist").position = 1
	_find(stuck, "guardian").position = 3
	_find(stuck, "warrior").position = 3
	_find(stuck, "medic").position = 4
	_remove(stuck, "hunter")
	var stuck_choice: Variant = _choose(stuck, "cultist")
	assert_true(stuck_choice is PassCommand)
	assert_eq(rules.validate_pass(stuck_choice, stuck), CombatResult.Rejection.NONE)


func test_ties_break_the_same_way_every_time() -> void:
	var state := _battle()
	_turn_of(state, "guardian")
	var picks := PackedStringArray()
	for attempt in range(5):
		var chosen: Variant = EnemyAi.new(rules).choose_action(state)
		picks.append("%s>%s" % [chosen.ability_id, chosen.target_id])
	for pick in picks:
		assert_eq(pick, picks[0])


# --- Pass -------------------------------------------------------------------------


func _pass_command(actor_id: String) -> PassCommand:
	var command := PassCommand.new()
	command.actor_id = actor_id
	return command


func test_a_hero_pass_ends_the_turn_ticks_cooldowns_and_effects_and_never_rolls() -> void:
	var state := _use(_battle(), "warrior", "warrior_battle_stance", "warrior").state
	var warrior := _find(state, "warrior")
	assert_eq(warrior.cooldown_left["warrior_battle_stance"], 3)
	assert_eq(warrior.effects[0].turns_left, 2)
	_turn_of(state, "warrior")
	var before := _snapshot(state)
	var rng := _rng(6)
	var rng_state := rng.state
	var result := rules.resolve_pass(_pass_command("warrior"), state, rng)
	assert_true(result.accepted)
	assert_eq(rng.state, rng_state)
	assert_eq(_kinds(result.events), [CombatEvent.Kind.TURN_PASSED])
	assert_eq(result.events[0].actor_id, "warrior")
	var after := _find(result.state, "warrior")
	assert_eq(after.cooldown_left["warrior_battle_stance"], 2)
	assert_eq(after.effects[0].turns_left, 1)
	assert_eq(after.position, 1)
	assert_eq(after.hp, 22)
	assert_eq(result.state.turn_queue[0], "hunter")
	assert_false(result.state.turn_queue.has("warrior"))
	assert_eq(_snapshot(state), before)

	# The next own pass ends the stance and reports it after the pass.
	_turn_of(result.state, "warrior")
	var second := rules.resolve_pass(_pass_command("warrior"), result.state, _rng(6))
	assert_eq(_kinds(second.events), [CombatEvent.Kind.TURN_PASSED, CombatEvent.Kind.EFFECT_EXPIRED])
	assert_eq(_find(second.state, "warrior").cooldown_left["warrior_battle_stance"], 1)


func test_an_enemy_pass_through_the_ai_moves_the_queue() -> void:
	var state := _battle()
	_find(state, "cultist").position = 1
	_find(state, "guardian").position = 3
	_find(state, "warrior").position = 3
	_find(state, "medic").position = 4
	_remove(state, "hunter")
	_find(state, "cultist").cooldown_left["cultist_prepared_rite"] = 2
	_turn_of(state, "cultist")
	var rng := _rng(4)
	var rng_state := rng.state
	var result := EnemyAi.new(rules).take_turn(state, rng)
	assert_true(result.accepted)
	assert_eq(rng.state, rng_state)
	assert_eq(_kinds(result.events), [CombatEvent.Kind.TURN_PASSED])
	assert_eq(_find(result.state, "cultist").position, 1)
	assert_eq(_find(result.state, "cultist").cooldown_left["cultist_prepared_rite"], 1)
	assert_eq(result.state.turn_queue[0], "warrior")


func test_the_last_pass_of_a_round_starts_the_next_one() -> void:
	var state := _battle()
	state.turn_queue = ["medic"]
	var result := rules.resolve_pass(_pass_command("medic"), state, _rng(1))
	assert_eq(_kinds(result.events), [CombatEvent.Kind.TURN_PASSED, CombatEvent.Kind.ROUND_STARTED])
	assert_eq(result.state.round_number, 2)
	assert_eq(result.state.turn_queue, rules.build_turn_queue(result.state.combatants))


func test_a_due_prepared_strike_replaces_the_pass_command() -> void:
	var prepared := _use(_battle(), "cultist", "cultist_prepared_rite", "medic").state
	_turn_of(prepared, "cultist")
	var rng := _rng(5)
	var rng_state := rng.state
	var result := rules.resolve_pass(_pass_command("cultist"), prepared, rng)
	assert_true(result.accepted)
	assert_eq(rng.state, rng_state)
	assert_false(_kinds(result.events).has(CombatEvent.Kind.TURN_PASSED))
	assert_eq(result.events[0].kind, CombatEvent.Kind.DAMAGE_APPLIED)
	assert_eq(result.events[0].amount, 14)
	assert_null(result.state.prepared)

	# With the target gone the record is dropped and the pass is played.
	var lost := _use(_battle(), "cultist", "cultist_prepared_rite", "medic").state
	_remove(lost, "medic")
	_turn_of(lost, "cultist")
	var after_loss := rules.resolve_pass(_pass_command("cultist"), lost, _rng(5))
	assert_eq(_kinds(after_loss.events), [CombatEvent.Kind.TURN_PASSED])
	assert_null(after_loss.state.prepared)


func test_an_invalid_pass_is_rejected_without_changes() -> void:
	# command actor, battle outcome, reason
	var cases: Array = [
		["hunter", CombatState.Outcome.ONGOING, CombatResult.Rejection.NOT_ACTIVE_TURN],
		["nobody", CombatState.Outcome.ONGOING, CombatResult.Rejection.UNKNOWN_ACTOR],
		["", CombatState.Outcome.ONGOING, CombatResult.Rejection.UNKNOWN_ACTOR],
		["warrior", CombatState.Outcome.HEROES_VICTORIOUS, CombatResult.Rejection.BATTLE_FINISHED],
	]
	for row: Array in cases:
		var state := _battle()
		_turn_of(state, "warrior")
		state.outcome = row[1]
		var before := _snapshot(state)
		var rng := _rng(2)
		var rng_state := rng.state
		var result := rules.resolve_pass(_pass_command(row[0]), state, rng)
		assert_false(result.accepted, row[0])
		assert_eq(result.rejection, row[2], row[0])
		assert_eq(result.state, state)
		assert_eq(result.events.size(), 0)
		assert_eq(rng.state, rng_state)
		assert_eq(_snapshot(state), before)
	# No active fighter at all: the AI's turn is rejected the same way.
	var empty := _battle()
	empty.turn_queue = []
	var none := EnemyAi.new(rules).take_turn(empty, _rng(2))
	assert_false(none.accepted)
	assert_eq(none.state, empty)


func test_the_ai_never_steps_back_or_swaps_without_offense() -> void:
	# Every enemy placement on slots 1–4 with heroes kept out of reach of every card.
	for guardian_slot in range(1, 5):
		for cultist_slot in range(1, 5):
			if cultist_slot == guardian_slot:
				continue
			var state := _battle()
			_remove(state, "shadowclaw")
			_remove(state, "medic")
			_remove(state, "hunter")
			# A warrior far back: only the cultist's arrow and rite from 2–4 can reach slot 3–4.
			_find(state, "warrior").position = 4
			_find(state, "guardian").position = guardian_slot
			_find(state, "cultist").position = cultist_slot
			for enemy_id: String in ["guardian", "cultist"]:
				var enemy := _find(state, enemy_id)
				var chosen: Variant = _choose(state, enemy_id)
				assert_not_null(chosen, enemy_id)
				if chosen is StepCommand:
					assert_eq(chosen.destination_position, enemy.position - 1, "%s from %d" % [enemy_id, enemy.position])
					var ally := _find(state, "cultist" if enemy_id == "guardian" else "guardian")
					assert_ne(ally.position, chosen.destination_position, "%s swapped" % enemy_id)
				var result: CombatResult = null
				if chosen is StepCommand:
					result = rules.resolve(chosen, state, _rng(1))
				elif chosen is PassCommand:
					result = rules.resolve_pass(chosen, state, _rng(1))
				else:
					result = rules.resolve_ability(chosen, state, _rng(1))
				assert_true(result.accepted, "%s at %d" % [enemy_id, enemy.position])
				assert_false(result.state.turn_queue.has(enemy_id) and result.state.turn_queue[0] == enemy_id, enemy_id)


func test_a_real_tie_on_cover_breaks_by_slot() -> void:
	# No offense from slot 1 with heroes on 3–4, and every ally already covered: every cover scores 0.
	var state := _battle()
	_find(state, "warrior").position = 3
	_find(state, "hunter").position = 4
	_remove(state, "medic")
	for enemy_id: String in ["guardian", "shadowclaw", "cultist"]:
		_find(state, enemy_id).guard_reduction = 10
	var utility := EnemyUtility.new(rules)
	_turn_of(state, "guardian")
	for enemy_id: String in ["guardian", "shadowclaw", "cultist"]:
		assert_eq(utility._guard_points(state, AbilityCatalog.definition("warrior_guard"), _find(state, enemy_id)), 0)
	for attempt in range(3):
		var chosen: Variant = _choose(state, "guardian")
		assert_true(chosen is AbilityCommand)
		assert_eq([chosen.ability_id, chosen.target_id], ["warrior_guard", "guardian"])
	# After swapping slots the same tie picks the fighter now on slot 1.
	_find(state, "guardian").position = 2
	_find(state, "shadowclaw").position = 1
	var second: Variant = _choose(state, "guardian")
	assert_eq(second.target_id, "shadowclaw")


func test_offense_whose_numbers_fail_does_not_bring_back_a_retreat() -> void:
	# Shadowclaw at 1, cultist at 2; the only hero breaks the formulas, so no offense can be scored.
	var state := _battle()
	_remove(state, "guardian")
	_remove(state, "hunter")
	_remove(state, "medic")
	_find(state, "shadowclaw").position = 1
	_find(state, "cultist").position = 2
	_find(state, "warrior").dexterity = -1
	var chosen: Variant = _choose(state, "shadowclaw")
	assert_true(chosen is PassCommand)
	assert_eq(chosen.actor_id, "shadowclaw")
	var errors := get_errors()
	assert_gt(errors.size(), 0)
	for error in errors:
		error.handled = true

