class_name BuildSpot
extends Area2D

signal clicked(spot: BuildSpot)
signal hovered(spot: BuildSpot, state: bool)

var current_tower: TowerBase = null
var is_hovered: bool = false
var is_selected: bool = false
var spot_radius: float = 26.0

var pulse_time: float = 0.0
var tower_script = preload("res://scripts/tower_base.gd")

func _ready() -> void:
	input_pickable = true
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	if not has_node("CollisionShape2D"):
		var shape = CollisionShape2D.new()
		var circle_shape = CircleShape2D.new()
		circle_shape.radius = spot_radius
		shape.shape = circle_shape
		add_child(shape)
		
	queue_redraw()

func _process(delta: float) -> void:
	if is_selected or is_hovered:
		pulse_time += delta * 4.0
		queue_redraw()

func _on_mouse_entered() -> void:
	is_hovered = true
	hovered.emit(self, true)
	queue_redraw()

func _on_mouse_exited() -> void:
	is_hovered = false
	hovered.emit(self, false)
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var local_pos = to_local(get_global_mouse_position())
		if local_pos.length() <= spot_radius + 4.0:
			clicked.emit(self)
			get_viewport().set_input_as_handled()

func set_selected(val: bool) -> void:
	is_selected = val
	if is_instance_valid(current_tower) and not current_tower.is_queued_for_deletion():
		current_tower.set_selected(val)
	queue_redraw()

func has_tower() -> bool:
	return is_instance_valid(current_tower) and not current_tower.is_queued_for_deletion()

func can_upgrade_tower() -> bool:
	return has_tower() and current_tower.can_upgrade()

func _get_game_manager() -> GameManager:
	var gm = get_tree().get_first_node_in_group("game_manager") as GameManager
	if not gm:
		gm = get_tree().root.get_node_or_null("Game/GameManager")
	return gm

func get_tower_cost(tower_type: String) -> int:
	var game_manager = _get_game_manager()
	if not game_manager or not game_manager.tower_data.has(tower_type):
		return 100
		
	var base_cost = game_manager.tower_data[tower_type].get("cost", 100)
	var tech = get_tree().get_first_node_in_group("tech_tree_manager") as TechTreeManager
	var mult = 1.0
	if tech:
		mult -= tech.get_cost_discount()
	if game_manager.discount_active_wave:
		mult -= 0.25
	return max(10, int(base_cost * mult))

func build_tower(tower_type: String) -> bool:
	if has_tower():
		return false
		
	var game_manager = _get_game_manager()
	if not game_manager:
		return false
		
	var cost = get_tower_cost(tower_type)
	if not game_manager.spend_gold(cost):
		return false
		
	var tower = Node2D.new()
	tower.set_script(tower_script)
	tower.tower_type = tower_type
	tower.total_spent = cost
	add_child(tower)
	current_tower = tower
	if is_selected:
		current_tower.set_selected(true)
		
	queue_redraw()
	return true

func upgrade_tower() -> bool:
	if not has_tower():
		return false
		
	var game_manager = _get_game_manager()
	if not game_manager or not current_tower.can_upgrade():
		return false
		
	var base_cost = current_tower.upgrade_cost
	var tech = get_tree().get_first_node_in_group("tech_tree_manager") as TechTreeManager
	var mult = 1.0
	if tech:
		mult -= tech.get_cost_discount()
	if game_manager.discount_active_wave:
		mult -= 0.25
	var cost = max(10, int(base_cost * mult))
	
	if not game_manager.spend_gold(cost):
		return false
		
	current_tower.upgrade()
	queue_redraw()
	return true

func get_sell_value() -> int:
	if not has_tower() or not is_instance_valid(current_tower):
		return 0
	if current_tower.has_method("get_sell_value"):
		return current_tower.get_sell_value()
	return 50

func sell_tower() -> int:
	if not has_tower():
		return 0
		
	var game_manager = _get_game_manager()
	var sell_val = get_sell_value()
	
	if game_manager:
		game_manager.add_gold(sell_val)
		
	current_tower.queue_free()
	current_tower = null
	queue_redraw()
	return sell_val


# === Evolution System (Stage 3) ===
func can_evolve_tower() -> bool:
	return has_tower() and current_tower.can_evolve()

func evolve_tower(branch: String) -> bool:
	if not has_tower() or not current_tower.can_evolve():
		return false
	current_tower.apply_evolution(branch)
	queue_redraw()
	return true

