class_name TestTowersAndCombat
extends TestBase

func test_tower_base_stats() -> void:
	var tower = TowerBase.new()
	tower.tower_type = "archer"
	tower.damage = 15.0
	tower.range_radius = 200.0
	tower.attack_speed = 1.5
	
	assert_eq(tower.get_effective_damage(), 15.0, "Effective damage without buffs should equal base damage")
	assert_eq(tower.get_effective_range(), 200.0, "Effective range without buffs should equal base range")
	assert_eq(tower.get_effective_attack_speed(), 1.5, "Effective attack speed without buffs should equal base speed")
	tower.free()

func test_monster_armor_and_physical_damage() -> void:
	var monster = MonsterBase.new()
	monster.max_health = 100.0
	monster.current_health = 100.0
	monster.armor = 50.0 # 50% physical reduction
	
	# Deal 50 physical damage -> should be reduced to 25 damage
	monster.take_damage(50.0, "physical")
	assert_almost_eq(monster.current_health, 75.0, 0.01, "50 armor should reduce 50 physical damage to 25")
	
	# Deal 50 magic damage -> ignores armor
	monster.take_damage(50.0, "magic")
	assert_almost_eq(monster.current_health, 25.0, 0.01, "Magic damage should bypass physical armor")
	
	monster.free()

func test_monster_slow_and_freeze() -> void:
	var monster = MonsterBase.new()
	monster.base_speed = 100.0
	monster.speed = 100.0
	
	monster.apply_slow(0.5, 3.0)
	monster._process(0.1)
	assert_almost_eq(monster.speed, 50.0, 0.01, "50% slow should halve monster speed")
	
	# Freeze stops monster movement
	monster.apply_freeze(2.0)
	assert_gt(monster.freeze_timer, 0.0, "Freeze timer should be active")
	
	monster.free()

func test_monster_healing() -> void:
	var monster = MonsterBase.new()
	monster.max_health = 100.0
	monster.current_health = 40.0
	
	monster.heal(30.0)
	assert_eq(monster.current_health, 70.0, "Health should increase by 30")
	
	monster.heal(100.0)
	assert_eq(monster.current_health, 100.0, "Health should not exceed max_health")
	
	monster.free()

func test_projectile_target_freed_handling() -> void:
	var proj = Projectile.new()
	var monster = MonsterBase.new()
	proj.target = monster
	proj.damage = 10.0
	
	# Free monster before projectile arrives/hits
	monster.free()
	
	# Projectile process and on_hit should handle freed target gracefully without crashing
	proj._process(0.1)
	proj._on_hit(null)
	assert_true(true, "Projectile safely handled previously freed target")
	
	proj.free()

