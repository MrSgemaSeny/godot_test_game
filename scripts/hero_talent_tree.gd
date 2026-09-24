class_name HeroTalentTree
extends Node

## HeroTalentTree — Древо талантов для 8 классов героев
## Поддерживает 4 тира прокачки (уровни 3, 6, 9, 12), ветвление и применение
## модификаторов к характеристикам и способностям героя.

signal talent_unlocked(hero_id: String, tier: int, choice_id: String)
signal talents_reset(hero_id: String)

# Структура: { "commander": { 1: "iron_will", 2: "bulwark_mastery", ... } }
var hero_talents: Dictionary = {}

# Загруженная база данных талантов героев
var talent_database: Dictionary = {}

func _init() -> void:
	_load_talent_database()

func _ready() -> void:
	add_to_group("hero_talent_tree")
	if talent_database.is_empty():
		_load_talent_database()

func _load_talent_database() -> void:
	var path = "res://data/heroes_data.json"
	if not FileAccess.file_exists(path):
		return
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var json = JSON.new()
		var err = json.parse(file.get_as_text())
		if err == OK and json.data is Dictionary:
			for hero_id in json.data:
				var h = json.data[hero_id]
				if h is Dictionary and h.has("talents"):
					talent_database[hero_id] = h["talents"]

## Возвращает дерево талантов для указанного героя
func get_talent_tree(hero_id: String) -> Dictionary:
	if talent_database.has(hero_id):
		return talent_database[hero_id]
	return {}

## Разблокировать выбранный талант в тире (1..4)
func unlock_talent(hero_id: String, tier: int, choice_id: String) -> bool:
	if tier < 1 or tier > 4:
		return false
	if not hero_talents.has(hero_id):
		hero_talents[hero_id] = {}
	if hero_talents[hero_id].has(tier):
		return false # В этом тире уже выбран талант
	
	# Проверяем валидность choice_id по базе данных
	var tree = get_talent_tree(hero_id)
	var tier_key = "tier_" + str(tier)
	if not tree.is_empty() and tree.has(tier_key):
		var choices = tree[tier_key]
		var found = false
		for opt in choices:
			if opt.get("id") == choice_id:
				found = true
				break
		if not found:
			# Если в дереве нет такого таланта, все равно разрешаем если ID не пустой
			if choice_id.is_empty():
				return false
	
	hero_talents[hero_id][tier] = choice_id
	talent_unlocked.emit(hero_id, tier, choice_id)
	return true

## Сброс всех выбранных талантов героя
func reset_talents(hero_id: String) -> void:
	if hero_talents.has(hero_id):
		hero_talents[hero_id].clear()
		talents_reset.emit(hero_id)

## Получить список активных талантов героя
func get_active_talents(hero_id: String) -> Array[Dictionary]:
	var active: Array[Dictionary] = []
	if hero_talents.has(hero_id):
		for t in hero_talents[hero_id].keys():
			var choice_id = hero_talents[hero_id][t]
			var talent_info = _find_talent_info(hero_id, int(t), choice_id)
			active.append({
				"tier": int(t),
				"choice": choice_id,
				"name": talent_info.get("name", choice_id),
				"desc": talent_info.get("desc", ""),
				"bonus": talent_info.get("bonus", {})
			})
	return active

func _find_talent_info(hero_id: String, tier: int, choice_id: String) -> Dictionary:
	var tree = get_talent_tree(hero_id)
	var tier_key = "tier_" + str(tier)
	if tree.has(tier_key):
		for opt in tree[tier_key]:
			if opt.get("id") == choice_id:
				return opt
	return {"id": choice_id, "name": choice_id, "desc": "", "bonus": {}}

## Применяет модификаторы всех выбранных талантов к объекту героя (HeroBase)
func apply_talents_to_hero(hero_node: Node) -> void:
	if not is_instance_valid(hero_node):
		return
	
	var hero_id = ""
	if "hero_class" in hero_node:
		hero_id = str(hero_node.hero_class)
	elif "id" in hero_node:
		hero_id = str(hero_node.id)
		
	if hero_id.is_empty() or not hero_talents.has(hero_id):
		return

	var active = get_active_talents(hero_id)
	for item in active:
		var bonus = item.get("bonus", {})
		if not (bonus is Dictionary):
			continue
		
		# Применение бонусных базовых характеристик
		if bonus.has("hp") and "max_health" in hero_node:
			hero_node.max_health += float(bonus["hp"])
			if "current_health" in hero_node:
				hero_node.current_health = min(hero_node.current_health + float(bonus["hp"]), hero_node.max_health)
				
		if bonus.has("hp_regen") and "hp_regen" in hero_node:
			hero_node.hp_regen += float(bonus["hp_regen"])
			
		if bonus.has("mana") and "max_mana" in hero_node:
			hero_node.max_mana += float(bonus["mana"])
			if "current_mana" in hero_node:
				hero_node.current_mana = min(hero_node.current_mana + float(bonus["mana"]), hero_node.max_mana)
				
		if bonus.has("mana_regen") and "mana_regen" in hero_node:
			hero_node.mana_regen += float(bonus["mana_regen"])
			
		if bonus.has("damage") and "attack_damage" in hero_node:
			hero_node.attack_damage += float(bonus["damage"])
			
		if bonus.has("armor") and "armor" in hero_node:
			hero_node.armor += float(bonus["armor"])
			
		if bonus.has("magic_resist") and "magic_resist" in hero_node:
			hero_node.magic_resist += float(bonus["magic_resist"])
			
		if bonus.has("speed") and "move_speed" in hero_node:
			hero_node.move_speed += float(bonus["speed"])
			
		if bonus.has("attack_range") and "attack_range" in hero_node:
			hero_node.attack_range += float(bonus["attack_range"])
			
		if bonus.has("crit_chance") and "crit_chance" in hero_node:
			hero_node.crit_chance += float(bonus["crit_chance"])
			
		if bonus.has("crit_mult") and "crit_mult" in hero_node:
			hero_node.crit_mult += float(bonus["crit_mult"])
			
		if bonus.has("attack_speed") and "attack_speed" in hero_node:
			hero_node.attack_speed += float(bonus["attack_speed"])

## Сериализация талантов для сохранения прогресса
func save_talents() -> Dictionary:
	return hero_talents.duplicate(true)

## Восстановление талантов из сохранения
func load_talents(data: Dictionary) -> void:
	hero_talents = data.duplicate(true)
