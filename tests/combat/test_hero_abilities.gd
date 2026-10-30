extends GutTest

## Phase 6. The twelve starting hero cards through the real command path.
## Fighters here are test states with the approved stats and ability_ids. The control battle is not touched.


const WARRIOR_CARDS: Array[String] = ["warrior_sword", "warrior_guard", "warrior_shield_push", "warrior_battle_stance"]
const HUNTER_CARDS: Array[String] = ["hunter_bow_shot", "hunter_dagger", "hunter_aimed_shot", "hunter_maneuver"]
const MEDIC_CARDS: Array[String] = ["medic_crossbow", "medic_healing", "medic_tincture", "medic_stimulant"]

var rules: CombatRules


func before_each() -> void:
	rules = CombatRules.new()


# --- Helpers ---------------------------------------------------------------


## Heroes 1–3 and enemies 1–3 of the approved new start. Slot 4 stays empty on both sides.
func _battle() -> CombatState:
	var fighters: Array[CombatantState] = []
	fighters.append(_fighter("warrior", CombatantState.Side.HEROES, 1, 5, 22, 80, 10, 25, [5, 5, 3, 2, 4], WARRIOR_CARDS))
	fighters.append(_fighter("hunter", CombatantState.Side.HEROES, 2, 8, 20, 84, 12, 0, [3, 2, 6, 2, 3], HUNTER_CARDS))
	fighters.append(_fighter("medic", CombatantState.Side.HEROES, 3, 3, 20, 68, 4, 0, [2, 2, 4, 6, 3], MEDIC_CARDS))
	fighters.append(_fighter("guardian", CombatantState.Side.ENEMIES, 1, 4, 20, 77, 11, 50, [4, 4, 2, 1, 5], ["guardian_basic"]))
	fighters.append(_fighter("shadowclaw", CombatantState.Side.ENEMIES, 2, 6, 12, 77, 11, 0, [4, 1, 7, 1, 3], ["shadowclaw_claws"]))
	fighters.append(_fighter("cultist", CombatantState.Side.ENEMIES, 3, 7, 10, 78, 19, 0, [2, 1, 4, 6, 3], ["cultist_prepared_rite", "cultist_basic"]))
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
	rng: RandomNumberGenerator = null,
	destination: int = 0
) -> CombatResult:
	_turn_of(state, actor_id)
	if rng == null:
		rng = _rng(1)
	return rules.resolve_ability(_command(actor_id, ability_id, target_id, destination), state, rng)


func _command(actor_id: String, ability_id: String, target_id: String, destination: int = 0) -> AbilityCommand:
	var command := AbilityCommand.new()
	command.actor_id = actor_id
	command.ability_id = ability_id
	command.target_id = target_id
	command.destination_position = destination
	return command


## One own turn spent on a step, so effects and cooldowns tick without rolling.
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


func _kinds(events: Array[CombatEvent]) -> Array[CombatEvent.Kind]:
	var kinds: Array[CombatEvent.Kind] = []
	for event: CombatEvent in events:
		kinds.append(event.kind)
	return kinds


func _effect(fighter: CombatantState, effect_id: String) -> ActiveEffect:
	for effect: ActiveEffect in fighter.effects:
		if effect.effect_id == effect_id:
			return effect
	return null


## Damage before armor for every base of the card, lowest base first.
func _before_armor(actor: CombatantState, card: AbilityDefinition) -> Array[int]:
	var values: Array[int] = []
	for base in range(card.base_min, card.base_max + 1):
		values.append(rules.damage_before_armor_for(actor, card, base))
	return values


## Every field of the battle, its fighters and their effects, to prove nothing was written.
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


# --- Step A. Cards -------------------------------------------------------------


func test_twelve_cards_have_the_approved_numbers() -> void:
	var kind := AbilityDefinition.Kind
	var mode := AbilityDefinition.TargetMode
	# id, from, to, target from, to, hits enemies, kind, cooldown, base min, max, STR, DEX, KNO, amount, accuracy, mode
	var rows: Array = [
		["warrior_sword", 1, 2, 1, 2, true, kind.STRIKE, 0, 4, 6, 100, 0, 0, 0, 0, mode.SLOTS],
		["warrior_guard", 1, 2, 1, 4, false, kind.GUARD, 1, 0, 0, 0, 0, 0, 10, 0, mode.SLOTS],
		["warrior_shield_push", 1, 2, 1, 2, true, kind.STRIKE, 2, 2, 4, 100, 0, 0, 0, 0, mode.SLOTS],
		["warrior_battle_stance", 1, 4, 1, 4, false, kind.EFFECT, 3, 0, 0, 0, 0, 0, 0, 0, mode.SELF],
		["hunter_bow_shot", 2, 4, 1, 4, true, kind.STRIKE, 0, 3, 5, 0, 100, 0, 0, 0, mode.SLOTS],
		["hunter_dagger", 1, 2, 1, 1, true, kind.STRIKE, 0, 5, 7, 40, 60, 0, 0, 0, mode.SLOTS],
		["hunter_aimed_shot", 2, 4, 2, 4, true, kind.STRIKE, 2, 3, 5, 0, 100, 0, 0, 15, mode.SLOTS],
		["hunter_maneuver", 1, 4, 1, 4, false, kind.MANEUVER, 3, 0, 0, 0, 0, 0, 0, 0, mode.OWN_ADJACENT],
		["medic_crossbow", 2, 4, 1, 4, true, kind.STRIKE, 0, 2, 4, 0, 100, 0, 0, 0, mode.SLOTS],
		["medic_healing", 3, 4, 1, 4, false, kind.HEAL, 2, 0, 0, 0, 0, 100, 4, 0, mode.SLOTS],
		["medic_tincture", 1, 4, 1, 4, false, kind.EFFECT, 3, 0, 0, 0, 0, 0, 0, 0, mode.SLOTS],
		["medic_stimulant", 2, 4, 1, 4, false, kind.EFFECT, 3, 0, 0, 0, 0, 0, 0, 0, mode.SLOTS],
	]
	for row: Array in rows:
		var card := AbilityCatalog.definition(row[0])
		assert_not_null(card, row[0])
		assert_eq(card.id, row[0])
		assert_eq([card.from_min, card.from_max, card.target_min, card.target_max], [row[1], row[2], row[3], row[4]], row[0])
		assert_eq(card.hits_enemies, row[5], row[0])
		assert_eq(card.kind, row[6], row[0])
		assert_eq(card.cooldown_turns, row[7], row[0])
		assert_eq([card.base_min, card.base_max], [row[8], row[9]], row[0])
		assert_eq([card.strength_percent, card.dexterity_percent, card.knowledge_percent], [row[10], row[11], row[12]], row[0])
		assert_eq(card.amount, row[13], row[0])
		assert_eq(card.accuracy_bonus, row[14], row[0])
		assert_eq(card.target_mode, row[15], row[0])
		assert_eq(card.damage_type, AbilityDefinition.DamageType.PHYSICAL, row[0])
		assert_eq(card.multiplier_percent, 100, row[0])
		assert_false(card.guaranteed_hit, row[0])
		assert_eq(card.pushes_target, row[0] == "warrior_shield_push", row[0])

	# effect id, kind, magnitude, turns
	var effects := {
		"warrior_battle_stance": ["battle_stance", ActiveEffect.Kind.BLOCK_POINTS, 50],
		"hunter_maneuver": ["maneuver_dodge", ActiveEffect.Kind.DODGE_POINTS, 20],
		"medic_tincture": ["resilience_tincture", ActiveEffect.Kind.SPECIAL_RECEIVED_PERCENT, -40],
		"medic_stimulant": ["combat_stimulant", ActiveEffect.Kind.PHYSICAL_DEALT_PERCENT, 30],
	}
	for row: Array in rows:
		var card := AbilityCatalog.definition(row[0])
		if effects.has(card.id):
			var wanted: Array = effects[card.id]
			assert_eq([card.effect_id, card.effect_kind, card.effect_magnitude, card.effect_turns], [wanted[0], wanted[1], wanted[2], 2], card.id)
		else:
			assert_eq(card.effect_id, "", card.id)


