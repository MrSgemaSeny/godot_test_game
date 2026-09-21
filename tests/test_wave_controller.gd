class_name TestWaveController
extends TestBase

const WaveControllerScript = preload("res://scripts/wave_controller.gd")
const MonsterScript = preload("res://scripts/monster_base.gd")

func test_wave_controller_initial_state() -> void:
	var wc = WaveControllerScript.new()
	wc.load_waves_data()
	
	assert_gt(wc.get_total_waves(), 0, "WaveController should load waves")
	assert_eq(wc.current_wave_index, 0, "Initial wave index should be 0")
	assert_false(wc.is_wave_active, "Wave should not be active initially")
	
	wc.free()

func test_wave_countdown_and_start() -> void:
	var wc = WaveControllerScript.new()
	wc.load_waves_data()
	
	var started_emitted = [false]
	wc.wave_started.connect(func(w_num, _total, _is_boss): started_emitted[0] = (w_num == 1))
	
	wc.start_current_wave()
	assert_true(wc.is_wave_active, "Wave should be active after start")
	assert_true(started_emitted[0], "wave_started signal should emit wave 1")
	assert_gt(wc.total_to_spawn, 0, "Wave 1 should have enemies to spawn")
	
	wc.free()

func test_wave_completion_via_finished_counter() -> void:
	var wc = WaveControllerScript.new()
	wc.load_waves_data()
	
	var completed_wave = [0]
	wc.wave_completed.connect(func(w_num, _is_last): completed_wave[0] = w_num)
	
	wc.start_current_wave()
	var needed = wc.total_to_spawn
	
	# Simulate all enemies spawned and finished
	wc.spawned_count = needed
	for i in range(needed):
		wc.register_enemy_finished(MonsterScript.EnemyOutcome.KILLED, 10)
		
	assert_eq(completed_wave[0], 1, "Wave 1 should be completed when finished_count == total_to_spawn")
	assert_false(wc.is_wave_active, "Wave should not be active after completion")
	assert_eq(wc.current_wave_index, 1, "Wave index should increment to 1")
	
	wc.free()

