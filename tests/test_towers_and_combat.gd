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

func test_tower_buffs_application_and_clean_expiration() -> void:
	var tower = TowerBase.new()
	tower.tower_type = "archer"
	tower.damage = 20.0
	tower.range_radius = 100.0
	tower.attack_speed = 1.0
	
	# Apply buffs
	tower.apply_buff("damage", 2.0, 1.5)
	tower.apply_buff("range", 2.0, 1.25)
	tower.apply_buff("attack_speed", 2.0, 2.0)
	
	assert_almost_eq(tower.get_effective_damage(), 30.0, 0.01, "Damage buff 1.5x should yield 30.0")
	assert_almost_eq(tower.get_effective_range(), 125.0, 0.01, "Range buff 1.25x should yield 125.0")
	assert_almost_eq(tower.get_effective_attack_speed(), 2.0, 0.01, "Attack speed buff 2.0x should yield 2.0")
	
	# Advance time halfway (1.0s) -> buffs still active
	tower._process(1.0)
	assert_almost_eq(tower.get_effective_damage(), 30.0, 0.01, "Buffs should persist before expiration")
	
	# Advance time past 2.0s total -> buffs expire cleanly
	tower._process(1.1)
	assert_almost_eq(tower.get_effective_damage(), 20.0, 0.01, "Damage should reset cleanly with no residual leak")
	assert_almost_eq(tower.get_effective_range(), 100.0, 0.01, "Range should reset cleanly with no residual leak")
	assert_almost_eq(tower.get_effective_attack_speed(), 1.0, 0.01, "Attack speed should reset cleanly with no residual leak")
	assert_false(tower.has_buff("damage"), "Buff should be expired")
	
	tower.free()

func test_tower_buff_refresh_and_stacking() -> void:
	var tower = TowerBase.new()
	tower.damage = 10.0
	
	# Apply buff twice with same multiplier -> should refresh duration, not double multiplier
	tower.apply_buff("damage", 2.0, 1.2)
	tower.apply_buff("damage", 5.0, 1.2)
	assert_almost_eq(tower.get_effective_damage(), 12.0, 0.01, "Identical buff refresh should not stack multiplier")
	
	# Apply distinct multiplier -> should stack multiplicatively
	tower.apply_buff("damage", 5.0, 1.5)
	assert_almost_eq(tower.get_effective_damage(), 18.0, 0.01, "Distinct buffs should stack multiplicatively (10 * 1.2 * 1.5)")
	
	tower.clear_buffs()
	assert_almost_eq(tower.get_effective_damage(), 10.0, 0.01, "clear_buffs() should immediately restore base damage")
	tower.free()

func test_projectile_and_targeting_dead_enemy_zero_crash() -> void:
	var proj = Projectile.new()
	var monster = MonsterBase.new()
	monster.current_health = 10.0
	proj.init_projectile(monster, 400.0, 15.0, "physical")
	
	# Monster dies before projectile impact
	monster.take_damage(50.0, "physical")
	assert_true(monster.is_dead, "Monster should be marked dead")
	
	# Process projectile flight step towards dead monster
	proj._process(0.1)
	proj._on_hit(monster)
	assert_true(true, "Projectile safely handled dead monster without crashing")
	
	proj.free()
	monster.free()

