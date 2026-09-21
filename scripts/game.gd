class_name Game
extends Node2D

@onready var game_manager: GameManager = $GameManager
@onready var meta_manager: MetaManager = $MetaManager
@onready var tech_tree_manager: TechTreeManager = $TechTreeManager
@onready var spell_system: SpellSystem = $SpellSystem
@onready var hud: GameHUD = $CanvasLayer/HUD
@onready var path2d: Path2D = $Path2D
@onready var build_spots_container: Node2D = $BuildSpots
@onready var enemies_container: Node2D = $Path2D
@onready var projectiles_container: Node2D = $Projectiles
@onready var girls_container: Node2D = $Girls
@onready var interactive_container: Node2D = $InteractiveObjects

var monster_script = preload("res://scripts/monster_base.gd")
var girl_script = preload("res://scripts/girl_npc.gd")
var map_obj_script = preload("res://scripts/interactive_map_obj.gd")

var active_enemies: int = 0
var wave_in_progress: bool = false
var auto_start_timer: float = 0.0
var is_counting_down: bool = false
var total_girls: int = 5

func _ready() -> void:
	game_manager.set_chosen_path(GlobalState.selected_path)
	
	_setup_signals()
	_setup_path()
	_setup_build_spots()
	_setup_interactive_objects()
	_start_new_game()

func _setup_signals() -> void:
	game_manager.gold_changed.connect(hud.update_gold)
	game_manager.lives_changed.connect(_on_lives_changed)
	game_manager.wave_changed.connect(hud.update_wave)
	game_manager.state_changed.connect(_on_game_state_changed)
	game_manager.tower_selection_changed.connect(hud.show_spot_panel)
	
	spell_system.mana_changed.connect(hud.update_mana)
	tech_tree_manager.research_points_changed.connect(hud.update_research_points)
	
	hud.start_wave_pressed.connect(_on_start_wave_pressed)
	hud.restart_pressed.connect(_start_new_game)

func _setup_path() -> void:
	# Сказочная извилистая дорожка через Кудрявую Долину
	var curve = Curve2D.new()
	curve.add_point(Vector2(-30, 200))
	curve.add_point(Vector2(200, 200))
	curve.add_point(Vector2(200, 380))
	curve.add_point(Vector2(460, 380))
	curve.add_point(Vector2(460, 190))
	curve.add_point(Vector2(700, 190))
	curve.add_point(Vector2(700, 470))
	curve.add_point(Vector2(880, 470)) # Деревня девочек!
	path2d.curve = curve

func _setup_build_spots() -> void:
	for child in build_spots_container.get_children():
		child.queue_free()
		
	var spot_positions = [
		Vector2(120, 130),
		Vector2(275, 290),
		Vector2(120, 455),
		Vector2(380, 455),
		Vector2(380, 120),
		Vector2(545, 120),
		Vector2(545, 270),
		Vector2(620, 270),
		Vector2(620, 545),
		Vector2(780, 390),
		Vector2(780, 545),
		Vector2(840, 290)
	]
	
	for pos in spot_positions:
		var spot = Area2D.new()
		spot.set_script(preload("res://scripts/build_spot.gd"))
		spot.position = pos
		spot.clicked.connect(_on_spot_clicked)
		build_spots_container.add_child(spot)

func _setup_interactive_objects() -> void:
	for child in interactive_container.get_children():
		child.queue_free()
		
	# Размещаем взрывные бочки и сундук с золотом у дороги
	var barrel_positions = [Vector2(210, 290), Vector2(460, 280), Vector2(700, 330)]
	for pos in barrel_positions:
		var barrel = Area2D.new()
		barrel.set_script(map_obj_script)
		barrel.object_type = "barrel"
		barrel.position = pos
		interactive_container.add_child(barrel)
		
	var chest = Area2D.new()
	chest.set_script(map_obj_script)
	chest.object_type = "chest"
	chest.position = Vector2(870, 380)
	interactive_container.add_child(chest)

