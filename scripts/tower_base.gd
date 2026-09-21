class_name TowerBase
extends Node2D

@export var tower_type: String = "archer"
@export var current_level: int = 1

var max_level: int = 3
var tower_name: String = "Башня"
var damage: float = 12.0
var range_radius: float = 180.0
var attack_speed: float = 1.4
var projectile_speed: float = 450.0
var projectile_type: String = "arrow"
var damage_type: String = "physical"
var slow_factor: float = 0.0
var slow_duration: float = 0.0
var splash_radius: float = 0.0
var pierce_count: int = 1
var gold_per_sec: int = 0
var upgrade_cost: int = 60
var total_spent: int = 70

var is_selected: bool = false
var shoot_timer: float = 0.0
var scan_timer: float = 0.0
var gold_timer: float = 0.0
var current_target: Node2D = null

var projectile_script = preload("res://scripts/projectile.gd")

func _ready() -> void:
	_load_stats()
	queue_redraw()

func _load_stats() -> void:
	var game_manager = get_tree().get_first_node_in_group("game_manager") as GameManager
	if not game_manager:
		game_manager = get_tree().root.get_node_or_null("Game/GameManager")
		
	if game_manager and game_manager.tower_data.has(tower_type):
		var tdata = game_manager.tower_data[tower_type]
		tower_name = tdata.get("name", tower_name)
		damage_type = tdata.get("damage_type", damage_type)
		var levels = tdata.get("levels", [])
		if current_level - 1 < levels.size():
			var ldata = levels[current_level - 1]
			damage = ldata.get("damage", damage)
			range_radius = ldata.get("range", range_radius)
			attack_speed = ldata.get("attack_speed", attack_speed)
			projectile_speed = ldata.get("projectile_speed", projectile_speed)
			projectile_type = ldata.get("projectile_type", projectile_type)
			slow_factor = ldata.get("slow_factor", 0.0)
			slow_duration = ldata.get("slow_duration", 0.0)
			splash_radius = ldata.get("splash_radius", 0.0)
			pierce_count = ldata.get("pierce", 1)
			gold_per_sec = ldata.get("gold_per_sec", 0)
			upgrade_cost = ldata.get("upgrade_cost", 0)

func get_effective_damage() -> float:
	var dmg = damage
	var meta = get_tree().get_first_node_in_group("meta_manager") as MetaManager
	if meta:
		dmg *= (1.0 + meta.get_base_damage_mult())
	var tech = get_tree().get_first_node_in_group("tech_tree_manager") as TechTreeManager
	if tech:
		dmg *= (1.0 + tech.get_damage_bonus())
		
	# Синергия Аркан-сети для магических башен
	var gm = get_tree().get_first_node_in_group("game_manager") as GameManager
	if gm and gm.selected_path == "magic" and damage_type == "magic":
		dmg *= 1.15
		
	return dmg

func get_effective_range() -> float:
	var r = range_radius
	var tech = get_tree().get_first_node_in_group("tech_tree_manager") as TechTreeManager
	if tech:
		r *= (1.0 + tech.get_range_bonus())
	return r

func get_effective_attack_speed() -> float:
	var spd = attack_speed
	var gm = get_tree().get_first_node_in_group("game_manager") as GameManager
	# Режим Берсерка удваивает скорость атаки
	if gm and gm.ability_active and gm.selected_path == "military":
		spd *= 2.0
	return spd

func _process(delta: float) -> void:
	# Доход от Торгового поста
	if gold_per_sec > 0:
		gold_timer += delta
		if gold_timer >= 1.0:
			gold_timer = 0.0
			var gm = get_tree().get_first_node_in_group("game_manager") as GameManager
			if gm and gm.game_state == GameManager.GameState.WAVE_IN_PROGRESS:
				gm.add_gold(gold_per_sec)
				
	if shoot_timer > 0.0:
		shoot_timer -= delta
		
	scan_timer -= delta
	if scan_timer <= 0.0:
		scan_timer = 0.15
		_find_best_target()
		
	if shoot_timer <= 0.0:
		if tower_type == "bastion":
			_shoot_bastion()
		elif is_instance_valid(current_target):
			_shoot_single(current_target)

func _find_best_target() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var best_target: Node2D = null
	var best_progress: float = -1.0
	var eff_range = get_effective_range()
	
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.get("is_dead"):
			var dist = global_position.distance_to(enemy.global_position)
			if dist <= eff_range:
				var prog = enemy.get("progress") if "progress" in enemy else 0.0
				if prog > best_progress:
					best_progress = prog
					best_target = enemy
					
	current_target = best_target

func _shoot_single(target_node: Node2D) -> void:
	if not is_instance_valid(target_node):
		return
		
	var spd = get_effective_attack_speed()
	shoot_timer = 1.0 / max(0.05, spd)
	
	var proj = Node2D.new()
	proj.set_script(projectile_script)
	proj.global_position = global_position
	
	proj.init_projectile(
		target_node,
		projectile_speed,
		get_effective_damage(),
		damage_type,
		slow_factor,
		slow_duration,
		projectile_type,
		splash_radius,
		pierce_count
	)
	
	var projectles_container = get_tree().root.get_node_or_null("Game/Projectiles")
	if projectles_container:
		projectles_container.add_child(proj)
	else:
		get_parent().add_child(proj)

