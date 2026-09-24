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
		if not levels.is_empty():
			max_level = levels.size()
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
	var art_mgr = get_tree().get_first_node_in_group("artifact_manager") as ArtifactManager
	if art_mgr and art_mgr.has_active_effect("damage_mult"):
		dmg *= (1.0 + art_mgr.get_effect_value("damage_mult"))
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
	var art_mgr = get_tree().get_first_node_in_group("artifact_manager") as ArtifactManager
	if art_mgr and art_mgr.has_active_effect("range_mult"):
		r *= (1.0 + art_mgr.get_effect_value("range_mult"))
	return r

func get_effective_attack_speed() -> float:
	var spd: float = attack_speed * get_buff_multiplier("attack_speed")
	if not is_inside_tree() or get_tree() == null:
		return spd
	var gm = get_tree().get_first_node_in_group("game_manager") as GameManager
	if gm and gm.ability_active and gm.selected_path == "military":
		spd *= 2.0
	var tech = get_tree().get_first_node_in_group("tech_tree_manager") as TechTreeManager
	if tech and tech.is_berserk_unlocked():
		spd *= 2.0
	var art_mgr = get_tree().get_first_node_in_group("artifact_manager") as ArtifactManager
	if art_mgr:
		if art_mgr.has_active_effect("attack_speed_mult"):
			spd *= (1.0 + art_mgr.get_effect_value("attack_speed_mult"))
		if art_mgr.has_active_effect("kill_speed_surge"):
			spd *= (1.0 + art_mgr.get_effect_value("kill_speed_surge"))
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

func get_chapter_max_level() -> int:
	var chapter = 1
	if is_inside_tree() and get_tree() != null:
		var gm = get_tree().get_first_node_in_group("game_manager") as GameManager
		if gm and "current_chapter" in gm and gm.current_chapter > 0:
			chapter = gm.current_chapter
		elif "current_chapter" in GlobalState and GlobalState.current_chapter > 0:
			chapter = GlobalState.current_chapter
	elif "current_chapter" in GlobalState and GlobalState.current_chapter > 0:
		chapter = GlobalState.current_chapter
	else:
		return 5
	
	if chapter <= 2:
		return 3
	elif chapter <= 4:
		return 4
	else:
		return 5

