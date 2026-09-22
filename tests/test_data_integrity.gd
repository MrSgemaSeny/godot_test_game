class_name TestDataIntegrity
extends TestBase

# ==============================================================================
# Feature 7: Towers Database Integrity (17 Towers, 3 Levels Each)
# ==============================================================================
func test_towers_database_integrity() -> void:
	assert_true(FileAccess.file_exists("res://data/towers.json"), "towers.json must exist")
	var file = FileAccess.open("res://data/towers.json", FileAccess.READ)
	var json = JSON.new()
	var parse_err = json.parse(file.get_as_text())
	assert_eq(parse_err, OK, "towers.json must be valid JSON")
	assert_true(json.data is Dictionary, "towers.json root must be a Dictionary")
	
	var data: Dictionary = json.data
	assert_eq(data.size(), 17, "towers.json must contain exactly 17 towers")
	
	var expected_towers = [
		"archer", "crossbowman", "siege_cannon", "bastion", "ice_mage",
		"necromancer", "time_tower", "trading_post", "trap", "auto_turret",
		"flame_tower", "tesla", "poison_tower", "support_tower", "watchtower",
		"wall", "cannon"
	]
	
	var valid_damage_types = ["physical", "magic", "poison", "fire", "cold", "lightning", "true", "none"]
	var expected_keys = ["name", "cost", "damage_type", "levels"]
	
	for tower_id in expected_towers:
		assert_true(data.has(tower_id), "towers.json must contain tower '%s'" % tower_id)
		var tinfo = data[tower_id]
		assert_true(tinfo is Dictionary, "Tower %s must be a Dictionary" % tower_id)
		
		for k in expected_keys:
			assert_true(tinfo.has(k), "Tower %s must have property '%s'" % [tower_id, k])
			
		assert_gt(tinfo.cost, 0, "Tower %s cost must be positive" % tower_id)
		assert_true(valid_damage_types.has(tinfo.damage_type), "Tower %s has invalid damage_type '%s'" % [tower_id, tinfo.damage_type])
		
		var levels = tinfo.get("levels", [])
		assert_true(levels is Array, "Tower %s levels must be an Array" % tower_id)
		assert_ge(levels.size(), 3, "Tower %s must have at least 3 levels" % tower_id)
		
		for i in range(3):
			var lvl_data = levels[i]
			assert_true(lvl_data is Dictionary, "Tower %s level %d must be a Dictionary" % [tower_id, i + 1])
			assert_eq(int(lvl_data.get("level", 0)), i + 1, "Tower %s level index mismatch" % tower_id)
			assert_gt(float(lvl_data.get("range", 0.0)), 0.0, "Tower %s level %d range must be > 0" % [tower_id, i + 1])
			assert_gt(float(lvl_data.get("attack_speed", 0.0)), 0.0, "Tower %s level %d attack_speed must be > 0" % [tower_id, i + 1])
			assert_ge(float(lvl_data.get("damage", 0.0)), 0.0, "Tower %s level %d damage must be >= 0" % [tower_id, i + 1])
			assert_ge(int(lvl_data.get("upgrade_cost", 0)), 0, "Tower %s level %d upgrade_cost must be >= 0" % [tower_id, i + 1])


