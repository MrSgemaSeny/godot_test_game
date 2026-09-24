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
var current_decoration_type: String = "flower"
var current_zoom: float = 1.0

const GRID_CELL = 64
var _camera_pos: Vector2 = Vector2.ZERO
var _is_panning: bool = false
var _pan_start: Vector2 = Vector2.ZERO
var proc_gen: ProceduralMapGenerator = null

# Undo/Redo System
var undo_stack: Array[Dictionary] = []
var redo_stack: Array[Dictionary] = []
const MAX_UNDO_STEPS = 50

func _ready() -> void:
	add_to_group("map_editor")
	proc_gen = ProceduralMapGenerator.new()
	add_child(proc_gen)
	set_process_input(true)
	_push_undo_state()
	_connect_ui_buttons()

func _connect_ui_buttons() -> void:
	var btn_path = get_node_or_null("CanvasLayer/Panel/VBoxContainer/BtnPath") as Button
	if is_instance_valid(btn_path): btn_path.pressed.connect(func(): set_mode(EditMode.PLACE_PATH))
	
	var btn_build = get_node_or_null("CanvasLayer/Panel/VBoxContainer/BtnBuild") as Button
	if is_instance_valid(btn_build): btn_build.pressed.connect(func(): set_mode(EditMode.PLACE_BUILD_SPOT))
	
	var btn_deco = get_node_or_null("CanvasLayer/Panel/VBoxContainer/BtnDeco") as Button
	if is_instance_valid(btn_deco): btn_deco.pressed.connect(func(): set_mode(EditMode.PLACE_DECORATION))
	
	var btn_erase = get_node_or_null("CanvasLayer/Panel/VBoxContainer/BtnErase") as Button
	if is_instance_valid(btn_erase): btn_erase.pressed.connect(func(): set_mode(EditMode.ERASE))
	
	var btn_gen = get_node_or_null("CanvasLayer/Panel/VBoxContainer/BtnGen") as Button
	if is_instance_valid(btn_gen): btn_gen.pressed.connect(func(): generate_random_map(randi()))
	
	var btn_save = get_node_or_null("CanvasLayer/Panel/VBoxContainer/BtnSave") as Button
	if is_instance_valid(btn_save): btn_save.pressed.connect(func(): 
		save_map("custom_map")
		_set_status("Карта сохранена!")
	)
	
	var btn_load = get_node_or_null("CanvasLayer/Panel/VBoxContainer/BtnLoad") as Button
	if is_instance_valid(btn_load): btn_load.pressed.connect(func(): 
		if load_map("custom_map"):
			_set_status("Карта загружена!")
		else:
			_set_status("Файл не найден")
	)
	
	var btn_back = get_node_or_null("CanvasLayer/Panel/VBoxContainer/BtnBack") as Button
	if is_instance_valid(btn_back): btn_back.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	)
	
	var opt_biome = get_node_or_null("CanvasLayer/Panel/VBoxContainer/OptionBiome") as OptionButton
	if is_instance_valid(opt_biome):
		opt_biome.item_selected.connect(func(idx):
			selected_biome = opt_biome.get_item_text(idx)
			queue_redraw()
		)

func _set_status(txt: String) -> void:
	var lbl = get_node_or_null("CanvasLayer/Panel/VBoxContainer/StatusLabel") as Label
	if is_instance_valid(lbl):
		lbl.text = txt

func _push_undo_state() -> void:
	var state = {
		"path_points": path_points.duplicate(true),
		"build_spots": build_spots.duplicate(true),
		"decorations": decorations.duplicate(true)
	}
	undo_stack.append(state)
	if undo_stack.size() > MAX_UNDO_STEPS:
		undo_stack.pop_front()
	redo_stack.clear()

func undo_last_action() -> void:
	if undo_stack.size() > 1:
		var current_state = undo_stack.pop_back()
		redo_stack.append(current_state)
		var previous_state = undo_stack.back()
		_apply_state(previous_state)

func redo_action() -> void:
	if redo_stack.size() > 0:
		var state = redo_stack.pop_back()
		undo_stack.append(state)
		_apply_state(state)

func _apply_state(state: Dictionary) -> void:
	path_points = state["path_points"].duplicate(true)
	build_spots = state["build_spots"].duplicate(true)
	decorations = state["decorations"].duplicate(true)
	queue_redraw()

func set_mode(mode: EditMode) -> void:
	current_mode = mode
	queue_redraw()
	
