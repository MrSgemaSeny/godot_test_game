class_name WaveEditor
extends Node

signal wave_added(index: int)
signal wave_removed(index: int)
signal waves_saved(filename: String)

var waves: Array[Dictionary] = []
var current_wave_index: int = -1

const ENEMY_THREAT_SCORES: Dictionary = {
	"grunt": 1.0,
	"fast": 1.5,
	"tank": 3.0,
	"swarmer": 0.5,
	"ranged": 2.0,
	"armored": 2.5,
	"stealth": 2.0,
	"healer": 3.5,
	"flyer": 2.0,
	"boss": 25.0,
	"boss_orc": 30.0,
	"boss_spider": 28.0,
	"boss_golem": 40.0,
	"boss_dragon": 50.0,
	"air": 2.0,
	"mage": 4.0,
	"summoner": 5.0,
	"kamikaze": 2.5,
	"elite": 8.0,
	"mimic": 4.5
}

func _init() -> void:
	add_to_group("wave_editor")

func add_wave() -> Dictionary:
	var new_wave = {
		"wave_event": "none",
		"spawn_groups": []
	}
	waves.append(new_wave)
	current_wave_index = waves.size() - 1
	wave_added.emit(current_wave_index)
	return new_wave

func generate_balanced_wave(wave_num: int, difficulty: float) -> Dictionary:
	var w = add_wave()
	var budget = wave_num * 10.0 * difficulty
	
	var is_boss_wave = (wave_num % 10 == 0)
	if is_boss_wave:
		w["wave_event"] = "boss_wave"
		budget *= 1.5
		
		var boss_type = "boss_orc"
		if wave_num >= 40: boss_type = "boss_dragon"
		elif wave_num >= 30: boss_type = "boss_golem"
		elif wave_num >= 20: boss_type = "boss_spider"
		
		add_enemy_to_wave(current_wave_index, boss_type, 1, 5.0)
		budget -= ENEMY_THREAT_SCORES.get(boss_type, 25.0)
		
	var available_types = ["grunt", "fast"]
	if wave_num > 3: available_types.append("tank")
	if wave_num > 5: available_types.append("swarmer")
	if wave_num > 8: available_types.append("stealth")
	if wave_num > 12: available_types.append("flyer")
	
	while budget > 2.0:
		var type = available_types[randi() % available_types.size()]
		var cost = ENEMY_THREAT_SCORES.get(type, 1.0)
		var max_count = int(budget / cost)
		if max_count <= 0: break
		
		var count = clamp(randi() % max_count + 1, 1, 20)
		add_enemy_to_wave(current_wave_index, type, count, randf_range(0.5, 2.0))
		budget -= count * cost
		
	return w

func generate_boss_wave(boss_type: String, wave_num: int) -> Dictionary:
	var w = add_wave()
	w["wave_event"] = "boss_wave"
	add_enemy_to_wave(current_wave_index, boss_type, 1, 2.0)
	
	# Adds some minion support
	add_enemy_to_wave(current_wave_index, "swarmer", 10 + wave_num, 0.5)
	add_enemy_to_wave(current_wave_index, "healer", int(wave_num / 5), 4.0)
	
	return w

func remove_wave(index: int) -> void:
	if index >= 0 and index < waves.size():
		waves.remove_at(index)
		if current_wave_index >= waves.size():
			current_wave_index = waves.size() - 1
		wave_removed.emit(index)

func add_enemy_to_wave(wave_idx: int, enemy_type: String, count: int, interval: float) -> void:
	if wave_idx >= 0 and wave_idx < waves.size():
		var w = waves[wave_idx]
		if not w.has("spawn_groups"):
			w["spawn_groups"] = []
		w["spawn_groups"].append({
			"enemy_type": enemy_type,
			"count": count,
			"interval": interval,
			"delay": 0.0
		})

func remove_enemy_from_wave(wave_idx: int, enemy_idx: int) -> void:
	if wave_idx >= 0 and wave_idx < waves.size():
		var w = waves[wave_idx]
		if w.has("spawn_groups"):
			var groups = w["spawn_groups"]
			if enemy_idx >= 0 and enemy_idx < groups.size():
				groups.remove_at(enemy_idx)

func set_wave_event(wave_idx: int, event: String) -> void:
	if wave_idx >= 0 and wave_idx < waves.size():
		waves[wave_idx]["wave_event"] = event

