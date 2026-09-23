class_name MapBiomeRenderer
extends Node2D

## Handles the visual rendering of the map background and weather overlays
## depending on the selected biome.

var current_biome: String = "valley"
var animation_time: float = 0.0

func _ready() -> void:
	add_to_group("biome_renderer")

func set_biome(biome: String) -> void:
	current_biome = biome
	queue_redraw()

func _process(delta: float) -> void:
	animation_time += delta
	queue_redraw()

func _draw() -> void:
	match current_biome:
		"valley":
			_draw_valley_background()
		"swamp":
			_draw_swamp_background()
		"frost_peak":
			_draw_frost_background()
		"caves":
			_draw_caves_background()
		"city", "besieged_citadel":
			_draw_city_background()
		_:
			_draw_valley_background()

func _draw_valley_background() -> void:
	# Base lush green
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.30, 0.62, 0.23))
	
	# Rolling hills silhouette
	var hill_col1 = Color(0.36, 0.70, 0.28)
	var hill_col2 = Color(0.25, 0.55, 0.20)
	draw_circle(Vector2(160, 140), 190, hill_col1)
	draw_circle(Vector2(520, 130), 220, hill_col1)
	draw_circle(Vector2(920, 150), 230, hill_col1)
	draw_circle(Vector2(140, 680), 200, hill_col2)
	draw_circle(Vector2(550, 680), 230, hill_col2)
	draw_circle(Vector2(1050, 680), 220, hill_col2)
	
	# Small ponds
	var pond_water = Color(0.35, 0.72, 0.90)
	var sand_col = Color(0.92, 0.84, 0.58)
	draw_circle(Vector2(250, 440), 65, sand_col)
	draw_circle(Vector2(250, 440), 50, pond_water)
	draw_circle(Vector2(1150, 310), 80, sand_col)
	draw_circle(Vector2(1160, 290), 55, pond_water)
	
	# Wind effect (animated grass sweeping)
	for i in range(20):
		var wx = fposmod(i * 123.0 + animation_time * 80.0, 1280.0)
		var wy = fposmod(i * 45.0, 720.0)
		draw_line(Vector2(wx, wy), Vector2(wx + 20, wy - 10), Color(0.5, 0.8, 0.3, 0.5), 2.0)

func _draw_swamp_background() -> void:
	# Murky dark green
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.16, 0.24, 0.18))
	draw_circle(Vector2(200, 150), 220, Color(0.13, 0.20, 0.15))
	draw_circle(Vector2(600, 180), 250, Color(0.13, 0.20, 0.15))
	draw_circle(Vector2(1000, 200), 240, Color(0.13, 0.20, 0.15))
	
	# Toxic slime pools
	var slime_col = Color(0.22, 0.65, 0.30, 0.75)
	draw_circle(Vector2(550, 240), 70, slime_col)
	draw_circle(Vector2(950, 210), 85, slime_col)
	draw_circle(Vector2(300, 500), 100, slime_col)
	
	# Bubbles animating in slime pools
	for i in range(15):
		var bx = 550 + sin(animation_time * 2.0 + i) * 50
		var by = 240 + cos(animation_time * 1.5 + i) * 50
		var size = 3.0 + sin(animation_time * 3.0 + i) * 2.0
		draw_circle(Vector2(bx, by), max(1.0, size), Color(0.4, 0.9, 0.5, 0.8))
		
	# Fog patches
	for i in range(5):
		var fx = fposmod(animation_time * 20.0 + i * 300, 1500) - 100
		var fy = 360 + sin(animation_time + i) * 100
		draw_circle(Vector2(fx, fy), 150, Color(0.3, 0.4, 0.3, 0.2))

func _draw_frost_background() -> void:
	# Ice white/blue
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.82, 0.88, 0.94))
	draw_circle(Vector2(200, 150), 210, Color(0.88, 0.93, 0.98))
	draw_circle(Vector2(600, 170), 230, Color(0.88, 0.93, 0.98))
	draw_circle(Vector2(1000, 190), 220, Color(0.88, 0.93, 0.98))
	
	# Frozen turquoise glacier pools
	var ice_col = Color(0.45, 0.80, 0.92, 0.85)
	draw_circle(Vector2(450, 240), 85, ice_col)
	draw_circle(Vector2(850, 510), 90, ice_col)
	
	# Snowflakes ambient particles
	for i in range(40):
		var sx = fposmod(i * 41.0 + sin(animation_time * 0.5 + i) * 50.0, 1280.0)
		var sy = fposmod(i * 37.0 + animation_time * 40.0, 720.0)
		draw_circle(Vector2(sx, sy), 2.0, Color(1, 1, 1, 0.8))
		
	# Large ice crystals jutting from ground
	for i in range(6):
		var cx = 150 + i * 200
		var cy = 100 + (i % 2) * 400
		draw_polygon(PackedVector2Array([
			Vector2(cx, cy),
			Vector2(cx - 20, cy + 50),
			Vector2(cx + 20, cy + 60)
		]), PackedColorArray([Color.CYAN, Color.BLUE, Color.DEEP_SKY_BLUE]))

