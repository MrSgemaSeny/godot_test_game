class_name MetaManager
extends Node

signal glory_changed(amount: int)
signal meta_upgraded(upgrade_id: String, new_level: int)
signal map_stars_changed(biome_id: String, stars: int)

const SAVE_PATH: String = "user://meta_save.json"
const CURRENT_SCHEMA_VERSION: int = 2

# === Persistent State ===
var save_path: String = SAVE_PATH
var schema_version: int = CURRENT_SCHEMA_VERSION
var glory_points: int = 0
var upgrades: Dictionary = {}
var map_stars: Dictionary = {}
var unlocked_artifacts: Array = []
var equipped_artifacts: Array = []
var statistics: Dictionary = {
	"total_games_played": 0,
	"total_victories": 0,
	"total_enemies_killed": 0,
	"total_gold_earned": 0,
	"total_glory_earned": 0
}

var meta_tree_data: Array = []

func _enter_tree() -> void:
	add_to_group("meta_manager")

func _ready() -> void:
	load_meta_tree_data()
	load_data()

func load_meta_tree_data() -> void:
	if not FileAccess.file_exists("res://data/meta_tree.json"):
		return
	var file = FileAccess.open("res://data/meta_tree.json", FileAccess.READ)
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Array:
		meta_tree_data = json.data

# === Save & Load Interface Contract ===

## Interface Contract per PROJECT.md: loads and migrates save storage
func load_data() -> void:
	if not FileAccess.file_exists(save_path):
		_reset_to_clean_defaults()
		return
		
	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		_reset_to_clean_defaults()
		return
		
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK or not (json.data is Dictionary):
		_reset_to_clean_defaults()
		return
		
	var raw_data: Dictionary = json.data
	var loaded_version: int = int(raw_data.get("schema_version", 1))
	
	if loaded_version < CURRENT_SCHEMA_VERSION:
		raw_data = migrate_save_dict(raw_data, loaded_version, CURRENT_SCHEMA_VERSION)
		# Persist migrated file immediately so subsequent boots are natively v2
		_write_dict_to_storage(raw_data)
		
	_apply_dict_to_state(raw_data)
	glory_changed.emit(glory_points)

## Interface Contract per PROJECT.md: returns full dictionary and persists to disk
func save_data() -> Dictionary:
	var data: Dictionary = {
		"schema_version": CURRENT_SCHEMA_VERSION,
		"glory_points": glory_points,
		"upgrades": upgrades.duplicate(true),
		"map_stars": map_stars.duplicate(true),
		"unlocked_artifacts": unlocked_artifacts.duplicate(true),
		"equipped_artifacts": equipped_artifacts.duplicate(true),
		"statistics": statistics.duplicate(true)
	}
	_write_dict_to_storage(data)
	return data

## Backward-compatibility alias for existing codebase and test calls
func load_meta() -> void:
	load_data()

## Backward-compatibility alias for existing codebase and test calls
func save_meta() -> void:
	save_data()

# === Migration Engine ===

## Pure functional migration pipeline: testable headlessly without disk side-effects
func migrate_save_dict(raw_data: Dictionary, from_version: int, to_version: int) -> Dictionary:
	var migrated: Dictionary = raw_data.duplicate(true)
	
	if from_version < 2 and to_version >= 2:
		migrated["schema_version"] = 2
		# Cleanly preserve existing progression
		migrated["glory_points"] = int(raw_data.get("glory_points", 0))
		migrated["upgrades"] = raw_data.get("upgrades", {}).duplicate(true)
		
		# Seamlessly initialize new v2 systems if absent
		if not migrated.has("map_stars") or not (migrated["map_stars"] is Dictionary):
			migrated["map_stars"] = {}
		if not migrated.has("unlocked_artifacts") or not (migrated["unlocked_artifacts"] is Array):
			migrated["unlocked_artifacts"] = []
		if not migrated.has("equipped_artifacts") or not (migrated["equipped_artifacts"] is Array):
			migrated["equipped_artifacts"] = []
		if not migrated.has("statistics") or not (migrated["statistics"] is Dictionary):
			migrated["statistics"] = {
				"total_games_played": 0,
				"total_victories": 0,
				"total_enemies_killed": 0,
				"total_gold_earned": 0,
				"total_glory_earned": int(raw_data.get("glory_points", 0))
			}
			
	return migrated

