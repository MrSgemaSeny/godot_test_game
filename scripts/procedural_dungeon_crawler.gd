class_name ProceduralDungeonCrawler
extends Node

## Процедурный генератор и менеджер подземелий (Фаза 8)
## Реализует структуру узлового пути (Node Map) с ветвлениями, этажами, событиями и боссами

signal dungeon_generated(seed_value: int, total_floors: int)
signal floor_reached(floor_num: int, node_data: Dictionary)
signal node_completed(node_data: Dictionary, reward: Dictionary)
signal dungeon_completed(summary: Dictionary)
signal dungeon_failed(floor_reached: int)

enum NodeType {
	BATTLE,
	ELITE_BATTLE,
	REST_SHRINE,
	TREASURE_VAULT,
	MYSTERY_EVENT,
	MERCHANT_OUTPOST,
	BOSS_LAIR
}

const BIOME_LIST = ["valley", "swamp", "caves", "frost_peak", "besieged_citadel"]

var dungeon_seed: int = 1337
var current_floor: int = 0
var total_floors: int = 15
var current_node_id: String = ""
var dungeon_graph: Dictionary = {} # floor_idx -> Array of node dicts
var path_history: Array[String] = []
var active_curses: Array[String] = []
var collected_relics: Array[String] = []
var dungeon_gold: int = 150
var dungeon_health: int = 5

func _ready() -> void:
	add_to_group("dungeon_crawler")

func generate_dungeon(seed_val: int = -1, floors: int = 15) -> Dictionary:
	if seed_val == -1:
		dungeon_seed = int(Time.get_unix_time_from_system())
	else:
		dungeon_seed = seed_val
		
	total_floors = floors
	current_floor = 0
	current_node_id = ""
	path_history.clear()
	active_curses.clear()
	collected_relics.clear()
	dungeon_gold = 150
	dungeon_health = 5
	dungeon_graph.clear()
	
	var rng = RandomNumberGenerator.new()
	rng.seed = dungeon_seed
	
	for f in range(total_floors):
		dungeon_graph[f] = _generate_floor_nodes(f, rng)
		
	_connect_floor_branches(rng)
	dungeon_generated.emit(dungeon_seed, total_floors)
	return dungeon_graph

