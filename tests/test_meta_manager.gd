class_name TestMetaManager
extends TestBase

const TEST_SAVE_PATH: String = "user://test_meta_migration.json"

var meta: MetaManager = null

func before_each() -> void:
	_cleanup_test_save_file()
	meta = MetaManager.new()
	meta.save_path = TEST_SAVE_PATH if "save_path" in meta else MetaManager.SAVE_PATH
	meta.load_meta_tree_data()
	meta.glory_points = 0
	meta.upgrades = {}
	if "map_stars" in meta:
		meta.map_stars = {}
	if "unlocked_artifacts" in meta:
		meta.unlocked_artifacts = []

func after_each() -> void:
	if is_instance_valid(meta):
		meta.reset_meta()
		meta.free()
		meta = null
	_cleanup_test_save_file()

func _cleanup_test_save_file() -> void:
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(TEST_SAVE_PATH)

# ==============================================================================
# Existing Baseline Progression Tests
# ==============================================================================
func test_glory_points_addition() -> void:
	assert_eq(meta.glory_points, 0, "Initial glory points should be 0")
	meta.add_glory(50)
	assert_eq(meta.glory_points, 50, "Glory points should increase to 50")

func test_upgrade_purchase_and_levels() -> void:
	meta.add_glory(100)
	assert_eq(meta.get_level("meta_starting_gold"), 0, "Level before purchase should be 0")
	
	# Base cost is 15 for meta_starting_gold level 1
	var bought = meta.buy_upgrade("meta_starting_gold")
	assert_true(bought, "Upgrade purchase should succeed")
	assert_eq(meta.get_level("meta_starting_gold"), 1, "Level should now be 1")
	assert_eq(meta.get_starting_gold_bonus(), 50, "Level 1 starting gold bonus should be 50")
	
	# Try buying without enough points
	meta.glory_points = 0
	var failed_buy = meta.buy_upgrade("meta_starting_gold")
	assert_false(failed_buy, "Should fail to buy without glory points")
	assert_eq(meta.get_level("meta_starting_gold"), 1, "Level should remain 1")

func test_bonus_calculations() -> void:
	meta.upgrades["meta_starting_gold"] = 2
	meta.upgrades["meta_bonus_lives"] = 3
	meta.upgrades["meta_base_damage"] = 4
	meta.upgrades["meta_research_start"] = 2
	
	assert_eq(meta.get_starting_gold_bonus(), 100, "2 levels of gold bonus = 100g")
	assert_eq(meta.get_bonus_lives(), 15, "3 levels of bonus lives = 15 lives")
	assert_almost_eq(meta.get_base_damage_mult(), 0.32, 0.001, "4 levels of damage = +32%")
	assert_eq(meta.get_starting_research_bonus(), 2, "2 levels of research start = 2 points")

# ==============================================================================
# Feature 12: Save Schema Versioning & Automated Migrations (v1 -> v2)
# ==============================================================================
func test_save_data_contract_schema_v2() -> void:
	meta.glory_points = 180
	meta.upgrades["meta_starting_gold"] = 3
	meta.upgrades["meta_bonus_lives"] = 2
	if "map_stars" in meta:
		meta.map_stars["curly_valley"] = 3
	if "unlocked_artifacts" in meta:
		meta.unlocked_artifacts = ["swift_boots"]
		
	assert_true(meta.has_method("save_data"), "MetaManager must implement save_data() -> Dictionary")
	var data: Dictionary = meta.save_data()
	
	assert_true(data.has("schema_version"), "Save data dictionary must include 'schema_version'")
	assert_eq(int(data.schema_version), 2, "Save data schema_version must be exactly 2")
	assert_eq(int(data.glory_points), 180, "Glory points must match active state")
	assert_eq(int(data.upgrades.get("meta_starting_gold", 0)), 3, "Upgrades must match active state")
	assert_true(data.has("map_stars"), "Save data must include 'map_stars'")
	assert_true(data.has("unlocked_artifacts"), "Save data must include 'unlocked_artifacts'")

