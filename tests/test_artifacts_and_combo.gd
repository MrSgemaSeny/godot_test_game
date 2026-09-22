class_name TestArtifactsAndCombo
extends TestBase

const ArtifactManagerClass = preload("res://scripts/artifact_manager.gd")
const ComboTrackerClass = preload("res://scripts/combo_tracker.gd")

func test_artifacts_database_loading() -> void:
	var am = ArtifactManagerClass.new()
	am._load_artifacts_db()
	assert_gt(am.artifacts_db.size(), 0, "Artifacts database should contain items")
	assert_eq(am.artifacts_db.size(), 30, "Artifacts database must contain exactly 30 artifacts")
	assert_true(am.artifacts_db.has("boots_of_speed"))
	assert_true(am.artifacts_db.has("infinity_stone"))
	am.queue_free()

func test_artifacts_unlock_and_equip() -> void:
	var am = ArtifactManagerClass.new()
	am._load_artifacts_db()
	
	assert_false(am.equip_artifact("boots_of_speed", 0), "Locked artifact cannot be equipped")
	assert_true(am.unlock_artifact("boots_of_speed"))
	assert_true(am.is_unlocked("boots_of_speed"))
	
	# Equip into slot 0
	assert_true(am.equip_artifact("boots_of_speed", 0))
	assert_true(am.is_equipped("boots_of_speed"))
	assert_true(am.has_active_effect("instant_build"))
	assert_almost_eq(am.get_effect_value("instant_build"), 1.0, 0.01)
	
	# Re-equip into slot 1 moves it cleanly
	assert_true(am.equip_artifact("boots_of_speed", 1))
	assert_eq(am.equipped_slots[0], "", "Slot 0 should be emptied after move")
	assert_eq(am.equipped_slots[1], "boots_of_speed")
	
	# Unequip
	assert_true(am.unequip_slot(1))
	assert_false(am.is_equipped("boots_of_speed"))
	assert_false(am.has_active_effect("instant_build"))
	
	am.queue_free()

func test_combo_tracker_progression_and_expiry() -> void:
	var ct = ComboTrackerClass.new()
	assert_eq(ct.current_streak, 0)
	assert_almost_eq(ct.current_multiplier, 1.0, 0.01)
	
	# Kills advance streak and multiplier
	for i in range(6):
		ct.register_kill()
		
	assert_eq(ct.current_streak, 6)
	assert_almost_eq(ct.current_multiplier, 1.2, 0.01, "6 kills should give 1.2x multiplier")
	
	# Timeout breaks combo
	ct._process(3.0)
	assert_eq(ct.current_streak, 0)
	assert_almost_eq(ct.current_multiplier, 1.0, 0.01)
	
	ct.queue_free()
