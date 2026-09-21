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
	var instance = scene.instantiate()
	assert_not_null(instance, "tech_tree_modal.tscn must instantiate")
	instance.free()

func test_instantiate_game_scene() -> void:
	var scene = load("res://scenes/game.tscn")
	assert_not_null(scene, "game.tscn must load")
	var instance = scene.instantiate()
	assert_not_null(instance, "game.tscn must instantiate")
	assert_not_null(instance.get_node_or_null("CanvasLayer/HUD"), "HUD must exist in Game scene")
	assert_not_null(instance.get_node_or_null("GameManager"), "GameManager must exist in Game scene")
	assert_not_null(instance.get_node_or_null("SpellSystem"), "SpellSystem must exist in Game scene")
	assert_not_null(instance.get_node_or_null("TechTreeManager"), "TechTreeManager must exist in Game scene")
	assert_not_null(instance.get_node_or_null("MetaManager"), "MetaManager must exist in Game scene")
	instance.free()
