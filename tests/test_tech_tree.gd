class_name TestTechTree
extends TestBase

var tech: TechTreeManager = null

func before_each() -> void:
	tech = TechTreeManager.new()
	tech.load_tech_data()

func after_each() -> void:
	if is_instance_valid(tech):
		tech.free()
		tech = null

func test_points_addition_and_reset() -> void:
	assert_eq(tech.research_points, 0, "Initial research points should be 0")
	tech.add_points(3)
	assert_eq(tech.research_points, 3, "Points should be 3 after add_points(3)")
	tech.reset_tree(5)
	assert_eq(tech.research_points, 5, "Points should reset to given initial amount")
	assert_eq(tech.unlocked_nodes.size(), 0, "Unlocked nodes should be cleared on reset")

func test_prerequisites_and_unlock() -> void:
	tech.add_points(1)
	# defense_2 requires defense_1
	assert_false(tech.can_unlock("defense_2"), "Cannot unlock defense_2 without defense_1")
	assert_true(tech.can_unlock("defense_1"), "Can unlock defense_1 with 1 point")
	
	var success = tech.unlock_node("defense_1")
	assert_true(success, "defense_1 unlock should succeed")
	assert_eq(tech.research_points, 0, "1 point should be consumed")
	assert_true(tech.is_unlocked("defense_1"), "defense_1 should be marked unlocked")
	assert_almost_eq(tech.get_damage_bonus(), 0.12, 0.001, "Damage bonus should now be 12%")

func test_mutual_exclusion_blocking() -> void:
	tech.add_points(10)
	tech.unlock_node("defense_1")
	
	# Unlocking defense_2 should block econ_2
	tech.unlock_node("defense_2")
	assert_true(tech.is_blocked("econ_2"), "econ_2 should now be blocked")
	
	# Try unlocking econ_1 and then blocked econ_2
	tech.unlock_node("econ_1")
	assert_false(tech.can_unlock("econ_2"), "Cannot unlock blocked econ_2")
	assert_false(tech.unlock_node("econ_2"), "unlock_node on blocked node must fail")

func test_modifier_calculations() -> void:
	tech.add_points(10)
	assert_almost_eq(tech.get_cost_discount(), 0.0, 0.001, "Initial discount should be 0%")
	assert_eq(tech.get_end_wave_bonus_gold(), 0, "Initial end wave gold should be 0")
	
	tech.unlock_node("special_1")
	assert_almost_eq(tech.get_cost_discount(), 0.15, 0.001, "Discount should be 15%")
	
	tech.unlock_node("econ_1")
	assert_almost_eq(tech.get_gold_reward_mult(), 0.20, 0.001, "Gold mult should be 20%")
