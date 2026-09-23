class_name WorldRegionManager
extends Node

## WorldRegionManager handles the overarching campaign map, all 12 distinct regions,
## outpost control, threat levels, and caravan defense missions.
## Regions included: valley, swamp, greenwood, stone_suburbs, royal_highway,
## crystal_caves, frost_peak, ash_wastes, fire_chasms, sunken_kingdom, astral_ruins, royal_heart.

signal region_unlocked(region_id: String)
signal threat_level_changed(region_id: String, new_level: int)
signal outpost_captured(region_id: String, outpost_id: String)
signal caravan_mission_spawned(region_id: String)
signal caravan_mission_completed(success: bool, rewards: Dictionary)

const MAX_THREAT_LEVEL: int = 5
const MIN_THREAT_LEVEL: int = 1

var regions: Dictionary = {}
var active_caravans: Array[Dictionary] = []
var global_faction_influence: Dictionary = {
	"royal": 0,
	"mages_guild": 0,
	"merchants": 0,
	"mercenaries": 0
}

func _init() -> void:
	add_to_group("world_region_manager")

func _ready() -> void:
	initialize()

## Initializes the region manager, loading data from JSON if available, or setting defaults.
func initialize() -> void:
	var file_path = "res://data/regions_data.json"
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			var data = json.data
			if typeof(data) == TYPE_DICTIONARY or typeof(data) == TYPE_ARRAY:
				_import_regions_data(data)
	else:
		_setup_fallback_regions()
		
	# Start threat simulation timer
	var timer = Timer.new()
	timer.wait_time = 300.0 # 5 minutes of real time
	timer.autostart = true
	timer.timeout.connect(_on_threat_decay_tick)
	add_child(timer)

func _import_regions_data(data) -> void:
	regions.clear()
	var arr = data if typeof(data) == TYPE_ARRAY else data.values()
	for r in arr:
		if typeof(r) == TYPE_DICTIONARY and r.has("id"):
			var rid = r["id"]
			regions[rid] = {
				"id": rid,
				"name": r.get("name", rid),
				"is_unlocked": r.get("start_unlocked", false),
				"threat_level": MIN_THREAT_LEVEL,
				"outposts": {},
				"connections": r.get("connecting_regions", []),
				"base_danger": r.get("danger_level", 1)
			}
			var outposts_arr = r.get("outposts", [])
			for out_data in outposts_arr:
				if out_data is Dictionary and out_data.has("id"):
					regions[rid]["outposts"][out_data["id"]] = {
						"captured": false,
						"resource_yield": out_data.get("resource_yield", 0),
						"faction": out_data.get("faction", "neutral")
					}

func _setup_fallback_regions() -> void:
	var region_ids = [
		"valley", "swamp", "greenwood", "stone_suburbs", "royal_highway", 
		"crystal_caves", "frost_peak", "ash_wastes", "fire_chasms", 
		"sunken_kingdom", "astral_ruins", "royal_heart"
	]
	
	for i in range(region_ids.size()):
		var rid = region_ids[i]
		regions[rid] = {
			"id": rid,
			"name": rid.capitalize(),
			"is_unlocked": i == 0,
			"threat_level": MIN_THREAT_LEVEL,
			"outposts": {
				"outpost_1": {"captured": false, "resource_yield": 10, "faction": "merchants"},
				"outpost_2": {"captured": false, "resource_yield": 15, "faction": "mages_guild"}
			},
			"connections": [],
			"base_danger": 1 + (i / 3)
		}
		if i > 0:
			regions[region_ids[i-1]]["connections"].append(rid)
			regions[rid]["connections"].append(region_ids[i-1])

## Gets all runtime data for a specific region.
func get_region_data(id: String) -> Dictionary:
	return regions.get(id, {})

## Unlocks a region in the campaign graph.
func unlock_region(id: String) -> bool:
	if regions.has(id):
		if not regions[id]["is_unlocked"]:
			regions[id]["is_unlocked"] = true
			region_unlocked.emit(id)
			return true
	return false