func test_migrate_save_dict_pure_functional() -> void:
	# Raw legacy v1 save payload without schema_version
	var v1_payload = {
		"glory_points": 320,
		"upgrades": {
			"meta_starting_gold": 2,
			"meta_bonus_lives": 1
		}
	}
	
	assert_true(meta.has_method("migrate_save_dict"), "MetaManager must provide migrate_save_dict pure functional method")
	var migrated: Dictionary = meta.migrate_save_dict(v1_payload, 1, 2)
	
	assert_eq(int(migrated.get("schema_version", 0)), 2, "Migrated dictionary must have schema_version 2")
	assert_eq(int(migrated.get("glory_points", 0)), 320, "Migrated dictionary must preserve glory_points")
	assert_eq(int(migrated.get("upgrades", {}).get("meta_starting_gold", 0)), 2, "Migrated dictionary must preserve upgrades")
	assert_eq(int(migrated.get("upgrades", {}).get("meta_bonus_lives", 0)), 1, "Migrated dictionary must preserve upgrades")
	assert_true(migrated.has("map_stars"), "Migrated dictionary must initialize map_stars")
	assert_true(migrated.has("unlocked_artifacts"), "Migrated dictionary must initialize unlocked_artifacts")

func test_legacy_v1_save_migration_from_disk() -> void:
	# 1. Write legacy v1 save without schema_version to isolated test save file
	var v1_json = JSON.stringify({
		"glory_points": 275,
		"upgrades": {
			"meta_starting_gold": 3,
			"meta_base_damage": 2
		}
	}, "\t")
	
	var file = FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	assert_not_null(file, "Test save file must open for writing")
	file.store_string(v1_json)
	file.close()
	
	# 2. Instantiate fresh MetaManager pointed to the test save file
	var test_meta = MetaManager.new()
	test_meta.save_path = TEST_SAVE_PATH
	test_meta.load_meta_tree_data()
	
	# 3. Call load_data() / load_meta()
	test_meta.load_data()
	
	# 4. Assert migration occurred seamlessly
	assert_eq(test_meta.schema_version, 2, "Active schema_version must be upgraded to 2")
	assert_eq(test_meta.glory_points, 275, "Glory points from v1 save must be preserved")
	assert_eq(test_meta.get_level("meta_starting_gold"), 3, "meta_starting_gold level must be 3")
	assert_eq(test_meta.get_level("meta_base_damage"), 2, "meta_base_damage level must be 2")
	assert_true(test_meta.map_stars is Dictionary, "map_stars must be initialized to Dictionary")
	assert_true(test_meta.unlocked_artifacts is Array, "unlocked_artifacts must be initialized to Array")
	
	test_meta.free()

func test_migrated_save_persisted_to_disk_with_schema_v2() -> void:
	# 1. Write legacy v1 save to disk
	var v1_json = JSON.stringify({
		"glory_points": 450,
		"upgrades": {
			"meta_bonus_lives": 4
		}
	}, "\t")
	
	var f_write = FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	f_write.store_string(v1_json)
	f_write.close()
	
	# 2. Load via MetaManager (which auto-migrates and persists back)
	var test_meta = MetaManager.new()
	test_meta.save_path = TEST_SAVE_PATH
	test_meta.load_meta_tree_data()
	test_meta.load_data()
	test_meta.free()
	
	# 3. Inspect raw file on disk: it must now have schema_version: 2
	var f_read = FileAccess.open(TEST_SAVE_PATH, FileAccess.READ)
	assert_not_null(f_read, "Migrated save file must exist on disk")
	var json = JSON.new()
	var parse_err = json.parse(f_read.get_as_text())
	f_read.close()
	
	assert_eq(parse_err, OK, "Migrated disk file must be valid JSON")
	var disk_data: Dictionary = json.data
	assert_true(disk_data.has("schema_version"), "Disk save must now contain 'schema_version'")
	assert_eq(int(disk_data.schema_version), 2, "Disk save schema_version must now be 2")
	assert_eq(int(disk_data.glory_points), 450, "Disk save must retain 450 glory points")
	assert_eq(int(disk_data.upgrades.get("meta_bonus_lives", 0)), 4, "Disk save must retain upgrades")