func move_wave(from_idx: int, to_idx: int) -> void:
	if from_idx >= 0 and from_idx < waves.size() and to_idx >= 0 and to_idx < waves.size():
		var w = waves.pop_at(from_idx)
		waves.insert(to_idx, w)
		if current_wave_index == from_idx:
			current_wave_index = to_idx
		elif current_wave_index > from_idx and current_wave_index <= to_idx:
			current_wave_index -= 1
		elif current_wave_index < from_idx and current_wave_index >= to_idx:
			current_wave_index += 1

func duplicate_wave(idx: int) -> void:
	if idx >= 0 and idx < waves.size():
		var w_copy = waves[idx].duplicate(true)
		waves.insert(idx + 1, w_copy)
		wave_added.emit(idx + 1)

func clone_and_scale_wave(idx: int, scale: float) -> Dictionary:
	duplicate_wave(idx)
	var new_idx = idx + 1
	var w = waves[new_idx]
	for g in w.get("spawn_groups", []):
		g["count"] = max(1, int(round(g.get("count", 1) * scale)))
	return w

func save_waves(filename: String) -> bool:
	if not DirAccess.dir_exists_absolute("user://maps"):
		DirAccess.make_dir_absolute("user://maps")
	
	var exported = export_to_game_format()
	var json_str = JSON.stringify(exported, "\t")
	
	var file = FileAccess.open("user://maps/" + filename + "_waves.json", FileAccess.WRITE)
	if file:
		file.store_string(json_str)
		waves_saved.emit(filename)
		return true
	return false

func load_waves(filename: String) -> bool:
	var path = "user://maps/" + filename + "_waves.json"
	if not FileAccess.file_exists(path):
		return false
		
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			var data = json.data
			if data is Array:
				import_from_game_format(data)
				return true
	return false

func export_to_game_format() -> Array:
	var exported = []
	for w in waves:
		var w_export = {
			"wave_event": w.get("wave_event", "none"),
			"spawn_groups": []
		}
		var groups = w.get("spawn_groups", [])
		for g in groups:
			w_export["spawn_groups"].append({
				"enemy_type": g.get("enemy_type", "grunt"),
				"count": g.get("count", 1),
				"interval": g.get("interval", 1.0),
				"delay": g.get("delay", 0.0)
			})
		exported.append(w_export)
	return exported

func import_from_game_format(data: Array) -> void:
	waves.clear()
	for d in data:
		if typeof(d) == TYPE_DICTIONARY:
			var new_wave = {
				"wave_event": d.get("wave_event", "none"),
				"spawn_groups": []
			}
			var groups = d.get("spawn_groups", [])
			for g in groups:
				if typeof(g) == TYPE_DICTIONARY:
					new_wave["spawn_groups"].append({
						"enemy_type": g.get("enemy_type", "grunt"),
						"count": int(g.get("count", 1)),
						"interval": float(g.get("interval", 1.0)),
						"delay": float(g.get("delay", 0.0))
					})
			waves.append(new_wave)
	if waves.size() > 0:
		current_wave_index = 0

func validate_waves() -> Dictionary:
	var valid = true
	var warnings: Array[String] = []
	var errors: Array[String] = []
	
	if waves.is_empty():
		valid = false
		errors.append("No waves defined.")
		
	for i in range(waves.size()):
		var w = waves[i]
		var groups = w.get("spawn_groups", [])
		if groups.is_empty():
			warnings.append("Wave " + str(i + 1) + " has no enemies.")
			
		var invalid_types = _validate_enemy_types(w)
		for it in invalid_types:
			errors.append("Wave " + str(i+1) + " uses unknown enemy type: " + it)
			valid = false
			
		for j in range(groups.size()):
			var g = groups[j]
			if g.get("count", 0) <= 0:
				errors.append("Wave " + str(i + 1) + " group " + str(j + 1) + " has zero or negative count.")
				valid = false
			if g.get("interval", 0) <= 0.0:
				warnings.append("Wave " + str(i + 1) + " group " + str(j + 1) + " has zero or negative interval.")
	
	return {
		"valid": valid,
		"warnings": warnings,
		"errors": errors
	}

func _validate_enemy_types(wave_data: Dictionary) -> Array[String]:
	var invalid: Array[String] = []
	var groups = wave_data.get("spawn_groups", [])
	for g in groups:
		var etype = g.get("enemy_type", "")
		if not ENEMY_THREAT_SCORES.has(etype):
			invalid.append(etype)
	return invalid

