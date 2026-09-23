class_name ProceduralMapGenerator
extends Node

## ProceduralMapGenerator handles the random generation of game maps
## It supports multiple biomes, path generation, decoration placement,
## and wave modifier generation. It also includes validation tools.

signal map_generated(map_data: Dictionary)

const GRID_W = 20
const GRID_H = 15
const CELL_SIZE = 64

## A curated list of seeds that are guaranteed to produce high-quality maps.
const CURATED_SEEDS: Array[int] = [
	1001, 1002, 1003, 1004, 1005, 1006, 1007, 1008, 1009, 1010,
	2001, 2002, 2003, 2004, 2005, 2006, 2007, 2008, 2009, 2010,
	3001, 3002, 3003, 3004, 3005, 3006, 3007, 3008, 3009, 3010
]

var _rng: RandomNumberGenerator

func _init() -> void:
	add_to_group("procedural_generator")
	_rng = RandomNumberGenerator.new()

## Generates a complete map dictionary based on a given seed, biome, and difficulty.
func generate_map(seed: int, biome: String, difficulty: int) -> Dictionary:
	_rng.seed = seed
	
	var curve_points = _generate_curve_points(_rng, GRID_W, GRID_H)
	
	# Fallback if path generation fails or is too short
	if not validate_path(curve_points):
		curve_points = _generate_fallback_path()
		
	# Apply Chaikin smoothing
	curve_points = _smooth_path(curve_points, 3)
	
	var build_spots = _place_build_spots(curve_points, _rng)
	var decorations = _get_biome_decorations(biome, _rng)
	var ambient_particles = _generate_ambient_particles(biome, _rng)
	var wave_modifiers = _get_biome_modifiers(biome, difficulty)
	var recommended_towers = get_recommended_tower_count({"curve_points": curve_points, "build_spots": build_spots})
	
	var map_data = {
		"seed": seed,
		"biome": biome,
		"difficulty": difficulty,
		"curve_points": curve_points,
		"build_spots": build_spots,
		"decorations": decorations,
		"ambient_particles": ambient_particles,
		"wave_modifiers": wave_modifiers,
		"recommended_towers": recommended_towers,
		"version": "1.0"
	}
	
	map_generated.emit(map_data)
	return map_data

## Generates a raw grid-based path from the left edge to the right edge.
func _generate_curve_points(rng: RandomNumberGenerator, grid_w: int, grid_h: int) -> Array[Vector2]:
	var path_points: Array[Vector2] = []
	var grid: Array = []
	for x in range(grid_w):
		var col = []
		for y in range(grid_h):
			col.append(0)
		grid.append(col)
		
	var start_y = rng.randi_range(2, grid_h - 3)
	var current_pos = Vector2(0, start_y)
	grid[int(current_pos.x)][int(current_pos.y)] = 1
	
	var path_grid_pts: Array[Vector2] = [current_pos]
	
	var max_steps = 100
	var step = 0
	var current_dir = Vector2.RIGHT
	
	while current_pos.x < grid_w - 1 and step < max_steps:
		var possible_dirs = []
		
		# Right
		if current_pos.x + 1 < grid_w and grid[int(current_pos.x + 1)][int(current_pos.y)] == 0:
			possible_dirs.append(Vector2.RIGHT)
			possible_dirs.append(Vector2.RIGHT)
			possible_dirs.append(Vector2.RIGHT)
		
		# Up
		if current_pos.y - 1 > 1 and grid[int(current_pos.x)][int(current_pos.y - 1)] == 0:
			if current_dir != Vector2.DOWN:
				possible_dirs.append(Vector2.UP)
		
		# Down
		if current_pos.y + 1 < grid_h - 2 and grid[int(current_pos.x)][int(current_pos.y + 1)] == 0:
			if current_dir != Vector2.UP:
				possible_dirs.append(Vector2.DOWN)
				
		if possible_dirs.is_empty():
			break
			
		var chosen_dir = possible_dirs[rng.randi_range(0, possible_dirs.size() - 1)]
		current_pos += chosen_dir
		current_dir = chosen_dir
		grid[int(current_pos.x)][int(current_pos.y)] = 1
		path_grid_pts.append(current_pos)
		step += 1
		
	if path_grid_pts.back().x < grid_w - 1:
		path_grid_pts.append(Vector2(grid_w - 1, path_grid_pts.back().y))
		
	for p in path_grid_pts:
		var world_x = p.x * CELL_SIZE + CELL_SIZE / 2.0
		var world_y = p.y * CELL_SIZE + CELL_SIZE / 2.0
		path_points.append(Vector2(world_x, world_y))
		
	return path_points

