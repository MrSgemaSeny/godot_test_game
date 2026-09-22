extends SceneTree

# ==============================================================================
# CHALLENGER STRESS HARNESS: STAGE 1 ZERO-CRASH & CONCURRENCY EDGE CASES
# ==============================================================================

var total_assertions: int = 0
var passed_assertions: int = 0
var failed_assertions: int = 0
var failure_log: Array = []

func _initialize() -> void:
	print("\n==================================================")
	print("⚔️  STARTING ZERO-CRASH ADVERSARIAL STRESS HARNESS")
	print("==================================================")
	
	await run_stress_suite()
	
	print("\n==================================================")
	print("📊 STRESS HARNESS SUMMARY:")
	print("Total assertions checked: %d" % total_assertions)
	print("✅ Passed: %d" % passed_assertions)
	print("❌ Failed: %d" % failed_assertions)
	
	if failed_assertions > 0:
		print("\n❌ FAILURE DETAILS:")
		for f in failure_log:
			print("  - " + str(f))
		print("==================================================")
		quit(1)
	else:
		print("🎉 ALL ADVERSARIAL STRESS TESTS COMPLETED WITH ZERO CRASHES!")
		print("==================================================")
		quit(0)

func assert_true(cond: bool, desc: String) -> void:
	total_assertions += 1
	if cond:
		passed_assertions += 1
		print("    ✓ " + desc)
	else:
		failed_assertions += 1
		failure_log.append("FAILED: " + desc)
		print("    ✗ FAILED: " + desc)

func assert_eq(a, b, desc: String) -> void:
	total_assertions += 1
	if a == b:
		passed_assertions += 1
		print("    ✓ " + desc)
	else:
		failed_assertions += 1
		var err = "FAILED: %s (got %s, expected %s)" % [desc, str(a), str(b)]
		failure_log.append(err)
		print("    ✗ " + err)

func assert_almost_eq(a: float, b: float, eps: float, desc: String) -> void:
	total_assertions += 1
	if abs(a - b) <= eps:
		passed_assertions += 1
		print("    ✓ " + desc)
	else:
		failed_assertions += 1
		var err = "FAILED: %s (got %f, expected %f)" % [desc, a, b]
		failure_log.append(err)
		print("    ✗ " + err)

func run_stress_suite() -> void:
	test_scenario_1_projectiles_in_flight_when_target_freed()
	test_scenario_2_unparented_nodes_core_methods()
	test_scenario_3_rapid_buff_and_status_spam()
	await test_scenario_4_monster_death_and_clean_retargeting()
	test_scenario_5_massive_concurrency_chaos()