func _draw() -> void:
	var r = spot_radius
	
	# 1. Мягкая глубинная тень под основанием в перспективе
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.55))
	draw_circle(Vector2(3, 24), r * 1.25, Color(0.0, 0.0, 0.0, 0.38))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 1.0))
	
	# Цветовая палитра монументального гранита
	var stone_shadow = Color(0.20, 0.22, 0.25)
	var stone_mid = Color(0.38, 0.40, 0.44)
	var stone_light = Color(0.55, 0.58, 0.62)
	var stone_highlight = Color(0.70, 0.74, 0.78)
	var mortar_line = Color(0.15, 0.16, 0.18, 0.85)
	
	# 2. Вертикальная фасадная грань каменного постамента (эффект высоты 2.5D)
	var wall_height = 10.0
	var oct_pts_top: Array[Vector2] = []
	var oct_pts_bot: Array[Vector2] = []
	for i in range(8):
		var ang = i * (TAU / 8.0) + PI / 8.0
		var pt = Vector2(cos(ang) * r, sin(ang) * (r * 0.72) - 2.0)
		oct_pts_top.append(pt)
		oct_pts_bot.append(pt + Vector2(0, wall_height))
		
	# Отрисовка передних вертикальных граней (фасад)
	for i in range(4):
		var idx1 = (i + 1) % 8
		var idx2 = (i + 2) % 8
		var quad = PackedVector2Array([
			oct_pts_top[idx1], oct_pts_top[idx2],
			oct_pts_bot[idx2], oct_pts_bot[idx1]
		])
		var shade = stone_shadow.lerp(stone_mid, float(i) / 3.0)
		draw_colored_polygon(quad, shade)
		draw_polyline(quad, mortar_line, 1.2)
		
	# 3. Верхняя горизонтальная плита (восьмигранник в ракурсе)
	var top_poly = PackedVector2Array(oct_pts_top)
	draw_colored_polygon(top_poly, stone_mid)
	draw_polyline(top_poly, stone_highlight, 2.0)
	
	# Внутренний бордюр и плиты мощения
	var inner_pts: Array[Vector2] = []
	for i in range(8):
		var ang = i * (TAU / 8.0) + PI / 8.0
		inner_pts.append(Vector2(cos(ang) * (r * 0.8), sin(ang) * (r * 0.58) - 2.0))
	draw_colored_polygon(PackedVector2Array(inner_pts), stone_shadow.lerp(stone_mid, 0.5))
	draw_polyline(PackedVector2Array(inner_pts), mortar_line, 1.5)
	
	# Радиальные швы каменной кладки
	for i in range(8):
		var p_out = oct_pts_top[i]
		var p_in = inner_pts[i]
		draw_line(p_in, p_out, mortar_line, 1.2)
		
	# 4. Древний рунический круг в центре площадки
	var rune_col = Color(0.95, 0.80, 0.35)
	var glow_alpha = 0.75 + sin(pulse_time * 2.5) * 0.25 if (is_hovered or is_selected) else (0.28 if not has_tower() else 0.0)
	
	if glow_alpha > 0.0:
		var center_y = -2.0
		var rune_r = r * 0.52
		draw_set_transform(Vector2(0, center_y), 0.0, Vector2(1.0, 0.7))
		
		# Магический контур
		draw_arc(Vector2.ZERO, rune_r, 0, TAU, 32, Color(rune_col.r, rune_col.g, rune_col.b, glow_alpha * 0.8), 1.5)
		draw_arc(Vector2.ZERO, rune_r * 0.7, 0, TAU, 24, Color(rune_col.r, rune_col.g, rune_col.b, glow_alpha * 0.5), 1.0)
		
		# Вписанная руническая звезда
		for i in range(4):
			var a = i * (TAU / 4.0) + (pulse_time * 0.4 if is_hovered else 0.0)
			var p1 = Vector2(cos(a), sin(a)) * rune_r
			var p2 = Vector2(cos(a + PI), sin(a + PI)) * rune_r
			draw_line(p1, p2, Color(rune_col.r, rune_col.g, rune_col.b, glow_alpha * 0.6), 1.2)
			
		# Светящееся ядро
		draw_circle(Vector2.ZERO, 3.5, Color(1.0, 0.95, 0.7, glow_alpha))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 1.0))
		
	# 5. Ореол интерактивного выделения
	if is_selected:
		var pulse_rad = r + 5.0 + sin(pulse_time * 3.0) * 2.0
		draw_set_transform(Vector2(0, -2), 0.0, Vector2(1.0, 0.72))
		draw_arc(Vector2.ZERO, pulse_rad, 0, TAU, 36, Color(1.0, 0.88, 0.2, 0.9), 2.5)
		draw_arc(Vector2.ZERO, pulse_rad + 4.0, 0, TAU, 32, Color(1.0, 0.88, 0.2, 0.4), 1.5)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 1.0))
	elif is_hovered:
		draw_set_transform(Vector2(0, -2), 0.0, Vector2(1.0, 0.72))
		draw_arc(Vector2.ZERO, r + 4.0, 0, TAU, 32, Color(0.4, 0.88, 1.0, 0.85), 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 1.0))
