class_name MetaManager
extends Node

signal glory_changed(amount: int)
signal meta_upgraded(upgrade_id: String, new_level: int)

const SAVE_PATH: String = "user://meta_save.json"

var glory_points: int = 0
var upgrades: Dictionary = {}
var meta_tree_data: Array = []

func _enter_tree() -> void:
	add_to_group("meta_manager")

func _ready() -> void:
	load_meta_tree_data()
	load_meta()

func load_meta_tree_data() -> void:
	if not FileAccess.file_exists("res://data/meta_tree.json"):
		return
	var file = FileAccess.open("res://data/meta_tree.json", FileAccess.READ)
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Array:
		meta_tree_data = json.data

func load_meta() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		glory_points = 0
		upgrades = {}
		return
		
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		glory_points = json.data.get("glory_points", 0)
		upgrades = json.data.get("upgrades", {})
	glory_changed.emit(glory_points)

func save_meta() -> void:
	var data = {
		"glory_points": glory_points,
		"upgrades": upgrades
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))

func reset_meta() -> void:
	glory_points = 0
	upgrades = {}
	save_meta()
	glory_changed.emit(glory_points)

func add_glory(amount: int) -> void:
	glory_points += amount
	save_meta()
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
				save_meta()
				glory_changed.emit(glory_points)
				meta_upgraded.emit(upgrade_id, cur_lvl + 1)
				return true
	return false

func get_starting_gold_bonus() -> int:
	return get_level("meta_starting_gold") * 50

func get_bonus_lives() -> int:
	return get_level("meta_bonus_lives") * 5

func get_base_damage_mult() -> float:
	return get_level("meta_base_damage") * 0.08

func get_starting_research_bonus() -> int:
	return get_level("meta_research_start") * 1
