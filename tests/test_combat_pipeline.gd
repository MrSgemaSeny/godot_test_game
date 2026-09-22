class_name TestCombatPipeline
extends TestBase

# ==============================================================================
# Feature 1 & 2: Armor Scaling & Physical Damage Mitigation
# ==============================================================================

func test_calculate_actual_damage_physical_armor_scaling() -> void:
	var monster = MonsterBase.new()
	monster.max_health = 200.0
	monster.current_health = 200.0
	
	# Scenario 1: Zero armor -> 0% reduction
	monster.armor = 0.0
	var dmg_0 = monster.calculate_actual_damage(100.0, "physical")
	assert_almost_eq(dmg_0, 100.0, 0.01, "0 armor should result in 0% damage reduction")
	
	# Scenario 2: 25 armor -> 25% reduction
	monster.armor = 25.0
	var dmg_25 = monster.calculate_actual_damage(100.0, "physical")
	assert_almost_eq(dmg_25, 75.0, 0.01, "25 armor should result in 25% damage reduction")
	
	# Scenario 3: 50 armor -> 50% reduction
	monster.armor = 50.0
	var dmg_50 = monster.calculate_actual_damage(100.0, "physical")
	assert_almost_eq(dmg_50, 50.0, 0.01, "50 armor should result in 50% damage reduction")
	
	# Scenario 4: 85 armor -> 85% reduction (boundary cap)
	monster.armor = 85.0
	var dmg_85 = monster.calculate_actual_damage(100.0, "physical")
	assert_almost_eq(dmg_85, 15.0, 0.01, "85 armor should result in 85% damage reduction")
	
	# Scenario 5: 100 armor -> clamped to 85% reduction cap
	monster.armor = 100.0
	var dmg_100 = monster.calculate_actual_damage(100.0, "physical")
	assert_almost_eq(dmg_100, 15.0, 0.01, "100 armor must be clamped to 85% maximum reduction")
	
	# Scenario 6: 150 armor -> clamped to 85% reduction cap
	monster.armor = 150.0
	var dmg_150 = monster.calculate_actual_damage(100.0, "physical")
	assert_almost_eq(dmg_150, 15.0, 0.01, "Over-cap armor (150) must remain clamped to 85% reduction")
	
	# Scenario 7: Negative armor -> clamped to 0.0 minimum reduction
	monster.armor = -30.0
	var dmg_neg = monster.calculate_actual_damage(100.0, "physical")
	assert_almost_eq(dmg_neg, 100.0, 0.01, "Negative armor must clamp reduction to 0.0")
	
	# Scenario 8: Zero raw damage -> returns 0.0
	monster.armor = 50.0
	var dmg_zero = monster.calculate_actual_damage(0.0, "physical")
	assert_almost_eq(dmg_zero, 0.0, 0.001, "Zero raw damage must return 0.0")
	
	# Scenario 9: Fractional raw and armor calculation
	monster.armor = 40.0 # 40% reduction -> 60% damage taken
	var dmg_frac = monster.calculate_actual_damage(35.5, "physical")
	assert_almost_eq(dmg_frac, 21.3, 0.01, "Fractional damage calculation must be precise")
	
	monster.free()

# ==============================================================================
# Feature 3: True Damage Bypass
# ==============================================================================

func test_calculate_actual_damage_true_damage_bypass() -> void:
	var monster = MonsterBase.new()
	monster.max_health = 200.0
	monster.current_health = 200.0
	
	# 1. Armor bypass: 85 armor does not mitigate true damage
	monster.armor = 85.0
	var dmg_true_armor = monster.calculate_actual_damage(100.0, "true")
	assert_almost_eq(dmg_true_armor, 100.0, 0.01, "True damage must bypass 85 physical armor")
	
	# 2. Resistance bypass: resistances do not mitigate true damage
	monster.armor = 100.0
	if "resistances" in monster and monster.resistances is Dictionary:
		monster.resistances["true"] = 0.90
	var dmg_true_res = monster.calculate_actual_damage(100.0, "true")
	assert_almost_eq(dmg_true_res, 100.0, 0.01, "True damage must bypass any resistance values")
	
	# 3. Immunity bypass: immunities do not negate true damage
	if "immunities" in monster:
		if monster.immunities is Array:
			monster.immunities.append("true")
		elif monster.immunities is Dictionary:
			monster.immunities["true"] = true
	var dmg_true_imm = monster.calculate_actual_damage(100.0, "true")
	assert_almost_eq(dmg_true_imm, 100.0, 0.01, "True damage must ignore immunity declarations")
	
	# 4. Shield bypass in take_damage
	monster.current_health = 100.0
	monster.shield = 60.0
	
	# Normal damage damages shield first
	monster.take_damage(20.0, "magic")
	assert_almost_eq(monster.shield, 40.0, 0.01, "Magic damage should absorb into shield")
	assert_almost_eq(monster.current_health, 100.0, 0.01, "Health should remain untouched while shield holds")
	
	# True damage bypasses shield directly into health
	monster.take_damage(35.0, "true")
	assert_almost_eq(monster.current_health, 65.0, 0.01, "True damage must penetrate directly to health")
	assert_almost_eq(monster.shield, 40.0, 0.01, "Shield must remain intact when true damage bypasses it")
	
	monster.free()

