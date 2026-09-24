class_name CityHubManager
extends Node

## CityHubManager — Менеджер Центрального Городского Хаба
## Управляет 20 постоянными городскими зданиями в 5 категориях
## (Военные, Экономические, Магические, Социальные, Секретные фракционные).
## Предоставляет пассивные глобальные бонусы для экспедиций и боев.

signal building_upgraded(building_id: String, new_level: int)
signal building_unlocked(building_id: String)
signal hub_production_collected(resources: Dictionary)

# Состояние прокачки зданий: { "arsenal": { "level": 1 }, ... }
var buildings: Dictionary = {}
var buildings_database: Dictionary = {}
var production_accumulated: Dictionary = { "gold": 0, "glory": 0 }
var last_tick_time: int = 0
var tick_interval: int = 60 # секунды

func _init() -> void:
	load_buildings_database()
	_init_buildings_state()

func _ready() -> void:
	add_to_group("city_hub_manager")
	if buildings_database.is_empty():
		load_buildings_database()
	if buildings.is_empty():
		_init_buildings_state()

func load_buildings_database(path: String = "res://data/city_buildings.json") -> void:
	if not FileAccess.file_exists(path):
		return
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var json = JSON.new()
		var err = json.parse(file.get_as_text())
		if err == OK and json.data is Dictionary:
			buildings_database = json.data.get("buildings", {})

func _init_buildings_state() -> void:
	for b_id in buildings_database.keys():
		if not buildings.has(b_id):
			var b_data = buildings_database[b_id]
			var is_unlocked = bool(b_data.get("unlocked", true))
			buildings[b_id] = {
				"level": 1 if is_unlocked else 0,
				"unlocked": is_unlocked
			}

## Проверить доступность улучшения здания
func can_upgrade(b_id: String, available_glory: int) -> bool:
	if not buildings.has(b_id) or not buildings_database.has(b_id):
		return false
	var current_lvl = int(buildings[b_id].get("level", 0))
	var max_lvl = int(buildings_database[b_id].get("max_level", 5))
	if current_lvl >= max_lvl:
		return false
	var cost = get_upgrade_cost(b_id)
	return available_glory >= cost

## Получить стоимость улучшения в Очках Славы
func get_upgrade_cost(b_id: String) -> int:
	if not buildings_database.has(b_id):
		return 999999
	var costs: Array = buildings_database[b_id].get("costs_glory", [50, 100, 200, 350, 500])
	var current_lvl = int(buildings.get(b_id, {}).get("level", 0))
	if current_lvl < costs.size():
		return int(costs[current_lvl])
	return int(costs[costs.size() - 1])

## Улучшить здание
func upgrade_building(b_id: String) -> bool:
	if not buildings.has(b_id):
		return false
	var current_lvl = int(buildings[b_id].get("level", 0))
	var max_lvl = int(buildings_database.get(b_id, {}).get("max_level", 5))
	if current_lvl >= max_lvl:
		return false
	
	buildings[b_id]["level"] = current_lvl + 1
	buildings[b_id]["unlocked"] = true
	building_upgraded.emit(b_id, current_lvl + 1)
	return true

## Разблокировать секретное здание при достижении репутации с фракцией
func check_faction_unlocks(faction_id: String, tier_name: String) -> void:
	for b_id in buildings_database.keys():
		var b_data = buildings_database[b_id]
		if b_data.has("required_reputation"):
			var req = b_data["required_reputation"]
			if req.get("faction") == faction_id:
				var req_tier = str(req.get("tier", "Honored"))
				if _is_tier_sufficient(tier_name, req_tier):
					if not buildings.has(b_id) or not bool(buildings[b_id].get("unlocked", false)):
						buildings[b_id] = { "level": 1, "unlocked": true }
						building_unlocked.emit(b_id)

func _is_tier_sufficient(current_tier: String, required_tier: String) -> bool:
	var tiers = ["Hated", "Hostile", "Neutral", "Friendly", "Honored", "Revered", "Exalted"]
	var c_idx = tiers.find(current_tier)
	var r_idx = tiers.find(required_tier)
	return c_idx >= r_idx and c_idx >= 0 and r_idx >= 0

func get_building_info(b_id: String) -> Dictionary:
	var info: Dictionary = {}
	if buildings_database.has(b_id):
		info = buildings_database[b_id].duplicate(true)
	if buildings.has(b_id):
		for k in buildings[b_id].keys():
			info[k] = buildings[b_id][k]
	return info

func get_all_buildings() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for b_id in buildings_database.keys():
		list.append(get_building_info(b_id))
	return list

