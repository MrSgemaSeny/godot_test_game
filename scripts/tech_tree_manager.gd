class_name TechTreeManager
extends Node

signal research_points_changed(amount: int)
signal node_unlocked(node_id: String)

var research_points: int = 0
var unlocked_nodes: Array = []
var blocked_nodes: Array = []
var tech_nodes_data: Array = []

func _enter_tree() -> void:
	add_to_group("tech_tree_manager")

func _ready() -> void:
	load_tech_data()

func load_tech_data() -> void:
	if not FileAccess.file_exists("res://data/tech_tree.json"):
		return
	var file = FileAccess.open("res://data/tech_tree.json", FileAccess.READ)
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Array:
		tech_nodes_data = json.data

func validate_tech_tree() -> Dictionary:
	var errors: Array = []
	var known_ids: Dictionary = {}
	
	for node in tech_nodes_data:
		var node_id = node.get("id", "")
		if node_id.is_empty():
			errors.append("Found tech node with empty ID")
			continue
		if known_ids.has(node_id):
			errors.append("Duplicate tech node ID: %s" % node_id)
		known_ids[node_id] = node
		
		var cost = node.get("cost", 0)
		if cost < 0:
			errors.append("Negative cost for node: %s" % node_id)
			
	for node in tech_nodes_data:
		var node_id = node.get("id", "")
		var reqs = node.get("requires", [])
		for r in reqs:
			if not known_ids.has(r):
				errors.append("Node %s requires unknown node %s" % [node_id, r])
				
		var muts = node.get("mutually_exclusive", [])
		for m in muts:
			if not known_ids.has(m):
				errors.append("Node %s has unknown mutually_exclusive node %s" % [node_id, m])
				
	return {
		"valid": errors.is_empty(),
		"errors": errors
	}


func reset_tree(initial_points: int = 0) -> void:
	research_points = initial_points
	unlocked_nodes = []
	blocked_nodes = []
	research_points_changed.emit(research_points)

func add_points(amount: int = 1) -> void:
	research_points += amount
	research_points_changed.emit(research_points)

func get_node_info(node_id: String) -> Dictionary:
	for node in tech_nodes_data:
		if node.get("id") == node_id:
			return node
	return {}

func is_unlocked(node_id: String) -> bool:
	return node_id in unlocked_nodes

func is_blocked(node_id: String) -> bool:
	return node_id in blocked_nodes

func can_unlock(node_id: String) -> bool:
	if is_unlocked(node_id) or is_blocked(node_id):
		return false
		
	var info = get_node_info(node_id)
	if info.is_empty():
		return false
		
	# Проверка очков исследований
	var cost = info.get("cost", 1)
	if research_points < cost:
		return false
		
	# Проверка зависимостей
	var reqs = info.get("requires", [])
	for r in reqs:
		if not (r in unlocked_nodes):
			return false
			
	return true

func unlock_node(node_id: String) -> bool:
	if not can_unlock(node_id):
		return false
		
	var info = get_node_info(node_id)
	var cost = info.get("cost", 1)
	research_points -= cost
	unlocked_nodes.append(node_id)
	
	# Применяем блокировки
	var blocks = info.get("mutually_exclusive", [])
	for b in blocks:
		if not (b in blocked_nodes):
			blocked_nodes.append(b)
			
	research_points_changed.emit(research_points)
	node_unlocked.emit(node_id)
	return true

# Геттеры активных модификаторов
func get_damage_bonus() -> float:
	var total = 0.0
	if is_unlocked("defense_1"):
		total += 0.12
	return total

func get_range_bonus() -> float:
	return 0.20 if is_unlocked("defense_2") else 0.0

func get_boss_damage_bonus() -> float:
	return 0.30 if is_unlocked("defense_3") else 0.0

func get_gold_reward_mult() -> float:
	return 0.20 if is_unlocked("econ_1") else 0.0

func get_sell_ratio() -> float:
	return 0.90 if is_unlocked("econ_2") else 0.70

func get_end_wave_bonus_gold() -> int:
	return 60 if is_unlocked("econ_3") else 0

func get_cost_discount() -> float:
	return 0.15 if is_unlocked("special_1") else 0.0

func get_ability_cooldown_mult() -> float:
	return 0.40 if is_unlocked("special_2") else 0.0

# === Stage 2 New Tech Tree Accessors ===

func get_armor_penetration() -> float:
	return 0.25 if is_unlocked("defense_4") else 0.0

func is_berserk_unlocked() -> bool:
	return is_unlocked("defense_5")

func get_stun_chance() -> float:
	return 0.20 if is_unlocked("defense_7") else 0.0

func get_merchant_discount() -> float:
	return 0.30 if is_unlocked("econ_4") else 0.0

func get_passive_gold_per_sec() -> int:
	return 2 if is_unlocked("econ_5") else 0

func get_wave_end_interest_ratio() -> float:
	return 0.10 if is_unlocked("econ_6") else 0.0

func get_bulk_tower_discount() -> float:
	return 0.08 if is_unlocked("econ_7") else 0.0

func get_mana_regen_bonus() -> float:
	return 0.35 if is_unlocked("special_3") else 0.0

func get_synergy_multiplier_bonus() -> float:
	return 0.50 if is_unlocked("special_4") else 0.0

func can_reveal_stealth_waves() -> bool:
	return is_unlocked("special_5")

func get_buff_drop_chance() -> float:
	return 0.05 if is_unlocked("special_6") else 0.0

