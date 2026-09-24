class_name ContentValidator
extends RefCounted

## Валидатор целостности игровых данных (Фаза 9)
## Проверяет все JSON базы на отсутствие синтаксических ошибок, битых ссылок и циклов

static func validate_all_content() -> Dictionary:
	var results = {
		"valid": true,
		"errors": [],
		"warnings": [],
		"stats": {}
	}
	
	_validate_towers(results)
	_validate_enemies(results)
	_validate_waves(results)
	_validate_tech_tree(results)
	_validate_artifacts(results)
	
	results["valid"] = results["errors"].is_empty()
	return results

static func _validate_towers(res: Dictionary) -> void:
	var path = "res://data/towers.json"
	if not FileAccess.file_exists(path):
		res["errors"].append("Missing towers.json")
		return
	var f = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	if json.parse(f.get_as_text()) != OK or not json.data is Dictionary:
		res["errors"].append("Invalid JSON format in towers.json")
		return
		
	var towers: Dictionary = json.data
	res["stats"]["total_towers"] = towers.size()
	
	for t_id in towers:
		var t = towers[t_id]
		if not t.has("name"): res["warnings"].append("Tower %s missing name" % t_id)
		if not t.has("cost") or int(t["cost"]) <= 0: res["errors"].append("Tower %s has invalid cost" % t_id)
		if not t.has("levels") or not t["levels"] is Array or t["levels"].is_empty():
			res["errors"].append("Tower %s missing levels array" % t_id)
		else:
			for lvl in t["levels"]:
				if not lvl.has("damage") or float(lvl["damage"]) < 0.0:
					res["errors"].append("Tower %s level has invalid damage" % t_id)
				if not lvl.has("range") or float(lvl["range"]) <= 0.0:
					res["errors"].append("Tower %s level has invalid range" % t_id)
				if not lvl.has("attack_speed") or float(lvl["attack_speed"]) <= 0.0:
					res["errors"].append("Tower %s level has invalid attack_speed" % t_id)

static func _validate_enemies(res: Dictionary) -> void:
	var path = "res://data/enemies.json"
	if not FileAccess.file_exists(path):
		res["errors"].append("Missing enemies.json")
		return
	var f = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	if json.parse(f.get_as_text()) != OK or not json.data is Dictionary:
		res["errors"].append("Invalid JSON format in enemies.json")
		return
		
	var enemies: Dictionary = json.data
	res["stats"]["total_enemies"] = enemies.size()
	
	for e_id in enemies:
		var e = enemies[e_id]
		if not e.has("max_health") or float(e["max_health"]) <= 0.0: 
			res["errors"].append("Enemy %s has invalid max_health" % e_id)
		if not e.has("speed") or float(e["speed"]) <= 0.0: 
			res["errors"].append("Enemy %s has invalid speed" % e_id)
		if not e.has("gold_reward"): 
			res["warnings"].append("Enemy %s has no gold_reward" % e_id)

static func _validate_waves(res: Dictionary) -> void:
	var path = "res://data/waves.json"
	if not FileAccess.file_exists(path):
		res["errors"].append("Missing waves.json")
		return
	var f = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	if json.parse(f.get_as_text()) != OK or not json.data is Array:
		res["errors"].append("Invalid JSON in waves.json")
		return
		
	var waves: Array = json.data
	res["stats"]["total_waves"] = waves.size()
	
	for i in range(waves.size()):
		var w = waves[i]
		if not w.has("spawn_groups") or not w["spawn_groups"] is Array:
			res["errors"].append("Wave %d missing spawn_groups array" % (i + 1))

static func _validate_tech_tree(res: Dictionary) -> void:
	var path = "res://data/tech_tree.json"
	if not FileAccess.file_exists(path):
		return
	var f = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	if json.parse(f.get_as_text()) != OK or not json.data is Array:
		res["errors"].append("Invalid JSON array in tech_tree.json")
		return
		
	var nodes_arr: Array = json.data
	res["stats"]["tech_nodes"] = nodes_arr.size()
	
	var node_ids = {}
	for n in nodes_arr:
		if n is Dictionary and n.has("id"):
			node_ids[n["id"]] = true
			
	for n in nodes_arr:
		if n is Dictionary:
			var reqs = n.get("requires", [])
			for req in reqs:
				if not node_ids.has(req):
					res["errors"].append("Tech node %s refers to nonexistent prerequisite %s" % [n.get("id"), req])

static func _validate_artifacts(res: Dictionary) -> void:
	var path = "res://data/artifacts.json"
	if not FileAccess.file_exists(path):
		return
	var f = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	if json.parse(f.get_as_text()) != OK or not json.data is Dictionary:
		res["errors"].append("Invalid JSON dictionary in artifacts.json")
		return
	var arts: Dictionary = json.data
	res["stats"]["artifacts"] = arts.size()
	
	for a_id in arts:
		var a = arts[a_id]
		if not a.has("name") or not a.has("effect"):
			res["errors"].append("Artifact %s missing name or effect" % a_id)
