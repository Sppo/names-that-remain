extends GutTest

## Regression reference for the frozen 3v3 control battle.
## Recorded from the code on 30 Oct 2026, before any work on the new combat model.
## A mismatch means observable behavior of the control battle changed. Do not update
## the expected values to make a refactor pass; find the change instead.
## Hero lines follow the same scripted policy as test_m11_lines.gd.

const SEEDS_FROM := 1
const SEEDS_TO := 20
const FOCUS_IDS: Array[String] = ["enemy-1", "enemy-2", "enemy-3"]
const TURN_LIMIT := 80
const ADVANCE_LIMIT := 16

const EXPECTED_OPENING := (
	"round=1 outcome=ONGOING prepared=none\n" +
	"queue=hero-2,enemy-2,enemy-3,hero-1,enemy-1,hero-3\n" +
	"hero-1 Воїн side=0 pos=1 speed=5 hp=20/20 acc=80 dodge=10 block=25 guard=0 cd={  } abilities=warrior_shield,warrior_guard,warrior_basic\n" +
	"hero-2 Мисливець side=0 pos=2 speed=8 hp=20/20 acc=90 dodge=15 block=0 guard=0 cd={  } abilities=hunter_shot,hunter_knife,hunter_basic\n" +
	"hero-3 Лікар side=0 pos=3 speed=3 hp=20/20 acc=70 dodge=5 block=0 guard=0 cd={  } abilities=doctor_heal,doctor_basic\n" +
	"enemy-1 Вартовий side=1 pos=1 speed=4 hp=16/16 acc=75 dodge=10 block=50 guard=0 cd={  } abilities=guard_strike,warrior_guard,guardian_basic\n" +
	"enemy-2 Культист side=1 pos=2 speed=7 hp=10/10 acc=80 dodge=20 block=0 guard=0 cd={  } abilities=cultist_arrow,cultist_rite,cultist_basic\n" +
	"enemy-3 Тіньокіготь side=1 pos=3 speed=6 hp=12/12 acc=85 dodge=15 block=0 guard=0 cd={  } abilities=shadowclaw_claws,shadowclaw_execute"
)
const EXPECTED_CATALOG := (
	"warrior_shield Удар щитом kind=STRIKE from=1-2 target=1-2 amount=6 finish=0@0 enemies=true cd=2\n" +
	"warrior_guard Прикрити kind=GUARD from=1-2 target=1-4 amount=10 finish=0@0 enemies=false cd=1\n" +
	"warrior_basic Базовий удар kind=STRIKE from=1-4 target=1-4 amount=3 finish=0@0 enemies=true cd=0\n" +
	"hunter_shot Постріл kind=STRIKE from=2-4 target=1-4 amount=5 finish=0@0 enemies=true cd=2\n" +
	"hunter_knife Ніж kind=STRIKE from=1-2 target=1-2 amount=4 finish=0@0 enemies=true cd=1\n" +
	"hunter_basic Базовий удар kind=STRIKE from=1-4 target=1-4 amount=3 finish=0@0 enemies=true cd=0\n" +
	"doctor_heal Лікування kind=HEAL from=3-4 target=1-4 amount=5 finish=0@0 enemies=false cd=2\n" +
	"doctor_basic Базовий удар kind=STRIKE from=1-4 target=1-4 amount=2 finish=0@0 enemies=true cd=0\n" +
	"guard_strike Удар kind=STRIKE from=1-2 target=1-2 amount=5 finish=0@0 enemies=true cd=1\n" +
	"guardian_basic Базовий удар kind=STRIKE from=1-4 target=1-4 amount=3 finish=0@0 enemies=true cd=0\n" +
	"cultist_arrow Стріла kind=STRIKE from=2-4 target=2-4 amount=4 finish=0@0 enemies=true cd=1\n" +
	"cultist_rite Обряд kind=RITE from=2-4 target=3-4 amount=14 finish=0@0 enemies=true cd=2\n" +
	"cultist_basic Базовий удар kind=STRIKE from=1-4 target=1-4 amount=3 finish=0@0 enemies=true cd=0\n" +
	"shadowclaw_claws Кігті kind=STRIKE from=1-4 target=1-4 amount=5 finish=0@0 enemies=true cd=0\n" +
	"shadowclaw_execute Добивання kind=STRIKE from=1-4 target=1-4 amount=5 finish=8@50 enemies=true cd=2"
)
const EXPECTED_LINES := {
	"enemy-1:1": "HEROES_VICTORIOUS|r13|3/0/0|turns=45|rng_calls=69|state=6270979245068364038|43dc0a44b37b5cc8",
	"enemy-1:2": "HEROES_VICTORIOUS|r6|20/10/0|turns=23|rng_calls=38|state=-4648642875329354158|ff249c7b4fb39e4c",
	"enemy-1:3": "HEROES_DEFEATED|r12|0/0/0|turns=40|rng_calls=64|state=-1718854582581656231|5186955aef39e28d",
	"enemy-1:4": "HEROES_DEFEATED|r7|0/0/0|turns=31|rng_calls=45|state=6701686281444170137|0736fe84577bb7b0",
	"enemy-1:5": "HEROES_DEFEATED|r7|0/0/0|turns=34|rng_calls=48|state=8021282487785134499|f378f2a52d2eedca",
	"enemy-1:6": "HEROES_DEFEATED|r9|0/0/0|turns=28|rng_calls=47|state=8541415440853393493|35ac2e84c3257bd0",
	"enemy-1:7": "HEROES_DEFEATED|r8|0/0/0|turns=31|rng_calls=50|state=575103497911466839|2221316f0ec92021",
	"enemy-1:8": "HEROES_VICTORIOUS|r11|3/0/0|turns=38|rng_calls=62|state=104263069178767976|8263facfc28cb25e",
	"enemy-1:9": "HEROES_VICTORIOUS|r10|16/0/0|turns=37|rng_calls=58|state=-5259400553207924727|c2e3f2cede87303f",
	"enemy-1:10": "HEROES_DEFEATED|r10|0/0/0|turns=34|rng_calls=55|state=-5096613854044328543|79860bae1bcc2eeb",
	"enemy-1:11": "HEROES_DEFEATED|r10|0/0/0|turns=40|rng_calls=60|state=-6567966819835846787|dfbcc0b4dae6a78e",
	"enemy-1:12": "HEROES_VICTORIOUS|r10|2/0/0|turns=35|rng_calls=57|state=3820894736568569773|bd2b1d5b5a116977",
	"enemy-1:13": "HEROES_VICTORIOUS|r8|2/0/0|turns=28|rng_calls=47|state=-2149204926806864996|d854ecc6bcc5eece",
	"enemy-1:14": "HEROES_DEFEATED|r9|0/0/0|turns=33|rng_calls=53|state=3634767896197487643|1a82d477c550a99d",
	"enemy-1:15": "HEROES_DEFEATED|r10|0/0/0|turns=32|rng_calls=53|state=4312557935638006612|b5db3a6dc66f014f",
	"enemy-1:16": "HEROES_VICTORIOUS|r12|2/0/0|turns=42|rng_calls=64|state=1361825594295049122|4ac54b7e319056cc",
	"enemy-1:17": "HEROES_DEFEATED|r9|0/0/0|turns=37|rng_calls=57|state=1602247995112211354|0a7ee622fba8b7e3",
	"enemy-1:18": "HEROES_DEFEATED|r8|0/0/0|turns=35|rng_calls=52|state=7669991499179518944|41ce2339e8b0691c",
	"enemy-1:19": "HEROES_DEFEATED|r9|0/0/0|turns=31|rng_calls=51|state=5431287314772284342|0d1d1f072ca1140c",
	"enemy-1:20": "HEROES_VICTORIOUS|r8|10/0/0|turns=28|rng_calls=47|state=5606918779242428131|91595cd0e52b253f",
	"enemy-2:1": "HEROES_VICTORIOUS|r6|20/15/0|turns=27|rng_calls=42|state=3629889001526608337|68c2b7e8db0e347b",
	"enemy-2:2": "HEROES_VICTORIOUS|r9|10/0/0|turns=31|rng_calls=53|state=-4498712577088739985|c2456b1242a95e32",
	"enemy-2:3": "HEROES_VICTORIOUS|r7|20/10/1|turns=32|rng_calls=51|state=-8352257650322241882|720a75616e026824",
	"enemy-2:4": "HEROES_DEFEATED|r10|0/0/0|turns=39|rng_calls=55|state=-6788611920267841957|15835bd8e3e8f215",
	"enemy-2:5": "HEROES_DEFEATED|r10|0/0/0|turns=39|rng_calls=56|state=2164628893972850475|e4de3f9a7040f2c4",
	"enemy-2:6": "HEROES_DEFEATED|r11|0/0/0|turns=37|rng_calls=61|state=7139444548077204955|c8dfeba777ea4434",
	"enemy-2:7": "HEROES_DEFEATED|r11|0/0/0|turns=42|rng_calls=64|state=7742928890477123085|d8b7acc60f6269ee",
	"enemy-2:8": "HEROES_DEFEATED|r9|0/0/0|turns=40|rng_calls=60|state=-3193084418071980442|1a6b15b467212ecb",
	"enemy-2:9": "HEROES_VICTORIOUS|r9|15/0/0|turns=36|rng_calls=57|state=-2226614848041435822|c43a74a786f70342",
	"enemy-2:10": "HEROES_DEFEATED|r10|0/0/0|turns=39|rng_calls=63|state=-5513210975909297943|a5f21f0b4e32adec",
	"enemy-2:11": "HEROES_VICTORIOUS|r12|15/0/0|turns=43|rng_calls=67|state=-3531766099181408770|0affcc402e0b7fd1",
	"enemy-2:12": "HEROES_DEFEATED|r10|0/0/0|turns=37|rng_calls=59|state=2273316132238771975|00f563467cdcf9c4",
	"enemy-2:13": "HEROES_VICTORIOUS|r6|20/15/5|turns=27|rng_calls=45|state=-1428804778133231238|5612342817609fec",
	"enemy-2:14": "HEROES_DEFEATED|r9|0/0/0|turns=34|rng_calls=53|state=3634767896197487643|63a4259e38cd97e8",
	"enemy-2:15": "HEROES_VICTORIOUS|r12|11/0/0|turns=43|rng_calls=69|state=4092404233867708836|1b70db2d5364597e",
	"enemy-2:16": "HEROES_DEFEATED|r12|0/0/0|turns=44|rng_calls=66|state=5657420849997789700|c5186428bc71ffaf",
	"enemy-2:17": "HEROES_VICTORIOUS|r7|20/15/8|turns=30|rng_calls=46|state=-6496782110204793691|363ffe3b9ff661e1",
	"enemy-2:18": "HEROES_VICTORIOUS|r15|2/0/0|turns=49|rng_calls=74|state=-4087850234268836906|cd27e105fd724372",
	"enemy-2:19": "HEROES_VICTORIOUS|r10|2/0/0|turns=36|rng_calls=57|state=-6663908330954152660|5bd4700f21a6c663",
	"enemy-2:20": "HEROES_DEFEATED|r8|0/0/0|turns=29|rng_calls=47|state=5606918779242428131|f06884e74ef44759",
	"enemy-3:1": "HEROES_VICTORIOUS|r10|20/1/0|turns=41|rng_calls=62|state=-4541397835589614875|a700939beb6433f8",
	"enemy-3:2": "HEROES_DEFEATED|r7|0/0/0|turns=31|rng_calls=45|state=4409185611637025639|bfa7a8b8fc5143d9",
	"enemy-3:3": "HEROES_DEFEATED|r9|0/0/0|turns=35|rng_calls=53|state=-3820922537648221016|8d75098ccbbdcc46",
	"enemy-3:4": "HEROES_VICTORIOUS|r12|2/0/0|turns=40|rng_calls=63|state=1916736114573716195|e04886fc422b074e",
	"enemy-3:5": "HEROES_DEFEATED|r10|0/0/0|turns=39|rng_calls=57|state=-4141046269618259410|140ed9c1c2277b9a",
	"enemy-3:6": "HEROES_VICTORIOUS|r12|8/0/0|turns=40|rng_calls=64|state=-3845889014642347552|894e02e851f1d6d5",
	"enemy-3:7": "HEROES_DEFEATED|r10|0/0/0|turns=36|rng_calls=57|state=6039541478024928192|d3323f4548ed3f72",
	"enemy-3:8": "HEROES_DEFEATED|r9|0/0/0|turns=39|rng_calls=60|state=-3193084418071980442|076621af613931d5",
	"enemy-3:9": "HEROES_DEFEATED|r9|0/0/0|turns=39|rng_calls=56|state=-1504841758701925025|16bc9bd6e55bf139",
	"enemy-3:10": "HEROES_DEFEATED|r11|0/0/0|turns=41|rng_calls=63|state=-5513210975909297943|dba726ac7236c81b",
	"enemy-3:11": "HEROES_VICTORIOUS|r10|20/2/0|turns=39|rng_calls=60|state=-6567966819835846787|435b6d4691ab574c",
	"enemy-3:12": "HEROES_DEFEATED|r11|0/0/0|turns=45|rng_calls=67|state=-7259744484568984305|623cffc1ab7ca442",
	"enemy-3:13": "HEROES_DEFEATED|r12|0/0/0|turns=42|rng_calls=65|state=-5493572225411977378|9a62e952211a0cd1",
	"enemy-3:14": "HEROES_DEFEATED|r15|0/0/0|turns=47|rng_calls=72|state=6427514288530908784|db1be8ec88620708",
	"enemy-3:15": "HEROES_DEFEATED|r16|0/0/0|turns=51|rng_calls=79|state=2012241032009510590|5cc03752c6f6a9cd",
	"enemy-3:16": "HEROES_VICTORIOUS|r13|13/0/0|turns=49|rng_calls=70|state=2964144055740521400|730b9d9e1dc365b6",
	"enemy-3:17": "HEROES_DEFEATED|r10|0/0/0|turns=43|rng_calls=62|state=806757354249674037|608f37827c00ad92",
	"enemy-3:18": "HEROES_DEFEATED|r14|0/0/0|turns=52|rng_calls=76|state=-8266338406957986472|d925a2edfb0d022c",
	"enemy-3:19": "HEROES_VICTORIOUS|r8|20/0/0|turns=33|rng_calls=53|state=7023718093400082488|0d0dc0eb79512285",
	"enemy-3:20": "HEROES_DEFEATED|r12|0/0/0|turns=46|rng_calls=69|state=679092576480396033|d7229410936fd1a7",
}
const EXPECTED_ANCHOR := (
	"T0 r1 hero-2 rng+2\n" +
	"  DAMAGE_APPLIED hunter_shot hero-2->enemy-2 amount=5 hp=5 listed=5 NONE\n" +
	"T1 r1 enemy-2 rng+2\n" +
	"  DAMAGE_APPLIED cultist_arrow enemy-2->hero-3 amount=4 hp=16 listed=4 NONE\n" +
	"T2 r1 enemy-3 rng+2\n" +
	"  DAMAGE_APPLIED shadowclaw_claws enemy-3->hero-3 amount=5 hp=11 listed=5 NONE\n" +
	"T3 r1 hero-1 rng+2\n" +
	"  DAMAGE_APPLIED warrior_shield hero-1->enemy-2 amount=5 hp=0 listed=6 NONE\n" +
	"  REMOVED_FROM_BATTLE enemy-2 side=1 pos=2\n" +
	"T4 r1 enemy-1 rng+2\n" +
	"  DAMAGE_APPLIED guard_strike enemy-1->hero-2 amount=5 hp=15 listed=5 NONE\n" +
	"T5 r1 hero-3 rng+0\n" +
	"  HEALED doctor_heal hero-3->hero-3 amount=5 hp=16\n" +
	"  ROUND_STARTED 2 [hero-2,enemy-3,hero-1,enemy-1,hero-3]\n" +
	"T6 r2 hero-2 rng+2\n" +
	"  DAMAGE_APPLIED hunter_knife hero-2->enemy-1 amount=2 hp=14 listed=4 BLOCK\n" +
	"T7 r2 enemy-3 rng+2\n" +
	"  DAMAGE_APPLIED shadowclaw_claws enemy-3->hero-3 amount=5 hp=11 listed=5 NONE\n" +
	"T8 r2 hero-1 rng+2\n" +
	"  DAMAGE_APPLIED warrior_basic hero-1->enemy-1 amount=1 hp=13 listed=3 BLOCK\n" +
	"T9 r2 enemy-1 rng+2\n" +
	"  DAMAGE_APPLIED guardian_basic enemy-1->hero-3 amount=3 hp=8 listed=3 NONE\n" +
	"T10 r2 hero-3 rng+1\n" +
	"  MISSED doctor_basic hero-3->enemy-1 amount=0"
)

