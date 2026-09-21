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
var floating_text_script = preload("res://scripts/floating_text.gd")

var active_enemies: int = 0
var wave_in_progress: bool = false
var auto_start_timer: float = 0.0
var is_counting_down: bool = false
var total_girls: int = 5
var scene_anim_time: float = 0.0
var tip_timer: float = 0.0
var tip_index: int = 0

var tips: Array = [
	"💡 Совет: Ледяные маги замедляют монстров, давая пушкам время сделать мощный залп!",
	"💡 Совет: Кликайте по пороховым бочкам на обочине, когда рядом идет толпа монстров!",
	"💡 Совет: Если монстр схватил девочку, убейте его — и она с сердечком побежит домой!",
	"💡 Совет: Нажмите [Пробел] для досрочного старта волны и получите +10% бонусного золота!",
	"💡 Совет: Используйте клавиши [1]-[4] для быстрого применения заклинаний маны!",
	"💡 Совет: Изучайте новые технологии в Древе Исследований за очки побед!"
]

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
	var curve = Curve2D.new()
	curve.add_point(Vector2(-40, 460))
	curve.add_point(Vector2(300, 460))
	curve.add_point(Vector2(300, 330))
	curve.add_point(Vector2(840, 330))
	curve.add_point(Vector2(840, 650))
	curve.add_point(Vector2(260, 650))
	curve.add_point(Vector2(260, 530))
	curve.add_point(Vector2(950, 530))
	curve.add_point(Vector2(950, 680))
	curve.add_point(Vector2(1120, 680)) # Сказочная деревня
	path2d.curve = curve

