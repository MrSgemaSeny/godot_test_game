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

# === Evolution System (Stage 3) ===
var evolution_chosen: String = ""
var evolution_data_a: Dictionary = {}
var evolution_data_b: Dictionary = {}
var special_ability: String = ""

signal buff_applied(buff_type: String, duration: float, multiplier: float)
signal buff_expired(buff_type: String)
signal evolution_applied(branch: String)

var active_buffs: Array[Dictionary] = []

var is_selected: bool = false
var shoot_timer: float = 0.0
var scan_timer: float = 0.0
var gold_timer: float = 0.0
var current_target: Node2D = null
var anim_time: float = 0.0
var turret_angle: float = 0.0

var projectile_script = preload("res://scripts/projectile.gd")
var ballistic_script = preload("res://scripts/ballistic_projectile.gd")

func _ready() -> void:
	_load_stats()
	queue_redraw()

func _load_stats() -> void:
	if not is_inside_tree() or get_tree() == null:
		return
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
			
		evolution_data_a = tdata.get("evolution_a", {}).duplicate()
		evolution_data_b = tdata.get("evolution_b", {}).duplicate()

# Public Buff API
func apply_buff(buff_type: String, duration: float, multiplier: float) -> void:
	var b_type: String = buff_type.to_lower().strip_edges()
	if b_type == "speed" or b_type == "attackspeed":
		b_type = "attack_speed"
		
	if not b_type in ["damage", "range", "attack_speed"]:
		push_warning("TowerBase: Unsupported buff type '%s'" % buff_type)
		return
		
	if duration <= 0.0 or multiplier <= 0.0:
		return
		
	var found: bool = false
	for b in active_buffs:
		if b.get("type", "") == b_type and is_equal_approx(float(b.get("multiplier", 1.0)), multiplier):
			b["duration"] = max(float(b.get("duration", 0.0)), duration)
			found = true
			break
			
	if not found:
		active_buffs.append({
			"type": b_type,
			"duration": duration,
			"multiplier": multiplier
		})
		
	buff_applied.emit(b_type, duration, multiplier)
	if b_type == "range" or is_selected:
		queue_redraw()

func has_buff(buff_type: String) -> bool:
	var b_type = buff_type.to_lower().strip_edges()
	if b_type == "speed" or b_type == "attackspeed":
		b_type = "attack_speed"
	for b in active_buffs:
		if b.get("type", "") == b_type and float(b.get("duration", 0.0)) > 0.0:
			return true
	return false

func get_buff_multiplier(buff_type: String) -> float:
	var mult: float = 1.0
	var b_type = buff_type.to_lower().strip_edges()
	if b_type == "speed" or b_type == "attackspeed":
		b_type = "attack_speed"
	for b in active_buffs:
		if b.get("type", "") == b_type:
			mult *= float(b.get("multiplier", 1.0))
	return mult

func clear_buffs() -> void:
	active_buffs.clear()
	queue_redraw()

func _update_buffs(delta: float) -> void:
	if active_buffs.is_empty():
		return
	var had_range_buff: bool = false
	var changed: bool = false
	var i: int = active_buffs.size() - 1
	while i >= 0:
		var b = active_buffs[i]
		b["duration"] = float(b.get("duration", 0.0)) - delta
		if b["duration"] <= 0.0:
			var b_type = b.get("type", "")
			if b_type == "range":
				had_range_buff = true
			buff_expired.emit(b_type)
			active_buffs.remove_at(i)
			changed = true
		i -= 1
	if changed:
		if had_range_buff or is_selected:
			queue_redraw()

func get_effective_damage() -> float:
	var dmg: float = damage * get_buff_multiplier("damage")
	if not is_inside_tree() or get_tree() == null:
		return dmg
	var meta = get_tree().get_first_node_in_group("meta_manager") as MetaManager
	if meta:
		dmg *= (1.0 + meta.get_base_damage_mult())
	var tech = get_tree().get_first_node_in_group("tech_tree_manager") as TechTreeManager
	if tech:
		dmg *= (1.0 + tech.get_damage_bonus())
	var gm = get_tree().get_first_node_in_group("game_manager") as GameManager
	if gm and gm.selected_path == "magic" and damage_type == "magic":
		dmg *= 1.15
	return dmg