var rules: CombatRules


func before_each() -> void:
	rules = CombatRules.new()


func test_opening_state_is_unchanged() -> void:
	var actual := _opening_snapshot(BattleSetup.create_opening_battle())
	if actual != EXPECTED_OPENING:
		print("GOLDEN_OPENING\n%s" % actual)
	assert_eq(actual, EXPECTED_OPENING)


func test_control_catalog_is_unchanged() -> void:
	var actual := _catalog_snapshot()
	if actual != EXPECTED_CATALOG:
		print("GOLDEN_CATALOG\n%s" % actual)
	assert_eq(actual, EXPECTED_CATALOG)


func test_three_lines_over_twenty_seeds_are_unchanged() -> void:
	var seen := 0
	for focus_id in FOCUS_IDS:
		for seed_value in range(SEEDS_FROM, SEEDS_TO + 1):
			var key := "%s:%d" % [focus_id, seed_value]
			var line := _play(focus_id, seed_value)
			if line["summary"] != str(EXPECTED_LINES.get(key, "")):
				print("GOLDEN_LINE \"%s\": \"%s\"," % [key, line["summary"]])
			assert_eq(line["summary"], str(EXPECTED_LINES.get(key, "")), key)
			seen += 1
	assert_eq(seen, FOCUS_IDS.size() * (SEEDS_TO - SEEDS_FROM + 1))


