class_name TestHorizontalScale
extends TestBase

const HeroBaseScript = preload("res://scripts/hero_base.gd")
const HeroTalentTreeScript = preload("res://scripts/hero_talent_tree.gd")
const RuneSocketSystemScript = preload("res://scripts/rune_socket_system.gd")
const CampaignQuestSystemScript = preload("res://scripts/campaign_quest_system.gd")
const FactionManagerScript = preload("res://scripts/faction_manager.gd")
const CityHubManagerScript = preload("res://scripts/city_hub_manager.gd")
const CraftingSystemScript = preload("res://scripts/crafting_system.gd")
const MasterySystemScript = preload("res://scripts/mastery_system.gd")
const DayNightCycleScript = preload("res://scripts/day_night_cycle.gd")

func before_each() -> void:
	pass

func after_each() -> void:
	pass

func test_heroes_design_and_talents() -> void:
	# 1. Проверяем наличие всех 8 героев в heroes_data.json
	var file = FileAccess.open("res://data/heroes_data.json", FileAccess.READ)
	assert_not_null(file, "heroes_data.json must exist")
	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	file.close()
	assert_eq(err, OK, "heroes_data.json must be valid JSON")
	
	var data = json.data as Dictionary
	var classes = ["commander", "archmage", "ranger", "engineer", "summoner", "alchemist", "paladin", "shadowblade"]
	for c in classes:
		assert_true(data.has(c), "Class %s must be present in heroes_data.json" % c)
		var hero = data[c]
		assert_true(hero.has("name") and not hero["name"].begins_with("Hero "), "Hero %s must have real name" % c)
		assert_true(hero.has("lore") and not hero["lore"].begins_with("Lore for"), "Hero %s must have rich lore" % c)
		assert_true(hero.has("abilities") and hero["abilities"].size() == 3, "Hero %s must have 3 active abilities" % c)
		assert_true(hero.has("passive"), "Hero %s must have passive" % c)
		assert_true(hero.has("ultimate"), "Hero %s must have ultimate" % c)
		assert_true(hero.has("talents"), "Hero %s must have talent tree" % c)

	# 2. Проверяем дерево талантов
	var tree = HeroTalentTreeScript.new()
	var unlocked = tree.unlock_talent("commander", 1, "iron_will")
	assert_true(unlocked, "Unlocking tier 1 talent must succeed")
	
	var active = tree.get_active_talents("commander")
	assert_eq(active.size(), 1, "Commander must have 1 active talent")
	assert_eq(active[0]["choice"], "iron_will")
	
	# Проверяем применение таланта к герою
	var hero_node = HeroBaseScript.new()
	hero_node.hero_class = "commander"
	var base_hp = hero_node.max_health
	tree.apply_talents_to_hero(hero_node)
	assert_gt(hero_node.max_health, base_hp, "Talents must increase hero max health")
	
	tree.free()
	hero_node.free()

func test_runes_system_and_fusion() -> void:
	var file = FileAccess.open("res://data/runes_database.json", FileAccess.READ)
	assert_not_null(file, "runes_database.json must exist")
	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	file.close()
	assert_eq(err, OK, "runes_database.json must be valid JSON")
	
	var data = json.data as Dictionary
	var runes = data.get("runes", [])
	assert_ge(runes.size(), 30, "Database must contain at least 30 real runes")

	# Проверяем работу сокет-системы
	var rune_sys = RuneSocketSystemScript.new()
	var TowerBaseScript = preload("res://scripts/tower_base.gd")
	var dummy_tower = TowerBaseScript.new()
	dummy_tower.current_level = 3
	dummy_tower.damage = 50
	dummy_tower.range_radius = 150.0
	dummy_tower.attack_speed = 1.0
	
	var socket_ok = rune_sys.socket_rune(dummy_tower, 0, "rune_blade_1")
	assert_true(socket_ok, "Socketing rune_blade_1 must succeed")
	
	# Урон должен вырасти
	assert_gt(dummy_tower.damage, 50, "Damage should increase from rune")
	
	# Извлечение руны
	var unsocketed = rune_sys.unsocket_rune(dummy_tower, 0)
	assert_eq(unsocketed.get("id"), "rune_blade_1", "Unsocketed rune id must match")
	assert_eq(dummy_tower.damage, 50, "Damage must return to base after unsocket")
	
	# Проверяем слияние
	var fused = rune_sys.fuse_runes("ruby_1")
	assert_true(fused.begins_with("ruby_2"), "Fused ruby_1 must yield ruby_2 tier")
	
	rune_sys.free()
	dummy_tower.free()

func test_campaign_quests_expansion() -> void:
	var file = FileAccess.open("res://data/campaign_quests.json", FileAccess.READ)
	assert_not_null(file, "campaign_quests.json must exist")
	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	file.close()
	assert_eq(err, OK, "campaign_quests.json must be valid JSON")
	
	var quests = json.data as Array
	assert_ge(quests.size(), 30, "Campaign quests must have at least 30 real quests")
	
	# Проверяем отсутствие filler_quest
	for q in quests:
		assert_false(str(q.get("id", "")).begins_with("filler_quest"), "No filler quests allowed")

	var quest_sys = CampaignQuestSystemScript.new()
	var started = quest_sys.start_quest("ch1_q1")
	assert_true(started, "Starting ch1_q1 quest must succeed")
	assert_eq(quest_sys.active_quests.size(), 1)
	
	quest_sys.advance_quest_progress("kill", "grunt", 10.0)
	assert_gt(quest_sys.active_quests[0]["progress"], 0.0, "Progress must advance")
	
	quest_sys.free()

