extends SceneTree

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0
var failed_details: Array = []

func _init() -> void:
	print("==================================================")
	print("🚀 STARTING GODOT 4.7 TOWER DEFENSE TEST SUITE")
	print("==================================================")
	
	run_all_tests()
	
	print("\n==================================================")
	print("📊 TEST SUMMARY:")
	print("Total tests executed: %d" % total_tests)
	print("✅ Passed: %d" % passed_tests)
	print("❌ Failed: %d" % failed_tests)
	
	if failed_tests > 0:
		print("\n❌ Failures detail:")
		for f in failed_details:
			print("  - " + str(f))
		print("==================================================")
		quit(1)
	else:
		print("🎉 ALL TESTS PASSED SUCCESSFULLY!")
		print("==================================================")
		quit(0)

func run_all_tests() -> void:
	var test_classes = [
		preload("res://tests/test_data_integrity.gd"),
		preload("res://tests/test_game_manager.gd"),
		preload("res://tests/test_tech_tree.gd"),
		preload("res://tests/test_meta_manager.gd"),
		preload("res://tests/test_spells.gd"),
		preload("res://tests/test_towers_and_combat.gd"),
		preload("res://tests/test_monsters_and_girls.gd"),
		preload("res://tests/test_interactive_objects.gd"),
		preload("res://tests/test_scene_integration.gd")
	]
	
	for test_cls in test_classes:
		var suite = test_cls.new()
		var suite_name = suite.get_script().resource_path.get_file()
		print("\n--- Running Suite: %s ---" % suite_name)
		
		# Find all methods starting with "test_"
		for method_info in suite.get_method_list():
			var m_name = method_info.name
			if m_name.begins_with("test_"):
				total_tests += 1
				
				# Setup if exists
				if suite.has_method("before_each"):
					suite.before_each()
					
				try_run_test(suite, m_name)
				
				# Teardown if exists
				if suite.has_method("after_each"):
					suite.after_each()

func try_run_test(suite: Object, m_name: String) -> void:
	suite.current_test_failed = false
	suite.current_test_error = ""
	
	suite.call(m_name)
	
	if suite.current_test_failed:
		failed_tests += 1
		var err = "[%s] %s: %s" % [suite.get_script().resource_path.get_file(), m_name, suite.current_test_error]
		failed_details.append(err)
		print("  ❌ %s: FAILED -> %s" % [m_name, suite.current_test_error])
	else:
		passed_tests += 1
		print("  ✅ %s: PASSED" % m_name)
