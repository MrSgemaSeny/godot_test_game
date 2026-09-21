class_name TestInteractiveObjects
extends TestBase

func test_barrel_initialization_and_activation() -> void:
	var barrel = InteractiveMapObj.new()
	barrel.object_type = "barrel"
	barrel.damage = 250.0
	barrel.radius = 120.0
	
	var exploded_called = [false]
	barrel.exploded.connect(func(_p, _d, _r): exploded_called[0] = true)
	
	barrel.activate()
	assert_true(barrel.is_activated, "Barrel should be marked activated")
	assert_true(exploded_called[0], "exploded signal must be emitted on activation")
	barrel.free()

func test_chest_activation() -> void:
	var chest = InteractiveMapObj.new()
	chest.object_type = "chest"
	chest.gold_reward = 50
	
	chest.activate()
	assert_true(chest.is_activated, "Chest should be marked activated")
	chest.free()