func set_decoration_type(dec_type: String) -> void:
	current_decoration_type = dec_type

func set_zoom(zoom_level: float) -> void:
	current_zoom = clamp(zoom_level, 0.5, 2.0)
	scale = Vector2(current_zoom, current_zoom)
	queue_redraw()

func clear_map() -> void:
	_push_undo_state()
	path_points.clear()
	build_spots.clear()
	decorations.clear()
	queue_redraw()

func generate_random_map(seed: int) -> void:
	_push_undo_state()
	var data = proc_gen.generate_map(seed, selected_biome, 1)
	if data.has("curve_points"):
		path_points = data["curve_points"]
	if data.has("build_spots"):
		build_spots = data["build_spots"]
	if data.has("decorations"):
		decorations = data["decorations"]
	queue_redraw()

func snap_to_grid(pos: Vector2) -> Vector2:
	return pos.snapped(Vector2(GRID_CELL, GRID_CELL))

func add_path_point(pos: Vector2) -> void:
	_push_undo_state()
	var snapped_pos = snap_to_grid(pos)
	if not path_points.is_empty():
		var last = path_points.back()
		if last.distance_to(snapped_pos) < GRID_CELL:
			return # too close
	path_points.append(snapped_pos)
	queue_redraw()

func insert_path_point(index: int, pos: Vector2) -> void:
	_push_undo_state()
	if index >= 0 and index <= path_points.size():
		path_points.insert(index, snap_to_grid(pos))
		queue_redraw()

func move_path_point(index: int, new_pos: Vector2) -> void:
	_push_undo_state()
	if index >= 0 and index < path_points.size():
		path_points[index] = snap_to_grid(new_pos)
		queue_redraw()

func remove_last_path_point() -> void:
	_push_undo_state()
	if not path_points.is_empty():
		path_points.pop_back()
		queue_redraw()

func get_nearby_path_point(pos: Vector2, threshold: float) -> int:
	for i in range(path_points.size()):
		if path_points[i].distance_to(pos) <= threshold:
			return i
	return -1

func add_build_spot(pos: Vector2) -> void:
	_push_undo_state()
	for i in range(path_points.size() - 1):
		var p1 = path_points[i]
		var p2 = path_points[i+1]
		if _point_dist_to_segment(pos, p1, p2) < 45.0:
			push_warning("Cannot place build spot on path!")
			return
	build_spots.append(pos)
	queue_redraw()

func get_map_statistics() -> Dictionary:
	var path_len = 0.0
	for i in range(path_points.size() - 1):
		path_len += path_points[i].distance_to(path_points[i+1])
		
	var est_difficulty = "Normal"
	if build_spots.size() < 10 or path_len < 1000:
		est_difficulty = "Hard"
	elif build_spots.size() > 15 and path_len > 1500:
		est_difficulty = "Easy"
		
	return {
		"path_length": path_len,
		"build_spot_count": build_spots.size(),
		"estimated_difficulty": est_difficulty,
		"biome": selected_biome,
		"wave_count": 10
	}

