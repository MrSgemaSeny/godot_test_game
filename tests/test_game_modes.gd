class_name TestGameModes
extends TestBase

const ChallengeManagerClass = preload("res://scripts/challenge_manager.gd")
const NightmareControllerClass = preload("res://scripts/nightmare_controller.gd")
const EndlessControllerClass = preload("res://scripts/endless_controller.gd")

func test_challenges_database_and_activation() -> void:
	var cm = ChallengeManagerClass.new()
	assert_eq(cm.CHALLENGES_DB.size(), 20, "Must have exactly 20 challenges")
	assert_true(cm.CHALLENGES_DB.has("no_magic"))
	assert_true(cm.CHALLENGES_DB.has("ironman"))
	
	assert_false(cm.is_challenge_active())
	assert_true(cm.start_challenge("no_magic"))
	assert_true(cm.is_challenge_active())
	assert_true(cm.has_mutator("disable_spells"))
	assert_false(cm.has_mutator("one_life"))
	
	cm.stop_challenge()
	assert_false(cm.is_challenge_active())
	cm.queue_free()

func test_nightmare_mode_rules() -> void:
	var nc = NightmareControllerClass.new()
	assert_false(nc.is_nightmare_active)
	assert_eq(nc.get_max_lives(), 5)
	assert_almost_eq(nc.get_starting_gold_multiplier(), 1.0, 0.01)
	assert_almost_eq(nc.get_enemy_hp_multiplier(), 1.0, 0.01)
	assert_true(nc.is_tech_tree_allowed())
	
	nc.enable_nightmare()
	assert_true(nc.is_nightmare_active)
	assert_eq(nc.get_max_lives(), 1, "Nightmare mode must enforce 1 life")
	assert_almost_eq(nc.get_starting_gold_multiplier(), 0.50, 0.01, "Gold must be halved in nightmare")
	assert_almost_eq(nc.get_enemy_hp_multiplier(), 1.50, 0.01, "HP must be 1.5x in nightmare")
	assert_false(nc.is_tech_tree_allowed(), "Tech tree must be disabled in nightmare")
	
	var reward = nc.record_victory()
	assert_eq(reward, "infinity_stone")
	nc.queue_free()

func test_endless_mode_scaling() -> void:
	var ec = EndlessControllerClass.new()
	ec.start_endless(25)
	assert_true(ec.is_endless_active)
	
	var w1 = ec.generate_next_wave()
	assert_eq(w1["wave_number"], 26)
	assert_gt(w1["spawns"].size(), 10)
	
	# Simulate 5 waves up to boss wave 30
	for i in range(4):
		ec.generate_next_wave()
		
	var w_boss = ec.generate_next_wave() # wave 31, wait
	assert_gt(w_boss["difficulty_scale"], 1.0, "Difficulty scale must increase")
	
	ec.record_kill(25)
	assert_eq(ec.enemies_killed, 1)
	assert_eq(ec.gold_earned, 25)
	
	var result = ec.finish_endless()
	assert_false(ec.is_endless_active)
	assert_true(result["is_new_record"])
	assert_gt(result["final_wave"], 25)
	
	ec.queue_free()
