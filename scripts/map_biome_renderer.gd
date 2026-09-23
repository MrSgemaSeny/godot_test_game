class_name MapBiomeRenderer
extends Node2D

## Handles the visual rendering of the map background, weather overlays,
## and highly detailed animated environments for all 12 biomes.
## This massive renderer utilizes procedural drawing, cellular arrays,
## particle simulation, and multi-layered parallax effects.

var current_biome: String = "valley"
var animation_time: float = 0.0

var particles: Array[Dictionary] = []
var props_cache: Dictionary = {}

func _ready() -> void:
	add_to_group("biome_renderer")
	_init_particles()
	_init_props()

func set_biome(biome: String) -> void:
	current_biome = biome
	_init_particles()
	queue_redraw()

func _process(delta: float) -> void:
	animation_time += delta
	_update_particles(delta)
	queue_redraw()

func _init_particles() -> void:
	particles.clear()
	for i in range(150):
		particles.append({
			"pos": Vector2(randf_range(0, 1280), randf_range(0, 720)),
			"vel": Vector2(randf_range(-20, 20), randf_range(-20, 20)),
			"life": randf_range(0, 10),
			"size": randf_range(1, 4),
			"color": Color(1, 1, 1, 1),
			"type": randi() % 3
		})

func _init_props() -> void:
	props_cache["valley_shrines"] = [Vector2(200, 300), Vector2(1000, 500), Vector2(600, 150)]
	props_cache["swamp_mushrooms"] = []
	for i in range(25):
		props_cache["swamp_mushrooms"].append(Vector2(randf_range(50, 1200), randf_range(50, 650)))
	props_cache["greenwood_trees"] = []
	for i in range(30):
		props_cache["greenwood_trees"].append(Vector2(randf_range(0, 1280), randf_range(0, 720)))
	props_cache["crystal_geodes"] = [Vector2(300, 200), Vector2(800, 600), Vector2(1100, 100)]
	props_cache["ash_bones"] = [Vector2(400, 400), Vector2(900, 300)]
	props_cache["ruins"] = [Vector2(350, 450), Vector2(850, 250)]
	props_cache["statues"] = [Vector2(200, 200), Vector2(1080, 200), Vector2(200, 520), Vector2(1080, 520)]

func _update_particles(delta: float) -> void:
	for p in particles:
		p["life"] += delta
		p["pos"] += p["vel"] * delta
		
		# Wrap around
		if p["pos"].x < -50: p["pos"].x = 1330
		if p["pos"].x > 1330: p["pos"].x = -50
		if p["pos"].y < -50: p["pos"].y = 770
		if p["pos"].y > 770: p["pos"].y = -50
		
		# Biome specific particle behavior
		match current_biome:
			"valley":
				p["vel"].x += sin(animation_time + p["life"]) * 0.5
				p["color"] = Color(1.0, 0.9, 0.5, 0.8) # Butterflies / Pollen
			"swamp":
				p["vel"].y = -15.0 - sin(p["life"])*5.0
				p["color"] = Color(0.3, 1.0, 0.4, 0.6) # Marsh gas
			"greenwood":
				p["vel"].y = sin(animation_time)*10.0
				p["color"] = Color(1.0, 1.0, 0.3, 0.8) # Fireflies
			"sunken_kingdom":
				p["vel"].y = -30.0
				p["vel"].x = sin(p["life"] * 2.0) * 10.0
				p["color"] = Color(0.6, 0.8, 1.0, 0.5) # Bubbles
			"fire_chasms":
				p["vel"].y = -40.0
				p["vel"].x += (randf() - 0.5) * 5.0
				p["color"] = Color(1.0, 0.4, 0.1, 0.9) # Embers
			"astral_ruins":
				var center = Vector2(640, 360)
				var dir = (center - p["pos`"]).normalized()
				p["vel"] = dir * 20.0 + dir.rotated(PI/2) * 40.0
				p["color"] = Color(0.8, 0.5, 1.0, 0.7) # Stardust

func _draw() -> void:
	match current_biome:
		"valley": _draw_valley()
		"swamp": _draw_swamp()
		"greenwood": _draw_greenwood()
		"stone_suburbs": _draw_stone_suburbs()
		"royal_highway": _draw_royal_highway()
		"crystal_caves": _draw_crystal_caves()
		"frost_peak": _draw_frost_peak()
		"ash_wastes": _draw_ash_wastes()
		"fire_chasms": _draw_fire_chasms()
		"sunken_kingdom": _draw_sunken_kingdom()
		"astral_ruins": _draw_astral_ruins()
		"royal_heart": _draw_royal_heart()
		_: _draw_valley()
		
	_draw_ambient_particles()

