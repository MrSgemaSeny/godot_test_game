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

var hair_color: Color = Color(0.95, 0.75, 0.2)
var dress_color: Color = Color(0.95, 0.35, 0.55)

func _ready() -> void:
	home_position = global_position
	wander_target = home_position
	queue_redraw()

func _process(delta: float) -> void:
	bounce_anim += delta * 6.0
	
	match current_state:
		State.IN_VILLAGE:
			_process_village_wander(delta)
		State.BEING_CARRIED:
			if is_instance_valid(carrier_monster) and not carrier_monster.get("is_dead"):
				global_position = carrier_monster.global_position + Vector2(0, -22)
			else:
				# Монстр убит! Девочка спасена и бежит домой!
				_start_running_home()
		State.RUNNING_HOME:
			_process_running_home(delta)
			
	queue_redraw()

func _process_village_wander(delta: float) -> void:
	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_timer = randf_range(2.0, 4.5)
		var offset = Vector2(randf_range(-30, 30), randf_range(-30, 30))
		wander_target = home_position + offset
		
	var dir = (wander_target - global_position)
	if dir.length() > 2.0:
		global_position += dir.normalized() * 25.0 * delta

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
	var bounce = sin(bounce_anim) * 2.0 if current_state != State.IN_VILLAGE else 0.0
	
	# Платьице (треугольник)
	var dress_poly = PackedVector2Array([
		Vector2(0, -6 + bounce),
		Vector2(8, 8 + bounce),
		Vector2(-8, 8 + bounce)
	])
	draw_polygon(dress_poly, PackedColorArray([dress_color, dress_color, dress_color]))
	
	# Голова
	draw_circle(Vector2(0, -12 + bounce), 7.0, Color(1.0, 0.88, 0.78))
	
	# Прическа и хвостики
	draw_circle(Vector2(-7, -13 + bounce), 3.5, hair_color)
	draw_circle(Vector2(7, -13 + bounce), 3.5, hair_color)
	draw_arc(Vector2(0, -14 + bounce), 7.0, PI, TAU, 12, hair_color, 3.0)
	
	# Глазки
	if current_state == State.BEING_CARRIED:
		# Испуганные глазки (крестики или слезинки)
		draw_line(Vector2(-3, -13 + bounce), Vector2(-1, -11 + bounce), Color(0.2, 0.2, 0.3), 1.5)
		draw_line(Vector2(1, -13 + bounce), Vector2(3, -11 + bounce), Color(0.2, 0.2, 0.3), 1.5)
		# Значок крика "!" над головой
		draw_string(ThemeDB.get_fallback_font(), Vector2(-3, -24 + bounce), "!", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color(1.0, 0.2, 0.2))
	elif current_state == State.RUNNING_HOME:
		# Радостные глазки
		draw_arc(Vector2(-3, -12 + bounce), 2.0, PI, TAU, 6, Color(0.2, 0.2, 0.3), 1.5)
		draw_arc(Vector2(3, -12 + bounce), 2.0, PI, TAU, 6, Color(0.2, 0.2, 0.3), 1.5)
		# Сердечко над головой
		draw_circle(Vector2(-2, -24 + bounce), 2.5, Color(1.0, 0.2, 0.5))
		draw_circle(Vector2(2, -24 + bounce), 2.5, Color(1.0, 0.2, 0.5))
	else:
		# Обычные милые глазки
		draw_circle(Vector2(-2.5, -12), 1.2, Color(0.2, 0.2, 0.3))
		draw_circle(Vector2(2.5, -12), 1.2, Color(0.2, 0.2, 0.3))
