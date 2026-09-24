class_name TestEconomyChaptersAndEvolutions
extends TestBase

const WorldMapClass = preload("res://scripts/world_map.gd")

func test_5_chapters_and_stages() -> void:
	var wm_configs = WorldMapClass.MAP_CONFIGS
	assert_eq(wm_configs.size(), 5, "World map must define exactly 5 chapters")
	
	var expected_chapters = ["valley", "swamp", "caves", "frost_peak", "besieged_citadel"]
	var total_stages = 0
	
	for i in range(expected_chapters.size()):
		var ch_id = expected_chapters[i]
		assert_true(wm_configs.has(ch_id), "Chapter '%s' must exist" % ch_id)
		var conf = wm_configs[ch_id]
		assert_eq(int(conf.get("chapter_num", 0)), i + 1, "Chapter '%s' number mismatch" % ch_id)
		
		var stages = conf.get("stages", [])
		assert_true(stages is Array, "Chapter '%s' stages must be an Array" % ch_id)
		var count = stages.size()
		assert_ge(count, 8, "Chapter '%s' must have at least 8 stages (has %d)" % [ch_id, count])
		assert_le(count, 15, "Chapter '%s' must have at most 15 stages (has %d)" % [ch_id, count])
		total_stages += count
		
		# Verify each stage schema
		for s_idx in range(stages.size()):
			var st = stages[s_idx]
			assert_eq(int(st.get("stage", 0)), s_idx + 1, "Stage index mismatch in chapter '%s'" % ch_id)
			assert_gt(str(st.get("name", "")).length(), 0, "Stage name must not be empty")
			assert_gt(int(st.get("waves", 0)), 0, "Stage waves must be > 0")

	assert_eq(total_stages, 59, "Total stages across 5 chapters must be 59 (10+10+12+12+15)")

func test_tower_gating_by_chapter() -> void:
	var t = TowerBase.new()
	t.tower_type = "archer"
	t.current_level = 3
	t.max_level = 4
	t.upgrade_cost = 140
	
	# Fallback returns 5 when chapter is unset (0)
	GlobalState.current_chapter = 0
	assert_eq(t.get_chapter_max_level(), 5)
	
	# Chapter 1 gating (max level 3)
	GlobalState.current_chapter = 1
	assert_eq(t.get_chapter_max_level(), 3)
	assert_false(t.can_upgrade(), "Tower at level 3 must NOT be upgradable in Chapter 1")
	assert_false(t.can_evolve(), "Tower must NOT be evolvable in Chapter 1")
	
	# Chapter 2 gating (max level 3)
	GlobalState.current_chapter = 2
	assert_eq(t.get_chapter_max_level(), 3)
	assert_false(t.can_upgrade(), "Tower at level 3 cannot upgrade in Chapter 2 (cap 3)")
	assert_false(t.can_evolve(), "Tower must NOT be evolvable in Chapter 2")
	
	# Chapter 3 gating (max level 4)
	GlobalState.current_chapter = 3
	assert_eq(t.get_chapter_max_level(), 4)
	assert_true(t.can_upgrade(), "Tower at level 3 CAN upgrade to level 4 in Chapter 3")
	t.current_level = 4
	assert_false(t.can_upgrade(), "Tower at level 4 cannot upgrade further")
	assert_false(t.can_evolve(), "Tower must NOT be evolvable in Chapter 3 (cap 4)")
	
	# Chapter 4 gating (max level 4)
	GlobalState.current_chapter = 4
	assert_eq(t.get_chapter_max_level(), 4)
	assert_false(t.can_evolve(), "Tower must NOT be evolvable in Chapter 4 (cap 4)")
	
	# Chapter 5 gating (max level 5: Evolution A/B unlocked)
	GlobalState.current_chapter = 5
	assert_eq(t.get_chapter_max_level(), 5)
	t.evolution_data_a = {"name": "Снайпер", "damage": 85, "range": 350}
	t.evolution_data_b = {"name": "Пулемётчик", "damage": 18, "attack_speed": 6.5}
	assert_true(t.can_evolve(), "Tower at level 4 CAN evolve in Chapter 5")
	
	# Clean up
	GlobalState.current_chapter = 1
	t.free()

func test_5_tower_levels_and_evolutions() -> void:
	var t = TowerBase.new()
	t.tower_type = "archer"
	t.current_level = 4
	t.max_level = 4
	t.evolution_data_a = {"name": "Снайпер", "damage": 85, "range": 350, "special_ability": "crit_20"}
	t.evolution_data_b = {"name": "Пулемётчик", "damage": 18, "attack_speed": 6.5, "special_ability": "pierce_5"}
	
	GlobalState.current_chapter = 3
	assert_true(t.can_evolve(), "Level 4 tower should be eligible for evolution in Chapter 3")
	
	# Apply Branch A -> becomes Level 5
	var success_a = t.apply_evolution("evolution_a")
	assert_true(success_a, "Evolution A should succeed")
	assert_eq(t.current_level, 5, "Evolved tower must be Level 5")
	assert_eq(t.evolution_chosen, "evolution_a", "evolution_chosen should be 'evolution_a'")
	assert_eq(t.tower_name, "Снайпер")
	
	# Clean up
	GlobalState.current_chapter = 1
	t.free()

func test_meta_manager_stage_progress_and_rewards() -> void:
	var meta = MetaManager.new()
	meta.map_stars = {}
	
	assert_eq(meta.get_unlocked_stage("valley", 10), 1, "Initial unlocked stage in valley should be 1")
	assert_eq(meta.get_stage_stars("valley", 1), 0, "Initial stage 1 stars should be 0")
	
	meta.record_stage_victory("valley", 1, 3)
	assert_eq(meta.get_stage_stars("valley", 1), 3, "Stage 1 should have 3 stars recorded")
	assert_eq(meta.get_unlocked_stage("valley", 10), 2, "Stage 2 should now be unlocked")
	assert_ge(meta.get_map_stars("valley"), 3, "Chapter stars should also be recorded")
	
	meta.queue_free()
