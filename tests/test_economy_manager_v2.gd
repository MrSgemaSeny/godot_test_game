class_name TestEconomyManagerV2
extends TestBase

const EconomyManagerScript = preload("res://scripts/economy_manager.gd")
const EconomySimulatorScript = preload("res://scripts/economy_simulator.gd")

var econ: Node = null

func before_each() -> void:
	econ = EconomyManagerScript.new()

func after_each() -> void:
	if is_instance_valid(econ):
		econ.free()
		econ = null

func test_interest_calculation_and_tiers() -> void:
	# Ch 3: interest active
	econ.initialize(350, 3)
	assert_true(econ.interest_enabled, "Interest should be enabled in Chapter 3")
	
	# Tier 0: < 100g -> 0%
	assert_eq(econ.calculate_interest(80), 0, "0-99g should yield 0 interest")
	
	# Tier 1: 100-199g -> 5%
	assert_eq(econ.calculate_interest(100), 5, "100g at 5% should yield 5")
	assert_eq(econ.calculate_interest(180), 9, "180g at 5% should yield 9")
	
	# Tier 2: 200-299g -> 10%
	assert_eq(econ.calculate_interest(200), 20, "200g at 10% should yield 20")
	assert_eq(econ.calculate_interest(250), 25, "250g at 10% should yield 25")
	
	# Tier 3: 300+g -> 15% (max bonus 30)
	assert_eq(econ.calculate_interest(300), 30, "300g at 15% should yield 30 (cap)")
	assert_eq(econ.calculate_interest(500), 30, "500g at 15% should be capped at 30")
	
	# Ch 1: interest disabled
	econ.initialize(350, 1)
	assert_false(econ.interest_enabled, "Interest should be disabled in Chapter 1")
	assert_eq(econ.calculate_interest(300), 0, "Interest should be 0 when disabled")

func test_transaction_logging_and_auditing() -> void:
	econ.initialize(300, 3)
	var logs = econ.get_transaction_log()
	assert_ge(logs.size(), 1, "Initial starting gold must be logged")
	assert_eq(logs[0]["action"], "START_GOLD")
	assert_eq(logs[0]["balance_after"], 300)
	
	# Spend gold
	var spent = econ.spend_gold(100, "build", "Постройка лучника")
	assert_true(spent)
	assert_eq(econ.current_gold, 200)
	assert_eq(econ.get_transaction_log().size(), 2)
	assert_eq(econ.get_transaction_log()[1]["action"], "-BUILD")
	assert_eq(econ.get_transaction_log()[1]["amount"], -100)
	assert_eq(econ.get_transaction_log()[1]["balance_after"], 200)
	
	# Add income
	econ.add_gold(50, "bounty", "Убийство элиты")
	assert_eq(econ.current_gold, 250)
	var formatted = econ.get_formatted_log_strings()
	assert_eq(formatted.size(), 3)
	assert_true(formatted[2].contains("Банк: 250"), "Formatted string should contain current bank")

func test_wave_rewards_and_scaling() -> void:
	econ.initialize(300, 1)
	# Chapter 1 wave reward: (30 + 1 * 4) * 1.0 = 34
	var r1 = econ.calculate_wave_reward(1, 1)
	assert_eq(r1, 34)
	
	# Chapter 5 wave reward: (30 + 10 * 4) * 1.5 = 70 * 1.5 = 105
	var r5 = econ.calculate_wave_reward(10, 5)
	assert_eq(r5, 105)
	
	# Perfect wave: 0 damage
	var pw_bonus = econ.evaluate_perfect_wave(1, 0, 0)
	assert_gt(pw_bonus, 0, "Perfect wave with 0 damage must grant bonus gold")
	
	# Imperfect wave: lost life
	var pw_fail = econ.evaluate_perfect_wave(1, 1, 0)
	assert_eq(pw_fail, 0, "Imperfect wave must grant 0 bonus")

func test_contracts_system_flow() -> void:
	econ.initialize(300, 2)
	assert_true(econ.contracts_enabled, "Contracts should be enabled in Chapter 2")
	
	var available = econ.get_available_contracts(2)
	assert_le(available.size(), 2)
	assert_gt(available.size(), 0)
	
	var c_id = available[0]["id"]
	var accepted = econ.accept_contract(c_id)
	assert_true(accepted, "Contract acceptance must succeed")
	assert_false(econ.active_contract.is_empty(), "Active contract should be populated")
	
	var mods = econ.get_active_contract_modifiers()
	assert_true(mods.has("hp_mult"))
	assert_true(mods.has("kill_bounty_mult"))
	
	# Complete contract
	var reward = econ.resolve_contract(true)
	assert_gt(reward, 0, "Successful contract resolution must yield bonus gold")
	assert_true(econ.active_contract.is_empty(), "Active contract should be cleared after resolve")

func test_enemy_roles_and_kill_bounties() -> void:
	econ.initialize(300, 3)
	
	var standard_bounty = econ.calculate_kill_bounty(10, "standard", 1.0)
	var elite_bounty = econ.calculate_kill_bounty(10, "elite", 1.0)
	var boss_bounty = econ.calculate_kill_bounty(10, "boss", 1.0)
	
	assert_eq(standard_bounty, 10)
	assert_gt(elite_bounty, standard_bounty, "Elite bounty should be higher than standard")
	assert_gt(boss_bounty, elite_bounty, "Boss bounty should be highest")
	
	# Thief theft mechanics
	var gold_before = econ.current_gold
	var stolen = econ.register_gold_stolen(0.04)
	assert_gt(stolen, 0, "Thief should steal positive gold")
	assert_eq(econ.current_gold, gold_before - stolen)
	
	# Tax collector refund
	var refund = econ.refund_stolen_gold(stolen)
	assert_ge(refund, stolen, "Tax collector refund should return full stolen gold + compensation")

func test_tower_sell_value_and_losses() -> void:
	econ.initialize(300, 1)
	var sell_val = econ.calculate_sell_value(200, 0.0)
	# 200 * 0.65 = 130
	assert_eq(sell_val, 130)
	
	var sold = econ.register_tower_sold(200, 0.0, "Башня мага")
	assert_eq(sold, 130)
	assert_eq(int(econ.stats["sell_losses"]), 70)

func test_comeback_and_emergency_cache() -> void:
	econ.initialize(300, 1)
	
	# Life lost comeback bonus
	var cb = econ.register_life_lost(15)
	assert_gt(cb, 0, "Life lost should grant comeback gold")
	
	# Critical life: emergency cache trigger
	var g_before = econ.current_gold
	econ.register_life_lost(4)
	assert_true(econ.emergency_cache_used)
	assert_gt(econ.current_gold, g_before, "Emergency cache should add substantial gold")

func test_economic_simulator_all_archetypes_and_campaign() -> void:
	var camp_file = FileAccess.open("res://data/campaign.json", FileAccess.READ)
	assert_not_null(camp_file)
	var json = JSON.new()
	assert_eq(json.parse(camp_file.get_as_text()), OK)
	var camp_data: Dictionary = json.data
	
	var stress_report = EconomySimulatorScript.run_multi_archetype_stress_test(camp_data)
	assert_true(stress_report.get("all_archetypes_viable", false), "All economic archetypes must be viable")
	assert_eq(int(stress_report.get("tested_archetypes", 0)), 5)