func test_v2_save_reloading_idempotent() -> void:
	# 1. Write an explicit v2 save to disk
	var v2_payload = {
		"schema_version": 2,
		"glory_points": 500,
		"upgrades": {
			"meta_starting_gold": 1
		},
		"map_stars": {"valley": 3},
		"unlocked_artifacts": ["swift_boots"],
		"equipped_artifacts": ["swift_boots"],
		"statistics": {"total_victories": 1}
	}
	
	var f_write = FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	f_write.store_string(JSON.stringify(v2_payload, "\t"))
	f_write.close()
	
	# 2. Load via MetaManager
	var test_meta = MetaManager.new()
	test_meta.save_path = TEST_SAVE_PATH
	test_meta.load_meta_tree_data()
	test_meta.load_data()
	
	# 3. Confirm all v2 properties loaded cleanly without modification
	assert_eq(test_meta.schema_version, 2, "schema_version must remain 2")
	assert_eq(test_meta.glory_points, 500, "glory_points must remain 500")
	assert_eq(test_meta.get_level("meta_starting_gold"), 1, "Upgrade level must remain 1")
	assert_eq(test_meta.map_stars.get("valley", 0), 3, "Map stars must match saved value")
	assert_true(test_meta.unlocked_artifacts.has("swift_boots"), "Artifacts must match saved value")
	
	test_meta.free()

func test_corrupted_save_graceful_recovery() -> void:
	# Write malformed non-JSON data
	var f_write = FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	f_write.store_string("NOT_VALID_JSON{:::broken")
	f_write.close()
	
	var test_meta = MetaManager.new()
	test_meta.save_path = TEST_SAVE_PATH
	test_meta.load_meta_tree_data()
	test_meta.load_data()
	
	assert_eq(test_meta.schema_version, 2, "Schema version should reset to clean defaults (2)")
	assert_eq(test_meta.glory_points, 0, "Glory points should safely reset to 0")
	test_meta.free()

func test_star_and_artifact_accessors() -> void:
	assert_eq(meta.get_map_stars("forest"), 0, "Default stars should be 0")
	meta.set_map_stars("forest", 2)
	assert_eq(meta.get_map_stars("forest"), 2, "Stars should be updated to 2")
	# Lower stars should not overwrite higher stars
	meta.set_map_stars("forest", 1)
	assert_eq(meta.get_map_stars("forest"), 2, "Lower stars should not downgrade")
	meta.set_map_stars("plains", 3)
	assert_eq(meta.get_total_stars(), 5, "Total stars should be 2 + 3 = 5")
	
	assert_false(meta.is_artifact_unlocked("ring_of_fire"), "Artifact should be locked initially")
	var unlocked = meta.unlock_artifact("ring_of_fire")
	assert_true(unlocked, "Unlocking new artifact should return true")
	assert_true(meta.is_artifact_unlocked("ring_of_fire"), "Artifact should now be unlocked")
	var re_unlocked = meta.unlock_artifact("ring_of_fire")
	assert_false(re_unlocked, "Unlocking already unlocked artifact should return false")