func can_upgrade() -> bool:
	if current_level >= get_chapter_max_level():
		return false
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
	if is_inside_tree() and get_tree() != null:
		if get_chapter_max_level() < 5:
			return false
	var req_level = max_level
	if current_level == 3:
		req_level = 3
	return current_level >= req_level and evolution_chosen == "" and (not evolution_data_a.is_empty() or not evolution_data_b.is_empty())

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
	if current_level >= 4:
		current_level = 5
	else:
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

	# Аура активных баффов
	if not active_buffs.is_empty():
		var aura_alpha = 0.35 + sin(anim_time * 2.5) * 0.18
		draw_arc(Vector2(0, -6), 22.0, 0, TAU, 24, Color(1.0, 0.85, 0.2, aura_alpha), 2.2)
		draw_arc(Vector2(0, -6), 26.0, 0, TAU, 24, Color(1.0, 0.95, 0.4, aura_alpha * 0.5), 1.0)

	var aim_dir = Vector2(cos(turret_angle), sin(turret_angle))

	# Мягкая глубинная тень под башней в ракурсе 2.5D
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.52))
	draw_circle(Vector2(3, 20), 18.0, Color(0.0, 0.0, 0.0, 0.36))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 1.0))

	match tower_type:

		"archer", "crossbowman":
			# 2.5D Деревянная дозорная вышка с лучником и черепичным навесом
			var wood_dark = Color(0.32, 0.18, 0.08)
			var wood_mid = Color(0.54, 0.34, 0.16)
			var wood_light = Color(0.68, 0.46, 0.24)
			var tile_col = Color(0.72, 0.28, 0.20)
			
			# Четыре опорных бревенчатых столба
			draw_line(Vector2(-12, 6), Vector2(-9, -16), wood_dark, 3.5)
			draw_line(Vector2(12, 6), Vector2(9, -16), wood_dark, 3.5)
			draw_line(Vector2(-12, 6), Vector2(12, 6), wood_mid, 3.0)
			# Диагональные балки жесткости
			draw_line(Vector2(-10, 4), Vector2(8, -14), wood_dark, 1.8)
			draw_line(Vector2(10, 4), Vector2(-8, -14), wood_dark, 1.8)
			
			# Боевая деревянная платформа с перилами
			draw_colored_polygon(PackedVector2Array([
				Vector2(-13, -14), Vector2(13, -14),
				Vector2(11, -8), Vector2(-11, -8)
			]), wood_light)
			draw_polyline(PackedVector2Array([
				Vector2(-13, -14), Vector2(13, -14),
				Vector2(11, -8), Vector2(-11, -8), Vector2(-13, -14)
			]), wood_dark, 1.5)
			
			# Фигурка лучника на вышке
			draw_circle(Vector2(0, -16), 4.5, Color(0.24, 0.48, 0.22)) # Зеленый охотничий капюшон
			draw_circle(Vector2(0, -17), 3.0, Color(0.95, 0.85, 0.72)) # Лицо
			
			# Лук / Арбалет, поворачивающийся к цели
			var bow_pos = Vector2(0, -15) + aim_dir * 8.0
			draw_line(bow_pos - aim_dir.orthogonal() * 7.0, bow_pos + aim_dir.orthogonal() * 7.0, wood_dark, 2.5)
			draw_line(bow_pos - aim_dir.orthogonal() * 7.0, bow_pos - aim_dir * 4.0, Color(0.9, 0.9, 0.85), 1.2)
			draw_line(bow_pos + aim_dir.orthogonal() * 7.0, bow_pos - aim_dir * 4.0, Color(0.9, 0.9, 0.85), 1.2)
			# Наложенная стрела
			draw_line(bow_pos - aim_dir * 4.0, bow_pos + aim_dir * 8.0, Color(0.7, 0.7, 0.75), 1.8)
			draw_circle(bow_pos + aim_dir * 8.0, 1.5, Color(0.9, 0.2, 0.2)) # Оперение
			
			# Черепичная остроконечная крыша
			var roof = PackedVector2Array([
				Vector2(-15, -20), Vector2(0, -32), Vector2(15, -20)
			])
			draw_colored_polygon(roof, tile_col)
			draw_polyline(roof, tile_col.darkened(0.3), 2.0)
			# Коньковый вымпел
			draw_line(Vector2(0, -32), Vector2(0, -37), wood_dark, 1.5)
			draw_colored_polygon(PackedVector2Array([Vector2(0, -37), Vector2(6, -34), Vector2(0, -31)]), Color(0.9, 0.8, 0.2))

		"cannon", "siege_cannon":
			# 2.5D Гранитный форт с поворотной чугунной мортирой
			var stone_dark = Color(0.24, 0.26, 0.30)
			var stone_mid = Color(0.42, 0.45, 0.50)
			var stone_light = Color(0.60, 0.64, 0.70)
			var iron_barrel = Color(0.18, 0.19, 0.22)
			var iron_highlight = Color(0.45, 0.48, 0.54)
			var brass_trim = Color(0.85, 0.70, 0.25)
			
			# Круглый каменный форт с зубцами
			draw_rect(Rect2(-13, -2, 26, 12), stone_mid)
			draw_line(Vector2(-13, 10), Vector2(13, 10), stone_dark, 2.0)
			for i in range(3):
				draw_rect(Rect2(-12 + i * 10, -7, 6, 6), stone_light)
			
			# Поворотный чугунный лафет
			draw_circle(Vector2(0, -3), 11.0, stone_dark)
			draw_circle(Vector2(0, -3), 9.0, iron_barrel)
			
			# Массивный нарезной ствол пушки в направлении цели
			var barrel_start = Vector2(0, -3) - aim_dir * 4.0
			var barrel_end = Vector2(0, -3) + aim_dir * 18.0
			var b_norm = aim_dir.orthogonal()
			var barrel_poly = PackedVector2Array([
				barrel_start - b_norm * 4.5, barrel_start + b_norm * 4.5,
				barrel_end + b_norm * 3.8, barrel_end - b_norm * 3.8
			])
			draw_colored_polygon(barrel_poly, iron_barrel)
			draw_polyline(barrel_poly, iron_highlight, 1.5)
			
			# Латунные обода усиления ствола
			draw_line(barrel_start + aim_dir * 6.0 - b_norm * 4.6, barrel_start + aim_dir * 6.0 + b_norm * 4.6, brass_trim, 2.0)
			draw_line(barrel_start + aim_dir * 14.0 - b_norm * 4.2, barrel_start + aim_dir * 14.0 + b_norm * 4.2, brass_trim, 2.0)
			
			# Жерло пушки с темным отверстием
			draw_circle(barrel_end, 3.8, iron_highlight)
			draw_circle(barrel_end, 2.4, Color(0.06, 0.06, 0.08))

		"ice_mage":
			# 2.5D Ледяной монумент с левитирующими сапфировыми кристаллами
			var float_y = sin(anim_time * 2.0) * 3.5
			var ice_deep = Color(0.12, 0.35, 0.65)
			var ice_mid = Color(0.28, 0.65, 0.92)
			var ice_bright = Color(0.70, 0.94, 1.0)
			
			# Рунический ледяной обелиск-основание
			var base_poly = PackedVector2Array([
				Vector2(-12, 8), Vector2(12, 8),
				Vector2(7, -8), Vector2(-7, -8)
			])
			draw_colored_polygon(base_poly, ice_deep)
			draw_polyline(base_poly, ice_bright, 1.5)
			
			# Парящий в воздухе граненый центральный ледяной кристалл
			var crystal_pts = PackedVector2Array([
				Vector2(0, -26 + float_y),
				Vector2(8, -13 + float_y),
				Vector2(0, 0 + float_y),
				Vector2(-8, -13 + float_y)
			])
			draw_colored_polygon(crystal_pts, ice_mid)
			# Световые грани кристалла
			draw_colored_polygon(PackedVector2Array([Vector2(0, -26 + float_y), Vector2(0, 0 + float_y), Vector2(-8, -13 + float_y)]), ice_deep)
			draw_colored_polygon(PackedVector2Array([Vector2(0, -26 + float_y), Vector2(0, 0 + float_y), Vector2(8, -13 + float_y)]), ice_bright)
			draw_polyline(crystal_pts, Color(1.0, 1.0, 1.0, 0.9), 1.5)
			
			# 3 вращающихся сателлитных кристаллика
			for i in range(3):
				var ang = anim_time * 1.8 + i * (TAU / 3.0)
				var c_pos = Vector2(cos(ang) * 14.0, sin(ang) * 6.0 - 13.0 + float_y)
				draw_circle(c_pos, 2.5, ice_bright)
				draw_circle(c_pos, 1.2, Color(1, 1, 1))

		"tesla", "auto_turret":
			# 2.5D Медная электростанция с керамическими изоляторами и молниями
			var copper = Color(0.75, 0.42, 0.20)
			var brass = Color(0.88, 0.72, 0.30)
			var ceramic = Color(0.85, 0.88, 0.92)
			var arc_col = Color(0.35, 0.85, 1.0)
			
			# Цилиндрический медный генератор
			draw_rect(Rect2(-11, -2, 22, 12), copper)
			draw_rect(Rect2(-9, -2, 18, 3), brass)
			
			# Керамические кольца-изоляторы
			for i in range(3):
				var iy = -6 - i * 6
				draw_rect(Rect2(-7, iy, 14, 4), ceramic)
				draw_rect(Rect2(-5, iy + 1, 10, 2), copper)
				
			# Верхняя сфера Теслы
			var sphere_pos = Vector2(0, -24)
			draw_circle(sphere_pos, 7.5, brass)
			draw_circle(sphere_pos, 5.0, arc_col)
			draw_circle(sphere_pos, 2.5, Color(1, 1, 1))
			
			# Анимированные электрические разряды в сторону цели
			var spark_t = anim_time * 8.0
			var spark_pts: Array[Vector2] = [sphere_pos]
			for step in range(3):
				var seg = sphere_pos + aim_dir * (float(step + 1) * 7.0) + aim_dir.orthogonal() * sin(spark_t + step * 2.0) * 4.0
				spark_pts.append(seg)
			draw_polyline(PackedVector2Array(spark_pts), arc_col, 2.0)
			draw_polyline(PackedVector2Array(spark_pts), Color(1, 1, 1), 1.0)

		"bastion", "wall":
			# 2.5D Могучая цитадель с бойницами и гербовым щитом
			var s_dark = Color(0.26, 0.28, 0.32)
			var s_mid = Color(0.48, 0.50, 0.56)
			var s_light = Color(0.68, 0.70, 0.76)
			
			# Башня крепости
			draw_rect(Rect2(-14, -8, 28, 18), s_mid)
			draw_line(Vector2(-14, 10), Vector2(14, 10), s_dark, 2.5)
			# Каменные зубцы (мерлоны)
			draw_rect(Rect2(-14, -14, 7, 7), s_light)
			draw_rect(Rect2(-3, -14, 6, 7), s_light)
			draw_rect(Rect2(7, -14, 7, 7), s_light)
			
			# Узкая стрелковая амбразура
			draw_rect(Rect2(-2, -4, 4, 9), Color(0.12, 0.12, 0.14))
			
			# Рыцарский геральдический щит на фасаде
			var shield_poly = PackedVector2Array([
				Vector2(-6, 0), Vector2(6, 0),
				Vector2(6, 6), Vector2(0, 11), Vector2(-6, 6)
			])
			draw_colored_polygon(shield_poly, Color(0.85, 0.22, 0.18))
			draw_polyline(shield_poly, Color(0.95, 0.85, 0.3), 1.5)
			draw_line(Vector2(0, 1), Vector2(0, 9), Color(0.95, 0.85, 0.3), 1.5)

		"flame_tower":
			# 2.5D Обсидиановый горн с лавовыми трещинами и языками пламени
			draw_rect(Rect2(-12, -4, 24, 14), Color(0.18, 0.14, 0.12))
			# Раскаленные магматические разломы
			draw_line(Vector2(-8, 6), Vector2(-2, 0), Color(1.0, 0.45, 0.1), 2.2)
			draw_line(Vector2(-2, 0), Vector2(7, 4), Color(1.0, 0.7, 0.15), 1.8)
			
			# Чаша огня
			draw_circle(Vector2(0, -6), 11.0, Color(0.24, 0.18, 0.15))
			draw_circle(Vector2(0, -7), 9.0, Color(0.85, 0.3, 0.05))
			
			# Динамические языки пламени
			for i in range(4):
				var fa = anim_time * 3.5 + i * (TAU / 4.0)
				var fl_pos = Vector2(cos(fa) * 5.0, sin(fa) * 3.0 - 10.0 - sin(anim_time * 5.0 + i) * 3.0)
				draw_circle(fl_pos, 4.0, Color(1.0, 0.55, 0.08, 0.9))
				draw_circle(fl_pos + Vector2(0, -2), 2.2, Color(1.0, 0.95, 0.3))

		"poison_tower":
			# 2.5D Лабораторный алхимический реактор с колбой и кислотой
			var brass = Color(0.72, 0.58, 0.22)
			var acid_col = Color(0.25, 0.88, 0.25)
			
			# Латунная станина
			draw_rect(Rect2(-10, 2, 20, 8), brass)
			# Стеклянный ретортообразный чан с бурлящей кислотой
			draw_circle(Vector2(0, -4), 10.0, Color(0.12, 0.28, 0.15, 0.85))
			draw_circle(Vector2(0, -3), 8.5, acid_col)
			# Пузыри кислоты
			for i in range(3):
				var bx = -4.0 + i * 4.0
				var by = -4.0 + sin(anim_time * 4.0 + i * 2.0) * 2.5
				draw_circle(Vector2(bx, by), 2.0, Color(0.7, 1.0, 0.4))
			# Латунный колпак и змеевик
			draw_rect(Rect2(-6, -15, 12, 5), brass)
			draw_line(Vector2(0, -15), Vector2(0, -4) + aim_dir * 12.0, Color(0.85, 0.75, 0.3), 2.5)

		"trading_post":
			# 2.5D Золотая казна с парчовым шатром и монетами
			draw_rect(Rect2(-12, -2, 24, 12), Color(0.48, 0.30, 0.15))
			# Полосатый купеческий навес
			for i in range(5):
				var col = Color(0.85, 0.2, 0.2) if i % 2 == 0 else Color(0.95, 0.92, 0.8)
				draw_rect(Rect2(-12 + i * 5, -8, 5, 7), col)
			# Горка золотых монет
			draw_circle(Vector2(-3, 2), 3.5, Color(1.0, 0.85, 0.25))
			draw_circle(Vector2(3, 3), 3.5, Color(1.0, 0.85, 0.25))
			draw_circle(Vector2(0, -1), 3.5, Color(1.0, 0.95, 0.5))
			# Золотой купол с флюгером
			draw_circle(Vector2(0, -12), 6.0, Color(0.95, 0.82, 0.22))
			draw_line(Vector2(0, -12), Vector2(0, -19), Color(0.95, 0.82, 0.22), 2.0)

		"necromancer":
			# 2.5D Обсидиановый склеп с парящей сферой душ
			draw_colored_polygon(PackedVector2Array([
				Vector2(-11, 8), Vector2(11, 8),
				Vector2(6, -8), Vector2(-6, -8)
			]), Color(0.12, 0.08, 0.18))
			draw_polyline(PackedVector2Array([
				Vector2(-11, 8), Vector2(11, 8),
				Vector2(6, -8), Vector2(-6, -8), Vector2(-11, 8)
			]), Color(0.55, 0.2, 0.85), 1.5)
			
			# Парящая сфера душ
			var soul_y = -18.0 + sin(anim_time * 2.2) * 3.0
			draw_circle(Vector2(0, soul_y), 7.0, Color(0.2, 0.05, 0.35))
			draw_circle(Vector2(0, soul_y), 5.0, Color(0.7, 0.2, 1.0))
			draw_circle(Vector2(0, soul_y), 2.5, Color(0.95, 0.85, 1.0))
			# Орбитальные черепа-огоньки
			for i in range(2):
				var sa = anim_time * 1.5 + i * PI
				var sp = Vector2(cos(sa) * 12.0, sin(sa) * 5.0 + soul_y)
				draw_circle(sp, 2.8, Color(0.85, 0.85, 0.78))
				draw_circle(sp, 1.0, Color(0.1, 0.0, 0.1))

		"time_tower":
			# 2.5D Башня с часовым циферблатом и маятником
			draw_rect(Rect2(-11, -6, 22, 16), Color(0.25, 0.22, 0.35))
			# Золоченый циферблат
			var clock_pos = Vector2(0, -8)
			draw_circle(clock_pos, 9.0, Color(0.92, 0.84, 0.60))
			draw_arc(clock_pos, 9.0, 0, TAU, 24, Color(0.35, 0.25, 0.12), 2.0)
			# Стрелки часов
			var ha = anim_time * 0.4
			var ma = anim_time * 2.2
			draw_line(clock_pos, clock_pos + Vector2(cos(ha), sin(ha)) * 5.0, Color(0.15, 0.12, 0.10), 2.0)
			draw_line(clock_pos, clock_pos + Vector2(cos(ma), sin(ma)) * 7.5, Color(0.15, 0.12, 0.10), 1.4)
			# Шпиль с куполом
			draw_colored_polygon(PackedVector2Array([
				Vector2(-10, -16), Vector2(0, -28), Vector2(10, -16)
			]), Color(0.45, 0.65, 0.60))

		"watchtower":
			# 2.5D Высокий бревенчатый снайперский пост
			draw_line(Vector2(-8, 8), Vector2(-5, -20), Color(0.35, 0.22, 0.12), 3.0)
			draw_line(Vector2(8, 8), Vector2(5, -20), Color(0.35, 0.22, 0.12), 3.0)
			draw_rect(Rect2(-10, -23, 20, 6), Color(0.55, 0.38, 0.22))
			# Снайперская подзорная труба
			var scope_start = Vector2(0, -20)
			var scope_end = scope_start + aim_dir * 18.0
			draw_line(scope_start, scope_end, Color(0.85, 0.72, 0.30), 3.0)
			draw_circle(scope_end, 2.5, Color(0.3, 0.8, 1.0))

		"support_tower":
			# 2.5D Белокаменное святилище с сияющей чашей
			draw_rect(Rect2(-12, -4, 24, 14), Color(0.85, 0.86, 0.90))
			draw_rect(Rect2(-14, 8, 28, 4), Color(0.70, 0.72, 0.78))
			# Колонны
			draw_line(Vector2(-8, -4), Vector2(-8, 8), Color(0.95, 0.96, 0.98), 3.0)
			draw_line(Vector2(8, -4), Vector2(8, 8), Color(0.95, 0.96, 0.98), 3.0)
			# Золотой кубок благословения
			draw_circle(Vector2(0, -9), 6.0, Color(0.95, 0.82, 0.25))
			draw_circle(Vector2(0, -11), 3.5, Color(1.0, 0.95, 0.6))
			# Лучи ауры
			draw_arc(Vector2(0, -9), 12.0 + sin(anim_time * 2.0) * 2.0, 0, TAU, 20, Color(1.0, 0.9, 0.3, 0.5), 1.5)

		"trap":
			# 2.5D Стальной капкан с зубьями
			draw_circle(Vector2(0, 4), 14.0, Color(0.24, 0.26, 0.28))
			draw_circle(Vector2(0, 4), 11.0, Color(0.38, 0.40, 0.44))
			for i in range(8):
				var ta = i * (TAU / 8.0)
				draw_line(Vector2(cos(ta) * 6.0, sin(ta) * 4.0 + 4), Vector2(cos(ta) * 13.0, sin(ta) * 9.0 + 4), Color(0.75, 0.78, 0.82), 2.2)

		_:
			# 2.5D Базовый каменный бастион
			draw_rect(Rect2(-12, -6, 24, 16), Color(0.42, 0.44, 0.48))
			draw_rect(Rect2(-12, -11, 7, 5), Color(0.55, 0.58, 0.62))
			draw_rect(Rect2(5, -11, 7, 5), Color(0.55, 0.58, 0.62))
			draw_line(Vector2(0, -6), Vector2(0, -6) + aim_dir * 14.0, Color(0.2, 0.2, 0.25), 3.5)

	# Отрисовка уникального внешнего вида каждого уровня (1-5) и эмблемы
	_draw_level_augmentations(aim_dir)
	_draw_level_emblem()