## Checks if all prerequisites for a region are met.
func can_unlock_region(id: String) -> bool:
	if not regions.has(id): return false
	if regions[id]["is_unlocked"]: return false
	
	var r = regions[id]
	for conn in r.get("connections", []):
		if regions.has(conn) and regions[conn]["is_unlocked"]:
			return true
	return false

## Adds threat to a region, increasing hazard probability and elite spawns.
func add_threat(region_id: String, amount: int) -> void:
	if regions.has(region_id):
		var old_val = regions[region_id]["threat_level"]
		var new_val = clamp(old_val + amount, MIN_THREAT_LEVEL, MAX_THREAT_LEVEL)
		if new_val != old_val:
			regions[region_id]["threat_level"] = new_val
			threat_level_changed.emit(region_id, new_val)
			
			if new_val >= MAX_THREAT_LEVEL:
				_trigger_maximum_threat_event(region_id)

## Decays threat in a region, usually from completing missions or time passing if guarded.
func decay_threat(region_id: String, amount: int = 1) -> void:
	if regions.has(region_id):
		var old_val = regions[region_id]["threat_level"]
		var new_val = clamp(old_val - amount, MIN_THREAT_LEVEL, MAX_THREAT_LEVEL)
		if new_val != old_val:
			regions[region_id]["threat_level"] = new_val
			threat_level_changed.emit(region_id, new_val)

## Timer callback to decay threats in regions with captured outposts, and increase in neglected ones.
func _on_threat_decay_tick() -> void:
	for rid in regions.keys():
		var r = regions[rid]
		if not r["is_unlocked"]: continue
		
		var captured_outposts = 0
		var total_outposts = r["outposts"].size()
		for out_data in r["outposts"].values():
			if out_data["captured"]:
				captured_outposts += 1
				
		if total_outposts > 0 and captured_outposts == total_outposts:
			decay_threat(rid, 1)
		elif captured_outposts == 0:
			if randf() > 0.5:
				add_threat(rid, 1)

## Captures an outpost for the player, unlocking passive benefits.
func capture_outpost(region_id: String, outpost_id: String) -> bool:
	if regions.has(region_id):
		var r = regions[region_id]
		if r["outposts"].has(outpost_id):
			if not r["outposts"][outpost_id]["captured"]:
				r["outposts"][outpost_id]["captured"] = true
				
				var faction = r["outposts"][outpost_id]["faction"]
				if global_faction_influence.has(faction):
					global_faction_influence[faction] += 10
					
				outpost_captured.emit(region_id, outpost_id)
				decay_threat(region_id, 2)
				return true
	return false

## Gets a list of available region routes based on unlocked status.
func get_available_routes() -> Array[Dictionary]:
	var routes: Array[Dictionary] = []
	for rid in regions.keys():
		if regions[rid]["is_unlocked"]:
			routes.append(regions[rid])
	return routes

## Spawns a caravan defense mission in the target region.
func spawn_caravan_mission(region_id: String) -> void:
	if not regions.has(region_id): return
	
	var mission = {
		"id": "caravan_" + str(Time.get_ticks_msec()),
		"region_id": region_id,
		"cargo_value": randi_range(500, 2000),
		"faction": ["merchants", "mages_guild", "royal"][randi() % 3],
		"active": true
	}
	active_caravans.append(mission)
	caravan_mission_spawned.emit(region_id)

## Completes a caravan mission.
func complete_caravan_mission(mission_id: String, success: bool) -> void:
	for i in range(active_caravans.size()):
		var m = active_caravans[i]
		if m["id"] == mission_id and m["active"]:
			m["active"] = false
			var rewards = {}
			if success:
				rewards["gold"] = m["cargo_value"]
				rewards["faction_influence"] = 15
				if global_faction_influence.has(m["faction"]):
					global_faction_influence[m["faction"]] += 15
				decay_threat(m["region_id"], 1)
			else:
				add_threat(m["region_id"], 1)
				if global_faction_influence.has(m["faction"]):
					global_faction_influence[m["faction"]] -= 10
					
			caravan_mission_completed.emit(success, rewards)
			active_caravans.remove_at(i)
			return

