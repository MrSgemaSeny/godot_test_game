class_name MapEditor
extends Node2D

signal map_saved(filename: String)
signal map_validated(result: Dictionary)

enum EditMode { PLACE_PATH, PLACE_BUILD_SPOT, PLACE_DECORATION, ERASE, TEST_PLAY }

var current_mode: EditMode = EditMode.PLACE_PATH
var path_points: Array[Vector2] = []
var build_spots: Array[Vector2] = []
var decorations: Array[Dictionary] = []
var map_name: String = "custom_map"
var selected_biome: String = "valley"

const GRID_CELL = 64
var _camera_pos: Vector2 = Vector2.ZERO
var _is_panning: bool = false
var _pan_start: Vector2 = Vector2.ZERO
var proc_gen: ProceduralMapGenerator = null

func _ready() -> void:
	add_to_group("map_editor")
	proc_gen = ProceduralMapGenerator.new()
	add_child(proc_gen)
	set_process_input(true)

func set_mode(mode: EditMode) -> void:
	current_mode = mode
	queue_redraw()

func clear_map() -> void:
	path_points.clear()
	build_spots.clear()
	decorations.clear()
	queue_redraw()

func generate_random_map(seed: int) -> void:
	var data = proc_gen.generate_map(seed, selected_biome, 1)
	if data.has("curve_points"):
		path_points = data["curve_points"]
	if data.has("build_spots"):
		build_spots = data["build_spots"]
	if data.has("decorations"):
		decorations = data["decorations"]
	queue_redraw()

func add_path_point(pos: Vector2) -> void:
	var snapped_pos = pos.snapped(Vector2(GRID_CELL, GRID_CELL))
	if not path_points.is_empty():
		var last = path_points.back()
		if last.distance_to(snapped_pos) < GRID_CELL:
			return # too close
	path_points.append(snapped_pos)
	queue_redraw()

func remove_last_path_point() -> void:
	if not path_points.is_empty():
		path_points.pop_back()
		queue_redraw()

func add_build_spot(pos: Vector2) -> void:
	# validate not on path
	for i in range(path_points.size() - 1):
		var p1 = path_points[i]
		var p2 = path_points[i+1]
		if _point_dist_to_segment(pos, p1, p2) < 45.0:
			push_warning("Cannot place build spot on path!")
			return
	build_spots.append(pos)
	queue_redraw()

func _point_dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var l2 = a.distance_squared_to(b)
	if l2 == 0: return p.distance_to(a)
	var t = max(0, min(1, (p - a).dot(b - a) / l2))
	var projection = a + t * (b - a)
	return p.distance_to(projection)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mpos = get_global_mouse_position()
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				_is_panning = true
				_pan_start = event.position
			else:
				_is_panning = false
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			match current_mode:
				EditMode.PLACE_PATH:
					add_path_point(mpos)
				EditMode.PLACE_BUILD_SPOT:
					add_build_spot(mpos)
				EditMode.PLACE_DECORATION:
					decorations.append({"type": "custom", "pos": mpos, "color": Color.WHITE, "size": 3.0})
					queue_redraw()
				EditMode.ERASE:
					_erase_at(mpos)
					queue_redraw()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			match current_mode:
				EditMode.PLACE_PATH:
					remove_last_path_point()
				_:
					_erase_at(mpos)
					queue_redraw()
	elif event is InputEventMouseMotion:
		if _is_panning:
			var diff = event.position - _pan_start
			position += diff
			_pan_start = event.position
		queue_redraw()

func _erase_at(mpos: Vector2) -> void:
	# Try decorations first
	for i in range(decorations.size() - 1, -1, -1):
		if mpos.distance_to(decorations[i]["pos"]) < 20.0:
			decorations.remove_at(i)
			return
	# Try build spots
	for i in range(build_spots.size() - 1, -1, -1):
		if mpos.distance_to(build_spots[i]) < 20.0:
			build_spots.remove_at(i)
			return

