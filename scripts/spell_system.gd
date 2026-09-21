class_name SpellSystem
extends Node

signal mana_changed(current: int, maximum: int)
signal spell_cast_success(spell_id: String)

var max_mana: int = 100
var current_mana: int = 60
var mana_regen_rate: float = 2.5
var spells_data: Dictionary = {}
var cooldowns: Dictionary = {}

func _enter_tree() -> void:
	add_to_group("spell_system")

func _ready() -> void:
	_load_spells_data()

func _load_spells_data() -> void:
	if not FileAccess.file_exists("res://data/spells_database.json"):
		return
	var file = FileAccess.open("res://data/spells_database.json", FileAccess.READ)
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		spells_data = json.data

func _process(delta: float) -> void:
	if current_mana < max_mana:
		current_mana = min(max_mana, int(current_mana + mana_regen_rate * delta * 10.0) / 10)
		mana_changed.emit(current_mana, max_mana)
		
	# Обновление кулдаунов
	for s_id in cooldowns.keys():
		if cooldowns[s_id] > 0.0:
			cooldowns[s_id] -= delta

func add_mana(amount: int) -> void:
	current_mana = min(max_mana, current_mana + amount)
	mana_changed.emit(current_mana, max_mana)

func can_cast(spell_id: String) -> bool:
	if not spells_data.has(spell_id):
		return false
	var sdata = spells_data[spell_id]
	var cost = sdata.get("mana_cost", 20)
	var cd = cooldowns.get(spell_id, 0.0)
	return current_mana >= cost and cd <= 0.0

func cast_spell(spell_id: String, target_pos: Vector2 = Vector2.ZERO) -> bool:
	if not can_cast(spell_id):
		return false
		
	var sdata = spells_data[spell_id]
	var cost = sdata.get("mana_cost", 20)
	var cd = sdata.get("cooldown", 15.0)
	
	current_mana -= cost
	cooldowns[spell_id] = cd
	mana_changed.emit(current_mana, max_mana)
	
	match spell_id:
		"meteor":
			_cast_meteor(target_pos, sdata.get("damage", 350), sdata.get("radius", 130))
		"freeze":
			_cast_freeze(sdata.get("duration", 5.0))
		"gold_rain":
			_cast_gold_rain(sdata.get("gold_amount", 120))
		"lightning":
			_cast_lightning(target_pos, sdata.get("damage", 220))
			
	spell_cast_success.emit(spell_id)
	return true

func _cast_meteor(target_pos: Vector2, dmg: float, radius: float) -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.get("is_dead"):
			var dist = target_pos.distance_to(enemy.global_position)
			if dist <= radius:
				enemy.take_damage(dmg, "magic")

func _cast_freeze(duration: float) -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.get("is_dead"):
			if enemy.has_method("apply_freeze"):
				enemy.apply_freeze(duration)

func _cast_gold_rain(amount: int) -> void:
	var gm = get_tree().get_first_node_in_group("game_manager") as GameManager
	if gm:
		gm.add_gold(amount)

func _cast_lightning(target_pos: Vector2, dmg: float) -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var closest_enemy: Node2D = null
	var min_dist: float = 999999.0
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.get("is_dead"):
			var dist = target_pos.distance_to(enemy.global_position)
			if dist < min_dist:
				min_dist = dist
				closest_enemy = enemy
				
	if is_instance_valid(closest_enemy) and min_dist <= 180.0:
		closest_enemy.take_damage(dmg, "magic")
