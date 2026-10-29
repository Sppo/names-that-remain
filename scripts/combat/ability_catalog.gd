class_name AbilityCatalog
extends RefCounted

## Abilities for the first battle, plus the warrior's cover and the cultist's rite.


static func definition(ability_id: String) -> AbilityDefinition:
	match ability_id:
		"hunter_basic":
			return _make("hunter_basic", "Базовий удар", 1, 4, 1, 4, 3, true, AbilityDefinition.Kind.STRIKE, 0)
		"hunter_shot":
			return _make("hunter_shot", "Постріл", 2, 4, 1, 4, 5, true, AbilityDefinition.Kind.STRIKE, 2)
		"hunter_knife":
			return _make("hunter_knife", "Ніж", 1, 2, 1, 2, 4, true, AbilityDefinition.Kind.STRIKE, 1)
		"cultist_basic":
			return _make("cultist_basic", "Базовий удар", 1, 4, 1, 4, 3, true, AbilityDefinition.Kind.STRIKE, 0)
		"cultist_arrow":
			return _make("cultist_arrow", "Стріла", 2, 4, 2, 4, 4, true, AbilityDefinition.Kind.STRIKE, 1)
		"warrior_basic":
			return _make("warrior_basic", "Базовий удар", 1, 4, 1, 4, 3, true, AbilityDefinition.Kind.STRIKE, 0)
		"warrior_shield":
			return _make("warrior_shield", "Удар щитом", 1, 2, 1, 2, 6, true, AbilityDefinition.Kind.STRIKE, 2)
		"guardian_basic":
			return _make("guardian_basic", "Базовий удар", 1, 4, 1, 4, 3, true, AbilityDefinition.Kind.STRIKE, 0)
		"guard_strike":
			return _make("guard_strike", "Удар", 1, 2, 1, 2, 5, true, AbilityDefinition.Kind.STRIKE, 1)
		"doctor_basic":
			return _make("doctor_basic", "Базовий удар", 1, 4, 1, 4, 2, true, AbilityDefinition.Kind.STRIKE, 0)
		"doctor_heal":
			return _make("doctor_heal", "Лікування", 3, 4, 1, 4, 5, false, AbilityDefinition.Kind.HEAL, 2)
		"warrior_guard":
			return _make("warrior_guard", "Прикрити", 1, 2, 1, 4, 10, false, AbilityDefinition.Kind.GUARD, 1)
		"cultist_rite":
			return _make("cultist_rite", "Обряд", 2, 4, 3, 4, 14, true, AbilityDefinition.Kind.RITE, 2)
		"shadowclaw_claws":
			return _make("shadowclaw_claws", "Кігті", 1, 4, 1, 4, 5, true, AbilityDefinition.Kind.STRIKE, 0)
		"shadowclaw_execute":
			return _finish(
				_make("shadowclaw_execute", "Добивання", 1, 4, 1, 4, 5, true, AbilityDefinition.Kind.STRIKE, 2),
				8,
				50,
				"5 шкоди. 8, якщо поточне здоров'я цілі не вище половини максимуму."
			)
		_:
			return null


static func ids_for(combatant_id: String) -> Array[String]:
	match combatant_id:
		"hero-2":
			return ["hunter_shot", "hunter_knife", "hunter_basic"]
		"enemy-2":
			return ["cultist_arrow", "cultist_rite", "cultist_basic"]
		"hero-1":
			return ["warrior_shield", "warrior_guard", "warrior_basic"]
		"enemy-1":
			return ["guard_strike", "warrior_guard", "guardian_basic"]
		"hero-3":
			return ["doctor_heal", "doctor_basic"]
		"enemy-3":
			return ["shadowclaw_claws", "shadowclaw_execute"]
		_:
			return []


static func _make(
	ability_id: String,
	label: String,
	from_min: int,
	from_max: int,
	target_min: int,
	target_max: int,
	amount: int,
	hits_enemies: bool,
	kind: AbilityDefinition.Kind,
	cooldown_turns: int
) -> AbilityDefinition:
	var ability := AbilityDefinition.new()
	ability.id = ability_id
	ability.label = label
	ability.from_min = from_min
	ability.from_max = from_max
	ability.target_min = target_min
	ability.target_max = target_max
	ability.amount = amount
	ability.hits_enemies = hits_enemies
	ability.kind = kind
	ability.cooldown_turns = cooldown_turns
	return ability


static func _finish(ability: AbilityDefinition, finish_amount: int, below_percent: int, hint: String) -> AbilityDefinition:
	ability.finish_amount = finish_amount
	ability.finish_below_percent = below_percent
	ability.hint = hint
	return ability
