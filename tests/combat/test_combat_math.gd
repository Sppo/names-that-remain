extends GutTest

## Phase 2. Every numeric example from the combat docs, checked against CombatMath.
## Each test names its source. Stats are hundredths, P is ten-thousandths, percents are whole.


# --- Helpers ---------------------------------------------------------------


## P from whole stats and whole-percent shares.
func _p(strength: int, dexterity: int, knowledge: int, strength_share: int, dexterity_share: int, knowledge_share: int) -> Variant:
	return CombatMath.weighted_stat_x10000(
		strength * 100,
		dexterity * 100,
		knowledge * 100,
		strength_share,
		dexterity_share,
		knowledge_share
	)


func _damage(base: int, multiplier: int, weighted: int, dealt: int = 100, received: int = 100) -> Variant:
	return CombatMath.damage_before_armor(base, multiplier, weighted, dealt, received)


## Damage over each base of a range, for one fixed P and dealt multiplier.
func _damage_row(bases: Array[int], weighted: int, dealt: int = 100) -> Array[int]:
	var row: Array[int] = []
	for base: int in bases:
		row.append(_damage(base, 100, weighted, dealt))
	return row


## Physical chain after the pre-armor number: armor, then block, then cover.
func _physical(damage: int, armor: int, blocked: bool, guard: int) -> Array[int]:
	var after_armor: int = CombatMath.damage_after_armor(damage, armor * 100)
	var after_block: int = CombatMath.blocked_damage(after_armor) if blocked else after_armor
	var final: int = CombatMath.damage_after_guard(after_block, guard)
	return [after_armor, after_block, final]


const NEUTRAL_P: int = 30000


# --- Rounding ----------------------------------------------------------------


func test_round_half_up_rounds_exact_halves_up() -> void:
	# DAMAGE_SYSTEM §3: 2.49 → 2, 2.5 → 3, 3.5 → 4. ACCURACY H07: 4.49 / 4.50 / 4.51 → 4 / 5 / 5.
	assert_eq(CombatMath.round_half_up(249, 100), 2)
	assert_eq(CombatMath.round_half_up(25, 10), 3)
	assert_eq(CombatMath.round_half_up(35, 10), 4)
	assert_eq(CombatMath.round_half_up(449, 100), 4)
	assert_eq(CombatMath.round_half_up(450, 100), 5)
	assert_eq(CombatMath.round_half_up(451, 100), 5)
	assert_eq(CombatMath.round_half_up(0, 7), 0)


# --- Categories and effective stats (STATUS_EFFECTS_SYSTEM) ------------------


func test_category_sum_is_capped_once() -> void:
	# STATUS_EFFECTS_SYSTEM §4 table and §10 cases 1, 2, 4–7, 10.
	assert_eq(CombatMath.category_multiplier_percent(0), 100)
	assert_eq(CombatMath.category_multiplier_percent(20 + 10), 130)
	assert_eq(CombatMath.category_multiplier_percent(80 + 70), 200)
	assert_eq(CombatMath.category_multiplier_percent(-40 - 40), 40)
	assert_eq(CombatMath.category_multiplier_percent(100 - 60), 140)
	assert_eq(CombatMath.category_multiplier_percent(150 - 80), 170)
	assert_eq(CombatMath.category_multiplier_percent(-80 + 150), 170)
	assert_eq(CombatMath.category_multiplier_percent(-60), 40)
	assert_eq(CombatMath.category_multiplier_percent(100), 200)
	# +80% +70% gives ×2.00; after +70% ends, ×1.80.
	assert_eq(CombatMath.category_multiplier_percent(80), 180)


func test_different_categories_multiply_without_a_global_cap() -> void:
	# STATUS_EFFECTS_SYSTEM §5.2 and §10 cases 3, 8, 9: 8 × 1.30 × 1.25 = 13.
	assert_eq(CombatMath.category_multiplier_percent(30) * CombatMath.category_multiplier_percent(25), 16250)
	assert_eq(_damage(8, 100, NEUTRAL_P, 130, 125), 13)
	assert_eq(CombatMath.category_multiplier_percent(100) * CombatMath.category_multiplier_percent(100), 40000)
	assert_eq(CombatMath.category_multiplier_percent(-60) * CombatMath.category_multiplier_percent(-60), 1600)
	# §5.3 and case 21: healing ×1.30 × ×0.75 = ×0.975.
	assert_eq(CombatMath.category_multiplier_percent(20 + 10) * CombatMath.category_multiplier_percent(-25), 9750)


func test_effective_stat_adds_flat_then_percent_without_rounding() -> void:
	# STATUS_EFFECTS_SYSTEM §5.4 and case 20: STR 5 + 2 = 7, back to 5 when it ends.
	assert_eq(CombatMath.effective_stat_x100(5, 2, 0), 700)
	assert_eq(CombatMath.effective_stat_x100(5, 0, 0), 500)
	# STARTING_ABILITIES_DETAILS §11.12: (5 + 2) × 1.20 = 8.4.
	assert_eq(CombatMath.effective_stat_x100(5, 2, 20), 840)
	# STATUS_EFFECTS_SYSTEM case 19: ARM 5 with −30% is 3.5.
	assert_eq(CombatMath.effective_stat_x100(5, 0, -30), 350)