func get_effective_range() -> float:
	var r: float = range_radius * get_buff_multiplier("range")
	if not is_inside_tree() or get_tree() == null:
		return r
	var tech = get_tree().get_first_node_in_group("tech_tree_manager") as TechTreeManager
	if tech:
		r *= (1.0 + tech.get_range_bonus())
	return r

func get_effective_attack_speed() -> float:
	var spd: float = attack_speed * get_buff_multiplier("attack_speed")
	if not is_inside_tree() or get_tree() == null:
		return spd
	var gm = get_tree().get_first_node_in_group("game_manager") as GameManager
	if gm and gm.ability_active and gm.selected_path == "military":
		spd *= 2.0
	return spd

func _process(delta: float) -> void:
	anim_time += delta * 3.0
	
	# Process buff countdown
	_update_buffs(delta)
	
	if gold_per_sec > 0:
		gold_timer += delta
		if gold_timer >= 1.0:
			gold_timer = 0.0
			if is_inside_tree() and get_tree() != null:
				var gm = get_tree().get_first_node_in_group("game_manager") as GameManager
				if gm and gm.game_state == GameManager.GameState.WAVE_IN_PROGRESS:
					gm.add_gold(gold_per_sec)
				
	if shoot_timer > 0.0:
		shoot_timer -= delta
		
	scan_timer -= delta
	if scan_timer <= 0.0:
		scan_timer = 0.15
		_find_best_target()
		
	if current_target != null:
		if not is_instance_valid(current_target) or not current_target.is_inside_tree() or current_target.is_queued_for_deletion() or current_target.get("is_dead"):
			current_target = null
		elif global_position.distance_to(current_target.global_position) > get_effective_range():
			current_target = null
		
	if is_instance_valid(current_target):
		var target_angle = (current_target.global_position - global_position).angle()
		turret_angle = lerp_angle(turret_angle, target_angle, delta * 12.0)
		queue_redraw()
		
	if shoot_timer <= 0.0:
		if tower_type == "bastion":
			_shoot_bastion()
		elif is_instance_valid(current_target):
			_shoot_single(current_target)

func _find_best_target() -> void:
	if not is_inside_tree() or get_tree() == null:
		current_target = null
		return
	var enemies = get_tree().get_nodes_in_group("enemies")
	var best_target: Node2D = null
	var best_progress: float = -1.0
	var eff_range = get_effective_range()
	
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.is_inside_tree() and not enemy.is_queued_for_deletion() and not enemy.get("is_dead"):
			var dist = global_position.distance_to(enemy.global_position)
			if dist <= eff_range:
				var prog = enemy.get("progress") if "progress" in enemy else 0.0
				if prog > best_progress:
					best_progress = prog
					best_target = enemy
					
	current_target = best_target

func _shoot_single(target_node: Node2D) -> void:
	if not is_instance_valid(target_node) or not target_node.is_inside_tree() or target_node.is_queued_for_deletion() or target_node.get("is_dead"):
		return
		
	var spd = get_effective_attack_speed()
	shoot_timer = 1.0 / max(0.05, spd)
	
	if tower_type == "cannon" or tower_type == "siege_cannon":
		# Баллистический снаряд с дугой и тенью
		var b_proj = Node2D.new()
		b_proj.set_script(ballistic_script)
		b_proj.init_ballistic(
			global_position,
			target_node.global_position,
			0.6,
			get_effective_damage(),
			splash_radius,
			"cannonball",
			0.5 if tower_type == "siege_cannon" else 0.0
		)
		_spawn_projectile(b_proj)
	else:
		# Прямой снаряд
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
		_spawn_projectile(proj)

func _spawn_projectile(proj: Node2D) -> void:
	if not is_inside_tree() or get_tree() == null:
		proj.queue_free()
		return
	var proj_cont = get_tree().root.get_node_or_null("Game/Projectiles")
	if is_instance_valid(proj_cont) and proj_cont.is_inside_tree():
		proj_cont.add_child(proj)
	elif is_instance_valid(get_parent()) and get_parent().is_inside_tree():
		get_parent().add_child(proj)
	else:
		add_child(proj)

func _shoot_bastion() -> void:
	if not is_inside_tree() or get_tree() == null:
		return
	var enemies = get_tree().get_nodes_in_group("enemies")
	var in_range_enemies: Array = []
	var eff_range = get_effective_range()
	
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.is_inside_tree() and not enemy.is_queued_for_deletion() and not enemy.get("is_dead"):
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

