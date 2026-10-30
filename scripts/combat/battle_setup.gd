class_name BattleSetup
extends RefCounted

## Opening roster from docs/COMBAT_SPEC.md. Prototype numbers, not campaign balance.


static func create_opening_battle() -> CombatState:
	var fighters: Array[CombatantState] = []
	fighters.append(_combatant("hero-1", "Воїн", CombatantState.Side.HEROES, 1, 5, 20, 80, 10, 25))
	fighters.append(_combatant("hero-2", "Мисливець", CombatantState.Side.HEROES, 2, 8, 20, 90, 15, 0))
	fighters.append(_combatant("hero-3", "Лікар", CombatantState.Side.HEROES, 3, 3, 20, 70, 5, 0))
	fighters.append(_combatant("enemy-1", "Вартовий", CombatantState.Side.ENEMIES, 1, 4, 16, 75, 10, 50))
	fighters.append(_combatant("enemy-2", "Культист", CombatantState.Side.ENEMIES, 2, 7, 10, 80, 20, 0))
	fighters.append(_combatant("enemy-3", "Тіньокіготь", CombatantState.Side.ENEMIES, 3, 6, 12, 85, 15, 0))

	var state := CombatState.new()
	state.round_number = 1
	state.outcome = CombatState.Outcome.ONGOING
	state.combatants = fighters
	state.turn_queue = CombatRules.new().build_turn_queue(fighters)
	state.prepared = null
	return state


## Separate new-model battle from docs/STARTING_ABILITIES_DETAILS.md, §3.5, §3.8, §7, §8 and §10.2.
## It does not replace create_opening_battle(). Slot 4 stays empty on both sides.
## Max HP comes from BaseHP and HEALTH through CombatMath; every fighter starts at full health.
static func create_new_model_battle() -> CombatState:
	var fighters: Array[CombatantState] = []
	# id, name, side, slot, speed, BaseHP, base accuracy, base dodge, block, STR/ARM/DEX/KNO/HEALTH, abilities
	fighters.append(_new_model("warrior", "Воїн", CombatantState.Side.HEROES, 1, 5, 20, 80, 10, 25, [5, 5, 3, 2, 4],
		["warrior_sword", "warrior_guard", "warrior_shield_push", "warrior_battle_stance"]))
	fighters.append(_new_model("hunter", "Мисливець", CombatantState.Side.HEROES, 2, 8, 20, 84, 12, 0, [3, 2, 6, 2, 3],
		["hunter_bow_shot", "hunter_dagger", "hunter_aimed_shot", "hunter_maneuver"]))
	fighters.append(_new_model("medic", "Лікар", CombatantState.Side.HEROES, 3, 3, 20, 68, 4, 0, [2, 2, 4, 6, 3],
		["medic_crossbow", "medic_healing", "medic_tincture", "medic_stimulant"]))
	fighters.append(_new_model("guardian", "Вартовий", CombatantState.Side.ENEMIES, 1, 4, 16, 77, 11, 50, [4, 4, 2, 1, 5],
		["guardian_shield_bash", "warrior_guard"]))
	fighters.append(_new_model("shadowclaw", "Тіньокіготь", CombatantState.Side.ENEMIES, 2, 6, 12, 77, 11, 0, [4, 1, 7, 1, 3],
		["shadowclaw_claw_strike", "shadowclaw_finisher"]))
	fighters.append(_new_model("cultist", "Культист", CombatantState.Side.ENEMIES, 3, 7, 10, 78, 19, 0, [2, 1, 4, 6, 3],
		["cultist_prepared_rite", "cultist_arrow_shot", "cultist_strike"]))

	var state := CombatState.new()
	state.round_number = 1
	state.outcome = CombatState.Outcome.ONGOING
	state.combatants = fighters
	state.turn_queue = CombatRules.new().build_turn_queue(fighters)
	state.prepared = null
	return state


static func _new_model(
	id: String,
	display_name: String,
	side: CombatantState.Side,
	position: int,
	speed: int,
	base_hp: int,
	accuracy: int,
	dodge: int,
	block: int,
	stats: Array[int],
	ability_ids: Array[String]
) -> CombatantState:
	var max_hp: Variant = CombatMath.max_hp(base_hp, stats[4] * CombatMath.STAT_ONE)
	assert(max_hp != null)
	var combatant := _combatant(id, display_name, side, position, speed, max_hp, accuracy, dodge, block)
	combatant.strength = stats[0]
	combatant.armor = stats[1]
	combatant.dexterity = stats[2]
	combatant.knowledge = stats[3]
	combatant.health = stats[4]
	combatant.ability_ids.assign(ability_ids)
	return combatant


static func _combatant(
	id: String,
	display_name: String,
	side: CombatantState.Side,
	position: int,
	speed: int,
	hp: int,
	accuracy: int,
	dodge: int,
	block: int
) -> CombatantState:
	var combatant := CombatantState.new()
	combatant.id = id
	combatant.display_name = display_name
	combatant.side = side
	combatant.position = position
	combatant.speed = speed
	combatant.hp = hp
	combatant.max_hp = hp
	combatant.accuracy = accuracy
	combatant.dodge = dodge
	combatant.block = block
	combatant.guard_reduction = 0
	combatant.ability_ids = AbilityCatalog.ids_for(id)
	return combatant
