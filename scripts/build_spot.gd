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

func _input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
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

func sell_tower() -> int:
	if not has_tower():
		return 0
		
	var game_manager = _get_game_manager()
	var sell_val = current_tower.get_sell_value()
	
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
	# Тень под постаментом
	draw_circle(Vector2(2, 6), spot_radius + 3.0, Color(0.0, 0.0, 0.0, 0.35))
	
	# Каменная кладка башенки-постамента (конусообразное основание)
	var base_col = Color(0.42, 0.44, 0.46)
	var light_col = Color(0.62, 0.64, 0.68)
	var dark_col = Color(0.28, 0.30, 0.32)
	
	# Нижнее основание
	draw_circle(Vector2(0, 4), spot_radius, dark_col)
	draw_circle(Vector2(0, 2), spot_radius - 2.0, base_col)
	
	# Текстура отдельных каменных блоков
	for i in range(6):
		var ang = i * (PI / 3.0) + 0.2
		var p1 = Vector2(cos(ang), sin(ang)) * (spot_radius * 0.4) + Vector2(0, 2)
		var p2 = Vector2(cos(ang), sin(ang)) * (spot_radius * 0.95) + Vector2(0, 2)
		draw_line(p1, p2, Color(0.22, 0.24, 0.26, 0.7), 1.5)
	
	# Верхняя площадка с темным углублением
	draw_circle(Vector2(0, -2), spot_radius * 0.78, light_col)
	draw_circle(Vector2(0, -2), spot_radius * 0.65, Color(0.18, 0.16, 0.14)) # Темное жерло
	draw_arc(Vector2(0, -2), spot_radius * 0.65, 0, TAU, 24, Color(0.1, 0.08, 0.08), 2.0)
	
	# Каменные зубцы (Battlements) по ободу
	for i in range(8):
		var ang = i * (TAU / 8.0)
		var tooth_pos = Vector2(cos(ang), sin(ang)) * (spot_radius * 0.75) + Vector2(0, -2)
		draw_circle(tooth_pos, 3.2, light_col)
		draw_arc(tooth_pos, 3.2, 0, TAU, 8, dark_col, 1.0)
		
	if not has_tower():
		# Золотистый огонек в центре площадки
		var glow_alpha = 0.6 + sin(pulse_time) * 0.3 if (is_hovered or is_selected) else 0.35
		draw_circle(Vector2(0, -2), 5.0, Color(1.0, 0.85, 0.3, glow_alpha))
		
	# Пульсирующий ореол при выборе
	if is_selected:
		var pulse_rad = spot_radius + 4.0 + sin(pulse_time) * 2.0
		draw_arc(Vector2(0, 0), pulse_rad, 0, TAU, 32, Color(1.0, 0.85, 0.2, 0.9), 3.0)
		draw_arc(Vector2(0, 0), pulse_rad + 3.0, 0, TAU, 32, Color(1.0, 0.85, 0.2, 0.4), 1.5)
	elif is_hovered:
		draw_arc(Vector2(0, 0), spot_radius + 3.0, 0, TAU, 32, Color(0.4, 0.85, 1.0, 0.8), 2.0)
