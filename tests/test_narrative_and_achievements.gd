class_name TestNarrativeAndAchievements
extends TestBase

const LoreSystemClass = preload("res://scripts/lore_system.gd")
const BestiaryManagerClass = preload("res://scripts/bestiary_manager.gd")
const AchievementSystemClass = preload("res://scripts/achievement_system.gd")

func test_lore_system_triggers() -> void:
	var lore = LoreSystemClass.new()
	lore._load_lore_db()
	assert_gt(lore.lore_entries.size(), 0, "Lore entries must be populated")
	
	var d = lore.trigger_event("valley", 1, "wave_start")
	assert_false(d.is_empty(), "Triggering valley wave 1 start should return dialogue")
	assert_eq(d.get("speaker"), "Командир Гарольд")
	
	# Repeated trigger in same session is ignored (already shown)
	var d_repeat = lore.trigger_event("valley", 1, "wave_start")
	assert_true(d_repeat.is_empty(), "Shown dialogue should not repeat in same session")
	
	lore.queue_free()

func test_bestiary_progression() -> void:
	var bm = BestiaryManagerClass.new()
	assert_false(bm.is_discovered("grunt"))
	
	bm.register_encounter("grunt")
	assert_true(bm.is_discovered("grunt"))
	assert_false(bm.is_weakness_known("grunt"))
	assert_eq(bm.get_kill_count("grunt"), 0)
	
	for i in range(4):
		bm.register_kill("grunt")
	assert_eq(bm.get_kill_count("grunt"), 4)
	assert_false(bm.is_weakness_known("grunt"))
	
	# 5th kill unlocks weakness
	bm.register_kill("grunt")
	assert_eq(bm.get_kill_count("grunt"), 5)
	assert_true(bm.is_weakness_known("grunt"), "5 kills must unlock weakness info")
	
	bm.queue_free()

func test_achievements_system() -> void:
	var ach = AchievementSystemClass.new()
	ach._load_achievements_db()
	assert_eq(ach.get_total_count(), 40, "Achievements database must contain exactly 40 achievements")
	
	assert_false(ach.is_unlocked("first_blood"))
	assert_true(ach.unlock_achievement("first_blood"))
	assert_true(ach.is_unlocked("first_blood"))
	assert_eq(ach.get_unlocked_count(), 1)
	
	# Cannot unlock again
	assert_false(ach.unlock_achievement("first_blood"), "Duplicate unlock should return false")
	assert_eq(ach.get_unlocked_count(), 1)
	
	ach.queue_free()
