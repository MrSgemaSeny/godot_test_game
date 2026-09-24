class_name TestPhases8To10
extends TestBase

const ProceduralDungeonCrawlerClass = preload("res://scripts/procedural_dungeon_crawler.gd")
const DailyChallengeGeneratorClass = preload("res://scripts/daily_challenge_generator.gd")
const ContentValidatorClass = preload("res://scripts/content_validator.gd")
const CombatBalanceSimulatorClass = preload("res://scripts/combat_balance_simulator.gd")
const AudioSFXSynthesizerClass = preload("res://scripts/audio_sfx_synthesizer.gd")
const SaveMigrationV3Class = preload("res://scripts/save_migration_v3.gd")

func test_procedural_dungeon_generation() -> void:
	var crawler = ProceduralDungeonCrawlerClass.new()
	var graph = crawler.generate_dungeon(42, 10)
	
	assert_eq(crawler.total_floors, 10, "Total floors should match parameter")
	assert_eq(graph.size(), 10, "Graph must have 10 floor entries")
	
	# Floor 0 must have at least 1 node
	var floor_0_nodes: Array = graph.get(0, [])
	assert_true(floor_0_nodes.size() > 0, "Floor 0 must have nodes")
	
	# Enter starting node
	var start_id = floor_0_nodes[0]["id"]
	var entered = crawler.enter_node(start_id)
	assert_true(entered, "Should successfully enter starting node")
	assert_eq(crawler.current_floor, 0, "Current floor should be 0")
	
	# Complete node
	var reward = crawler.complete_current_node()
	assert_true(reward.size() > 0, "Reward must be issued upon node completion")
	
	# Check next available nodes
	var next_nodes = crawler.get_available_next_nodes()
	assert_true(next_nodes.size() > 0, "Should have branching next nodes available")
	
	crawler.free()

func test_daily_challenge_generator() -> void:
	var gen = DailyChallengeGeneratorClass.new()
	var chal1 = gen.generate_challenge_for_seed(20260924)
	var chal2 = gen.generate_challenge_for_seed(20260924)
	
	assert_eq(chal1["title"], chal2["title"], "Same seed must yield deterministic daily challenge title")
	assert_eq(chal1["biome"], chal2["biome"], "Same seed must yield same biome")
	assert_eq(chal1["mutators"].size(), chal2["mutators"].size(), "Mutator counts must be identical")
	
	var score_data = gen.calculate_run_score(15, 5, 300.0, 10)
	assert_true(score_data["final_score"] > 0, "Final score must be positive")
	assert_true(score_data["speed_bonus"] > 0, "Speed bonus must be positive for 300s clear")
	
	gen.free()

func test_content_validator() -> void:
	var report = ContentValidatorClass.validate_all_content()
	assert_true(report["valid"], "Game content must be 100% valid")
	assert_eq(report["errors"].size(), 0, "Zero fatal errors expected in content validation")
	assert_true(report["stats"].get("total_towers", 0) > 0, "Must validate towers")
	assert_true(report["stats"].get("total_enemies", 0) > 0, "Must validate enemies")

func test_combat_balance_simulator() -> void:
	var dummy_wave = {
		"spawn_groups": [
			{"enemy_type": "grunt", "count": 10, "interval": 1.0, "delay": 0.0}
		]
	}
	var dummy_towers: Array[Dictionary] = [
		{"damage": 25.0, "fire_rate": 1.5}
	]
	var dummy_enemies = {
		"grunt": {"health": 80.0}
	}
	
	var result = CombatBalanceSimulatorClass.simulate_wave(dummy_wave, dummy_towers, dummy_enemies)
	assert_true(result["winnable"], "Wave with high DPS towers must be evaluated as winnable")
	assert_eq(result["enemy_count"], 10, "Must correctly sum enemy count")
	assert_true(result["estimated_ttk"] > 0.0, "TTK must be positive")

func test_audio_sfx_synthesizer() -> void:
	var synth = AudioSFXSynthesizerClass.new()
	assert_not_null(synth, "AudioSFXSynthesizer must instantiate")
	synth.play_sfx(synth.SoundType.CLICK)
	synth.play_sfx(synth.SoundType.COIN)
	assert_eq(synth.is_muted, false, "Synthesizer must start unmuted")
	synth.toggle_mute()
	assert_eq(synth.is_muted, true, "Mute toggle must work")
	synth.free()

func test_save_migration_v3() -> void:
	var legacy_v1 = {
		"schema_version": 1,
		"gold": 500
	}
	var migrated = SaveMigrationV3Class.migrate_to_v3(legacy_v1)
	assert_eq(migrated["schema_version"], 3, "Schema version must be 3")
	assert_eq(migrated["glory_points"], 500, "Glory points must be carried over")
	assert_true(migrated.has("ng_level"), "Must contain ng_level")
	assert_true(migrated.has("dungeon_best_floor"), "Must contain dungeon_best_floor")
	assert_true(migrated.has("settings"), "Must contain settings")
	assert_true(SaveMigrationV3Class.is_save_valid_v3(migrated), "Save must pass v3 validation")