func _draw() -> void:
	# Draw grid
	for x in range(0, 1280, GRID_CELL):
		draw_line(Vector2(x, 0), Vector2(x, 720), Color(1, 1, 1, 0.1), 1)
	for y in range(0, 720, GRID_CELL):
		draw_line(Vector2(0, y), Vector2(1280, y), Color(1, 1, 1, 0.1), 1)
		
	# Draw path
	if path_points.size() > 1:
		draw_polyline(path_points, Color(0.8, 0.6, 0.2, 0.6), 24.0)
		for i in range(path_points.size() - 1):
			var dir = (path_points[i+1] - path_points[i]).normalized()
			var mid = (path_points[i] + path_points[i+1]) / 2.0
			draw_line(mid, mid - dir * 10 + dir.rotated(PI/2) * 10, Color(1, 0, 0), 2)
			draw_line(mid, mid - dir * 10 - dir.rotated(PI/2) * 10, Color(1, 0, 0), 2)
			
	for p in path_points:
		draw_circle(p, 8, Color(0.9, 0.2, 0.2))
		
	# Draw build spots
	for s in build_spots:
		draw_circle(s, 24, Color(0.2, 0.8, 0.3, 0.5))
		draw_arc(s, 24, 0, TAU, 16, Color(0.1, 0.6, 0.2), 2)
		
	# Draw decorations
	for d in decorations:
		var c = d.get("color", Color.WHITE)
		var s = d.get("size", 4.0)
		draw_circle(d["pos"], s * 3, c)

func save_map(filename: String) -> bool:
	var validation = _validate_current_map()
	map_validated.emit(validation)
	if not validation["valid"]:
		push_error("Map validation failed: " + str(validation["errors"]))
		return false
		
	var export_data = export_to_game_map()
	var json_str = JSON.stringify(export_data)
	
	if not DirAccess.dir_exists_absolute("user://maps"):
		DirAccess.make_dir_absolute("user://maps")
		
	var file = FileAccess.open("user://maps/" + filename + ".json", FileAccess.WRITE)
	if file:
		file.store_string(json_str)
		map_saved.emit(filename)
		return true
	return false

func load_map(filename: String) -> bool:
	var path = "user://maps/" + filename + ".json"
	if not FileAccess.file_exists(path):
		return false
		
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		var json = JSON.new()
		if json.parse(content) == OK:
			var data = json.data
			if data is Dictionary:
				path_points.clear()
				if data.has("curve_points"):
					for p in data["curve_points"]:
						path_points.append(Vector2(p[0], p[1]))
				
				build_spots.clear()
				if data.has("build_spots"):
					for s in data["build_spots"]:
						build_spots.append(Vector2(s[0], s[1]))
						
				decorations.clear()
				if data.has("decorations"):
					for d in data["decorations"]:
						decorations.append({
							"type": d.get("type", "custom"),
							"pos": Vector2(d["pos"][0], d["pos"][1]),
							"color": Color(d.get("color", "#ffffff")),
							"size": d.get("size", 4.0)
						})
				
				map_name = filename
				selected_biome = data.get("biome", "valley")
				queue_redraw()
				return true
	return false

func export_to_game_map() -> Dictionary:
	var safe_curves = []
	for p in path_points: safe_curves.append([p.x, p.y])
	
	var safe_spots = []
	for p in build_spots: safe_spots.append([p.x, p.y])
	
	var safe_decos = []
	for d in decorations:
		var c: Color = d.get("color", Color.WHITE)
		safe_decos.append({
			"type": d.get("type", "custom"),
			"pos": [d["pos"].x, d["pos"].y],
			"color": c.to_html(),
			"size": d.get("size", 4.0)
		})
		
	return {
		"version": "1.1",
		"map_name": map_name,
		"biome": selected_biome,
		"curve_points": safe_curves,
		"build_spots": safe_spots,
		"decorations": safe_decos
	}

func _validate_current_map() -> Dictionary:
	var errors: Array[String] = []
	
	if path_points.size() < 4:
		errors.append("Path must have at least 4 points.")
	if build_spots.size() < 3:
		errors.append("Need at least 3 build spots.")
		
	# Path start/end checks could go here, but allowing freeform for editor
		
	return {
		"valid": errors.is_empty(),
		"errors": errors
	}