func test_cover_is_the_unchanged_control_card() -> void:
	var guard := AbilityCatalog.definition("warrior_guard")
	assert_eq(guard.label, "Прикрити")
	assert_eq(guard.amount, 10)
	assert_eq(guard.cooldown_turns, 1)
	assert_eq(guard.kind, AbilityDefinition.Kind.GUARD)
	assert_eq(guard.target_mode, AbilityDefinition.TargetMode.SLOTS)
	assert_eq(guard.effect_id, "")


func test_control_battle_lists_none_of_the_new_cards() -> void:
	var new_ids: Array[String] = []
	new_ids.append_array(WARRIOR_CARDS)
	new_ids.append_array(HUNTER_CARDS)
	new_ids.append_array(MEDIC_CARDS)
	new_ids.erase("warrior_guard")
	assert_eq(new_ids.size(), 11)
	for fighter: CombatantState in BattleSetup.create_opening_battle().combatants:
		assert_eq(fighter.ability_ids, AbilityCatalog.ids_for(fighter.id), fighter.id)
		for ability_id: String in new_ids:
			assert_false(fighter.ability_ids.has(ability_id), "%s %s" % [fighter.id, ability_id])
			assert_false(AbilityCatalog.ids_for(fighter.id).has(ability_id))


func test_control_heal_keeps_its_fixed_five() -> void:
	var doctor := BattleSetup.create_opening_battle().combatants[2]
	var heal := AbilityCatalog.definition("doctor_heal")
	assert_eq(heal.knowledge_percent, 0)
	assert_eq(rules.heal_for(doctor, heal), 5)
	doctor.knowledge = 10
	assert_eq(rules.heal_for(doctor, heal), 5)


func test_caster_position_limits() -> void:
	for owner_id: String in ["warrior", "hunter", "medic"]:
		var cards: Array[String] = WARRIOR_CARDS
		if owner_id == "hunter":
			cards = HUNTER_CARDS
		elif owner_id == "medic":
			cards = MEDIC_CARDS
		for ability_id: String in cards:
			var card := AbilityCatalog.definition(ability_id)
			for position in range(1, 5):
				var state := _battle()
				var actor := _find(state, owner_id)
				actor.position = position
				var target_id := owner_id
				if card.hits_enemies:
					target_id = "guardian"
					_find(state, "guardian").position = card.target_min
				var destination := 0
				if card.target_mode == AbilityDefinition.TargetMode.OWN_ADJACENT:
					destination = position + 1 if position < 4 else position - 1
				_turn_of(state, owner_id)
				var rejection := rules.validate_ability(_command(owner_id, ability_id, target_id, destination), state)
				var allowed := position >= card.from_min and position <= card.from_max
				var wanted := CombatResult.Rejection.NONE if allowed else CombatResult.Rejection.ACTOR_OUT_OF_POSITION
				assert_eq(rejection, wanted, "%s from %d" % [ability_id, position])


func test_target_position_limits() -> void:
	var owners := {}
	for ability_id: String in WARRIOR_CARDS:
		owners[ability_id] = "warrior"
	for ability_id: String in HUNTER_CARDS:
		owners[ability_id] = "hunter"
	for ability_id: String in MEDIC_CARDS:
		owners[ability_id] = "medic"
	for ability_id: String in owners.keys():
		var card := AbilityCatalog.definition(ability_id)
		if card.target_mode != AbilityDefinition.TargetMode.SLOTS:
			continue
		var owner_id: String = owners[ability_id]
		for position in range(1, 5):
			var state := _battle()
			var actor := _find(state, owner_id)
			actor.position = card.from_max
			var target := _find(state, "guardian" if card.hits_enemies else ("medic" if owner_id != "medic" else "warrior"))
			target.position = position
			_turn_of(state, owner_id)
			var rejection := rules.validate_ability(_command(owner_id, ability_id, target.id), state)
			var allowed := position >= card.target_min and position <= card.target_max
			var wanted := CombatResult.Rejection.NONE if allowed else CombatResult.Rejection.ILLEGAL_TARGET
			assert_eq(rejection, wanted, "%s at %d" % [ability_id, position])


func test_wrong_side_self_only_and_missing_targets_are_rejected_without_writing() -> void:
	var state := _battle()
	var before := _snapshot(state)
	var cases: Array = [
		["warrior", "warrior_sword", "hunter"],
		["medic", "medic_healing", "guardian"],
		["medic", "medic_tincture", "cultist"],
		["medic", "medic_stimulant", "shadowclaw"],
		["warrior", "warrior_battle_stance", "hunter"],
		["hunter", "hunter_maneuver", "warrior"],
		["medic", "medic_healing", "nobody"],
		["hunter", "hunter_bow_shot", "nobody"],
	]
	for row: Array in cases:
		var rng := _rng(3)
		var rng_state := rng.state
		var result := _use(state, row[0], row[1], row[2], rng, 3)
		assert_false(result.accepted, row[1])
		assert_eq(result.rejection, CombatResult.Rejection.ILLEGAL_TARGET, row[1])
		assert_eq(result.state, state)
		assert_eq(result.events.size(), 0)
		assert_eq(rng.state, rng_state)
	state.turn_queue = []
	assert_eq(_snapshot(state), before)


func test_heal_and_effect_on_a_listed_fighter_at_hp_0_reject_without_changes() -> void:
	for ability_id: String in ["medic_healing", "medic_tincture", "medic_stimulant"]:
		var state := _battle()
		_find(state, "hunter").hp = 0
		_turn_of(state, "medic")
		var before := _snapshot(state)
		var rng := _rng(3)
		var rng_state := rng.state
		var result := rules.resolve_ability(_command("medic", ability_id, "hunter"), state, rng)
		assert_false(result.accepted, ability_id)
		assert_eq(result.rejection, CombatResult.Rejection.ILLEGAL_TARGET, ability_id)
		assert_eq(result.state, state)
		assert_eq(result.events.size(), 0, ability_id)
		assert_eq(rng.state, rng_state)
		assert_eq(_snapshot(state), before, ability_id)
	# Self-only stance on a warrior listed at hp 0 is refused the same way.
	var stance_state := _battle()
	_find(stance_state, "warrior").hp = 0
	_turn_of(stance_state, "warrior")
	var stance := rules.resolve_ability(_command("warrior", "warrior_battle_stance", "warrior"), stance_state, _rng(1))
	assert_eq(stance.rejection, CombatResult.Rejection.ILLEGAL_TARGET)
	assert_eq(stance.state, stance_state)
	# Maneuver puts an effect on the actor, so the check answers before the move is played.
	var maneuver_state := _battle()
	_find(maneuver_state, "hunter").hp = 0
	_turn_of(maneuver_state, "hunter")
	var before_maneuver := _snapshot(maneuver_state)
	var maneuver_command := _command("hunter", "hunter_maneuver", "hunter", 3)
	assert_eq(rules.validate_ability(maneuver_command, maneuver_state), CombatResult.Rejection.ILLEGAL_TARGET)
	var maneuver_rng := _rng(1)
	var maneuver_rng_state := maneuver_rng.state
	var maneuver := rules.resolve_ability(maneuver_command, maneuver_state, maneuver_rng)
	assert_eq(maneuver.rejection, CombatResult.Rejection.ILLEGAL_TARGET)
	assert_eq(maneuver.state, maneuver_state)
	assert_eq(maneuver.events.size(), 0)
	assert_eq(maneuver_rng.state, maneuver_rng_state)
	assert_eq(_snapshot(maneuver_state), before_maneuver)


