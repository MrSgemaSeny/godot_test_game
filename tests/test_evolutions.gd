class_name TestEvolutions
extends TestBase

func test_tower_evolution_requirements() -> void:
	var t = TowerBase.new()
	t.tower_type = "archer"
	t.current_level = 1
	t.evolution_data_a = {"name": "Снайпер", "damage": 85, "range": 350, "special_ability": "crit_20"}
	t.evolution_data_b = {"name": "Пулемётчик", "damage": 18, "attack_speed": 6.5, "special_ability": "pierce_5"}
	
	assert_false(t.can_evolve(), "Tower level 1 should not be eligible for evolution")
	t.current_level = 3
	assert_true(t.can_evolve(), "Tower level 3 with evolution data should be eligible for evolution")

func test_apply_evolution_branch_a() -> void:
	var t = TowerBase.new()
	t.tower_type = "archer"
	t.current_level = 3
	t.evolution_data_a = {"name": "Снайпер", "damage": 85, "range": 350, "projectile_speed": 900, "special_ability": "crit_20"}
	t.evolution_data_b = {"name": "Пулемётчик", "damage": 18, "attack_speed": 6.5, "special_ability": "pierce_5"}
	
	var res = t.apply_evolution("evolution_a")
	assert_true(res, "apply_evolution branch A should succeed")
	assert_eq(t.current_level, 4, "Evolved tower must be level 4")
	assert_eq(t.evolution_chosen, "evolution_a", "evolution_chosen should be 'evolution_a'")
	assert_eq(t.tower_name, "Снайпер", "tower_name must match evolution A")
	assert_almost_eq(t.damage, 85.0, 0.01, "Damage should match evolution A")
	assert_almost_eq(t.range_radius, 350.0, 0.01, "Range should match evolution A")
	assert_eq(t.special_ability, "crit_20", "Special ability should be crit_20")
	
	assert_false(t.can_evolve(), "Already evolved tower must not be able to evolve again")
	assert_false(t.apply_evolution("evolution_b"), "Second evolution attempt must be rejected")

func test_apply_evolution_branch_b() -> void:
	var t = TowerBase.new()
	t.tower_type = "archer"
	t.current_level = 3
	t.evolution_data_a = {"name": "Снайпер", "damage": 85, "range": 350, "special_ability": "crit_20"}
	t.evolution_data_b = {"name": "Пулемётчик", "damage": 18, "attack_speed": 6.5, "pierce": 5, "special_ability": "pierce_5"}
	
	var res = t.apply_evolution("evolution_b")
	assert_true(res, "apply_evolution branch B should succeed")
	assert_eq(t.evolution_chosen, "evolution_b")
	assert_eq(t.tower_name, "Пулемётчик")
	assert_almost_eq(t.attack_speed, 6.5, 0.01)
	assert_eq(t.pierce_count, 5)

func test_build_spot_evolution_integration() -> void:
	var spot = BuildSpot.new()
	var t = TowerBase.new()
	t.tower_type = "archer"
	t.current_level = 3
	t.evolution_data_a = {"name": "Снайпер", "damage": 85}
	t.evolution_data_b = {"name": "Пулемётчик", "damage": 18}
	spot.add_child(t)
	spot.current_tower = t
	
	assert_true(spot.can_evolve_tower(), "Build spot with lvl 3 tower should report can_evolve_tower = true")
	var res = spot.evolve_tower("evolution_a")
	assert_true(res, "Build spot evolve_tower should succeed")
	assert_eq(t.current_level, 4)
	assert_false(spot.can_evolve_tower(), "Build spot after evolution should report can_evolve_tower = false")
	
	spot.queue_free()