func _draw_level_augmentations(aim_dir: Vector2) -> void:
	# Уровень 2: Укреплённые стальные пластины и скобы
	if current_level >= 2:
		var steel_dark = Color(0.18, 0.20, 0.24)
		var steel_light = Color(0.65, 0.70, 0.78)
		draw_line(Vector2(-15, 6), Vector2(-15, -4), steel_light, 2.5)
		draw_line(Vector2(15, 6), Vector2(15, -4), steel_light, 2.5)
		draw_circle(Vector2(-15, 4), 1.6, steel_dark)
		draw_circle(Vector2(15, 4), 1.6, steel_dark)
		draw_line(Vector2(-14, 8), Vector2(14, 8), steel_light, 1.8)

	# Уровень 3: Золоченая отделка, рунический круг силы и усиленное вооружение
	if current_level >= 3:
		var gold_trim = Color(1.0, 0.85, 0.25)
		var r_angle = anim_time * 1.5
		draw_arc(Vector2(0, 10), 16.0, 0, TAU, 16, Color(1.0, 0.85, 0.25, 0.35), 1.5)
		for i in range(4):
			var ra = r_angle + i * (TAU / 4.0)
			draw_circle(Vector2(0, 10) + Vector2(cos(ra) * 16.0, sin(ra) * 8.0), 2.0, gold_trim)
		draw_line(Vector2(-12, -8), Vector2(-8, -12), gold_trim, 2.0)
		draw_line(Vector2(12, -8), Vector2(8, -12), gold_trim, 2.0)

	# Уровень 4: Элитный рубеж — цитадельные шипастые зубцы, аркановые кристаллы и импульсы
	if current_level >= 4:
		var plat = Color(0.4, 0.85, 1.0)
		for i in range(2):
			var sa = anim_time * 2.5 + i * PI
			var sp = Vector2(cos(sa) * 22.0, sin(sa) * 10.0 - 10.0)
			draw_circle(sp, 3.2, plat)
			draw_circle(sp, 1.6, Color(1, 1, 1))
		draw_colored_polygon(PackedVector2Array([Vector2(-16, -6), Vector2(-19, -10), Vector2(-13, -10)]), Color(0.3, 0.35, 0.42))
		draw_colored_polygon(PackedVector2Array([Vector2(16, -6), Vector2(19, -10), Vector2(13, -10)]), Color(0.3, 0.35, 0.42))
		var barrier_alpha = 0.25 + sin(anim_time * 4.0) * 0.15
		draw_arc(Vector2(0, 0), 24.0, 0, TAU, 24, Color(0.3, 0.8, 1.0, barrier_alpha), 2.0)

	# Уровень 5: Легендарная визуальная эволюция (Выбор из 2: Ветка A vs Ветка B)
	if current_level >= 5 and evolution_chosen != "":
		var is_a = evolution_chosen == "evolution_a"
		var theme_col = Color(0.2, 0.9, 0.4) if is_a else Color(1.0, 0.45, 0.1)
		
		var pulse = sin(anim_time * 5.0) * 3.0
		draw_arc(Vector2(0, -12), 26.0 + pulse, 0, TAU, 28, Color(theme_col.r, theme_col.g, theme_col.b, 0.45), 2.5)
		
		match tower_type:
			"archer", "crossbowman", "watchtower":
				if is_a:
					draw_line(Vector2(0, -16), Vector2(0, -16) + aim_dir * 85.0, Color(0.2, 1.0, 0.3, 0.65), 1.5)
					draw_circle(Vector2(0, -16) + aim_dir * 85.0, 3.0, Color(0.2, 1.0, 0.3, 0.9))
					draw_line(Vector2(0, -16) - aim_dir.orthogonal() * 10.0, Vector2(0, -16) + aim_dir.orthogonal() * 10.0, Color(0.1, 0.8, 0.3), 3.0)
				else:
					var barrel_base = Vector2(0, -16) + aim_dir * 12.0
					for b in range(4):
						var b_off = aim_dir.orthogonal() * (float(b) - 1.5) * 4.0
						draw_line(barrel_base + b_off, barrel_base + b_off + aim_dir * 10.0, Color(0.85, 0.45, 0.1), 2.2)
					draw_circle(barrel_base + aim_dir * 12.0, 4.5, Color(1.0, 0.9, 0.2, 0.8))

			"cannon", "siege_cannon":
				if is_a:
					draw_line(Vector2(0, -4) - aim_dir.orthogonal() * 8.0, Vector2(0, -4) + aim_dir.orthogonal() * 8.0, Color(0.85, 0.7, 0.2), 4.0)
					draw_circle(Vector2(0, -4) + aim_dir * 22.0, 6.0, Color(0.1, 0.1, 0.12))
					draw_arc(Vector2(0, -4) + aim_dir * 22.0, 6.0, 0, TAU, 16, Color(1.0, 0.8, 0.2), 2.0)
				else:
					for i in [-1, 0, 1]:
						var t_dir = aim_dir.rotated(i * 0.22)
						draw_line(Vector2(0, -4), Vector2(0, -4) + t_dir * 16.0, Color(0.9, 0.35, 0.15), 3.0)
						draw_circle(Vector2(0, -4) + t_dir * 16.0, 3.0, Color(1.0, 0.8, 0.2))

			"ice_mage":
				if is_a:
					for i in range(5):
						var ca = anim_time * 3.0 + i * (TAU / 5.0)
						var cp = Vector2(cos(ca) * 20.0, sin(ca) * 8.0 - 15.0)
						draw_circle(cp, 3.5, Color(0.5, 0.9, 1.0))
						draw_circle(cp, 1.8, Color(1, 1, 1))
				else:
					for i in range(6):
						var sa = i * (TAU / 6.0)
						var sp1 = Vector2(cos(sa) * 14.0, sin(sa) * 8.0 + 8.0)
						var sp2 = sp1 + Vector2(0, -12.0)
						draw_line(sp1, sp2, Color(0.15, 0.45, 0.85), 3.0)

			"tesla", "auto_turret":
				if is_a:
					var p1 = Vector2(-12, -22)
					var p2 = Vector2(12, -22)
					draw_circle(p1, 5.0, Color(0.3, 0.85, 1.0))
					draw_circle(p2, 5.0, Color(0.3, 0.85, 1.0))
					draw_line(p1, p2, Color(1.0, 1.0, 1.0, 0.9), 2.0)
					draw_line(p1, p1 + aim_dir * 18.0, Color(0.3, 0.9, 1.0), 2.5)
					draw_line(p2, p2 + aim_dir * 18.0, Color(0.3, 0.9, 1.0), 2.5)
				else:
					var emp_r = fmod(anim_time * 35.0, 32.0)
					draw_arc(Vector2(0, -10), emp_r, 0, TAU, 20, Color(0.2, 0.6, 1.0, 1.0 - (emp_r / 32.0)), 2.5)
					draw_line(Vector2(0, -15), Vector2(0, -15) + aim_dir * 45.0, Color(0.85, 0.95, 1.0), 3.5)

			"flame_tower", "poison_tower":
				if is_a:
					draw_circle(Vector2(-14, 2), 5.5, Color(0.85, 0.35, 0.1))
					draw_circle(Vector2(14, 2), 5.5, Color(0.85, 0.35, 0.1))
					draw_arc(Vector2(0, -8), 16.0, 0, TAU, 16, Color(1.0, 0.5, 0.1, 0.6), 2.5)
				else:
					draw_circle(Vector2(0, -6), 9.0, Color(0.1, 0.8, 0.9, 0.8))
					draw_circle(Vector2(0, -6), 5.0, Color(1, 1, 1, 0.9))

			"rock_catapult":
				if is_a:
					draw_line(Vector2(-10, 4), Vector2(-16, -20), Color(0.4, 0.25, 0.12), 4.0)
					draw_circle(Vector2(-16, -20), 8.0, Color(0.2, 0.2, 0.22))
					draw_line(Vector2(0, -6), Vector2(0, -6) + aim_dir * 30.0, Color(0.6, 0.4, 0.2), 3.0)
				else:
					draw_line(Vector2(0, -6), Vector2(0, -6) + aim_dir * 25.0, Color(0.3, 0.35, 0.4), 4.5)
					draw_arc(Vector2(0, -6) + aim_dir * 12.0, 14.0, 0, TAU, 16, Color(1.0, 0.5, 0.1), 2.0)

			"sniper":
				if is_a:
					draw_line(Vector2(0, -14), Vector2(0, -14) + aim_dir * 110.0, Color(0.1, 1.0, 0.5, 0.7), 1.8)
					draw_circle(Vector2(0, -14) + aim_dir * 110.0, 4.0, Color(0.2, 1.0, 0.6))
				else:
					draw_line(Vector2(0, -14), Vector2(0, -14) + aim_dir * 55.0, Color(0.4, 0.8, 1.0), 3.5)
					draw_circle(Vector2(0, -14) + aim_dir * 25.0, 6.0, Color(0.6, 0.9, 1.0, 0.8))

			"lightning_spire", "storm_tower":
				if is_a:
					for i in range(4):
						var la = anim_time * 6.0 + i * (TAU / 4.0)
						var lp = Vector2(cos(la) * 22.0, sin(la) * 12.0 - 20.0)
						draw_circle(lp, 3.5, Color(0.3, 0.9, 1.0))
						draw_line(Vector2(0, -20), lp, Color(1, 1, 1, 0.8), 1.5)
				else:
					draw_arc(Vector2(0, -22), 24.0, 0, TAU, 24, Color(0.8, 0.4, 1.0, 0.7), 3.0)
					draw_circle(Vector2(0, -22), 8.0, Color(1.0, 0.8, 1.0))

			"arcane_tower":
				if is_a:
					draw_arc(Vector2(0, -14), 22.0, anim_time * 2.0, anim_time * 2.0 + PI * 1.5, 20, Color(0.7, 0.2, 0.9), 3.0)
					draw_circle(Vector2(0, -14), 7.0, Color(0.15, 0.05, 0.25))
				else:
					for i in range(3):
						var ra = anim_time * 3.0 + i * (TAU / 3.0)
						draw_circle(Vector2(0, -14) + Vector2(cos(ra) * 18.0, sin(ra) * 18.0), 4.0, Color(0.9, 0.3, 1.0))

			"mortar":
				if is_a:
					draw_line(Vector2(0, -4), Vector2(0, -4) + aim_dir * 24.0, Color(0.2, 0.22, 0.26), 7.0)
					draw_circle(Vector2(0, -4) + aim_dir * 24.0, 5.0, Color(0.85, 0.3, 0.1))
				else:
					for k in [-1, 0, 1]:
						var kd = aim_dir.rotated(k * 0.28)
						draw_line(Vector2(0, -4), Vector2(0, -4) + kd * 18.0, Color(0.3, 0.35, 0.4), 3.5)

			"laser_crystal":
				if is_a:
					draw_line(Vector2(0, -12), Vector2(0, -12) + aim_dir * 90.0, Color(1.0, 0.1, 0.3, 0.85), 2.8)
					draw_circle(Vector2(0, -12) + aim_dir * 90.0, 4.0, Color(1.0, 0.5, 0.7))
				else:
					draw_arc(Vector2(0, -12), 20.0, 0, TAU, 6, Color(0.4, 0.9, 1.0, 0.8), 2.5)

			"sun_altar":
				if is_a:
					draw_circle(Vector2(0, -16), 12.0, Color(1.0, 0.75, 0.1, 0.9))
					draw_arc(Vector2(0, -16), 20.0, 0, TAU, 18, Color(1.0, 0.9, 0.3), 2.5)
				else:
					for i in range(8):
						var ra = anim_time * 1.5 + i * (TAU / 8.0)
						draw_line(Vector2(0, -16), Vector2(0, -16) + Vector2(cos(ra) * 26.0, sin(ra) * 26.0), Color(1.0, 0.85, 0.4, 0.6), 1.8)

			"frost_nova":
				if is_a:
					draw_arc(Vector2(0, -6), 28.0, 0, TAU, 24, Color(0.3, 0.85, 1.0, 0.8), 3.0)
					draw_circle(Vector2(0, -6), 9.0, Color(0.7, 0.95, 1.0))
				else:
					for i in range(6):
						var sa = anim_time * 4.0 + i * (TAU / 6.0)
						draw_circle(Vector2(0, -6) + Vector2(cos(sa) * 22.0, sin(sa) * 12.0), 3.5, Color(0.85, 0.95, 1.0))

			"barricade", "gold_shrine":
				if is_a:
					draw_rect(Rect2(-16, -14, 32, 28), Color(0.85, 0.7, 0.2, 0.6))
					draw_arc(Vector2(0, 0), 22.0, 0, TAU, 16, Color(1.0, 0.85, 0.3), 2.0)
				else:
					draw_circle(Vector2(0, 0), 18.0, Color(0.2, 0.8, 0.4, 0.6))
					draw_arc(Vector2(0, 0), 25.0, 0, TAU, 20, Color(0.3, 1.0, 0.6), 2.0)

			_:
				draw_circle(Vector2(-14, -8), 4.0, theme_col)
				draw_circle(Vector2(14, -8), 4.0, theme_col)