func test_cover_on_a_listed_fighter_at_hp_0_rejects_without_changes() -> void:
	var state := _battle()
	_find(state, "medic").hp = 0
	_turn_of(state, "warrior")
	var before := _snapshot(state)
	var rng := _rng(3)
	var rng_state := rng.state
	var command := _command("warrior", "warrior_guard", "medic")
	assert_eq(rules.validate_ability(command, state), CombatResult.Rejection.ILLEGAL_TARGET)
	var result := rules.resolve_ability(command, state, rng)
	assert_false(result.accepted)
	assert_eq(result.rejection, CombatResult.Rejection.ILLEGAL_TARGET)
	assert_eq(result.state, state)
	assert_eq(result.events.size(), 0)
	assert_eq(rng.state, rng_state)
	assert_eq(_snapshot(state), before)


func test_a_removed_ally_cannot_be_healed_or_raised() -> void:
	var state := _battle()
	state.combatants.erase(_find(state, "hunter"))
	var result := _use(state, "medic", "medic_healing", "hunter")
	assert_eq(result.rejection, CombatResult.Rejection.ILLEGAL_TARGET)
	assert_eq(result.state, state)
	assert_eq(result.events.size(), 0)


func test_every_hit_that_reaches_hp_0_removes_the_fighter() -> void:
	# Ranged strike, push, and the special rite: none leaves a fighter listed at hp 0.
	var struck := _battle()
	_find(struck, "cultist").hp = 1
	var table := rules.strike_outcome(_find(struck, "hunter"), _find(struck, "cultist"), AbilityCatalog.definition("hunter_bow_shot"), 0)
	var seed_value := _seed_where(func(r: RandomNumberGenerator) -> bool: return r.randi_range(1, 100) <= table.hit_chance)
	var shot := _use(struck, "hunter", "hunter_bow_shot", "cultist", _rng(seed_value))
	assert_null(_find(shot.state, "cultist"))
	assert_true(_kinds(shot.events).has(CombatEvent.Kind.REMOVED_FROM_BATTLE))

	var pushed_state := _battle()
	_find(pushed_state, "guardian").hp = 1
	var pushed := _use(pushed_state, "warrior", "warrior_shield_push", "guardian", _rng(_push_hit_seed(pushed_state, "guardian", false)))
	assert_null(_find(pushed.state, "guardian"))

	var prepared := _use(_battle(), "cultist", "cultist_prepared_rite", "medic").state
	_find(prepared, "medic").hp = 14
	var released := _use(prepared, "cultist", "cultist_basic", "warrior")
	assert_null(_find(released.state, "medic"))
	assert_eq(_kinds(released.events).slice(0, 2), [CombatEvent.Kind.DAMAGE_APPLIED, CombatEvent.Kind.REMOVED_FROM_BATTLE])
	for result: CombatResult in [shot, pushed, released]:
		for fighter: CombatantState in result.state.combatants:
			assert_gt(fighter.hp, 0, fighter.id)


func test_a_push_at_zero_damage_before_armor_still_moves_the_target() -> void:
	var state := _battle()
	var warrior := _find(state, "warrior")
	warrior.strength = 0
	var weak := ActiveEffect.new()
	weak.effect_id = "weakened"
	weak.kind = ActiveEffect.Kind.PHYSICAL_DEALT_PERCENT
	weak.magnitude = -60
	weak.turns_left = 2
	warrior.effects.append(weak)
	var table := _push_table(state, "guardian")
	assert_eq(table.listed[0], 0)
	var seed_value := _seed_where(func(r: RandomNumberGenerator) -> bool:
		return r.randi_range(1, 100) <= table.hit_chance and r.randi_range(2, 4) == 2)
	var result := _use(state, "warrior", "warrior_shield_push", "guardian", _rng(seed_value))
	assert_eq(_kinds(result.events), [CombatEvent.Kind.DAMAGE_APPLIED, CombatEvent.Kind.FORMATION_SHIFTED])
	assert_eq(result.events[0].listed_amount, 0)
	assert_eq(result.events[0].amount, 0)
	assert_eq(_find(result.state, "guardian").position, 2)
	assert_eq(_find(result.state, "guardian").hp, 20)


# --- Step B. Physical attacks ---------------------------------------------------


func test_strike_numbers_before_armor_match_the_spec() -> void:
	var state := _battle()
	var warrior := _find(state, "warrior")
	var hunter := _find(state, "hunter")
	var medic := _find(state, "medic")
	assert_eq(_before_armor(warrior, AbilityCatalog.definition("warrior_sword")), [5, 6, 7])
	# Base 3 at STR 5 is exactly 3.5 and rounds up.
	assert_eq(_before_armor(warrior, AbilityCatalog.definition("warrior_shield_push")), [2, 4, 5])
	assert_eq(_before_armor(hunter, AbilityCatalog.definition("hunter_bow_shot")), [4, 5, 6])
	assert_eq(_before_armor(hunter, AbilityCatalog.definition("hunter_dagger")), [6, 7, 8])
	assert_eq(_before_armor(hunter, AbilityCatalog.definition("hunter_aimed_shot")), [4, 5, 6])
	assert_eq(_before_armor(medic, AbilityCatalog.definition("medic_crossbow")), [2, 3, 4])


func test_dagger_scales_from_one_mixed_p() -> void:
	var hunter := _find(_battle(), "hunter")
	var dagger := AbilityCatalog.definition("hunter_dagger")
	# P = 0.6 × 6 + 0.4 × 3 = 4.8, M = 68/59.
	for base in range(5, 8):
		var wanted: int = CombatMath.damage_before_armor(base, 100, 48000, 100, 100)
		assert_eq(rules.damage_before_armor_for(hunter, dagger, base), wanted)
	# Strength takes part: STR 8 gives P = 6.8 and more damage than STR 3.
	hunter.strength = 8
	assert_eq(_before_armor(hunter, dagger), [6, 8, 9])
	# A pure dexterity card would not move with strength.
	assert_eq(_before_armor(hunter, AbilityCatalog.definition("hunter_bow_shot")), [4, 5, 6])


func test_hit_chances_add_dexterity_once_and_aimed_shot_adds_15_points() -> void:
	var state := _battle()
	assert_eq(rules.preview("warrior", "warrior_sword", "guardian", state).hit_chance, 70)
	assert_eq(rules.preview("hunter", "hunter_bow_shot", "shadowclaw", state).hit_chance, 75)
	assert_eq(rules.preview("hunter", "hunter_aimed_shot", "shadowclaw", state).hit_chance, 90)
	assert_eq(rules.preview("hunter", "hunter_bow_shot", "cultist", state).hit_chance, 70)
	assert_eq(rules.preview("hunter", "hunter_aimed_shot", "cultist", state).hit_chance, 85)
	assert_eq(rules.preview("medic", "medic_crossbow", "cultist", state).hit_chance, 50)
	# 90 + 15 − 10 = 95 is the bound; a bigger gap stays at 95.
	_find(state, "guardian").position = 2
	assert_eq(rules.preview("hunter", "hunter_aimed_shot", "guardian", state).hit_chance, 95)
	_find(state, "guardian").dodge = 0
	assert_eq(rules.preview("hunter", "hunter_aimed_shot", "guardian", state).hit_chance, 95)
	# The bonus is points on this attack, not a multiplier and not on the fighter.
	_find(state, "cultist").dodge = 79
	assert_eq(rules.preview("hunter", "hunter_bow_shot", "cultist", state).hit_chance, 10)
	assert_eq(rules.preview("hunter", "hunter_aimed_shot", "cultist", state).hit_chance, 25)
	assert_eq(_find(state, "hunter").accuracy, 84)


func test_aimed_shot_damage_is_the_shot_damage() -> void:
	var state := _battle()
	var shot := rules.preview("hunter", "hunter_bow_shot", "cultist", state)
	var aimed := rules.preview("hunter", "hunter_aimed_shot", "cultist", state)
	assert_eq([aimed.damage_on_hit, aimed.damage_on_hit_max], [shot.damage_on_hit, shot.damage_on_hit_max])


