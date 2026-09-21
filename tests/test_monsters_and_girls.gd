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
	var types = ["spiky", "goggle", "fish_flyer", "armored_crab", "shaman", "thief", "boss_thorn_king"]
	for m_type in types:
		var monster = MonsterBase.new()
		monster.monster_type = m_type
		monster._load_monster_data()
		assert_gt(monster.max_health, 0.0, "Monster %s should have positive max_health" % m_type)
		assert_gt(monster.speed, 0.0, "Monster %s should have positive speed" % m_type)
		if m_type == "boss_thorn_king":
			assert_true(monster.is_boss, "boss_thorn_king should have is_boss = true")
		if m_type == "fish_flyer":
			assert_true(monster.is_flyer, "fish_flyer should have is_flyer = true")
		monster.free()
