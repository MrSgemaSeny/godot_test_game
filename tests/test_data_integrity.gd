class_name TestDataIntegrity
extends TestBase

func test_towers_database_integrity() -> void:
	assert_true(FileAccess.file_exists("res://data/towers.json"), "towers.json must exist")
	var file = FileAccess.open("res://data/towers.json", FileAccess.READ)
	var json = JSON.new()
	var parse_err = json.parse(file.get_as_text())
	assert_eq(parse_err, OK, "towers.json must be valid JSON")
	assert_true(json.data is Dictionary, "towers.json root must be a Dictionary")
	
	var data: Dictionary = json.data
	assert_gt(data.size(), 0, "towers.json must contain towers")
	
	var expected_keys = ["name", "cost", "damage_type", "levels"]
	for tower_id in data:
		var tinfo = data[tower_id]
		assert_true(tinfo is Dictionary, "Tower %s must be a Dictionary" % tower_id)
		for k in expected_keys:
			assert_true(tinfo.has(k), "Tower %s must have property '%s'" % [tower_id, k])
		assert_gt(tinfo.cost, 0, "Tower %s cost must be positive" % tower_id)
		var levels = tinfo.get("levels", [])
		assert_gt(levels.size(), 0, "Tower %s must have at least 1 level" % tower_id)
		assert_gt(levels[0].range, 0.0, "Tower %s level 1 range must be > 0" % tower_id)

func test_enemies_database_integrity() -> void:
	assert_true(FileAccess.file_exists("res://data/enemies.json"), "enemies.json must exist")
	var file = FileAccess.open("res://data/enemies.json", FileAccess.READ)
	var json = JSON.new()
	assert_eq(json.parse(file.get_as_text()), OK, "enemies.json must be valid JSON")
	var data: Dictionary = json.data
	
	var required_enemies = ["grunt", "berserker", "armored", "shaman", "troll", "stealth", "warchief_boss", "archmage_boss"]
	for e_id in required_enemies:
		assert_true(data.has(e_id), "enemies.json must contain enemy '%s'" % e_id)
		var einfo = data[e_id]
		assert_gt(einfo.max_health, 0.0, "Enemy %s max_health must be > 0" % e_id)
		assert_gt(einfo.speed, 0.0, "Enemy %s speed must be > 0" % e_id)
		assert_gt(einfo.gold_reward, 0, "Enemy %s gold_reward must be > 0" % e_id)


func test_spells_database_integrity() -> void:
	assert_true(FileAccess.file_exists("res://data/spells_database.json"), "spells_database.json must exist")
	var file = FileAccess.open("res://data/spells_database.json", FileAccess.READ)
	var json = JSON.new()
	assert_eq(json.parse(file.get_as_text()), OK, "spells_database.json must be valid JSON")
	var data: Dictionary = json.data
	
	var required_spells = ["meteor", "freeze", "gold_rain", "lightning"]
	for s_id in required_spells:
		assert_true(data.has(s_id), "spells_database must contain spell '%s'" % s_id)
		var sinfo = data[s_id]
		assert_true(sinfo.has("mana_cost"), "Spell %s must have mana_cost" % s_id)
		assert_true(sinfo.has("cooldown"), "Spell %s must have cooldown" % s_id)
		assert_gt(sinfo.mana_cost, 0, "Spell %s mana_cost must be > 0" % s_id)

func test_tech_tree_integrity() -> void:
	assert_true(FileAccess.file_exists("res://data/tech_tree.json"), "tech_tree.json must exist")
	var file = FileAccess.open("res://data/tech_tree.json", FileAccess.READ)
	var json = JSON.new()
	assert_eq(json.parse(file.get_as_text()), OK, "tech_tree.json must be valid JSON")
	assert_true(json.data is Array, "tech_tree.json root must be an Array")
	
	var node_ids = []
	for node in json.data:
		assert_true(node.has("id"), "Tech node must have 'id'")
		assert_true(node.has("name"), "Tech node must have 'name'")
		assert_true(node.has("cost"), "Tech node must have 'cost'")
		node_ids.append(node.id)
		
	# Check prerequisites and blocks reference valid IDs
	for node in json.data:
		for prereq in node.get("requires", []):
			assert_true(node_ids.has(prereq), "Node %s requires non-existent node %s" % [node.id, prereq])
		for block in node.get("blocks", []):
			assert_true(node_ids.has(block), "Node %s blocks non-existent node %s" % [node.id, block])

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

func test_waves_database_integrity() -> void:
	assert_true(FileAccess.file_exists("res://data/waves.json"), "waves.json must exist")
	var file = FileAccess.open("res://data/waves.json", FileAccess.READ)
	var json = JSON.new()
	assert_eq(json.parse(file.get_as_text()), OK, "waves.json must be valid JSON")
	assert_true(json.data is Array, "waves.json root must be an Array")
	assert_eq(json.data.size(), 10, "There should be 10 waves")
	
	for wave in json.data:
		assert_true(wave.has("wave_number"), "Wave object must have 'wave_number'")
		assert_true(wave.has("spawn_groups"), "Wave object must have 'spawn_groups' array")
		for group in wave.spawn_groups:
			assert_true(group.has("enemy_type"), "Group must have 'enemy_type'")
			assert_true(group.has("count"), "Group must have 'count'")
			assert_gt(group.count, 0, "Group monster count must be > 0")