func test_reduced_armor_changes_the_armor_formula_only() -> void:
	# STATUS_EFFECTS_SYSTEM §5.4: ARM 3.5 lets through 20 / 23.5. 47 × 20 / 23.5 = 40 exactly.
	var armor: int = CombatMath.effective_stat_x100(5, 0, -30)
	assert_eq(CombatMath.damage_after_armor(47, armor), 40)
	# Without the effect ARM 5 lets through 80%.
	assert_eq(CombatMath.damage_after_armor(50, 500), 40)


# --- Max HP (HEALTH_CONCEPT, STARTING_ABILITIES_DETAILS) ---------------------


func test_max_hp_of_the_six_fighters() -> void:
	# STARTING_ABILITIES_DETAILS §7 and §11.1.
	assert_eq(CombatMath.max_hp(20, 400), 22)
	assert_eq(CombatMath.max_hp(20, 300), 20)
	assert_eq(CombatMath.max_hp(20, 300), 20)
	assert_eq(CombatMath.max_hp(16, 500), 20)
	assert_eq(CombatMath.max_hp(10, 300), 10)
	assert_eq(CombatMath.max_hp(12, 300), 12)


func test_max_hp_table_for_several_health_values() -> void:
	# HEALTH_CONCEPT §4, comparison table and worked examples.
	var expected := {
		20: [16, 18, 20, 22, 24, 34],
		16: [12, 14, 16, 18, 20, 30],
		10: [6, 8, 10, 12, 14, 24],
		12: [8, 10, 12, 14, 16, 26],
	}
	var healths: Array[int] = [1, 2, 3, 4, 5, 10]
	for base_hp: int in expected:
		var row: Array = expected[base_hp]
		for index in healths.size():
			assert_eq(CombatMath.max_hp(base_hp, healths[index] * 100), row[index], "BaseHP %d HEALTH %d" % [base_hp, healths[index]])


func test_max_hp_edge_cases() -> void:
	# HEALTH_CONCEPT §6.
	assert_eq(CombatMath.max_hp(20, 300), 20)
	assert_eq(CombatMath.max_hp(5, 100), 1)
	assert_eq(CombatMath.max_hp(4, 100), 1)
	assert_eq(CombatMath.max_hp(2, 100), 1)
	assert_eq(CombatMath.max_hp(2, 200), 1)
	assert_eq(CombatMath.max_hp(2, 300), 2)
	assert_eq(CombatMath.max_hp(20, 10000), 214)
	assert_eq(CombatMath.max_hp(10, 0), 4)
	# HEALTH 3.25 gives 20.5; the later approved single half-up makes it 21.
	assert_eq(CombatMath.max_hp(20, 325), 21)


func test_max_hp_from_a_fractional_effective_health() -> void:
	# STARTING_ABILITIES_DETAILS §11.12: HEALTH 4 × 1.20 = 4.8, MaxHP round_half_up(23.6) = 24.
	var health: int = CombatMath.effective_stat_x100(4, 0, 20)
	assert_eq(health, 480)
	assert_eq(CombatMath.max_hp(20, health), 24)


func test_current_hp_is_only_cut_when_max_changes() -> void:
	# STARTING_ABILITIES_DETAILS §11.12: 15 stays 15 at 22 → 24, drops to 12, stays 12 when max returns.
	assert_eq(CombatMath.current_hp_after_max_change(15, 24), 15)
	var cut: int = CombatMath.current_hp_after_max_change(15, 12)
	assert_eq(cut, 12)
	assert_eq(CombatMath.current_hp_after_max_change(cut, 22), 12)
	# HEALTH_CONCEPT §5: 13/20 at HEALTH 3 becomes 13/22, not 22/22.
	assert_eq(CombatMath.current_hp_after_max_change(13, 22), 13)
	# A fighter at 0 is not revived.
	assert_eq(CombatMath.current_hp_after_max_change(0, 22), 0)


# --- Weighted stat and scaling (DAMAGE_SYSTEM) -------------------------------


func test_weighted_stat_keeps_fractions() -> void:
	# DAMAGE_SYSTEM F04: STR 3, DEX 5, weights 0.4 / 0.6 give P = 4.2.
	assert_eq(_p(3, 5, 0, 40, 60, 0), 42000)
	# STARTING_ABILITIES_DETAILS §7.2: knife P = 0.6 × 6 + 0.4 × 3 = 4.8.
	assert_eq(_p(3, 6, 2, 40, 60, 0), 48000)
	# HUNTER_ABILITIES §8: knife with DEX 5, STR 2 gives 3.8, not 4.
	assert_eq(_p(2, 5, 0, 40, 60, 0), 38000)
	# STARTING_ABILITIES_DETAILS §8.3: claws P = 0.7 × 7 + 0.3 × 4 = 6.1.
	assert_eq(_p(4, 7, 1, 30, 70, 0), 61000)
	# No shares means no scaling.
	assert_eq(_p(9, 9, 9, 0, 0, 0), NEUTRAL_P)


func test_scaling_matches_the_exact_fractions() -> void:
	# DAMAGE_SYSTEM §2.1: M(P) as exact fractions. Base equal to the denominator gives the numerator.
	assert_eq(_damage(7, 100, 0), 4)
	assert_eq(_damage(4, 100, 10000), 3)
	assert_eq(_damage(5, 100, 30000), 5)
	assert_eq(_damage(28, 100, 42000), 31)
	assert_eq(_damage(6, 100, 50000), 7)
	assert_eq(_damage(17, 100, 100000), 24)
	assert_eq(_damage(27, 100, 200000), 44)


# --- Damage before armor (DAMAGE_SYSTEM) -------------------------------------


