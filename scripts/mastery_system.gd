class_name MasterySystem
extends Node

## MasterySystem — Система мастерства башен и врагов (Бестиарий)
## Отслеживает опыт башен (от использования и убийств) и убийства каждого типа врагов.
## Открывает пассивные бонусы к урону, дальности, криту и карточки в бестиарии.

signal tower_mastery_leveled_up(tower_type: String, new_level: int)
signal enemy_mastery_unlocked(enemy_type: String, new_tier: int)

var tower_mastery_xp: Dictionary = {}
var enemy_kill_counts: Dictionary = {}
var boss_defeats: Dictionary = {}

var mastery_config: Dictionary = {}

func _init() -> void:
	load_mastery_config()

func _ready() -> void:
	add_to_group("mastery_system")
	if mastery_config.is_empty():
		load_mastery_config()

func load_mastery_config(path: String = "res://data/mastery_data.json") -> void:
	if not FileAccess.file_exists(path):
		return
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var json = JSON.new()
		var err = json.parse(file.get_as_text())
		if err == OK and json.data is Dictionary:
			mastery_config = json.data

## Начислить опыт мастерства башне
func record_tower_kill(tower_type: String, xp: int = 1) -> void:
	var old_lvl = get_tower_mastery_level(tower_type)
	tower_mastery_xp[tower_type] = int(tower_mastery_xp.get(tower_type, 0)) + xp
	var new_lvl = get_tower_mastery_level(tower_type)
	if new_lvl > old_lvl:
		tower_mastery_leveled_up.emit(tower_type, new_lvl)

## Получить текущий уровень мастерства башни (0..5)
func get_tower_mastery_level(tower_type: String) -> int:
	var xp = int(tower_mastery_xp.get(tower_type, 0))
	var levels = mastery_config.get("tower_mastery_levels", [])
	var current_lvl = 0
	for item in levels:
		var req = int(item.get("xp_required", 100))
		if xp >= req:
			current_lvl = int(item.get("level", 1))
	return current_lvl

## Начислить убийство определенного врага
func record_enemy_kill(enemy_type: String) -> void:
	var old_tier = get_enemy_mastery_tier(enemy_type)
	enemy_kill_counts[enemy_type] = int(enemy_kill_counts.get(enemy_type, 0)) + 1
	var new_tier = get_enemy_mastery_tier(enemy_type)
	if new_tier > old_tier:
		enemy_mastery_unlocked.emit(enemy_type, new_tier)

## Получить тир мастерства против конкретного врага (0..3)
func get_enemy_mastery_tier(enemy_type: String) -> int:
	var kills = int(enemy_kill_counts.get(enemy_type, 0))
	var tiers = mastery_config.get("enemy_mastery_tiers", [])
	var current_tier = 0
	for item in tiers:
		var req = int(item.get("kills_required", 25))
		if kills >= req:
			current_tier = int(item.get("tier", 1))
	return current_tier

## Получить бонус к урону против указанного врага
func get_damage_bonus_vs_enemy(enemy_type: String) -> float:
	var tier = get_enemy_mastery_tier(enemy_type)
	match tier:
		1: return 0.0
		2: return 0.02 # +2% урона
		3: return 0.05 # +5% урона
		_: return 0.0

## Получить все пассивные бонусы башни по уровню мастерства
func get_tower_mastery_modifiers(tower_type: String) -> Dictionary:
	var lvl = get_tower_mastery_level(tower_type)
	var mods = {
		"damage_mult": 1.0,
		"range_mult": 1.0,
		"attack_speed_mult": 1.0,
		"crit_chance": 0.0,
		"upgrade_discount": 0.0
	}
	var levels = mastery_config.get("tower_mastery_levels", [])
	for item in levels:
		if int(item.get("level", 1)) <= lvl:
			var m = item.get("modifiers", {})
			if m.has("damage_mult"): mods["damage_mult"] *= float(m["damage_mult"])
			if m.has("range_mult"): mods["range_mult"] *= float(m["range_mult"])
			if m.has("attack_speed_mult"): mods["attack_speed_mult"] *= float(m["attack_speed_mult"])
			if m.has("crit_chance"): mods["crit_chance"] += float(m["crit_chance"])
			if m.has("upgrade_discount"): mods["upgrade_discount"] = max(mods["upgrade_discount"], float(m["upgrade_discount"]))
	return mods

func record_boss_defeat(boss_id: String, conditions: Dictionary = {}) -> void:
	boss_defeats[boss_id] = {
		"count": int(boss_defeats.get(boss_id, {}).get("count", 0)) + 1,
		"last_conditions": conditions
	}

func get_mastery_perks() -> Dictionary:
	var perks: Dictionary = {}
	for t in tower_mastery_xp.keys():
		perks[t] = get_tower_mastery_modifiers(t)
	return perks

func save_state() -> Dictionary:
	return {
		"tower_mastery_xp": tower_mastery_xp.duplicate(),
		"enemy_kill_counts": enemy_kill_counts.duplicate(),
		"boss_defeats": boss_defeats.duplicate(true)
	}

func load_state(data: Dictionary) -> void:
	if data.has("tower_mastery_xp") and data["tower_mastery_xp"] is Dictionary:
		tower_mastery_xp = data["tower_mastery_xp"].duplicate()
	if data.has("enemy_kill_counts") and data["enemy_kill_counts"] is Dictionary:
		enemy_kill_counts = data["enemy_kill_counts"].duplicate()
	if data.has("boss_defeats") and data["boss_defeats"] is Dictionary:
		boss_defeats = data["boss_defeats"].duplicate(true)
