class_name WaveClock
extends Control

signal clicked()

var time_left: float = 0.0
var total_time: float = 30.0
var is_active: bool = false
var is_boss_wave: bool = false
var next_monster_icon: String = "👾"
var hand_angle: float = 0.0

var pulse_timer: float = 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(76, 76)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		clicked.emit()

func set_countdown(cur: float, total: float = 30.0, is_boss: bool = false) -> void:
	time_left = cur
	total_time = max(0.1, total)
	is_active = cur > 0.0
	is_boss_wave = is_boss
	queue_redraw()

func _process(delta: float) -> void:
	pulse_timer += delta * 4.0
	if is_active and total_time > 0.0:
		var progress = 1.0 - clamp(time_left / total_time, 0.0, 1.0)
		hand_angle = progress * TAU
	else:
		hand_angle += delta * 1.5
	queue_redraw()

func _draw() -> void:
	var center = size / 2.0
	var radius = min(size.x, size.y) / 2.0 - 4.0
	
	# 1. Тень часов
	draw_circle(center + Vector2(2, 4), radius + 2.0, Color(0, 0, 0, 0.4))
	
	# 2. Внешнее каменное/деревянное кольцо
	draw_circle(center, radius, Color(0.48, 0.45, 0.38))
	draw_circle(center, radius - 3.0, Color(0.68, 0.62, 0.52))
	draw_arc(center, radius, 0, TAU, 32, Color(0.25, 0.22, 0.18), 2.5)
	
	# 3. Разноцветные секторы циферблата (как в оригинале «Башенок»: зеленый и синий)
	var inner_rad = radius - 6.0
	var segments = 16
	for i in range(segments):
		var a1 = -PI / 2.0 + (i / float(segments)) * TAU
		var a2 = -PI / 2.0 + ((i + 1) / float(segments)) * TAU
		var sector_col = Color(0.28, 0.68, 0.32) if (i % 2 == 0) else Color(0.22, 0.52, 0.72)
		if is_boss_wave and (i % 2 == 0):
			sector_col = Color(0.85, 0.25, 0.25)
		
		var p1 = center
		var p2 = center + Vector2(cos(a1), sin(a1)) * inner_rad
		var p3 = center + Vector2(cos(a2), sin(a2)) * inner_rad
		draw_polygon(PackedVector2Array([p1, p2, p3]), PackedColorArray([sector_col, sector_col, sector_col]))
		draw_line(p1, p2, Color(0.15, 0.3, 0.2, 0.5), 1.0)
	
	# Внутренний светлый диск циферблата
	draw_circle(center, inner_rad * 0.65, Color(0.78, 0.88, 0.92))
	draw_arc(center, inner_rad * 0.65, 0, TAU, 24, Color(0.3, 0.45, 0.5), 1.5)
	
	# 4. Стрелка часов
	var target_a = -PI / 2.0 + hand_angle
	var hand_p1 = center - Vector2(cos(target_a), sin(target_a)) * (inner_rad * 0.2)
	var hand_p2 = center + Vector2(cos(target_a), sin(target_a)) * (inner_rad * 0.85)
	var hand_side1 = center + Vector2(cos(target_a + PI/2), sin(target_a + PI/2)) * 3.0
	var hand_side2 = center + Vector2(cos(target_a - PI/2), sin(target_a - PI/2)) * 3.0
	
	# Стрелка часов
	draw_polygon(
		PackedVector2Array([hand_p1, hand_side1, hand_p2, hand_side2]),
		PackedColorArray([Color(0.12, 0.2, 0.3), Color(0.12, 0.2, 0.3), Color(0.12, 0.2, 0.3), Color(0.12, 0.2, 0.3)])
	)
	draw_circle(center, 4.0, Color(0.85, 0.75, 0.2))
	
	# 5. Надпись "БОСС!" или таймер
	var default_font = ThemeDB.fallback_font
	if default_font:
		if is_boss_wave:
			var pulse_scale = 1.0 + sin(pulse_timer) * 0.15
			draw_string(default_font, center + Vector2(0, radius + 14), "БОСС!", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color(1.0, 0.2, 0.2))
		elif is_active:
			draw_string(default_font, center + Vector2(0, 4), "%d" % int(ceil(time_left)), HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color(0.1, 0.2, 0.3))