func test_damage_formula_cases() -> void:
	# DAMAGE_SYSTEM §7.1, F01–F09.
	assert_eq(_damage(5, 100, NEUTRAL_P), 5)
	assert_eq(_damage(6, 100, 10000), 5)
	assert_eq(_damage(5, 50, NEUTRAL_P), 3)
	var mixed: int = _damage(5, 140, _p(3, 5, 0, 40, 60, 0), 125, 120)
	assert_eq(mixed, 12)
	assert_eq(CombatMath.damage_after_armor(mixed, 500), 10)
	var tiny: int = _damage(1, 100, NEUTRAL_P, 49)
	assert_eq(tiny, 0)
	assert_eq(CombatMath.damage_after_armor(tiny, 10000), 0)
	assert_eq(_damage(10, 100, NEUTRAL_P, 100, 0), 0)
	assert_eq(CombatMath.damage_after_armor(0, 500), 0)
	assert_eq(_damage(5, 110, NEUTRAL_P, 110), 6)
	assert_eq(_damage(0, 100, 50000), 0)


func test_sword_example_rounds_each_base_separately() -> void:
	# DAMAGE_SYSTEM §6 A: STR 5 gives 5 / 6 / 7; with A = 1.4 it gives 7 / 8 / 10, never 9.
	var strength_only: int = _p(5, 3, 3, 100, 0, 0)
	assert_eq(_damage_row([4, 5, 6], strength_only), [5, 6, 7])
	var stronger: Array[int] = []
	for base: int in [4, 5, 6]:
		stronger.append(_damage(base, 140, strength_only))
	assert_eq(stronger, [7, 8, 10])


# --- Armor, block, cover -----------------------------------------------------


func test_armor_table() -> void:
	# ARMOR_SYSTEM §5: damage after armor for D = 1, 5, 8, 14.
	var table := {
		0: [1, 5, 8, 14],
		3: [1, 4, 7, 12],
		5: [1, 4, 6, 11],
		10: [1, 3, 5, 9],
		20: [1, 3, 4, 7],
		40: [1, 2, 3, 5],
		60: [1, 1, 2, 4],
	}
	var hits: Array[int] = [1, 5, 8, 14]
	for armor: int in table:
		var row: Array = table[armor]
		for index in hits.size():
			assert_eq(CombatMath.damage_after_armor(hits[index], armor * 100), row[index], "ARM %d D %d" % [armor, hits[index]])


func test_armor_examples() -> void:
	# ARMOR_SYSTEM §6: 14 → 11 → 5 → 0; 5 at ARM 20 → 3, block → 1; 1 at ARM 60 → 1.
	assert_eq(_physical(14, 5, true, 10), [11, 5, 0])
	assert_eq(_physical(5, 20, true, 0), [3, 1, 1])
	assert_eq(_physical(1, 60, false, 0), [1, 1, 1])
	# Comparison table.
	assert_eq(_physical(14, 5, false, 0), [11, 11, 11])
	assert_eq(_physical(14, 5, true, 0), [11, 5, 5])
	assert_eq(_physical(14, 5, false, 10), [11, 11, 1])
	assert_eq(_physical(5, 0, false, 10), [5, 5, 0])
	assert_eq(_physical(1, 60, true, 0), [1, 0, 0])
	assert_eq(_physical(1, 60, true, 10), [1, 0, 0])


func test_defence_cases() -> void:
	# DAMAGE_SYSTEM §7.2, D01–D12: armor, block and cover columns.
	assert_eq(_physical(5, 0, false, 0), [5, 5, 5])
	assert_eq(_physical(5, 20, false, 0), [3, 3, 3])
	assert_eq(_physical(5, 3, false, 0), [4, 4, 4])
	assert_eq(_physical(5, 5, false, 0), [4, 4, 4])
	assert_eq(_physical(1, 100, false, 0), [1, 1, 1])
	assert_eq(_physical(1, 100, true, 0), [1, 0, 0])
	assert_eq(_physical(14, 5, true, 10), [11, 5, 0])
	assert_eq(_physical(14, 0, false, 10), [14, 14, 4])
	assert_eq(_physical(3, 0, false, 10), [3, 3, 0])
	assert_eq(_physical(0, 20, false, 10), [0, 0, 0])
	assert_eq(_physical(1, 0, true, 10), [1, 0, 0])
	assert_eq(_physical(7, 0, false, 0), [7, 7, 7])
	# DAMAGE_SYSTEM §6 D.
	assert_eq(_physical(1, 100, false, 0), [1, 1, 1])


func test_physical_and_special_branches() -> void:
	# DAMAGE_TYPES_SYSTEM §5, T01–T08.
	assert_eq(_physical(10, 0, false, 0)[2], 10)
	assert_eq(_physical(10, 20, false, 0)[2], 5)
	assert_eq(_physical(14, 5, true, 10), [11, 5, 0])
	assert_eq(_physical(14, 5, true, 3)[2], 2)
	assert_eq(_physical(1, 100, false, 0)[2], 1)
	assert_eq(_physical(1, 100, true, 0)[2], 0)
	assert_eq(_physical(0, 40, false, 0)[2], 0)
	# Special damage ends at the pre-armor number: no armor, block or cover stage.
	# T09, T13: 10 stays 10. T10, T12, T14: a 30% buff gives 7. T17: 3.5 → 4. T19: 0 stays 0.
	assert_eq(_damage(10, 100, NEUTRAL_P), 10)
	assert_eq(_damage(10, 100, NEUTRAL_P, 100, 70), 7)
	assert_eq(_damage(5, 100, NEUTRAL_P, 100, 70), 4)
	assert_eq(_damage(0, 100, NEUTRAL_P, 100, 70), 0)
	# §4.3: 10 at 50% gives 5. §4.4 and T18: 10 × 1.20 × 0.70 = 8.4 → 8, the buff counted once.
	assert_eq(_damage(10, 100, NEUTRAL_P, 100, 50), 5)
	assert_eq(_damage(10, 100, NEUTRAL_P, 120, 70), 8)


