class_name TestGameManager
extends TestBase

var gm: GameManager = null

func before_each() -> void:
	gm = GameManager.new()
	gm.load_all_data()

func after_each() -> void:
	if is_instance_valid(gm):
		gm.free()
		gm = null

func test_initial_values() -> void:
	assert_eq(gm.gold, GameManager.BASE_GOLD, "Starting gold should be BASE_GOLD")
	assert_eq(gm.lives, GameManager.BASE_LIVES, "Starting lives should be BASE_LIVES")
	assert_eq(gm.current_wave, 0, "Starting wave should be 0")
	assert_eq(gm.game_state, GameManager.GameState.BUILDING, "Initial state should be BUILDING")

func test_add_and_spend_gold() -> void:
	var initial_gold = gm.gold
	gm.add_gold(50)
	assert_eq(gm.gold, initial_gold + 50, "Gold should increase after add_gold")
	
	var spend_success = gm.spend_gold(100)
	assert_true(spend_success, "spend_gold should return true when sufficient gold")
	assert_eq(gm.gold, initial_gold - 50, "Gold should decrease after spend_gold")
	
	var spend_fail = gm.spend_gold(10000)
	assert_false(spend_fail, "spend_gold should return false when insufficient gold")
	assert_eq(gm.gold, initial_gold - 50, "Gold should remain unchanged on failed spend")

func test_reduce_lives_and_game_over() -> void:
	gm.reduce_lives(5)
	assert_eq(gm.lives, GameManager.BASE_LIVES - 5, "Lives should decrease by 5")
	assert_eq(gm.game_state, GameManager.GameState.BUILDING, "State should still be BUILDING")
	
	gm.reduce_lives(GameManager.BASE_LIVES)
	assert_eq(gm.lives, 0, "Lives should not go below 0")
	assert_eq(gm.game_state, GameManager.GameState.GAME_OVER, "State should transition to GAME_OVER")

func test_path_selection() -> void:
	gm.set_chosen_path("magic")
	assert_eq(gm.selected_path, "magic", "Selected path should be magic")
	var towers = gm.get_available_towers()
	assert_gt(towers.size(), 0, "Magic path should have available towers")
	assert_true(towers.has("ice_mage"), "Magic path should include ice_mage")

func test_reset_game() -> void:
	gm.add_gold(300)
	gm.reduce_lives(10)
	gm.set_state(GameManager.GameState.GAME_OVER)
	
	gm.reset_game()
	assert_eq(gm.gold, GameManager.BASE_GOLD, "Gold should reset")
	assert_eq(gm.lives, GameManager.BASE_LIVES, "Lives should reset")
	assert_eq(gm.game_state, GameManager.GameState.BUILDING, "State should reset to BUILDING")
	assert_eq(gm.current_wave, 0, "Wave should reset to 0")
