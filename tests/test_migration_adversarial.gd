extends SceneTree

# ==============================================================================
# ADVERSARIAL STRESS HARNESS: STAGE 2 SAVE MIGRATION & SCHEMA VERSIONING
# ==============================================================================

const TEST_SAVE_PATH: String = "user://test_adversarial_migration.json"

var total_assertions: int = 0
var passed_assertions: int = 0
var failed_assertions: int = 0
var failure_log: Array = []

func _init() -> void:
	print("\n==================================================")
	print("⚔️  STARTING SAVE MIGRATION ADVERSARIAL STRESS HARNESS")
	print("==================================================")
	
	run_all_stress_scenarios()
	
	print("\n==================================================")
	print("📊 MIGRATION STRESS HARNESS SUMMARY:")
	print("Total assertions checked: %d" % total_assertions)
	print("✅ Passed: %d" % passed_assertions)
	print("❌ Failed: %d" % failed_assertions)
	
	_cleanup()
	
	if failed_assertions > 0:
		print("\n❌ FAILURE DETAILS:")
		for f in failure_log:
			print("  - " + str(f))
		print("==================================================")
		quit(1)
	else:
		print("🎉 ALL ADVERSARIAL MIGRATION TESTS PASSED WITH ZERO CRASHES!")
		print("==================================================")
		quit(0)

func _cleanup() -> void:
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(TEST_SAVE_PATH)

func assert_true(cond: bool, desc: String) -> void:
	total_assertions += 1
	if cond:
		passed_assertions += 1
		print("    ✓ " + desc)
	else:
		failed_assertions += 1
		failure_log.append("FAILED: " + desc)
		print("    ✗ FAILED: " + desc)

func assert_eq(a, b, desc: String) -> void:
	total_assertions += 1
	if a == b:
		passed_assertions += 1
		print("    ✓ " + desc)
	else:
		failed_assertions += 1
		var err = "FAILED: %s (got %s, expected %s)" % [desc, str(a), str(b)]
		failure_log.append(err)
		print("    ✗ " + err)

func run_all_stress_scenarios() -> void:
	test_scenario_1_empty_and_minimalist_payloads()
	test_scenario_2_legacy_v1_payload_preservation()
	test_scenario_3_type_confusion_and_corrupt_types()
	test_scenario_4_future_schema_version_invariance()
	test_scenario_5_migration_idempotency_loop()
	test_scenario_6_disk_corruption_and_non_dict_roots()
	test_scenario_7_rapid_save_load_stress_cycle()

# ==============================================================================
# SCENARIO 1: Empty and Minimalist Payloads
# ==============================================================================
func test_scenario_1_empty_and_minimalist_payloads() -> void:
	print("\n--- [Scenario 1] Empty & Minimalist Payloads ---")
	var meta = MetaManager.new()
	
	var res1 = meta.migrate_save_dict({}, 1, 2)
	assert_eq(int(res1.get("schema_version", 0)), 2, "Scenario 1A: schema_version is 2")
	assert_eq(int(res1.get("glory_points", -1)), 0, "Scenario 1A: glory_points defaults to 0")
	assert_true(res1.get("upgrades") is Dictionary, "Scenario 1A: upgrades is Dictionary")
	assert_eq(res1.get("upgrades").size(), 0, "Scenario 1A: upgrades is empty")
	assert_true(res1.get("map_stars") is Dictionary, "Scenario 1A: map_stars is Dictionary")
	assert_eq(res1.get("map_stars").size(), 0, "Scenario 1A: map_stars is empty")
	assert_true(res1.get("unlocked_artifacts") is Array, "Scenario 1A: unlocked_artifacts is Array")
	assert_true(res1.get("equipped_artifacts") is Array, "Scenario 1A: equipped_artifacts is Array")
	assert_true(res1.get("statistics") is Dictionary, "Scenario 1A: statistics is Dictionary")
	
	# Minimal payload with schema_version 0
	var res2 = meta.migrate_save_dict({"schema_version": 0}, 0, 2)
	assert_eq(int(res2.get("schema_version", 0)), 2, "Scenario 1B: from_version 0 upgrades to 2")
	assert_eq(int(res2.get("glory_points", -1)), 0, "Scenario 1B: glory_points defaults to 0")
	
	meta.free()

