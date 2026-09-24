class_name RuneSocketSystem
extends Node

## RuneSocketSystem — Система инкрустации рун в башни
## Поддерживает 6 категорий рун (Attack, Support, Control, Elemental, Survival, Exotic),
## слоты инкрустации (до 3 слотов на башню), рунические слова (Runewords) и слияние (Fusion).

signal rune_socketed(tower: Node, slot_idx: int, rune_id: String)
signal rune_unsocketed(tower: Node, slot_idx: int, rune_id: String)
signal runes_fused(input_rune: String, result_rune: String)
signal runeword_activated(tower: Node, runeword_name: String)

# База данных рун: { "rune_blade_1": { ... } }
var runes_db: Dictionary = {}

# Рунические слова (комбинации категорий или типов рун в слотах одной башни)
var runewords_recipes: Array[Dictionary] = [
	{
		"name": "Ярость Бури (Storm Fury)",
		"required_categories": ["elemental", "attack"],
		"bonus_desc": "+25% цепной урон молнией при каждом критическом попадании",
		"modifiers": { "chain_on_crit": true, "bonus_damage_mult": 1.25 }
	},
	{
		"name": "Абсолютная Крепость (Citadel Bastion)",
		"required_categories": ["survival", "support"],
		"bonus_desc": "Башня дает ауру защиты +20% HP базе и замедляет врагов вокруг на 20%",
		"modifiers": { "citadel_slow_aura": 0.20, "leak_shield": 1 }
	},
	{
		"name": "Хаос Стихий (Elemental Cataclysm)",
		"required_categories": ["elemental", "control"],
		"bonus_desc": "Периодический урон стихий замораживает и поджигает одновременно",
		"modifiers": { "elemental_combo": true, "dot_amplify": 1.40 }
	},
	{
		"name": "Смертоносная Тень (Deadly Shadow)",
		"required_categories": ["attack", "exotic"],
		"bonus_desc": "Каждая атака башни игнорирует броню и наносит чистый урон боссам",
		"modifiers": { "pure_damage_bosses": true, "boss_bonus": 1.50 }
	}
]

func _init() -> void:
	load_runes_database()

func _ready() -> void:
	add_to_group("rune_socket_system")
	if runes_db.is_empty():
		load_runes_database()

func load_runes_database(path: String = "res://data/runes_database.json") -> void:
	if not FileAccess.file_exists(path):
		return
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var json = JSON.new()
		var err = json.parse(file.get_as_text())
		if err == OK and json.data is Dictionary:
			var list = json.data.get("runes", [])
			for r in list:
				if r is Dictionary and r.has("id"):
					runes_db[r["id"]] = r

func get_rune_info(rune_id: String) -> Dictionary:
	if runes_db.has(rune_id):
		return runes_db[rune_id]
	return {}

func get_all_runes() -> Array[Dictionary]:
	var res: Array[Dictionary] = []
	for k in runes_db:
		res.append(runes_db[k])
	return res

## Проверить доступное количество слотов на башне (1 слот по умолчанию, +1 на 3 уровне, +1 на 5 уровне)
func get_max_sockets_for_tower(tower_node: Node) -> int:
	if not is_instance_valid(tower_node):
		return 1
	var lvl = int(tower_node.get("current_level")) if "current_level" in tower_node else 1
	if lvl >= 5:
		return 3
	elif lvl >= 3:
		return 2
	return 1

## Получить массив вставленных рун в башню
func get_socketed_runes(tower_node: Node) -> Array:
	if not is_instance_valid(tower_node):
		return []
	if tower_node.has_meta("socketed_runes"):
		return tower_node.get_meta("socketed_runes")
	var initial: Array = ["", "", ""]
	tower_node.set_meta("socketed_runes", initial)
	return initial

## Установить руну в указанный слот башни (0..2)
func socket_rune(tower_node: Node, slot_idx: int, rune_id: String) -> bool:
	if not is_instance_valid(tower_node):
		return false
	if not runes_db.has(rune_id):
		return false
	var max_slots = get_max_sockets_for_tower(tower_node)
	if slot_idx < 0 or slot_idx >= max_slots:
		return false

	var sockets = get_socketed_runes(tower_node)
	while sockets.size() < 3:
		sockets.append("")
		
	# Если слот уже занят, сначала извлекаем старую руну
	if not sockets[slot_idx].is_empty():
		unsocket_rune(tower_node, slot_idx)

	sockets[slot_idx] = rune_id
	tower_node.set_meta("socketed_runes", sockets)

	# Сохраняем исходные параметры до модификации, если еще не сохранены
	_backup_tower_base_stats(tower_node)
	_reapply_tower_runes(tower_node)

	rune_socketed.emit(tower_node, slot_idx, rune_id)
	
	# Проверяем активацию Runewords
	var active_rw = get_active_runewords(tower_node)
	for rw in active_rw:
		runeword_activated.emit(tower_node, rw.get("name", ""))
		
	return true