# --- Accuracy, dodge, hit chance (ACCURACY_DODGE_HEALING_SYSTEM) -------------


func test_dexterity_contribution_table() -> void:
	# ACCURACY_DODGE_HEALING_SYSTEM §3.1.
	var accuracy := {100: -400, 200: -200, 300: 0, 500: 400, 700: 800}
	var dodge := {100: -200, 200: -100, 300: 0, 500: 200, 700: 400}
	for dexterity: int in accuracy:
		assert_eq(CombatMath.accuracy_x100(80, dexterity, 0) - 8000, accuracy[dexterity])
		assert_eq(CombatMath.dodge_x100(10, dexterity, 0) - 1000, dodge[dexterity])


func test_hunter_against_cultist_table() -> void:
	# ACCURACY_DODGE_HEALING_SYSTEM §3.3. Prototype 90 and 20 used as bases at DEX 3.
	var rows := [
		[300, 300, 70],
		[500, 300, 74],
		[300, 500, 68],
		[500, 500, 72],
		[100, 300, 66],
		[300, 100, 72],
		[500, 700, 70],
	]
	for row: Array in rows:
		var accuracy: int = CombatMath.accuracy_x100(90, row[0], 0)
		var dodge: int = CombatMath.dodge_x100(20, row[1], 0)
		assert_eq(CombatMath.hit_chance(accuracy, dodge), row[2], "DEX %d vs %d" % [row[0], row[1]])


func test_hit_chance_cases() -> void:
	# ACCURACY_DODGE_HEALING_SYSTEM §8.1.
	assert_eq(CombatMath.accuracy_x100(80, 300, 0), 8000)
	assert_eq(CombatMath.dodge_x100(10, 300, 0), 1000)
	assert_eq(CombatMath.hit_chance(8000, 1000), 70)
	assert_eq(CombatMath.hit_chance(9000, 2000), 70)
	assert_eq(CombatMath.hit_chance(10000, 0), 95)
	assert_eq(CombatMath.hit_chance(2500, 5000), 5)
	assert_eq(CombatMath.hit_chance(2000, 1500), 5)
	assert_eq(CombatMath.hit_chance(9500, 0), 95)
	# A09: raw 94, attacker +2 DEX gives raw 98, final 95.
	assert_eq(CombatMath.hit_chance(9400, 0), 94)
	assert_eq(CombatMath.hit_chance(CombatMath.accuracy_x100(94, 500, 0), 0), 95)
	# A11: back-calibrated bases 86 and 18 at DEX 5 give 90 and 20.
	assert_eq(CombatMath.accuracy_x100(86, 500, 0), 9000)
	assert_eq(CombatMath.dodge_x100(18, 500, 0), 2000)
	# A14: DEX 1.
	assert_eq(CombatMath.accuracy_x100(80, 100, 0), 7600)
	assert_eq(CombatMath.dodge_x100(10, 100, 0), 800)
	# DAMAGE_SYSTEM R08: raw 120 and −10.
	assert_eq(CombatMath.hit_chance(12000, 0), 95)
	assert_eq(CombatMath.hit_chance(0, 1000), 5)


func test_fractional_dexterity_rounds_the_chance_once() -> void:
	# ACCURACY_DODGE_HEALING_SYSTEM A13: DEX 3.5 gives Accuracy 81 and Dodge 10.5.
	# The doc writes a 70.5% chance from before the single half-up was approved; it is 71.
	var accuracy: int = CombatMath.accuracy_x100(80, 350, 0)
	var dodge: int = CombatMath.dodge_x100(10, 350, 0)
	assert_eq(accuracy, 8100)
	assert_eq(dodge, 1050)
	assert_eq(CombatMath.hit_chance(accuracy, dodge), 71)
	# STARTING_ABILITIES_DETAILS §3.5 and §11.13: 83.6 − 13.4 = 70.2 → 70, not 71.
	assert_eq(CombatMath.hit_chance(8360, 1340), 70)


func test_base_accuracy_and_dodge_of_the_six() -> void:
	# STARTING_ABILITIES_DETAILS §3.5 and §11.3.
	var fighters := [
		[80, 10, 300, 80, 10],
		[84, 12, 600, 90, 15],
		[68, 4, 400, 70, 5],
		[77, 11, 200, 75, 10],
		[78, 19, 400, 80, 20],
		[77, 11, 700, 85, 15],
	]
	for row: Array in fighters:
		assert_eq(CombatMath.accuracy_x100(row[0], row[2], 0), row[3] * 100)
		assert_eq(CombatMath.dodge_x100(row[1], row[2], 0), row[4] * 100)
	# DEX bonuses 0 / +6 / +2 / −2 / +2 / +8 and 0 / +3 / +1 / −1 / +1 / +4.
	var bonuses := [[300, 0, 0], [600, 6, 3], [400, 2, 1], [200, -2, -1], [400, 2, 1], [700, 8, 4]]
	for row: Array in bonuses:
		assert_eq(CombatMath.accuracy_x100(0, row[0], 0), row[1] * 100)
		assert_eq(CombatMath.dodge_x100(0, row[0], 0), row[2] * 100)