func test_factions_and_reputation_perks() -> void:
	var file = FileAccess.open("res://data/factions_data.json", FileAccess.READ)
	assert_not_null(file, "factions_data.json must exist")
	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	file.close()
	assert_eq(err, OK, "factions_data.json must be valid JSON")
	
	var factions = json.data as Array
	assert_eq(factions.size(), 8, "There must be exactly 8 real factions without minor padding")
	
	for f in factions:
		assert_false(str(f.get("id", "")).begins_with("minor_faction"), "No minor faction padding allowed")
		assert_true(f.has("contracts") and f["contracts"].size() >= 5, "Faction must have at least 5 contracts")
		assert_true(f.has("perks") and f["perks"].has("Friendly"), "Faction must have tier perks")

	var f_mgr = FactionManagerScript.new()
	f_mgr.add_reputation("royal_crown", 600)
	var rep = f_mgr.player_reputation.get("royal_crown", 0)
	assert_ge(rep, 500, "Reputation must be Honored level")
	
	f_mgr.free()

func test_mutators_database_integrity() -> void:
	var file = FileAccess.open("res://data/mutators_data.json", FileAccess.READ)
	assert_not_null(file, "mutators_data.json must exist")
	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	file.close()
	assert_eq(err, OK, "mutators_data.json must be valid JSON")
	
	var data = json.data as Dictionary
	assert_ge(data.size(), 100, "Mutators database must contain at least 100 real mutators")
	
	for k in data.keys():
		assert_false(k.begins_with("pad_mutator") or k.begins_with("mutator_"), "No dummy mutators allowed: %s" % k)
		var m = data[k]
		assert_true(m.has("category") and m.has("name") and m.has("description"), "Mutator must have full metadata")

func test_city_hub_and_crafting() -> void:
	# City Hub
	var hub = CityHubManagerScript.new()
	assert_eq(hub.buildings_database.size(), 20, "City Hub must contain 20 buildings")
	
	var up_cost = hub.get_upgrade_cost("arsenal")
	assert_gt(up_cost, 0, "Upgrade cost must be positive")
	
	var up_ok = hub.upgrade_building("arsenal")
	assert_true(up_ok, "Arsenal upgrade should succeed")
	
	var bonuses = hub.get_aggregate_bonuses()
	assert_ge(bonuses["starting_gold_bonus"], 0)
	
	hub.free()

	# Crafting System
	var craft = CraftingSystemScript.new()
	assert_ge(craft.recipes.size(), 25, "Crafting system must contain at least 25 recipes")
	
	# Проверяем крафт зелья
	var inv = { "healing_herbs": 5, "pure_water": 2 }
	var can_c = craft.can_craft("potion_health", inv)
	assert_true(can_c, "Should be able to craft potion_health with materials")
	
	var res = craft.craft_recipe("potion_health", inv)
	assert_true(res.get("success"), "Crafting must succeed")
	assert_eq(inv["pure_water"], 1, "Water must be consumed")
	
	craft.free()

func test_world_events_and_day_night() -> void:
	var file = FileAccess.open("res://data/world_events.json", FileAccess.READ)
	assert_not_null(file, "world_events.json must exist")
	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	file.close()
	assert_eq(err, OK, "world_events.json must be valid JSON")
	
	var events = json.data as Array
	assert_ge(events.size(), 50, "World events must have at least 50 events")
	for e in events:
		assert_false(str(e.get("id", "")).begins_with("filler_event"), "No filler events allowed")

	# Day/Night cycle
	var dn = DayNightCycleScript.new()
	dn.set_time_of_day(DayNightCycleScript.TimeOfDay.DAY)
	var day_mods = dn.get_combat_modifiers()
	assert_eq(day_mods.get("tower_range_mult"), 1.10, "Day must grant +10% tower range")
	
	dn.set_time_of_day(DayNightCycleScript.TimeOfDay.DUSK)
	var dusk_mods = dn.get_combat_modifiers()
	assert_eq(dusk_mods.get("enemy_speed_mult"), 1.05, "Dusk must grant +5% enemy speed")
	
	dn.set_time_of_day(DayNightCycleScript.TimeOfDay.DAWN)
	var dawn_mods = dn.get_combat_modifiers()
	assert_eq(dawn_mods.get("hero_mana_regen_mult"), 1.30, "Dawn must grant +30% hero mana regen")
	
	dn.free()

func test_mastery_system_and_procedural_rules() -> void:
	var mastery = MasterySystemScript.new()
	mastery.record_tower_kill("archer", 150)
	var lvl = mastery.get_tower_mastery_level("archer")
	assert_ge(lvl, 1, "Archer tower must reach level 1 mastery with 150 XP")
	
	mastery.record_enemy_kill("grunt")
	var kills = mastery.enemy_kill_counts.get("grunt", 0)
	assert_eq(kills, 1, "Kill must be recorded")
	mastery.free()

	# Procedural rules
	var p_file = FileAccess.open("res://data/procedural_rules.json", FileAccess.READ)
	assert_not_null(p_file, "procedural_rules.json must exist")
	var p_json = JSON.new()
	assert_eq(p_json.parse(p_file.get_as_text()), OK, "procedural_rules.json must be valid JSON")
	var p_data = p_json.data as Dictionary
	assert_true(p_data.has("biome_rules"), "procedural_rules.json must have biome_rules")
	p_file.close()
