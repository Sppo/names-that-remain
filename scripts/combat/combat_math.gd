class_name CombatMath
extends RefCounted

## Target-model formulas from docs/STARTING_ABILITIES_DETAILS.md, §3. Static, no state, no rolls.
## Not connected to the battle, preview or AI yet.
##
## Everything is whole-number arithmetic, so halves round exactly:
## - stats are hundredths of a point: 3.5 ARM is 350;
## - percents and multipliers are whole percent: +30% is 30, ×1.30 is 130;
## - weighted stat P is ten-thousandths: 4.8 is 48000.
##
## A function that can fail returns an int on success and null on failure.
## Failure is input outside the formulas' domain or a step that would overflow a 64-bit int.
## Every failure is reported with push_error. Callers must check for null before using the value.

const INT_MAX: int = 9223372036854775807
const INT_MIN: int = -INT_MAX - 1

## One stat point in stat_x100 units.
const STAT_ONE: int = 100

## One point of P in weighted-stat units.
const WEIGHTED_ONE: int = 10000

const CATEGORY_MIN_PERCENT: int = -60
const CATEGORY_MAX_PERCENT: int = 100
const HIT_CHANCE_MIN: int = 5
const HIT_CHANCE_MAX: int = 95
const BLOCK_CHANCE_MAX: int = 95


## Nearest whole number, halves up. Only for numerator >= 0 and denominator > 0. Cannot overflow.
static func round_half_up(numerator: int, denominator: int) -> Variant:
	if denominator <= 0:
		return _fail("round_half_up", "denominator must be above 0, got %d" % denominator)
	if numerator < 0:
		return _fail("round_half_up", "numerator must not be negative, got %d" % numerator)
	return _round_half_up(numerator, denominator)


## Multiplier of one percent category in whole percent: the summed bonuses are capped to −60…+100 once.
static func category_multiplier_percent(total_percent: int) -> int:
	return 100 + clampi(total_percent, CATEGORY_MIN_PERCENT, CATEGORY_MAX_PERCENT)


## (base + flat) × (1 + capped percent), in hundredths of a point, without rounding.
static func effective_stat_x100(base: int, flat: int, total_percent: int) -> Variant:
	var name := "effective_stat_x100"
	if base < 0:
		return _fail(name, "base %d must not be negative" % base)
	var points: Variant = _sum(name, [base, flat])
	if points == null:
		return null
	if points < 0:
		return _fail(name, "base %d with flat %d is negative" % [base, flat])
	return _product(name, [points, category_multiplier_percent(total_percent)])


## max(1, round_half_up(BaseHP + 2 × (HEALTH − 3))), rounded once after the whole sum.
static func max_hp(base_hp: int, health_x100: int) -> Variant:
	var name := "max_hp"
	if base_hp < 0 or health_x100 < 0:
		return _fail(name, "base_hp %d and health_x100 %d must not be negative" % [base_hp, health_x100])
	var base_part: Variant = _product(name, [base_hp, STAT_ONE])
	var health_part: Variant = _product(name, [2, health_x100 - 3 * STAT_ONE])
	if base_part == null or health_part == null:
		return null
	var hp_x100: Variant = _sum(name, [base_part, health_part])
	if hp_x100 == null:
		return null
	if hp_x100 <= 0:
		return 1
	return maxi(1, _round_half_up(hp_x100, STAT_ONE))


## Current HP after the maximum changes: only cut down, never healed.
static func current_hp_after_max_change(current_hp: int, new_max_hp: int) -> Variant:
	if current_hp < 0 or new_max_hp < 1:
		return _fail("current_hp_after_max_change", "current %d, max %d" % [current_hp, new_max_hp])
	return mini(current_hp, new_max_hp)


## P = STR × wSTR + DEX × wDEX + KNO × wKNO, in ten-thousandths.
## Shares are whole percent and sum to 100. All shares 0 means no stat scaling: returns the neutral P = 3.
static func weighted_stat_x10000(
	strength_x100: int,
	dexterity_x100: int,
	knowledge_x100: int,
	strength_percent: int,
	dexterity_percent: int,
	knowledge_percent: int
) -> Variant:
	var name := "weighted_stat_x10000"
	if strength_x100 < 0 or dexterity_x100 < 0 or knowledge_x100 < 0:
		return _fail(name, "stats must not be negative")
	if strength_percent < 0 or dexterity_percent < 0 or knowledge_percent < 0:
		return _fail(name, "shares must not be negative")
	if strength_percent > 100 or dexterity_percent > 100 or knowledge_percent > 100:
		return _fail(name, "a share is above 100")
	var share_sum := strength_percent + dexterity_percent + knowledge_percent
	if share_sum == 0:
		return 3 * WEIGHTED_ONE
	if share_sum != 100:
		return _fail(name, "shares sum to %d, not 100" % share_sum)
	var strength_part: Variant = _product(name, [strength_x100, strength_percent])
	var dexterity_part: Variant = _product(name, [dexterity_x100, dexterity_percent])
	var knowledge_part: Variant = _product(name, [knowledge_x100, knowledge_percent])
	if strength_part == null or dexterity_part == null or knowledge_part == null:
		return null
	return _sum(name, [strength_part, dexterity_part, knowledge_part])