func _point_dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var l2 = a.distance_squared_to(b)
	if l2 == 0: return p.distance_to(a)
	var t = max(0, min(1, (p - a).dot(b - a) / l2))
	var projection = a + t * (b - a)
	return p.distance_to(projection)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mpos = (get_global_mouse_position() - position) / current_zoom
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				_is_panning = true
				_pan_start = event.position
			else:
				_is_panning = false
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_zoom(current_zoom + 0.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			set_zoom(current_zoom - 0.1)
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			match current_mode:
				EditMode.PLACE_PATH:
					add_path_point(mpos)
				EditMode.PLACE_BUILD_SPOT:
					add_build_spot(mpos)
				EditMode.PLACE_DECORATION:
					_push_undo_state()
					decorations.append({"type": current_decoration_type, "pos": mpos, "color": Color.WHITE, "size": 3.0})
					queue_redraw()
				EditMode.ERASE:
					_push_undo_state()
					_erase_at(mpos)
					queue_redraw()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			match current_mode:
				EditMode.PLACE_PATH:
					remove_last_path_point()
				_:
					_push_undo_state()
					_erase_at(mpos)
					queue_redraw()
	elif event is InputEventMouseMotion:
		_handle_pan_input(event)
		queue_redraw()

func _handle_pan_input(event: InputEventMouseMotion) -> void:
	if _is_panning:
		var diff = event.position - _pan_start
		position += diff
		_pan_start = event.position

func _erase_at(mpos: Vector2) -> void:
	for i in range(decorations.size() - 1, -1, -1):
		if mpos.distance_to(decorations[i]["pos"]) < 20.0:
			decorations.remove_at(i)
			return
	for i in range(build_spots.size() - 1, -1, -1):
		if mpos.distance_to(build_spots[i]) < 20.0:
			build_spots.remove_at(i)
			return

func _draw() -> void:
	_draw_grid()
	_draw_path()
	_draw_build_spots()
	_draw_decorations()
	_draw_validation_overlay()
	
	var mpos = (get_global_mouse_position() - position) / current_zoom
	_draw_snap_cursor(mpos)

func _draw_grid() -> void:
	for x in range(0, 1280, GRID_CELL):
		draw_line(Vector2(x, 0), Vector2(x, 720), Color(1, 1, 1, 0.1), 1)
	for y in range(0, 720, GRID_CELL):
		draw_line(Vector2(0, y), Vector2(1280, y), Color(1, 1, 1, 0.1), 1)

func _draw_path() -> void:
	if path_points.size() > 1:
		draw_polyline(path_points, Color(0.8, 0.6, 0.2, 0.6), 24.0)
		for i in range(path_points.size() - 1):
			var dir = (path_points[i+1] - path_points[i]).normalized()
			var mid = (path_points[i] + path_points[i+1]) / 2.0
			draw_line(mid, mid - dir * 10 + dir.rotated(PI/2) * 10, Color(1, 0, 0), 2)
			draw_line(mid, mid - dir * 10 - dir.rotated(PI/2) * 10, Color(1, 0, 0), 2)
			
	for p in path_points:
		draw_circle(p, 8, Color(0.9, 0.2, 0.2))

func _draw_build_spots() -> void:
	for s in build_spots:
		draw_circle(s, 24, Color(0.2, 0.8, 0.3, 0.5))
		draw_arc(s, 24, 0, TAU, 16, Color(0.1, 0.6, 0.2), 2)

func _draw_decorations() -> void:
	for d in decorations:
		_draw_decoration(d["pos"], d.get("type", "custom"), d.get("size", 4.0))

func _draw_decoration(pos: Vector2, dec_type: String, size: float) -> void:
	match dec_type:
		"flower":
			draw_circle(pos, size * 2, Color.PINK)
			draw_circle(pos, size, Color.YELLOW)
		"tree":
			draw_circle(pos, size * 4, Color.DARK_GREEN)
			draw_rect(Rect2(pos.x - size, pos.y, size*2, size*4), Color.SADDLE_BROWN)
		"crystal":
			draw_polygon(PackedVector2Array([
				pos + Vector2(0, -size*4),
				pos + Vector2(size*2, size*2),
				pos + Vector2(-size*2, size*2)
			]), PackedColorArray([Color.CYAN, Color.BLUE, Color.CYAN]))
		"rock":
			draw_circle(pos, size * 3, Color.DARK_GRAY)
		"mushroom":
			draw_circle(pos + Vector2(0, -size*2), size*3, Color.RED)
			draw_rect(Rect2(pos.x - size, pos.y - size, size*2, size*2), Color.WHITE)
		"rune":
			draw_circle(pos, size * 2, Color.PURPLE)
		"pond":
			draw_circle(pos, size * 5, Color.AQUA)
		"torch":
			draw_circle(pos, size * 1.5, Color.ORANGE)
		_:
			draw_circle(pos, size * 3, Color.WHITE)

func _draw_snap_cursor(pos: Vector2) -> void:
	var snapped = snap_to_grid(pos)
	draw_rect(Rect2(snapped - Vector2(GRID_CELL/2, GRID_CELL/2), Vector2(GRID_CELL, GRID_CELL)), Color(1, 1, 0, 0.3), false, 2)

func _draw_validation_overlay() -> void:
	var val = _validate_current_map()
	if not val["valid"]:
		draw_string(ThemeDB.fallback_font, Vector2(10, 30), "INVALID MAP", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.RED)

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
				_push_undo_state()
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

func export_as_png(path: String) -> void:
	var viewport = get_viewport()
	var img = viewport.get_texture().get_image()
	img.save_png(path)

func _validate_current_map() -> Dictionary:
	var errors: Array[String] = []
	
	if path_points.size() < 4:
		errors.append("Path must have at least 4 points.")
	if build_spots.size() < 3:
		errors.append("Need at least 3 build spots.")
		
	return {
		"valid": errors.is_empty(),
		"errors": errors
	}