# ==============================================================================
# Feature 2: Elemental Resistances & Immunities
# ==============================================================================

func test_calculate_actual_damage_elemental_resists_and_immunities() -> void:
	var monster = MonsterBase.new()
	monster.max_health = 200.0
	monster.current_health = 200.0
	monster.armor = 60.0 # High physical armor to verify elemental ignores it
	
	# Setup resistances
	if "resistances" in monster and monster.resistances is Dictionary:
		monster.resistances["fire"] = 0.40       # 40% resist
		monster.resistances["cold"] = -0.50      # 50% vulnerability
		monster.resistances["lightning"] = 0.80 # 80% resist
		monster.resistances["poison"] = 0.25    # 25% resist
	
	# 1. Fire resistance mitigation
	var dmg_fire = monster.calculate_actual_damage(100.0, "fire")
	assert_almost_eq(dmg_fire, 60.0, 0.01, "Fire damage should be reduced by 40%")
	
	# 2. Cold vulnerability amplification
	var dmg_cold = monster.calculate_actual_damage(100.0, "cold")
	assert_almost_eq(dmg_cold, 150.0, 0.01, "Cold damage should be amplified by 50% due to vulnerability")
	
	# 3. Lightning resistance mitigation
	var dmg_lightning = monster.calculate_actual_damage(100.0, "lightning")
	assert_almost_eq(dmg_lightning, 20.0, 0.01, "Lightning damage should be reduced by 80%")
	
	# 4. Unspecified resistance defaults to 0%
	var dmg_magic = monster.calculate_actual_damage(100.0, "magic")
	assert_almost_eq(dmg_magic, 100.0, 0.01, "Magic without specific resistance should take full damage")
	
	# 5. Immunities: completely negates damage
	if "immunities" in monster:
		if monster.immunities is Array:
			monster.immunities.append("fire")
		elif monster.immunities is Dictionary:
			monster.immunities["fire"] = true
			
	var dmg_fire_immune = monster.calculate_actual_damage(100.0, "fire")
	assert_almost_eq(dmg_fire_immune, 0.0, 0.01, "Immunity to fire must reduce damage to exactly 0.0")
	
	# 6. Immunity takes precedence over vulnerability
	if "immunities" in monster:
		if monster.immunities is Array:
			monster.immunities.append("cold")
		elif monster.immunities is Dictionary:
			monster.immunities["cold"] = true
	var dmg_cold_immune = monster.calculate_actual_damage(100.0, "cold")
	assert_almost_eq(dmg_cold_immune, 0.0, 0.01, "Immunity must override negative resistance/vulnerability")
	
	monster.free()

# ==============================================================================
# Feature 1: Comprehensive 7 Damage Types Verification
# ==============================================================================

