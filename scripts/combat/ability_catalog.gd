class_name AbilityCatalog
extends RefCounted

## Abilities for the first battle, plus the warrior's cover and the cultist's rite.
## Hero and enemy cards of the new model are listed after them. No control fighter has them in ids_for.


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
		"cultist_prepared_rite":
			return _prepared_rite()
		"shadowclaw_claws":
			return _make("shadowclaw_claws", "Кігті", 1, 4, 1, 4, 5, true, AbilityDefinition.Kind.STRIKE, 0)
		"shadowclaw_execute":
			return _finish(
				_make("shadowclaw_execute", "Добивання", 1, 4, 1, 4, 5, true, AbilityDefinition.Kind.STRIKE, 2),
				8,
				50,
				"5 шкоди. 8, якщо поточне здоров'я цілі не вище половини максимуму."
			)
		"warrior_sword":
			return _rolled_strike(_make("warrior_sword", "Удар мечем", 1, 2, 1, 2, 0, true, AbilityDefinition.Kind.STRIKE, 0), 4, 6, 100, 0)
		"warrior_shield_push":
			var push := _rolled_strike(_make("warrior_shield_push", "Щитовий поштовх", 1, 2, 1, 2, 0, true, AbilityDefinition.Kind.STRIKE, 2), 2, 4, 100, 0)
			push.pushes_target = true
			return push
		"warrior_battle_stance":
			return _self_effect(
				_make("warrior_battle_stance", "Бойова стійка", 1, 4, 1, 4, 0, false, AbilityDefinition.Kind.EFFECT, 3),
				"battle_stance",
				ActiveEffect.Kind.BLOCK_POINTS,
				50
			)
		"hunter_bow_shot":
			return _rolled_strike(_make("hunter_bow_shot", "Постріл", 2, 4, 1, 4, 0, true, AbilityDefinition.Kind.STRIKE, 0), 3, 5, 0, 100)
		"hunter_dagger":
			return _rolled_strike(_make("hunter_dagger", "Ніж", 1, 2, 1, 1, 0, true, AbilityDefinition.Kind.STRIKE, 0), 5, 7, 40, 60)
		"hunter_aimed_shot":
			var aimed := _rolled_strike(_make("hunter_aimed_shot", "Прицільний постріл", 2, 4, 2, 4, 0, true, AbilityDefinition.Kind.STRIKE, 2), 3, 5, 0, 100)
			aimed.accuracy_bonus = 15
			return aimed
		"hunter_maneuver":
			var maneuver := _self_effect(
				_make("hunter_maneuver", "Маневр", 1, 4, 1, 4, 0, false, AbilityDefinition.Kind.MANEUVER, 3),
				"maneuver_dodge",
				ActiveEffect.Kind.DODGE_POINTS,
				20
			)
			maneuver.target_mode = AbilityDefinition.TargetMode.OWN_ADJACENT
			return maneuver
		"medic_crossbow":
			return _rolled_strike(_make("medic_crossbow", "Арбалетний постріл", 2, 4, 1, 4, 0, true, AbilityDefinition.Kind.STRIKE, 0), 2, 4, 0, 100)
		"medic_healing":
			var healing := _make("medic_healing", "Зцілення", 3, 4, 1, 4, 4, false, AbilityDefinition.Kind.HEAL, 2)
			healing.knowledge_percent = 100
			return healing
		"medic_tincture":
			return _effect(
				_make("medic_tincture", "Настоянка стійкості", 1, 4, 1, 4, 0, false, AbilityDefinition.Kind.EFFECT, 3),
				"resilience_tincture",
				ActiveEffect.Kind.SPECIAL_RECEIVED_PERCENT,
				-40
			)
		"medic_stimulant":
			return _effect(
				_make("medic_stimulant", "Бойовий стимулятор", 2, 4, 1, 4, 0, false, AbilityDefinition.Kind.EFFECT, 3),
				"combat_stimulant",
				ActiveEffect.Kind.PHYSICAL_DEALT_PERCENT,
				30
			)
		"guardian_shield_bash":
			return _rolled_strike(_make("guardian_shield_bash", "Удар щитом", 1, 2, 1, 2, 0, true, AbilityDefinition.Kind.STRIKE, 0), 4, 6, 100, 0)
		"cultist_arrow_shot":
			return _rolled_strike(_make("cultist_arrow_shot", "Стріла", 2, 4, 1, 4, 0, true, AbilityDefinition.Kind.STRIKE, 0), 2, 4, 0, 100)
		"cultist_strike":
			return _rolled_strike(_make("cultist_strike", "Базовий удар", 1, 2, 1, 2, 0, true, AbilityDefinition.Kind.STRIKE, 0), 2, 3, 100, 0)
		"shadowclaw_claw_strike":
			return _rolled_strike(_make("shadowclaw_claw_strike", "Удар кігтями", 1, 2, 1, 4, 0, true, AbilityDefinition.Kind.STRIKE, 0), 4, 6, 30, 70)
		"shadowclaw_finisher":
			var finisher := _rolled_strike(_make("shadowclaw_finisher", "Добивання", 1, 2, 1, 4, 0, true, AbilityDefinition.Kind.STRIKE, 2), 4, 6, 30, 70)
			finisher.target_hp_max_percent = 50
			finisher.dealt_bonus_percent = 30
			return finisher
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


## New ritual. Not on the control cultist's list: that battle keeps cultist_rite.
static func _prepared_rite() -> AbilityDefinition:
	var ability := _make("cultist_prepared_rite", "Підготовлений обряд", 2, 4, 3, 4, 11, true, AbilityDefinition.Kind.RITE, 2)
	ability.damage_type = AbilityDefinition.DamageType.SPECIAL
	ability.knowledge_percent = 100
	ability.multiplier_percent = 100
	ability.guaranteed_hit = true
	return ability


static func _finish(ability: AbilityDefinition, finish_amount: int, below_percent: int, hint: String) -> AbilityDefinition:
	ability.finish_amount = finish_amount
	ability.finish_below_percent = below_percent
	ability.hint = hint
	return ability


## Physical strike with a rolled base. The two shares sum to 100.
static func _rolled_strike(
	ability: AbilityDefinition,
	base_min: int,
	base_max: int,
	strength_percent: int,
	dexterity_percent: int
) -> AbilityDefinition:
	ability.base_min = base_min
	ability.base_max = base_max
	ability.strength_percent = strength_percent
	ability.dexterity_percent = dexterity_percent
	return ability


## Every hero effect lasts two own turns of the target.
static func _effect(ability: AbilityDefinition, effect_id: String, kind: ActiveEffect.Kind, magnitude: int) -> AbilityDefinition:
	ability.effect_id = effect_id
	ability.effect_kind = kind
	ability.effect_magnitude = magnitude
	ability.effect_turns = 2
	return ability


static func _self_effect(ability: AbilityDefinition, effect_id: String, kind: ActiveEffect.Kind, magnitude: int) -> AbilityDefinition:
	ability.target_mode = AbilityDefinition.TargetMode.SELF
	return _effect(ability, effect_id, kind, magnitude)
