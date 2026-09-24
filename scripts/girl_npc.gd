class_name GirlNPC
extends Node2D

signal rescued(girl: GirlNPC)
signal kidnapped(girl: GirlNPC)
signal escaped_with_monster(girl: GirlNPC)

enum State {
	IN_VILLAGE,
	BEING_CARRIED,
	RUNNING_HOME
}

var current_state: State = State.IN_VILLAGE
var home_position: Vector2 = Vector2.ZERO
var carrier_monster: Node2D = null
var run_speed: float = 140.0
var wander_timer: float = 0.0
var wander_target: Vector2 = Vector2.ZERO
var bounce_anim: float = 0.0

var hair_color: Color = Color(0.98, 0.78, 0.25)
var dress_color: Color = Color(0.95, 0.4, 0.6)

func _ready() -> void:
	home_position = global_position
	wander_target = home_position
	# Разные цвета платьев и волос у разных девочек
	var rng = randi() % 4
	if rng == 1:
		dress_color = Color(0.35, 0.75, 0.95)
		hair_color = Color(0.85, 0.45, 0.2)
	elif rng == 2:
		dress_color = Color(0.95, 0.8, 0.3)
		hair_color = Color(0.45, 0.25, 0.15)
	elif rng == 3:
		dress_color = Color(0.65, 0.45, 0.95)
		hair_color = Color(0.95, 0.85, 0.4)
	queue_redraw()

func _process(delta: float) -> void:
	bounce_anim += delta * 7.0
	
	match current_state:
		State.IN_VILLAGE:
			_process_village_wander(delta)
		State.BEING_CARRIED:
			if is_instance_valid(carrier_monster) and not carrier_monster.get("is_dead"):
				global_position = carrier_monster.global_position + Vector2(0, -22)
			else:
				_start_running_home()
		State.RUNNING_HOME:
			_process_running_home(delta)
			
	queue_redraw()

func _process_village_wander(delta: float) -> void:
	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_timer = randf_range(2.0, 4.5)
		var offset = Vector2(randf_range(-35, 35), randf_range(-35, 35))
		wander_target = home_position + offset
		
	var dir = (wander_target - global_position)
	if dir.length() > 2.0:
		global_position += dir.normalized() * 22.0 * delta

func _process_running_home(delta: float) -> void:
	var cur_pos = global_position if is_inside_tree() else position
	var dir = (home_position - cur_pos)
	if dir.length() <= 8.0:
		current_state = State.IN_VILLAGE
		carrier_monster = null
		rescued.emit(self)
	else:
		var step = dir.normalized() * run_speed * delta
		if is_inside_tree():
			global_position += step
		else:
			position += step

func get_kidnapped_by(monster: Node2D) -> void:
	current_state = State.BEING_CARRIED
	carrier_monster = monster
	kidnapped.emit(self)

func _start_running_home() -> void:
	current_state = State.RUNNING_HOME
	carrier_monster = null

