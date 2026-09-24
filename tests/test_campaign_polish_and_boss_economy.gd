class_name TestCampaignPolishAndBossEconomy
extends TestBase

const CampaignManagerScript = preload("res://scripts/campaign_manager.gd")
const EconomyManagerScript = preload("res://scripts/economy_manager.gd")

var cm: Node = null
var em: Node = null

func before_each() -> void:
	cm = CampaignManagerScript.new()
	em = EconomyManagerScript.new()

func after_each() -> void:
	if is_instance_valid(cm):
		cm.free()
		cm = null
	if is_instance_valid(em):
		em.free()
		em = null

func test_boss_reward_choices() -> void:
	em.initialize(350, 1)
	
	var chosen_signal_fired: Array = []
	em.boss_reward_chosen.connect(func(id): chosen_signal_fired.append(id))
	
	# Выбор A: Королевская Казна
	var res_a = em.grant_boss_reward("treasury")
	assert_eq(res_a.get("glory"), 150, "Treasury must grant 150 glory")
	assert_eq(res_a.get("next_stage_gold_bonus"), 100, "Treasury must grant 100 gold bonus")
	assert_eq(chosen_signal_fired.size(), 1)
	assert_eq(chosen_signal_fired[0], "treasury")
	
	# Выбор B: Печать Мастера
	var res_b = em.grant_boss_reward("master_seal")
	assert_eq(res_b.get("glory"), 100, "Master seal must grant 100 glory")
	assert_eq(float(res_b.get("damage_buff")), 0.10, "Master seal must grant 10% damage buff")
	assert_eq(chosen_signal_fired.size(), 2)
	assert_eq(chosen_signal_fired[1], "master_seal")
	
	# Проверка транзакций
	var log_entries = em.get_transaction_log()
	var boss_rewards_logged = 0
	for e in log_entries:
		if e.get("action") == "BOSS_REWARD":
			boss_rewards_logged += 1
	assert_eq(boss_rewards_logged, 2, "Both boss rewards must be recorded in transaction log")

func test_relic_trade_offs_bounties_and_rewards() -> void:
	em.initialize(350, 1)
	
	# 1. Hunter's Mark relic: +30% elite bounty, -10% standard bounty
	em.apply_relic_trade_offs(["hunters_mark"])
	var standard_bounty = em.calculate_kill_bounty(10, "standard", 1.0)
	var elite_bounty = em.calculate_kill_bounty(30, "elite", 1.0)
	
	# Base standard with role mult 1.0 * 0.9 = 9
	assert_eq(standard_bounty, 9, "Hunter's Mark must reduce standard bounty by 10%")
	# Base elite with role mult 2.2 * 30 = 66 * 1.30 = 85.8 -> ceil is 86
	assert_eq(elite_bounty, 86, "Hunter's Mark must increase elite bounty by 30%")
	
	# 2. Emergency Reserve relic: +60 starting gold, -5% interest (in Chapter 3)
	em.initialize(300, 3)
	em.apply_relic_trade_offs(["emergency_reserve"])
	assert_eq(em.starting_gold, 360, "Emergency Reserve must grant +60 starting gold")
	assert_eq(em.current_gold, 360, "Current gold must match updated starting gold")
	
	# With 360 gold in chapter 3, tier is 300+ (15% base rate) - 5% penalty = 10% rate
	var rate = em.get_current_interest_rate()
	assert_true(is_equal_approx(rate, 0.10), "Interest rate must be reduced by 5% (from 15% to 10%)")

func test_campaign_next_stage_coords() -> void:
	# Progression inside Chapter 1
	var c1_next = cm.get_next_stage_coords(1, 1)
	assert_eq(c1_next.get("chapter_num"), 1)
	assert_eq(c1_next.get("stage_num"), 2)
	assert_false(c1_next.get("is_final"))
	
	# Progression at end of Chapter 1 (10 stages) -> should go to Chapter 2 stage 1
	var c1_end_next = cm.get_next_stage_coords(1, 10)
	assert_eq(c1_end_next.get("chapter_num"), 2)
	assert_eq(c1_end_next.get("stage_num"), 1)
	assert_false(c1_end_next.get("is_final"))
	
	# Progression at end of Chapter 2 (10 stages) -> Chapter 3 stage 1
	var c2_end_next = cm.get_next_stage_coords(2, 10)
	assert_eq(c2_end_next.get("chapter_num"), 3)
	assert_eq(c2_end_next.get("stage_num"), 1)
	
	# Progression at end of Chapter 3 (12 stages) -> Chapter 4 stage 1
	var c3_end_next = cm.get_next_stage_coords(3, 12)
	assert_eq(c3_end_next.get("chapter_num"), 4)
	assert_eq(c3_end_next.get("stage_num"), 1)
	
	# Progression at end of Chapter 4 (12 stages) -> Chapter 5 stage 1
	var c4_end_next = cm.get_next_stage_coords(4, 12)
	assert_eq(c4_end_next.get("chapter_num"), 5)
	assert_eq(c4_end_next.get("stage_num"), 1)
	
	# Final stage of campaign (Chapter 5 stage 15) -> is_final = true
	var c5_final = cm.get_next_stage_coords(5, 15)
	assert_true(c5_final.get("is_final"), "Final stage of campaign must report is_final = true")

const EconomyHUDWidgetScript = preload("res://scripts/economy_hud_widget.gd")

func test_hud_briefing_and_boss_modal_flow() -> void:
	var ew = EconomyHUDWidgetScript.new()
	ew.setup(em)
	
	# Show stage briefing
	var st_info = {
		"chapter_num": 1,
		"stage_num": 1,
		"name": "Первый рубеж",
		"biome": "plains",
		"max_tower_level": 3,
		"start_gold": 350,
		"economy_profile": "standard",
		"wave_count": 10
	}
	ew.show_stage_briefing(st_info)
	assert_true(is_instance_valid(ew.stage_briefing_modal))
	assert_true(ew.stage_briefing_modal.visible, "Briefing modal must be visible after show_stage_briefing")
	
	# Show boss choice modal
	ew.show_boss_choice()
	assert_true(is_instance_valid(ew.boss_choice_modal))
	assert_true(ew.boss_choice_modal.visible, "Boss choice modal must be visible after show_boss_choice")
	
	# Simulate boss choice selection
	var reward_picked = []
	ew.boss_reward_selected.connect(func(c_id): reward_picked.append(c_id))
	ew._on_boss_reward_picked("treasury")
	assert_false(ew.boss_choice_modal.visible, "Boss choice modal must hide on pick")
	assert_eq(reward_picked.size(), 1)
	assert_eq(reward_picked[0], "treasury")
	
	ew.free()