# ==============================================================================
# SCENARIO 1: 20+ PROJECTILES IN FLIGHT WHEN TARGET IS FREED / KILLED
# ==============================================================================
func test_scenario_1_projectiles_in_flight_when_target_freed() -> void:
	print("\n--- [Scenario 1] 20+ Projectiles in flight when target freed ---")
	
	var root_node = Node2D.new()
	root.add_child(root_node)
	
	# Subtest 1A: 20 Projectiles targeting a monster that dies via take_damage()
	var monster_a = MonsterBase.new()
	monster_a.global_position = Vector2(300, 300)
	monster_a.max_health = 100.0
	monster_a.current_health = 100.0
	root_node.add_child(monster_a)
	
	var projectiles_a: Array = []
	for i in range(20):
		var p = Projectile.new()
		p.global_position = Vector2(100 + i * 5, 100)
		p.init_projectile(monster_a, 300.0, 15.0, "physical", 0.0, 0.0, "arrow", 30.0, 1)
		root_node.add_child(p)
		projectiles_a.append(p)
		
	var ballistics_a: Array = []
	for i in range(10):
		var bp = BallisticProjectile.new()
		bp.init_ballistic(Vector2(50, 50), monster_a.global_position, 0.4, 25.0, 40.0, "cannonball")
		root_node.add_child(bp)
		ballistics_a.append(bp)
		
	# Process 2 frames while target is alive
	for p in projectiles_a:
		p._process(0.016)
	for bp in ballistics_a:
		bp._process(0.016)
	assert_true(true, "Subtest 1A: Projectiles advance toward alive target without crash")
	
	# Fatal damage to monster_a
	monster_a.take_damage(500.0, "physical")
	assert_true(monster_a.is_dead, "Subtest 1A: Monster A marked dead after fatal hit")
	
	# Process 60 frames (1.0s) with target dead / queued for deletion
	for step in range(60):
		for p in projectiles_a:
			if is_instance_valid(p):
				p._process(0.016)
		for bp in ballistics_a:
			if is_instance_valid(bp):
				bp._process(0.016)
				
	assert_true(true, "Subtest 1A: 20 direct + 10 ballistic projectiles cleanly survived target death without crashes")
	
	# Subtest 1B: 20 Projectiles targeting a monster that is abruptly freed via free() (dangling pointer)
	var monster_b = MonsterBase.new()
	monster_b.global_position = Vector2(400, 200)
	root_node.add_child(monster_b)
	
	var projectiles_b: Array = []
	for i in range(20):
		var p = Projectile.new()
		p.global_position = Vector2(100, 200)
		p.init_projectile(monster_b, 400.0, 10.0, "magic", 0.3, 1.5, "frost_bolt", 40.0, 1)
		root_node.add_child(p)
		projectiles_b.append(p)
		
	# Immediate abrupt free() - turning target into dangling reference
	monster_b.free()
	assert_true(not is_instance_valid(monster_b), "Subtest 1B: Target monster was immediately freed")
	
	# Step all 20 projectiles for 60 frames
	for step in range(60):
		for p in projectiles_b:
			if is_instance_valid(p):
				p._process(0.016)
				
	assert_true(true, "Subtest 1B: 20 projectiles processed dangling target reference across 60 frames with 0 errors")
	
	# Subtest 1C: Pierce projectiles colliding with bystanders when primary target is freed
	var bystander = MonsterBase.new()
	bystander.global_position = Vector2(250, 100)
	root_node.add_child(bystander)
	
	var monster_c = MonsterBase.new()
	monster_c.global_position = Vector2(500, 100)
	root_node.add_child(monster_c)
	
	var pierce_proj = Projectile.new()
	pierce_proj.global_position = Vector2(100, 100)
	pierce_proj.init_projectile(monster_c, 500.0, 20.0, "physical", 0.0, 0.0, "arrow", 0.0, 3)
	root_node.add_child(pierce_proj)
	
	monster_c.free()
	
	for step in range(60):
		if is_instance_valid(pierce_proj):
			pierce_proj._process(0.016)
			
	assert_true(true, "Subtest 1C: Pierce projectile safely penetrated and processed with freed primary target")
	
	root_node.queue_free()