func _setup_build_spots() -> void:
	if is_instance_valid(build_spots_container):
		for child in build_spots_container.get_children():
			child.queue_free()
		
	# Аутентичное расположение каменных башенок-постаментов как на скриншоте
	var spot_positions = [
		Vector2(190, 525), Vector2(250, 525), # У таблички слева
		Vector2(330, 260), # Вверху слева
		Vector2(430, 260), # Вверху по центру у мостика
		Vector2(440, 390), # В центре у изгиба
		Vector2(430, 525), # В центре
		Vector2(310, 695), # У подсолнухов
		Vector2(730, 580), Vector2(785, 580), # Справа у поворота
		Vector2(785, 390), Vector2(785, 450), # Справа вверху
		Vector2(800, 610)  # У спуска к деревне
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
		
		var barrel_positions = [Vector2(260, 370), Vector2(600, 350), Vector2(940, 370)]
		for pos in barrel_positions:
			var barrel = Area2D.new()
			barrel.set_script(map_obj_script)
			barrel.object_type = "barrel"
			barrel.position = pos
			barrel.exploded.connect(func(p, _d, _r): _spawn_floating_text("💥 БУМ!", Color(1.0, 0.4, 0.1), p, 18))
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
	if is_instance_valid(hud):
		hud.end_screen.visible = false
		hud.set_countdown(GameManager.PRE_WAVE_TIME)
		hud.set_wave_button_enabled(true)
		is_counting_down = true
		auto_start_timer = GameManager.PRE_WAVE_TIME

func _process(delta: float) -> void:
	scene_anim_time += delta
	queue_redraw()
	
	# Ротация подсказок новичку
	tip_timer += delta
	if tip_timer >= 12.0:
		tip_timer = 0.0
		tip_index = (tip_index + 1) % tips.size()
		if is_instance_valid(hud):
			hud.set_hint(tips[tip_index])
			
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
			_spawn_floating_text("+%d🪙 Ранний старт!" % bonus, Color(1.0, 0.88, 0.2), Vector2(640, 200), 16)
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
	
	monster.died.connect(func(r): _on_monster_died(r, monster.global_position))
	monster.escaped_with_girl.connect(_on_monster_escaped)
	monster.took_damage.connect(func(dmg, type): _on_monster_took_damage(dmg, type, monster.global_position))
	monster.healed.connect(func(amt): _spawn_floating_text("+%d HP" % int(amt), Color(0.2, 0.95, 0.3), monster.global_position, 12))
	
	path2d.add_child(monster)

func _on_monster_took_damage(dmg: float, type: String, pos: Vector2) -> void:
	var col = Color(1.0, 1.0, 1.0) if type == "physical" else Color(0.4, 0.85, 1.0)
	_spawn_floating_text("-%d" % int(ceil(dmg)), col, pos + Vector2(0, -10), 12)

func _on_monster_died(reward: int, pos: Vector2) -> void:
	game_manager.add_gold(reward)
	_spawn_floating_text("+%d🪙" % reward, Color(1.0, 0.88, 0.25), pos, 15)
	_check_monster_count()

func _on_monster_escaped() -> void:
	_check_monster_count()

func _on_girl_rescued(girl: GirlNPC) -> void:
	_spawn_floating_text("❤️ Спасена!", Color(1.0, 0.3, 0.6), girl.global_position + Vector2(0, -20), 16)
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

func _spawn_floating_text(p_text: String, p_color: Color, p_pos: Vector2, p_size: int = 14) -> void:
	var ft = Node2D.new()
	ft.set_script(floating_text_script)
	ft.position = p_pos
	ft.setup(p_text, p_color, p_size, 0.85)
	add_child(ft)

func _check_monster_count() -> void:
	active_enemies = max(0, active_enemies - 1)
	if active_enemies == 0 and wave_in_progress:
		wave_in_progress = false
		if is_instance_valid(tech_tree_manager):
			tech_tree_manager.add_points(1)
		
		var end_bonus = tech_tree_manager.get_end_wave_bonus_gold() if is_instance_valid(tech_tree_manager) else 0
		if end_bonus > 0 and is_instance_valid(game_manager):
			game_manager.add_gold(end_bonus)
			_spawn_floating_text("+%d🪙 Казна" % end_bonus, Color(1.0, 0.88, 0.2), Vector2(640, 200), 16)
			
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
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if is_instance_valid(build_spots_container):
			for child in build_spots_container.get_children():
				if child is BuildSpot:
					child.set_selected(false)
		if is_instance_valid(game_manager):
			game_manager.select_spot(null)
		queue_redraw()
		
	# Горячие клавиши управления
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				if is_counting_down:
					_on_start_wave_pressed()
				else:
					var new_spd = 0.0 if Engine.time_scale > 0.0 else 1.0
					if is_instance_valid(hud):
						hud.set_game_speed(new_spd)
			KEY_1:
				if is_instance_valid(hud):
					hud._cast_player_spell("meteor")
			KEY_2:
				if is_instance_valid(hud):
					hud._cast_player_spell("freeze")
			KEY_3:
				if is_instance_valid(hud):
					hud._cast_player_spell("gold_rain")
			KEY_4:
				if is_instance_valid(hud):
					hud._cast_player_spell("lightning")
			KEY_Q:
				if is_instance_valid(hud):
					hud.set_game_speed(0.0)
			KEY_W:
				if is_instance_valid(hud):
					hud.set_game_speed(1.0)
			KEY_E:
				if is_instance_valid(hud):
					hud.set_game_speed(2.0)
			KEY_H:
				if is_instance_valid(hud):
					hud._on_help_clicked()

func _draw() -> void:
	# 1. Сказочный изумрудный холмистый ландшафт Кудрявой Долины
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.32, 0.65, 0.25))
	
	# Объемные мягкие холмы сочной травы
	var hill_col1 = Color(0.38, 0.72, 0.30)
	var hill_col2 = Color(0.26, 0.58, 0.22)
	draw_circle(Vector2(160, 140), 190, hill_col1)
	draw_circle(Vector2(520, 130), 220, hill_col1)
	draw_circle(Vector2(920, 150), 230, hill_col1)
	draw_circle(Vector2(140, 680), 200, hill_col2)
	draw_circle(Vector2(550, 680), 230, hill_col2)
	draw_circle(Vector2(1050, 680), 220, hill_col2)
	
	# 2. Песчаный пляж / пруд вверху по центру и справа
	var pond_water = Color(0.35, 0.72, 0.90)
	var sand_col = Color(0.92, 0.84, 0.58)
	draw_circle(Vector2(550, 240), 65, sand_col)
	draw_circle(Vector2(550, 240), 50, pond_water)
	draw_circle(Vector2(950, 210), 80, sand_col)
	draw_circle(Vector2(960, 190), 55, pond_water)
	
	# Деревянная лодочка на песке вверху справа
	var boat_p = Vector2(940, 240)
	draw_polygon(
		PackedVector2Array([boat_p + Vector2(-30, 0), boat_p + Vector2(25, -12), boat_p + Vector2(40, 0), boat_p + Vector2(20, 12)]),
		PackedColorArray([Color(0.48, 0.32, 0.18), Color(0.58, 0.38, 0.22), Color(0.48, 0.32, 0.18), Color(0.4, 0.26, 0.14)])
	)
	draw_line(boat_p + Vector2(-15, 0), boat_p + Vector2(20, 0), Color(0.3, 0.18, 0.1), 2.0)
	
	# 3. Сказочные поляны с цветами
	for flower in flower_patches:
		draw_circle(flower["pos"], flower["size"], flower["col"])
		draw_circle(flower["pos"], flower["size"] * 0.4, Color(1.0, 0.9, 0.2))
		
	# 4. Текстурированная извилистая песчаная дорога (как на скриншотах «Башенок»)
	if path2d and path2d.curve:
		var baked_points = path2d.curve.get_baked_points()
		if baked_points.size() > 1:
			# Мягкая тень обочины
			draw_polyline(baked_points, Color(0.0, 0.0, 0.0, 0.24), 74.0)
			# Каменная/травяная окантовка дороги
			draw_polyline(baked_points, Color(0.58, 0.52, 0.38), 64.0)
			# Основное теплое песчаное полотно
			draw_polyline(baked_points, Color(0.92, 0.82, 0.56), 50.0)
			# Протоптанная дорожка со следами
			draw_polyline(baked_points, Color(0.84, 0.74, 0.48), 24.0)
			
	# 5. Деревянный мостик через верхний пруд (по центру)
	var bridge_pos = Vector2(550, 240)
	draw_rect(Rect2(bridge_pos.x - 45, bridge_pos.y - 20, 90, 40), Color(0.55, 0.38, 0.22))
	for b_i in range(8):
		var plank_x = bridge_pos.x - 40 + b_i * 11
		draw_rect(Rect2(plank_x, bridge_pos.y - 22, 9, 44), Color(0.68, 0.48, 0.28))
		draw_line(Vector2(plank_x, bridge_pos.y - 22), Vector2(plank_x + 9, bridge_pos.y - 22), Color(0.35, 0.22, 0.12), 1.5)
		draw_line(Vector2(plank_x + 4, bridge_pos.y - 18), Vector2(plank_x + 4, bridge_pos.y + 18), Color(0.4, 0.28, 0.15), 1.0)
		
	# 6. Деревянный указатель со страшком/монстром слева
	var sign_p = Vector2(120, 420)
	draw_rect(Rect2(sign_p.x + 8, sign_p.y + 10, 8, 32), Color(0.45, 0.3, 0.15)) # Столбик
	draw_rect(Rect2(sign_p.x + 44, sign_p.y + 10, 8, 32), Color(0.45, 0.3, 0.15))
	draw_rect(Rect2(sign_p.x, sign_p.y - 20, 60, 32), Color(0.65, 0.45, 0.26)) # Доска
	draw_rect(Rect2(sign_p.x + 2, sign_p.y - 18, 56, 28), Color(0.75, 0.55, 0.32))
	# Нарисованный белый монстрик на табличке
	draw_circle(sign_p + Vector2(30, -5), 8.0, Color(1.0, 1.0, 1.0, 0.85))
	draw_circle(sign_p + Vector2(27, -6), 1.5, Color(0.2, 0.2, 0.3))
	draw_circle(sign_p + Vector2(33, -6), 1.5, Color(0.2, 0.2, 0.3))
	draw_line(sign_p + Vector2(22, -4), sign_p + Vector2(17, -10), Color(1.0, 1.0, 1.0, 0.85), 2.0)
	draw_line(sign_p + Vector2(38, -4), sign_p + Vector2(43, -10), Color(1.0, 1.0, 1.0, 0.85), 2.0)
	
	# 7. Пугало и подсолнухи в левом нижнем углу 🌻
	var scarecrow_p = Vector2(180, 640)
	# Поле ярких подсолнухов
	var sunflower_offsets = [
		Vector2(-40, 15), Vector2(-25, 25), Vector2(-10, 30), Vector2(10, 28),
		Vector2(25, 20), Vector2(-35, 40), Vector2(-15, 45), Vector2(15, 42),
		Vector2(35, 35), Vector2(-45, 28), Vector2(5, 50)
	]
	for s_off in sunflower_offsets:
		var sp = scarecrow_p + s_off
		# Зеленый стебель
		draw_line(sp + Vector2(0, 10), sp, Color(0.2, 0.5, 0.15), 2.5)
		# Желтые лепестки
		draw_circle(sp, 8.0, Color(1.0, 0.85, 0.1))
		# Темная серединка
		draw_circle(sp, 4.0, Color(0.28, 0.16, 0.08))
		
	# Пугало (Scarecrow)
	draw_line(scarecrow_p + Vector2(0, 20), scarecrow_p + Vector2(0, -25), Color(0.45, 0.3, 0.15), 3.5) # Шест
	draw_line(scarecrow_p + Vector2(-24, -10), scarecrow_p + Vector2(24, -10), Color(0.45, 0.3, 0.15), 3.0) # Поперечина
	# Синяя рубаха
	draw_polygon(
		PackedVector2Array([scarecrow_p + Vector2(-18, -10), scarecrow_p + Vector2(18, -10), scarecrow_p + Vector2(12, 10), scarecrow_p + Vector2(-12, 10)]),
		PackedColorArray([Color(0.25, 0.45, 0.75), Color(0.35, 0.55, 0.85), Color(0.2, 0.4, 0.7), Color(0.2, 0.4, 0.7)])
	)
	# Голова из мешковины
	draw_circle(scarecrow_p + Vector2(0, -22), 7.5, Color(0.9, 0.8, 0.65))
	# Шляпа
	draw_circle(scarecrow_p + Vector2(0, -26), 12.0, Color(0.85, 0.65, 0.25))
	draw_rect(Rect2(scarecrow_p.x - 7, scarecrow_p.y - 34, 14, 8), Color(0.85, 0.65, 0.25))
	draw_line(scarecrow_p + Vector2(-7, -26), scarecrow_p + Vector2(7, -26), Color(0.8, 0.2, 0.2), 2.0)
	
	# 8. Сказочная деревушка справа внизу (с черепичными домиками, заборчиком и мостиком)
	var village_origin = Vector2(980, 620)
	# Каменная площадка деревни
	draw_circle(village_origin + Vector2(80, 50), 90.0, Color(0.78, 0.74, 0.65))
	draw_arc(village_origin + Vector2(80, 50), 90.0, 0, TAU, 32, Color(0.55, 0.48, 0.38), 2.5)
	
	# Деревянный заборчик (плетень)
	for f_i in range(9):
		var fx = village_origin.x - 10 + f_i * 14
		var fy = village_origin.y + 45 - f_i * 4
		draw_line(Vector2(fx, fy), Vector2(fx, fy + 16), Color(0.48, 0.32, 0.18), 3.0)
	draw_line(Vector2(village_origin.x - 10, village_origin.y + 50), Vector2(village_origin.x + 110, village_origin.y + 20), Color(0.55, 0.4, 0.22), 2.0)
	
	# Маленький мостик перед деревней
	var v_bridge = village_origin + Vector2(-40, 40)
	draw_rect(Rect2(v_bridge.x - 20, v_bridge.y - 12, 40, 24), Color(0.62, 0.45, 0.28))
	draw_circle(v_bridge + Vector2(0, 15), 14.0, pond_water)
	
	# Домик 1 (Оранжевая черепица)
	var h1 = village_origin + Vector2(25, -20)
	draw_rect(Rect2(h1.x, h1.y, 48, 42), Color(0.88, 0.82, 0.72))
	draw_rect(Rect2(h1.x + 6, h1.y + 10, 12, 12), Color(1.0, 0.9, 0.4))
	draw_polygon(
		PackedVector2Array([h1 + Vector2(-6, 0), h1 + Vector2(24, -24), h1 + Vector2(54, 0)]),
		PackedColorArray([Color(0.85, 0.35, 0.2), Color(0.95, 0.45, 0.25), Color(0.75, 0.25, 0.15)])
	)
	
	# Домик 2 (Коричневая мансарда)
	var h2 = village_origin + Vector2(80, 15)
	draw_rect(Rect2(h2.x, h2.y, 42, 38), Color(0.82, 0.76, 0.68))
	draw_rect(Rect2(h2.x + 22, h2.y + 8, 11, 11), Color(1.0, 0.9, 0.4))
	draw_polygon(
		PackedVector2Array([h2 + Vector2(-5, 0), h2 + Vector2(21, -20), h2 + Vector2(47, 0)]),
		PackedColorArray([Color(0.65, 0.32, 0.2), Color(0.75, 0.42, 0.25), Color(0.55, 0.22, 0.15)])
	)
	
	# 9. Интерактивная подсветка радиуса атаки выбранной башни / площадки
	if is_instance_valid(game_manager) and is_instance_valid(game_manager.selected_spot):
		var spot: BuildSpot = game_manager.selected_spot as BuildSpot
		if is_instance_valid(spot):
			var r = 190.0
			if spot.has_tower():
				r = spot.current_tower.get_effective_range()
			draw_circle(spot.position, r, Color(0.3, 0.8, 1.0, 0.10 + sin(scene_anim_time * 4.0) * 0.03))
			draw_arc(spot.position, r, 0, TAU, 48, Color(0.4, 0.9, 1.0, 0.75), 2.5)
