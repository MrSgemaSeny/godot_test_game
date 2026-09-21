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
var scene_anim_time: float = 0.0

# Процедурные декоративные элементы
var flower_patches: Array = []
var trees: Array = []

func _ready() -> void:
	game_manager.set_chosen_path(GlobalState.selected_path)
	_generate_decorations()
	_setup_signals()
	_setup_path()
	_setup_build_spots()
	_setup_interactive_objects()
	_start_new_game()

func _generate_decorations() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 42 # Фиксированный красивый сид
	
	flower_patches.clear()
	for i in range(40):
		var pos = Vector2(rng.randf_range(60, 1220), rng.randf_range(80, 680))
		var col_type = rng.randi_range(0, 3)
		var col = Color(1.0, 1.0, 1.0) # Ромашки
		if col_type == 1:
			col = Color(0.95, 0.25, 0.3) # Маки
		elif col_type == 2:
			col = Color(0.35, 0.65, 1.0) # Незабудки
		elif col_type == 3:
			col = Color(1.0, 0.85, 0.2) # Лютики
		flower_patches.append({"pos": pos, "col": col, "size": rng.randf_range(2.5, 4.0)})
		
	trees.clear()
	var tree_positions = [
		Vector2(140, 100), Vector2(280, 90), Vector2(740, 100), Vector2(880, 95),
		Vector2(100, 640), Vector2(320, 650), Vector2(580, 660), Vector2(760, 650),
		Vector2(1180, 200), Vector2(1200, 320), Vector2(560, 360)
	]
	for tp in tree_positions:
		trees.append({"pos": tp, "scale": rng.randf_range(0.9, 1.25)})

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
	# Красивый извилистый маршрут через всю карту 1280x720
	var curve = Curve2D.new()
	curve.add_point(Vector2(-40, 260))
	curve.add_point(Vector2(240, 260))
	curve.add_point(Vector2(240, 480))
	curve.add_point(Vector2(580, 480))
	curve.add_point(Vector2(580, 230))
	curve.add_point(Vector2(920, 230))
	curve.add_point(Vector2(920, 520))
	curve.add_point(Vector2(1140, 520)) # Сказочная деревня девочек!
	path2d.curve = curve

func _setup_build_spots() -> void:
	if is_instance_valid(build_spots_container):
		for child in build_spots_container.get_children():
			child.queue_free()
		
	# 12 тактических мест у поворотов дороги
	var spot_positions = [
		Vector2(150, 180),
		Vector2(340, 370),
		Vector2(150, 560),
		Vector2(480, 560),
		Vector2(480, 150),
		Vector2(680, 150),
		Vector2(680, 360),
		Vector2(810, 350),
		Vector2(810, 600),
		Vector2(1020, 410),
		Vector2(1020, 600),
		Vector2(1100, 360)
	]
	
	if is_instance_valid(build_spots_container):
		for pos in spot_positions:
			var spot = Area2D.new()
			spot.set_script(preload("res://scripts/build_spot.gd"))
			spot.position = pos
			spot.clicked.connect(_on_spot_clicked)
			build_spots_container.add_child(spot)

func _setup_interactive_objects() -> void:
	if is_instance_valid(interactive_container):
		for child in interactive_container.get_children():
			child.queue_free()
		
		# Размещаем бочки с порохом на обочине у поворотов
		var barrel_positions = [Vector2(260, 370), Vector2(600, 350), Vector2(940, 370)]
		for pos in barrel_positions:
			var barrel = Area2D.new()
			barrel.set_script(map_obj_script)
			barrel.object_type = "barrel"
			barrel.position = pos
			interactive_container.add_child(barrel)
			
		var chest = Area2D.new()
		chest.set_script(map_obj_script)
		chest.object_type = "chest"
		chest.position = Vector2(1120, 420)
		interactive_container.add_child(chest)

func _setup_girls() -> void:
	if is_instance_valid(girls_container):
		for child in girls_container.get_children():
			child.queue_free()
		
		var village_center = Vector2(1150, 530)
		for i in range(total_girls):
			var girl = Node2D.new()
			girl.set_script(girl_script)
			girl.position = village_center + Vector2(randf_range(-30, 30), randf_range(-30, 30))
			girl.add_to_group("girls")
			girl.rescued.connect(_on_girl_rescued)
			girls_container.add_child(girl)
		
	if is_instance_valid(hud):
		hud.update_girls_count(total_girls)