## round_half_up(B × A × M(P) × M_dealt × M_received), M(P) = 1 + (P − 3) / (P + 7).
## Whole damage before armor, block and cover. Special damage stops here.
## multiplier_percent is A; the two modifiers are category multipliers, 100 meaning ×1.
static func damage_before_armor(
	base: int,
	multiplier_percent: int,
	weighted_x10000: int,
	dealt_multiplier_percent: int,
	received_multiplier_percent: int
) -> Variant:
	var name := "damage_before_armor"
	if base < 0 or multiplier_percent < 0 or weighted_x10000 < 0:
		return _fail(name, "base, multiplier and P must not be negative")
	if dealt_multiplier_percent < 0 or received_multiplier_percent < 0:
		return _fail(name, "modifiers must not be negative")
	return _scaled_amount(
		name,
		base,
		multiplier_percent,
		weighted_x10000,
		dealt_multiplier_percent,
		received_multiplier_percent
	)


## Physical damage after armor: D × 20 / (ARM + 20), halves up, at least 1 when D > 0. 0 stays 0.
static func damage_after_armor(damage: int, armor_x100: int) -> Variant:
	var name := "damage_after_armor"
	if damage < 0 or armor_x100 < 0:
		return _fail(name, "damage %d and armor_x100 %d must not be negative" % [damage, armor_x100])
	if damage == 0:
		return 0
	var numerator: Variant = _product(name, [damage, 20 * STAT_ONE])
	var denominator: Variant = _sum(name, [armor_x100, 20 * STAT_ONE])
	if numerator == null or denominator == null:
		return null
	return maxi(1, _round_half_up(numerator, denominator))


## A successful block halves the damage and drops the fraction.
static func blocked_damage(damage: int) -> Variant:
	if damage < 0:
		return _fail("blocked_damage", "damage %d must not be negative" % damage)
	return damage / 2


## Cover takes up to its amount, never below 0.
static func damage_after_guard(damage: int, guard: int) -> Variant:
	if damage < 0 or guard < 0:
		return _fail("damage_after_guard", "damage %d and guard %d must not be negative" % [damage, guard])
	return maxi(0, damage - guard)


## BaseAccuracy + 2 × (DEX − 3) + bonus points, in hundredths. Not clamped on its own and may be negative.
static func accuracy_x100(base_accuracy: int, dexterity_x100: int, bonus_points: int) -> Variant:
	return _derived_x100("accuracy_x100", base_accuracy, dexterity_x100, 2, bonus_points)


## BaseDodge + (DEX − 3) + bonus points, in hundredths. Not clamped on its own and may be negative.
static func dodge_x100(base_dodge: int, dexterity_x100: int, bonus_points: int) -> Variant:
	return _derived_x100("dodge_x100", base_dodge, dexterity_x100, 1, bonus_points)


## round_half_up(clamp(Accuracy − Dodge, 5, 95)) in whole percent. Any accuracy and dodge are valid.
static func hit_chance(accuracy_value_x100: int, dodge_value_x100: int) -> int:
	var low := HIT_CHANCE_MIN * STAT_ONE
	var high := HIT_CHANCE_MAX * STAT_ONE
	var raw := 0
	# The difference of two extreme ints may not fit; such a pair is already past one of the bounds.
	if dodge_value_x100 < 0 and accuracy_value_x100 > INT_MAX + dodge_value_x100:
		raw = high
	elif dodge_value_x100 > 0 and accuracy_value_x100 < INT_MIN + dodge_value_x100:
		raw = low
	else:
		raw = clampi(accuracy_value_x100 - dodge_value_x100, low, high)
	return _round_half_up(raw, STAT_ONE)


## Base block plus bonus points, capped at 95.
static func block_chance(base_block: int, bonus_points: int) -> Variant:
	var name := "block_chance"
	if base_block < 0:
		return _fail(name, "base %d must not be negative" % base_block)
	var total: Variant = _sum(name, [base_block, bonus_points])
	if total == null:
		return null
	if total < 0:
		return _fail(name, "base %d with bonus %d is negative" % [base_block, bonus_points])
	return mini(BLOCK_CHANCE_MAX, total)