func test_ranged_strikes_roll_hit_base_block_through_the_command() -> void:
	for row: Array in [
		["warrior", "warrior_sword", "guardian", 4, 6],
		["hunter", "hunter_bow_shot", "cultist", 3, 5],
		["hunter", "hunter_dagger", "guardian", 5, 7],
		["hunter", "hunter_aimed_shot", "cultist", 3, 5],
		["medic", "medic_crossbow", "shadowclaw", 2, 4],
		["warrior", "warrior_shield_push", "guardian", 2, 4],
	]:
		var state := _battle()
		var actor := _find(state, row[0])
		var target := _find(state, row[2])
		var card := AbilityCatalog.definition(row[1])
		var table := rules.strike_outcome(actor, target, card, 0)
		var low: int = row[3]
		var high: int = row[4]
		var seed_value := _seed_where(func(r: RandomNumberGenerator) -> bool:
			return r.randi_range(1, 100) <= table.hit_chance and r.randi_range(low, high) == high and r.randi_range(1, 100) > table.block_chance)
		var rng := _rng(seed_value)
		var result := _use(state, row[0], row[1], row[2], rng)
		var replay := _rng(seed_value)
		replay.randi_range(1, 100)
		replay.randi_range(low, high)
		replay.randi_range(1, 100)
		assert_eq(rng.state, replay.state, row[1])
		var damage: CombatEvent = result.events[0]
		assert_eq(damage.kind, CombatEvent.Kind.DAMAGE_APPLIED, row[1])
		assert_eq(damage.listed_amount, table.listed[table.listed.size() - 1], row[1])
		assert_eq(damage.amount, mini(table.on_hit[table.on_hit.size() - 1], target.hp), row[1])

		var miss_seed := _seed_where(func(r: RandomNumberGenerator) -> bool: return r.randi_range(1, 100) > table.hit_chance)
		var miss_rng := _rng(miss_seed)
		var missed := _use(_battle(), row[0], row[1], row[2], miss_rng)
		var miss_replay := _rng(miss_seed)
		miss_replay.randi_range(1, 100)
		assert_eq(miss_rng.state, miss_replay.state, row[1])
		assert_eq(missed.events[0].kind, CombatEvent.Kind.MISSED, row[1])


func test_strike_preview_matches_the_table_and_writes_nothing() -> void:
	var state := _battle()
	var before := _snapshot(state)
	var push := AbilityCatalog.definition("warrior_shield_push")
	var table := rules.strike_outcome(_find(state, "warrior"), _find(state, "guardian"), push, 0)
	var shown := rules.preview("warrior", "warrior_shield_push", "guardian", state)
	assert_eq(shown.hit_chance, table.hit_chance)
	assert_eq(shown.block_chance, 50)
	# 2/4/5 through armor 4: 2, 3, 4. Block halves to 1, 1, 2.
	assert_eq(table.listed, [2, 3, 4])
	assert_eq([shown.damage_on_hit, shown.damage_on_hit_max], [2, 4])
	assert_eq([shown.damage_if_blocked, shown.damage_if_blocked_max], [1, 2])
	for ability_id: String in ["warrior_battle_stance", "hunter_maneuver", "medic_healing", "medic_tincture"]:
		var blank := rules.preview("medic", ability_id, "medic", state)
		assert_eq([blank.hit_chance, blank.damage_on_hit, blank.damage_on_hit_max], [0, 0, 0], ability_id)
	assert_eq(_snapshot(state), before)


# --- Step C. Support -------------------------------------------------------------


func test_healing_restores_five_at_knowledge_six_and_stops_at_max() -> void:
	var state := _battle()
	var medic := _find(state, "medic")
	assert_eq(rules.heal_for(medic, AbilityCatalog.definition("medic_healing")), 5)
	medic.knowledge = 3
	assert_eq(rules.heal_for(medic, AbilityCatalog.definition("medic_healing")), 4)
	medic.knowledge = 6

	_find(state, "warrior").hp = 10
	var rng := _rng(7)
	var rng_state := rng.state
	var result := _use(state, "medic", "medic_healing", "warrior", rng)
	assert_eq(rng.state, rng_state)
	assert_eq(_kinds(result.events), [CombatEvent.Kind.HEALED])
	assert_eq(result.events[0].amount, 5)
	assert_eq(result.events[0].resulting_hp, 15)
	assert_eq(_find(result.state, "medic").cooldown_left["medic_healing"], 2)
	assert_eq(result.state.turn_queue[0], "warrior")
	assert_eq(_find(state, "warrior").hp, 10)

	var short := _battle()
	_find(short, "warrior").hp = 20
	var capped := _use(short, "medic", "medic_healing", "warrior")
	assert_eq(capped.events[0].amount, 2)
	assert_eq(capped.events[0].resulting_hp, 22)


func test_healing_a_full_ally_or_self_spends_the_action_and_cooldown() -> void:
	for target_id: String in ["warrior", "medic"]:
		var state := _battle()
		var result := _use(state, "medic", "medic_healing", target_id)
		assert_true(result.accepted)
		assert_eq(_kinds(result.events), [CombatEvent.Kind.HEALED])
		assert_eq(result.events[0].amount, 0)
		assert_eq(_find(result.state, target_id).hp, _find(result.state, target_id).max_hp)
		assert_eq(_find(result.state, "medic").cooldown_left["medic_healing"], 2)
		assert_false(result.state.turn_queue.has("medic"))


func test_cover_from_the_new_warrior_absorbs_a_hit_and_ignores_special_damage() -> void:
	var state := _battle()
	var covered := _use(state, "warrior", "warrior_guard", "medic")
	assert_eq(_kinds(covered.events), [CombatEvent.Kind.GUARD_PLACED])
	assert_eq(_find(covered.state, "medic").guard_reduction, 10)
	assert_eq(_find(covered.state, "warrior").cooldown_left["warrior_guard"], 1)

	# Special damage neither stops at the cover nor spends it.
	var prepared := _use(covered.state, "cultist", "cultist_prepared_rite", "medic")
	var rite := _use(prepared.state, "cultist", "cultist_basic", "warrior")
	assert_eq(rite.events[0].amount, 14)
	assert_eq(_find(rite.state, "medic").guard_reduction, 10)

	var claws := AbilityCatalog.definition("shadowclaw_claws")
	var table := rules.strike_outcome(_find(rite.state, "shadowclaw"), _find(rite.state, "medic"), claws, 10)
	var seed_value := _seed_where(func(r: RandomNumberGenerator) -> bool: return r.randi_range(1, 100) <= table.hit_chance)
	var hit := _use(rite.state, "shadowclaw", "shadowclaw_claws", "medic", _rng(seed_value))
	assert_eq(hit.events[0].amount, 0)
	assert_eq(hit.events[0].mitigation, CombatEvent.Mitigation.GUARD)
	assert_eq(_find(hit.state, "medic").guard_reduction, 0)


func test_battle_stance_adds_50_block_points_up_to_95_for_two_own_turns() -> void:
	var state := _battle()
	assert_eq(rules.preview("guardian", "guardian_basic", "warrior", state).block_chance, 25)
	var rng := _rng(4)
	var rng_state := rng.state
	var stance := _use(state, "warrior", "warrior_battle_stance", "warrior", rng)
	assert_eq(rng.state, rng_state)
	assert_eq(_kinds(stance.events), [CombatEvent.Kind.EFFECT_APPLIED])
	assert_eq(stance.events[0].actor_id, "warrior")
	assert_eq(stance.events[0].other_id, "warrior")
	assert_eq(stance.events[0].effect_id, "battle_stance")
	assert_eq(stance.events[0].amount, 50)
	var after := stance.state
	assert_eq(_find(after, "warrior").cooldown_left["warrior_battle_stance"], 3)
	assert_eq(_effect(_find(after, "warrior"), "battle_stance").turns_left, 2)
	assert_eq(rules.preview("guardian", "guardian_basic", "warrior", after).block_chance, 75)
	assert_eq(_find(after, "warrior").block, 25)

	after = _step(after, "warrior", 2)
	assert_eq(_effect(_find(after, "warrior"), "battle_stance").turns_left, 1)
	assert_eq(rules.preview("guardian", "guardian_basic", "warrior", after).block_chance, 75)
	_turn_of(after, "warrior")
	var expiring := rules.resolve(_step_command("warrior", 1), after, _rng(1))
	assert_true(_kinds(expiring.events).has(CombatEvent.Kind.EFFECT_EXPIRED))
	assert_null(_effect(_find(expiring.state, "warrior"), "battle_stance"))
	assert_eq(rules.preview("guardian", "guardian_basic", "warrior", expiring.state).block_chance, 25)

	var high := _battle()
	_find(high, "warrior").block = 50
	var capped := _use(high, "warrior", "warrior_battle_stance", "warrior")
	assert_eq(rules.preview("guardian", "guardian_basic", "warrior", capped.state).block_chance, 95)