func test_ability_bonuses_are_percentage_points() -> void:
	# HUNTER_ABILITIES §3.1 and §8: aimed shot +15 before the bound, maneuver +20 on dodge.
	var aimed: int = CombatMath.accuracy_x100(84, 600, 15)
	assert_eq(CombatMath.hit_chance(aimed, CombatMath.dodge_x100(19, 400, 0)), 85)
	assert_eq(CombatMath.hit_chance(CombatMath.accuracy_x100(90, 300, 15), 0), 95)
	# Maneuver example: Accuracy 90 against Dodge 20 is 70%, with +20 it is 50%.
	assert_eq(CombatMath.hit_chance(9000, CombatMath.dodge_x100(20, 300, 20)), 50)
	# Dodge 20 with maneuver +20 and another +5 is 45, not 65.
	assert_eq(CombatMath.dodge_x100(20, 300, 20 + 5), 4500)
	# +2 DEX: accuracy +4, dodge +2, each once.
	assert_eq(CombatMath.accuracy_x100(84, 800, 0) - CombatMath.accuracy_x100(84, 600, 0), 400)
	assert_eq(CombatMath.dodge_x100(12, 800, 0) - CombatMath.dodge_x100(12, 600, 0), 200)


func test_block_chance_cap() -> void:
	# STARTING_ABILITIES_DETAILS §3.3, §11.13: 25 + 50 = 75; 50 + 50 → 95.
	assert_eq(CombatMath.block_chance(25, 50), 75)
	assert_eq(CombatMath.block_chance(50, 50), 95)
	assert_eq(CombatMath.block_chance(0, 0), 0)
	assert_eq(CombatMath.block_chance(25, 0), 25)


# --- Healing (ACCURACY_DODGE_HEALING_SYSTEM) ---------------------------------


func test_heal_scales_with_knowledge() -> void:
	# ACCURACY_DODGE_HEALING_SYSTEM §5.3.
	var expected := {100: 3, 300: 4, 500: 5, 700: 5, 1000: 6, 2000: 7}
	for knowledge: int in expected:
		assert_eq(CombatMath.heal_amount(4, 100, knowledge, 100, 100), expected[knowledge], "KNO %d" % knowledge)
	# STARTING_ABILITIES_DETAILS §7.3: BaseHeal 4 at KNO 6 heals 5.
	assert_eq(CombatMath.heal_amount(4, 100, 600, 100, 100), 5)


func test_heal_cases() -> void:
	# ACCURACY_DODGE_HEALING_SYSTEM §8.2.
	assert_eq(CombatMath.heal_amount(4, 100, 300, 100, 100), 4)
	var heal: int = CombatMath.heal_amount(4, 100, 500, 100, 100)
	assert_eq(heal, 5)
	assert_eq(CombatMath.restored_hp(heal, 9, 12), 3)
	assert_eq(CombatMath.restored_hp(heal, 12, 12), 0)
	# H06: raw 4.5 heals 5, not 4. The integer-percent A cannot hold 1.125, so 9 × 0.5 gives the same 4.5.
	assert_eq(CombatMath.heal_amount(9, 50, 300, 100, 100), 5)
	assert_eq(CombatMath.heal_amount(0, 100, 500, 100, 100), 0)
	# H09: raw 0.4 heals 0, no minimum of 1.
	assert_eq(CombatMath.heal_amount(1, 100, 300, 100, 40), 0)
	# H10: ×1.30 and ×0.75 give 4.55 → 5.
	assert_eq(CombatMath.heal_amount(4, 100, 500, 130, 75), 5)
	# H11–H13: category caps.
	assert_eq(CombatMath.category_multiplier_percent(80 + 50), 200)
	assert_eq(CombatMath.category_multiplier_percent(-50 - 30), 40)
	assert_eq(CombatMath.category_multiplier_percent(80 + 50 - 50), 180)
	assert_eq(CombatMath.category_multiplier_percent(-50 + 80 + 50), 180)
	# H14: both categories at +100% heal 19 before the HP cap.
	assert_eq(CombatMath.heal_amount(4, 100, 500, 200, 200), 19)
	# H18: 13 of 12 restores 0 and never lowers HP.
	assert_eq(CombatMath.restored_hp(5, 13, 12), 0)
	# H20: KNO 3 → 5 heals 4 → 5.
	assert_eq(CombatMath.heal_amount(4, 100, 300, 100, 100), 4)
	assert_eq(CombatMath.heal_amount(4, 100, 500, 100, 100), 5)
	# STARTING_ABILITIES_DETAILS §11.2: missing 2 HP restores 2.
	assert_eq(CombatMath.restored_hp(5, 18, 20), 2)


func test_heal_with_effects_table() -> void:
	# ACCURACY_DODGE_HEALING_SYSTEM §6.1 and §6.2. BaseHeal 4, KNO 5.
	assert_eq(CombatMath.category_multiplier_percent(20 + 10), 130)
	assert_eq(CombatMath.category_multiplier_percent(-25), 75)
	assert_eq(CombatMath.heal_amount(4, 100, 500, 100, 100), 5)
	assert_eq(CombatMath.heal_amount(4, 100, 500, 130, 75), 5)
	assert_eq(CombatMath.heal_amount(4, 100, 500, CombatMath.category_multiplier_percent(130), 100), 9)
	assert_eq(CombatMath.heal_amount(4, 100, 500, 100, CombatMath.category_multiplier_percent(-80)), 2)
	assert_eq(CombatMath.heal_amount(4, 100, 500, 200, 200), 19)
	assert_eq(CombatMath.heal_amount(4, 100, 500, 40, 40), 1)