func _draw_caves_background() -> void:
	# Dark basalt
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.09, 0.09, 0.13))
	draw_circle(Vector2(250, 160), 200, Color(0.12, 0.12, 0.18))
	draw_circle(Vector2(650, 180), 230, Color(0.12, 0.12, 0.18))
	draw_circle(Vector2(1000, 180), 220, Color(0.12, 0.12, 0.18))
	
	# Lava chasms
	var lava_col = Color(0.8, 0.2, 0.0)
	var lava_glow = Color(1.0, 0.4, 0.0, 0.5 + sin(animation_time * 2.0) * 0.2)
	draw_rect(Rect2(100, 500, 300, 40), lava_col)
	draw_rect(Rect2(90, 490, 320, 60), lava_glow)
	draw_rect(Rect2(800, 100, 40, 200), lava_col)
	draw_rect(Rect2(790, 90, 60, 220), lava_glow)
	
	# Glowing ambient spores
	for i in range(30):
		var px = fposmod(i * 77.0 + sin(animation_time + i) * 30.0, 1280.0)
		var py = fposmod(i * 53.0 - animation_time * 20.0, 720.0)
		var c = Color(0.4, 0.1, 0.8, 0.6) if i % 2 == 0 else Color(0.1, 0.8, 0.8, 0.6)
		draw_circle(Vector2(px, py), 3.0, c)

func _draw_city_background() -> void:
	# Dark cobblestone foundation
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.22, 0.23, 0.26))
	
	# Render large paving stones
	for x in range(0, 1280, 80):
		for y in range(0, 720, 40):
			var offset = 40 if (y / 40) % 2 == 0 else 0
			draw_rect(Rect2(x - offset, y, 76, 36), Color(0.27, 0.28, 0.32))
			
	# Broken wall segments
	draw_rect(Rect2(200, 150, 150, 40), Color(0.15, 0.16, 0.18))
	draw_rect(Rect2(800, 550, 200, 40), Color(0.15, 0.16, 0.18))
	
	# Torch flames
	for pos in [Vector2(100, 100), Vector2(1100, 100), Vector2(100, 600), Vector2(1100, 600)]:
		var flame_h = 20 + sin(animation_time * 15.0 + pos.x) * 5
		draw_circle(pos, 8.0, Color.ORANGE)
		draw_polygon(PackedVector2Array([
			pos + Vector2(-8, 0),
			pos + Vector2(8, 0),
			pos + Vector2(0, -flame_h)
		]), PackedColorArray([Color.ORANGE, Color.ORANGE, Color.YELLOW]))
		draw_circle(pos, 25.0, Color(1.0, 0.5, 0.0, 0.2 + sin(animation_time * 10.0 + pos.x) * 0.05))

func draw_weather_overlay(weather_type: String, intensity: float) -> void:
	match weather_type:
		"rain":
			for i in range(int(70 * intensity)):
				var rx = fposmod(i * 47.0 + animation_time * 500.0, 1280.0)
				var ry = fposmod(i * 31.0 + animation_time * 800.0, 720.0)
				draw_line(Vector2(rx, ry), Vector2(rx - 6, ry + 16), Color(0.7, 0.85, 1.0, 0.45), 1.5)
		"snow":
			for i in range(int(80 * intensity)):
				var sx = fposmod(i * 39.0 + sin(animation_time + i) * 30.0, 1280.0)
				var sy = fposmod(i * 29.0 + animation_time * 90.0, 720.0)
				draw_circle(Vector2(sx, sy), 2.5, Color(1.0, 1.0, 1.0, 0.75))
		"fog":
			draw_rect(Rect2(0, 0, 1280, 720), Color(0.85, 0.88, 0.92, 0.22 * intensity + sin(animation_time * 1.5) * 0.05))