func test_cooldowns_one_two_three_count_only_own_turns() -> void:
	# Card, the own turn it is ready again: cooldown 1 on turn 2, 2 on turn 3, 3 on turn 4.
	for row: Array in [["warrior_guard", 1], ["warrior_shield_push", 2], ["warrior_battle_stance", 3]]:
		var state := _battle()
		var target_id := "warrior"
		if row[0] == "warrior_shield_push":
			target_id = "guardian"
			_find(state, "warrior").accuracy = 0
		var used := _use(state, "warrior", row[0], target_id)
		assert_true(used.accepted, row[0])
		var current := used.state
		for own_turn in range(1, row[1] + 1):
			_turn_of(current, "warrior")
			assert_eq(rules.validate_ability(_command("warrior", row[0], target_id), current), CombatResult.Rejection.ON_COOLDOWN, "%s turn %d" % [row[0], own_turn])
			current = _step(current, "warrior", 2 if _find(current, "warrior").position == 1 else 1)
		_turn_of(current, "warrior")
		assert_eq(rules.validate_ability(_command("warrior", row[0], target_id), current), CombatResult.Rejection.NONE, row[0])


func test_hunter_and_medic_cooldowns_count_only_own_turns() -> void:
	# Owner, card, target, cooldown, the two slots the owner steps between.
	for row: Array in [
		["hunter", "hunter_aimed_shot", "cultist", 2, [2, 3]],
		["hunter", "hunter_maneuver", "hunter", 3, [2, 3]],
		["medic", "medic_healing", "warrior", 2, [3, 4]],
		["medic", "medic_tincture", "warrior", 3, [3, 4]],
		["medic", "medic_stimulant", "warrior", 3, [3, 4]],
	]:
		var owner_id: String = row[0]
		var slots: Array = row[4]
		var state := _battle()
		_find(state, "hunter").accuracy = 0
		var used := _use(state, owner_id, row[1], row[2], _rng(1), 3)
		assert_true(used.accepted, row[1])
		var current := used.state
		for own_turn in range(1, row[3] + 2):
			var position := _find(current, owner_id).position
			var destination: int = slots[1] if position == slots[0] else slots[0]
			_turn_of(current, owner_id)
			var wanted := CombatResult.Rejection.ON_COOLDOWN if own_turn <= row[3] else CombatResult.Rejection.NONE
			assert_eq(rules.validate_ability(_command(owner_id, row[1], row[2], destination), current), wanted, "%s turn %d" % [row[1], own_turn])
			current = _step(current, owner_id, destination)


func test_tincture_on_self_does_not_count_the_current_turn() -> void:
	var after := _use(_battle(), "medic", "medic_tincture", "medic").state
	var effect := _effect(_find(after, "medic"), "resilience_tincture")
	assert_eq([effect.turns_left, effect.skips_next_tick], [2, false])
	after = _step(after, "medic", 4)
	assert_eq(_effect(_find(after, "medic"), "resilience_tincture").turns_left, 1)
	after = _step(after, "medic", 3)
	assert_null(_effect(_find(after, "medic"), "resilience_tincture"))


func test_an_effect_id_held_under_another_kind_rejects_the_card_atomically() -> void:
	for row: Array in [
		["medic", "medic_stimulant", "hunter", "combat_stimulant", 0],
		["hunter", "hunter_maneuver", "hunter", "maneuver_dodge", 3],
	]:
		var state := _battle()
		var odd := ActiveEffect.new()
		odd.effect_id = row[3]
		odd.kind = ActiveEffect.Kind.BLOCK_POINTS
		odd.magnitude = 5
		odd.turns_left = 1
		_find(state, "hunter").effects.append(odd)
		_turn_of(state, row[0])
		var before := _snapshot(state)
		var rng := _rng(2)
		var rng_state := rng.state
		var result := rules.resolve_ability(_command(row[0], row[1], row[2], row[4]), state, rng)
		assert_eq(result.rejection, CombatResult.Rejection.INVALID_EFFECT, row[1])
		assert_eq(result.state, state)
		assert_eq(result.events.size(), 0)
		assert_eq(rng.state, rng_state)
		assert_eq(_snapshot(state), before, row[1])


func test_a_heal_formula_that_fails_rejects_before_any_change() -> void:
	var state := _battle()
	_find(state, "medic").knowledge = -1
	_find(state, "warrior").hp = 10
	_turn_of(state, "medic")
	var before := _snapshot(state)
	var rng := _rng(2)
	var rng_state := rng.state
	var result := rules.resolve_ability(_command("medic", "medic_healing", "warrior"), state, rng)
	assert_eq(result.rejection, CombatResult.Rejection.CALCULATION_FAILED)
	assert_eq(result.state, state)
	assert_eq(result.events.size(), 0)
	assert_eq(rng.state, rng_state)
	assert_eq(_snapshot(state), before)
	assert_push_error_count(1)


func test_enemy_threat_reads_the_medic_heal_from_the_rules() -> void:
	var state := _battle()
	var utility: EnemyUtility = EnemyUtility.new(rules)
	var medic := _find(state, "medic")
	# Crossbow lists at most 4 before armor, so the heal of 5 is the threat.
	assert_eq(utility._threat(state, medic), 5)
	medic.knowledge = 10
	assert_eq(utility._threat(state, medic), 6)


func test_stimulant_adds_30_percent_to_physical_damage_only() -> void:
	var state := _battle()
	var stimulated := _use(state, "medic", "medic_stimulant", "hunter")
	assert_eq(_kinds(stimulated.events), [CombatEvent.Kind.EFFECT_APPLIED])
	var after := stimulated.state
	var effect := _effect(_find(after, "hunter"), "combat_stimulant")
	assert_eq([effect.kind, effect.magnitude, effect.turns_left, effect.skips_next_tick], [ActiveEffect.Kind.PHYSICAL_DEALT_PERCENT, 30, 2, false])
	assert_eq(_find(after, "medic").cooldown_left["medic_stimulant"], 3)
	# 3/4/5 × 16/13 × 1.3 = 4.8, 6.4, 8.
	assert_eq(_before_armor(_find(after, "hunter"), AbilityCatalog.definition("hunter_bow_shot")), [5, 6, 8])
	assert_eq(_before_armor(_find(state, "hunter"), AbilityCatalog.definition("hunter_bow_shot")), [4, 5, 6])

	# Not on special damage and not on healing, even on the medic itself.
	var self_state := _battle()
	_find(self_state, "cultist").ability_ids.append("medic_stimulant")
	_find(self_state, "cultist").position = 2
	var cultist_buffed := _use(self_state, "cultist", "medic_stimulant", "cultist")
	var rite := AbilityCatalog.definition("cultist_prepared_rite")
	var table := rules.strike_outcome(_find(cultist_buffed.state, "cultist"), _find(cultist_buffed.state, "medic"), rite, 0)
	assert_eq(table.on_hit, [14])
	var medic_buffed := _use(_battle(), "medic", "medic_stimulant", "medic")
	assert_true(_effect(_find(medic_buffed.state, "medic"), "combat_stimulant").turns_left == 2)
	assert_eq(rules.heal_for(_find(medic_buffed.state, "medic"), AbilityCatalog.definition("medic_healing")), 5)