func _shoot_bastion() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var in_range_enemies: Array = []
	var eff_range = get_effective_range()
	
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.get("is_dead"):
			if global_position.distance_to(enemy.global_position) <= eff_range:
				in_range_enemies.append(enemy)
				
	if in_range_enemies.is_empty():
		return
		
	var spd = get_effective_attack_speed()
	shoot_timer = 1.0 / max(0.05, spd)
	
	for enemy in in_range_enemies:
		_shoot_single(enemy)

func can_upgrade() -> bool:
	return current_level < max_level and upgrade_cost > 0

func upgrade() -> bool:
	if not can_upgrade():
		return false
	current_level += 1
	total_spent += upgrade_cost
	_load_stats()
	queue_redraw()
	return true

func get_sell_value() -> int:
	var tech = get_tree().get_first_node_in_group("tech_tree_manager") as TechTreeManager
	var ratio = tech.get_sell_ratio() if tech else 0.70
	return int(total_spent * ratio)

func set_selected(selected: bool) -> void:
	is_selected = selected
	queue_redraw()

func _draw() -> void:
	var eff_range = get_effective_range()
	if is_selected:
		draw_circle(Vector2.ZERO, eff_range, Color(0.3, 0.7, 1.0, 0.12))
		draw_arc(Vector2.ZERO, eff_range, 0, TAU, 36, Color(0.3, 0.7, 1.0, 0.5), 1.5)
	
	match tower_type:
		"archer":
			draw_rect(Rect2(-16, -16, 32, 32), Color(0.35, 0.35, 0.4))
			draw_rect(Rect2(-10, -10, 20, 20), Color(0.55, 0.35, 0.15))
			draw_arc(Vector2.ZERO, 6.0, -PI/2, PI/2, 8, Color(0.85, 0.7, 0.2), 2.0)
		"crossbowman":
			draw_rect(Rect2(-16, -16, 32, 32), Color(0.3, 0.25, 0.25))
			draw_line(Vector2(-12, 0), Vector2(12, 0), Color(0.9, 0.2, 0.2), 3.0)
			draw_line(Vector2(4, -8), Vector2(4, 8), Color(0.7, 0.7, 0.7), 2.5)
		"siege_cannon":
			draw_circle(Vector2.ZERO, 16.0, Color(0.2, 0.2, 0.25))
			draw_circle(Vector2.ZERO, 10.0, Color(0.1, 0.1, 0.15))
			draw_line(Vector2(0, 0), Vector2(16, 0), Color(0.3, 0.3, 0.35), 6.0)
		"bastion":
			draw_rect(Rect2(-18, -18, 36, 36), Color(0.4, 0.25, 0.15))
			draw_rect(Rect2(-12, -12, 24, 24), Color(0.5, 0.35, 0.2))
			draw_circle(Vector2.ZERO, 6.0, Color(0.9, 0.6, 0.2))
		"ice_mage":
			draw_polygon(PackedVector2Array([Vector2(0, -20), Vector2(16, 12), Vector2(-16, 12)]), PackedColorArray([Color(0.2, 0.4, 0.7), Color(0.15, 0.25, 0.5), Color(0.15, 0.25, 0.5)]))
			draw_polygon(PackedVector2Array([Vector2(0, -14), Vector2(7, -4), Vector2(0, 6), Vector2(-7, -4)]), PackedColorArray([Color(0.4, 0.85, 1.0), Color(0.4, 0.85, 1.0), Color(0.4, 0.85, 1.0), Color(0.4, 0.85, 1.0)]))
		"necromancer":
			draw_polygon(PackedVector2Array([Vector2(0, -20), Vector2(14, 14), Vector2(-14, 14)]), PackedColorArray([Color(0.3, 0.1, 0.4), Color(0.2, 0.05, 0.3), Color(0.2, 0.05, 0.3)]))
			draw_circle(Vector2.ZERO, 5.0, Color(0.8, 0.2, 1.0))
		"time_tower":
			draw_circle(Vector2.ZERO, 15.0, Color(0.2, 0.2, 0.5))
			draw_arc(Vector2.ZERO, 11.0, 0, TAU, 12, Color(0.5, 0.5, 1.0), 2.0)
			draw_line(Vector2.ZERO, Vector2(0, -8), Color(1.0, 1.0, 1.0), 2.0)
		"trading_post":
			draw_rect(Rect2(-16, -16, 32, 32), Color(0.6, 0.45, 0.2))
			draw_circle(Vector2.ZERO, 7.0, Color(1.0, 0.85, 0.2))
		"trap":
			draw_circle(Vector2.ZERO, 12.0, Color(0.7, 0.3, 0.1))
			draw_circle(Vector2.ZERO, 5.0, Color(1.0, 0.4, 0.1))
		"auto_turret":
			draw_circle(Vector2.ZERO, 13.0, Color(0.35, 0.4, 0.45))
			draw_line(Vector2(0, 0), Vector2(12, 0), Color(0.2, 0.2, 0.2), 3.0)
		_:
			draw_rect(Rect2(-14, -14, 28, 28), Color(0.4, 0.4, 0.4))
	
	# Звездочки уровня
	for i in range(current_level):
		var offset_x = (i - (current_level - 1) * 0.5) * 8.0
		draw_circle(Vector2(offset_x, 18), 2.5, Color(1.0, 0.85, 0.2))