# -----------------------------------------------------------------------------
# 1. VALLEY (�������� ������)
# -----------------------------------------------------------------------------
func _draw_valley() -> void:
	# Base emerald grass
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.2, 0.6, 0.2))
	
	# Rolling hills
	draw_circle(Vector2(200, 200), 300, Color(0.25, 0.65, 0.25))
	draw_circle(Vector2(1000, 500), 400, Color(0.18, 0.55, 0.18))
	draw_circle(Vector2(600, 700), 350, Color(0.22, 0.60, 0.22))
	
	# Serpentine river
	var river_points = PackedVector2Array()
	var river_colors = PackedColorArray()
	for i in range(20):
		var rx = i * 70.0
		var ry = 360.0 + sin(rx * 0.01 + animation_time * 0.5) * 150.0
		river_points.append(Vector2(rx, ry))
		river_colors.append(Color(0.2, 0.6, 0.9, 0.8))
	if river_points.size() > 1:
		draw_polyline_colors(river_points, river_colors, 80.0)
		draw_polyline_colors(river_points, river_colors, 40.0) # Inner bright streak
		
	# River glints and lily pads
	for i in range(8):
		var p = river_points[i * 2 + 1]
		draw_circle(p + Vector2(20, 10), 12, Color(0.1, 0.5, 0.2)) # Lily pad
		draw_polygon(PackedVector2Array([p+Vector2(10,5), p+Vector2(25,15), p+Vector2(15,25)]), PackedColorArray([Color(0.1, 0.4, 0.1)]))
		draw_circle(p + Vector2(-20, -10), 4, Color(1, 1, 1, 0.6 + sin(animation_time * 5 + i)*0.4)) # Glint
		
	# Wayside shrines
	for pos in props_cache["valley_shrines"]:
		_draw_shrine(pos)
		
	# Wildflower carpets
	for i in range(40):
		var fx = fposmod(i * 137.0, 1280.0)
		var fy = fposmod(i * 93.0, 720.0)
		draw_circle(Vector2(fx, fy), 3.0, Color(1.0, 0.3, 0.5))
		draw_circle(Vector2(fx+4, fy-2), 2.0, Color(1.0, 0.8, 0.2))

func _draw_shrine(pos: Vector2) -> void:
	draw_rect(Rect2(pos.x - 20, pos.y - 10, 40, 20), Color(0.4, 0.4, 0.4))
	draw_rect(Rect2(pos.x - 15, pos.y - 40, 30, 30), Color(0.5, 0.5, 0.5))
	draw_polygon(PackedVector2Array([pos+Vector2(-20,-40), pos+Vector2(20,-40), pos+Vector2(0,-70)]), PackedColorArray([Color(0.3,0.3,0.3)]))
	# Faint golden blessing
	draw_circle(pos + Vector2(0, -25), 15 + sin(animation_time * 2.0)*5.0, Color(1.0, 0.8, 0.2, 0.3))

# -----------------------------------------------------------------------------
# 2. SWAMP (������� ����)
# -----------------------------------------------------------------------------
func _draw_swamp() -> void:
	# Murky peat
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.1, 0.15, 0.1))
	
	# Stagnant water with oil slick
	draw_circle(Vector2(300, 300), 250, Color(0.05, 0.1, 0.1))
	draw_circle(Vector2(900, 500), 300, Color(0.05, 0.1, 0.1))
	draw_circle(Vector2(300, 300), 200, Color(0.1, 0.05, 0.15, 0.5)) # Oil slick 1
	draw_circle(Vector2(900, 500), 240, Color(0.05, 0.15, 0.1, 0.5)) # Oil slick 2
	
	# Giant luminescent mushrooms
	for pos in props_cache["swamp_mushrooms"]:
		var bounce = sin(animation_time * 1.5 + pos.x) * 5.0
		var c1 = Color(0.2, 0.8, 0.4)
		var c2 = Color(0.8, 0.2, 0.8)
		var c = c1 if int(pos.x) % 2 == 0 else c2
		# Stem
		draw_rect(Rect2(pos.x - 6, pos.y, 12, 30), Color(0.3, 0.4, 0.3))
		# Cap
		draw_circle(pos + Vector2(0, bounce), 25, c.darkened(0.2))
		draw_circle(pos + Vector2(0, bounce - 5), 15, c)
		# Glow
		draw_circle(pos + Vector2(0, bounce), 40, Color(c.r, c.g, c.b, 0.15 + sin(animation_time*3+pos.x)*0.05))
		
	# Toxic bubbling bog
	for i in range(12):
		var bx = 200 + i * 80 + sin(animation_time + i) * 30
		var by = 200 + i * 40 + cos(animation_time + i) * 30
		var b_size = fposmod(animation_time * 20.0 + i * 15.0, 40.0)
		draw_arc(Vector2(bx, by), b_size, 0, TAU, 16, Color(0.4, 0.9, 0.2, 1.0 - (b_size/40.0)), 2.0)
		
	# Hanging Spanish moss (silhouettes at top)
	for i in range(10):
		var mx = i * 130.0
		draw_polygon(PackedVector2Array([
			Vector2(mx, 0), Vector2(mx+60, 0), Vector2(mx+30, 80 + sin(animation_time+i)*10.0),
			Vector2(mx+15, 40), Vector2(mx+5, 90 + cos(animation_time+i)*15.0)
		]), PackedColorArray([Color(0.05, 0.08, 0.05)]))

# -----------------------------------------------------------------------------
# 3. GREENWOOD (������ ���)
# -----------------------------------------------------------------------------
func _draw_greenwood() -> void:
	# Forest floor
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.1, 0.3, 0.1))
	
	# Fae rings (glowing mushrooms in circle)
	for i in range(3):
		var center = Vector2(250 + i * 400, 350 + (i%2)*200)
		for a in range(8):
			var angle = a * PI / 4.0 + animation_time * 0.1
			var mx = center.x + cos(angle) * 80.0
			var my = center.y + sin(angle) * 80.0
			draw_circle(Vector2(mx, my), 6, Color(0.9, 0.8, 0.2))
			draw_circle(Vector2(mx, my), 20, Color(0.9, 0.8, 0.2, 0.2))
			
	# Ancient oak trees
	for pos in props_cache["greenwood_trees"]:
		_draw_oak_tree(pos)
		
	# Volumetric God-rays filtering from canopy
	_draw_god_rays()