# --- Ability cards (STARTING_ABILITIES_DETAILS, COMBAT_IMPLEMENTATION_PLAN phase 2) ---


func test_enemy_cards() -> void:
	# STARTING_ABILITIES_DETAILS §8.4–8.6.
	assert_eq(_damage_row([4, 5, 6], _p(4, 2, 1, 100, 0, 0)), [4, 5, 7])
	var claws: int = _p(4, 7, 1, 30, 70, 0)
	assert_eq(_damage_row([4, 5, 6], claws), [5, 6, 7])
	assert_eq(_damage_row([4, 5, 6], claws, CombatMath.category_multiplier_percent(30)), [6, 8, 10])
	assert_eq(_damage_row([2, 3, 4], _p(2, 4, 6, 0, 100, 0)), [2, 3, 4])
	assert_eq(_damage_row([2, 3], _p(2, 4, 6, 100, 0, 0)), [2, 3])


func test_hero_cards() -> void:
	# STARTING_ABILITIES_DETAILS §4–6, with the stats from §7.
	var warrior_strength: int = _p(5, 3, 2, 100, 0, 0)
	assert_eq(_damage_row([4, 5, 6], warrior_strength), [5, 6, 7])
	# Shield push includes the exact half 3.5 → 4.
	assert_eq(_damage_row([2, 3, 4], warrior_strength), [2, 4, 5])
	var hunter_dexterity: int = _p(3, 6, 2, 0, 100, 0)
	assert_eq(_damage_row([3, 4, 5], hunter_dexterity), [4, 5, 6])
	assert_eq(_damage_row([5, 6, 7], _p(3, 6, 2, 40, 60, 0)), [6, 7, 8])
	assert_eq(_damage_row([2, 3, 4], _p(2, 4, 6, 0, 100, 0)), [2, 3, 4])


func test_rite_and_tincture() -> void:
	# STARTING_ABILITIES_DETAILS §8.5: base 11, KNO 6 gives 14; with the tincture 8, one rounding.
	var knowledge: int = _p(2, 4, 6, 0, 0, 100)
	assert_eq(_damage(11, 100, knowledge), 14)
	var tincture: int = CombatMath.category_multiplier_percent(-40)
	assert_eq(tincture, 60)
	assert_eq(_damage(11, 100, knowledge, 100, tincture), 8)
	# MEDIC_RESILIENCE_TINCTURE §7: 7.5 × 0.6 = 4.5 → 5. This only checks the exact half:
	# rounding 7.5 to 8 first gives 8 × 0.6 = 4.8 → 5 as well. The rite does not tell them apart either.
	assert_eq(_damage(15, 50, NEUTRAL_P, 100, tincture), 5)
	# Here one rounding and two differ: 1 × 4/7 × 0.6 ≈ 0.34 → 0, while rounding 4/7 to 1 first gives 0.6 → 1.
	assert_eq(_damage(1, 100, 0, 100, tincture), 0)
	# §6.2: vulnerability +25% and tincture −40% sum to −15%.
	assert_eq(CombatMath.category_multiplier_percent(25 - 40), 85)


func test_tincture_table() -> void:
	# MEDIC_RESILIENCE_TINCTURE §7 and §8 cases 4, 9, 11–13, 20.
	assert_eq(_damage(14, 100, NEUTRAL_P), 14)
	assert_eq(_damage(14, 100, NEUTRAL_P, 100, 60), 8)
	assert_eq(_damage(15, 100, NEUTRAL_P, 100, 60), 9)
	assert_eq(_damage(14, 100, NEUTRAL_P, 100, CombatMath.category_multiplier_percent(25 - 40)), 12)
	assert_eq(_damage(14, 100, NEUTRAL_P, 100, CombatMath.category_multiplier_percent(-40 - 30)), 6)
	assert_eq(_damage(14, 100, NEUTRAL_P, 100, CombatMath.category_multiplier_percent(100 + 70 - 40)), 28)
	assert_eq(_damage(14, 100, NEUTRAL_P, CombatMath.category_multiplier_percent(20 + 10), 60), 11)
	# Physical 14 with a +25% vulnerability, the tincture filtered out: 17.5 → 18.
	assert_eq(_damage(14, 100, NEUTRAL_P, 100, 125), 18)
	assert_eq(_damage(15, 50, NEUTRAL_P, 100, 60), 5)


func test_medic_examples() -> void:
	# MEDIC_ABILITIES §7 and §10.
	assert_eq(_damage(14, 100, NEUTRAL_P, 100, 60), 8)
	assert_eq(_damage(10, 100, NEUTRAL_P, 130), 13)
	assert_eq(CombatMath.category_multiplier_percent(30 + 20), 150)
	assert_eq(CombatMath.category_multiplier_percent(-40 + 25), 85)
	assert_eq(CombatMath.category_multiplier_percent(-40 - 30), 40)
	assert_eq(_damage_row([2, 3, 4], _p(2, 4, 6, 0, 100, 0)), [2, 3, 4])
	assert_eq(CombatMath.heal_amount(4, 100, 600, 100, 100), 5)


