class_name SynergyManager
extends Node

## Менеджер синергий соседства башен (Этап 7)
## Проверяет дистанцию между башнями и активирует связки синергий

signal synergy_activated(synergy_id: String, tower_a: Node2D, tower_b: Node2D)
signal synergy_deactivated(synergy_id: String)

var synergies_db: Dictionary = {}
var active_synergies: Dictionary = {} # synergy_id -> Array[Dictionary] (pairs)

func _ready() -> void:
	add_to_group("synergy_manager")
	_load_synergies_db()

func _load_synergies_db() -> void:
	if not FileAccess.file_exists("res://data/synergies.json"):
		return
	var f = FileAccess.open("res://data/synergies.json", FileAccess.READ)
	var json = JSON.new()
	if json.parse(f.get_as_text()) == OK and json.data is Dictionary:
		synergies_db = json.data.duplicate(true)

func evaluate_all_synergies(towers: Array) -> Array[Dictionary]:
	active_synergies.clear()
	var activated_list: Array[Dictionary] = []
	
	for syn_id in synergies_db:
		var syn_data = synergies_db[syn_id]
		var pair = syn_data.get("towers", [])
		if pair.size() < 2:
			continue
			
		var t1_type = pair[0]
		var t2_type = pair[1]
		var max_dist = float(syn_data.get("max_distance", 140.0))
		var mult = min(2.5, float(syn_data.get("damage_mult", 1.0))) # Safety cap against runaway mults
		
		# Find tower pairs of matching types within max_dist
		for i in range(towers.size()):
			var a = towers[i]
			if not is_instance_valid(a) or a.get("tower_type") != t1_type:
				continue
			for j in range(towers.size()):
				if i == j:
					continue
				var b = towers[j]
				if not is_instance_valid(b) or b.get("tower_type") != t2_type:
					continue
					
				var dist = a.global_position.distance_to(b.global_position)
				if dist <= max_dist:
					var item = {
						"synergy_id": syn_id,
						"name": syn_data.get("name", syn_id),
						"damage_mult": mult,
						"tower_a": a,
						"tower_b": b
					}
					activated_list.append(item)
					if not active_synergies.has(syn_id):
						active_synergies[syn_id] = []
					active_synergies[syn_id].append(item)
					synergy_activated.emit(syn_id, a, b)
					
	return activated_list

func is_synergy_active(synergy_id: String) -> bool:
	return active_synergies.has(synergy_id) and not active_synergies[synergy_id].is_empty()

func get_tower_synergy_multiplier(tower: Node2D) -> float:
	var total_mult = 1.0
	for syn_id in active_synergies:
		for item in active_synergies[syn_id]:
			if item.get("tower_a") == tower or item.get("tower_b") == tower:
				total_mult *= float(item.get("damage_mult", 1.0))
	return min(5.0, total_mult) # Max 5x multiplier safety clamp
