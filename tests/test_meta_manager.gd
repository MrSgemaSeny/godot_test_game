class_name TestMetaManager
extends TestBase

var meta: MetaManager = null

func before_each() -> void:
	meta = MetaManager.new()
	meta.load_meta_tree_data()
	meta.glory_points = 0
	meta.upgrades = {}

func after_each() -> void:
	if is_instance_valid(meta):
		meta.reset_meta()
		meta.free()
		meta = null

func test_glory_points_addition() -> void:
	assert_eq(meta.glory_points, 0, "Initial glory points should be 0")
	meta.add_glory(50)
	assert_eq(meta.glory_points, 50, "Glory points should increase to 50")

func test_upgrade_purchase_and_levels() -> void:
	meta.add_glory(100)
	assert_eq(meta.get_level("meta_starting_gold"), 0, "Level before purchase should be 0")
	
	# Base cost is 15 for meta_starting_gold level 1
	var bought = meta.buy_upgrade("meta_starting_gold")
	assert_true(bought, "Upgrade purchase should succeed")
	assert_eq(meta.get_level("meta_starting_gold"), 1, "Level should now be 1")
	assert_eq(meta.get_starting_gold_bonus(), 50, "Level 1 starting gold bonus should be 50")
	
	# Try buying without enough points
	meta.glory_points = 0
	var failed_buy = meta.buy_upgrade("meta_starting_gold")
	assert_false(failed_buy, "Should fail to buy without glory points")
	assert_eq(meta.get_level("meta_starting_gold"), 1, "Level should remain 1")

func test_bonus_calculations() -> void:
	meta.upgrades["meta_starting_gold"] = 2
	meta.upgrades["meta_bonus_lives"] = 3
	meta.upgrades["meta_base_damage"] = 4
	meta.upgrades["meta_research_start"] = 2
	
	assert_eq(meta.get_starting_gold_bonus(), 100, "2 levels of gold bonus = 100g")
	assert_eq(meta.get_bonus_lives(), 15, "3 levels of bonus lives = 15 lives")
	assert_almost_eq(meta.get_base_damage_mult(), 0.32, 0.001, "4 levels of damage = +32%")
	assert_eq(meta.get_starting_research_bonus(), 2, "2 levels of research start = 2 points")