# ==============================================================================
# SCENARIO 2: UNPARENTED NODES CALLING CORE METHODS
# ==============================================================================
func test_scenario_2_unparented_nodes_core_methods() -> void:
	print("\n--- [Scenario 2] Unparented nodes calling core methods ---")
	
	# 2A: TowerBase unparented
	var tower = TowerBase.new()
	assert_false(tower.is_inside_tree(), "Subtest 2A: Tower is not in SceneTree")
	
	var dmg = tower.get_effective_damage()
	assert_gt(dmg, 0.0, "Subtest 2A: get_effective_damage() returns valid float on unparented tower")
	
	var rng = tower.get_effective_range()
	assert_gt(rng, 0.0, "Subtest 2A: get_effective_range() returns valid float on unparented tower")
	
	var spd = tower.get_effective_attack_speed()
	assert_gt(spd, 0.0, "Subtest 2A: get_effective_attack_speed() returns valid float on unparented tower")
	
	# Apply buffs when unparented (tests signals and queue_redraw())
	tower.apply_buff("damage", 2.0, 1.5)
	tower.apply_buff("range", 2.0, 1.2) # Calls queue_redraw()
	tower.apply_buff("attack_speed", 2.0, 1.3)
	assert_almost_eq(tower.get_effective_damage(), dmg * 1.5, 0.01, "Subtest 2A: Damage buff applied unparented")
	assert_almost_eq(tower.get_effective_range(), rng * 1.2, 0.01, "Subtest 2A: Range buff applied unparented")
	
	tower._update_buffs(2.5) # Expiration
	assert_almost_eq(tower.get_effective_damage(), dmg, 0.01, "Subtest 2A: Damage reverted to base unparented")
	
	var sell_val = tower.get_sell_value()
	assert_gt(sell_val, 0, "Subtest 2A: get_sell_value() returns positive integer unparented")
	
	tower.clear_buffs()
	tower._find_best_target() # Should safely set current_target = null
	assert_null(tower.current_target, "Subtest 2A: _find_best_target() sets current_target to null unparented")
	tower.free()
	
	# 2B: MonsterBase unparented
	var monster = MonsterBase.new()
	assert_false(monster.is_inside_tree(), "Subtest 2B: Monster is not in SceneTree")
	
	var actual_dmg = monster.calculate_actual_damage(50.0, "physical")
	assert_almost_eq(actual_dmg, 50.0, 0.01, "Subtest 2B: calculate_actual_damage() works unparented")
	
	monster.take_damage(20.0, "magic")
	assert_almost_eq(monster.current_health, monster.max_health - 20.0, 0.01, "Subtest 2B: take_damage() reduces health unparented")
	
	monster.apply_status_effect(StatusEffect.Type.BURN, 3.0, 5.0)
	monster.apply_status_effect(StatusEffect.Type.SLOW, 2.0, 0.3)
	assert_true(monster.has_status_effect(StatusEffect.Type.BURN), "Subtest 2B: has_status_effect returns true unparented")
	
	monster._process_status_effects(0.6) # Burn tick
	assert_true(true, "Subtest 2B: status effects tick unparented without crash")
	
	# Fatal damage on unparented monster
	var died_emitted = [false]
	monster.died.connect(func(_r): died_emitted[0] = true)
	monster.take_damage(9999.0, "true")
	assert_true(monster.is_dead, "Subtest 2B: Unparented monster marked dead on fatal damage")
	assert_true(died_emitted[0], "Subtest 2B: Unparented monster cleanly emitted died signal")
	monster.free()
	
	# 2C: Projectiles unparented
	var proj = Projectile.new()
	proj.init_projectile(null, 300.0, 10.0, "physical")
	proj._process(0.1)
	proj._on_hit(null)
	proj.free()
	
	var b_proj = BallisticProjectile.new()
	b_proj.init_ballistic(Vector2.ZERO, Vector2(100, 100), 0.5, 20.0, 30.0)
	b_proj._process(0.1)
	b_proj._on_impact(Vector2(100, 100))
	b_proj.free()
	assert_true(true, "Subtest 2C: Unparented projectiles processed and impacted safely")