## round_half_up(BaseHeal × A × M(KNO) × M_done × M_received). No roll and no minimum of 1.
static func heal_amount(
	base_heal: int,
	multiplier_percent: int,
	knowledge_x100: int,
	done_multiplier_percent: int,
	received_multiplier_percent: int
) -> Variant:
	var name := "heal_amount"
	if base_heal < 0 or multiplier_percent < 0 or knowledge_x100 < 0:
		return _fail(name, "base, multiplier and knowledge_x100 must not be negative")
	if done_multiplier_percent < 0 or received_multiplier_percent < 0:
		return _fail(name, "modifiers must not be negative")
	var weighted: Variant = _product(name, [knowledge_x100, 100])
	if weighted == null:
		return null
	return _scaled_amount(
		name,
		base_heal,
		multiplier_percent,
		weighted,
		done_multiplier_percent,
		received_multiplier_percent
	)


## HP actually restored: max(0, min(heal, MaxHP − CurrentHP)). Never lowers HP.
static func restored_hp(heal: int, current_hp: int, max_hp_value: int) -> Variant:
	if heal < 0 or current_hp < 0 or max_hp_value < 0:
		return _fail("restored_hp", "heal %d, current %d, max %d" % [heal, current_hp, max_hp_value])
	return maxi(0, mini(heal, max_hp_value - current_hp))


## Shared product of damage and healing. Inputs are already checked as non-negative.
static func _scaled_amount(
	name: String,
	base: int,
	multiplier_percent: int,
	weighted_x10000: int,
	first_modifier_percent: int,
	second_modifier_percent: int
) -> Variant:
	# M(P) = (2P + 4) / (P + 7), both parts in weighted units.
	var doubled: Variant = _product(name, [2, weighted_x10000])
	var scaling_numerator: Variant = null
	if doubled != null:
		scaling_numerator = _sum(name, [doubled, 4 * WEIGHTED_ONE])
	var scaling_denominator: Variant = _sum(name, [weighted_x10000, 7 * WEIGHTED_ONE])
	if scaling_numerator == null or scaling_denominator == null:
		return null
	var numerator: Variant = _product(name, [
		base,
		multiplier_percent,
		scaling_numerator,
		first_modifier_percent,
		second_modifier_percent,
	])
	var denominator: Variant = _product(name, [100, scaling_denominator, 100, 100])
	if numerator == null or denominator == null:
		return null
	return _round_half_up(numerator, denominator)


## base + factor × (DEX − 3) + bonus, in hundredths. The base and DEX must not be negative; the result may be.
static func _derived_x100(name: String, base: int, dexterity_x100: int, factor: int, bonus_points: int) -> Variant:
	if base < 0 or dexterity_x100 < 0:
		return _fail(name, "base %d and dexterity_x100 %d must not be negative" % [base, dexterity_x100])
	var base_part: Variant = _product(name, [base, STAT_ONE])
	var dexterity_part: Variant = _product(name, [factor, dexterity_x100 - 3 * STAT_ONE])
	var bonus_part: Variant = _product(name, [bonus_points, STAT_ONE])
	if base_part == null or dexterity_part == null or bonus_part == null:
		return null
	return _sum(name, [base_part, dexterity_part, bonus_part])


## numerator >= 0, denominator > 0. Quotient and remainder keep it free of overflow.
static func _round_half_up(numerator: int, denominator: int) -> int:
	var quotient := numerator / denominator
	var remainder := numerator % denominator
	if remainder >= denominator - remainder:
		quotient += 1
	return quotient


## Product of ints, or null with an error when a step would not fit in 64 bits.
static func _product(name: String, factors: Array) -> Variant:
	var result := 1
	for factor: int in factors:
		if not _times_fits(result, factor):
			return _fail(name, "the product overflows a 64-bit int")
		result *= factor
	return result


## Sum of ints, or null with an error when a step would not fit in 64 bits.
static func _sum(name: String, terms: Array) -> Variant:
	var result := 0
	for term: int in terms:
		if (term > 0 and result > INT_MAX - term) or (term < 0 and result < INT_MIN - term):
			return _fail(name, "the sum overflows a 64-bit int")
		result += term
	return result


## True when a × b fits in a 64-bit int. Checked by division before multiplying.
static func _times_fits(a: int, b: int) -> bool:
	if a == 0 or b == 0:
		return true
	if a > 0:
		if b > 0:
			return a <= INT_MAX / b
		return b >= INT_MIN / a
	if b > 0:
		return a >= INT_MIN / b
	return a >= INT_MAX / b


static func _fail(name: String, message: String) -> Variant:
	push_error("CombatMath.%s: %s" % [name, message])
	return null
