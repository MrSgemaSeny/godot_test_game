class_name TestSceneIntegration
extends TestBase

func test_instantiate_main_menu() -> void:
	var scene = load("res://scenes/main_menu.tscn")
	assert_not_null(scene, "main_menu.tscn must load")
	var instance = scene.instantiate()
	assert_not_null(instance, "main_menu.tscn must instantiate")
	instance.free()

func test_instantiate_path_select() -> void:
	var scene = load("res://scenes/path_select.tscn")
	assert_not_null(scene, "path_select.tscn must load")
	var instance = scene.instantiate()
	assert_not_null(instance, "path_select.tscn must instantiate")
	instance.free()

func test_instantiate_meta_tree() -> void:
	var scene = load("res://scenes/meta_tree.tscn")
	assert_not_null(scene, "meta_tree.tscn must load")
	var instance = scene.instantiate()
	assert_not_null(instance, "meta_tree.tscn must instantiate")
	instance.free()

func test_instantiate_tech_tree_modal() -> void:
	var scene = load("res://scenes/tech_tree_modal.tscn")
	assert_not_null(scene, "tech_tree_modal.tscn must load")
	var instance = scene.instantiate() as TechTreeModal
	assert_not_null(instance, "tech_tree_modal.tscn must instantiate")
	
	# Test opening modal and rendering cards without crashing
	var tech_manager = TechTreeManager.new()
	tech_manager.load_tech_data()
	tech_manager.add_to_group("tech_tree_manager")
	instance.tech_tree = tech_manager
	
	# Add to dummy tree node to initialize @onready nodes
	var root = Node.new()
	root.add_child(instance)
	instance.open_modal()
	assert_true(instance.visible, "Modal should be visible when opened")
	
	root.free()
	tech_manager.free()


func test_instantiate_game_scene() -> void:
	var scene = load("res://scenes/game.tscn")
	assert_not_null(scene, "game.tscn must load")
	var instance = scene.instantiate()
	assert_not_null(instance, "game.tscn must instantiate")
	assert_not_null(instance.get_node_or_null("CanvasLayer/HUD"), "HUD must exist in Game scene")
	assert_not_null(instance.get_node_or_null("CanvasLayer/HUD/TopBar/MarginContainer/HBoxContainer/WaveClock"), "WaveClock must exist in Game scene")
	assert_not_null(instance.get_node_or_null("GameManager"), "GameManager must exist in Game scene")
	assert_not_null(instance.get_node_or_null("SpellSystem"), "SpellSystem must exist in Game scene")
	assert_not_null(instance.get_node_or_null("TechTreeManager"), "TechTreeManager must exist in Game scene")
	assert_not_null(instance.get_node_or_null("MetaManager"), "MetaManager must exist in Game scene")
	instance.free()

func test_wave_clock_widget() -> void:
	var clock = WaveClock.new()
	clock.set_countdown(20.0, 30.0, false)
	assert_eq(clock.time_left, 20.0, "Clock time_left should be 20")
	assert_true(clock.is_active, "Clock should be active")
	
	var clicked_emitted = [false]
	clock.clicked.connect(func(): clicked_emitted[0] = true)
	clock.clicked.emit()
	assert_true(clicked_emitted[0], "Clock clicked signal should work")
	clock.free()
