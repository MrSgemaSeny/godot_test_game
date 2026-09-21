class_name InteractiveMapObj
extends Area2D

signal exploded(pos: Vector2, damage: float, radius: float)

@export var object_type: String = "barrel" # "barrel", "chest"
@export var damage: float = 250.0
@export var radius: float = 120.0
@export var gold_reward: int = 50

var is_activated: bool = false
var is_hovered: bool = false

func _ready() -> void:
	input_pickable = true
	mouse_entered.connect(func(): is_hovered = true; queue_redraw())
	mouse_exited.connect(func(): is_hovered = false; queue_redraw())
	
	if not has_node("CollisionShape2D"):
		var shape = CollisionShape2D.new()
		var circle = CircleShape2D.new()
		circle.radius = 20.0
		shape.shape = circle
		add_child(shape)
		
	queue_redraw()

func _input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		activate()
		get_viewport().set_input_as_handled()

func activate() -> void:
	if is_activated:
		return
	is_activated = true
	
	if object_type == "barrel":
		# Взрыв бочки с порохом!
		var enemies = get_tree().get_nodes_in_group("enemies")
		for enemy in enemies:
			if is_instance_valid(enemy) and not enemy.get("is_dead"):
				if global_position.distance_to(enemy.global_position) <= radius:
					enemy.take_damage(damage, "physical")
		exploded.emit(global_position, damage, radius)
		queue_free()
	elif object_type == "chest":
		# Сбор сундука с золотом
		var gm = get_tree().get_first_node_in_group("game_manager") as GameManager
		if gm:
			gm.add_gold(gold_reward)
		queue_free()

func _draw() -> void:
	if object_type == "barrel":
		# Бочка с порохом
		draw_circle(Vector2.ZERO, 15.0, Color(0.6, 0.35, 0.15))
		draw_arc(Vector2.ZERO, 15.0, 0, TAU, 16, Color(0.3, 0.15, 0.05), 2.0)
		draw_line(Vector2(-15, -5), Vector2(15, -5), Color(0.2, 0.2, 0.2), 2.0)
		draw_line(Vector2(-15, 5), Vector2(15, 5), Color(0.2, 0.2, 0.2), 2.0)
		# Череп / Огонек на бочке
		draw_circle(Vector2.ZERO, 4.0, Color(1.0, 0.3, 0.1))
	elif object_type == "chest":
		# Сундук с сокровищами
		draw_rect(Rect2(-14, -10, 28, 20), Color(0.7, 0.5, 0.2))
		draw_rect(Rect2(-12, -8, 24, 16), Color(0.9, 0.75, 0.3))
		draw_circle(Vector2(0, 0), 3.0, Color(1.0, 1.0, 1.0))
		
	if is_hovered:
		draw_arc(Vector2.ZERO, 20.0, 0, TAU, 16, Color(1.0, 0.9, 0.2, 0.8), 2.0)