func can_evolve() -> bool:
	return current_level >= max_level and evolution_chosen == "" and (not evolution_data_a.is_empty() or not evolution_data_b.is_empty())

func get_evolution_info(branch: String) -> Dictionary:
	if branch == "evolution_a":
		return evolution_data_a
	elif branch == "evolution_b":
		return evolution_data_b
	return {}

func apply_evolution(branch: String) -> bool:
	if not can_evolve():
		return false
	if branch != "evolution_a" and branch != "evolution_b":
		return false
	var info = get_evolution_info(branch)
	if info.is_empty():
		return false
		
	evolution_chosen = branch
	current_level = 4
	tower_name = info.get("name", tower_name)
	damage = float(info.get("damage", damage))
	range_radius = float(info.get("range", range_radius))
	attack_speed = float(info.get("attack_speed", attack_speed))
	projectile_speed = float(info.get("projectile_speed", projectile_speed))
	projectile_type = str(info.get("projectile_type", projectile_type))
	special_ability = str(info.get("special_ability", ""))
	if info.has("pierce"):
		pierce_count = int(info["pierce"])
	if info.has("splash_radius"):
		splash_radius = float(info["splash_radius"])
	if info.has("slow_factor"):
		slow_factor = float(info["slow_factor"])
	if info.has("slow_duration"):
		slow_duration = float(info["slow_duration"])
		
	evolution_applied.emit(branch)
	queue_redraw()
	return true

func get_sell_value() -> int:
	if not is_inside_tree() or get_tree() == null:
		return int(total_spent * 0.70)
	var tech = get_tree().get_first_node_in_group("tech_tree_manager") as TechTreeManager
	var ratio = tech.get_sell_ratio() if tech else 0.70
	return int(total_spent * ratio)

func set_selected(selected: bool) -> void:
	is_selected = selected
	queue_redraw()