# ==============================================================================
# Adversarial Challenge: Edge Cases of migrate_save_dict() & Schema Handling
# ==============================================================================
func test_migration_empty_dictionary_edge_case() -> void:
	# 1. Functional migration of empty dictionary {}
	var empty_input: Dictionary = {}
	var migrated: Dictionary = meta.migrate_save_dict(empty_input, 1, 2)
	
	assert_eq(int(migrated.get("schema_version", 0)), 2, "Empty dict must upgrade to schema_version 2")
	assert_eq(int(migrated.get("glory_points", -1)), 0, "Empty dict must default to 0 glory points")
	assert_true(migrated.get("upgrades") is Dictionary, "Empty dict must have upgrades Dictionary")
	assert_eq(migrated.get("upgrades").size(), 0, "Empty dict upgrades Dictionary must be empty")
	assert_true(migrated.get("map_stars") is Dictionary, "Empty dict must have map_stars Dictionary")
	assert_eq(migrated.get("map_stars").size(), 0, "Empty dict map_stars Dictionary must be empty")
	assert_true(migrated.get("unlocked_artifacts") is Array, "Empty dict must have unlocked_artifacts Array")
	assert_eq(migrated.get("unlocked_artifacts").size(), 0, "Empty dict unlocked_artifacts Array must be empty")
	assert_true(migrated.get("equipped_artifacts") is Array, "Empty dict must have equipped_artifacts Array")
	assert_eq(migrated.get("equipped_artifacts").size(), 0, "Empty dict equipped_artifacts Array must be empty")
	assert_true(migrated.get("statistics") is Dictionary, "Empty dict must have statistics Dictionary")
	assert_eq(int(migrated.get("statistics").get("total_glory_earned", -1)), 0, "Empty dict statistics total_glory_earned must be 0")
	
	# 2. Disk load of empty dictionary {}
	var f_write = FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	f_write.store_string("{}")
	f_write.close()
	
	var test_meta = MetaManager.new()
	test_meta.save_path = TEST_SAVE_PATH
	test_meta.load_meta_tree_data()
	test_meta.load_data()
	
	assert_eq(test_meta.schema_version, 2, "Disk load of {} must set schema_version 2")
	assert_eq(test_meta.glory_points, 0, "Disk load of {} must set glory_points 0")
	assert_eq(test_meta.upgrades.size(), 0, "Disk load of {} must have empty upgrades")
	assert_eq(test_meta.map_stars.size(), 0, "Disk load of {} must have empty map_stars")
	test_meta.free()

func test_migration_legacy_v1_dictionary_preservation() -> void:
	var legacy_input: Dictionary = {
		"glory_points": 500,
		"upgrades": {
			"damage_bonus": 3
		}
	}
	
	# Functional migration test
	var migrated: Dictionary = meta.migrate_save_dict(legacy_input, 1, 2)
	assert_eq(int(migrated.get("schema_version", 0)), 2, "Migrated legacy dict must have schema_version 2")
	assert_eq(int(migrated.get("glory_points", 0)), 500, "Glory points must be exactly preserved as 500")
	assert_true(migrated.get("upgrades") is Dictionary, "Upgrades must remain a Dictionary")
	assert_eq(int(migrated.get("upgrades").get("damage_bonus", 0)), 3, "Upgrade levels must be preserved (damage_bonus: 3)")
	assert_true(migrated.get("map_stars") is Dictionary, "map_stars must be initialized")
	assert_true(migrated.get("unlocked_artifacts") is Array, "unlocked_artifacts must be initialized")
	assert_eq(int(migrated.get("statistics").get("total_glory_earned", 0)), 500, "Statistics total_glory_earned must match 500")
	
	# Disk persistence roundtrip
	var f_write = FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	f_write.store_string(JSON.stringify(legacy_input, "\t"))
	f_write.close()
	
	var test_meta = MetaManager.new()
	test_meta.save_path = TEST_SAVE_PATH
	test_meta.load_meta_tree_data()
	test_meta.load_data()
	
	assert_eq(test_meta.schema_version, 2, "Loaded legacy save must be schema_version 2")
	assert_eq(test_meta.glory_points, 500, "Loaded legacy save must retain 500 glory points")
	assert_eq(test_meta.get_level("damage_bonus"), 3, "Loaded legacy save must retain damage_bonus level 3")
	test_meta.free()

