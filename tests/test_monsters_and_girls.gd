class_name TestMonstersAndGirls
extends TestBase

func test_girl_initial_state() -> void:
	var girl = GirlNPC.new()
	girl.position = Vector2(100, 100)
	girl.home_position = Vector2(100, 100)
	
	assert_eq(girl.current_state, GirlNPC.State.IN_VILLAGE, "Girl should start in IN_VILLAGE state")
	assert_null(girl.carrier_monster, "Girl should not have carrier monster initially")
	girl.free()

func test_girl_kidnapped_and_rescue_flow() -> void:
	var girl = GirlNPC.new()
	girl.position = Vector2(100, 100)
	girl.home_position = Vector2(100, 100)
	
	var monster = MonsterBase.new()
	monster.position = Vector2(100, 100)
	
	var kidnapped_emitted = [false]
	girl.kidnapped.connect(func(_g): kidnapped_emitted[0] = true)
	
	# Monster kidnaps girl
	girl.get_kidnapped_by(monster)
	assert_eq(girl.current_state, GirlNPC.State.BEING_CARRIED, "Girl state should be BEING_CARRIED")
	assert_eq(girl.carrier_monster, monster, "Girl carrier should be monster")
	assert_true(kidnapped_emitted[0], "kidnapped signal should be emitted")
	
	# Monster dies -> Girl runs home
	girl._start_running_home()
	assert_eq(girl.current_state, GirlNPC.State.RUNNING_HOME, "Girl state should be RUNNING_HOME")
	assert_null(girl.carrier_monster, "Carrier monster should be nullified")
	
	# Girl reaches home
	var rescued_emitted = [false]
	girl.rescued.connect(func(_g): rescued_emitted[0] = true)
	girl.global_position = Vector2(100, 100)
	girl.home_position = Vector2(100, 100)
	girl._process_running_home(0.1)
	assert_eq(girl.current_state, GirlNPC.State.IN_VILLAGE, "Girl should return to IN_VILLAGE state")
	assert_true(rescued_emitted[0], "rescued signal should be emitted")
	
	girl.free()
	monster.free()

func test_monster_database_types_instantiation() -> void:
	var types = [
		"grunt", "berserker", "armored", "shaman", "troll", "stealth",
		"warchief_boss", "archmage_boss", "fish_mosquito", "windwing",
		"shadow_wolf", "carapace_beetle", "stone_golem", "iron_guard",
		"flying_pumpkin", "spore_flyer", "carrion_griffin", "splitter",
		"frost_orc", "exploding_troll"
	]
	var flyers = ["windwing", "flying_pumpkin", "spore_flyer", "carrion_griffin"]
	var stealths = ["stealth", "shadow_wolf"]
	
	for m_type in types:
		var monster = MonsterBase.new()
		monster.monster_type = m_type
		monster._load_enemy_data()
		assert_gt(monster.max_health, 0.0, "Monster %s should have positive max_health" % m_type)
		assert_gt(monster.speed, 0.0, "Monster %s should have positive speed" % m_type)
		if m_type == "warchief_boss" or m_type == "archmage_boss":
			assert_true(monster.is_boss, "%s should have is_boss = true" % m_type)
		if flyers.has(m_type):
			assert_true(monster.is_flyer, "%s should have is_flyer = true" % m_type)
		if stealths.has(m_type):
			assert_true(monster.is_stealth, "%s should have is_stealth = true" % m_type)
		monster.free()


func test_enemy_outcome_lifecycle_killed() -> void:
	var monster = MonsterBase.new()
	monster.monster_type = "grunt"
	monster._load_enemy_data()
	
	var finished_outcome = []
	monster.finished.connect(func(outcome, _reward): finished_outcome.append(outcome))
	
	monster._finish_enemy(MonsterBase.EnemyOutcome.KILLED)
	assert_eq(finished_outcome.size(), 1, "finished signal must emit exactly once")
	assert_eq(finished_outcome[0], MonsterBase.EnemyOutcome.KILLED, "Outcome should be KILLED")

func test_enemy_outcome_lifecycle_reached_base() -> void:
	var monster = MonsterBase.new()
	monster.monster_type = "berserker"
	monster._load_enemy_data()
	
	var finished_outcome = []
	monster.finished.connect(func(outcome, _reward): finished_outcome.append(outcome))
	
	monster._finish_enemy(MonsterBase.EnemyOutcome.REACHED_BASE)
	assert_eq(finished_outcome.size(), 1, "finished signal must emit when reaching base")
	assert_eq(finished_outcome[0], MonsterBase.EnemyOutcome.REACHED_BASE, "Outcome should be REACHED_BASE")