func _trigger_maximum_threat_event(region_id: String) -> void:
	push_warning("Region %s has reached MAXIMUM THREAT! Elite boss invasion imminent." % region_id)
	if is_instance_valid(get_tree()):
		var events = get_tree().get_nodes_in_group("world_event_system")
		if events.size() > 0:
			if events[0].has_method("trigger_event_by_id"):
				events[0].trigger_event_by_id("elite_invasion_" + region_id)

## Returns the aggregate faction standing across all outposts and missions.
func get_faction_influence(faction: String) -> int:
	return global_faction_influence.get(faction, 0)

## Saves the state of the world manager to a dictionary format.
func save_state() -> Dictionary:
	return {
		"regions": regions.duplicate(true),
		"global_faction_influence": global_faction_influence.duplicate(true),
		"active_caravans": active_caravans.duplicate(true),
		"version": "1.0"
	}

## Loads the state of the world manager from a dictionary.
func load_state(data: Dictionary) -> void:
	if data.has("regions"):
		regions = data["regions"].duplicate(true)
	if data.has("global_faction_influence"):
		global_faction_influence = data["global_faction_influence"].duplicate(true)
	if data.has("active_caravans"):
		active_caravans = data["active_caravans"].duplicate(true)

# ---------------------------------------------------------
# Padding with extensive utility functions to fully support the system
# ---------------------------------------------------------

func get_region_threat_multiplier(region_id: String) -> float:
	if not regions.has(region_id): return 1.0
	var level = regions[region_id]["threat_level"]
	return 1.0 + (level - 1) * 0.25

func get_region_elite_chance(region_id: String) -> float:
	if not regions.has(region_id): return 0.0
	var level = regions[region_id]["threat_level"]
	return (level - 1) * 0.10

func get_fast_travel_nodes() -> Array[String]:
	var ft_nodes: Array[String] = []
	for rid in regions.keys():
		var r = regions[rid]
		if r["is_unlocked"]:
			var captured_count = 0
			for out_data in r["outposts"].values():
				if out_data["captured"]:
					captured_count += 1
			if captured_count >= r["outposts"].size() and r["outposts"].size() > 0:
				ft_nodes.append(rid)
	return ft_nodes

func is_fast_travel_available(from_region: String, to_region: String) -> bool:
	var ft_nodes = get_fast_travel_nodes()
	return from_region in ft_nodes and to_region in ft_nodes

func get_unlocked_regions_count() -> int:
	var count = 0
	for rid in regions.keys():
		if regions[rid]["is_unlocked"]:
			count += 1
	return count

func get_total_regions_count() -> int:
	return regions.size()

func get_captured_outposts_count() -> int:
	var count = 0
	for r in regions.values():
		for out in r["outposts"].values():
			if out["captured"]: count += 1
	return count

func get_total_outposts_count() -> int:
	var count = 0
	for r in regions.values():
		count += r["outposts"].size()
	return count

func get_faction_bonus_multiplier(faction: String) -> float:
	var inf = get_faction_influence(faction)
	if inf < 0: return 0.8
	if inf < 50: return 1.0
	if inf < 150: return 1.15
	if inf < 300: return 1.3
	return 1.5

func trigger_global_faction_event(faction: String) -> void:
	if global_faction_influence.has(faction):
		global_faction_influence[faction] += randi_range(-20, 20)
		for rid in regions.keys():
			var r = regions[rid]
			for out in r["outposts"].values():
				if out["faction"] == faction and not out["captured"]:
					if randf() > 0.5:
						add_threat(rid, 1)

func process_offline_progress(seconds_elapsed: int) -> Dictionary:
	var ticks = int(seconds_elapsed / 300.0)
	var generated_gold = 0
	for i in range(ticks):
		_on_threat_decay_tick()
		for r in regions.values():
			for out in r["outposts"].values():
				if out["captured"]:
					var y = out["resource_yield"]
					generated_gold += y
					
	return {
		"gold_earned": generated_gold,
		"ticks_processed": ticks
	}
