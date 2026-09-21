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