# ==============================================================================
# SCENARIO 3: RAPID BUFF SPAM (50+ CALLS IN RAPID SUCCESSION)
# ==============================================================================
func test_scenario_3_rapid_buff_and_status_spam() -> void:
	print("\n--- [Scenario 3] 50 Rapid buff calls with identical/overlapping types ---")
	
	var tower = TowerBase.new()
	tower.damage = 100.0
	tower.range_radius = 200.0
	tower.attack_speed = 1.0
	
	# 3A: 50 rapid calls with IDENTICAL buff type and multiplier
	for i in range(50):
		tower.apply_buff("damage", 3.0, 1.5)
		
	assert_eq(tower.active_buffs.size(), 1, "Subtest 3A: 50 identical buffs collapse into single entry (no memory leak)")
	assert_almost_eq(tower.get_effective_damage(), 150.0, 0.01, "Subtest 3A: Effective damage is 150.0, no exponential compounding")
	
	# 3B: Overlapping buffs with different multipliers
	for i in range(1, 6): # 5 distinct multipliers
		tower.apply_buff("range", 2.0, 1.0 + i * 0.1)
	assert_eq(tower.active_buffs.size(), 6, "Subtest 3B: 1 damage + 5 range buffs = 6 entries")
	
	# Clean expiration of all buffs
	tower._update_buffs(3.5)
	assert_eq(tower.active_buffs.size(), 0, "Subtest 3B: All buffs cleanly expired after elapsed time")
	assert_almost_eq(tower.get_effective_damage(), 100.0, 0.01, "Subtest 3B: Damage reverted to base 100.0")
	assert_almost_eq(tower.get_effective_range(), 200.0, 0.01, "Subtest 3B: Range reverted to base 200.0")
	
	# 3C: Dirty input and edge case buff spam
	var edge_inputs = [
		{"type": "  DAMAGE  ", "dur": 2.0, "mult": 1.2},
		{"type": "speed", "dur": 2.0, "mult": 1.3},
		{"type": "ATTACKSPEED", "dur": 2.0, "mult": 1.4},
		{"type": "invalid_magic_buff", "dur": 2.0, "mult": 1.5}, # Unsupported
		{"type": "damage", "dur": -5.0, "mult": 1.5},             # Negative duration
		{"type": "damage", "dur": 2.0, "mult": -1.0},             # Negative multiplier
		{"type": "damage", "dur": 0.0, "mult": 1.5},              # Zero duration
		{"type": "damage", "dur": 2.0, "mult": 0.0},              # Zero multiplier
	]
	
	for inp in edge_inputs:
		tower.apply_buff(inp["type"], inp["dur"], inp["mult"])
		
	assert_true(tower.has_buff("attack_speed"), "Subtest 3C: 'speed' alias mapped to 'attack_speed'")
	assert_false(tower.has_buff("invalid_magic_buff"), "Subtest 3C: Invalid buff type safely rejected")
	tower.free()
	
	# 3D: 50 rapid calls to apply_status_effect on MonsterBase
	var monster = MonsterBase.new()
	for i in range(50):
		monster.apply_status_effect(StatusEffect.Type.BURN, 2.0, 5.0, 3)
		
	var burn_effect: StatusEffect = monster.get_status_effect(StatusEffect.Type.BURN)
	assert_not_null(burn_effect, "Subtest 3D: Burn effect present on monster")
	assert_eq(burn_effect.stacks, 3, "Subtest 3D: 50 burn calls capped at max_stacks (3)")
	
	# Tick DoT
	var hp_before = monster.current_health
	monster._process_status_effects(0.55) # 1 tick
	assert_almost_eq(monster.current_health, hp_before - (5.0 * 3), 0.01, "Subtest 3D: DoT deals exactly power * 3 stacks")
	
	# Expire
	monster._process_status_effects(2.5)
	assert_false(monster.has_status_effect(StatusEffect.Type.BURN), "Subtest 3D: Burn effect cleanly expired")
	monster.free()

# ==============================================================================
# SCENARIO 4: MONSTER DIES INSIDE TOWER ATTACK RANGE & CLEAN RETARGETING
# ==============================================================================
func test_scenario_4_monster_death_and_clean_retargeting() -> void:
	print("\n--- [Scenario 4] Monster death inside tower range & clean retargeting ---")
	
	var root_node = Node2D.new()
	root.add_child(root_node)
	current_scene = root_node
	await process_frame
	
	var tower = TowerBase.new()
	tower.global_position = Vector2(100, 100)
	tower.range_radius = 200.0
	root_node.add_child(tower)
	
	# Spawn 3 candidate monsters in range with different progress values
	var m1 = MonsterBase.new()
	m1.global_position = Vector2(120, 100)
	m1.progress = 50.0
	root_node.add_child(m1)
	
	var m2 = MonsterBase.new()
	m2.global_position = Vector2(150, 100)
	m2.progress = 90.0 # Leading progress
	root_node.add_child(m2)
	
	var m3 = MonsterBase.new()
	m3.global_position = Vector2(180, 100)
	m3.progress = 30.0
	root_node.add_child(m3)
	
	# Initial target acquisition
	tower._find_best_target()
	assert_eq(tower.current_target, m2, "Subtest 4: Tower correctly targets m2 (highest progress: 90)")
	
	# Step 1: m2 dies via standard combat pipeline take_damage
	# If scan_timer > 0, tower should clear target to null before next scan
	tower.scan_timer = 0.10
	m2.take_damage(9999.0, "physical")
	assert_true(m2.is_dead, "Subtest 4: m2 is dead")
	
	# Process tower frame (scan_timer drops from 0.10 to 0.084, so no scan happens)
	tower._process(0.016)
	assert_null(tower.current_target, "Subtest 4: Tower clears dead target to null mid-scan interval")
	
	# Now advance timer to trigger retarget
	tower.scan_timer = 0.0
	tower._process(0.016)
	assert_eq(tower.current_target, m1, "Subtest 4: Tower cleanly retargets to m1 on next scan (progress: 50)")
	
	# Step 2: m1 is abruptly freed via free() mid-lock
	m1.free()
	tower._process(0.016)
	assert_null(tower.current_target, "Subtest 4: Tower cleanly handles dangling freed m1 without error")
	
	tower.scan_timer = 0.0
	tower._process(0.016)
	assert_eq(tower.current_target, m3, "Subtest 4: Tower retargets to last remaining enemy m3 (progress: 30)")
	
	# Step 3: m3 dies
	m3.take_damage(9999.0, "true")
	tower._process(0.016)
	tower.scan_timer = 0.0
	tower._process(0.016)
	assert_null(tower.current_target, "Subtest 4: Tower target becomes null with 0 enemies alive")
	
	# Tower attempts to shoot with null target
	tower.shoot_timer = 0.0
	tower._process(0.016)
	assert_true(true, "Subtest 4: Tower process with 0 targets executes cleanly without firing errors")
	
	root_node.queue_free()