# ==============================================================================
# Feature 8: Enemies Database Integrity (20 Enemies, Flags, Resistances)
# ==============================================================================
func test_enemies_database_integrity() -> void:
	assert_true(FileAccess.file_exists("res://data/enemies.json"), "enemies.json must exist")
	var file = FileAccess.open("res://data/enemies.json", FileAccess.READ)
	var json = JSON.new()
	assert_eq(json.parse(file.get_as_text()), OK, "enemies.json must be valid JSON")
	assert_true(json.data is Dictionary, "enemies.json root must be a Dictionary")
	
	var data: Dictionary = json.data
	assert_eq(data.size(), 20, "enemies.json must contain exactly 20 enemies")
	
	var expected_enemies = [
		"grunt", "berserker", "armored", "shaman", "troll", "stealth",
		"warchief_boss", "archmage_boss", "fish_mosquito", "windwing",
		"shadow_wolf", "carapace_beetle", "stone_golem", "iron_guard",
		"flying_pumpkin", "spore_flyer", "carrion_griffin", "splitter",
		"frost_orc", "exploding_troll"
	]
	
	var valid_damage_types = ["physical", "magic", "poison", "fire", "cold", "lightning", "true", "all"]
	var flyers = ["windwing", "flying_pumpkin", "spore_flyer", "carrion_griffin"]
	var stealths = ["stealth", "shadow_wolf"]
	var bosses = ["warchief_boss", "archmage_boss"]
	
	for e_id in expected_enemies:
		assert_true(data.has(e_id), "enemies.json must contain enemy '%s'" % e_id)
		var einfo = data[e_id]
		assert_true(einfo is Dictionary, "Enemy %s must be a Dictionary" % e_id)
		
		assert_gt(float(einfo.get("max_health", 0.0)), 0.0, "Enemy %s max_health must be > 0" % e_id)
		assert_gt(float(einfo.get("speed", 0.0)), 0.0, "Enemy %s speed must be > 0" % e_id)
		assert_ge(float(einfo.get("armor", 0.0)), 0.0, "Enemy %s armor must be >= 0" % e_id)
		assert_gt(int(einfo.get("gold_reward", 0)), 0, "Enemy %s gold_reward must be > 0" % e_id)
		
		# Flyer flag check
		if flyers.has(e_id):
			assert_true(bool(einfo.get("is_flyer", false)), "Enemy %s must have is_flyer = true" % e_id)
			
		# Stealth flag check
		if stealths.has(e_id):
			var has_stealth = bool(einfo.get("is_stealth", false)) or bool(einfo.get("is_invisible", false))
			assert_true(has_stealth, "Enemy %s must have is_stealth or is_invisible = true" % e_id)
			
		# Boss flag check
		if bosses.has(e_id):
			assert_true(bool(einfo.get("is_boss", false)), "Enemy %s must have is_boss = true" % e_id)
			
		# Split on death check
		if e_id == "splitter":
			var has_split = bool(einfo.get("split_on_death", false)) or einfo.has("split_on_death")
			assert_true(has_split, "Enemy splitter must have split_on_death configured")
			var split_type = str(einfo.get("split_enemy_type", ""))
			if split_type.is_empty() and einfo.get("split_on_death") is Dictionary:
				split_type = str(einfo["split_on_death"].get("type", ""))
			assert_true(data.has(split_type), "Split target enemy '%s' must exist in enemies.json" % split_type)
			
		# Resistances validation
		if einfo.has("resistances") and einfo["resistances"] is Dictionary:
			for r_type in einfo["resistances"]:
				assert_true(valid_damage_types.has(r_type), "Enemy %s has invalid resistance type '%s'" % [e_id, r_type])
		elif einfo.has("resist") and einfo["resist"] is Dictionary:
			for r_type in einfo["resist"]:
				assert_true(valid_damage_types.has(r_type), "Enemy %s has invalid resist type '%s'" % [e_id, r_type])
				
		# Immunities validation
		if einfo.has("immunities") and einfo["immunities"] is Array:
			for imm in einfo["immunities"]:
				assert_true(valid_damage_types.has(imm), "Enemy %s has invalid immunity type '%s'" % [e_id, imm])
		elif einfo.has("immune_to") and einfo["immune_to"] is Array:
			for imm in einfo["immune_to"]:
				assert_true(valid_damage_types.has(imm), "Enemy %s has invalid immune_to type '%s'" % [e_id, imm])