func test_seed_two_cultist_focus_opening_turns_read_the_same() -> void:
	var line := _play("enemy-2", 2)
	var lines: PackedStringArray = line["transcript"].split("\n")
	var head := "\n".join(lines.slice(0, 24))
	if head != EXPECTED_ANCHOR:
		print("GOLDEN_ANCHOR\n%s" % head)
	assert_eq(head, EXPECTED_ANCHOR)


func test_replaying_a_line_in_the_same_process_gives_the_same_record() -> void:
	for focus_id in FOCUS_IDS:
		var first := _play(focus_id, 7)
		var second := _play(focus_id, 7)
		assert_eq(second["transcript"], first["transcript"], focus_id)
		assert_eq(second["summary"], first["summary"], focus_id)


func test_every_control_turn_advances_the_generator_zero_to_two_times() -> void:
	for focus_id in FOCUS_IDS:
		for seed_value in range(SEEDS_FROM, SEEDS_TO + 1):
			var line := _play(focus_id, seed_value)
			for advances: int in line["advances"]:
				assert_between(advances, 0, 2, "%s:%d" % [focus_id, seed_value])


## Returns transcript, summary and per-turn generator advances for one scripted line.
func _play(focus_id: String, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var state := BattleSetup.create_opening_battle()
	var ai := EnemyAi.new(rules)
	var transcript := PackedStringArray()
	var advances: Array[int] = []
	var turns := 0
	while state.outcome == CombatState.Outcome.ONGOING and turns < TURN_LIMIT:
		var actor := _find(state, state.turn_queue[0])
		var before := rng.state
		var result: CombatResult
		if actor.side == CombatantState.Side.ENEMIES:
			result = ai.take_turn(state, rng)
		else:
			var command: Variant = _hero_command(state, focus_id)
			if command is AbilityCommand:
				result = rules.resolve_ability(command, state, rng)
			else:
				result = rules.resolve(command, state, rng)
		assert_true(result.accepted, "%s:%d turn %d" % [focus_id, seed_value, turns])
		var advanced := _advances_between(before, rng.state)
		advances.append(advanced)
		transcript.append("T%d r%d %s rng+%d" % [turns, state.round_number, actor.id, advanced])
		for event: CombatEvent in result.events:
			transcript.append("  " + _event_line(event))
		state = result.state
		turns += 1

	var joined := "\n".join(transcript)
	var total := 0
	for value in advances:
		total += value
	var summary := "%s|r%d|%d/%d/%d|turns=%d|rng_calls=%d|state=%d|%s" % [
		CombatState.Outcome.keys()[state.outcome],
		state.round_number,
		_hp_of(state, "hero-1"),
		_hp_of(state, "hero-2"),
		_hp_of(state, "hero-3"),
		turns,
		total,
		rng.state,
		joined.sha256_text().substr(0, 16),
	]
	return {"transcript": joined, "summary": summary, "advances": advances}


## Steps a copy of the generator from before until it reaches after.
func _advances_between(before: int, after: int) -> int:
	if before == after:
		return 0
	var probe := RandomNumberGenerator.new()
	probe.state = before
	for count in range(1, ADVANCE_LIMIT + 1):
		probe.randi()
		if probe.state == after:
			return count
	return -1


func _event_line(event: CombatEvent) -> String:
	var kind: String = CombatEvent.Kind.keys()[event.kind]
	match event.kind:
		CombatEvent.Kind.STEPPED:
			return "%s %s %d->%d" % [kind, event.actor_id, event.from_position, event.to_position]
		CombatEvent.Kind.SWAPPED:
			return "%s %s<->%s %d->%d" % [kind, event.actor_id, event.other_id, event.from_position, event.to_position]
		CombatEvent.Kind.REMOVED_FROM_BATTLE:
			return "%s %s side=%d pos=%d" % [kind, event.actor_id, event.side, event.from_position]
		CombatEvent.Kind.FORMATION_SHIFTED:
			var parts := PackedStringArray()
			for shift: PositionShift in event.shifts:
				parts.append("%s:%d->%d" % [shift.combatant_id, shift.from_position, shift.to_position])
			return "%s side=%d %s" % [kind, event.side, ",".join(parts)]
		CombatEvent.Kind.ROUND_STARTED:
			return "%s %d [%s]" % [kind, event.round_number, ",".join(event.turn_queue)]
		CombatEvent.Kind.BATTLE_ENDED:
			return "%s %s" % [kind, CombatState.Outcome.keys()[event.outcome]]
		CombatEvent.Kind.DAMAGE_APPLIED:
			return "%s %s %s->%s amount=%d hp=%d listed=%d %s" % [
				kind,
				event.ability_id,
				event.actor_id,
				event.other_id,
				event.amount,
				event.resulting_hp,
				event.listed_amount,
				CombatEvent.Mitigation.keys()[event.mitigation],
			]
		CombatEvent.Kind.HEALED:
			return "%s %s %s->%s amount=%d hp=%d" % [
				kind, event.ability_id, event.actor_id, event.other_id, event.amount, event.resulting_hp
			]
		_:
			return "%s %s %s->%s amount=%d" % [kind, event.ability_id, event.actor_id, event.other_id, event.amount]


func _opening_snapshot(state: CombatState) -> String:
	var lines := PackedStringArray()
	lines.append("round=%d outcome=%s prepared=%s" % [
		state.round_number,
		CombatState.Outcome.keys()[state.outcome],
		"none" if state.prepared == null else state.prepared.actor_id,
	])
	lines.append("queue=%s" % ",".join(state.turn_queue))
	for fighter: CombatantState in state.combatants:
		lines.append("%s %s side=%d pos=%d speed=%d hp=%d/%d acc=%d dodge=%d block=%d guard=%d cd=%s abilities=%s" % [
			fighter.id,
			fighter.display_name,
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
			",".join(AbilityCatalog.ids_for(fighter.id)),
		])
	return "\n".join(lines)


func _catalog_snapshot() -> String:
	var ids: Array[String] = []
	for fighter_id in ["hero-1", "hero-2", "hero-3", "enemy-1", "enemy-2", "enemy-3"]:
		for ability_id: String in AbilityCatalog.ids_for(fighter_id):
			if not ids.has(ability_id):
				ids.append(ability_id)
	var lines := PackedStringArray()
	for ability_id in ids:
		var ability := AbilityCatalog.definition(ability_id)
		lines.append("%s %s kind=%s from=%d-%d target=%d-%d amount=%d finish=%d@%d enemies=%s cd=%d" % [
			ability.id,
			ability.label,
			AbilityDefinition.Kind.keys()[ability.kind],
			ability.from_min,
			ability.from_max,
			ability.target_min,
			ability.target_max,
			ability.amount,
			ability.finish_amount,
			ability.finish_below_percent,
			str(ability.hits_enemies),
			ability.cooldown_turns,
		])
	return "\n".join(lines)


func _hero_command(state: CombatState, preferred_id: String) -> Variant:
	var actor := _find(state, state.turn_queue[0])
	if actor.id == "hero-3":
		var patient := _most_wounded_hero(state)
		var heal := _ability(actor.id, "doctor_heal", patient.id)
		if rules.validate_ability(heal, state) == CombatResult.Rejection.NONE:
			return heal
	for target_id: String in _focus_order(preferred_id):
		var strike := _legal_strike(state, actor, target_id)
		if strike != null:
			return strike
	var destination := actor.position - 1
	if actor.id == "hero-2" and actor.position < 2:
		destination = actor.position + 1
	if actor.id == "hero-1" and actor.position > 2:
		destination = actor.position - 1
	if actor.id == "hero-3":
		destination = actor.position + 1
	return _step_toward(state, actor, destination)


func _focus_order(preferred_id: String) -> Array[String]:
	var order: Array[String] = [preferred_id]
	for enemy_id: String in ["enemy-1", "enemy-2", "enemy-3"]:
		if enemy_id != preferred_id:
			order.append(enemy_id)
	return order


func _legal_strike(state: CombatState, actor: CombatantState, target_id: String) -> AbilityCommand:
	var target := _find(state, target_id)
	if target == null or target.hp <= 0:
		return null
	for ability_id: String in AbilityCatalog.ids_for(actor.id):
		var ability := AbilityCatalog.definition(ability_id)
		if ability == null or ability.kind != AbilityDefinition.Kind.STRIKE:
			continue
		var command := _ability(actor.id, ability_id, target_id)
		if rules.validate_ability(command, state) == CombatResult.Rejection.NONE:
			return command
	return null


func _most_wounded_hero(state: CombatState) -> CombatantState:
	var chosen: CombatantState = null
	for combatant: CombatantState in state.combatants:
		if combatant.side != CombatantState.Side.HEROES or combatant.hp <= 0:
			continue
		if chosen == null or combatant.hp < chosen.hp or (
			combatant.hp == chosen.hp and combatant.position < chosen.position
		):
			chosen = combatant
	return chosen


func _step_toward(state: CombatState, actor: CombatantState, destination: int) -> StepCommand:
	var command := _step(actor.id, destination)
	if rules.validate(command, state) == CombatResult.Rejection.NONE:
		return command
	var fallback := actor.position + 1 if destination < actor.position else actor.position - 1
	return _step(actor.id, fallback)


func _hp_of(state: CombatState, id: String) -> int:
	var combatant := _find(state, id)
	if combatant == null:
		return 0
	return combatant.hp


func _ability(actor_id: String, ability_id: String, target_id: String) -> AbilityCommand:
	var command := AbilityCommand.new()
	command.actor_id = actor_id
	command.ability_id = ability_id
	command.target_id = target_id
	return command


func _step(actor_id: String, destination: int) -> StepCommand:
	var command := StepCommand.new()
	command.actor_id = actor_id
	command.destination_position = destination
	return command


func _find(state: CombatState, id: String) -> CombatantState:
	for combatant: CombatantState in state.combatants:
		if combatant.id == id:
			return combatant
	return null