## Извлечь руну из слота
func unsocket_rune(tower_node: Node, slot_idx: int) -> Dictionary:
	if not is_instance_valid(tower_node):
		return {}
	var sockets = get_socketed_runes(tower_node)
	if slot_idx < 0 or slot_idx >= sockets.size():
		return {}
	var rune_id = sockets[slot_idx]
	if rune_id.is_empty():
		return {}

	sockets[slot_idx] = ""
	tower_node.set_meta("socketed_runes", sockets)
	_reapply_tower_runes(tower_node)

	rune_unsocketed.emit(tower_node, slot_idx, rune_id)
	return get_rune_info(rune_id)

func _backup_tower_base_stats(tower_node: Node) -> void:
	if not tower_node.has_meta("rune_base_stats"):
		var base = {
			"damage": float(tower_node.get("damage")) if "damage" in tower_node else 10.0,
			"range_radius": float(tower_node.get("range_radius")) if "range_radius" in tower_node else 150.0,
			"attack_speed": float(tower_node.get("attack_speed")) if "attack_speed" in tower_node else 1.0
		}
		tower_node.set_meta("rune_base_stats", base)

func _reapply_tower_runes(tower_node: Node) -> void:
	if not is_instance_valid(tower_node):
		return
	if not tower_node.has_meta("rune_base_stats"):
		return

	var base = tower_node.get_meta("rune_base_stats")
	var base_dmg = float(base.get("damage", 10.0))
	var base_rng = float(base.get("range_radius", 150.0))
	var base_spd = float(base.get("attack_speed", 1.0))

	var dmg_mult: float = 1.0
	var rng_mult: float = 1.0
	var spd_mult: float = 1.0
	var extra_crit: float = 0.0

	var sockets = get_socketed_runes(tower_node)
	for r_id in sockets:
		if r_id.is_empty() or not runes_db.has(r_id):
			continue
		var r = runes_db[r_id]
		var mods = r.get("modifiers", {})
		if mods.has("damage_mult"):
			dmg_mult *= float(mods["damage_mult"])
		if mods.has("range_mult"):
			rng_mult *= float(mods["range_mult"])
		if mods.has("attack_speed_mult"):
			spd_mult *= float(mods["attack_speed_mult"])
		if mods.has("crit_chance"):
			extra_crit += float(mods["crit_chance"])

	# Учитываем активные Runewords
	var rwords = get_active_runewords(tower_node)
	for rw in rwords:
		var r_mods = rw.get("modifiers", {})
		if r_mods.has("bonus_damage_mult"):
			dmg_mult *= float(r_mods["bonus_damage_mult"])

	if "damage" in tower_node:
		tower_node.damage = int(round(base_dmg * dmg_mult))
	if "range_radius" in tower_node:
		tower_node.range_radius = base_rng * rng_mult
	if "attack_speed" in tower_node:
		tower_node.attack_speed = base_spd * spd_mult

## Проверка активных рунических комбинаций (Runewords)
func get_active_runewords(tower_node: Node) -> Array[Dictionary]:
	if not is_instance_valid(tower_node):
		return []
	var sockets = get_socketed_runes(tower_node)
	var present_categories: Array[String] = []
	for r_id in sockets:
		if not r_id.is_empty() and runes_db.has(r_id):
			var cat = str(runes_db[r_id].get("category", "")).to_lower()
			if not present_categories.has(cat):
				present_categories.append(cat)

	var active_rw: Array[Dictionary] = []
	for rw in runewords_recipes:
		var reqs: Array = rw.get("required_categories", [])
		var matches_all = true
		for req in reqs:
			if not present_categories.has(str(req).to_lower()):
				matches_all = false
				break
		if matches_all and not reqs.is_empty():
			active_rw.append(rw)

	return active_rw

## Слияние рун: 3 одинаковые руны Tier N превращаются в 1 руну Tier N+1
func fuse_runes(rune_id: String) -> String:
	if not runes_db.has(rune_id):
		return rune_id + "_upgraded"
	var r = runes_db[rune_id]
	var current_tier = int(r.get("tier", 1))
	var next_tier = current_tier + 1
	var base_id = rune_id
	if base_id.ends_with("_" + str(current_tier)):
		base_id = base_id.substr(0, base_id.length() - str(current_tier).length() - 1)
	
	var target_id = base_id + "_" + str(next_tier)
	runes_fused.emit(rune_id, target_id)
	return target_id
