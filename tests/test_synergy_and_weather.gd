class_name TestSynergyAndWeather
extends TestBase

const SynergyManagerClass = preload("res://scripts/synergy_manager.gd")
const WeatherSystemClass = preload("res://scripts/weather_system.gd")

func test_synergies_neighbor_detection() -> void:
	var sm = SynergyManagerClass.new()
	sm._load_synergies_db()
	assert_gt(sm.synergies_db.size(), 0, "Synergies database must be populated")
	
	# Create ice_mage and cannon close to each other
	var t_ice = TowerBase.new()
	t_ice.tower_type = "ice_mage"
	t_ice.global_position = Vector2(100, 100)
	
	var t_cannon = TowerBase.new()
	t_cannon.tower_type = "cannon"
	t_cannon.global_position = Vector2(180, 100) # Distance 80 <= 140
	
	var res = sm.evaluate_all_synergies([t_ice, t_cannon])
	assert_gt(res.size(), 0, "Close ice_mage and cannon should trigger synergy")
	assert_true(sm.is_synergy_active("ice_and_cannon"))
	assert_almost_eq(sm.get_tower_synergy_multiplier(t_cannon), 1.40, 0.01)
	
	# Move far away
	t_cannon.global_position = Vector2(500, 500)
	var res_far = sm.evaluate_all_synergies([t_ice, t_cannon])
	assert_eq(res_far.size(), 0, "Far away towers should not trigger synergy")
	assert_false(sm.is_synergy_active("ice_and_cannon"))
	
	t_ice.queue_free()
	t_cannon.queue_free()
	sm.queue_free()

func test_weather_modifiers() -> void:
	var ws = WeatherSystemClass.new()
	
	# Clear
	ws.set_weather("clear")
	assert_almost_eq(ws.get_damage_modifier("fire"), 1.0, 0.01)
	assert_almost_eq(ws.get_tower_range_modifier(), 1.0, 0.01)
	
	# Rain: lightning +25%, fire -30%
	ws.set_weather("rain")
	assert_almost_eq(ws.get_damage_modifier("lightning"), 1.25, 0.01)
	assert_almost_eq(ws.get_damage_modifier("fire"), 0.70, 0.01)
	
	# Fog: range -20%
	ws.set_weather("fog")
	assert_almost_eq(ws.get_tower_range_modifier(), 0.80, 0.01)
	
	# Eclipse: enemy speed +20%, gold x2
	ws.set_weather("eclipse")
	assert_almost_eq(ws.get_enemy_speed_modifier(), 1.20, 0.01)
	assert_almost_eq(ws.get_gold_multiplier(), 2.0, 0.01)
	
	# Snow: traps disabled, enemy speed -10%
	ws.set_weather("snow")
	assert_true(ws.are_traps_disabled())
	assert_almost_eq(ws.get_enemy_speed_modifier(), 0.90, 0.01)
	
	ws.queue_free()