# ==============================================================================
# SCENARIO 2: Legacy v1 Progression Preservation
# ==============================================================================
func test_scenario_2_legacy_v1_payload_preservation() -> void:
	print("\n--- [Scenario 2] Legacy v1 Progression Preservation ---")
	var meta = MetaManager.new()
	
	var v1_payload = {
		"glory_points": 500,
		"upgrades": {
			"damage_bonus": 3,
			"attack_speed": 2,
			"gold_start": 5
		},
		"unrecognized_legacy_field": "keep_me"
	}
	
	var res = meta.migrate_save_dict(v1_payload, 1, 2)
	assert_eq(int(res.get("schema_version", 0)), 2, "Scenario 2: schema_version is 2")
	assert_eq(int(res.get("glory_points", 0)), 500, "Scenario 2: glory_points preserved exactly at 500")
	assert_eq(int(res.get("upgrades").get("damage_bonus", 0)), 3, "Scenario 2: damage_bonus preserved at 3")
	assert_eq(int(res.get("upgrades").get("attack_speed", 0)), 2, "Scenario 2: attack_speed preserved at 2")
	assert_eq(int(res.get("upgrades").get("gold_start", 0)), 5, "Scenario 2: gold_start preserved at 5")
	assert_true(res.has("unrecognized_legacy_field"), "Scenario 2: extra legacy fields preserved")
	assert_eq(int(res.get("statistics").get("total_glory_earned", 0)), 500, "Scenario 2: total_glory_earned initialized to 500")
	
	meta.free()

# ==============================================================================
# SCENARIO 3: Type Confusion & Corrupt Types
# ==============================================================================
func test_scenario_3_type_confusion_and_corrupt_types() -> void:
	print("\n--- [Scenario 3] Type Confusion & Corrupted Types ---")
	var meta = MetaManager.new()
	
	# String glory points
	var res1 = meta.migrate_save_dict({"glory_points": "abc"}, 1, 2)
	assert_eq(int(res1.get("glory_points", -1)), 0, "Scenario 3A: 'abc' string glory points cast to 0")
	
	# Numeric string glory points
	var res2 = meta.migrate_save_dict({"glory_points": "1250"}, 1, 2)
	assert_eq(int(res2.get("glory_points", -1)), 1250, "Scenario 3B: '1250' numeric string glory points parsed to 1250")
	
	# Negative glory points
	var res3 = meta.migrate_save_dict({"glory_points": -999}, 1, 2)
	assert_eq(int(res3.get("glory_points", 0)), -999, "Scenario 3C: negative glory points handled without crashing")
	
	# Float glory points
	var res4 = meta.migrate_save_dict({"glory_points": 99.9}, 1, 2)
	assert_eq(int(res4.get("glory_points", 0)), 99, "Scenario 3D: float glory points converted cleanly to int")
	
	# Corrupted map_stars, artifacts, statistics
	var corrupt_payload = {
		"glory_points": 200,
		"map_stars": 9999,
		"unlocked_artifacts": "swift_boots",
		"equipped_artifacts": false,
		"statistics": [1, 2, 3]
	}
	var res5 = meta.migrate_save_dict(corrupt_payload, 1, 2)
	assert_true(res5.get("map_stars") is Dictionary, "Scenario 3E: non-dict map_stars replaced with Dictionary")
	assert_true(res5.get("unlocked_artifacts") is Array, "Scenario 3E: non-array unlocked_artifacts replaced with Array")
	assert_true(res5.get("equipped_artifacts") is Array, "Scenario 3E: non-array equipped_artifacts replaced with Array")
	assert_true(res5.get("statistics") is Dictionary, "Scenario 3E: non-dict statistics replaced with Dictionary")
	
	meta.free()

# ==============================================================================
# SCENARIO 4: Future Schema Version Invariance
# ==============================================================================
func test_scenario_4_future_schema_version_invariance() -> void:
	print("\n--- [Scenario 4] Future Schema Version Invariance ---")
	var meta = MetaManager.new()
	
	var future_payload = {
		"schema_version": 99,
		"glory_points": 99999,
		"upgrades": {"future_tech": 10},
		"future_modes": ["interstellar", "quantum"],
		"secret_token": "xyz_abc"
	}
	
	# Migrate call on future version
	var res = meta.migrate_save_dict(future_payload, 99, 2)
	assert_eq(int(res.get("schema_version", 0)), 99, "Scenario 4A: future version not changed")
	assert_eq(int(res.get("glory_points", 0)), 99999, "Scenario 4A: glory_points unchanged")
	assert_true(res.has("future_modes"), "Scenario 4A: future_modes array preserved")
	assert_true(res.has("secret_token"), "Scenario 4A: secret_token preserved")
	
	# Disk write and load
	_cleanup()
	var f = FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(future_payload, "\t"))
	f.close()
	
	var test_meta = MetaManager.new()
	test_meta.save_path = TEST_SAVE_PATH
	test_meta.load_meta_tree_data()
	test_meta.load_data()
	
	assert_eq(test_meta.schema_version, 99, "Scenario 4B: MetaManager loaded schema_version is 99")
	assert_eq(test_meta.glory_points, 99999, "Scenario 4B: MetaManager loaded glory_points is 99999")
	
	# Verify file on disk was not modified/overwritten
	var f_read = FileAccess.open(TEST_SAVE_PATH, FileAccess.READ)
	var json = JSON.new()
	json.parse(f_read.get_as_text())
	f_read.close()
	var disk_data: Dictionary = json.data
	assert_eq(int(disk_data.get("schema_version", 0)), 99, "Scenario 4B: Disk file retained schema_version 99")
	assert_true(disk_data.has("secret_token"), "Scenario 4B: Disk file retained future unreleased fields")
	
	test_meta.free()
	meta.free()

