class_name TestBossAndSpecialEnemies
extends TestBase

const BossPhaseControllerClass = preload("res://scripts/boss_phase_controller.gd")

func test_boss_phase_shield_trigger() -> void:
	var m = MonsterBase.new()
	m.is_boss = true
	m.max_health = 1000.0
	m.current_health = 1000.0
	m.shield = 0.0
	
	var phases = [
		{"hp_threshold": 0.5, "effect": "gain_shield", "amount": 400.0}
	]
	m.boss_phase_controller = BossPhaseControllerClass.new(m, phases)
	
	# Damage down to 60% -> no trigger
	m.take_damage(400.0, "true")
	assert_almost_eq(m.current_health, 600.0, 0.01)
	assert_almost_eq(m.shield, 0.0, 0.01, "Shield should not trigger above threshold")
	
	# Damage down to 50% -> triggers shield!
	m.take_damage(100.0, "true")
	assert_almost_eq(m.shield, 400.0, 0.01, "Phase should grant 400 shield at 50% HP")
	
	m.queue_free()

func test_boss_phase_berserk_trigger() -> void:
	var m = MonsterBase.new()
	m.is_boss = true
	m.max_health = 1000.0
	m.current_health = 1000.0
	m.base_speed = 50.0
	m.speed = 50.0
	
	var phases = [
		{"hp_threshold": 0.3, "effect": "berserk", "speed_mult": 2.0}
	]
	m.boss_phase_controller = BossPhaseControllerClass.new(m, phases)
	
	m.take_damage(750.0, "true") # Health at 25% <= 30%
	assert_almost_eq(m.speed, 100.0, 0.01, "Speed must be multiplied by 2 in berserk phase")
	
	m.queue_free()

func test_burrower_invulnerability() -> void:
	var m = MonsterBase.new()
	m.max_health = 100.0
	m.current_health = 100.0
	
	m.enter_burrow(3.0)
	assert_gt(m.burrow_timer, 0.0)
	
	m.take_damage(50.0, "physical")
	assert_almost_eq(m.current_health, 100.0, 0.01, "Enemy should take 0 damage while burrowed")
	
	m.burrow_timer = 0.0
	m.take_damage(50.0, "physical")
	assert_almost_eq(m.current_health, 50.0, 0.01, "Enemy takes normal damage after burrow expires")
	
	m.queue_free()

func test_mirror_demon_reflection() -> void:
	var m = MonsterBase.new()
	m.max_health = 200.0
	m.current_health = 200.0
	m.reflect_ratio = 0.30
	
	var mock_tower = MonsterBase.new() # Can act as mock damageable node
	mock_tower.max_health = 100.0
	mock_tower.current_health = 100.0
	
	m.take_damage(100.0, "physical", mock_tower)
	assert_almost_eq(mock_tower.current_health, 70.0, 0.01, "Mock tower should receive 30 reflected damage")
	
	m.queue_free()
	mock_tower.queue_free()

func test_gold_thief_timer_expiry() -> void:
	var m = MonsterBase.new()
	m.gold_reward = 50
	m.gold_thief_timer = 1.0
	
	m._process(0.5)
	assert_eq(m.gold_reward, 50, "Gold thief should still have gold before timer expires")
	
	m._process(0.6)
	assert_eq(m.gold_reward, 0, "Gold thief gold must drop to 0 after timer expires")
	
	m.queue_free()