func _start_new_game() -> void:
	if is_instance_valid(enemies_container):
		for child in enemies_container.get_children():
			if child is MonsterBase or child is EnemyBase:
				child.queue_free()
	if is_instance_valid(projectiles_container):
		for child in projectiles_container.get_children():
			child.queue_free()
		
	if is_instance_valid(build_spots_container):
		for spot in build_spots_container.get_children():
			if spot is BuildSpot and spot.has_tower():
				spot.sell_tower()
			
	active_enemies = 0
	wave_in_progress = false
	is_counting_down = false
	
	if is_instance_valid(game_manager):
		game_manager.reset_game()
	_setup_girls()
	_setup_interactive_objects()
	hud.end_screen.visible = false
	_start_intermission_timer()

func _process(delta: float) -> void:
	scene_anim_time += delta
	queue_redraw()
	
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
	if is_instance_valid(girls_container):
		for g in girls_container.get_children():
			if is_instance_valid(g) and g.current_state != GirlNPC.State.BEING_CARRIED:
				free_girls += 1
	if is_instance_valid(hud):
		hud.update_girls_count(free_girls)

func _check_monster_count() -> void:
	active_enemies = max(0, active_enemies - 1)
	if active_enemies == 0 and wave_in_progress:
		wave_in_progress = false
		if is_instance_valid(tech_tree_manager):
			tech_tree_manager.add_points(1)
		
		var end_bonus = tech_tree_manager.get_end_wave_bonus_gold() if is_instance_valid(tech_tree_manager) else 0
		if end_bonus > 0 and is_instance_valid(game_manager):
			game_manager.add_gold(end_bonus)
			
		if is_instance_valid(game_manager):
			if game_manager.current_wave >= GameManager.TOTAL_WAVES:
				game_manager.set_state(GameManager.GameState.VICTORY)
			else:
				game_manager.set_state(GameManager.GameState.BUILDING)
				_start_intermission_timer()

func _on_game_state_changed(state: GameManager.GameState) -> void:
	if state == GameManager.GameState.GAME_OVER:
		wave_in_progress = false
		is_counting_down = false
		if is_instance_valid(hud):
			hud.show_game_over(false)
	elif state == GameManager.GameState.VICTORY:
		wave_in_progress = false
		is_counting_down = false
		if is_instance_valid(hud):
			hud.show_game_over(true)

func _on_spot_clicked(spot: BuildSpot) -> void:
	if is_instance_valid(build_spots_container):
		for child in build_spots_container.get_children():
			if child is BuildSpot and child != spot:
				child.set_selected(false)
			
	spot.set_selected(true)
	if is_instance_valid(game_manager):
		game_manager.select_spot(spot)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if is_instance_valid(build_spots_container):
			for child in build_spots_container.get_children():
				if child is BuildSpot:
					child.set_selected(false)
		if is_instance_valid(game_manager):
			game_manager.select_spot(null)