# ==============================================================================
# Feature 9: Waves Database Integrity (25 Waves, wave_event, Enemy Cross-Refs)
# ==============================================================================
func test_waves_database_integrity() -> void:
	assert_true(FileAccess.file_exists("res://data/waves.json"), "waves.json must exist")
	var file = FileAccess.open("res://data/waves.json", FileAccess.READ)
	var json = JSON.new()
	assert_eq(json.parse(file.get_as_text()), OK, "waves.json must be valid JSON")
	assert_true(json.data is Array, "waves.json root must be an Array")
	assert_eq(json.data.size(), 25, "There should be 25 waves")
	
	# Load enemies.json to verify every referenced enemy_type exists
	assert_true(FileAccess.file_exists("res://data/enemies.json"), "enemies.json must exist for wave validation")
	var ef = FileAccess.open("res://data/enemies.json", FileAccess.READ)
	var ejson = JSON.new()
	assert_eq(ejson.parse(ef.get_as_text()), OK, "enemies.json must be valid JSON")
	var enemy_dict: Dictionary = ejson.data
	
	var valid_events = ["none", "boss_wave", "speed_surge", "air_wave", "stealth_wave", "armor_surge", "ambush", "double_rewards"]
	var boss_waves = [5, 10, 15, 20, 25]
	
	for i in range(json.data.size()):
		var wave = json.data[i]
		assert_true(wave is Dictionary, "Wave at index %d must be a Dictionary" % i)
		assert_true(wave.has("wave_number"), "Wave object must have 'wave_number'")
		assert_eq(int(wave.wave_number), i + 1, "Wave at index %d must have wave_number %d" % [i, i + 1])
		
		assert_true(wave.has("wave_event"), "Wave %d must have 'wave_event' property" % wave.wave_number)
		assert_true(valid_events.has(str(wave.wave_event)), "Wave %d has invalid wave_event '%s'" % [wave.wave_number, str(wave.wave_event)])
		
		if boss_waves.has(wave.wave_number):
			assert_eq(str(wave.wave_event), "boss_wave", "Wave %d must be a 'boss_wave' event" % wave.wave_number)
			
		assert_true(wave.has("spawn_groups"), "Wave %d must have 'spawn_groups' array" % wave.wave_number)
		assert_true(wave.spawn_groups is Array, "Wave %d spawn_groups must be an Array" % wave.wave_number)
		assert_gt(wave.spawn_groups.size(), 0, "Wave %d must contain at least 1 spawn group" % wave.wave_number)
		
		for group in wave.spawn_groups:
			assert_true(group is Dictionary, "Spawn group in wave %d must be a Dictionary" % wave.wave_number)
			assert_true(group.has("enemy_type"), "Group in wave %d must have 'enemy_type'" % wave.wave_number)
			assert_true(enemy_dict.has(group.enemy_type), "Wave %d references non-existent enemy_type '%s'" % [wave.wave_number, group.enemy_type])
			assert_true(group.has("count"), "Group in wave %d must have 'count'" % wave.wave_number)
			assert_gt(int(group.count), 0, "Group monster count must be > 0 in wave %d" % wave.wave_number)
			assert_gt(float(group.get("interval", 1.0)), 0.0, "Group interval must be > 0 in wave %d" % wave.wave_number)
			assert_ge(float(group.get("delay", 0.0)), 0.0, "Group delay must be >= 0 in wave %d" % wave.wave_number)


# ==============================================================================
# Feature 10: Tech Tree Integrity (20 Nodes, 3 Branches, Symmetrical Locks)
# ==============================================================================
func test_tech_tree_integrity() -> void:
	assert_true(FileAccess.file_exists("res://data/tech_tree.json"), "tech_tree.json must exist")
	var file = FileAccess.open("res://data/tech_tree.json", FileAccess.READ)
	var json = JSON.new()
	assert_eq(json.parse(file.get_as_text()), OK, "tech_tree.json must be valid JSON")
	assert_true(json.data is Array, "tech_tree.json root must be an Array")
	assert_eq(json.data.size(), 20, "tech_tree.json must contain exactly 20 nodes")
	
	var node_ids = []
	var branch_counts = {"defense": 0, "economy": 0, "special": 0}
	var node_map = {}
	
	for node in json.data:
		assert_true(node is Dictionary, "Tech node must be a Dictionary")
		assert_true(node.has("id"), "Tech node must have 'id'")
		assert_true(node.has("name"), "Tech node must have 'name'")
		assert_true(node.has("branch"), "Tech node must have 'branch'")
		assert_true(node.has("cost"), "Tech node must have 'cost'")
		assert_gt(int(node.cost), 0, "Tech node %s cost must be > 0" % node.id)
		assert_true(node.has("effect"), "Tech node %s must have 'effect'" % node.id)
		
		var b = str(node.branch)
		assert_true(branch_counts.has(b), "Tech node %s has unknown branch '%s'" % [node.id, b])
		branch_counts[b] += 1
		
		node_ids.append(node.id)
		node_map[node.id] = node
		
	assert_eq(branch_counts["defense"], 7, "Defense branch must have exactly 7 nodes")
	assert_eq(branch_counts["economy"], 7, "Economy branch must have exactly 7 nodes")
	assert_eq(branch_counts["special"], 6, "Special branch must have exactly 6 nodes")
	
	# Check prerequisites and mutual exclusions
	for node in json.data:
		for prereq in node.get("requires", []):
			assert_true(node_ids.has(prereq), "Node %s requires non-existent node %s" % [node.id, prereq])
			assert_ne(prereq, node.id, "Node %s cannot require itself" % node.id)
			
		var locks = node.get("mutually_exclusive", [])
		if locks.is_empty() and node.has("blocks"):
			locks = node.get("blocks", [])
			
		for block in locks:
			assert_true(node_ids.has(block), "Node %s blocks non-existent node %s" % [node.id, block])
			assert_ne(block, node.id, "Node %s cannot block itself" % node.id)
			
			# Verify symmetrical reciprocal lock
			var target_node = node_map[block]
			var target_locks = target_node.get("mutually_exclusive", target_node.get("blocks", []))
			assert_true(target_locks.has(node.id), "Mutual exclusion between %s and %s must be reciprocal" % [node.id, block])
			
	# Validate via TechTreeManager
	var tech_mgr = TechTreeManager.new()
	tech_mgr.load_tech_data()
	var val_res = tech_mgr.validate_tech_tree()
	assert_true(val_res.get("valid", false), "TechTreeManager.validate_tech_tree() must return true")
	tech_mgr.free()