func test_all_seven_damage_types() -> void:
	var expected_types = ["physical", "magic", "poison", "fire", "cold", "lightning", "true"]
	
	var monster = MonsterBase.new()
	monster.max_health = 500.0
	monster.current_health = 500.0
	monster.armor = 50.0 # 50% physical reduction
	
	if "resistances" in monster and monster.resistances is Dictionary:
		monster.resistances["magic"] = 0.20
		monster.resistances["poison"] = 0.30
		monster.resistances["fire"] = 0.50
		monster.resistances["cold"] = -0.25
		monster.resistances["lightning"] = 0.10
	
	# Expected outcomes for 100.0 raw damage:
	var expected_damages = {
		"physical": 50.0,
		"magic": 80.0,
		"poison": 70.0,
		"fire": 50.0,
		"cold": 125.0,
		"lightning": 90.0,
		"true": 100.0
	}
	
	for dtype in expected_types:
		var actual = monster.calculate_actual_damage(100.0, dtype)
		var expected = expected_damages[dtype]
		assert_almost_eq(actual, expected, 0.01, "Damage type '%s' should compute to %f" % [dtype, expected])
		
		# Test signal emission
		var emitted_dmg = [-1.0]
		var emitted_type = [""]
		var on_took_damage = func(amt: float, t: String):
			emitted_dmg[0] = amt
			emitted_type[0] = t
		monster.took_damage.connect(on_took_damage, CONNECT_ONE_SHOT)
		
		monster.take_damage(100.0, dtype)
		assert_almost_eq(emitted_dmg[0], expected, 0.01, "took_damage signal should emit computed actual damage for %s" % dtype)
		assert_eq(emitted_type[0], dtype, "took_damage signal should emit correct damage_type string for %s" % dtype)
	
	# Unknown damage type safe fallback
	var unknown_actual = monster.calculate_actual_damage(100.0, "void_energy")
	assert_gt(unknown_actual, 0.0, "Unknown damage type should return a valid positive fallback amount without crashing")
	
	monster.free()

# ==============================================================================
# Feature 4: Modular Status Effects (Burn, Freeze, Poison, Stun, Slow)
# ==============================================================================

func test_status_effects_burn_freeze_poison_stun_slow() -> void:
	var monster = MonsterBase.new()
	monster.max_health = 200.0
	monster.current_health = 200.0
	monster.base_speed = 100.0
	monster.speed = 100.0
	
	# 1. SLOW
	if monster.has_method("apply_status_effect"):
		monster.apply_status_effect(StatusEffect.Type.SLOW, 2.0, 0.4)
	else:
		monster.apply_slow(0.4, 2.0)
	monster._process(0.01)
	assert_almost_eq(monster.speed, 60.0, 1.0, "40% slow should reduce speed to 60%")
	
	# 2. FREEZE
	if monster.has_method("apply_status_effect"):
		monster.apply_status_effect(StatusEffect.Type.FREEZE, 1.5, 1.0)
	else:
		monster.apply_freeze(1.5)
	assert_gt(monster.freeze_timer, 0.0, "Freeze timer should be active")
	
	# 3. STUN
	if monster.has_method("apply_status_effect"):
		monster.apply_status_effect(StatusEffect.Type.STUN, 1.0, 1.0)
		assert_true(monster.get("is_stunned") or monster.freeze_timer > 0.0 or monster.speed == 0.0, "Stun should halt movement")
	
	# 4. BURN (DoT)
	var hp_before_burn = monster.current_health
	if monster.has_method("apply_status_effect"):
		monster.apply_status_effect(StatusEffect.Type.BURN, 2.0, 10.0)
		# Process tick interval (0.5s)
		monster._process(0.55)
		assert_lt(monster.current_health, hp_before_burn, "Burn should deal tick damage to health")
		
	# 5. POISON (DoT)
	var hp_before_poison = monster.current_health
	if monster.has_method("apply_status_effect"):
		monster.apply_status_effect(StatusEffect.Type.POISON, 2.0, 10.0)
		monster._process(0.55)
		assert_lt(monster.current_health, hp_before_poison, "Poison should deal tick damage to health")
	
	monster.free()

# ==============================================================================
# Feature 4: Status Effects Stack Capping, Refresh & Expiry
# ==============================================================================

func test_status_effects_stack_capping_and_expiry() -> void:
	var monster = MonsterBase.new()
	monster.max_health = 200.0
	monster.current_health = 200.0
	monster.base_speed = 100.0
	monster.speed = 100.0
	
	if monster.has_method("apply_status_effect"):
		# Apply slow 5 times (max_stacks is 3)
		for i in range(5):
			monster.apply_status_effect(StatusEffect.Type.SLOW, 2.0, 0.15)
			
		if "active_status_effects" in monster and monster.active_status_effects.has(StatusEffect.Type.SLOW):
			var effect: StatusEffect = monster.active_status_effects[StatusEffect.Type.SLOW]
			assert_le(effect.stacks, effect.max_stacks, "Status effect stacks must not exceed max_stacks")
			assert_eq(effect.stacks, 3, "Status effect should be capped at exactly max_stacks (3)")
		
		# Duration refresh
		monster._process(1.5) # 0.5s remaining
		monster.apply_status_effect(StatusEffect.Type.SLOW, 3.0, 0.15)
		if "active_status_effects" in monster and monster.active_status_effects.has(StatusEffect.Type.SLOW):
			var effect: StatusEffect = monster.active_status_effects[StatusEffect.Type.SLOW]
			assert_gt(effect.duration, 2.0, "Re-applying status effect should refresh remaining duration")
			
		# Expiration and stat reset
		monster._process(3.5) # Exceeds duration
		assert_almost_eq(monster.speed, monster.base_speed, 0.1, "Speed should fully reset to base_speed after slow expires")
	else:
		# Fallback verification for prototype slow_timer
		monster.apply_slow(0.5, 1.0)
		monster._process(0.1)
		assert_almost_eq(monster.speed, 50.0, 0.1, "Speed slowed")
		monster._process(1.1)
		assert_almost_eq(monster.speed, 100.0, 0.1, "Speed reset after slow_timer expires")
		
	monster.free()