func get_enemy_threat_score(enemy_type: String) -> float:
	return ENEMY_THREAT_SCORES.get(enemy_type, 1.0)

func get_wave_summary(idx: int) -> String:
	if idx < 0 or idx >= waves.size():
		return "Invalid wave"
		
	var w = waves[idx]
	var total_enemies = 0
	var types = {}
	
	var groups = w.get("spawn_groups", [])
	for g in groups:
		var c = g.get("count", 1)
		total_enemies += c
		var t = g.get("enemy_type", "grunt")
		if types.has(t):
			types[t] += c
		else:
			types[t] = c
			
	var type_str = ""
	for t in types.keys():
		type_str += t + ":" + str(types[t]) + " "
		
	var event = w.get("wave_event", "none")
	var event_str = ""
	if event != "none":
		event_str = "[Event: " + event + "] "
		
	return "Wave " + str(idx + 1) + " " + event_str + "- " + str(total_enemies) + " enemies (" + type_str + ")"

func preview_wave_as_string(idx: int) -> String:
	var summary = get_wave_composition_summary(idx)
	if summary.is_empty():
		return "No data."
		
	var txt = "--- WAVE " + str(idx+1) + " ---\n"
	txt += "Threat Score: " + str(summary["threat_score"]) + "\n"
	txt += "Total Enemies: " + str(summary["total_enemies"]) + "\n"
	txt += "Duration: " + str(summary["estimated_duration"]) + "s\n"
	txt += "Composition:\n"
	for k in summary["by_type"].keys():
		txt += "  - " + k + " x" + str(summary["by_type"][k]) + "\n"
	return txt

func get_wave_composition_summary(idx: int) -> Dictionary:
	if idx < 0 or idx >= waves.size(): return {}
	
	var w = waves[idx]
	var total_e = 0
	var by_type = {}
	var threat = 0.0
	var duration = 0.0
	
	for g in w.get("spawn_groups", []):
		var count = g.get("count", 1)
		var etype = g.get("enemy_type", "grunt")
		total_e += count
		by_type[etype] = by_type.get(etype, 0) + count
		threat += count * get_enemy_threat_score(etype)
		
		var g_time = g.get("delay", 0.0) + (count * g.get("interval", 1.0))
		if g_time > duration:
			duration = g_time
			
	return {
		"total_enemies": total_e,
		"by_type": by_type,
		"threat_score": threat,
		"estimated_duration": duration
	}

func simulate_wave_difficulty(idx: int) -> float:
	var summary = get_wave_composition_summary(idx)
	if summary.is_empty(): return 0.0
	return summary["threat_score"]

func _calculate_wave_ttk(wave_data: Dictionary, tower_dps: float) -> float:
	var total_hp = 0.0
	for g in wave_data.get("spawn_groups", []):
		var etype = g.get("enemy_type", "grunt")
		var count = g.get("count", 1)
		# Rough HP estimate based on threat
		var hp = ENEMY_THREAT_SCORES.get(etype, 1.0) * 100.0
		total_hp += (hp * count)
		
	if tower_dps <= 0.0: return 9999.0
	return total_hp / tower_dps

func apply_difficulty_scale(scale: float) -> void:
	for w in waves:
		var groups = w.get("spawn_groups", [])
		for g in groups:
			g["count"] = max(1, int(round(g.get("count", 1) * scale)))

func apply_biome_modifier(biome: String) -> void:
	var scale = 1.0
	match biome:
		"swamp": scale = 1.2
		"frost_peak": scale = 1.3
		"caves": scale = 1.1
		"city": scale = 1.5
	apply_difficulty_scale(scale)

func rebalance_all_waves(target_difficulty_curve: Array[float]) -> void:
	for i in range(min(waves.size(), target_difficulty_curve.size())):
		var target_diff = target_difficulty_curve[i]
		var current_diff = simulate_wave_difficulty(i)
		if current_diff > 0:
			var scale = target_diff / current_diff
			var w = waves[i]
			for g in w.get("spawn_groups", []):
				g["count"] = max(1, int(round(g.get("count", 1) * scale)))

func get_wave_duration(idx: int) -> float:
	var s = get_wave_composition_summary(idx)
	return s.get("estimated_duration", 0.0)
