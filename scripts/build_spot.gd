class_name BuildSpot
extends Area2D

signal clicked(spot: BuildSpot)

var current_tower: TowerBase = null
var is_hovered: bool = false
var is_selected: bool = false
var spot_size: Vector2 = Vector2(40, 40)

var tower_script = preload("res://scripts/tower_base.gd")

func _ready() -> void:
	input_pickable = true
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	if not has_node("CollisionShape2D"):
		var shape = CollisionShape2D.new()
		var rect_shape = RectangleShape2D.new()
		rect_shape.size = spot_size
		shape.shape = rect_shape
		add_child(shape)
		
	queue_redraw()

func _on_mouse_entered() -> void:
	is_hovered = true
	queue_redraw()

func _on_mouse_exited() -> void:
	is_hovered = false
	queue_redraw()

func _input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		clicked.emit(self)
		get_viewport().set_input_as_handled()

func set_selected(val: bool) -> void:
	is_selected = val
	if is_instance_valid(current_tower):
		current_tower.set_selected(val)
	queue_redraw()

func has_tower() -> bool:
	return is_instance_valid(current_tower)

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

func _draw() -> void:
	var rect = Rect2(-spot_size / 2.0, spot_size)
	
	if not has_tower():
		draw_rect(rect, Color(0.22, 0.2, 0.22, 0.7))
		draw_rect(rect, Color(0.4, 0.38, 0.35, 0.8), false, 1.5)
		
		var icon_col = Color(0.8, 0.75, 0.6, 0.5 if not is_hovered else 0.9)
		draw_line(Vector2(-6, 0), Vector2(6, 0), icon_col, 2.0)
		draw_line(Vector2(0, -6), Vector2(0, 6), icon_col, 2.0)
		
	if is_selected:
		draw_rect(rect.grow(2.0), Color(1.0, 0.85, 0.2, 0.9), false, 2.0)
	elif is_hovered:
		draw_rect(rect.grow(1.0), Color(0.5, 0.8, 1.0, 0.6), false, 1.5)