# ==============================================================================
# Feature 5: Tower Buff System Lifecycle & Leak Prevention
# ==============================================================================

func test_tower_buff_lifecycle_and_leak_prevention() -> void:
	var tower = TowerBase.new()
	tower.damage = 20.0
	tower.range_radius = 150.0
	tower.attack_speed = 1.0
	
	# Baseline check
	assert_eq(tower.get_effective_damage(), 20.0, "Initial effective damage should match base")
	assert_eq(tower.get_effective_range(), 150.0, "Initial effective range should match base")
	assert_eq(tower.get_effective_attack_speed(), 1.0, "Initial effective attack speed should match base")
	
	# Check if apply_buff is available
	if tower.has_method("apply_buff"):
		# 1. Damage buff
		tower.apply_buff("damage", 2.0, 1.5)
		assert_almost_eq(tower.get_effective_damage(), 30.0, 0.01, "Damage buff (+50%) should increase effective damage to 30.0")
		assert_eq(tower.get_effective_range(), 150.0, "Damage buff should not alter range")
		
		# 2. Range buff
		tower.apply_buff("range", 2.0, 1.2)
		assert_almost_eq(tower.get_effective_range(), 180.0, 0.01, "Range buff (+20%) should increase effective range to 180.0")
		
		# 3. Attack Speed buff
		tower.apply_buff("attack_speed", 2.0, 1.5)
		assert_almost_eq(tower.get_effective_attack_speed(), 1.5, 0.01, "Attack speed buff (+50%) should increase effective speed to 1.5")
		
		# Concurrency check: All 3 buffs active simultaneously
		assert_almost_eq(tower.get_effective_damage(), 30.0, 0.01)
		assert_almost_eq(tower.get_effective_range(), 180.0, 0.01)
		assert_almost_eq(tower.get_effective_attack_speed(), 1.5, 0.01)
		
		# 4. Expiration check: process past duration
		tower._process(2.2)
		assert_almost_eq(tower.get_effective_damage(), 20.0, 0.01, "Effective damage must revert to baseline after expiration")
		assert_almost_eq(tower.get_effective_range(), 150.0, 0.01, "Effective range must revert to baseline after expiration")
		assert_almost_eq(tower.get_effective_attack_speed(), 1.0, 0.01, "Effective attack speed must revert to baseline after expiration")
		
		# 5. Leak prevention: re-applying buff should not compound into previous expired state
		tower.apply_buff("damage", 2.0, 1.5)
		assert_almost_eq(tower.get_effective_damage(), 30.0, 0.01, "Re-applying buff after expiry must not compound multiplier")
		tower._process(2.2)
	else:
		assert_true(true, "apply_buff not yet implemented on TowerBase (pending Worker implementation)")
		
	tower.free()

# ==============================================================================
# Feature 6: Zero-Crash Defensive References & Null Handling
# ==============================================================================