## Рассчитать суммарные глобальные пассивные бонусы города для боя
func get_aggregate_bonuses() -> Dictionary:
	var agg: Dictionary = {
		"starting_gold_bonus": 0,
		"base_starting_lives": 0,
		"interest_rate_bonus": 0.0,
		"interest_cap_bonus": 0,
		"spell_cost_discount_pct": 0.0,
		"glory_gain_mult": 1.0,
		"hero_xp_gain_mult": 1.0,
		"archer_range_mult": 1.0,
		"archer_crit_chance": 0.0,
		"dot_damage_mult": 1.0,
		"elemental_damage_mult": 1.0,
		"boss_damage_mult": 1.0,
		"reputation_gain_mult": 1.0,
		"leak_shield_charges": 0
	}

	for b_id in buildings.keys():
		var b_state = buildings[b_id]
		var lvl = int(b_state.get("level", 0))
		if lvl <= 0 or not bool(b_state.get("unlocked", false)):
			continue
		if not buildings_database.has(b_id):
			continue

		var mods = buildings_database[b_id].get("modifiers", {})
		var factor = float(lvl)

		if mods.has("starting_gold_bonus"):
			agg["starting_gold_bonus"] += int(mods["starting_gold_bonus"]) * lvl
		if mods.has("base_starting_lives"):
			agg["base_starting_lives"] += int(mods["base_starting_lives"]) * lvl
		if mods.has("interest_rate_bonus"):
			agg["interest_rate_bonus"] += float(mods["interest_rate_bonus"]) * factor * 0.5
		if mods.has("interest_cap_bonus"):
			agg["interest_cap_bonus"] += int(mods["interest_cap_bonus"]) * lvl
		if mods.has("spell_cost_discount_pct"):
			agg["spell_cost_discount_pct"] = min(0.40, agg["spell_cost_discount_pct"] + float(mods["spell_cost_discount_pct"]) * factor * 0.2)
		if mods.has("glory_gain_mult"):
			agg["glory_gain_mult"] += (float(mods["glory_gain_mult"]) - 1.0) * factor * 0.2
		if mods.has("hero_xp_gain_mult"):
			agg["hero_xp_gain_mult"] += (float(mods["hero_xp_gain_mult"]) - 1.0) * factor * 0.2
		if mods.has("archer_range_mult"):
			agg["archer_range_mult"] += (float(mods["archer_range_mult"]) - 1.0) * factor * 0.2
		if mods.has("archer_crit_chance"):
			agg["archer_crit_chance"] += float(mods["archer_crit_chance"]) * factor * 0.2
		if mods.has("dot_damage_mult"):
			agg["dot_damage_mult"] += (float(mods["dot_damage_mult"]) - 1.0) * factor * 0.2
		if mods.has("elemental_damage_mult"):
			agg["elemental_damage_mult"] += (float(mods["elemental_damage_mult"]) - 1.0) * factor * 0.2
		if mods.has("boss_damage_mult"):
			agg["boss_damage_mult"] += (float(mods["boss_damage_mult"]) - 1.0) * factor * 0.2
		if mods.has("reputation_gain_mult"):
			agg["reputation_gain_mult"] += (float(mods["reputation_gain_mult"]) - 1.0) * factor * 0.2
		if mods.has("leak_shield_charges"):
			agg["leak_shield_charges"] += int(mods["leak_shield_charges"])

	return agg

## Применить модификаторы города к игре
func apply_city_bonuses_to_game(game_manager: Node) -> void:
	if not is_instance_valid(game_manager):
		return
	var bonuses = get_aggregate_bonuses()
	if bonuses["starting_gold_bonus"] > 0 and "gold" in game_manager:
		game_manager.gold += bonuses["starting_gold_bonus"]
	if bonuses["base_starting_lives"] > 0 and "lives" in game_manager:
		game_manager.lives += bonuses["base_starting_lives"]

func process_city_tick() -> void:
	var bonuses = get_aggregate_bonuses()
	var gold_produced = 20
	if buildings.has("town_hall"):
		gold_produced += int(buildings["town_hall"].get("level", 0)) * 15
	production_accumulated["gold"] = int(production_accumulated.get("gold", 0)) + gold_produced
	hub_production_collected.emit(production_accumulated)

func save_city_state() -> Dictionary:
	return {
		"buildings": buildings.duplicate(true),
		"production_accumulated": production_accumulated.duplicate(true)
	}

func load_city_state(data: Dictionary) -> void:
	if data.has("buildings") and data["buildings"] is Dictionary:
		buildings = data["buildings"].duplicate(true)
	if data.has("production_accumulated") and data["production_accumulated"] is Dictionary:
		production_accumulated = data["production_accumulated"].duplicate(true)