func _draw() -> void:
	# 1. Сказочный изумрудный холмистый ландшафт Кудрявой Долины
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.25, 0.52, 0.22))
	
	# Объемные мягкие холмы с градиентными слоями
	var hill_col1 = Color(0.30, 0.58, 0.26)
	var hill_col2 = Color(0.22, 0.46, 0.20)
	draw_circle(Vector2(120, 80), 160, hill_col1)
	draw_circle(Vector2(450, 60), 200, hill_col1)
	draw_circle(Vector2(880, 70), 220, hill_col1)
	draw_circle(Vector2(160, 680), 190, hill_col2)
	draw_circle(Vector2(700, 690), 240, hill_col2)
	draw_circle(Vector2(1100, 680), 210, hill_col2)
	
	# 2. Сказочные поляны с цветами
	for flower in flower_patches:
		draw_circle(flower["pos"], flower["size"], flower["col"])
		draw_circle(flower["pos"], flower["size"] * 0.4, Color(1.0, 0.9, 0.2))
		
	# 3. Сказочные деревья
	for tree in trees:
		var tp = tree["pos"]
		var ts = tree["scale"]
		# Тень дерева
		draw_circle(tp + Vector2(6, 12), 26.0 * ts, Color(0.0, 0.0, 0.0, 0.25))
		# Ствол
		draw_rect(Rect2(tp.x - 6 * ts, tp.y, 12 * ts, 20 * ts), Color(0.45, 0.3, 0.15))
		# Крона (3 пышных круга)
		draw_circle(tp + Vector2(0, -18 * ts), 24.0 * ts, Color(0.18, 0.42, 0.15))
		draw_circle(tp + Vector2(-12 * ts, -8 * ts), 18.0 * ts, Color(0.22, 0.48, 0.18))
		draw_circle(tp + Vector2(12 * ts, -8 * ts), 18.0 * ts, Color(0.26, 0.54, 0.22))
		# Блик света на кроне
		draw_circle(tp + Vector2(-4 * ts, -22 * ts), 10.0 * ts, Color(0.35, 0.65, 0.3, 0.7))
	
	# 4. Текстурированная извилистая дорога из булыжника и теплого песка
	if path2d and path2d.curve:
		var baked_points = path2d.curve.get_baked_points()
		if baked_points.size() > 1:
			# Мягкая тень обочины
			draw_polyline(baked_points, Color(0.0, 0.0, 0.0, 0.22), 68.0)
			# Каменная окантовка дороги
			draw_polyline(baked_points, Color(0.48, 0.42, 0.32), 58.0)
			# Основное песчаное полотно
			draw_polyline(baked_points, Color(0.86, 0.76, 0.52), 44.0)
			# Протоптанная колея
			draw_polyline(baked_points, Color(0.78, 0.68, 0.45), 20.0)
			
	# 5. Логово Монстров (Пещера слева с горящими факелами и черепом)
	# Скалистый свод
	draw_polygon(
		PackedVector2Array([Vector2(-40, 160), Vector2(70, 180), Vector2(60, 340), Vector2(-40, 360)]),
		PackedColorArray([Color(0.2, 0.18, 0.22), Color(0.28, 0.25, 0.3), Color(0.18, 0.16, 0.2), Color(0.15, 0.13, 0.18)])
	)
	# Зев пещеры (глубокая тьма и светящийся зловещий фиолетовый туман)
	draw_circle(Vector2(0, 260), 45.0, Color(0.08, 0.05, 0.1))
	draw_circle(Vector2(0, 260), 32.0, Color(0.35, 0.1, 0.45, 0.6 + sin(scene_anim_time * 3.0) * 0.2))
	# Факелы у входа
	draw_circle(Vector2(55, 200), 5.0, Color(1.0, 0.5, 0.1))
	draw_circle(Vector2(55, 320), 5.0, Color(1.0, 0.5, 0.1))
	
	# 6. Сказочная деревня Девочек справа (Деревянные домики, черепичные крыши, забор, дым из трубы)
	var village_origin = Vector2(1080, 420)
	# Зеленая полянка вокруг деревни
	draw_circle(village_origin + Vector2(60, 90), 100.0, Color(0.32, 0.62, 0.28))
	draw_arc(village_origin + Vector2(60, 90), 100.0, 0, TAU, 32, Color(0.65, 0.55, 0.35), 3.0)
	
	# Домик 1 (Уютный дом с черепичной крышей)
	var h1_pos = village_origin + Vector2(10, 20)
	draw_rect(Rect2(h1_pos.x, h1_pos.y, 60, 55), Color(0.85, 0.78, 0.65)) # Стены
	draw_rect(Rect2(h1_pos.x + 8, h1_pos.y + 12, 16, 16), Color(1.0, 0.9, 0.4)) # Теплое светящееся окно
	draw_rect(Rect2(h1_pos.x + 36, h1_pos.y + 24, 18, 31), Color(0.55, 0.35, 0.2)) # Дверь
	# Черепичная треугольная крыша
	draw_polygon(
		PackedVector2Array([Vector2(h1_pos.x - 8, h1_pos.y), Vector2(h1_pos.x + 30, h1_pos.y - 32), Vector2(h1_pos.x + 68, h1_pos.y)]),
		PackedColorArray([Color(0.88, 0.28, 0.22), Color(0.95, 0.35, 0.28), Color(0.82, 0.22, 0.18)])
	)
	# Дым из трубы
	var smoke_y = h1_pos.y - 35 - fmod(scene_anim_time * 25.0, 40.0)
	draw_circle(Vector2(h1_pos.x + 46, smoke_y), 6.0, Color(0.9, 0.9, 0.95, 0.5))
	
	# Домик 2 (Синяя мансарда)
	var h2_pos = village_origin + Vector2(75, 70)
	draw_rect(Rect2(h2_pos.x, h2_pos.y, 50, 45), Color(0.78, 0.72, 0.6))
	draw_rect(Rect2(h2_pos.x + 28, h2_pos.y + 10, 14, 14), Color(1.0, 0.9, 0.4))
	draw_polygon(
		PackedVector2Array([Vector2(h2_pos.x - 6, h2_pos.y), Vector2(h2_pos.x + 25, h2_pos.y - 26), Vector2(h2_pos.x + 56, h2_pos.y)]),
		PackedColorArray([Color(0.25, 0.45, 0.85), Color(0.35, 0.55, 0.95), Color(0.2, 0.38, 0.75)])
	)
