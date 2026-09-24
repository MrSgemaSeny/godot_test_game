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
		if is_inside_tree():
			var enemies = get_tree().get_nodes_in_group("enemies")
			for enemy in enemies:
				if is_instance_valid(enemy) and not enemy.get("is_dead"):
					if global_position.distance_to(enemy.global_position) <= radius:
						enemy.take_damage(damage, "physical")
		exploded.emit(global_position, damage, radius)
		queue_free()
	elif object_type == "chest":
		# Сбор сундука с золотом
		if is_inside_tree():
			var gm = get_tree().get_first_node_in_group("game_manager") as GameManager
			if gm:
				gm.add_gold(gold_reward)
		queue_free()

func _draw() -> void:
	# Мягкая эллиптическая тень на земле
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.55))
	draw_circle(Vector2(2, 22), 16.0, Color(0.0, 0.0, 0.0, 0.32))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 1.0))
	
	if object_type == "barrel":
		# 2.5D Пороховая бочка с дубовыми клепками и стальными обручами
		var wood_dark = Color(0.38, 0.22, 0.10)
		var wood_mid = Color(0.58, 0.35, 0.18)
		var wood_light = Color(0.72, 0.46, 0.24)
		var iron_dark = Color(0.22, 0.24, 0.28)
		var iron_light = Color(0.48, 0.52, 0.58)
		
		# Корпус бочки (выпуклый многоугольник со скруглением)
		var barrel_poly = PackedVector2Array([
			Vector2(-11, -14), Vector2(11, -14),
			Vector2(15, -4), Vector2(16, 4), Vector2(13, 12),
			Vector2(10, 15), Vector2(-10, 15),
			Vector2(-13, 12), Vector2(-16, 4), Vector2(-15, -4)
		])
		draw_colored_polygon(barrel_poly, wood_mid)
		
		# Вертикальные волокна и стыки дубовых клепок
		draw_line(Vector2(-6, -14), Vector2(-8, 14), wood_dark, 1.5)
		draw_line(Vector2(0, -14), Vector2(0, 15), wood_light, 1.5)
		draw_line(Vector2(6, -14), Vector2(8, 14), wood_dark, 1.5)
		
		# Железные кованые обручи (верхний, средний, нижний) с металлическим бликом
		var hoops_y = [-9.0, 1.0, 10.0]
		for hy in hoops_y:
			var hw = 13.5 if hy < 0 else (16.0 if hy < 5 else 13.0)
			draw_line(Vector2(-hw, hy), Vector2(hw, hy), iron_dark, 3.5)
			draw_line(Vector2(-hw + 2, hy - 0.5), Vector2(hw - 2, hy - 0.5), iron_light, 1.2)
			# Заклепки на обруче
			draw_circle(Vector2(-hw * 0.5, hy), 1.3, Color(0.75, 0.78, 0.82))
			draw_circle(Vector2(hw * 0.5, hy), 1.3, Color(0.75, 0.78, 0.82))
		
		# Верхняя крышка бочки (овал в перспективе)
		draw_set_transform(Vector2(0, -14), 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2.ZERO, 11.0, wood_dark)
		draw_circle(Vector2(0, -1), 9.5, wood_mid)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 1.0))
		
		# Тлеющий фитиль с искрами
		draw_line(Vector2(0, -14), Vector2(4, -20), Color(0.85, 0.82, 0.72), 2.0)
		draw_circle(Vector2(4, -20), 3.0, Color(1.0, 0.4, 0.1, 0.9))
		draw_circle(Vector2(4, -20), 1.5, Color(1.0, 0.95, 0.4))
		
		# Знак черепа / опасности
		draw_circle(Vector2(0, 1), 3.5, Color(0.95, 0.95, 0.92, 0.9))
		draw_line(Vector2(-1.5, 4.5), Vector2(1.5, 4.5), Color(0.95, 0.95, 0.92, 0.9), 1.5)
		draw_circle(Vector2(-1.2, 0.5), 1.0, Color(0.2, 0.1, 0.1))
		draw_circle(Vector2(1.2, 0.5), 1.0, Color(0.2, 0.1, 0.1))

	elif object_type == "chest":
		# 2.5D Кованый сундук с сокровищами
		var wood_base = Color(0.42, 0.24, 0.12)
		var wood_lit = Color(0.62, 0.38, 0.20)
		var gold_trim = Color(0.92, 0.75, 0.22)
		var gold_shine = Color(1.0, 0.92, 0.55)
		var iron_rim = Color(0.24, 0.25, 0.28)
		
		# Нижний корпус сундука
		draw_rect(Rect2(-14, -2, 28, 16), wood_base)
		draw_rect(Rect2(-12, 0, 24, 12), wood_lit)
		
		# Округлая крышка сундука в перспективе
		var lid_poly = PackedVector2Array([
			Vector2(-15, -2), Vector2(-13, -12),
			Vector2(0, -15), Vector2(13, -12), Vector2(15, -2)
		])
		draw_colored_polygon(lid_poly, wood_lit.lightened(0.1))
		
		# Кованые уголки и окантовка
		draw_line(Vector2(-14, -2), Vector2(-14, 14), iron_rim, 2.5)
		draw_line(Vector2(14, -2), Vector2(14, 14), iron_rim, 2.5)
		draw_line(Vector2(-14, 14), Vector2(14, 14), iron_rim, 2.5)
		draw_polyline(lid_poly, iron_rim, 2.5)
		
		# Золотой замок с замочной скважиной
		draw_rect(Rect2(-4, -4, 8, 8), gold_trim)
		draw_circle(Vector2(0, -4), 3.0, gold_shine)
		draw_circle(Vector2(0, 0), 1.2, Color(0.12, 0.08, 0.04))
		draw_line(Vector2(0, 0), Vector2(0, 2.5), Color(0.12, 0.08, 0.04), 1.2)
		
		# Сияние выбивающегося золота из-под крышки
		draw_line(Vector2(-11, -2), Vector2(-5, -2), Color(1.0, 0.85, 0.3, 0.85), 2.0)
		draw_line(Vector2(5, -2), Vector2(11, -2), Color(1.0, 0.85, 0.3, 0.85), 2.0)
		
	# Ореол подсветки при наведении
	if is_hovered:
		draw_arc(Vector2(0, 0), 22.0, 0, TAU, 28, Color(1.0, 0.88, 0.25, 0.9), 2.5)
		draw_arc(Vector2(0, 0), 25.0, 0, TAU, 24, Color(1.0, 0.88, 0.25, 0.35), 1.5)