func _draw() -> void:
	var eff_range = get_effective_range()
	if is_selected:
		draw_circle(Vector2.ZERO, eff_range, Color(0.3, 0.75, 1.0, 0.08))
		draw_arc(Vector2.ZERO, eff_range, 0, TAU, 48, Color(0.4, 0.85, 1.0, 0.6), 2.0)
		draw_arc(Vector2.ZERO, eff_range - 4.0, 0, TAU, 36, Color(1.0, 0.85, 0.2, 0.3), 1.0)

	# Buff aura ring
	if not active_buffs.is_empty():
		var aura_alpha = 0.3 + sin(anim_time * 2.0) * 0.15
		draw_arc(Vector2.ZERO, 20.0, 0, TAU, 24, Color(1.0, 0.85, 0.2, aura_alpha), 2.0)

	var aim_dir = Vector2(cos(turret_angle), sin(turret_angle))

	match tower_type:

		"archer", "crossbowman":
			# Wood tower with bow/crossbow turret
			draw_circle(Vector2(0, 4), 16.0, Color(0.28, 0.18, 0.10))
			draw_circle(Vector2(0, 0), 14.0, Color(0.52, 0.36, 0.18))
			draw_arc(Vector2.ZERO, 14.0, 0, TAU, 16, Color(0.35, 0.22, 0.12), 3.0)
			draw_line(Vector2.ZERO, aim_dir * 16.0, Color(0.2, 0.2, 0.25), 3.5)
			draw_line(aim_dir * 8.0 + aim_dir.orthogonal() * -8.0, aim_dir * 8.0 + aim_dir.orthogonal() * 8.0, Color(0.85, 0.3, 0.2), 2.5)

		"cannon", "siege_cannon":
			# Iron cannon on wooden carriage
			draw_rect(Rect2(-12, -4, 24, 12), Color(0.42, 0.30, 0.16))
			draw_circle(Vector2(0, 2), 16.0, Color(0.22, 0.22, 0.27))
			draw_line(Vector2.ZERO, aim_dir * 19.0, Color(0.18, 0.18, 0.22), 8.0)
			draw_line(Vector2.ZERO, aim_dir * 20.0, Color(0.75, 0.65, 0.25), 2.0)
			draw_circle(aim_dir * 18.0, 4.5, Color(0.1, 0.1, 0.12))

		"ice_mage":
			# Floating ice crystal obelisk
			var float_y = sin(anim_time) * 4.0
			draw_polygon(PackedVector2Array([Vector2(0, -18), Vector2(14, 10), Vector2(-14, 10)]),
				PackedColorArray([Color(0.2, 0.4, 0.7), Color(0.15, 0.25, 0.5), Color(0.15, 0.25, 0.5)]))
			var crystal_col = Color(0.4, 0.88, 1.0, 0.9)
			var c_poly = PackedVector2Array([
				Vector2(0, -22 + float_y), Vector2(9, -10 + float_y),
				Vector2(0, 2 + float_y), Vector2(-9, -10 + float_y)
			])
			draw_polygon(c_poly, PackedColorArray([Color(0.9, 0.98, 1.0), crystal_col, Color(0.2, 0.6, 0.9), crystal_col]))
			draw_circle(Vector2(0, -10 + float_y), 3.5, Color(1.0, 1.0, 1.0))

		"tesla", "auto_turret":
			# Tesla coil / auto turret with electric rings
			draw_circle(Vector2.ZERO, 15.0, Color(0.3, 0.25, 0.12))
			draw_rect(Rect2(-5, -18, 10, 22), Color(0.72, 0.52, 0.18))
			draw_circle(Vector2(0, -20), 7.0, Color(1.0, 0.9, 0.3))
			draw_arc(Vector2(0, -20), 11.0 + sin(anim_time * 3.0) * 2.5, 0, TAU, 12, Color(0.4, 0.8, 1.0, 0.85), 2.0)
			draw_arc(Vector2(0, -20), 16.0 + sin(anim_time * 2.0 + 1.0) * 2.0, 0, TAU, 10, Color(0.7, 0.9, 1.0, 0.4), 1.5)
			draw_line(Vector2.ZERO, aim_dir * 14.0, Color(0.4, 0.8, 1.0), 3.0)

		"bastion", "wall":
			# Hexagonal stone fortress / wall
			draw_circle(Vector2.ZERO, 19.0, Color(0.32, 0.32, 0.38))
			draw_circle(Vector2.ZERO, 13.0, Color(0.50, 0.50, 0.56))
			for i in range(6):
				var ang = i * (PI / 3.0)
				draw_line(Vector2.ZERO, Vector2(cos(ang), sin(ang)) * 18.0, Color(0.82, 0.28, 0.18), 2.5)
			draw_circle(Vector2.ZERO, 4.5, Color(1.0, 0.85, 0.2))

		"flame_tower":
			# Lava pillar with animated flame crown
			draw_circle(Vector2(0, 4), 16.0, Color(0.22, 0.10, 0.05))
			draw_circle(Vector2.ZERO, 13.0, Color(0.7, 0.22, 0.05))
			for i in range(5):
				var fang = i * (TAU / 5.0) + anim_time * 0.8
				var fp = Vector2(cos(fang), sin(fang)) * 10.0
				draw_circle(fp, 4.5 + sin(anim_time * 2.0 + i) * 1.5, Color(1.0, 0.5, 0.05, 0.85))
				draw_circle(fp, 2.5, Color(1.0, 0.9, 0.3))

		"poison_tower":
			# Green bubbling poison vat
			draw_circle(Vector2(0, 4), 16.0, Color(0.10, 0.18, 0.08))
			draw_circle(Vector2.ZERO, 13.0, Color(0.22, 0.55, 0.12))
			for i in range(4):
				var bang = i * (TAU / 4.0) + anim_time * 0.5
				var bp = Vector2(cos(bang), sin(bang)) * 7.0
				draw_circle(bp, 3.0 + sin(anim_time * 1.5 + i * 1.2) * 1.0, Color(0.5, 0.9, 0.2, 0.75))
			draw_circle(Vector2.ZERO, 3.5, Color(0.8, 1.0, 0.3))

		"trading_post":
			# Golden coin stack
			draw_circle(Vector2(0, 5), 16.0, Color(0.38, 0.28, 0.06))
			draw_circle(Vector2.ZERO, 13.0, Color(0.85, 0.68, 0.12))
			draw_circle(Vector2.ZERO, 9.0, Color(1.0, 0.88, 0.3))
			draw_circle(Vector2(-3, -3), 3.5, Color(1.0, 1.0, 0.8, 0.9))
			draw_circle(Vector2(3, 3), 2.5, Color(1.0, 0.95, 0.5, 0.8))

		"necromancer":
			# Dark purple arcane tower with orbiting skull orbs
			draw_circle(Vector2.ZERO, 14.0, Color(0.12, 0.06, 0.28))
			draw_arc(Vector2.ZERO, 14.0, 0, TAU, 18, Color(0.55, 0.15, 0.85, 0.8), 2.5)
			for i in range(3):
				var oang = anim_time * 1.0 + i * (TAU / 3.0)
				var op = Vector2(cos(oang), sin(oang)) * 12.0
				draw_circle(op, 3.5, Color(0.88, 0.85, 0.78, 0.9))
				draw_circle(op + Vector2(-1.2, 0), 1.2, Color(0.1, 0.05, 0.1))
				draw_circle(op + Vector2(1.2, 0), 1.2, Color(0.1, 0.05, 0.1))
			draw_circle(Vector2.ZERO, 4.5, Color(0.5, 0.15, 0.8))

		"time_tower":
			# Clock tower with rotating hands
			draw_circle(Vector2.ZERO, 14.0, Color(0.20, 0.18, 0.35))
			draw_arc(Vector2.ZERO, 14.0, 0, TAU, 24, Color(0.6, 0.55, 0.85, 0.85), 2.5)
			var hour_ang = anim_time * 0.3
			var min_ang = anim_time * 1.8
			draw_line(Vector2.ZERO, Vector2(cos(hour_ang), sin(hour_ang)) * 8.0, Color(1.0, 0.9, 0.5), 2.5)
			draw_line(Vector2.ZERO, Vector2(cos(min_ang), sin(min_ang)) * 11.0, Color(0.8, 0.8, 1.0), 1.5)
			draw_circle(Vector2.ZERO, 2.5, Color(1.0, 0.95, 0.6))

		"watchtower":
			# Tall watchtower with sniper scope
			draw_circle(Vector2(0, 4), 12.0, Color(0.30, 0.22, 0.14))
			draw_circle(Vector2.ZERO, 10.0, Color(0.55, 0.42, 0.25))
			draw_line(Vector2.ZERO, aim_dir * 22.0, Color(0.18, 0.18, 0.22), 3.0)
			draw_line(Vector2.ZERO, aim_dir * 23.0, Color(0.6, 0.55, 0.3), 1.0)
			draw_circle(aim_dir * 14.0, 2.5, Color(0.9, 0.15, 0.15, 0.9))

		"support_tower":
			# Support pillar with pulsing aura rings
			draw_circle(Vector2.ZERO, 13.0, Color(0.5, 0.4, 0.15))
			draw_circle(Vector2.ZERO, 9.0, Color(0.9, 0.8, 0.3))
			for i in range(3):
				var ring_r = 11.0 + i * 6.0 + sin(anim_time * 1.5 + i) * 2.0
				draw_arc(Vector2.ZERO, ring_r, 0, TAU, 20, Color(1.0, 0.9, 0.3, 0.4 - i * 0.1), 1.5)
			draw_circle(Vector2.ZERO, 4.0, Color(1.0, 1.0, 0.6))

		"trap":
			# Spike trap
			for i in range(8):
				var tang = i * (TAU / 8.0)
				draw_line(Vector2(cos(tang), sin(tang)) * 8.0, Vector2(cos(tang), sin(tang)) * 16.0, Color(0.55, 0.45, 0.15), 3.0)
			draw_circle(Vector2.ZERO, 8.0, Color(0.35, 0.28, 0.10))
			draw_circle(Vector2.ZERO, 5.0, Color(0.7, 0.55, 0.2))


		_:
			# Generic fallback — stone circle tower
			draw_circle(Vector2(0, 3), 16.0, Color(0.28, 0.28, 0.32))
			draw_circle(Vector2.ZERO, 13.0, Color(0.48, 0.46, 0.50))
			draw_circle(Vector2.ZERO, 7.0, Color(0.32, 0.30, 0.34))
			draw_line(Vector2.ZERO, aim_dir * 15.0, Color(0.7, 0.6, 0.4), 3.0)

	# Level stars beneath tower
	for i in range(current_level):
		var offset_x = (i - (current_level - 1) * 0.5) * 9.0
		draw_circle(Vector2(offset_x, 20), 3.0, Color(1.0, 0.85, 0.2))
		draw_circle(Vector2(offset_x, 20), 1.5, Color(1.0, 1.0, 0.8))

