class_name SpellSystem
extends Node

signal mana_changed(current: int, maximum: int)
signal spell_cast_success(spell_id: String)
signal spell_cast_at(spell_id: String, target_pos: Vector2)

var max_mana: int = 100
var current_mana: int = 60
var mana_regen_rate: float = 2.5
var _mana_accum: float = 0.0
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
	var regen = mana_regen_rate
	if is_inside_tree() and get_tree() != null:
		var tech = get_tree().get_first_node_in_group("tech_tree_manager") as TechTreeManager
		if tech:
			regen *= (1.0 + tech.get_mana_regen_bonus())
			
	if current_mana < max_mana:
		_mana_accum += regen * delta
		if _mana_accum >= 1.0:
			var add = int(_mana_accum)
			_mana_accum -= add
			current_mana = min(max_mana, current_mana + add)
			mana_changed.emit(current_mana, max_mana)
		
	# Обновление кулдаунов
	for s_id in cooldowns.keys():
		if cooldowns[s_id] > 0.0:
			cooldowns[s_id] -= delta

func add_mana(amount: int) -> void:
	current_mana = min(max_mana, current_mana + amount)
	mana_changed.emit(current_mana, max_mana)

var _default_spell_costs: Dictionary = {
	"meteor": 40, "freeze": 30, "gold_rain": 50, "lightning": 25,
	"vortex": 35, "roots": 25, "chronoshift": 45, "stone_wall": 20
}
var _default_spell_cooldowns: Dictionary = {
	"meteor": 18.0, "freeze": 20.0, "gold_rain": 25.0, "lightning": 10.0,
	"vortex": 15.0, "roots": 15.0, "chronoshift": 20.0, "stone_wall": 12.0
}

func _get_spell_data(spell_id: String) -> Dictionary:
	if spells_data.has(spell_id):
		return spells_data[spell_id]
	return {}

func get_spell_cost(spell_id: String) -> int:
	var base_cost = int(_get_spell_data(spell_id).get("mana_cost", _default_spell_costs.get(spell_id, 30)))
	if is_inside_tree() and get_tree() != null:
		var tech = get_tree().get_first_node_in_group("tech_tree_manager") as TechTreeManager
		if tech:
			base_cost = int(ceil(base_cost * (1.0 - tech.get_cost_discount())))
	return max(1, base_cost)

func get_spell_cooldown(spell_id: String) -> float:
	var base_cd = float(_get_spell_data(spell_id).get("cooldown", _default_spell_cooldowns.get(spell_id, 15.0)))
	if is_inside_tree() and get_tree() != null:
		var tech = get_tree().get_first_node_in_group("tech_tree_manager") as TechTreeManager
		if tech:
			base_cd *= (1.0 - tech.get_ability_cooldown_mult())
		var art_mgr = get_tree().get_first_node_in_group("artifact_manager") as ArtifactManager
		if art_mgr and art_mgr.has_active_effect("cooldown_reduction"):
			var art_data = art_mgr.get_artifact_data("time_crystal")
			if art_data.get("spell") == spell_id:
				base_cd *= (1.0 - float(art_data.get("value", 0.5)))
	return max(0.5, base_cd)

func can_cast(spell_id: String) -> bool:
	var cost = get_spell_cost(spell_id)
	var cd = cooldowns.get(spell_id, 0.0)
	return current_mana >= cost and cd <= 0.0

func cast_spell(spell_id: String, target_pos: Vector2 = Vector2.ZERO) -> bool:
	if not can_cast(spell_id):
		return false

	var sdata = _get_spell_data(spell_id)
	var cost = get_spell_cost(spell_id)
	var cd = get_spell_cooldown(spell_id)

	current_mana -= cost
	cooldowns[spell_id] = cd
	mana_changed.emit(current_mana, max_mana)

	match spell_id:
		"meteor":
			_cast_meteor(target_pos, float(sdata.get("damage", 350)), float(sdata.get("radius", 130)), str(sdata.get("damage_type", "fire")))
		"freeze":
			_cast_freeze(float(sdata.get("duration", 5.0)))
		"gold_rain":
			_cast_gold_rain(int(sdata.get("gold_amount", 120)))
		"lightning":
			_cast_lightning(target_pos, float(sdata.get("damage", 220)), str(sdata.get("damage_type", "lightning")))
		"vortex":
			_cast_vortex(target_pos, float(sdata.get("radius", 200.0)), float(sdata.get("duration", 4.0)))
		"roots":
			_cast_roots(target_pos, float(sdata.get("radius", 150.0)), float(sdata.get("duration", 6.0)))
		"chronoshift":
			_cast_chronoshift(float(sdata.get("duration", 5.0)), float(sdata.get("power", 3.0)))
		"stone_wall":
			_cast_stone_wall(target_pos, float(sdata.get("duration", 8.0)))

	spell_cast_success.emit(spell_id)
	spell_cast_at.emit(spell_id, target_pos)
	return true