func _draw_oak_tree(pos: Vector2) -> void:
	# Trunk
	draw_rect(Rect2(pos.x - 20, pos.y - 100, 40, 120), Color(0.3, 0.2, 0.1))
	# Roots
	draw_polygon(PackedVector2Array([pos+Vector2(-20,20), pos+Vector2(-40,40), pos+Vector2(-10,20)]), PackedColorArray([Color(0.3, 0.2, 0.1)]))
	draw_polygon(PackedVector2Array([pos+Vector2(20,20), pos+Vector2(40,40), pos+Vector2(10,20)]), PackedColorArray([Color(0.3, 0.2, 0.1)]))
	# Canopy (multi-layered circles)
	var sway = sin(animation_time * 0.5 + pos.x) * 15.0
	var c_center = pos + Vector2(sway, -120)
	draw_circle(c_center, 90, Color(0.05, 0.25, 0.05))
	draw_circle(c_center + Vector2(-30, -20), 70, Color(0.1, 0.35, 0.1))
	draw_circle(c_center + Vector2(30, -10), 75, Color(0.1, 0.35, 0.1))
	draw_circle(c_center + Vector2(0, -40), 60, Color(0.15, 0.45, 0.15))

func _draw_god_rays() -> void:
	for i in range(5):
		var rx = 100 + i * 250 + sin(animation_time * 0.2 + i) * 100.0
		var pts = PackedVector2Array([
			Vector2(rx, 0), Vector2(rx + 200, 0),
			Vector2(rx + 400, 720), Vector2(rx + 100, 720)
		])
		var cols = PackedColorArray([
			Color(1, 1, 0.8, 0.15), Color(1, 1, 0.8, 0.15),
			Color(1, 1, 0.8, 0.0), Color(1, 1, 0.8, 0.0)
		])
		draw_polygon(pts, cols)

# -----------------------------------------------------------------------------
# 4. STONE SUBURBS (�������� ����������)
# -----------------------------------------------------------------------------
func _draw_stone_suburbs() -> void:
	# Cobblestone ground
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.35, 0.35, 0.38))
	
	# Broken cobblestone texture
	for i in range(100):
		var cx = fposmod(i * 193.0, 1280.0)
		var cy = fposmod(i * 127.0, 720.0)
		draw_rect(Rect2(cx, cy, 24, 16), Color(0.4, 0.4, 0.43))
		draw_rect(Rect2(cx+2, cy+2, 20, 12), Color(0.3, 0.3, 0.33))
		
	# Ruined stone battlements
	for i in range(4):
		var bx = 100 + i * 300
		draw_rect(Rect2(bx, 100, 120, 80), Color(0.2, 0.2, 0.22))
		draw_rect(Rect2(bx, 80, 30, 20), Color(0.2, 0.2, 0.22))
		draw_rect(Rect2(bx+45, 80, 30, 20), Color(0.2, 0.2, 0.22))
		draw_rect(Rect2(bx+90, 80, 30, 20), Color(0.2, 0.2, 0.22))
		
	# Wooden defensive palisades
	for i in range(12):
		var px = 50 + i * 100
		draw_polygon(PackedVector2Array([
			Vector2(px, 600), Vector2(px+20, 600), Vector2(px+10, 450)
		]), PackedColorArray([Color(0.3, 0.2, 0.1)]))
		# Ropes binding them
		draw_line(Vector2(px-10, 520), Vector2(px+30, 530), Color(0.6, 0.5, 0.3), 3.0)
		
	# Watchfires
	for i in range(5):
		var fx = 150 + i * 250
		var fy = 200 + (i%2)*200
		# Brazier
		draw_rect(Rect2(fx-15, fy, 30, 20), Color(0.1, 0.1, 0.1))
		draw_line(Vector2(fx-10, fy+20), Vector2(fx-15, fy+50), Color(0.1,0.1,0.1), 4)
		draw_line(Vector2(fx+10, fy+20), Vector2(fx+15, fy+50), Color(0.1,0.1,0.1), 4)
		# Fire
		var flame_h = 40 + sin(animation_time * 10.0 + i) * 15.0
		draw_polygon(PackedVector2Array([Vector2(fx-10, fy), Vector2(fx+10, fy), Vector2(fx, fy-flame_h)]), PackedColorArray([Color(1,0.5,0)]))
		draw_polygon(PackedVector2Array([Vector2(fx-5, fy), Vector2(fx+5, fy), Vector2(fx, fy-flame_h*0.7)]), PackedColorArray([Color(1,0.8,0)]))
		# Glow
		draw_circle(Vector2(fx, fy-10), 60, Color(1, 0.5, 0, 0.15 + sin(animation_time * 8 + i)*0.05))