func _generate_floor_nodes(floor_idx: int, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var nodes: Array[Dictionary] = []
	
	# Floor 0: Always starting battle
	if floor_idx == 0:
		nodes.append(_build_node_dict(floor_idx, 0, NodeType.BATTLE, "Начальный заслон", "valley"))
		return nodes
		
	# Final floor: Always boss lair
	if floor_idx == total_floors - 1:
		nodes.append(_build_node_dict(floor_idx, 0, NodeType.BOSS_LAIR, "Врата Апокалипсиса", "besieged_citadel"))
		return nodes
		
	# Mid-dungeon mini-boss at floor 7
	if floor_idx == 7:
		nodes.append(_build_node_dict(floor_idx, 0, NodeType.ELITE_BATTLE, "Цитадель Хранителя", "caves"))
		nodes.append(_build_node_dict(floor_idx, 1, NodeType.TREASURE_VAULT, "Скрытая сокровищница", "caves"))
		return nodes
		
	# Normal floor: 2 to 3 branches
	var branch_count = rng.randi_range(2, 3)
	for b in range(branch_count):
		var n_type = _pick_random_node_type(floor_idx, rng)
		var biome = BIOME_LIST[rng.randi_range(0, BIOME_LIST.size() - 1)]
		var name = _get_node_name(n_type, biome)
		nodes.append(_build_node_dict(floor_idx, b, n_type, name, biome))
		
	return nodes

func _pick_random_node_type(floor_idx: int, rng: RandomNumberGenerator) -> NodeType:
	var roll = rng.randf()
	if floor_idx == 4 or floor_idx == 11:
		return NodeType.REST_SHRINE if roll < 0.5 else NodeType.MERCHANT_OUTPOST
		
	if roll < 0.45:
		return NodeType.BATTLE
	elif roll < 0.65:
		return NodeType.MYSTERY_EVENT
	elif roll < 0.80:
		return NodeType.ELITE_BATTLE
	elif roll < 0.90:
		return NodeType.TREASURE_VAULT
	elif roll < 0.95:
		return NodeType.MERCHANT_OUTPOST
	else:
		return NodeType.REST_SHRINE

func _build_node_dict(floor_idx: int, branch_idx: int, n_type: NodeType, n_name: String, biome: String) -> Dictionary:
	var id = "f%d_b%d" % [floor_idx, branch_idx]
	return {
		"id": id,
		"floor": floor_idx,
		"branch": branch_idx,
		"type": n_type,
		"type_name": _node_type_to_string(n_type),
		"name": n_name,
		"biome": biome,
		"cleared": false,
		"next_nodes": [],
		"modifier": _generate_node_modifier(floor_idx),
		"reward": _generate_node_reward(n_type, floor_idx)
	}

func _node_type_to_string(t: NodeType) -> String:
	match t:
		NodeType.BATTLE: return "battle"
		NodeType.ELITE_BATTLE: return "elite_battle"
		NodeType.REST_SHRINE: return "rest_shrine"
		NodeType.TREASURE_VAULT: return "treasure"
		NodeType.MYSTERY_EVENT: return "event"
		NodeType.MERCHANT_OUTPOST: return "merchant"
		NodeType.BOSS_LAIR: return "boss"
		_: return "battle"

func _get_node_name(t: NodeType, biome: String) -> String:
	match t:
		NodeType.BATTLE: return "Застава " + _biome_title(biome)
		NodeType.ELITE_BATTLE: return "Орда элиты: " + _biome_title(biome)
		NodeType.REST_SHRINE: return "Святилище отдыха"
		NodeType.TREASURE_VAULT: return "Древний тайник"
		NodeType.MYSTERY_EVENT: return "Загадочный путник"
		NodeType.MERCHANT_OUTPOST: return "Караван торговца"
		NodeType.BOSS_LAIR: return "Тронное логово"
		_: return "Узел подземелья"

func _biome_title(b: String) -> String:
	match b:
		"valley": return "Долины"
		"swamp": return "Топей"
		"caves": return "Пещер"
		"frost_peak": return "Ледника"
		"besieged_citadel": return "Цитадели"
		_: return "Земель"

func _connect_floor_branches(rng: RandomNumberGenerator) -> void:
	for f in range(total_floors - 1):
		var curr_nodes: Array = dungeon_graph.get(f, [])
		var next_nodes: Array = dungeon_graph.get(f + 1, [])
		if curr_nodes.is_empty() or next_nodes.is_empty():
			continue
			
		for c in curr_nodes:
			var connections = 0
			for n in next_nodes:
				if abs(c["branch"] - n["branch"]) <= 1 or next_nodes.size() == 1:
					c["next_nodes"].append(n["id"])
					connections += 1
			if connections == 0 and not next_nodes.is_empty():
				c["next_nodes"].append(next_nodes[0]["id"])

func _generate_node_modifier(floor_idx: int) -> Dictionary:
	var mult = 1.0 + (float(floor_idx) * 0.08)
	return {
		"hp_multiplier": mult,
		"speed_multiplier": 1.0 + (float(floor_idx) * 0.03),
		"gold_multiplier": 1.0 + (float(floor_idx) * 0.05),
		"extra_wave": floor_idx >= 8
	}

func _generate_node_reward(t: NodeType, floor_idx: int) -> Dictionary:
	var base_gold = 100 + (floor_idx * 25)
	match t:
		NodeType.BATTLE:
			return {"gold": base_gold, "glory": 15, "relic_chance": 0.15}
		NodeType.ELITE_BATTLE:
			return {"gold": base_gold * 2, "glory": 40, "relic_chance": 0.85}
		NodeType.TREASURE_VAULT:
			return {"gold": base_gold * 3, "glory": 25, "relic_chance": 1.0}
		NodeType.REST_SHRINE:
			return {"heal": 2, "purify_curses": true}
		NodeType.BOSS_LAIR:
			return {"gold": 1000, "glory": 250, "relic_chance": 1.0, "legendary": true}
		_:
			return {"gold": base_gold, "glory": 10}

func get_available_next_nodes() -> Array[Dictionary]:
	if current_node_id == "":
		return dungeon_graph.get(0, [])
		
	var curr = _find_node_by_id(current_node_id)
	if curr.is_empty():
		return []
		
	var next_ids = curr.get("next_nodes", [])
	var res: Array[Dictionary] = []
	var f = curr.get("floor", 0) + 1
	var nodes_on_next: Array = dungeon_graph.get(f, [])
	for n in nodes_on_next:
		if n["id"] in next_ids:
			res.append(n)
	return res

func enter_node(node_id: String) -> bool:
	var n = _find_node_by_id(node_id)
	if n.is_empty():
		return false
		
	current_node_id = node_id
	current_floor = n.get("floor", 0)
	path_history.append(node_id)
	floor_reached.emit(current_floor, n)
	return true

func complete_current_node() -> Dictionary:
	var n = _find_node_by_id(current_node_id)
	if n.is_empty():
		return {}
		
	n["cleared"] = true
	var r = n.get("reward", {})
	dungeon_gold += int(r.get("gold", 0))
	
	if r.has("heal"):
		dungeon_health = min(10, dungeon_health + int(r["heal"]))
	if r.get("purify_curses", false):
		active_curses.clear()
		
	node_completed.emit(n, r)
	
	if current_floor >= total_floors - 1:
		var summary = {
			"victory": true,
			"floors_cleared": total_floors,
			"gold_amassed": dungeon_gold,
			"seed": dungeon_seed
		}
		dungeon_completed.emit(summary)
		return summary
		
	return r

func fail_dungeon() -> void:
	dungeon_failed.emit(current_floor)

func _find_node_by_id(n_id: String) -> Dictionary:
	for f in dungeon_graph:
		for n in dungeon_graph[f]:
			if n.get("id") == n_id:
				return n
	return {}

func serialize_state() -> Dictionary:
	return {
		"dungeon_seed": dungeon_seed,
		"current_floor": current_floor,
		"total_floors": total_floors,
		"current_node_id": current_node_id,
		"path_history": path_history,
		"dungeon_gold": dungeon_gold,
		"dungeon_health": dungeon_health,
		"collected_relics": collected_relics,
		"active_curses": active_curses
	}

func deserialize_state(data: Dictionary) -> void:
	dungeon_seed = data.get("dungeon_seed", 1337)
	total_floors = data.get("total_floors", 15)
	current_floor = data.get("current_floor", 0)
	current_node_id = data.get("current_node_id", "")
	path_history.assign(data.get("path_history", []))
	dungeon_gold = data.get("dungeon_gold", 150)
	dungeon_health = data.get("dungeon_health", 5)
	collected_relics.assign(data.get("collected_relics", []))
	active_curses.assign(data.get("active_curses", []))
	generate_dungeon(dungeon_seed, total_floors)