func test_warrior_examples() -> void:
	# WARRIOR_ABILITIES §4.1: push at STR 3 and STR 5; STR 5, base 3 into ARM 5.
	assert_eq(_damage_row([2, 3, 4], _p(3, 3, 3, 100, 0, 0)), [2, 3, 4])
	assert_eq(_damage_row([2, 3, 4], _p(5, 3, 3, 100, 0, 0)), [2, 4, 5])
	var push: int = _damage(3, 100, _p(5, 3, 3, 100, 0, 0))
	assert_eq(push, 4)
	assert_eq(_physical(push, 5, false, 0), [3, 3, 3])
	assert_eq(_physical(push, 5, true, 0), [3, 1, 1])
	# §4.2: 14 into ARM 5 under cover, with and without block.
	assert_eq(_physical(14, 5, true, 10), [11, 5, 0])
	assert_eq(_physical(14, 5, false, 10), [11, 11, 1])
	# §4.4: rite 14 under the tincture.
	assert_eq(_damage(14, 100, NEUTRAL_P, 100, 60), 8)


func test_hunter_examples() -> void:
	# HUNTER_BASIC_ABILITIES §4 A: P = 3.
	assert_eq(_damage_row([3, 4, 5], NEUTRAL_P), [3, 4, 5])
	assert_eq(_damage_row([5, 6, 7], _p(3, 3, 3, 40, 60, 0)), [5, 6, 7])
	# §4 B: DEX 5, STR 3; shot 5 and knife 7, after ARM 5 → 4 and 6.
	var shot: int = _damage(4, 100, _p(3, 5, 3, 0, 100, 0))
	var knife: int = _damage(6, 100, _p(3, 5, 3, 40, 60, 0))
	assert_eq(shot, 5)
	assert_eq(knife, 7)
	assert_eq(CombatMath.damage_after_armor(shot, 500), 4)
	assert_eq(CombatMath.damage_after_armor(knife, 500), 6)
	# §4 C: knife 7 into ARM 5, block, cover → 6, 3, 0. §4 D: shot 5 under cover → 0.
	assert_eq(_physical(7, 5, true, 10), [6, 3, 0])
	assert_eq(_physical(5, 0, false, 10), [5, 5, 0])
	# §5 cases 16–19.
	assert_eq(_physical(3, 4, false, 0), [3, 3, 3])
	assert_eq(_physical(3, 0, true, 0), [3, 1, 1])
	assert_eq(_physical(1, 100, false, 0), [1, 1, 1])
	assert_eq(_physical(1, 100, true, 0), [1, 0, 0])
	assert_eq(_physical(1, 100, true, 10), [1, 0, 0])
	# HUNTER_ABILITIES §8: shot at DEX 1 → 3; DEX 5 with +20% +10% dealt and +25% received → 8, ARM 5 → 6, block → 3.
	assert_eq(_damage(4, 100, _p(3, 1, 3, 0, 100, 0)), 3)
	var boosted: int = _damage(4, 100, _p(3, 5, 3, 0, 100, 0), CombatMath.category_multiplier_percent(20 + 10), 125)
	assert_eq(boosted, 8)
	assert_eq(_physical(boosted, 5, true, 0), [6, 3, 3])
	assert_eq(_physical(4, 0, false, 10)[2], 0)
	assert_eq(_physical(13, 0, false, 10)[2], 3)


# --- Input outside the formulas' domain --------------------------------------


func test_invalid_input_is_reported_and_returns_null() -> void:
	assert_null(CombatMath.round_half_up(5, 0))
	assert_null(CombatMath.round_half_up(-5, 2))
	assert_null(CombatMath.effective_stat_x100(2, -3, 0))
	assert_null(CombatMath.max_hp(20, -100))
	assert_null(CombatMath.current_hp_after_max_change(5, 0))
	# DAMAGE_SYSTEM F10: negative armor or stats, shares that do not sum to 1.
	assert_null(CombatMath.weighted_stat_x10000(-100, 300, 300, 100, 0, 0))
	assert_null(CombatMath.weighted_stat_x10000(300, 300, 300, 40, 50, 0))
	assert_null(CombatMath.damage_before_armor(5, -100, NEUTRAL_P, 100, 100))
	assert_null(CombatMath.damage_after_armor(5, -100))
	assert_null(CombatMath.blocked_damage(-1))
	assert_null(CombatMath.damage_after_guard(5, -10))
	assert_null(CombatMath.accuracy_x100(80, -100, 0))
	assert_null(CombatMath.block_chance(25, -30))
	# ACCURACY_DODGE_HEALING_SYSTEM H19: KNO −7.
	assert_null(CombatMath.heal_amount(4, 100, -700, 100, 100))
	assert_null(CombatMath.restored_hp(-1, 5, 10))
	assert_push_error_count(15)


func test_healing_error_names_the_healing_function() -> void:
	assert_null(CombatMath.heal_amount(4, -100, 300, 100, 100))
	assert_push_error("CombatMath.heal_amount")


func test_valid_input_reports_no_error() -> void:
	CombatMath.damage_before_armor(11, 100, 60000, 100, 60)
	CombatMath.damage_after_armor(14, 500)
	CombatMath.heal_amount(4, 100, 600, 100, 100)
	CombatMath.max_hp(10, 0)
	assert_push_error_count(0)


# --- Negative results are values, not errors ---------------------------------