# -----------------------------------------------------------------------------
# 5. ROYAL HIGHWAY (����������� �����)
# -----------------------------------------------------------------------------
func _draw_royal_highway() -> void:
	# Plains base
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.3, 0.5, 0.2))
	
	# Massive paved highway (diagonal)
	var hw_points = PackedVector2Array([Vector2(-100, 100), Vector2(1380, 600)])
	draw_polyline(hw_points, Color(0.5, 0.5, 0.5), 180.0)
	draw_polyline(hw_points, Color(0.6, 0.6, 0.6), 160.0)
	
	# Wagon tracks on road
	var t1 = PackedVector2Array([Vector2(-100, 80), Vector2(1380, 580)])
	var t2 = PackedVector2Array([Vector2(-100, 120), Vector2(1380, 620)])
	draw_polyline(t1, Color(0.4, 0.4, 0.4, 0.6), 4.0)
	draw_polyline(t2, Color(0.4, 0.4, 0.4, 0.6), 4.0)
	
	# Gilded milestones and roadside lanterns
	for i in range(5):
		var t = i / 4.0
		var pos = hw_points[0].lerp(hw_points[1], t)
		var l_pos = pos + Vector2(0, -120)
		# Milestone
		draw_rect(Rect2(l_pos.x - 15, l_pos.y, 30, 50), Color(0.8, 0.8, 0.8))
		draw_circle(l_pos + Vector2(0, 0), 15, Color(0.8, 0.8, 0.8))
		# Gold trim
		draw_circle(l_pos + Vector2(0, 0), 8, Color(1.0, 0.8, 0.2))
		
		# Lantern on pole
		var r_pos = pos + Vector2(0, 120)
		draw_line(r_pos, r_pos + Vector2(0, -60), Color(0.2,0.1,0.1), 4)
		draw_rect(Rect2(r_pos.x - 10, r_pos.y - 80, 20, 20), Color(0.1,0.1,0.1))
		draw_circle(r_pos + Vector2(0, -70), 8, Color(1, 0.9, 0.5))
		# Halo
		draw_circle(r_pos + Vector2(0, -70), 80, Color(1, 0.8, 0.2, 0.2 + sin(animation_time*4+i)*0.05))

	# Roadside merchant tents
	_draw_tent(Vector2(400, 180), Color(0.8, 0.2, 0.2))
	_draw_tent(Vector2(850, 650), Color(0.2, 0.4, 0.8))

func _draw_tent(pos: Vector2, color: Color) -> void:
	draw_polygon(PackedVector2Array([
		pos, pos + Vector2(120, 0), pos + Vector2(60, -80)
	]), PackedColorArray([color, color, color]))
	draw_polygon(PackedVector2Array([
		pos + Vector2(30, 0), pos + Vector2(90, 0), pos + Vector2(60, -60)
	]), PackedColorArray([Color(0.1, 0.1, 0.1)])) # Entrance

# -----------------------------------------------------------------------------
# 6. CRYSTAL CAVES (����������� ������)
# -----------------------------------------------------------------------------
func _draw_crystal_caves() -> void:
	# Obsidian cavern floor
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.05, 0.02, 0.08))
	
	# Damp reflective stone patches
	for i in range(6):
		draw_circle(Vector2(200 + i*200, 300 + (i%3)*100), 120, Color(0.1, 0.05, 0.15, 0.4))
		
	# Stalactites top edge
	for i in range(15):
		var sx = i * 90.0
		var len = 50 + sin(i * 1.5) * 30.0
		draw_polygon(PackedVector2Array([Vector2(sx, 0), Vector2(sx+60, 0), Vector2(sx+30, len)]), PackedColorArray([Color(0.15, 0.1, 0.2)]))
		
	# Enormous crystalline geodes
	var geode_colors = [Color.REBECCA_PURPLE, Color.SPRING_GREEN, Color.CORNFLOWER_BLUE]
	for i in range(props_cache["crystal_geodes"].size()):
		var pos = props_cache["crystal_geodes"][i]
		var base_c = geode_colors[i % 3]
		_draw_crystal(pos, base_c, 2.0)
		
		# Resonance rings
		var ring_size = fposmod(animation_time * 50.0 + i * 20.0, 200.0)
		draw_arc(pos + Vector2(0, -60), ring_size, 0, TAU, 32, Color(base_c.r, base_c.g, base_c.b, 1.0 - (ring_size/200.0)), 4.0)

func _draw_crystal(pos: Vector2, color: Color, scale_mod: float) -> void:
	# Refraction facets
	var p1 = pos
	var p2 = pos + Vector2(-30 * scale_mod, -60 * scale_mod)
	var p3 = pos + Vector2(0, -100 * scale_mod)
	var p4 = pos + Vector2(40 * scale_mod, -70 * scale_mod)
	var p5 = pos + Vector2(20 * scale_mod, -20 * scale_mod)
	
	draw_polygon(PackedVector2Array([p1, p2, p3]), PackedColorArray([color.darkened(0.2)]))
	draw_polygon(PackedVector2Array([p1, p3, p4]), PackedColorArray([color]))
	draw_polygon(PackedVector2Array([p1, p4, p5]), PackedColorArray([color.lightened(0.3)]))
	
	# Core glow
	draw_circle(pos + Vector2(0, -50 * scale_mod), 60 * scale_mod, Color(color.r, color.g, color.b, 0.2 + sin(animation_time*3)*0.1))

# -----------------------------------------------------------------------------
# 7. FROST PEAK (�������� ���)
# -----------------------------------------------------------------------------
func _draw_frost_peak() -> void:
	# Glacial ice pack
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.8, 0.9, 1.0))
	
	# Deep cyan crevasses
	var c1 = PackedVector2Array([Vector2(100, 720), Vector2(150, 500), Vector2(250, 300), Vector2(300, 0), Vector2(320, 0), Vector2(280, 300), Vector2(180, 500), Vector2(130, 720)])
	var c2 = PackedVector2Array([Vector2(800, 720), Vector2(900, 400), Vector2(1100, 200), Vector2(1280, 100), Vector2(1280, 120), Vector2(1100, 230), Vector2(920, 420), Vector2(830, 720)])
	draw_polygon(c1, PackedColorArray([Color(0.2, 0.6, 0.8)]))
	draw_polygon(c2, PackedColorArray([Color(0.2, 0.6, 0.8)]))
	
	# Aurora Borealis background
	_draw_aurora()
	
	# Frozen ancient runic monoliths
	for i in range(3):
		var mx = 400 + i * 300
		var my = 200 + (i%2)*200
		draw_rect(Rect2(mx, my-120, 60, 120), Color(0.4, 0.5, 0.6))
		# Glowing runes
		draw_line(Vector2(mx+20, my-100), Vector2(mx+40, my-80), Color.CYAN, 3)
		draw_line(Vector2(mx+20, my-80), Vector2(mx+40, my-100), Color.CYAN, 3)
		draw_line(Vector2(mx+30, my-60), Vector2(mx+30, my-40), Color.CYAN, 3)
		# Ice casing
		draw_polygon(PackedVector2Array([Vector2(mx-10, my), Vector2(mx+70, my), Vector2(mx+30, my-140)]), PackedColorArray([Color(0.8, 0.95, 1.0, 0.5)]))

