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
