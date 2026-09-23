class_name InteractiveEnvironmentSystem
extends Node2D

## Handles interactive environment hazards and mechanics on the battlefield.
## Includes water/flooding, lava/geysers, ice/freezing, foliage/wildfires, and crystal resonance.
## Implements a complex grid-based state machine for cellular automata like wildfire spread.

signal environment_triggered(type: String, pos: Vector2)
signal hazard_cleared(pos: Vector2)
signal hazard_damage_dealt(target: Node2D, amount: float, type: String)
signal terrain_state_changed(grid_pos: Vector2i, new_state: String)
signal crystal_fully_charged(pos: Vector2)
signal bridge_state_toggled(pos: Vector2, is_open: bool)

var active_hazards: Array[Dictionary] = []
var interactive_objects: Array[Dictionary] = []
var terrain_grid: Dictionary = {}
var cell_size: float = 64.0
var tick_timer: float = 0.0

func _init() -> void:
	add_to_group("interactive_environment")

func _ready() -> void:
	set_process(true)

func _process(delta: float) -> void:
	tick_timer += delta
	_process_hazards(delta)
	_process_objects(delta)
	
	# Slower tick for cellular automata (fire spread, water flow)
	if tick_timer > 0.5:
		_process_cellular_automata()
		tick_timer = 0.0

## Registers a tile or zone as a specific environmental type.
func register_terrain_cell(grid_pos: Vector2i, terrain_type: String) -> void:
	terrain_grid[grid_pos] = {
		"type": terrain_type,
		"state": "normal",
		"hp": 100.0,
		"combustibility": 0.0,
		"temperature": 25.0
	}
	match terrain_type:
		"foliage": terrain_grid[grid_pos]["combustibility"] = 0.8
		"water": terrain_grid[grid_pos]["temperature"] = 15.0
		"lava": terrain_grid[grid_pos]["temperature"] = 500.0
		"ice": terrain_grid[grid_pos]["temperature"] = -10.0

## Spawns a hazard dynamically during gameplay (e.g. wildfire, flood).
func spawn_hazard(hazard_type: String, world_pos: Vector2, duration: float, radius: float = 100.0) -> void:
	var h_id = hazard_type + "_" + str(Time.get_ticks_usec())
	active_hazards.append({
		"id": h_id,
		"type": hazard_type,
		"pos": world_pos,
		"radius": radius,
		"duration": duration,
		"time_active": 0.0,
		"intensity": 1.0,
		"tags": _get_tags_for_hazard(hazard_type)
	})
	environment_triggered.emit(hazard_type, world_pos)

func _get_tags_for_hazard(h_type: String) -> Array[String]:
	match h_type:
		"wildfire", "lava_pool": return ["fire", "damage"]
		"flood", "whirlpool": return ["water", "kinetic"]
		"blizzard": return ["ice", "slow"]
		"crystal_resonance": return ["magic", "burst"]
	return []

## Processes all active hazards and applies area of effect logic to entities.
func _process_hazards(delta: float) -> void:
	for i in range(active_hazards.size() - 1, -1, -1):
		var h = active_hazards[i]
		h["time_active"] += delta
		
		# Apply effects based on hazard type
		if h["type"] == "wildfire":
			_apply_aoe_damage(h["pos"], h["radius"], 15.0 * delta, "fire")
		elif h["type"] == "lava_pool":
			_apply_aoe_damage(h["pos"], h["radius"], 40.0 * delta, "fire")
		elif h["type"] == "flood":
			_apply_water_current(h["pos"], h["radius"], Vector2(1, 0) * 50.0 * delta)
		elif h["type"] == "blizzard":
			_apply_freeze_effect(h["pos"], h["radius"], 0.2 * delta)
		elif h["type"] == "crystal_resonance":
			_apply_aoe_damage(h["pos"], h["radius"], 100.0 * delta * h["intensity"], "magic")
		elif h["type"] == "poison_gas":
			_apply_aoe_damage(h["pos"], h["radius"], 10.0 * delta, "poison")
			
		if h["duration"] > 0 and h["time_active"] >= h["duration"]:
			hazard_cleared.emit(h["pos"])
			active_hazards.remove_at(i)