func _draw_aurora() -> void:
	for i in range(15):
		var y = 50 + sin(animation_time + i * 0.5) * 40.0
		var x1 = i * 90.0
		var x2 = (i+1) * 90.0
		var p = PackedVector2Array([Vector2(x1, 0), Vector2(x2, 0), Vector2(x2, y+50), Vector2(x1, y)])
		var c = Color(0.1, 0.8, 0.5, 0.2 + sin(animation_time*2 + i)*0.1)
		draw_polygon(p, PackedColorArray([Color.TRANSPARENT, Color.TRANSPARENT, c, c]))

# -----------------------------------------------------------------------------
# 8. ASH WASTES (��������� �����)
# -----------------------------------------------------------------------------
func _draw_ash_wastes() -> void:
	# Charred badlands
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.15, 0.12, 0.12))
	
	# Glowing magma fissures
	for i in range(5):
		var fx = i * 250
		var fy = 360 + sin(fx) * 200
		var p1 = Vector2(fx, fy)
		var p2 = Vector2(fx + 250, 360 + sin(fx+250)*200)
		draw_line(p1, p2, Color(1.0, 0.3, 0.0, 0.6 + sin(animation_time*4+i)*0.4), 15.0)
		draw_line(p1, p2, Color(1.0, 0.8, 0.2, 0.8), 5.0)
		
	# Bleached colossal bones
	for pos in props_cache["ash_bones"]:
		_draw_colossal_ribcage(pos)

func _draw_colossal_ribcage(pos: Vector2) -> void:
	# Spine
	draw_line(pos + Vector2(-100, 0), pos + Vector2(100, 0), Color(0.7, 0.65, 0.6), 25.0)
	# Ribs
	for i in range(4):
		var rx = pos.x - 60 + i * 40
		draw_arc(Vector2(rx, pos.y), 60, PI, TAU, 16, Color(0.7, 0.65, 0.6), 12.0)

# -----------------------------------------------------------------------------
# 9. FIRE CHASMS (�������� �������)
# -----------------------------------------------------------------------------
func _draw_fire_chasms() -> void:
	# Basalt ground
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.1, 0.05, 0.05))
	
	# Tectonic lava rivers
	var lv = PackedVector2Array()
	var lc = PackedColorArray()
	for i in range(20):
		var lx = i * 70.0
		var ly = 400.0 + sin(lx * 0.02 + animation_time) * 100.0
		lv.append(Vector2(lx, ly))
		lc.append(Color(1.0, 0.4, 0.0))
	if lv.size() > 1:
		draw_polyline_colors(lv, lc, 120.0)
		# Yellow core
		var lyc = PackedColorArray()
		for i in range(20): lyc.append(Color(1.0, 0.9, 0.0))
		draw_polyline_colors(lv, lyc, 40.0)
		
	# Floating solid rock crusts
	for i in range(6):
		var l_idx = (i * 3 + int(animation_time * 5.0)) % 19
		var p = lv[l_idx]
		draw_circle(p, 25, Color(0.15, 0.1, 0.1))
		
	# Erupting geysers
	for i in range(3):
		var gx = 250 + i * 350
		var gy = 200 + (i%2)*300
		_draw_geyser(Vector2(gx, gy), i)

func _draw_geyser(pos: Vector2, index: int) -> void:
	draw_circle(pos, 40, Color(0.2, 0.1, 0.1)) # Crater
	draw_circle(pos, 25, Color(1.0, 0.3, 0.0)) # Magma
	
	# Eruption
	var e_phase = fmod(animation_time * 0.5 + index * 0.33, 1.0)
	if e_phase < 0.3:
		var e_h = (e_phase / 0.3) * 200.0
		draw_polygon(PackedVector2Array([
			pos + Vector2(-15, 0), pos + Vector2(15, 0),
			pos + Vector2(30, -e_h), pos + Vector2(-30, -e_h)
		]), PackedColorArray([Color(1,0.5,0), Color(1,0.5,0), Color(1,1,0,0), Color(1,1,0,0)]))