func test_stimulant_on_another_ally_lasts_two_of_their_own_turns() -> void:
	var after := _use(_battle(), "medic", "medic_stimulant", "hunter").state
	after = _step(after, "hunter", 3)
	assert_eq(_effect(_find(after, "hunter"), "combat_stimulant").turns_left, 1)
	_turn_of(after, "hunter")
	var second := rules.resolve(_step_command("hunter", 2), after, _rng(1))
	assert_true(_kinds(second.events).has(CombatEvent.Kind.EFFECT_EXPIRED))
	assert_null(_effect(_find(second.state, "hunter"), "combat_stimulant"))


func test_stimulant_on_self_does_not_count_the_current_turn() -> void:
	var after := _use(_battle(), "medic", "medic_stimulant", "medic").state
	var effect := _effect(_find(after, "medic"), "combat_stimulant")
	assert_eq([effect.turns_left, effect.skips_next_tick], [2, false])
	after = _step(after, "medic", 4)
	assert_eq(_effect(_find(after, "medic"), "combat_stimulant").turns_left, 1)
	after = _step(after, "medic", 3)
	assert_null(_effect(_find(after, "medic"), "combat_stimulant"))


func test_repeat_refreshes_without_stacking_strength() -> void:
	var state := _battle()
	var second_medic := _fighter("medic-2", CombatantState.Side.HEROES, 4, 2, 20, 68, 4, 0, [2, 2, 4, 6, 3], MEDIC_CARDS)
	state.combatants.append(second_medic)
	var first := _use(state, "medic", "medic_stimulant", "hunter").state
	first = _step(first, "hunter", 3)
	assert_eq(_effect(_find(first, "hunter"), "combat_stimulant").turns_left, 1)
	var again := _use(first, "medic-2", "medic_stimulant", "hunter")
	var hunter := _find(again.state, "hunter")
	assert_eq(hunter.effects.size(), 1)
	assert_eq(_effect(hunter, "combat_stimulant").magnitude, 30)
	assert_eq(_effect(hunter, "combat_stimulant").turns_left, 2)
	assert_eq(_before_armor(hunter, AbilityCatalog.definition("hunter_bow_shot")), [5, 6, 8])

	var tinctured := _use(state, "medic", "medic_tincture", "warrior").state
	var twice := _use(tinctured, "medic-2", "medic_tincture", "warrior").state
	assert_eq(_find(twice, "warrior").effects.size(), 1)
	assert_eq(rules.special_received_multiplier_percent(_find(twice, "warrior")), 60)


func test_tincture_cuts_the_rite_from_14_to_8_and_leaves_physical_damage() -> void:
	var state := _battle()
	var rite := AbilityCatalog.definition("cultist_prepared_rite")
	var claws := AbilityCatalog.definition("shadowclaw_claws")
	var plain_claws := rules.strike_outcome(_find(state, "shadowclaw"), _find(state, "medic"), claws, 0)
	var protected := _use(state, "medic", "medic_tincture", "medic").state
	var medic := _find(protected, "medic")
	assert_eq(_effect(medic, "resilience_tincture").magnitude, -40)
	assert_eq(medic.cooldown_left["medic_tincture"], 3)
	assert_eq(rules.strike_outcome(_find(state, "cultist"), _find(state, "medic"), rite, 0).on_hit, [14])
	assert_eq(rules.strike_outcome(_find(protected, "cultist"), medic, rite, 0).on_hit, [8])
	var tinctured_claws := rules.strike_outcome(_find(protected, "shadowclaw"), medic, claws, 0)
	assert_eq(tinctured_claws.on_hit, plain_claws.on_hit)
	assert_eq(tinctured_claws.listed, plain_claws.listed)


func test_tincture_after_preparation_reduces_the_released_rite_without_rolls() -> void:
	var prepared := _use(_battle(), "cultist", "cultist_prepared_rite", "medic")
	assert_eq(_kinds(prepared.events), [CombatEvent.Kind.PREPARED_STRIKE])
	var protected := _use(prepared.state, "medic", "medic_tincture", "medic")
	assert_eq(_kinds(protected.events), [CombatEvent.Kind.EFFECT_APPLIED])
	assert_not_null(protected.state.prepared)
	var rng := _rng(11)
	var rng_state := rng.state
	var released := _use(protected.state, "cultist", "cultist_basic", "warrior", rng)
	assert_eq(rng.state, rng_state)
	assert_eq(released.events[0].kind, CombatEvent.Kind.DAMAGE_APPLIED)
	assert_eq(released.events[0].amount, 8)
	assert_eq(_find(released.state, "medic").hp, 12)
	assert_null(released.state.prepared)


func test_support_actions_never_roll() -> void:
	var cases: Array = [
		["warrior", "warrior_guard", "hunter", 0],
		["warrior", "warrior_battle_stance", "warrior", 0],
		["hunter", "hunter_maneuver", "hunter", 3],
		["medic", "medic_healing", "warrior", 0],
		["medic", "medic_tincture", "warrior", 0],
		["medic", "medic_stimulant", "warrior", 0],
	]
	for row: Array in cases:
		var rng := _rng(21)
		var rng_state := rng.state
		var result := _use(_battle(), row[0], row[1], row[2], rng, row[3])
		assert_true(result.accepted, row[1])
		assert_eq(rng.state, rng_state, row[1])
		assert_eq(_find(result.state, row[0]).cooldown_left.get(row[1], 0), AbilityCatalog.definition(row[1]).cooldown_turns, row[1])
		assert_false(result.state.turn_queue.has(row[0]), row[1])


# --- Step D. Push and Maneuver ---------------------------------------------------


func test_push_moves_the_target_into_an_empty_slot() -> void:
	var state := _battle()
	_find(state, "shadowclaw").position = 4
	_find(state, "cultist").position = 3
	var result := _use(state, "warrior", "warrior_shield_push", "guardian", _rng(_push_hit_seed(state, "guardian", false)))
	assert_eq(_kinds(result.events), [CombatEvent.Kind.DAMAGE_APPLIED, CombatEvent.Kind.FORMATION_SHIFTED])
	var shifted: CombatEvent = result.events[1]
	assert_eq(shifted.side, CombatantState.Side.ENEMIES)
	assert_eq(shifted.shifts.size(), 1)
	assert_eq([shifted.shifts[0].combatant_id, shifted.shifts[0].from_position, shifted.shifts[0].to_position], ["guardian", 1, 2])
	assert_eq(_find(result.state, "guardian").position, 2)
	assert_null(_at(result.state, CombatantState.Side.ENEMIES, 1))
	assert_eq(_find(result.state, "warrior").cooldown_left["warrior_shield_push"], 2)
	_assert_formation(result.state)


func test_push_swaps_with_the_occupant_from_1_and_from_2() -> void:
	var state := _battle()
	var from_front := _use(state, "warrior", "warrior_shield_push", "guardian", _rng(_push_hit_seed(state, "guardian", false)))
	var shifted: CombatEvent = from_front.events[1]
	assert_eq(shifted.kind, CombatEvent.Kind.FORMATION_SHIFTED)
	assert_eq(shifted.shifts.size(), 2)
	assert_eq([shifted.shifts[0].combatant_id, shifted.shifts[0].from_position, shifted.shifts[0].to_position], ["guardian", 1, 2])
	assert_eq([shifted.shifts[1].combatant_id, shifted.shifts[1].from_position, shifted.shifts[1].to_position], ["shadowclaw", 2, 1])
	assert_eq(_find(from_front.state, "guardian").position, 2)
	assert_eq(_find(from_front.state, "shadowclaw").position, 1)
	_assert_formation(from_front.state)

	var second := _battle()
	var from_second := _use(second, "warrior", "warrior_shield_push", "shadowclaw", _rng(_push_hit_seed(second, "shadowclaw", false)))
	assert_eq(_find(from_second.state, "shadowclaw").position, 3)
	assert_eq(_find(from_second.state, "cultist").position, 2)
	assert_eq(_find(from_second.state, "guardian").position, 1)
	_assert_formation(from_second.state)


