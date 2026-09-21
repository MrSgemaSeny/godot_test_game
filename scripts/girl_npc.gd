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
	var dir = (home_position - global_position)
	if dir.length() <= 8.0:
		current_state = State.IN_VILLAGE
		carrier_monster = null
		rescued.emit(self)
	else:
		global_position += dir.normalized() * run_speed * delta

func get_kidnapped_by(monster: Node2D) -> void:
	current_state = State.BEING_CARRIED
	carrier_monster = monster
	kidnapped.emit(self)

func _start_running_home() -> void:
	current_state = State.RUNNING_HOME
	carrier_monster = null

func _draw() -> void:
	var bounce = sin(bounce_anim) * 2.5 if current_state != State.IN_VILLAGE else sin(bounce_anim * 0.5) * 1.0
	
	# Мягкая тень под ногами
	draw_circle(Vector2(0, 10), 8.0, Color(0.0, 0.0, 0.0, 0.25))
	
	# Пышное сказочное платьице
	var dress_poly = PackedVector2Array([
		Vector2(0, -5 + bounce),
		Vector2(10, 9 + bounce),
		Vector2(-10, 9 + bounce)
	])
	draw_polygon(dress_poly, PackedColorArray([dress_color, dress_color, dress_color]))
	# Белый передничек
	draw_polygon(
		PackedVector2Array([Vector2(0, -3 + bounce), Vector2(5, 9 + bounce), Vector2(-5, 9 + bounce)]),
		PackedColorArray([Color(1.0, 1.0, 1.0, 0.9), Color(1.0, 1.0, 1.0, 0.9), Color(1.0, 1.0, 1.0, 0.9)])
	)
	
	# Голова
	draw_circle(Vector2(0, -12 + bounce), 8.0, Color(1.0, 0.9, 0.82))
	# Румянец на щечках
	draw_circle(Vector2(-4.5, -9 + bounce), 2.0, Color(1.0, 0.5, 0.6, 0.6))
	draw_circle(Vector2(4.5, -9 + bounce), 2.0, Color(1.0, 0.5, 0.6, 0.6))
	
	# Волосы и пышные хвостики с бантиками
	draw_circle(Vector2(-8, -13 + bounce), 4.5, hair_color)
	draw_circle(Vector2(8, -13 + bounce), 4.5, hair_color)
	draw_circle(Vector2(-8, -17 + bounce), 2.0, Color(1.0, 0.3, 0.5)) # Бантик слева
	draw_circle(Vector2(8, -17 + bounce), 2.0, Color(1.0, 0.3, 0.5)) # Бантик справа
	draw_arc(Vector2(0, -14 + bounce), 8.0, PI, TAU, 14, hair_color, 3.5)
	
	if current_state == State.BEING_CARRIED:
		# Испуганные глазки
		draw_line(Vector2(-3.5, -13 + bounce), Vector2(-1.5, -11 + bounce), Color(0.2, 0.2, 0.3), 2.0)
		draw_line(Vector2(1.5, -11 + bounce), Vector2(3.5, -13 + bounce), Color(0.2, 0.2, 0.3), 2.0)
		# Значок паники
		draw_circle(Vector2(0, -26 + bounce), 6.0, Color(1.0, 0.2, 0.2, 0.85))
		draw_line(Vector2(0, -29 + bounce), Vector2(0, -25 + bounce), Color(1.0, 1.0, 1.0), 2.0)
		draw_circle(Vector2(0, -23 + bounce), 1.0, Color(1.0, 1.0, 1.0))
	elif current_state == State.RUNNING_HOME:
		# Счастливые глазки-дуги
		draw_arc(Vector2(-3.5, -12 + bounce), 2.2, PI, TAU, 6, Color(0.2, 0.2, 0.3), 2.0)
		draw_arc(Vector2(3.5, -12 + bounce), 2.2, PI, TAU, 6, Color(0.2, 0.2, 0.3), 2.0)
		# Сердечко над головой
		draw_circle(Vector2(-2.5, -25 + bounce), 3.0, Color(1.0, 0.2, 0.45))
		draw_circle(Vector2(2.5, -25 + bounce), 3.0, Color(1.0, 0.2, 0.45))
		draw_polygon(
			PackedVector2Array([Vector2(-5.5, -24 + bounce), Vector2(5.5, -24 + bounce), Vector2(0, -18 + bounce)]),
			PackedColorArray([Color(1.0, 0.2, 0.45), Color(1.0, 0.2, 0.45), Color(1.0, 0.2, 0.45)])
		)
	else:
		# Милые круглые глазки с бликами
		draw_circle(Vector2(-3.5, -12 + bounce), 1.8, Color(0.2, 0.2, 0.3))
		draw_circle(Vector2(3.5, -12 + bounce), 1.8, Color(0.2, 0.2, 0.3))
		draw_circle(Vector2(-3.0, -12.5 + bounce), 0.7, Color(1.0, 1.0, 1.0))
		draw_circle(Vector2(4.0, -12.5 + bounce), 0.7, Color(1.0, 1.0, 1.0))