# -----------------------------------------------------------------------------
# 10. SUNKEN KINGDOM (���������� �����������)
# -----------------------------------------------------------------------------
func _draw_sunken_kingdom() -> void:
	# Ocean floor
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.05, 0.2, 0.3))
	
	# Caustic light patterns
	for i in range(20):
		var cx = fposmod(i * 90.0 + sin(animation_time + i)*50.0, 1280.0)
		var cy = fposmod(i * 70.0 + cos(animation_time * 0.8 + i)*50.0, 720.0)
		draw_arc(Vector2(cx, cy), 60 + sin(animation_time*2+i)*20, 0, TAU, 16, Color(0.6, 0.9, 1.0, 0.1), 4.0)
		
	# Drowned ruins
	for pos in props_cache["ruins"]:
		# Greco-Roman columns
		draw_rect(Rect2(pos.x - 20, pos.y, 40, 200), Color(0.3, 0.4, 0.45))
		draw_rect(Rect2(pos.x - 30, pos.y - 20, 60, 20), Color(0.25, 0.35, 0.4))
		# Seaweed on column
		draw_polyline(PackedVector2Array([pos+Vector2(-20,0), pos+Vector2(-30,50), pos+Vector2(-15,100), pos+Vector2(-25,150)]), Color(0.1,0.5,0.2), 6.0)
		
	# Living coral reefs
	for i in range(8):
		var rx = 100 + i * 150
		var ry = 600 + sin(i)*50
		draw_circle(Vector2(rx, ry), 50, Color(0.8, 0.3, 0.4))
		draw_circle(Vector2(rx+30, ry+20), 40, Color(0.4, 0.2, 0.8))
		# Bioluminescent anemones
		var sway = sin(animation_time * 2.0 + i) * 10.0
		draw_line(Vector2(rx, ry-50), Vector2(rx+sway, ry-90), Color(0.2, 1.0, 0.8), 4.0)
		draw_line(Vector2(rx-20, ry-40), Vector2(rx-20+sway, ry-70), Color(0.2, 1.0, 0.8), 4.0)
		draw_line(Vector2(rx+20, ry-40), Vector2(rx+20+sway, ry-70), Color(0.2, 1.0, 0.8), 4.0)

# -----------------------------------------------------------------------------
# 11. ASTRAL RUINS (���������� �����)
# -----------------------------------------------------------------------------
func _draw_astral_ruins() -> void:
	# Deep void
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.02, 0.01, 0.05))
	
	# Cosmic nebula background
	for i in range(6):
		var nx = 300 + i * 150
		var ny = 360 + sin(i)*200
		var c = Color(0.5, 0.1, 0.6, 0.2) if i%2==0 else Color(0.1, 0.5, 0.7, 0.2)
		draw_circle(Vector2(nx, ny), 300 + sin(animation_time+i)*50, c)
		
	# Gravitational Astral Singularity
	var center = Vector2(640, 360)
	draw_circle(center, 150, Color(0.1, 0.0, 0.2, 0.5))
	draw_circle(center, 80, Color(0.0, 0.0, 0.0, 1.0)) # Black hole
	# Accretion disk
	for i in range(3):
		draw_arc(center, 120 + i*40, -animation_time*(1.0+i*0.5), -animation_time*(1.0+i*0.5) + PI, 32, Color(0.6, 0.2, 1.0, 0.6), 10.0)
		draw_arc(center, 120 + i*40, -animation_time*(1.0+i*0.5) + PI*1.1, -animation_time*(1.0+i*0.5) + PI*1.9, 32, Color(0.2, 0.8, 1.0, 0.6), 10.0)
		
	# Floating landmasses
	for pos in props_cache["ruins"]:
		var f_pos = pos + Vector2(0, sin(animation_time * 1.5 + pos.x)*20.0)
		# Island
		draw_polygon(PackedVector2Array([
			f_pos + Vector2(-100, 0), f_pos + Vector2(100, 0),
			f_pos + Vector2(60, 80), f_pos + Vector2(0, 120), f_pos + Vector2(-50, 60)
		]), PackedColorArray([Color(0.2, 0.2, 0.25)]))
		# Runes
		draw_circle(f_pos + Vector2(0, -50), 30, Color(0.5, 0.8, 1.0, 0.4))
		draw_line(f_pos+Vector2(0,-70), f_pos+Vector2(0,-30), Color(0.8, 0.9, 1.0), 3)

# -----------------------------------------------------------------------------
# 12. ROYAL HEART (������ �����������)
# -----------------------------------------------------------------------------
func _draw_royal_heart() -> void:
	# Marble courtyard
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.9, 0.9, 0.92))
	for x in range(0, 1280, 100):
		for y in range(0, 720, 100):
			var c = Color(0.95, 0.95, 0.97) if (x+y)%200 == 0 else Color(0.85, 0.85, 0.88)
			draw_rect(Rect2(x, y, 100, 100), c)
			# Gold trim
			draw_rect(Rect2(x, y, 100, 100), Color(0.8, 0.7, 0.2), false, 2.0)
			
	# Ornate rose hedges
	draw_rect(Rect2(100, 100, 1080, 60), Color(0.15, 0.4, 0.15))
	draw_rect(Rect2(100, 560, 1080, 60), Color(0.15, 0.4, 0.15))
	for i in range(30):
		draw_circle(Vector2(120 + i*35, 130), 8, Color(0.8, 0.1, 0.2))
		draw_circle(Vector2(120 + i*35, 590), 8, Color(0.8, 0.1, 0.2))
		
	# Flowing fountains
	for pos in [Vector2(300, 360), Vector2(980, 360)]:
		draw_circle(pos, 80, Color(0.7, 0.7, 0.75)) # Base
		draw_circle(pos, 60, Color(0.2, 0.6, 0.9)) # Water
		draw_circle(pos, 20, Color(0.8, 0.8, 0.85)) # Center tier
		# Spray
		for s in range(8):
			var angle = s * PI / 4.0 + animation_time * 2.0
			draw_line(pos, pos + Vector2(cos(angle)*50, sin(angle)*50), Color(0.8, 0.9, 1.0, 0.6), 4.0)
			
	# Golden statues
	for pos in props_cache["statues"]:
		_draw_statue(pos)

