class_name BattleController
extends RefCounted

## Runs one battle without any node or graphics. Owns the generator, the rules and the enemy AI.
## The scene sends player commands and asks for enemy turns; it shows the results and never decides them.
## A rejected enemy command puts the controller into an explicit failed state, and it stops playing.

var state: CombatState
var failed: bool
var failure: CombatResult.Rejection

var _rules: CombatRules
var _ai: EnemyAi
var _rng: RandomNumberGenerator


func _init() -> void:
	state = null
	failed = false
	failure = CombatResult.Rejection.NONE
	_rules = CombatRules.new()
	_ai = EnemyAi.new(_rules)
	_rng = RandomNumberGenerator.new()


func start(battle: CombatState, seed_value: int) -> void:
	state = battle
	failed = false
	failure = CombatResult.Rejection.NONE
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed_value


func active() -> CombatantState:
	if state == null or state.turn_queue.is_empty():
		return null
	for fighter: CombatantState in state.combatants:
		if fighter.id == state.turn_queue[0]:
			return fighter
	return null


func is_player_turn() -> bool:
	if state == null or failed or state.outcome != CombatState.Outcome.ONGOING:
		return false
	var fighter := active()
	return fighter != null and fighter.side == CombatantState.Side.HEROES


## AbilityCommand, StepCommand or PassCommand from the player. Only on a hero's turn.
func submit(command: Variant) -> CombatResult:
	if not is_player_turn():
		return CombatResult.rejected(state, CombatResult.Rejection.NOT_ACTIVE_TURN)
	var result: CombatResult = null
	if command is AbilityCommand:
		result = _rules.resolve_ability(command, state, _rng)
	elif command is StepCommand:
		result = _rules.resolve(command, state, _rng)
	elif command is PassCommand:
		result = _rules.resolve_pass(command, state, _rng)
	else:
		push_error("BattleController.submit: unsupported command %s" % str(command))
		return CombatResult.rejected(state, CombatResult.Rejection.UNKNOWN_ACTOR)
	if result.accepted:
		state = result.state
	return result


## One turn of the active enemy through EnemyAi.
func advance_enemy() -> CombatResult:
	var fighter := active()
	if failed or state.outcome != CombatState.Outcome.ONGOING or fighter == null or fighter.side != CombatantState.Side.ENEMIES:
		return CombatResult.rejected(state, CombatResult.Rejection.NOT_ACTIVE_TURN)
	var result := _ai.take_turn(state, _rng)
	if result.accepted:
		state = result.state
	else:
		failed = true
		failure = result.rejection
	return result


## For tests: the generator state, so a test can prove the view never rolls it.
func rng_state() -> int:
	return _rng.state
