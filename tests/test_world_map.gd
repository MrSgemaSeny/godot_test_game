class_name TestWorldMap
extends TestBase

const WorldMapClass = preload("res://scripts/world_map.gd")

func test_world_map_initial_unlocks() -> void:
	var wm = WorldMapClass.new()
	var meta = MetaManager.new()
	meta.map_stars = {}
	
	assert_true(wm.is_map_unlocked("valley", meta), "Valley should be unlocked by default")
	assert_false(wm.is_map_unlocked("swamp", meta), "Swamp should be locked initially")
	assert_false(wm.is_map_unlocked("caves", meta), "Caves should be locked initially")
	assert_false(wm.is_map_unlocked("frost_peak", meta), "Frost peak should be locked initially")
	assert_false(wm.is_map_unlocked("besieged_citadel", meta), "Citadel should be locked initially")
	
	meta.queue_free()

func test_world_map_progressive_unlocking() -> void:
	var wm = WorldMapClass.new()
	var meta = MetaManager.new()
	meta.map_stars = {}
	
	# Pass Valley with 1 star -> Swamp still locked (needs 2 stars)
	meta.set_map_stars("valley", 1)
	assert_false(wm.is_map_unlocked("swamp", meta))
	
	# Pass Valley with 2 stars -> Swamp unlocks!
	meta.set_map_stars("valley", 2)
	assert_true(wm.is_map_unlocked("swamp", meta), "Swamp should unlock with 2 stars on Valley")
	
	# Pass Swamp -> Caves unlocks (2 completed maps total)
	meta.set_map_stars("swamp", 1)
	assert_true(wm.is_map_unlocked("caves", meta), "Caves should unlock with 2 completed maps")
	
	# Pass Caves -> Frost peak unlocks (both swamp and caves completed)
	meta.set_map_stars("caves", 1)
	assert_true(wm.is_map_unlocked("frost_peak", meta), "Frost peak unlocks when both Swamp and Caves are beaten")
	
	# Pass Frost peak -> Final Citadel unlocks
	meta.set_map_stars("frost_peak", 1)
	assert_true(wm.is_map_unlocked("besieged_citadel", meta), "Citadel unlocks when Frost peak is beaten")
	
	meta.queue_free()

func test_world_map_selection_flow() -> void:
	var wm = WorldMapClass.new()
	var meta = MetaManager.new()
	meta.map_stars = {"valley": 3}
	
	assert_true(wm.select_map("valley", meta))
	assert_eq(wm.current_selected_map, "valley")
	
	assert_true(wm.select_map("swamp", meta))
	assert_eq(wm.current_selected_map, "swamp")
	
	# Cannot select locked caves
	assert_false(wm.select_map("caves", meta))
	assert_eq(wm.current_selected_map, "swamp", "Selection should remain on swamp when caves is locked")
	
	meta.queue_free()