func _cast_meteor(target_pos: Vector2, dmg: float, radius: float, dmg_type: String = "fire") -> void:
	if not is_inside_tree() or get_tree() == null:
		return
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.get("is_dead"):
			var dist = target_pos.distance_to(enemy.global_position)
			if dist <= radius:
				enemy.take_damage(dmg, dmg_type)

func _cast_freeze(duration: float) -> void:
	if not is_inside_tree() or get_tree() == null:
		return
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.get("is_dead"):
			if enemy.has_method("apply_freeze"):
				enemy.apply_freeze(duration)

func _cast_gold_rain(amount: int) -> void:
	if not is_inside_tree() or get_tree() == null:
		return
	var gm = get_tree().get_first_node_in_group("game_manager") as GameManager
	if gm:
		gm.add_gold(amount)

func _cast_lightning(target_pos: Vector2, dmg: float, dmg_type: String = "lightning") -> void:
	if not is_inside_tree() or get_tree() == null:
		return
	var enemies = get_tree().get_nodes_in_group("enemies")
	var closest_enemy: Node2D = null
	var min_dist: float = 999999.0
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.get("is_dead"):
			# Search closest to target_pos, but with full-map fallback radius
			var dist = target_pos.distance_to(enemy.global_position)
			if dist < min_dist:
				min_dist = dist
				closest_enemy = enemy
	if is_instance_valid(closest_enemy):
		closest_enemy.take_damage(dmg, dmg_type)

func _cast_vortex(target_pos: Vector2, radius: float, duration: float) -> void:
	if not is_inside_tree() or get_tree() == null:
		return
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.get("is_dead"):
			var dist = target_pos.distance_to(enemy.global_position)
			if dist <= radius:
				# Use apply_slow since PathFollow2D enemies use progress, not raw position
				if enemy.has_method("apply_slow"):
					enemy.apply_slow(0.9, duration)
				elif enemy.has_method("apply_status_effect"):
					enemy.apply_status_effect(StatusEffect.Type.SLOW, duration, 0.9)


func _cast_roots(target_pos: Vector2, radius: float, duration: float) -> void:
	if not is_inside_tree() or get_tree() == null:
		return
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.get("is_dead"):
			var dist = target_pos.distance_to(enemy.global_position)
			if dist <= radius:
				if enemy.has_method("apply_status_effect"):
					enemy.apply_status_effect(StatusEffect.Type.STUN, duration, 1.0)
				elif enemy.has_method("apply_freeze"):
					enemy.apply_freeze(duration)

func _cast_chronoshift(duration: float, factor: float) -> void:
	if not is_inside_tree() or get_tree() == null:
		return
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.get("is_dead"):
			if enemy.has_method("apply_status_effect"):
				enemy.apply_status_effect(StatusEffect.Type.SLOW, duration, 1.0 - (1.0 / factor))
			elif enemy.has_method("apply_slow"):
				enemy.apply_slow(1.0 - (1.0 / factor), duration)

func _cast_stone_wall(target_pos: Vector2, duration: float) -> void:
	if not is_inside_tree() or get_tree() == null:
		return
	var barrier = Node2D.new()
	barrier.name = "StoneWallBarrier_%d" % Time.get_ticks_msec()
	barrier.global_position = target_pos
	barrier.add_to_group("barricades")
	if get_tree().current_scene:
		get_tree().current_scene.add_child(barrier)
	else:
		add_child(barrier)
	
	var timer = get_tree().create_timer(duration)
	timer.timeout.connect(func():
		if is_instance_valid(barrier):
			barrier.queue_free()
	)