func _setup_girls() -> void:
	for child in girls_container.get_children():
		child.queue_free()
		
	var village_center = Vector2(880, 470)
	for i in range(total_girls):
		var girl = Node2D.new()
		girl.set_script(girl_script)
		girl.position = village_center + Vector2(randf_range(-25, 25), randf_range(-25, 25))
		girl.add_to_group("girls")
		girl.rescued.connect(_on_girl_rescued)
		girls_container.add_child(girl)
		
	hud.update_girls_count(total_girls)

func _start_new_game() -> void:
	for child in enemies_container.get_children():
		if child is MonsterBase or child is EnemyBase:
			child.queue_free()
	for child in projectiles_container.get_children():
		child.queue_free()
		
	for spot in build_spots_container.get_children():
		if spot is BuildSpot and spot.has_tower():
			spot.sell_tower()
			
	active_enemies = 0
	wave_in_progress = false
	is_counting_down = false
	
	game_manager.reset_game()
	_setup_girls()
	_setup_interactive_objects()
	hud.end_screen.visible = false
	_start_intermission_timer()

func _process(delta: float) -> void:
	if is_counting_down:
		auto_start_timer -= delta
		if auto_start_timer <= 0.0:
			is_counting_down = false
			_start_wave()

func _start_intermission_timer() -> void:
	if game_manager.current_wave >= GameManager.TOTAL_WAVES:
		return
	auto_start_timer = GameManager.PRE_WAVE_TIME
	is_counting_down = true
	hud.set_countdown(auto_start_timer)
	hud.set_wave_button_enabled(true)

func _on_start_wave_pressed() -> void:
	if is_counting_down and auto_start_timer > 0.0:
		var bonus = int(game_manager.gold * 0.10)
		if bonus > 0:
			game_manager.add_gold(bonus)
	_start_wave()

func _start_wave() -> void:
	if wave_in_progress:
		return
		
	is_counting_down = false
	wave_in_progress = true
	hud.stop_countdown()
	hud.set_wave_button_enabled(false)
	
	game_manager.current_wave += 1
	game_manager.wave_changed.emit(game_manager.current_wave, GameManager.TOTAL_WAVES)
	game_manager.set_state(GameManager.GameState.WAVE_IN_PROGRESS)
	game_manager.on_wave_started()
	
	var wave_idx = game_manager.current_wave - 1
	if wave_idx < game_manager.waves_data.size():
		var wave_cfg = game_manager.waves_data[wave_idx]
		_spawn_wave_groups(wave_cfg.get("spawn_groups", []))
	else:
		_spawn_fallback_wave(game_manager.current_wave)

func _spawn_wave_groups(groups: Array) -> void:
	var total_to_spawn = 0
	for g in groups:
		total_to_spawn += g.get("count", 0)
	active_enemies = total_to_spawn
	
	for group in groups:
		var enemy_type = group.get("enemy_type", "spiky")
		var count = group.get("count", 5)
		var interval = group.get("interval", 1.0)
		var delay = group.get("delay", 0.0)
		_spawn_group_coroutine(enemy_type, count, interval, delay)

func _spawn_group_coroutine(enemy_type: String, count: int, interval: float, delay: float) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
		
	for i in range(count):
		if game_manager.game_state == GameManager.GameState.GAME_OVER:
			return
		_spawn_monster(enemy_type)
		if i < count - 1:
			await get_tree().create_timer(interval).timeout

func _spawn_fallback_wave(wave_num: int) -> void:
	var count = 6 + wave_num * 3
	active_enemies = count
	for i in range(count):
		if game_manager.game_state == GameManager.GameState.GAME_OVER:
			return
		_spawn_monster("spiky")
		await get_tree().create_timer(1.0).timeout

func _spawn_monster(enemy_type: String) -> void:
	var monster = PathFollow2D.new()
	monster.set_script(monster_script)
	monster.monster_type = enemy_type
	monster.add_to_group("enemies")
	
	monster.died.connect(_on_monster_died)
	monster.escaped_with_girl.connect(_on_monster_escaped)
	
	path2d.add_child(monster)

func _on_monster_died(reward: int) -> void:
	game_manager.add_gold(reward)
	_check_monster_count()

func _on_monster_escaped() -> void:
	_check_monster_count()

func _on_girl_rescued(_girl: GirlNPC) -> void:
	_update_girls_ui()

func _on_lives_changed(_new_lives: int) -> void:
	_update_girls_ui()