func test_push_does_not_reach_slots_3_and_4() -> void:
	var state := _battle()
	_turn_of(state, "warrior")
	assert_eq(rules.validate_ability(_command("warrior", "warrior_shield_push", "cultist"), state), CombatResult.Rejection.ILLEGAL_TARGET)
	_find(state, "cultist").position = 4
	assert_eq(rules.validate_ability(_command("warrior", "warrior_shield_push", "cultist"), state), CombatResult.Rejection.ILLEGAL_TARGET)
	# Empty slots ahead do not extend the reach.
	var lone := _battle()
	lone.combatants.erase(_find(lone, "guardian"))
	lone.combatants.erase(_find(lone, "shadowclaw"))
	_turn_of(lone, "warrior")
	assert_eq(rules.validate_ability(_command("warrior", "warrior_shield_push", "cultist"), lone), CombatResult.Rejection.ILLEGAL_TARGET)
	assert_eq(rules.validate_ability(_command("warrior", "warrior_sword", "cultist"), lone), CombatResult.Rejection.ILLEGAL_TARGET)


func test_a_missed_push_neither_damages_nor_moves() -> void:
	var state := _battle()
	var table := _push_table(state, "guardian")
	var seed_value := _seed_where(func(r: RandomNumberGenerator) -> bool: return r.randi_range(1, 100) > table.hit_chance)
	var rng := _rng(seed_value)
	var result := _use(state, "warrior", "warrior_shield_push", "guardian", rng)
	var replay := _rng(seed_value)
	replay.randi_range(1, 100)
	assert_eq(rng.state, replay.state)
	assert_eq(_kinds(result.events), [CombatEvent.Kind.MISSED])
	assert_eq(_find(result.state, "guardian").position, 1)
	assert_eq(_find(result.state, "shadowclaw").position, 2)
	assert_eq(_find(result.state, "warrior").cooldown_left["warrior_shield_push"], 2)


func test_a_lethal_push_leaves_the_slot_empty_and_moves_nobody() -> void:
	var state := _battle()
	_find(state, "guardian").hp = 1
	var result := _use(state, "warrior", "warrior_shield_push", "guardian", _rng(_push_hit_seed(state, "guardian", false)))
	assert_eq(_kinds(result.events), [CombatEvent.Kind.DAMAGE_APPLIED, CombatEvent.Kind.REMOVED_FROM_BATTLE])
	assert_null(_find(result.state, "guardian"))
	assert_eq(_find(result.state, "shadowclaw").position, 2)
	assert_null(_at(result.state, CombatantState.Side.ENEMIES, 1))


func test_a_blocked_or_fully_absorbed_push_still_moves_the_target() -> void:
	var state := _battle()
	var blocked := _use(state, "warrior", "warrior_shield_push", "guardian", _rng(_push_hit_seed(state, "guardian", true)))
	assert_eq(blocked.events[0].mitigation, CombatEvent.Mitigation.BLOCK)
	assert_eq(blocked.events[1].kind, CombatEvent.Kind.FORMATION_SHIFTED)
	assert_eq(_find(blocked.state, "guardian").position, 2)

	var covered := _battle()
	_find(covered, "guardian").guard_reduction = 10
	var absorbed := _use(covered, "warrior", "warrior_shield_push", "guardian", _rng(_push_hit_seed(covered, "guardian", false)))
	assert_eq(absorbed.events[0].amount, 0)
	assert_eq(absorbed.events[0].mitigation, CombatEvent.Mitigation.GUARD)
	assert_eq(_find(absorbed.state, "guardian").hp, 20)
	assert_eq(_find(absorbed.state, "guardian").guard_reduction, 0)
	assert_eq(_find(absorbed.state, "guardian").position, 2)
	assert_eq(_find(absorbed.state, "shadowclaw").position, 1)


func test_push_keeps_the_occupants_cover_and_the_prepared_rite() -> void:
	var state := _battle()
	_find(state, "cultist").position = 2
	_find(state, "shadowclaw").position = 3
	_find(state, "shadowclaw").guard_reduction = 10
	var prepared := _use(state, "cultist", "cultist_prepared_rite", "medic").state
	assert_not_null(prepared.prepared)
	var pushed := _use(prepared, "warrior", "warrior_shield_push", "cultist", _rng(_push_hit_seed(prepared, "cultist", false)))
	assert_true(_kinds(pushed.events).has(CombatEvent.Kind.FORMATION_SHIFTED))
	assert_eq(_find(pushed.state, "cultist").position, 3)
	assert_eq(_find(pushed.state, "shadowclaw").position, 2)
	assert_eq(_find(pushed.state, "shadowclaw").guard_reduction, 10)
	assert_eq([pushed.state.prepared.actor_id, pushed.state.prepared.target_id], ["cultist", "medic"])
	var released := _use(pushed.state, "cultist", "cultist_basic", "warrior")
	assert_eq(released.events[0].other_id, "medic")
	assert_eq(released.events[0].amount, 14)


func test_maneuver_into_an_empty_slot_grants_dodge_after_the_move() -> void:
	var state := _battle()
	_find(state, "medic").position = 4
	var before := _snapshot(state)
	var shadowclaw_hit := rules.preview("shadowclaw", "shadowclaw_claws", "hunter", state).hit_chance
	assert_eq(shadowclaw_hit, 70)
	var result := _use(state, "hunter", "hunter_maneuver", "hunter", _rng(1), 3)
	assert_eq(_kinds(result.events), [CombatEvent.Kind.STEPPED, CombatEvent.Kind.EFFECT_APPLIED])
	assert_eq([result.events[0].actor_id, result.events[0].from_position, result.events[0].to_position], ["hunter", 2, 3])
	assert_eq(result.events[1].effect_id, "maneuver_dodge")
	assert_eq(result.events[1].amount, 20)
	var hunter := _find(result.state, "hunter")
	assert_eq(hunter.position, 3)
	assert_eq(hunter.dodge, 12)
	assert_eq(hunter.cooldown_left["hunter_maneuver"], 3)
	assert_eq(rules.preview("shadowclaw", "shadowclaw_claws", "hunter", result.state).hit_chance, 50)
	state.turn_queue = []
	assert_eq(_snapshot(state), before)
	_assert_formation(result.state)


func test_maneuver_swaps_with_an_ally() -> void:
	var result := _use(_battle(), "hunter", "hunter_maneuver", "hunter", _rng(1), 1)
	assert_eq(_kinds(result.events), [CombatEvent.Kind.SWAPPED, CombatEvent.Kind.EFFECT_APPLIED])
	assert_eq([result.events[0].actor_id, result.events[0].other_id], ["hunter", "warrior"])
	assert_eq(_find(result.state, "hunter").position, 1)
	assert_eq(_find(result.state, "warrior").position, 2)
	assert_not_null(_effect(_find(result.state, "hunter"), "maneuver_dodge"))
	assert_eq(_find(result.state, "warrior").effects.size(), 0)
	_assert_formation(result.state)


