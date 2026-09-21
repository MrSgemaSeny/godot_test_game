class_name FloatingText
extends Node2D

var text: String = ""
var text_color: Color = Color(1, 1, 1)
var font_size: int = 14
var duration: float = 0.8
var elapsed: float = 0.0
var velocity: Vector2 = Vector2(0, -45)

func setup(p_text: String, p_color: Color = Color(1, 1, 1), p_size: int = 14, p_duration: float = 0.8) -> void:
	text = p_text
	text_color = p_color
	font_size = p_size
	duration = p_duration
	velocity = Vector2(randf_range(-12, 12), randf_range(-40, -55))

func _process(delta: float) -> void:
	elapsed += delta
	position += velocity * delta
	velocity.y += 20.0 * delta # Slight gravity deceleration
	
	if elapsed >= duration:
		queue_free()
	else:
		queue_redraw()

func _draw() -> void:
	var alpha = clamp(1.0 - (elapsed / duration), 0.0, 1.0)
	var draw_col = Color(text_color.r, text_color.g, text_color.b, alpha)
	var shadow_col = Color(0, 0, 0, alpha * 0.85)
	
	var default_font = ThemeDB.fallback_font
	if default_font:
		# Тень текста для максимальной читаемости на любом фоне
		draw_string(default_font, Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, shadow_col)
		draw_string(default_font, Vector2(-1, 1), text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, shadow_col)
		draw_string(default_font, Vector2(0, 0), text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, draw_col)