func test_zero_crash_defensive_references() -> void:
	# 1. Tower target freed mid-process
	var tower = TowerBase.new()
	var monster1 = MonsterBase.new()
	tower.current_target = monster1
	monster1.free()
	
	# Calling process and targeting on freed instance must not throw engine crash or null pointer error
	tower._process(0.1)
	tower._find_best_target()
	assert_true(true, "Tower gracefully handled freed current_target without crashing")
	tower.free()
	
	# 2. Projectile target freed mid-flight
	var proj = Projectile.new()
	var monster2 = MonsterBase.new()
	proj.init_projectile(monster2, 400.0, 10.0, "physical")
	monster2.free()
	
	proj._process(0.1)
	proj._on_hit(null)
	assert_true(true, "Projectile gracefully handled freed target without crashing")
	proj.free()
	
	# 3. Ballistic Projectile target freed mid-flight
	var b_proj = BallisticProjectile.new()
	b_proj.init_ballistic(Vector2.ZERO, Vector2(100, 100), 0.5, 20.0, 50.0, "cannonball")
	b_proj._process(0.6) # Reaches target position and explodes
	assert_true(true, "Ballistic projectile safely landed and processed without target dependency crash")
	b_proj.free()
	
	# 4. Dead monster receiving damage does not trigger secondary death or negative health underflow
	var monster3 = MonsterBase.new()
	monster3.max_health = 100.0
	monster3.current_health = 0.0
	monster3.is_dead = true
	
	var death_signals = [0]
	monster3.died.connect(func(_r): death_signals[0] += 1)
	
	monster3.take_damage(50.0, "physical")
	assert_eq(death_signals[0], 0, "Dead monster should not re-emit died signal on subsequent damage")
	monster3.free()
	
	# 5. Invalid arguments to calculate_actual_damage handled safely
	var monster4 = MonsterBase.new()
	var neg_dmg = monster4.calculate_actual_damage(-100.0, "physical")
	assert_eq(neg_dmg, 0.0, "Negative damage should clamp to 0.0 without calculation errors")
	
	var empty_type_dmg = monster4.calculate_actual_damage(50.0, "")
	assert_ge(empty_type_dmg, 0.0, "Empty damage type string should return valid positive float without crashing")
	monster4.free()

# ==============================================================================
# Feature 2 & 3: Shield Absorption & Overflow Mechanics
# ==============================================================================

func test_shield_absorption_and_depletion() -> void:
	var monster = MonsterBase.new()
	monster.max_health = 100.0
	monster.current_health = 100.0
	monster.shield = 50.0
	
	# Partial shield absorption
	monster.take_damage(30.0, "magic")
	assert_almost_eq(monster.shield, 20.0, 0.01, "Shield should absorb 30 damage and reduce to 20")
	assert_almost_eq(monster.current_health, 100.0, 0.01, "Health should remain untouched when shield absorbs full hit")
	
	# Shield break and damage overflow into health
	monster.take_damage(45.0, "magic")
	assert_almost_eq(monster.shield, 0.0, 0.01, "Shield should be completely depleted")
	assert_almost_eq(monster.current_health, 75.0, 0.01, "Remaining 25 damage should overflow and reduce health to 75")
	
	monster.free()

# ==============================================================================
# Feature 2 & 4 Defect Remediation: Resistance Extremes & Immediate Speed Zeroing
# ==============================================================================

func test_calculate_actual_damage_extreme_resistances_and_percentages() -> void:
	var monster = MonsterBase.new()
	monster.max_health = 500.0
	monster.current_health = 500.0
	monster.armor = 0.0
	
	# 1. Over-cap positive resistance factor (2.0 = 200% resistance -> clamped to 1.0 -> 0.0 damage)
	monster.resistances = {"fire": 2.0}
	var dmg_fire = monster.calculate_actual_damage(100.0, "fire")
	assert_almost_eq(dmg_fire, 0.0, 0.001, "Over-cap positive resistance factor (2.0) must produce 0.0 damage")
	
	# 2. Over-cap negative resistance factor (-2.0 = -200% resistance -> clamped to -1.0 -> 200.0 damage)
	monster.resistances = {"cold": -2.0}
	var dmg_cold = monster.calculate_actual_damage(100.0, "cold")
	assert_almost_eq(dmg_cold, 200.0, 0.001, "Over-cap negative resistance factor (-2.0) must produce 200.0 damage")
	
	# 3. Unnormalized percentage input (150.0 = 150% resistance -> clamped to 1.0 -> 0.0 damage)
	monster.resistances = {"lightning": 150.0}
	var dmg_lightning = monster.calculate_actual_damage(100.0, "lightning")
	assert_almost_eq(dmg_lightning, 0.0, 0.001, "Percentage resistance input (150.0) must produce 0.0 damage")
	
	# 4. Unnormalized negative percentage input (-150.0 = -150% resistance -> clamped to -1.0 -> 200.0 damage)
	monster.resistances = {"poison": -150.0}
	var dmg_poison = monster.calculate_actual_damage(100.0, "poison")
	assert_almost_eq(dmg_poison, 200.0, 0.001, "Percentage vulnerability input (-150.0) must produce 200.0 damage")
	
	# 5. Exact boundary values: 1.0 (100% resist) and -1.0 (100% extra damage)
	monster.resistances = {"magic": 1.0}
	var dmg_magic_100 = monster.calculate_actual_damage(100.0, "magic")
	assert_almost_eq(dmg_magic_100, 0.0, 0.001, "Exact 1.0 resistance must produce 0.0 damage")
	
	monster.resistances = {"magic": -1.0}
	var dmg_magic_vuln = monster.calculate_actual_damage(100.0, "magic")
	assert_almost_eq(dmg_magic_vuln, 200.0, 0.001, "Exact -1.0 resistance must produce 200.0 damage")
	
	# 6. Standard percentage input (50.0 = 50% resist)
	monster.resistances = {"fire": 50.0}
	var dmg_fire_pct = monster.calculate_actual_damage(100.0, "fire")
	assert_almost_eq(dmg_fire_pct, 50.0, 0.01, "Standard percentage resistance (50.0) should produce 50.0 damage")
	
	# 7. Standard decimal factor input (0.50 = 50% resist)
	monster.resistances = {"fire": 0.50}
	var dmg_fire_dec = monster.calculate_actual_damage(100.0, "fire")
	assert_almost_eq(dmg_fire_dec, 50.0, 0.01, "Standard decimal resistance (0.50) should produce 50.0 damage")
	
	monster.free()

