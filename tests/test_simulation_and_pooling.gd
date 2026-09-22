class_name TestSimulationAndPooling
extends TestBase

const ObjectPoolClass = preload("res://scripts/object_pool.gd")
const HeadlessSimulatorClass = preload("res://scripts/headless_simulator.gd")

func test_object_pool_lifecycle() -> void:
	var pool = ObjectPoolClass.new(null, 5, 20)
	assert_eq(pool.get_available_count(), 5, "Pool must start with 5 prewarmed objects")
	assert_eq(pool.get_active_count(), 0)
	
	# Acquire object
	var obj1 = pool.acquire()
	assert_true(obj1 != null)
	assert_eq(pool.get_available_count(), 4)
	assert_eq(pool.get_active_count(), 1)
	
	# Release object
	pool.release(obj1)
	assert_eq(pool.get_available_count(), 5)
	assert_eq(pool.get_active_count(), 0)
	
	pool.clear()

func test_headless_simulator_ttk_and_winnability() -> void:
	# TTK for 100 HP, 0 armor, 50 DPS -> 2.0s
	var ttk_normal = HeadlessSimulatorClass.calculate_ttk(100.0, 0.0, {}, 50.0, "physical")
	assert_almost_eq(ttk_normal, 2.0, 0.01)
	
	# TTK for 100 HP, 50 armor (reduces DPS by 50% to 25) -> 4.0s
	var ttk_armored = HeadlessSimulatorClass.calculate_ttk(100.0, 50.0, {}, 50.0, "physical")
	assert_almost_eq(ttk_armored, 4.0, 0.01)
	
	# Winnability test
	var enemies = [
		{"health": 100.0},
		{"health": 100.0},
		{"health": 100.0}
	]
	var res_winnable = HeadlessSimulatorClass.simulate_wave_winnable(enemies, 100.0, 10.0)
	assert_true(res_winnable["is_winnable"], "300 HP vs 100 DPS over 10s path should be winnable")
	
	var res_unwinnable = HeadlessSimulatorClass.simulate_wave_winnable(enemies, 10.0, 5.0)
	assert_false(res_unwinnable["is_winnable"], "300 HP vs 10 DPS over 5s path should be unwinnable")