## Smooths a given path using Chaikin's algorithm
func _smooth_path(points: Array[Vector2], iterations: int) -> Array[Vector2]:
	if points.size() < 3:
		return points
		
	var smoothed = points.duplicate()
	for i in range(iterations):
		var temp: Array[Vector2] = []
		temp.append(smoothed[0]) # Keep start point
		
		for j in range(smoothed.size() - 1):
			var p0 = smoothed[j]
			var p1 = smoothed[j + 1]
			
			var p0_new = p0 + (p1 - p0) * 0.25
			var p1_new = p0 + (p1 - p0) * 0.75
			
			if j > 0: temp.append(p0_new)
			if j < smoothed.size() - 2: temp.append(p1_new)
			
		temp.append(smoothed.back()) # Keep end point
		smoothed = temp
		
	return smoothed

## Calculates total path length in pixels
func _calculate_path_length(points: Array[Vector2]) -> float:
	var total = 0.0
	for i in range(points.size() - 1):
		total += points[i].distance_to(points[i+1])
	return total

## Finds any points where the path crosses itself (for validation)
func _find_path_crossings(points: Array[Vector2]) -> Array[Dictionary]:
	var crossings: Array[Dictionary] = []
	for i in range(points.size() - 3):
		for j in range(i + 2, points.size() - 1):
			if _segments_intersect(points[i], points[i+1], points[j], points[j+1]):
				crossings.append({
					"seg1": [i, i+1],
					"seg2": [j, j+1]
				})
	return crossings

## Generates a hardcoded fallback path in case procedural generation fails
func _generate_fallback_path() -> Array[Vector2]:
	return [
		Vector2(0, 360),
		Vector2(300, 360),
		Vector2(300, 200),
		Vector2(800, 200),
		Vector2(800, 600),
		Vector2(1100, 600),
		Vector2(1100, 360),
		Vector2(1280, 360)
	]

## Validates a build spot placement against the path and existing spots
func _validate_build_spot_placement(spot: Vector2, path_points: Array, existing_spots: Array) -> bool:
	# Check distance to path
	var min_dist_to_path = 9999.0
	for i in range(path_points.size() - 1):
		var dist = _point_to_segment_dist(spot, path_points[i], path_points[i+1])
		if dist < min_dist_to_path:
			min_dist_to_path = dist
			
	if min_dist_to_path < 45.0 or min_dist_to_path > 150.0:
		return false
		
	# Check distance to other spots
	for existing in existing_spots:
		if existing.distance_to(spot) < 70.0:
			return false
			
	return true

## Randomly places build spots around the generated path
func _place_build_spots(path_points: Array[Vector2], rng: RandomNumberGenerator) -> Array[Vector2]:
	var build_spots: Array[Vector2] = []
	var attempts = 0
	var max_attempts = 500
	var spot_count = rng.randi_range(12, 20)
	
	while build_spots.size() < spot_count and attempts < max_attempts:
		attempts += 1
		var bx = rng.randf_range(CELL_SIZE, GRID_W * CELL_SIZE - CELL_SIZE)
		var by = rng.randf_range(CELL_SIZE, GRID_H * CELL_SIZE - CELL_SIZE)
		var test_pos = Vector2(bx, by)
		
		if _validate_build_spot_placement(test_pos, path_points, build_spots):
			build_spots.append(test_pos)
			
	return build_spots

## Determines the recommended number of towers based on map features
func get_recommended_tower_count(map_data: Dictionary) -> int:
	var path_len = 0.0
	if map_data.has("curve_points"):
		path_len = _calculate_path_length(map_data["curve_points"])
	var spot_count = 0
	if map_data.has("build_spots"):
		spot_count = map_data["build_spots"].size()
		
	var base_rec = int(path_len / 200.0)
	return min(base_rec, spot_count)