func test_migration_corrupted_unexpected_types_zero_crash() -> void:
	# String glory_points: "abc"
	var abc_dict: Dictionary = {"glory_points": "abc"}
	var abc_res: Dictionary = meta.migrate_save_dict(abc_dict, 1, 2)
	assert_eq(int(abc_res.get("glory_points", -1)), 0, "String 'abc' glory points must gracefully convert to 0")
	assert_eq(int(abc_res.get("schema_version", 0)), 2, "Schema version must still upgrade to 2")
	
	# Negative glory points: -50
	var neg_dict: Dictionary = {"glory_points": -50}
	var neg_res: Dictionary = meta.migrate_save_dict(neg_dict, 1, 2)
	assert_eq(int(neg_res.get("glory_points", 0)), -50, "Negative glory points handled without crashing")
	assert_eq(int(neg_res.get("schema_version", 0)), 2, "Schema version must still upgrade to 2")
	
	# Float glory points: 123.75
	var float_dict: Dictionary = {"glory_points": 123.75}
	var float_res: Dictionary = meta.migrate_save_dict(float_dict, 1, 2)
	assert_eq(int(float_res.get("glory_points", 0)), 123, "Float glory points gracefully truncated to integer")
	
	# Corrupted map_stars, artifacts, statistics types
	var bad_types_dict: Dictionary = {
		"glory_points": 100,
		"map_stars": "not_a_dict",
		"unlocked_artifacts": 12345,
		"equipped_artifacts": true,
		"statistics": "corrupted_string"
	}
	var clean_res: Dictionary = meta.migrate_save_dict(bad_types_dict, 1, 2)
	assert_true(clean_res.get("map_stars") is Dictionary, "Corrupted map_stars must recover to empty Dictionary")
	assert_true(clean_res.get("unlocked_artifacts") is Array, "Corrupted unlocked_artifacts must recover to empty Array")
	assert_true(clean_res.get("equipped_artifacts") is Array, "Corrupted equipped_artifacts must recover to empty Array")
	assert_true(clean_res.get("statistics") is Dictionary, "Corrupted statistics must recover to valid Dictionary")

func test_migration_future_schema_version_protection() -> void:
	var future_data: Dictionary = {
		"schema_version": 99,
		"glory_points": 9999,
		"upgrades": {"omega_turret": 10},
		"future_field_unreleased": {"quantum_teleport": true}
	}
	
	# 1. Functional: migrate_save_dict must not downgrade or corrupt future schema version
	var res: Dictionary = meta.migrate_save_dict(future_data, 99, 2)
	assert_eq(int(res.get("schema_version", 0)), 99, "Future schema version must remain 99")
	assert_eq(int(res.get("glory_points", 0)), 9999, "Future glory points must remain 9999")
	assert_true(res.has("future_field_unreleased"), "Future fields must be preserved without deletion")
	
	# 2. Disk: loading future schema version must not crash or corrupt the file
	var f_write = FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	f_write.store_string(JSON.stringify(future_data, "\t"))
	f_write.close()
	
	var test_meta = MetaManager.new()
	test_meta.save_path = TEST_SAVE_PATH
	test_meta.load_meta_tree_data()
	test_meta.load_data()
	
	assert_eq(test_meta.schema_version, 99, "MetaManager schema_version should reflect future schema 99")
	assert_eq(test_meta.glory_points, 9999, "MetaManager glory points should reflect 9999")
	
	# Verify file on disk was not overwritten with v2
	var f_read = FileAccess.open(TEST_SAVE_PATH, FileAccess.READ)
	var json = JSON.new()
	json.parse(f_read.get_as_text())
	f_read.close()
	var disk_data: Dictionary = json.data
	assert_eq(int(disk_data.get("schema_version", 0)), 99, "File on disk must retain future schema_version 99")
	assert_true(disk_data.has("future_field_unreleased"), "File on disk must retain future unreleased fields")
	
	test_meta.free()