func _draw_level_emblem() -> void:
	var badge_y = -35.0
	if tower_type in ["watchtower", "time_tower"]:
		badge_y = -44.0
	var pos = Vector2(0, badge_y)

	match current_level:
		1:
			draw_circle(pos, 6.0, Color(0.16, 0.12, 0.08, 0.92))
			draw_arc(pos, 6.0, 0, TAU, 16, Color(0.75, 0.48, 0.22), 1.8)
			draw_line(pos + Vector2(0, -3), pos + Vector2(0, 3), Color(0.95, 0.8, 0.55), 1.8)
		2:
			draw_circle(pos, 7.0, Color(0.12, 0.16, 0.22, 0.92))
			draw_arc(pos, 7.0, 0, TAU, 16, Color(0.75, 0.82, 0.92), 2.0)
			draw_line(pos + Vector2(-2, -3.5), pos + Vector2(-2, 3.5), Color(0.9, 0.95, 1.0), 1.8)
			draw_line(pos + Vector2(2, -3.5), pos + Vector2(2, 3.5), Color(0.9, 0.95, 1.0), 1.8)
		3:
			draw_circle(pos, 8.0, Color(0.22, 0.17, 0.05, 0.95))
			draw_arc(pos, 8.0, 0, TAU, 20, Color(1.0, 0.84, 0.0), 2.2)
			draw_line(pos + Vector2(-3, -4), pos + Vector2(-3, 4), Color(1.0, 0.95, 0.6), 1.6)
			draw_line(pos + Vector2(0, -4), pos + Vector2(0, 4), Color(1.0, 0.95, 0.6), 1.6)
			draw_line(pos + Vector2(3, -4), pos + Vector2(3, 4), Color(1.0, 0.95, 0.6), 1.6)
		4:
			draw_circle(pos, 9.5, Color(0.08, 0.15, 0.28, 0.95))
			draw_arc(pos, 9.5, 0, TAU, 24, Color(0.4, 0.85, 1.0), 2.4)
			draw_line(pos + Vector2(-4, -4.5), pos + Vector2(-4, 4.5), Color(0.85, 0.95, 1.0), 1.8)
			draw_line(pos + Vector2(-1, -4.5), pos + Vector2(2, 4.5), Color(0.85, 0.95, 1.0), 1.8)
			draw_line(pos + Vector2(2, 4.5), pos + Vector2(5, -4.5), Color(0.85, 0.95, 1.0), 1.8)
		_:
			var is_a = evolution_chosen == "evolution_a"
			var crown_col = Color(1.0, 0.85, 0.2) if is_a else Color(1.0, 0.55, 0.15)
			var gem_col = Color(0.25, 0.95, 0.45) if is_a else Color(0.95, 0.25, 0.25)
			var badge_r = 12.0 + sin(anim_time * 4.0) * 1.5
			draw_circle(pos, badge_r, Color(0.15, 0.08, 0.02, 0.95))
			draw_arc(pos, badge_r, 0, TAU, 24, crown_col, 2.5)
			var crown_pts = PackedVector2Array([
				pos + Vector2(-7, 3),
				pos + Vector2(-7, -4),
				pos + Vector2(-3.5, -1),
				pos + Vector2(0, -6),
				pos + Vector2(3.5, -1),
				pos + Vector2(7, -4),
				pos + Vector2(7, 3)
			])
			draw_colored_polygon(crown_pts, crown_col)
			draw_circle(pos + Vector2(0, 0), 2.2, gem_col)
			var b_col = Color(1.0, 1.0, 1.0)
			if is_a:
				draw_line(pos + Vector2(-2, 7), pos + Vector2(0, 4), b_col, 1.2)
				draw_line(pos + Vector2(2, 7), pos + Vector2(0, 4), b_col, 1.2)
				draw_line(pos + Vector2(-1, 6), pos + Vector2(1, 6), b_col, 1.2)
			else:
				draw_line(pos + Vector2(-2, 4), pos + Vector2(-2, 7), b_col, 1.2)
				draw_line(pos + Vector2(-2, 4), pos + Vector2(1, 4), b_col, 1.2)
				draw_line(pos + Vector2(-2, 5.5), pos + Vector2(1, 5.5), b_col, 1.2)
				draw_line(pos + Vector2(-2, 7), pos + Vector2(1, 7), b_col, 1.2)