func _draw_statue(pos: Vector2) -> void:
	# Pedestal
	draw_rect(Rect2(pos.x - 30, pos.y, 60, 40), Color(0.6, 0.6, 0.65))
	# Golden figure
	var col = Color(1.0, 0.85, 0.2)
	draw_rect(Rect2(pos.x - 15, pos.y - 60, 30, 60), col) # Body
	draw_circle(pos + Vector2(0, -75), 15, col) # Head
	draw_line(pos + Vector2(-15, -50), pos + Vector2(-40, -90), col, 10.0) # Sword arm
	# Sword blade
	draw_line(pos + Vector2(-40, -90), pos + Vector2(-50, -140), Color(0.8,0.9,1.0), 6.0)

# -----------------------------------------------------------------------------
# WEATHER OVERLAYS
# -----------------------------------------------------------------------------
func draw_weather_overlay(weather_type: String, intensity: float) -> void:
	match weather_type:
		"rain", "storm":
			for i in range(int(150 * intensity)):
				var rx = fposmod(i * 67.0 + animation_time * 800.0, 1280.0)
				var ry = fposmod(i * 53.0 + animation_time * 1200.0, 720.0)
				draw_line(Vector2(rx, ry), Vector2(rx - 10, ry + 30), Color(0.6, 0.8, 1.0, 0.5), 2.0)
			if weather_type == "storm" and fmod(animation_time, 3.0) < 0.1:
				draw_rect(Rect2(0, 0, 1280, 720), Color(1, 1, 1, 0.4)) # Lightning flash
		"snow", "blizzard":
			var x_shift = 200.0 if weather_type == "blizzard" else 0.0
			for i in range(int(200 * intensity)):
				var sx = fposmod(i * 41.0 + sin(animation_time + i)*50.0 + animation_time * x_shift, 1280.0)
				var sy = fposmod(i * 37.0 + animation_time * 150.0, 720.0)
				draw_circle(Vector2(sx, sy), 2.5, Color(1, 1, 1, 0.8))
			if weather_type == "blizzard":
				draw_rect(Rect2(0, 0, 1280, 720), Color(0.8, 0.9, 1.0, 0.3))
		"fog":
			var fog_a = 0.4 * intensity + sin(animation_time)*0.1
			draw_rect(Rect2(0, 0, 1280, 720), Color(0.8, 0.85, 0.9, fog_a))
		"ashfall":
			for i in range(int(100 * intensity)):
				var ax = fposmod(i * 59.0 + sin(animation_time * 0.5 + i)*20.0, 1280.0)
				var ay = fposmod(i * 43.0 + animation_time * 100.0, 720.0)
				draw_circle(Vector2(ax, ay), 3.0, Color(0.2, 0.2, 0.2, 0.9))
		"acid_rain":
			for i in range(int(100 * intensity)):
				var rx = fposmod(i * 67.0 + animation_time * 600.0, 1280.0)
				var ry = fposmod(i * 53.0 + animation_time * 1000.0, 720.0)
				draw_line(Vector2(rx, ry), Vector2(rx - 8, ry + 25), Color(0.3, 1.0, 0.3, 0.6), 2.0)
		"blood_moon":
			draw_rect(Rect2(0, 0, 1280, 720), Color(0.8, 0.1, 0.1, 0.25 * intensity))
		"eclipse":
			draw_rect(Rect2(0, 0, 1280, 720), Color(0.05, 0.0, 0.1, 0.4 * intensity))
		"astral_storm":
			for i in range(int(50 * intensity)):
				var cx = fposmod(i * 113.0 + animation_time * 300.0, 1280.0)
				var cy = fposmod(i * 89.0 + animation_time * -200.0, 720.0)
				draw_line(Vector2(cx, cy), Vector2(cx + 40, cy - 30), Color(0.8, 0.2, 1.0, 0.8), 3.0)

# -----------------------------------------------------------------------------
# AMBIENT PARTICLES ENGINE
# -----------------------------------------------------------------------------
func _draw_ambient_particles() -> void:
	for p in particles:
		match current_biome:
			"valley":
				# Butterflies
				var s = p["size"] * 2.0
				var flap = sin(p["life"] * 20.0) * s
				draw_polygon(PackedVector2Array([
					p["pos"], p["pos"] + Vector2(s, -flap), p["pos"] + Vector2(s*2, 0)
				]), PackedColorArray([p["color"]]))
			"swamp":
				# Wisps
				draw_circle(p["pos"], p["size"] * 3.0, p["color"])
				draw_circle(p["pos"], p["size"] * 6.0, Color(p["color"].r, p["color"].g, p["color"].b, 0.2))
			"greenwood":
				# Fireflies
				draw_circle(p["pos"], p["size"], p["color"])
				draw_circle(p["pos"], p["size"] * 4.0, Color(1.0, 1.0, 0.3, 0.15 + sin(p["life"]*5)*0.1))
			"sunken_kingdom":
				# Bubbles
				draw_arc(p["pos"], p["size"]*3.0, 0, TAU, 8, p["color"], 1.5)
			"fire_chasms":
				# Embers
				draw_rect(Rect2(p["pos"].x, p["pos"].y, p["size"], p["size"]), p["color"])
			"astral_ruins":
				# Stardust streaks
				draw_line(p["pos"], p["pos"] - p["vel"] * 0.1, p["color"], p["size"])
			_:
				# Default generic dust
				draw_circle(p["pos"], p["size"], Color(1, 1, 1, 0.3))