# ==============================================================================
# SCENARIO 5: Migration Idempotency Loop
# ==============================================================================
func test_scenario_5_migration_idempotency_loop() -> void:
	print("\n--- [Scenario 5] Migration Idempotency Loop (100 passes) ---")
	var meta = MetaManager.new()
	
	var current_dict: Dictionary = {
		"glory_points": 350,
		"upgrades": {"meta_bonus_lives": 2}
	}
	
	# First pass v1 -> v2
	current_dict = meta.migrate_save_dict(current_dict, 1, 2)
	var snapshot = current_dict.duplicate(true)
	
	# 99 repeated passes: v2 -> v2
	for i in range(99):
		current_dict = meta.migrate_save_dict(current_dict, 2, 2)
		
	assert_eq(current_dict, snapshot, "Scenario 5: 100 consecutive migration passes are strictly idempotent")
	meta.free()

# ==============================================================================
# SCENARIO 6: Disk Corruption & Non-Dictionary Root Recovery
# ==============================================================================
func test_scenario_6_disk_corruption_and_non_dict_roots() -> void:
	print("\n--- [Scenario 6] Disk Corruption & Non-Dictionary Root Recovery ---")
	var meta = MetaManager.new()
	meta.save_path = TEST_SAVE_PATH
	
	# 6A: Truncated JSON
	var f = FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	f.store_string('{"schema_version": 2, "glory_points": 1000, "upgrad')
	f.close()
	meta.load_data()
	assert_eq(meta.schema_version, 2, "Scenario 6A: Reset to clean schema_version on truncated JSON")
	assert_eq(meta.glory_points, 0, "Scenario 6A: Reset to 0 glory on truncated JSON")
	
	# 6B: Non-dictionary JSON root (JSON Array: `[1, 2, 3]`)
	f = FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	f.store_string('[1, 2, 3, {"nested": "value"}]')
	f.close()
	meta.load_data()
	assert_eq(meta.schema_version, 2, "Scenario 6B: Reset to clean schema_version on Array root JSON")
	assert_eq(meta.glory_points, 0, "Scenario 6B: Reset to 0 glory on Array root JSON")
	
	# 6C: Non-dictionary JSON root (JSON String: `"just_a_string"`)
	f = FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	f.store_string('"a single string payload"')
	f.close()
	meta.load_data()
	assert_eq(meta.schema_version, 2, "Scenario 6C: Reset to clean schema_version on String root JSON")
	assert_eq(meta.glory_points, 0, "Scenario 6C: Reset to 0 glory on String root JSON")
	
	meta.free()

# ==============================================================================
# SCENARIO 7: Rapid Save/Load Stress Cycle
# ==============================================================================
func test_scenario_7_rapid_save_load_stress_cycle() -> void:
	print("\n--- [Scenario 7] Rapid Save/Load Stress Cycle (50 iterations) ---")
	var meta = MetaManager.new()
	meta.save_path = TEST_SAVE_PATH
	meta.load_meta_tree_data()
	meta.reset_meta()
	
	for i in range(1, 51):
		meta.add_glory(10)
		meta.set_map_stars("forest", i % 4)
		if i == 10:
			meta.unlock_artifact("speed_ring")
		meta.save_data()
		
		var reloaded = MetaManager.new()
		reloaded.save_path = TEST_SAVE_PATH
		reloaded.load_meta_tree_data()
		reloaded.load_data()
		
		if reloaded.glory_points != meta.glory_points:
			assert_eq(reloaded.glory_points, meta.glory_points, "Cycle %d glory mismatch" % i)
			break
		reloaded.free()
		
	assert_eq(meta.glory_points, 500, "Scenario 7: 50 iterations accumulated 500 glory points")
	assert_true(meta.is_artifact_unlocked("speed_ring"), "Scenario 7: Artifact unlocked in cycle preserved")
	meta.free()