## Process interactive objects like levers, bridges, or geysers.
func _process_objects(delta: float) -> void:
	for obj in interactive_objects:
		if obj["type"] == "geyser":
			obj["timer"] -= delta
			if obj["timer"] <= 0:
				obj["timer"] = obj["cooldown"]
				_erupt_geyser(obj)
		elif obj["type"] == "resonance_crystal":
			if obj["charge"] > 0:
				obj["charge"] -= delta * 5.0 # Slow discharge
				if obj["charge"] >= 100.0:
					_trigger_crystal_pulse(obj)

## Grid cellular automata step for fire spread, freezing, melting, etc.
func _process_cellular_automata() -> void:
	var updates = {}
	for grid_pos in terrain_grid.keys():
		var cell = terrain_grid[grid_pos]
		
		if cell["type"] == "foliage" and cell["state"] == "burning":
			# Spread fire to neighbors
			var neighbors = _get_neighbors(grid_pos)
			for n_pos in neighbors:
				if terrain_grid.has(n_pos):
					var n_cell = terrain_grid[n_pos]
					if n_cell["type"] == "foliage" and n_cell["state"] == "normal":
						if randf() < n_cell["combustibility"] * 0.2:
							updates[n_pos] = "burning"
							
			# Cell burns out
			cell["hp"] -= 15.0
			if cell["hp"] <= 0:
				updates[grid_pos] = "ash"
				
		elif cell["type"] == "water" and cell["temperature"] < 0:
			updates[grid_pos] = "ice"
		elif cell["type"] == "ice" and cell["temperature"] > 5:
			updates[grid_pos] = "water"

	# Apply updates
	for g_pos in updates.keys():
		terrain_grid[g_pos]["state"] = updates[g_pos]
		terrain_state_changed.emit(g_pos, updates[g_pos])
		
		if updates[g_pos] == "burning":
			var w_pos = Vector2(g_pos.x * cell_size + cell_size/2, g_pos.y * cell_size + cell_size/2)
			spawn_hazard("wildfire", w_pos, 8.0, cell_size * 1.5)

func _get_neighbors(pos: Vector2i) -> Array[Vector2i]:
	return [
		pos + Vector2i(1, 0),
		pos + Vector2i(-1, 0),
		pos + Vector2i(0, 1),
		pos + Vector2i(0, -1)
	]

## Core logic to apply damage to enemies within a radius.
func _apply_aoe_damage(pos: Vector2, radius: float, damage: float, dmg_type: String) -> void:
	if not is_instance_valid(get_tree()): return
	var enemies = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if is_instance_valid(e) and e.has_method("take_damage"):
			if e.global_position.distance_to(pos) <= radius:
				e.take_damage(damage, dmg_type)
				hazard_damage_dealt.emit(e, damage, dmg_type)

## Flooding effect: pushes enemies.
func _apply_water_current(pos: Vector2, radius: float, force: Vector2) -> void:
	if not is_instance_valid(get_tree()): return
	var enemies = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if is_instance_valid(e) and e.global_position.distance_to(pos) <= radius:
			if e.get("is_flying") == true: continue
			
			if e.has_method("apply_force"):
				e.apply_force(force)
			else:
				e.global_position += force

## Ice effect: slows movement and makes enemies slip.
func _apply_freeze_effect(pos: Vector2, radius: float, freeze_amount: float) -> void:
	if not is_instance_valid(get_tree()): return
	var enemies = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if is_instance_valid(e) and e.global_position.distance_to(pos) <= radius:
			if e.has_method("add_freeze"):
				e.add_freeze(freeze_amount)