func _apply_dict_to_state(data: Dictionary) -> void:
	schema_version = int(data.get("schema_version", CURRENT_SCHEMA_VERSION))
	glory_points = int(data.get("glory_points", 0))
	upgrades = data.get("upgrades", {}).duplicate(true)
	map_stars = data.get("map_stars", {}).duplicate(true)
	unlocked_artifacts = data.get("unlocked_artifacts", []).duplicate(true)
	equipped_artifacts = data.get("equipped_artifacts", []).duplicate(true)
	statistics = data.get("statistics", {}).duplicate(true)

func _write_dict_to_storage(data: Dictionary) -> void:
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))

func _reset_to_clean_defaults() -> void:
	schema_version = CURRENT_SCHEMA_VERSION
	glory_points = 0
	upgrades = {}
	map_stars = {}
	unlocked_artifacts = []
	equipped_artifacts = []
	statistics = {
		"total_games_played": 0,
		"total_victories": 0,
		"total_enemies_killed": 0,
		"total_gold_earned": 0,
		"total_glory_earned": 0
	}

func reset_meta() -> void:
	_reset_to_clean_defaults()
	save_data()
	glory_changed.emit(glory_points)

func add_glory(amount: int) -> void:
	glory_points += amount
	if statistics.has("total_glory_earned"):
		statistics["total_glory_earned"] += amount
	save_data()
	glory_changed.emit(glory_points)

func get_level(upgrade_id: String) -> int:
	return upgrades.get(upgrade_id, 0)

func buy_upgrade(upgrade_id: String) -> bool:
	for item in meta_tree_data:
		if item.get("id") == upgrade_id:
			var cur_lvl = get_level(upgrade_id)
			var max_lvl = item.get("max_level", 1)
			if cur_lvl >= max_lvl:
				return false
			var cost = item.get("cost_per_level", 10) * (cur_lvl + 1)
			if glory_points >= cost:
				glory_points -= cost
				upgrades[upgrade_id] = cur_lvl + 1
				save_data()
				glory_changed.emit(glory_points)
				meta_upgraded.emit(upgrade_id, cur_lvl + 1)
				return true
	return false

# === Map Stars & Artifact Accessors ===

func get_map_stars(biome_id: String) -> int:
	return int(map_stars.get(biome_id, 0))

func set_map_stars(biome_id: String, stars: int) -> void:
	var prev_stars = get_map_stars(biome_id)
	if stars > prev_stars:
		map_stars[biome_id] = stars
		save_data()
		map_stars_changed.emit(biome_id, stars)

func record_map_stars(biome_id: String, stars: int) -> void:
	set_map_stars(biome_id, stars)

func record_victory(biome_id: String = "", stars: int = 3) -> void:
	if statistics.has("total_victories"):
		statistics["total_victories"] += 1
	if biome_id != "":
		set_map_stars(biome_id, stars)
	else:
		save_data()

func get_total_stars() -> int:
	var total = 0
	for b in map_stars:
		total += int(map_stars[b])
	return total

func unlock_artifact(artifact_id: String) -> bool:
	if not (artifact_id in unlocked_artifacts):
		unlocked_artifacts.append(artifact_id)
		save_data()
		return true
	return false

func is_artifact_unlocked(artifact_id: String) -> bool:
	return artifact_id in unlocked_artifacts

# === Active Meta Modifiers ===

func get_starting_gold_bonus() -> int:
	return get_level("meta_starting_gold") * 50

func get_bonus_lives() -> int:
	return get_level("meta_bonus_lives") * 5

func get_base_damage_mult() -> float:
	return get_level("meta_base_damage") * 0.08

func get_starting_research_bonus() -> int:
	return get_level("meta_research_start") * 1