func test_minus_one_is_a_valid_accuracy_or_dodge() -> void:
	# Accuracy and dodge are not clamped on their own, so −1 (in hundredths) is a real result.
	var dodge: Variant = CombatMath.dodge_x100(0, 299, 0)
	assert_not_null(dodge)
	assert_eq(dodge, -1)
	var accuracy: Variant = CombatMath.accuracy_x100(0, 300, -1)
	assert_eq(accuracy, -100)
	assert_eq(CombatMath.accuracy_x100(1, 250, 0), 0)
	assert_eq(CombatMath.accuracy_x100(0, 100, 0), -400)
	# Negative accuracy or dodge still gives a bounded chance.
	assert_eq(CombatMath.hit_chance(-1, 1000), 5)
	assert_eq(CombatMath.hit_chance(9000, -1), 90)
	assert_eq(CombatMath.hit_chance(9600, -1), 95)
	assert_push_error_count(0)


# --- Overflow ------------------------------------------------------------------


func test_overflow_fails_instead_of_returning_a_wrong_number() -> void:
	# Checker found this pair wrapping to −993805: the old 2n + d rounding overflowed.
	# The product itself fits (≈8.16e18), so now the exact value comes back.
	assert_eq(CombatMath.damage_before_armor(10000, 10000, 1000000, 200, 200), 7626168)
	# Ten times the base no longer fits and fails.
	assert_null(CombatMath.damage_before_armor(100000, 10000, 1000000, 200, 200))
	assert_null(CombatMath.heal_amount(CombatMath.INT_MAX, 100, 300, 100, 100))
	assert_null(CombatMath.effective_stat_x100(CombatMath.INT_MAX, 1, 0))
	assert_null(CombatMath.max_hp(CombatMath.INT_MAX, 300))
	assert_null(CombatMath.accuracy_x100(CombatMath.INT_MAX, 300, 0))
	assert_null(CombatMath.dodge_x100(0, 300, CombatMath.INT_MIN))
	assert_null(CombatMath.block_chance(CombatMath.INT_MAX, 1))
	assert_null(CombatMath.weighted_stat_x10000(CombatMath.INT_MAX, 0, 0, 100, 0, 0))
	assert_push_error_count(8)


func test_values_right_at_the_overflow_limit() -> void:
	# The largest stat that still fits after ×200 succeeds; one point more fails.
	var limit := CombatMath.INT_MAX / 200
	assert_eq(CombatMath.effective_stat_x100(limit, 0, 100), limit * 200)
	assert_null(CombatMath.effective_stat_x100(limit + 1, 0, 100))
	# Armor multiplies the damage by 2000 first.
	var armor_limit := CombatMath.INT_MAX / 2000
	assert_eq(CombatMath.damage_after_armor(armor_limit, 0), armor_limit)
	assert_null(CombatMath.damage_after_armor(armor_limit + 1, 0))
	# A sum right at the edge is fine: base + 0 bonus.
	assert_eq(CombatMath.block_chance(CombatMath.INT_MAX, 0), 95)
	assert_push_error_count(2)


func test_rounding_never_overflows() -> void:
	# Quotient and remainder, not 2n + d.
	assert_eq(CombatMath.round_half_up(CombatMath.INT_MAX, 1), CombatMath.INT_MAX)
	assert_eq(CombatMath.round_half_up(CombatMath.INT_MAX, 2), CombatMath.INT_MAX / 2 + 1)
	assert_eq(CombatMath.round_half_up(CombatMath.INT_MAX - 1, CombatMath.INT_MAX), 1)
	assert_eq(CombatMath.round_half_up(CombatMath.INT_MAX / 2, CombatMath.INT_MAX), 0)
	# Extreme accuracy and dodge still end inside 5–95.
	assert_eq(CombatMath.hit_chance(CombatMath.INT_MAX, CombatMath.INT_MIN), 95)
	assert_eq(CombatMath.hit_chance(CombatMath.INT_MIN, CombatMath.INT_MAX), 5)
	assert_push_error_count(0)


# --- Examples added after the Checker review ---------------------------------


func test_accuracy_migration_table() -> void:
	# ACCURACY_DODGE_HEALING_SYSTEM §4: bases 86 and 18 at DEX 5 keep 90 and 20.
	assert_eq(CombatMath.hit_chance(CombatMath.accuracy_x100(86, 500, 0), CombatMath.dodge_x100(18, 500, 0)), 70)
	# Hunter +2 DEX after migration: 86 + 2 × (7 − 3) − 20 = 74%.
	assert_eq(CombatMath.hit_chance(CombatMath.accuracy_x100(86, 700, 0), CombatMath.dodge_x100(18, 500, 0)), 74)
	# The mistake of keeping 90 as the base gives 94 instead of 90.
	assert_eq(CombatMath.accuracy_x100(90, 500, 0), 9400)


func test_shot_and_knife_read_only_their_stats() -> void:
	# HUNTER_BASIC_ABILITIES §5, cases 10–12.
	var shot: Variant = _p(3, 5, 3, 0, 100, 0)
	assert_eq(_p(7, 5, 3, 0, 100, 0), shot)
	assert_eq(_p(3, 5, 9, 0, 100, 0), shot)
	var knife: Variant = _p(3, 5, 3, 40, 60, 0)
	assert_eq(_p(3, 5, 9, 40, 60, 0), knife)
	# STR +1 moves P by 0.4, DEX +1 by 0.6.
	assert_eq(_p(4, 5, 3, 40, 60, 0) - knife, 4000)
	assert_eq(_p(3, 6, 3, 40, 60, 0) - knife, 6000)


func test_block_halves_eight_to_four() -> void:
	# WARRIOR_ABILITIES §4.3: after armor 8, a block leaves 4.
	assert_eq(CombatMath.blocked_damage(8), 4)
	assert_eq(CombatMath.blocked_damage(7), 3)