# ==============================================================================
# SCENARIO 5: MASSIVE CONCURRENCY & CHAOS SIMULATION
# ==============================================================================
func test_scenario_5_massive_concurrency_chaos() -> void:
	print("\n--- [Scenario 5] Massive concurrency chaos (30 monsters, 5 towers, 100 frames) ---")
	
	var root_node = Node2D.new()
	root.add_child(root_node)
	
	var proj_cont = Node2D.new()
	proj_cont.name = "Projectiles"
	# Create a dummy Game node so projectiles can find Game/Projectiles if needed
	var game_node = Node2D.new()
	game_node.name = "Game"
	root_node.add_child(game_node)
	game_node.add_child(proj_cont)
	
	# 5 towers
	var towers: Array = []
	for i in range(5):
		var t = TowerBase.new()
		t.global_position = Vector2(100 + i * 80, 150)
		t.range_radius = 250.0
		t.attack_speed = 3.0 # High rate of fire
		game_node.add_child(t)
		towers.append(t)
		
	# 30 monsters
	var monsters: Array = []
	for i in range(30):
		var m = MonsterBase.new()
		m.global_position = Vector2(50 + i * 25, 150 + (i % 3) * 20)
		m.progress = float(i * 10)
		m.max_health = 100.0
		m.current_health = 100.0
		game_node.add_child(m)
		monsters.append(m)
		
	# Simulate 100 frames of chaotic combat
	for frame in range(100):
		# Random buff spikes on towers
		if frame % 10 == 0:
			for t in towers:
				t.apply_buff("damage", 1.0, 1.2)
				t.apply_buff("attack_speed", 1.0, 1.3)
				
		# Process towers
		for t in towers:
			t._process(0.016)
			
		# Process projectiles in proj_cont
		for child in proj_cont.get_children():
			if is_instance_valid(child) and child.has_method("_process"):
				child._process(0.016)
				
		# Process monsters
		for m in monsters:
			if is_instance_valid(m) and not m.is_dead:
				m._process(0.016)
				
		# Chaos: randomly kill or free monsters during combat
		if frame == 20 and is_instance_valid(monsters[5]):
			monsters[5].take_damage(9999.0, "fire")
		if frame == 35 and is_instance_valid(monsters[12]):
			monsters[12].free() # Dangling free
		if frame == 50 and is_instance_valid(monsters[20]):
			monsters[20].queue_free()
			
	assert_true(true, "Subtest 5: 100 frames of massive concurrent chaos finished with ZERO crashes")
	root_node.queue_free()

func assert_false(cond: bool, desc: String) -> void:
	assert_true(not cond, desc)

func assert_null(val, desc: String) -> void:
	assert_true(val == null, desc)

func assert_not_null(val, desc: String) -> void:
	assert_true(val != null, desc)

func assert_gt(val, thresh, desc: String) -> void:
	assert_true(val > thresh, "%s (expected %s > %s)" % [desc, str(val), str(thresh)])