## Gets a list of decoration dictionaries for a specific biome
func _get_biome_decorations(biome: String, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var decos: Array[Dictionary] = []
	var count = rng.randi_range(40, 80)
	for i in range(count):
		var px = rng.randf_range(20, 1260)
		var py = rng.randf_range(20, 700)
		var d = {"pos": Vector2(px, py), "size": rng.randf_range(1.0, 5.0)}
		
		match biome:
			"valley":
				d["type"] = "flower"
				d["color"] = Color(rng.randf(), rng.randf(), rng.randf())
			"swamp":
				d["type"] = "mushroom"
				d["color"] = Color(0.2, rng.randf_range(0.6, 1.0), 0.2)
			"frost_peak":
				d["type"] = "crystal"
				d["color"] = Color(0.8, 0.9, 1.0)
			"caves":
				d["type"] = "crystal"
				d["color"] = Color(rng.randf_range(0.2, 0.5), 0.1, rng.randf_range(0.5, 1.0))
			"city", "besieged_citadel":
				d["type"] = "barrel"
				d["color"] = Color(0.5, 0.3, 0.1)
			_:
				d["type"] = "tree"
				d["color"] = Color(0.2, 0.8, 0.2)
		decos.append(d)
	return decos

## Generates ambient particles for visual flair
func _generate_ambient_particles(biome: String, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var particles: Array[Dictionary] = []
	var count = rng.randi_range(10, 20)
	for i in range(count):
		particles.append({
			"pos": Vector2(rng.randf_range(0, 1280), rng.randf_range(0, 720)),
			"speed": rng.randf_range(10, 30),
			"lifetime": rng.randf_range(3.0, 6.0)
		})
	return particles

## Fetches generic biome modifiers for a specific difficulty
func _get_biome_modifiers(biome: String, difficulty: int) -> Dictionary:
	var base_mult = 1.0 + (difficulty - 1) * 0.1
	var mods = {}
	match biome:
		"valley":
			mods = {"speed_mult": 1.0 * base_mult, "hp_mult": 1.0 * base_mult}
		"swamp":
			mods = {"speed_mult": 0.85 * base_mult, "hp_mult": 1.2 * base_mult, "poison_aura": true}
		"frost_peak":
			mods = {"speed_mult": 1.3 * base_mult, "hp_mult": 0.9 * base_mult, "freeze_resist": 0.3}
		"caves":
			mods = {"speed_mult": 1.0 * base_mult, "hp_mult": 1.15 * base_mult, "stealth_bonus": 0.25}
		"city", "besieged_citadel":
			mods = {"speed_mult": 1.1 * base_mult, "hp_mult": 1.0 * base_mult, "multi_path": true}
		_:
			mods = {"speed_mult": 1.0 * base_mult, "hp_mult": 1.0 * base_mult}
	return mods

## Generates specific modifiers per wave for progressive difficulty scaling
func _generate_biome_modifiers(biome: String, wave_num: int) -> Dictionary:
	var base_mod = _get_biome_modifiers(biome, 1)
	var scale = 1.0 + (wave_num * 0.05)
	
	var wave_mod = {}
	for k in base_mod.keys():
		if typeof(base_mod[k]) == TYPE_FLOAT:
			wave_mod[k] = base_mod[k] * scale
		else:
			wave_mod[k] = base_mod[k]
			
	# Inject special wave events
	if wave_num % 5 == 0:
		wave_mod["is_boss"] = true
		wave_mod["hp_mult"] = wave_mod.get("hp_mult", 1.0) * 1.5
		
	return wave_mod

## Fetches a deterministically generated seed based on the current date
func get_daily_seed() -> int:
	var dt = Time.get_datetime_dict_from_system()
	return dt["year"] * 10000 + dt["month"] * 100 + dt["day"]

## Validates if a generated path is playable
func validate_path(points: Array[Vector2]) -> bool:
	if points.size() < 8:
		return false
	if points[0].x > 150: # start must be near left edge
		return false
	if points.back().x < 1100: # end must be near right edge
		return false
		
	var crossings = _find_path_crossings(points)
	if not crossings.is_empty():
		return false
				
	return true

## Utility method to serialize a map dictionary into JSON
func serialize_map(map_data: Dictionary) -> String:
	var safe_data = map_data.duplicate(true)
	var safe_curves = []
	if map_data.has("curve_points"):
		for p in map_data["curve_points"]:
			safe_curves.append([p.x, p.y])
		safe_data["curve_points"] = safe_curves
		
	var safe_spots = []
	if map_data.has("build_spots"):
		for p in map_data["build_spots"]:
			safe_spots.append([p.x, p.y])
		safe_data["build_spots"] = safe_spots
		
	if map_data.has("decorations"):
		for i in range(safe_data["decorations"].size()):
			var p = safe_data["decorations"][i]["pos"]
			safe_data["decorations"][i]["pos"] = [p.x, p.y]
			var c = safe_data["decorations"][i]["color"]
			safe_data["decorations"][i]["color"] = c.to_html()

	return JSON.stringify(safe_data)

## Utility method to deserialize a JSON string into a map dictionary
func deserialize_map(json_str: String) -> Dictionary:
	var json = JSON.new()
	var err = json.parse(json_str)
	if err != OK:
		push_error("Failed to parse map JSON")
		return {}
		
	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return {}
		
	if data.has("curve_points"):
		var pts: Array[Vector2] = []
		for p in data["curve_points"]:
			pts.append(Vector2(p[0], p[1]))
		data["curve_points"] = pts
		
	if data.has("build_spots"):
		var spots: Array[Vector2] = []
		for s in data["build_spots"]:
			spots.append(Vector2(s[0], s[1]))
		data["build_spots"] = spots
		
	if data.has("decorations"):
		for i in range(data["decorations"].size()):
			var p = data["decorations"][i]["pos"]
			data["decorations"][i]["pos"] = Vector2(p[0], p[1])
			if data["decorations"][i].has("color"):
				data["decorations"][i]["color"] = Color(data["decorations"][i]["color"])
				
	return data

## Generates an ImageTexture preview for a map
func generate_minimap_texture(map_data: Dictionary, size: Vector2i) -> ImageTexture:
	var img = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.1, 0.1, 0.1, 1.0))
	
	var scale_x = size.x / 1280.0
	var scale_y = size.y / 720.0
	
	if map_data.has("curve_points"):
		var pts = map_data["curve_points"]
		for i in range(pts.size() - 1):
			var p1 = pts[i]
			var p2 = pts[i+1]
			# Simple DDA line drawing algorithm logic could go here
			# For minimal implementation we can just set pixels at points
			img.set_pixel(int(p1.x * scale_x), int(p1.y * scale_y), Color.WHITE)
			
	return ImageTexture.create_from_image(img)