func test_an_impossible_maneuver_changes_nothing() -> void:
	# start, destination, reason
	var cases: Array = [
		[1, 0, CombatResult.Rejection.POSITION_OUT_OF_RANGE],
		[4, 5, CombatResult.Rejection.POSITION_OUT_OF_RANGE],
		[2, 4, CombatResult.Rejection.NOT_ADJACENT],
		[2, 2, CombatResult.Rejection.NOT_ADJACENT],
	]
	for row: Array in cases:
		var state := _battle()
		_place_hunter(state, row[0])
		_turn_of(state, "hunter")
		var before := _snapshot(state)
		var rng := _rng(5)
		var rng_state := rng.state
		var result := rules.resolve_ability(_command("hunter", "hunter_maneuver", "hunter", row[1]), state, rng)
		assert_false(result.accepted, "%d to %d" % [row[0], row[1]])
		assert_eq(result.rejection, row[2], "%d to %d" % [row[0], row[1]])
		assert_eq(result.state, state)
		assert_eq(result.events.size(), 0)
		assert_eq(rng.state, rng_state)
		assert_eq(_snapshot(state), before)
	# Edges are fine one slot inward.
	for row: Array in [[1, 2], [4, 3]]:
		var edge := _battle()
		_place_hunter(edge, row[0])
		var moved := _use(edge, "hunter", "hunter_maneuver", "hunter", _rng(1), row[1])
		assert_true(moved.accepted)
		assert_eq(_find(moved.state, "hunter").position, row[1])


func test_maneuver_dodge_lasts_exactly_two_own_turns_and_step_stays() -> void:
	var state := _battle()
	_find(state, "medic").position = 4
	var after := _use(state, "hunter", "hunter_maneuver", "hunter", _rng(1), 3).state
	var effect := _effect(_find(after, "hunter"), "maneuver_dodge")
	assert_eq([effect.turns_left, effect.skips_next_tick], [2, false])
	# The plain step is still a separate action, also during the cooldown.
	after = _step(after, "hunter", 2)
	assert_eq(_effect(_find(after, "hunter"), "maneuver_dodge").turns_left, 1)
	assert_eq(rules.preview("shadowclaw", "shadowclaw_claws", "hunter", after).hit_chance, 50)
	_turn_of(after, "hunter")
	var last := rules.resolve(_step_command("hunter", 3), after, _rng(1))
	assert_true(_kinds(last.events).has(CombatEvent.Kind.EFFECT_EXPIRED))
	assert_null(_effect(_find(last.state, "hunter"), "maneuver_dodge"))
	assert_eq(rules.preview("shadowclaw", "shadowclaw_claws", "hunter", last.state).hit_chance, 70)
	_turn_of(last.state, "hunter")
	assert_eq(rules.validate_ability(_command("hunter", "hunter_maneuver", "hunter", 2), last.state), CombatResult.Rejection.ON_COOLDOWN)


# --- Step E. Integration -----------------------------------------------------------


func test_combined_stance_cover_and_stimulant_push() -> void:
	# Stance and cover on the same warrior: 75% block, then cover takes the rest.
	var state := _battle()
	var guarded := _use(state, "warrior", "warrior_battle_stance", "warrior").state
	_find(guarded, "warrior").guard_reduction = 10
	var table := rules.strike_outcome(_find(guarded, "guardian"), _find(guarded, "warrior"), AbilityCatalog.definition("guardian_basic"), 10)
	assert_eq(table.block_chance, 75)
	assert_eq(table.on_hit, [0])

	# A stimulated push: 2/4/5 × 1.3 before armor.
	var buffed := _use(_battle(), "medic", "medic_stimulant", "warrior").state
	assert_eq(_before_armor(_find(buffed, "warrior"), AbilityCatalog.definition("warrior_shield_push")), [3, 5, 6])
	var pushed := _use(buffed, "warrior", "warrior_shield_push", "guardian", _rng(_push_hit_seed(buffed, "guardian", false)))
	assert_eq(_find(pushed.state, "guardian").position, 2)
	assert_eq(_effect(_find(pushed.state, "warrior"), "combat_stimulant").turns_left, 1)


func test_new_states_are_copies_and_the_source_is_untouched() -> void:
	var state := _battle()
	var before := _snapshot(state)
	var stance := _use(state, "warrior", "warrior_battle_stance", "warrior")
	var pushed := _use(state, "warrior", "warrior_shield_push", "guardian", _rng(_push_hit_seed(state, "guardian", false)))
	var moved := _use(state, "hunter", "hunter_maneuver", "hunter", _rng(1), 1)
	for result: CombatResult in [stance, pushed, moved]:
		assert_ne(result.state, state)
	state.turn_queue = []
	assert_eq(_snapshot(state), before)
	var copy := rules.discard_prepared(stance.state)
	var original_effect := _effect(_find(stance.state, "warrior"), "battle_stance")
	var copied_effect := _effect(_find(copy, "warrior"), "battle_stance")
	assert_ne(original_effect, copied_effect)
	copied_effect.magnitude = 1
	assert_eq(original_effect.magnitude, 50)


func test_enemy_choice_with_hero_cards_and_effects_is_legal_and_writes_nothing() -> void:
	var state := _battle()
	state = _use(state, "medic", "medic_stimulant", "hunter").state
	state = _use(state, "medic", "medic_tincture", "medic").state
	state = _use(state, "warrior", "warrior_battle_stance", "warrior").state
	for enemy_id: String in ["guardian", "shadowclaw", "cultist"]:
		_turn_of(state, enemy_id)
		var before := _snapshot(state)
		var ai := EnemyAi.new(rules)
		var action: Variant = ai.choose_action(state)
		assert_not_null(action, enemy_id)
		if action is AbilityCommand:
			assert_eq(rules.validate_ability(action, state), CombatResult.Rejection.NONE, enemy_id)
		else:
			assert_eq(rules.validate(action, state), CombatResult.Rejection.NONE, enemy_id)
		assert_eq(_snapshot(state), before, enemy_id)


func test_enemy_turn_rolls_the_same_as_the_rules() -> void:
	var state := _battle()
	_turn_of(state, "shadowclaw")
	var ai_rng := _rng(9)
	var rules_rng := _rng(9)
	var by_ai := EnemyAi.new(rules).take_turn(state, ai_rng)
	var action: Variant = EnemyAi.new(rules).choose_action(state)
	var by_rules := rules.resolve_ability(action, state, rules_rng)
	assert_true(by_ai.accepted)
	assert_eq(ai_rng.state, rules_rng.state)
	assert_eq(_snapshot(by_ai.state), _snapshot(by_rules.state))


# --- Local helpers -----------------------------------------------------------------


func _step_command(actor_id: String, destination: int) -> StepCommand:
	var command := StepCommand.new()
	command.actor_id = actor_id
	command.destination_position = destination
	return command


func _push_table(state: CombatState, target_id: String) -> CombatRules.StrikeOutcome:
	var target := _find(state, target_id)
	return rules.strike_outcome(_find(state, "warrior"), target, AbilityCatalog.definition("warrior_shield_push"), target.guard_reduction)


## Hunter at slot 1 or 4 trades places with whoever stood there, so no slot holds two heroes.
func _place_hunter(state: CombatState, position: int) -> void:
	var hunter := _find(state, "hunter")
	var occupant := _at(state, CombatantState.Side.HEROES, position)
	if occupant != null and occupant != hunter:
		occupant.position = hunter.position
	hunter.position = position


## Seed for a landed push, blocked or not.
func _push_hit_seed(state: CombatState, target_id: String, blocked: bool) -> int:
	var table := _push_table(state, target_id)
	return _seed_where(func(r: RandomNumberGenerator) -> bool:
		if r.randi_range(1, 100) > table.hit_chance:
			return false
		r.randi_range(2, 4)
		return (r.randi_range(1, 100) <= table.block_chance) == blocked)


func _at(state: CombatState, side: CombatantState.Side, position: int) -> CombatantState:
	for fighter: CombatantState in state.combatants:
		if fighter.side == side and fighter.position == position:
			return fighter
	return null


## Every fighter once, in slots 1–4, never two in one slot of a side.
func _assert_formation(state: CombatState) -> void:
	var seen := {}
	var ids := {}
	for fighter: CombatantState in state.combatants:
		assert_false(ids.has(fighter.id), "duplicate %s" % fighter.id)
		ids[fighter.id] = true
		assert_between(fighter.position, CombatantState.FRONT_POSITION, CombatantState.REAR_POSITION, fighter.id)
		var key := "%d:%d" % [fighter.side, fighter.position]
		assert_false(seen.has(key), "two fighters at %s" % key)
		seen[key] = true
