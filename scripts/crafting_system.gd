class_name CraftingSystem
extends Node

## CraftingSystem — Алхимический и кузнечный движок
## Обрабатывает рецепты слияния рун, переплавки артефактов и создания боевых расходников.
## Загружает рецепты из data/crafting_recipes.json.

signal item_crafted(recipe_id: String, output_item: String, count: int)
signal item_dismantled(item_id: String, returned_materials: Dictionary)

var recipes: Array[Dictionary] = []
var recipes_by_id: Dictionary = {}
var normal_crafts: int = 0

# Локальный инвентарь материалов хаба
var player_materials: Dictionary = {
	"wood": 50,
	"stone": 50,
	"iron_ore": 20,
	"black_powder": 10,
	"pure_water": 15,
	"crystal_shards": 10,
	"parchment": 5,
	"healing_herbs": 10
}

func _init() -> void:
	load_recipes()

func _ready() -> void:
	add_to_group("crafting_system")
	if recipes.is_empty():
		load_recipes()

func load_recipes(path: String = "res://data/crafting_recipes.json") -> void:
	if not FileAccess.file_exists(path):
		return
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var json = JSON.new()
		var err = json.parse(file.get_as_text())
		if err == OK and json.data is Dictionary:
			var list = json.data.get("recipes", [])
			recipes.clear()
			recipes_by_id.clear()
			for r in list:
				if r is Dictionary and r.has("id"):
					recipes.append(r)
					recipes_by_id[r["id"]] = r

func get_recipe(recipe_id: String) -> Dictionary:
	if recipes_by_id.has(recipe_id):
		return recipes_by_id[recipe_id]
	return {}

func get_known_recipes() -> Array[Dictionary]:
	return recipes.duplicate(true)

func get_recipes_by_category(category: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for r in recipes:
		if r.get("category", "") == category:
			result.append(r)
	return result

## Проверка наличия необходимых материалов для крафта
func can_craft(recipe_id: String, inventory_override: Dictionary = {}) -> bool:
	var r = get_recipe(recipe_id)
	if r.is_empty():
		return false

	var source_inv = inventory_override if not inventory_override.is_empty() else player_materials
	var inputs: Dictionary = r.get("inputs", {})
	for mat_id in inputs.keys():
		var required_qty = int(inputs[mat_id])
		var available_qty = int(source_inv.get(mat_id, 0))
		if available_qty < required_qty:
			return false
	return true

## Выполнить крафт по рецепту
func craft_recipe(recipe_id: String, inventory_override: Dictionary = {}) -> Dictionary:
	if not can_craft(recipe_id, inventory_override):
		return { "success": false, "error": "Insufficient materials" }

	var r = get_recipe(recipe_id)
	var source_inv = inventory_override if not inventory_override.is_empty() else player_materials
	var inputs: Dictionary = r.get("inputs", {})

	# Списываем материалы
	for mat_id in inputs.keys():
		var required_qty = int(inputs[mat_id])
		source_inv[mat_id] = int(source_inv.get(mat_id, 0)) - required_qty

	var output_info = r.get("output", {})
	var output_item = ""
	var output_count = 1
	if output_info is Dictionary:
		output_item = str(output_info.get("item", "crafted_item"))
		output_count = int(output_info.get("count", 1))
	elif output_info is String:
		output_item = output_info

	# Добавляем скрафченный предмет в инвентарь материалов, если он там отслеживается
	source_inv[output_item] = int(source_inv.get(output_item, 0)) + output_count
	normal_crafts += 1

	item_crafted.emit(recipe_id, output_item, output_count)
	return {
		"success": true,
		"item": output_item,
		"count": output_count,
		"quality": "Normal"
	}

## Разбор предмета на компоненты
func dismantle_item(item_id: String) -> Dictionary:
	var materials: Dictionary = {}
	match item_id:
		"wood_scrap", "timber_logs": materials = { "wood": 5 }
		"stone_blocks": materials = { "stone": 5 }
		"broken_weapon": materials = { "iron_ore": 3 }
		"broken_artifact": materials = { "common_scrap": 1, "crystal_shards": 2 }
		_: materials = { "wood": 2, "iron_ore": 1 }

	for mat in materials:
		player_materials[mat] = int(player_materials.get(mat, 0)) + int(materials[mat])

	item_dismantled.emit(item_id, materials)
	return { "materials": materials }