## Register an interactive object.
func register_object(obj_type: String, pos: Vector2, config: Dictionary) -> void:
	var obj = {
		"id": obj_type + "_" + str(Time.get_ticks_usec()),
		"type": obj_type,
		"pos": pos,
		"state": "idle"
	}
	for k in config.keys():
		obj[k] = config[k]
		
	if obj_type == "geyser":
		obj["timer"] = obj.get("cooldown", 15.0)
	elif obj_type == "resonance_crystal":
		obj["charge"] = 0.0
		
	interactive_objects.append(obj)

func interact_with_object(pos: Vector2) -> bool:
	for obj in interactive_objects:
		if obj["pos"].distance_to(pos) < 50.0:
			if obj["type"] == "lever":
				_toggle_lever(obj)
				return true
	return false

func _toggle_lever(obj: Dictionary) -> void:
	obj["state"] = "active" if obj["state"] == "idle" else "idle"
	var target_id = obj.get("target_id", "")
	for other in interactive_objects:
		if other.get("id", "") == target_id and other["type"] == "bridge":
			var is_open = (obj["state"] == "active")
			other["state"] = "lowered" if is_open else "raised"
			environment_triggered.emit("bridge_toggled", other["pos"])
			bridge_state_toggled.emit(other["pos"], is_open)

func _erupt_geyser(obj: Dictionary) -> void:
	environment_triggered.emit("geyser_eruption", obj["pos"])
	_apply_aoe_damage(obj["pos"], 150.0, 100.0, "fire")
	
	if not is_instance_valid(get_tree()): return
	var enemies = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if is_instance_valid(e) and e.global_position.distance_to(obj["pos"]) <= 150.0:
			if e.has_method("knockback"):
				var dir = (e.global_position - obj["pos"]).normalized()
				e.knockback(dir, 300.0)

## Charges a crystal if hit by magic
func charge_crystal(pos: Vector2, amount: float) -> void:
	for obj in interactive_objects:
		if obj["type"] == "resonance_crystal" and obj["pos"].distance_to(pos) < 60.0:
			obj["charge"] = clamp(obj["charge"] + amount, 0.0, 100.0)
			if obj["charge"] >= 100.0:
				crystal_fully_charged.emit(obj["pos"])

func _trigger_crystal_pulse(obj: Dictionary) -> void:
	obj["charge"] = 0.0
	spawn_hazard("crystal_resonance", obj["pos"], 2.0, 300.0)
	environment_triggered.emit("crystal_pulse", obj["pos"])

## Applies macro weather modifications to hazards.
func apply_weather_modifications(weather: String) -> void:
	if weather == "rain":
		for h in active_hazards:
			if h["type"] == "wildfire":
				h["time_active"] += 5.0 # Accelerated decay
			elif h["type"] == "flood":
				h["radius"] *= 1.2 # Flood expands
	elif weather == "snow":
		for h in active_hazards:
			if h["type"] == "lava_pool":
				h["intensity"] = 0.5
	elif weather == "drought":
		for h in active_hazards:
			if h["type"] == "wildfire":
				h["intensity"] = 1.5
				h["radius"] *= 1.5

## Clears everything for a scene reload or map reset.
func clear_all() -> void:
	active_hazards.clear()
	interactive_objects.clear()
	terrain_grid.clear()
	tick_timer = 0.0

## Expose state for saving
func save_state() -> Dictionary:
	return {
		"terrain_grid": terrain_grid.duplicate(true),
		"interactive_objects": interactive_objects.duplicate(true),
		"active_hazards": active_hazards.duplicate(true)
	}

func load_state(data: Dictionary) -> void:
	if data.has("terrain_grid"): terrain_grid = data["terrain_grid"].duplicate(true)
	if data.has("interactive_objects"): interactive_objects = data["interactive_objects"].duplicate(true)
	if data.has("active_hazards"): active_hazards = data["active_hazards"].duplicate(true)