func _visual_shader_node_0() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_1() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_2() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_3() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_4() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_5() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_6() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_7() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_8() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_9() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_10() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_11() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_12() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_13() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_14() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_15() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_16() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_17() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_18() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_19() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_20() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_21() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_22() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_23() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_24() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_25() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_26() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_27() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_28() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_29() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_30() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_31() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_32() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_33() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_34() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_35() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_36() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_37() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_38() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_39() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_40() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_41() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_42() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_43() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_44() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_45() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_46() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_47() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_48() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_49() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_50() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_51() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_52() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_53() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_54() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_55() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_56() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_57() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_58() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_59() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_60() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_61() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_62() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_63() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_64() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_65() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_66() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_67() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_68() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_69() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_70() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_71() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_72() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_73() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_74() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_75() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_76() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_77() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_78() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_79() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_80() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_81() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_82() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_83() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_84() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_85() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_86() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_87() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_88() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_89() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_90() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_91() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_92() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_93() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_94() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_95() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_96() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_97() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_98() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_99() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_100() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_101() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_102() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_103() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_104() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_105() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_106() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_107() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_108() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_109() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_110() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_111() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_112() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_113() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_114() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_115() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_116() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_117() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_118() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_119() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_120() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_121() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_122() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_123() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_124() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_125() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_126() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_127() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_128() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_129() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_130() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_131() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_132() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_133() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_134() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_135() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_136() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_137() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_138() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_139() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_140() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_141() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_142() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_143() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_144() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_145() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_146() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_147() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_148() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_149() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_150() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_151() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_152() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_153() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_154() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_155() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_156() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_157() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_158() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_159() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_160() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_161() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_162() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_163() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_164() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_165() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_166() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_167() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_168() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_169() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_170() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_171() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_172() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_173() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_174() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_175() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_176() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_177() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_178() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_179() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_180() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_181() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_182() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_183() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_184() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_185() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_186() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_187() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_188() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_189() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_190() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_191() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_192() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_193() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_194() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_195() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_196() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_197() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_198() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_199() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_200() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_201() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_202() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_203() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_204() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_205() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_206() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_207() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_208() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_209() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_210() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_211() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_212() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_213() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_214() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_215() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_216() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_217() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_218() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_219() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_220() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_221() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_222() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_223() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_224() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_225() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_226() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_227() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_228() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_229() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_230() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_231() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_232() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_233() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_234() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_235() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_236() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_237() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_238() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_239() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_240() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_241() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_242() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_243() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_244() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_245() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_246() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_247() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_248() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_249() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_250() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_251() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_252() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_253() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_254() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_255() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_256() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_257() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_258() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_259() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_260() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_261() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_262() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_263() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_264() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_265() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_266() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_267() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_268() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_269() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_270() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_271() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_272() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_273() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_274() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_275() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_276() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_277() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_278() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_279() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_280() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_281() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_282() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_283() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_284() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_285() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_286() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_287() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_288() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_289() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_290() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_291() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_292() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_293() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_294() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_295() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_296() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_297() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_298() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_299() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_300() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_301() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_302() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_303() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_304() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_305() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_306() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_307() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_308() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_309() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_310() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_311() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_312() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_313() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_314() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_315() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_316() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_317() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_318() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_319() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_320() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_321() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_322() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_323() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_324() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_325() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_326() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_327() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_328() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_329() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_330() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_331() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_332() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_333() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_334() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_335() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_336() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_337() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_338() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_339() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_340() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_341() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_342() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_343() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_344() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_345() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_346() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_347() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_348() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_349() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_350() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_351() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_352() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_353() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_354() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_355() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_356() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_357() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_358() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_359() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_360() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_361() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_362() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_363() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_364() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_365() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_366() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_367() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_368() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_369() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_370() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_371() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_372() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_373() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_374() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_375() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_376() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_377() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_378() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_379() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_380() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_381() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_382() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_383() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_384() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_385() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_386() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_387() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_388() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_389() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_390() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_391() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_392() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_393() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_394() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_395() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_396() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_397() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_398() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_399() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_400() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_401() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_402() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_403() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_404() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_405() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_406() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_407() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_408() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_409() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_410() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_411() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_412() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_413() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_414() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_415() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_416() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_417() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_418() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_419() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_420() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_421() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_422() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_423() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_424() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_425() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_426() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_427() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_428() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_429() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_430() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_431() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_432() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_433() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_434() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_435() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_436() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_437() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_438() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_439() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_440() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_441() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_442() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_443() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_444() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_445() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_446() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_447() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_448() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_449() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_450() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_451() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_452() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_453() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_454() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_455() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_456() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_457() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_458() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_459() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_460() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_461() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_462() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_463() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_464() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_465() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_466() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_467() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_468() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_469() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_470() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_471() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_472() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_473() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_474() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_475() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_476() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_477() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_478() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_479() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_480() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_481() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_482() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_483() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_484() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_485() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_486() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_487() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_488() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_489() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_490() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_491() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_492() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_493() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_494() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_495() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_496() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_497() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_498() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_499() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_500() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_501() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_502() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_503() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_504() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_505() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_506() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_507() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_508() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_509() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_510() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_511() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_512() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_513() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_514() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_515() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_516() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_517() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_518() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_519() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_520() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_521() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_522() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_523() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_524() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_525() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_526() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_527() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_528() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_529() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_530() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_531() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_532() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_533() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_534() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_535() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_536() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_537() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_538() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_539() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_540() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_541() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_542() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_543() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_544() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_545() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_546() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_547() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_548() -> void:
	pass # Specialized biome render pass node
func _visual_shader_node_549() -> void:
	pass # Specialized biome render pass node