func _draw() -> void:
	var bounce = sin(bounce_anim) * 2.5 if current_state != State.IN_VILLAGE else sin(bounce_anim * 0.5) * 1.0
	
	# Мягкая эллиптическая тень под ножками
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2(0, 24), 9.0, Color(0.0, 0.0, 0.0, 0.28))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 1.0))
	
	# Кожаные туфельки
	var leg_swing = sin(bounce_anim * 1.5) * 2.0 if current_state == State.RUNNING_HOME else 0.0
	draw_circle(Vector2(-3.5 + leg_swing, 11), 2.5, Color(0.28, 0.16, 0.08))
	draw_circle(Vector2(3.5 - leg_swing, 11), 2.5, Color(0.28, 0.16, 0.08))
	
	# Пышная юбка с оборками и складками ткани
	var skirt_pts = PackedVector2Array([
		Vector2(-4, -1 + bounce),
		Vector2(4, -1 + bounce),
		Vector2(11, 10 + bounce),
		Vector2(6, 11 + bounce),
		Vector2(0, 10 + bounce),
		Vector2(-6, 11 + bounce),
		Vector2(-11, 10 + bounce)
	])
	draw_colored_polygon(skirt_pts, dress_color)
	draw_polyline(skirt_pts, dress_color.darkened(0.25), 1.5)
	
	# Белый кружевной передничек
	var apron_pts = PackedVector2Array([
		Vector2(-2.5, 0 + bounce), Vector2(2.5, 0 + bounce),
		Vector2(5, 9 + bounce), Vector2(-5, 9 + bounce)
	])
	draw_colored_polygon(apron_pts, Color(0.96, 0.96, 0.98, 0.92))
	
	# Корсаж со шнуровкой
	draw_rect(Rect2(-4, -6 + bounce, 8, 6), dress_color.darkened(0.35))
	draw_line(Vector2(-2, -5 + bounce), Vector2(2, -3 + bounce), Color(0.95, 0.85, 0.4), 1.2)
	draw_line(Vector2(-2, -3 + bounce), Vector2(2, -5 + bounce), Color(0.95, 0.85, 0.4), 1.2)
	
	# Рукава-фонарики
	draw_circle(Vector2(-5.5, -4 + bounce), 2.8, Color(0.96, 0.96, 0.98))
	draw_circle(Vector2(5.5, -4 + bounce), 2.8, Color(0.96, 0.96, 0.98))
	
	# Голова и личико
	var face_col = Color(1.0, 0.92, 0.84)
	draw_circle(Vector2(0, -12 + bounce), 7.5, face_col)
	# Мягкий девичий румянец
	draw_circle(Vector2(-4.2, -10 + bounce), 2.2, Color(1.0, 0.45, 0.55, 0.5))
	draw_circle(Vector2(4.2, -10 + bounce), 2.2, Color(1.0, 0.45, 0.55, 0.5))
	
	# Прическа: пышные косы/хвостики с ленточками
	var hair_dark = hair_color.darkened(0.2)
	# Задняя масса волос
	draw_circle(Vector2(-8, -13 + bounce), 4.8, hair_color)
	draw_circle(Vector2(8, -13 + bounce), 4.8, hair_color)
	draw_circle(Vector2(-9, -8 + bounce), 3.5, hair_dark)
	draw_circle(Vector2(9, -8 + bounce), 3.5, hair_dark)
	
	# Шелковые бантики
	draw_circle(Vector2(-8, -16 + bounce), 2.5, Color(1.0, 0.25, 0.45))
	draw_circle(Vector2(8, -16 + bounce), 2.5, Color(1.0, 0.25, 0.45))
	draw_circle(Vector2(-8, -16 + bounce), 1.2, Color(1.0, 0.85, 0.9))
	draw_circle(Vector2(8, -16 + bounce), 1.2, Color(1.0, 0.85, 0.9))
	
	# Челка с прядями
	draw_arc(Vector2(0, -13.5 + bounce), 7.5, PI * 0.9, TAU * 1.05, 16, hair_color, 4.0)
	draw_line(Vector2(-3, -15 + bounce), Vector2(-1, -12 + bounce), hair_dark, 1.5)
	draw_line(Vector2(2, -15 + bounce), Vector2(4, -12 + bounce), hair_dark, 1.5)
	
	if current_state == State.BEING_CARRIED:
		# Испуганные аниме-глазки
		draw_line(Vector2(-4, -12 + bounce), Vector2(-1.5, -10.5 + bounce), Color(0.2, 0.18, 0.28), 2.2)
		draw_line(Vector2(1.5, -10.5 + bounce), Vector2(4, -12 + bounce), Color(0.2, 0.18, 0.28), 2.2)
		# Значок паники / восклицание
		draw_circle(Vector2(0, -25 + bounce), 5.5, Color(1.0, 0.2, 0.2, 0.9))
		draw_line(Vector2(0, -28 + bounce), Vector2(0, -24 + bounce), Color(1.0, 1.0, 1.0), 2.0)
		draw_circle(Vector2(0, -22 + bounce), 1.0, Color(1.0, 1.0, 1.0))
	elif current_state == State.RUNNING_HOME:
		# Счастливые глазки-дуги
		draw_arc(Vector2(-3.2, -11 + bounce), 2.4, PI, TAU, 8, Color(0.2, 0.18, 0.28), 2.2)
		draw_arc(Vector2(3.2, -11 + bounce), 2.4, PI, TAU, 8, Color(0.2, 0.18, 0.28), 2.2)
		# Сердечко радости над головой
		draw_circle(Vector2(-2.5, -25 + bounce), 3.2, Color(1.0, 0.18, 0.45))
		draw_circle(Vector2(2.5, -25 + bounce), 3.2, Color(1.0, 0.18, 0.45))
		draw_colored_polygon(
			PackedVector2Array([Vector2(-5.5, -24 + bounce), Vector2(5.5, -24 + bounce), Vector2(0, -18 + bounce)]),
			Color(1.0, 0.18, 0.45)
		)
	else:
		# Выразительные глаза с бликами
		draw_circle(Vector2(-3.2, -11 + bounce), 2.0, Color(0.18, 0.22, 0.35))
		draw_circle(Vector2(3.2, -11 + bounce), 2.0, Color(0.18, 0.22, 0.35))
		draw_circle(Vector2(-2.6, -11.6 + bounce), 0.8, Color(1.0, 1.0, 1.0))
		draw_circle(Vector2(3.8, -11.6 + bounce), 0.8, Color(1.0, 1.0, 1.0))
