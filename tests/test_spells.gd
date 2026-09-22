class_name TestSpells
extends TestBase

var spell_sys: SpellSystem = null

func before_each() -> void:
	spell_sys = SpellSystem.new()
	spell_sys._load_spells_data()
	spell_sys.current_mana = 100
	spell_sys.max_mana = 100
	spell_sys.cooldowns.clear()

func after_each() -> void:
	if is_instance_valid(spell_sys):
		spell_sys.free()
		spell_sys = null

func test_mana_addition_and_cap() -> void:
	spell_sys.current_mana = 50
	spell_sys.add_mana(30)
	assert_eq(spell_sys.current_mana, 80, "Mana should be 80 after add_mana(30)")
	spell_sys.add_mana(50)
	assert_eq(spell_sys.current_mana, 100, "Mana should not exceed max_mana")

func test_can_cast_and_mana_cost() -> void:
	assert_true(spell_sys.can_cast("meteor"), "Should be able to cast meteor with 100 mana")
	spell_sys.current_mana = 5
	assert_false(spell_sys.can_cast("meteor"), "Should not be able to cast meteor with insufficient mana")

func test_cast_cooldown_trigger() -> void:
	spell_sys.current_mana = 100
	var success = spell_sys.cast_spell("freeze")
	assert_true(success, "Freeze cast should succeed")
	assert_gt(spell_sys.cooldowns.get("freeze", 0.0), 0.0, "Cooldown should be set after casting")
	assert_false(spell_sys.can_cast("freeze"), "Cannot cast again immediately while on cooldown")
	
	# Simulate cooldown elapsing
	spell_sys._process(30.0)
	assert_le(spell_sys.cooldowns.get("freeze", 0.0), 0.0, "Cooldown should expire after time")

func test_all_eight_spells_present() -> void:
	var required = ["meteor", "freeze", "gold_rain", "lightning", "vortex", "roots", "chronoshift", "stone_wall"]
	for s_id in required:
		assert_true(spell_sys.spells_data.has(s_id), "Spells data must contain %s" % s_id)
		var s = spell_sys.spells_data[s_id]
		assert_gt(int(s.get("mana_cost", 0)), 0, "%s mana_cost must be > 0" % s_id)
		assert_gt(float(s.get("cooldown", 0.0)), 0.0, "%s cooldown must be > 0.0" % s_id)
		assert_true(s.has("damage_type"), "%s must define damage_type" % s_id)
		assert_true(s.has("effect_type"), "%s must define effect_type" % s_id)

func test_cast_new_spells() -> void:
	var new_spells = ["vortex", "roots", "chronoshift", "stone_wall"]
	for s_id in new_spells:
		spell_sys.current_mana = 100
		spell_sys.cooldowns.clear()
		assert_true(spell_sys.can_cast(s_id), "Should be able to cast %s with full mana" % s_id)
		var res = spell_sys.cast_spell(s_id, Vector2(100, 100))
		assert_true(res, "Casting %s should succeed" % s_id)
		assert_gt(spell_sys.cooldowns.get(s_id, 0.0), 0.0, "%s should set cooldown" % s_id)