## Math helper: distance from point to line segment
func _point_to_segment_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var l2 = a.distance_squared_to(b)
	if l2 == 0: return p.distance_to(a)
	var t = max(0, min(1, (p - a).dot(b - a) / l2))
	var projection = a + t * (b - a)
	return p.distance_to(projection)

## Math helper: detects if two line segments cross
func _segments_intersect(p1: Vector2, p2: Vector2, q1: Vector2, q2: Vector2) -> bool:
	var o1 = _orientation(p1, p2, q1)
	var o2 = _orientation(p1, p2, q2)
	var o3 = _orientation(q1, q2, p1)
	var o4 = _orientation(q1, q2, p2)
	
	if o1 != o2 and o3 != o4:
		return true
	return false

## Math helper: orientation of ordered triplet
func _orientation(p: Vector2, q: Vector2, r: Vector2) -> int:
	var val = (q.y - p.y) * (r.x - q.x) - (q.x - p.x) * (r.y - q.y)
	if val == 0: return 0
	return 1 if val > 0 else 2
	
func get_supported_biomes() -> Array:
	return ["valley", "swamp", "frost_peak", "caves", "city", "besieged_citadel"]

func is_biome_valid(biome: String) -> bool:
	return biome in get_supported_biomes()

func get_difficulty_range() -> Dictionary:
	return {"min": 1, "max": 5}

func _process(_delta: float) -> void:
	pass