# ==============================================================================
# Feature 11: Spells Database Integrity (8 Spells, Damage Types, Cooldowns)
# ==============================================================================
func test_spells_database_integrity() -> void:
	assert_true(FileAccess.file_exists("res://data/spells_database.json"), "spells_database.json must exist")
	var file = FileAccess.open("res://data/spells_database.json", FileAccess.READ)
	var json = JSON.new()
	assert_eq(json.parse(file.get_as_text()), OK, "spells_database.json must be valid JSON")
	assert_true(json.data is Dictionary, "spells_database.json root must be a Dictionary")
	
	var data: Dictionary = json.data
	assert_eq(data.size(), 8, "spells_database.json must contain exactly 8 spells")
	
	var expected_spells = [
		"meteor", "freeze", "gold_rain", "lightning",
		"vortex", "roots", "chronoshift", "stone_wall"
	]
	
	var valid_damage_types = ["fire", "cold", "lightning", "magic", "physical", "none"]
	var valid_effect_types = ["damage", "freeze", "resource", "displacement", "immobilize", "time_slow", "barrier"]
	
	for s_id in expected_spells:
		assert_true(data.has(s_id), "spells_database must contain spell '%s'" % s_id)
		var sinfo = data[s_id]
		assert_true(sinfo is Dictionary, "Spell %s must be a Dictionary" % s_id)
		
		assert_true(sinfo.has("mana_cost"), "Spell %s must have mana_cost" % s_id)
		assert_gt(int(sinfo.mana_cost), 0, "Spell %s mana_cost must be > 0" % s_id)
		
		assert_true(sinfo.has("cooldown"), "Spell %s must have cooldown" % s_id)
		assert_gt(float(sinfo.cooldown), 0.0, "Spell %s cooldown must be > 0" % s_id)
		
		assert_true(sinfo.has("name"), "Spell %s must have 'name'" % s_id)
		assert_true(sinfo.has("description"), "Spell %s must have 'description'" % s_id)
		
		if sinfo.has("damage_type"):
			assert_true(valid_damage_types.has(str(sinfo.damage_type)), "Spell %s has invalid damage_type '%s'" % [s_id, str(sinfo.damage_type)])
		if sinfo.has("effect_type"):
			assert_true(valid_effect_types.has(str(sinfo.effect_type)), "Spell %s has invalid effect_type '%s'" % [s_id, str(sinfo.effect_type)])


# ==============================================================================
# Meta Tree Integrity (Preserved Baseline)
# ==============================================================================
func test_meta_tree_integrity() -> void:
	assert_true(FileAccess.file_exists("res://data/meta_tree.json"), "meta_tree.json must exist")
	var file = FileAccess.open("res://data/meta_tree.json", FileAccess.READ)
	var json = JSON.new()
	assert_eq(json.parse(file.get_as_text()), OK, "meta_tree.json must be valid JSON")
	assert_true(json.data is Array, "meta_tree.json root must be an Array")
	
	for item in json.data:
		assert_true(item.has("id"), "Meta item must have 'id'")
		assert_true(item.has("max_level"), "Meta item must have 'max_level'")
		assert_gt(item.max_level, 0, "Meta item max_level must be > 0")
		assert_true(item.has("cost_per_level"), "Meta item must have 'cost_per_level'")
		assert_gt(item.cost_per_level, 0, "Meta item cost_per_level must be > 0")