func _update_girls_ui() -> void:
	var free_girls = 0
	for g in girls_container.get_children():
		if is_instance_valid(g) and g.current_state != GirlNPC.State.BEING_CARRIED:
			free_girls += 1
	hud.update_girls_count(free_girls)

func _check_monster_count() -> void:
	active_enemies = max(0, active_enemies - 1)
	if active_enemies == 0 and wave_in_progress:
		wave_in_progress = false
		tech_tree_manager.add_points(1)
		
		var end_bonus = tech_tree_manager.get_end_wave_bonus_gold()
		if end_bonus > 0:
			game_manager.add_gold(end_bonus)
			
		if game_manager.current_wave >= GameManager.TOTAL_WAVES:
			game_manager.set_state(GameManager.GameState.VICTORY)
		else:
			game_manager.set_state(GameManager.GameState.BUILDING)
			_start_intermission_timer()

func _on_game_state_changed(state: GameManager.GameState) -> void:
	if state == GameManager.GameState.GAME_OVER:
		wave_in_progress = false
		is_counting_down = false
		hud.show_game_over(false)
	elif state == GameManager.GameState.VICTORY:
		wave_in_progress = false
		is_counting_down = false
		hud.show_game_over(true)

func _on_spot_clicked(spot: BuildSpot) -> void:
	for child in build_spots_container.get_children():
		if child is BuildSpot and child != spot:
			child.set_selected(false)
			
	spot.set_selected(true)
	game_manager.select_spot(spot)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		for child in build_spots_container.get_children():
			if child is BuildSpot:
				child.set_selected(false)
		game_manager.select_spot(null)

func _draw() -> void:
	# Сказочный изумрудный газон Кудрявой Долины
	draw_rect(Rect2(0, 0, 960, 640), Color(0.24, 0.48, 0.22))
	
	# Холмы и цветочные поляны
	var hill_col = Color(0.28, 0.55, 0.25)
	draw_circle(Vector2(90, 60), 90, hill_col)
	draw_circle(Vector2(340, 70), 130, hill_col)
	draw_circle(Vector2(660, 80), 140, hill_col)
	draw_circle(Vector2(110, 580), 120, hill_col)
	draw_circle(Vector2(550, 590), 150, hill_col)
	
	# Дорожка из желтого песка и камешков
	if path2d and path2d.curve:
		var baked_points = path2d.curve.get_baked_points()
		if baked_points.size() > 1:
			draw_polyline(baked_points, Color(0.55, 0.45, 0.25), 50.0)
			draw_polyline(baked_points, Color(0.85, 0.75, 0.45), 38.0)
			draw_polyline(baked_points, Color(0.75, 0.65, 0.35), 14.0)
			
	# Логово монстров (пещера слева)
	draw_rect(Rect2(-20, 160, 50, 80), Color(0.18, 0.12, 0.1))
	var font = ThemeDB.get_fallback_font()
	if font:
		draw_string(font, Vector2(8, 155), "ЛОГОВО МОНСТРОВ", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.95, 0.3, 0.3))
	
	# Сказочная деревня девочек справа
	draw_rect(Rect2(830, 420, 120, 110), Color(0.35, 0.65, 0.3)) # Заборчик
	# Домик 1
	draw_rect(Rect2(850, 410, 45, 40), Color(0.8, 0.7, 0.55))
	draw_polygon(PackedVector2Array([Vector2(845, 410), Vector2(872, 385), Vector2(900, 410)]), PackedColorArray([Color(0.85, 0.25, 0.2), Color(0.85, 0.25, 0.2), Color(0.85, 0.25, 0.2)]))
	# Домик 2
	draw_rect(Rect2(905, 460, 40, 35), Color(0.75, 0.65, 0.5))
	draw_polygon(PackedVector2Array([Vector2(900, 460), Vector2(925, 440), Vector2(950, 460)]), PackedColorArray([Color(0.3, 0.5, 0.8), Color(0.3, 0.5, 0.8), Color(0.3, 0.5, 0.8)]))
	
	if font:
		draw_string(font, Vector2(840, 375), "ДОМИК ДЕВОЧЕК", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.9, 0.3))
