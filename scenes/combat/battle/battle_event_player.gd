class_name BattleEventPlayer
extends Node

## Plays the events of one accepted result in order: a log line, then a short visual reaction.
## It reads events only; the scene matches the view to the controller state afterwards.
## Every wait checks that the scene is still showing the same battle, so a restart or exit stops it cleanly.

@export var step_seconds := 0.45


## False when the scene left the tree or restarted while playing.
func play(result: CombatResult, view: BattleScene, generation: int) -> bool:
	for event: CombatEvent in result.events:
		if not view.is_current(generation):
			return false
		var line := describe(event, view)
		if line != "":
			view.hud.add_log(line)
		var shown := _show(event, view)
		if shown and not await _hold(view, generation):
			return false
	return view.is_current(generation)


func _show(event: CombatEvent, view: BattleScene) -> bool:
	var move_seconds := step_seconds * 0.8
	match event.kind:
		CombatEvent.Kind.DAMAGE_APPLIED:
			var target := view.unit_of(event.other_id)
			if target != null:
				target.show_current_hp(event.resulting_hp)
				target.float_text("−%d%s" % [event.amount, _mitigation_word(event.mitigation)], Color(1, 0.45, 0.4), step_seconds)
			return true
		CombatEvent.Kind.MISSED:
			var missed := view.unit_of(event.other_id)
			if missed != null:
				missed.float_text("промах", Color(0.85, 0.85, 0.85), step_seconds)
			return true
		CombatEvent.Kind.HEALED:
			var healed := view.unit_of(event.other_id)
			if healed != null:
				healed.show_current_hp(event.resulting_hp)
				healed.float_text("+%d" % event.amount, Color(0.5, 0.95, 0.55), step_seconds)
			return true
		CombatEvent.Kind.GUARD_PLACED:
			var guarded := view.unit_of(event.other_id)
			if guarded != null:
				guarded.float_text("прикрито", Color(0.7, 0.8, 1), step_seconds)
			return true
		CombatEvent.Kind.EFFECT_APPLIED:
			var affected := view.unit_of(event.other_id)
			if affected != null:
				affected.float_text(CombatUnit.EFFECT_NAMES.get(event.effect_id, event.effect_id), Color(0.95, 0.85, 0.5), step_seconds)
			return true
		CombatEvent.Kind.STEPPED:
			var stepper := view.unit_of(event.actor_id)
			if stepper != null:
				stepper.move_to(view.slot_position(view.side_of(event.actor_id), event.to_position), move_seconds)
			return true
		CombatEvent.Kind.SWAPPED:
			var side := view.side_of(event.actor_id)
			var mover := view.unit_of(event.actor_id)
			var other := view.unit_of(event.other_id)
			if mover != null:
				mover.move_to(view.slot_position(side, event.to_position), move_seconds)
			if other != null:
				other.move_to(view.slot_position(side, event.from_position), move_seconds)
			return true
		CombatEvent.Kind.FORMATION_SHIFTED:
			for shift: PositionShift in event.shifts:
				var shifted := view.unit_of(shift.combatant_id)
				if shifted != null:
					shifted.move_to(view.slot_position(event.side, shift.to_position), move_seconds)
			return true
		CombatEvent.Kind.REMOVED_FROM_BATTLE:
			var removed := view.unit_of(event.actor_id)
			if removed != null:
				removed.show_removed(step_seconds)
			return true
		CombatEvent.Kind.PREPARED_STRIKE, CombatEvent.Kind.TURN_PASSED:
			var actor := view.unit_of(event.actor_id)
			if actor != null:
				actor.float_text("обряд" if event.kind == CombatEvent.Kind.PREPARED_STRIKE else "пропуск", Color(0.8, 0.7, 1), step_seconds)
			return true
	return false


## One log line in Ukrainian. Empty for events that need no line.
func describe(event: CombatEvent, view: BattleScene) -> String:
	var actor := view.name_of(event.actor_id)
	var other := view.name_of(event.other_id)
	match event.kind:
		CombatEvent.Kind.DAMAGE_APPLIED:
			return "%s: %s → %s, −%d%s (HP %d)" % [actor, _ability(event.ability_id), other, event.amount, _mitigation_word(event.mitigation), event.resulting_hp]
		CombatEvent.Kind.MISSED:
			return "%s: %s → %s, промах" % [actor, _ability(event.ability_id), other]
		CombatEvent.Kind.HEALED:
			return "%s лікує %s: +%d (HP %d)" % [actor, other, event.amount, event.resulting_hp]
		CombatEvent.Kind.GUARD_PLACED:
			return "%s прикриває %s" % [actor, other]
		CombatEvent.Kind.PREPARED_STRIKE:
			return "%s готує обряд на %s" % [actor, other]
		CombatEvent.Kind.PREPARED_STRIKE_CANCELLED:
			return "Обряд %s скасовано" % actor
		CombatEvent.Kind.EFFECT_APPLIED:
			return "%s: %s %+d на %d ходи" % [other, CombatUnit.EFFECT_NAMES.get(event.effect_id, event.effect_id), event.amount, event.resulting_hp]
		CombatEvent.Kind.EFFECT_EXPIRED:
			return "%s: %s завершився" % [actor, CombatUnit.EFFECT_NAMES.get(event.effect_id, event.effect_id)]
		CombatEvent.Kind.STEPPED:
			return "%s переходить на позицію %d" % [actor, event.to_position]
		CombatEvent.Kind.SWAPPED:
			return "%s міняється місцями з %s" % [actor, other]
		CombatEvent.Kind.FORMATION_SHIFTED:
			var moves := PackedStringArray()
			for shift: PositionShift in event.shifts:
				moves.append("%s %d→%d" % [view.name_of(shift.combatant_id), shift.from_position, shift.to_position])
			return "Поштовх: %s" % ", ".join(moves)
		CombatEvent.Kind.REMOVED_FROM_BATTLE:
			return "%s вибуває з бою" % actor
		CombatEvent.Kind.TURN_PASSED:
			return "%s пропускає хід" % actor
		CombatEvent.Kind.ROUND_STARTED:
			return "— Раунд %d —" % event.round_number
		CombatEvent.Kind.BATTLE_ENDED:
			return view.outcome_sentence(event.outcome)
	return ""


func _hold(view: BattleScene, generation: int) -> bool:
	if step_seconds <= 0.0:
		return view.is_current(generation)
	await get_tree().create_timer(step_seconds).timeout
	return is_instance_valid(view) and view.is_current(generation)


func _ability(ability_id: String) -> String:
	var ability := AbilityCatalog.definition(ability_id)
	return ability.label if ability != null else ability_id


func _mitigation_word(mitigation: CombatEvent.Mitigation) -> String:
	match mitigation:
		CombatEvent.Mitigation.BLOCK:
			return ", блок"
		CombatEvent.Mitigation.GUARD:
			return ", прикрито"
		CombatEvent.Mitigation.BLOCK_AND_GUARD:
			return ", блок і прикрито"
	return ""