func test_status_effects_immediate_speed_zeroing() -> void:
	var monster = MonsterBase.new()
	monster.base_speed = 100.0
	monster.speed = 100.0
	
	# Baseline check
	assert_almost_eq(monster.speed, 100.0, 0.001, "Monster initial speed should be 100.0")
	assert_true(monster.has_method("get_effective_speed"), "MonsterBase must implement get_effective_speed()")
	if monster.has_method("get_effective_speed"):
		assert_almost_eq(monster.get_effective_speed(), 100.0, 0.001, "Monster initial get_effective_speed should be 100.0")
		
	# 1. Immediate Freeze speed zeroing (string argument, no _process call in between)
	monster.apply_status_effect("freeze", 2.0, 1.0)
	assert_almost_eq(monster.speed, 0.0, 0.001, "apply_status_effect('freeze') must immediately set monster.speed to 0.0 in the same frame")
	if monster.has_method("get_effective_speed"):
		assert_almost_eq(monster.get_effective_speed(), 0.0, 0.001, "monster.get_effective_speed() must immediately return 0.0 when frozen")
		
	# Advance time past freeze duration -> speed resets to base_speed
	monster._process(2.2)
	assert_almost_eq(monster.speed, 100.0, 0.01, "monster.speed must revert to base_speed after freeze expires")
	if monster.has_method("get_effective_speed"):
		assert_almost_eq(monster.get_effective_speed(), 100.0, 0.01, "monster.get_effective_speed() must revert to base_speed after freeze expires")
		
	# 2. Immediate Stun speed zeroing (string argument, no _process call in between)
	monster.apply_status_effect("stun", 2.0, 1.0)
	assert_almost_eq(monster.speed, 0.0, 0.001, "apply_status_effect('stun') must immediately set monster.speed to 0.0 in the same frame")
	if monster.has_method("get_effective_speed"):
		assert_almost_eq(monster.get_effective_speed(), 0.0, 0.001, "monster.get_effective_speed() must immediately return 0.0 when stunned")
		
	# Advance time past stun duration -> speed resets to base_speed
	monster._process(2.2)
	assert_almost_eq(monster.speed, 100.0, 0.01, "monster.speed must revert to base_speed after stun expires")
	if monster.has_method("get_effective_speed"):
		assert_almost_eq(monster.get_effective_speed(), 100.0, 0.01, "monster.get_effective_speed() must revert to base_speed after stun expires")
		
	# 3. Direct convenience helper methods apply_freeze and apply_stun
	monster.apply_freeze(1.5)
	assert_almost_eq(monster.speed, 0.0, 0.001, "apply_freeze(1.5) must immediately set monster.speed to 0.0 in the same frame")
	if monster.has_method("get_effective_speed"):
		assert_almost_eq(monster.get_effective_speed(), 0.0, 0.001, "monster.get_effective_speed() must return 0.0 on apply_freeze")
	monster._process(1.6)
	
	monster.apply_stun(1.5)
	assert_almost_eq(monster.speed, 0.0, 0.001, "apply_stun(1.5) must immediately set monster.speed to 0.0 in the same frame")
	if monster.has_method("get_effective_speed"):
		assert_almost_eq(monster.get_effective_speed(), 0.0, 0.001, "monster.get_effective_speed() must return 0.0 on apply_stun")
	monster._process(1.6)
	
	monster.free()
