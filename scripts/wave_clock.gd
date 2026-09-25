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
	custom_minimum_size = Vector2(88, 88)
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
	
	# 1. Мягкая глубинная тень компаса
	draw_circle(center + Vector2(2, 5), radius + 2.0, Color(0, 0, 0, 0.45))
	
	# 2. Массивный резной каменный обод с бронзовой фаской
	var stone_dark = Color(0.24, 0.22, 0.18)
	var stone_mid = Color(0.44, 0.40, 0.34)
	var stone_light = Color(0.68, 0.62, 0.52)
	var bronze = Color(0.85, 0.72, 0.30)
	var rune_gold = Color(1.0, 0.88, 0.42)
	
	draw_circle(center, radius, stone_dark)
	draw_circle(center, radius - 2.5, stone_mid)
	draw_circle(center, radius - 5.0, stone_light)
	draw_arc(center, radius, 0, TAU, 36, stone_dark, 2.0)
	draw_arc(center, radius - 5.0, 0, TAU, 36, bronze, 1.8)
	
	# 4 золоченые заклепки по сторонам света
	for i in range(4):
		var ca = i * (TAU / 4.0)
		var cp = center + Vector2(cos(ca), sin(ca)) * (radius - 2.8)
		draw_circle(cp, 2.5, bronze)
		draw_circle(cp, 1.2, rune_gold)
	
	# 3. Разноцветные секторы циферблата (как на фото: зеленый, лазурный, синий, фиолетовый)
	var inner_rad = radius - 7.5
	var segments = 16
	for i in range(segments):
		var a1 = -PI / 2.0 + (i / float(segments)) * TAU
		var a2 = -PI / 2.0 + ((i + 1) / float(segments)) * TAU
		
		var sec_col: Color
		if is_boss_wave:
			sec_col = Color(0.92, 0.22, 0.20) if (i % 2 == 0) else Color(1.0, 0.45, 0.15)
		else:
			if i < 5:
				sec_col = Color(0.25, 0.72, 0.28) if (i % 2 == 0) else Color(0.35, 0.85, 0.38)
			elif i < 10:
				sec_col = Color(0.20, 0.68, 0.90) if (i % 2 == 0) else Color(0.32, 0.82, 0.98)
			else:
				sec_col = Color(0.48, 0.28, 0.80) if (i % 2 == 0) else Color(0.62, 0.38, 0.92)
		
		var p1 = center
		var p2 = center + Vector2(cos(a1), sin(a1)) * inner_rad
		var p3 = center + Vector2(cos(a2), sin(a2)) * inner_rad
		draw_polygon(PackedVector2Array([p1, p2, p3]), PackedColorArray([sec_col, sec_col, sec_col]))
		draw_line(p1, p2, Color(0.12, 0.18, 0.14, 0.4), 1.0)
	
	# 4. Светлый небесно-пергаментный центральный диск циферблата
	var face_rad = inner_rad * 0.68
	draw_circle(center, face_rad, Color(0.85, 0.92, 0.96))
	draw_arc(center, face_rad, 0, TAU, 32, Color(0.35, 0.48, 0.58), 1.5)
	
	# Радиальные часовые насечки компаса
	for i in range(12):
		var ta = i * (TAU / 12.0)
		var tick_len = 4.0 if (i % 3 == 0) else 2.2
		var p_out = center + Vector2(cos(ta), sin(ta)) * face_rad
		var p_in = center + Vector2(cos(ta), sin(ta)) * (face_rad - tick_len)
		draw_line(p_in, p_out, Color(0.25, 0.35, 0.45), 1.2)

	# 5. Медальоны с портретами монстров по краям циферблата (в точности как на фото!)
	# Левый медальон: Зеленый гоблин
	var gob_pos = center + Vector2(-radius * 0.72, -radius * 0.65)
	draw_circle(gob_pos, 9.5, stone_dark)
	draw_circle(gob_pos, 8.0, bronze)
	draw_circle(gob_pos, 6.5, Color(0.32, 0.75, 0.25)) # Зеленая голова
	draw_circle(gob_pos + Vector2(-2, -1), 1.5, Color(1, 1, 1)) # Глаз
	draw_circle(gob_pos + Vector2(2, -1), 1.5, Color(1, 1, 1))
	draw_circle(gob_pos + Vector2(-2, -1), 0.8, Color(0, 0, 0))
	draw_circle(gob_pos + Vector2(2, -1), 0.8, Color(0, 0, 0))
	# Ушки гоблина
	draw_line(gob_pos + Vector2(-5, -3), gob_pos + Vector2(-8, -6), Color(0.32, 0.75, 0.25), 2.0)
	draw_line(gob_pos + Vector2(5, -3), gob_pos + Vector2(8, -6), Color(0.32, 0.75, 0.25), 2.0)

	# Правый медальон: Фиолетовый летающий демон/нетопырь
	var bat_pos = center + Vector2(radius * 0.72, -radius * 0.65)
	draw_circle(bat_pos, 9.5, stone_dark)
	draw_circle(bat_pos, 8.0, bronze)
	draw_circle(bat_pos, 6.5, Color(0.65, 0.25, 0.85)) # Фиолетовая голова
	draw_circle(bat_pos + Vector2(-2, -1), 1.5, Color(1.0, 0.9, 0.2)) # Желтые глаза
	draw_circle(bat_pos + Vector2(2, -1), 1.5, Color(1.0, 0.9, 0.2))
	# Рожки
	draw_line(bat_pos + Vector2(-3, -4), bat_pos + Vector2(-5, -8), Color(0.3, 0.1, 0.4), 2.0)
	draw_line(bat_pos + Vector2(3, -4), bat_pos + Vector2(5, -8), Color(0.3, 0.1, 0.4), 2.0)

	# 6. Массивная стрелка компаса (синий и золотой лазурит)
	var target_a = -PI / 2.0 + hand_angle
	var hand_dir = Vector2(cos(target_a), sin(target_a))
	var hand_norm = hand_dir.orthogonal()
	
	var h_tip = center + hand_dir * (face_rad * 0.88)
	var h_tail = center - hand_dir * (face_rad * 0.25)
	var h_left = center + hand_norm * 4.2
	var h_right = center - hand_norm * 4.2
	
	# Синяя половина стрелки
	draw_colored_polygon(PackedVector2Array([center, h_left, h_tip]), Color(0.15, 0.42, 0.75))
	# Золотая половина стрелки
	draw_colored_polygon(PackedVector2Array([center, h_right, h_tip]), Color(0.92, 0.75, 0.25))
	# Хвостовой противовес
	draw_colored_polygon(PackedVector2Array([center, h_left, h_tail, h_right]), Color(0.24, 0.22, 0.20))
	draw_polyline(PackedVector2Array([h_tail, h_left, h_tip, h_right, h_tail]), Color(0.12, 0.10, 0.08), 1.2)
	
	# Центральная латунная заклепка с сапфиром
	draw_circle(center, 5.0, bronze)
	draw_circle(center, 3.0, Color(0.2, 0.7, 1.0))
	draw_circle(center, 1.2, Color(1, 1, 1))

	# 7. Надпись "БОСС!" или секундомер волны
	var default_font = ThemeDB.fallback_font
	if default_font:
		if is_boss_wave:
			var pulse_val = sin(pulse_timer) * 2.0
			var b_box = Rect2(center.x - 32, center.y + radius - 6 + pulse_val, 64, 18)
			draw_rect(b_box, Color(0.2, 0.05, 0.05, 0.95))
			draw_rect(b_box, Color(0.85, 0.2, 0.2), false, 1.5)
			draw_string(default_font, Vector2(center.x, center.y + radius + 8 + pulse_val), "БОСС!", HORIZONTAL_ALIGNMENT_CENTER, -1, 13, Color(1.0, 0.9, 0.2))
		elif is_active:
			draw_string(default_font, Vector2(center.x, center.y + 18), "%d" % int(ceil(time_left)), HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(0.12, 0.20, 0.28))
