class_name Game
extends Node2D

@onready var game_manager: GameManager = $GameManager
@onready var wave_controller = $WaveController
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

var total_girls: int = 5

const MAP_LAYOUTS: Dictionary = {
	"valley": {
		"curve": [
			Vector2(-40, 240), Vector2(260, 240), Vector2(400, 420),
			Vector2(700, 420), Vector2(880, 260), Vector2(1060, 260),
			Vector2(1060, 560), Vector2(1140, 560)
		],
		"spots": [
			Vector2(180, 170), Vector2(250, 310), Vector2(340, 170),
			Vector2(330, 490), Vector2(470, 490), Vector2(550, 340),
			Vector2(650, 490), Vector2(760, 340), Vector2(840, 490),
			Vector2(950, 190), Vector2(980, 330), Vector2(980, 490)
		],
		"village": Vector2(1120, 540),
		"barrels": [Vector2(400, 350), Vector2(700, 350)],
		"chest": Vector2(880, 190),
		"bridge": Vector2(550, 420)
	},
	"swamp": {
		"curve": [
			Vector2(-40, 420), Vector2(220, 420), Vector2(320, 600),
			Vector2(640, 600), Vector2(640, 200), Vector2(920, 200),
			Vector2(920, 480), Vector2(1140, 480)
		],
		"spots": [
			Vector2(140, 350), Vector2(240, 510), Vector2(180, 600),
			Vector2(420, 530), Vector2(550, 530), Vector2(560, 380),
			Vector2(560, 270), Vector2(720, 270), Vector2(820, 270),
			Vector2(840, 400), Vector2(1000, 400), Vector2(1000, 560)
		],
		"village": Vector2(1120, 460),
		"barrels": [Vector2(320, 520), Vector2(640, 380)],
		"chest": Vector2(920, 120),
		"bridge": Vector2(640, 400)
	},
	"caves": {
		"curve": [
			Vector2(-40, 180), Vector2(320, 180), Vector2(320, 480),
			Vector2(680, 480), Vector2(680, 220), Vector2(1000, 220),
			Vector2(1000, 620), Vector2(1140, 620)
		],
		"spots": [
			Vector2(180, 250), Vector2(250, 110), Vector2(390, 250),
			Vector2(390, 410), Vector2(500, 550), Vector2(610, 550),
			Vector2(610, 350), Vector2(750, 150), Vector2(860, 150),
			Vector2(930, 290), Vector2(930, 450), Vector2(1070, 540)
		],
		"village": Vector2(1120, 600),
		"barrels": [Vector2(320, 330), Vector2(680, 350)],
		"chest": Vector2(500, 410),
		"bridge": Vector2(680, 350)
	},
	"frost_peak": {
		"curve": [
			Vector2(-40, 560), Vector2(280, 560), Vector2(280, 240),
			Vector2(600, 240), Vector2(600, 500), Vector2(900, 500),
			Vector2(900, 220), Vector2(1140, 220)
		],
		"spots": [
			Vector2(160, 490), Vector2(210, 630), Vector2(350, 450),
			Vector2(350, 310), Vector2(460, 170), Vector2(530, 310),
			Vector2(670, 310), Vector2(670, 430), Vector2(780, 570),
			Vector2(830, 430), Vector2(970, 310), Vector2(1040, 150)
		],
		"village": Vector2(1120, 200),
		"barrels": [Vector2(280, 400), Vector2(600, 370)],
		"chest": Vector2(750, 430),
		"bridge": Vector2(600, 380)
	},
	"besieged_citadel": {
		"curve": [
			Vector2(-40, 360), Vector2(260, 360), Vector2(440, 180),
			Vector2(740, 180), Vector2(740, 540), Vector2(960, 540),
			Vector2(960, 360), Vector2(1140, 360)
		],
		"spots": [
			Vector2(140, 290), Vector2(140, 430), Vector2(320, 260),
			Vector2(360, 430), Vector2(560, 110), Vector2(620, 250),
			Vector2(670, 390), Vector2(670, 610), Vector2(820, 610),
			Vector2(880, 470), Vector2(1030, 470), Vector2(1030, 290)
		],
		"village": Vector2(1120, 340),
		"barrels": [Vector2(440, 260), Vector2(740, 360)],
		"chest": Vector2(560, 250),
		"bridge": Vector2(740, 360)
	}
}

func _get_current_layout() -> Dictionary:
	var b = GlobalState.selected_map if GlobalState.selected_map != "" else "valley"
	return MAP_LAYOUTS.get(b, MAP_LAYOUTS["valley"])
var scene_anim_time: float = 0.0
var tip_timer: float = 0.0
var tip_index: int = 0

# Системы расширения (Этапы 5, 6, 7, 9)
var combo_tracker: ComboTracker = null
var weather_system: WeatherSystem = null
var lore_system: LoreSystem = null
var artifact_manager: ArtifactManager = null

var active_boss: MonsterBase = null
var lightning_flash_timer: float = 0.0

var tips: Array = [
	"💡 Совет: Ледяные маги замедляют монстров, давая пушкам время сделать мощный залп!",
	"💡 Совет: Кликайте по пороховым бочкам на обочине, когда рядом идет толпа монстров!",
	"💡 Совет: Если монстр схватил девочку, убейте его — и она с сердечком побежит домой!",
	"💡 Совет: Нажмите [Пробел] для досрочного старта волны и получите +10% бонусного золота!",
	"💡 Совет: Используйте клавиши [1]-[8] для быстрого применения заклинаний маны!",
	"💡 Совет: Открывайте Бестиарий и Реликвии на верхней панели для тактических подсказок!"
]

# Процедурные декоративные элементы
var flower_patches: Array = []
var trees: Array = []
var crystals: Array = []
var swamp_mushrooms: Array = []

func _ready() -> void:
	game_manager.set_chosen_path(GlobalState.selected_path)
	_setup_expansion_systems()
	_generate_decorations()
	_setup_signals()
	_setup_path()
	_setup_build_spots()
	_setup_interactive_objects()
	_start_new_game()

func _setup_expansion_systems() -> void:
	combo_tracker = ComboTracker.new()
	add_child(combo_tracker)
	combo_tracker.combo_updated.connect(func(streak, mult):
		if is_instance_valid(hud):
			hud.update_combo(streak, mult, combo_tracker.timer, combo_tracker.window_duration)
	)
	combo_tracker.combo_broken.connect(func():
		if is_instance_valid(hud):
			hud.update_combo(0, 1.0, 0.0, 2.5)
	)
	
	weather_system = WeatherSystem.new()
	add_child(weather_system)
	weather_system.weather_changed.connect(func(w):
		if is_instance_valid(hud):
			hud.update_weather(w)
	)
	
	lore_system = LoreSystem.new()
	add_child(lore_system)
	lore_system.dialogue_spoken.connect(func(spk, txt):
		if is_instance_valid(hud):
			hud.show_dialogue(spk, txt)
	)
	
	artifact_manager = ArtifactManager.new()
	add_child(artifact_manager)
	
	var hero_manager = HeroManager.new()

	add_child(hero_manager)
	var spawn_pt = Vector2(400, 400)
	hero_manager.spawn_hero('commander', spawn_pt, self)
	
	# Установка начальной погоды в зависимости от карты
	match GlobalState.selected_map:
		"swamp": weather_system.set_weather("rain")
		"frost_peak": weather_system.set_weather("snow")
		"caves": weather_system.set_weather("fog")
		_: weather_system.set_weather("clear")
		
	# Инициализация особых игровых режимов
	_setup_game_mode()

func _setup_game_mode() -> void:
	match GlobalState.game_mode:
		"nightmare":
			var nm = NightmareController.new()
			add_child(nm)
			nm.enable_nightmare()
			game_manager.lives = 1
			game_manager.max_lives = 1
			game_manager.gold = int(game_manager.gold * 0.5)
			_spawn_floating_text("💀 РЕЖИМ КОШМАРА: 1 ЖИЗНЬ!", Color(1.0, 0.2, 0.2), Vector2(640, 200), 22)
		"boss_rush":
			var br = BossRushController.new()
			add_child(br)
			br.start_boss_rush()
			_spawn_floating_text("👹 БИТВА С БОССАМИ!", Color(1.0, 0.3, 0.3), Vector2(640, 200), 22)
		"ng_plus":
			var ng = NGPlusController.new()
			add_child(ng)
			ng.start_ng_plus(meta_manager)
			_spawn_floating_text("👑 NEW GAME+ АКТИВИРОВАН!", Color(1.0, 0.85, 0.3), Vector2(640, 200), 22)
		"endless":
			var end_ctrl = EndlessController.new()
			add_child(end_ctrl)
			end_ctrl.start_endless()
			_spawn_floating_text("♾️ БЕСКОНЕЧНЫЙ ШТУРМ!", Color(0.4, 0.8, 1.0), Vector2(640, 200), 22)
		"challenge":
			if GlobalState.selected_challenge != "":
				var ch = ChallengeManager.new()
				add_child(ch)
				ch.start_challenge(GlobalState.selected_challenge)
				_spawn_floating_text("🎯 ИСПЫТАНИЕ АКТИВИРОВАНО!", Color(0.4, 1.0, 0.5), Vector2(640, 200), 22)
		"weekly":
			var wk = WeeklyChallengeController.new()
			add_child(wk)
			_spawn_floating_text("📅 ЕЖЕНЕДЕЛЬНОЕ ИСПЫТАНИЕ!", Color(0.85, 0.6, 1.0), Vector2(640, 200), 22)
		"draft":
			var dr = DraftModeController.new()
			add_child(dr)
			dr.start_draft_run(randi())
			_spawn_floating_text("🃏 ДРАФТ-РЕЖИМ БАШЕН!", Color(1.0, 0.7, 0.2), Vector2(640, 200), 22)

func _generate_decorations() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 42
	
	flower_patches.clear()
	for i in range(40):
		var pos = Vector2(rng.randf_range(60, 1220), rng.randf_range(80, 680))
		var col_type = rng.randi_range(0, 3)
		var col = Color(1.0, 1.0, 1.0)
		if col_type == 1: col = Color(0.95, 0.25, 0.3)
		elif col_type == 2: col = Color(0.35, 0.65, 1.0)
		elif col_type == 3: col = Color(1.0, 0.85, 0.2)
		flower_patches.append({"pos": pos, "col": col, "size": rng.randf_range(2.5, 4.0)})
		
	crystals.clear()
	for i in range(25):
		var pos = Vector2(rng.randf_range(50, 1230), rng.randf_range(70, 690))
		var c_col = Color(0.1, 0.85, 1.0) if i % 2 == 0 else Color(0.85, 0.3, 1.0)
		crystals.append({"pos": pos, "col": c_col, "size": rng.randf_range(8.0, 16.0)})
		
	swamp_mushrooms.clear()
	for i in range(25):
		var pos = Vector2(rng.randf_range(50, 1230), rng.randf_range(70, 690))
		swamp_mushrooms.append({"pos": pos, "size": rng.randf_range(10.0, 20.0)})
		
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
	
	if is_instance_valid(wave_controller):
		wave_controller.wave_countdown_tick.connect(_on_wave_countdown_tick)
		wave_controller.wave_started.connect(_on_wave_started)
		wave_controller.enemy_spawn_requested.connect(_spawn_monster)
		wave_controller.wave_completed.connect(_on_wave_completed)
		wave_controller.all_waves_completed.connect(_on_all_waves_completed)

func _setup_path() -> void:
	var layout = _get_current_layout()
	var curve = Curve2D.new()
	for pt in layout.get("curve", []):
		curve.add_point(pt)
	path2d.curve = curve

func _setup_build_spots() -> void:
	if is_instance_valid(build_spots_container):
		for child in build_spots_container.get_children():
			child.queue_free()
		
	var layout = _get_current_layout()
	var spot_positions = layout.get("spots", [])
	
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
		
		var layout = _get_current_layout()
		var barrel_positions = layout.get("barrels", [])
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
		chest.position = layout.get("chest", Vector2(1000, 300))
		interactive_container.add_child(chest)

func _setup_girls() -> void:
	if is_instance_valid(girls_container):
		for child in girls_container.get_children():
			child.queue_free()
		
		var layout = _get_current_layout()
		var village_center = layout.get("village", Vector2(1120, 540))
		for i in range(total_girls):
			var girl = Node2D.new()
			girl.set_script(girl_script)
			girl.position = village_center + Vector2(randf_range(-25, 25), randf_range(-25, 25))
			girl.add_to_group("girls")
			girl.rescued.connect(_on_girl_rescued)
			girls_container.add_child(girl)
		
	if is_instance_valid(hud):
		hud.update_girls_count(total_girls)

func _start_new_game() -> void:
	if is_instance_valid(enemies_container):
		for child in enemies_container.get_children():
			if child is MonsterBase:
				child.queue_free()
	if is_instance_valid(projectiles_container):
		for child in projectiles_container.get_children():
			child.queue_free()
		
	if is_instance_valid(build_spots_container):
		for spot in build_spots_container.get_children():
			if spot is BuildSpot and spot.has_tower():
				spot.sell_tower()
			
	if is_instance_valid(game_manager):
		game_manager.reset_game()
	_setup_girls()
	_setup_interactive_objects()
	
	if is_instance_valid(combo_tracker):
		combo_tracker.reset_combo()
	if is_instance_valid(lore_system):
		lore_system.reset_session()
	
	if is_instance_valid(hud):
		hud.end_screen.visible = false
		hud.set_wave_button_enabled(true)
		hud.hide_boss_bar()
		
	if is_instance_valid(wave_controller):
		wave_controller.reset_waves()
		wave_controller.start_wave_countdown(GameManager.PRE_WAVE_TIME)
		_update_wave_preview(1)

func _process(delta: float) -> void:
	scene_anim_time += delta
	if lightning_flash_timer > 0.0:
		lightning_flash_timer -= delta
		
	queue_redraw()
	
	# Обновление комбо-индикатора в реальном времени
	if is_instance_valid(combo_tracker) and combo_tracker.current_streak > 0:
		if is_instance_valid(hud):
			hud.update_combo(combo_tracker.current_streak, combo_tracker.current_multiplier, combo_tracker.timer, combo_tracker.window_duration)
			
	# Обновление полоски здоровья босса
	if is_instance_valid(active_boss) and not active_boss.get("is_dead"):
		var cur_hp = active_boss.current_health
		var max_hp = active_boss.max_health
		var shld = active_boss.shield
		var m_shld = active_boss.max_shield
		var b_name = active_boss.monster_name
		var phase_text = "⚔️ Фаза боя"
		if cur_hp <= max_hp * 0.3: phase_text = "⚡ ФАЗА 3: ЯРОСТЬ БЕРСЕРКА!"
		elif cur_hp <= max_hp * 0.6: phase_text = "🛡️ ФАЗА 2: ЗАЩИТНЫЙ ЩИТ"
		if is_instance_valid(hud):
			hud.show_boss_bar(b_name, cur_hp, max_hp, shld, m_shld, phase_text)
	else:
		if is_instance_valid(active_boss):
			active_boss = null
			if is_instance_valid(hud):
				hud.hide_boss_bar()
	
	# Ротация подсказок
	tip_timer += delta
	if tip_timer >= 12.0:
		tip_timer = 0.0
		tip_index = (tip_index + 1) % tips.size()
		if is_instance_valid(hud):
			hud.set_hint(tips[tip_index])

func _on_wave_countdown_tick(time_left: float, total_time: float, is_boss: bool) -> void:
	if is_instance_valid(hud):
		hud.set_countdown(time_left)
		if is_instance_valid(hud.wave_clock):
			hud.wave_clock.set_countdown(time_left, total_time, is_boss)

func _on_start_wave_pressed() -> void:
	if is_instance_valid(wave_controller) and wave_controller.is_counting_down:
		var bonus = int(game_manager.gold * 0.10) if is_instance_valid(game_manager) else 0
		if bonus > 0 and is_instance_valid(game_manager):
			game_manager.add_gold(bonus)
			_spawn_floating_text("+%d🪙 Ранний старт!" % bonus, Color(1.0, 0.88, 0.2), Vector2(640, 200), 16)
		wave_controller.start_current_wave(true)

func _on_wave_started(wave_num: int, total_waves: int, is_boss: bool) -> void:
	if is_instance_valid(game_manager):
		game_manager.current_wave = wave_num
		game_manager.wave_changed.emit(wave_num, total_waves)
		game_manager.set_state(GameManager.GameState.WAVE_IN_PROGRESS)
		game_manager.on_wave_started()
	if is_instance_valid(hud):
		hud.stop_countdown()
		hud.set_wave_button_enabled(false)
		hud.show_wave_preview("")
		
	if is_instance_valid(lore_system):
		lore_system.trigger_event(GlobalState.selected_map, wave_num, "wave_start")
		
	# Смена погоды на волнах боссов
	if is_boss and is_instance_valid(weather_system):
		weather_system.set_weather("thunderstorm")
		lightning_flash_timer = 0.4
	elif is_instance_valid(weather_system) and wave_num % 3 == 0:
		var weathers = ["clear", "rain", "fog", "snow"]
		weather_system.set_weather(weathers[wave_num % weathers.size()])

func _spawn_monster(enemy_type: String) -> void:
	var monster = PathFollow2D.new()
	monster.set_script(monster_script)
	monster.monster_type = enemy_type
	monster.add_to_group("enemies")
	
	if monster.is_boss:
		active_boss = monster
		if is_instance_valid(lore_system):
			lore_system.trigger_event(GlobalState.selected_map, game_manager.current_wave, "boss_spawn")
	
	monster.died.connect(func(r): _on_monster_died(r, monster.global_position, monster))
	monster.finished.connect(func(outcome, reward): 
		if is_instance_valid(wave_controller):
			wave_controller.register_enemy_finished(outcome, reward)
	)
	monster.took_damage.connect(func(dmg, type): _on_monster_took_damage(dmg, type, monster.global_position))
	monster.healed.connect(func(amt): _spawn_floating_text("+%d HP" % int(amt), Color(0.2, 0.95, 0.3), monster.global_position, 12))
	
	path2d.add_child(monster)

func _on_monster_took_damage(dmg: float, type: String, pos: Vector2) -> void:
	var col = Color(1.0, 1.0, 1.0)
	match type:
		"fire": col = Color(1.0, 0.4, 0.1)
		"cold": col = Color(0.3, 0.8, 1.0)
		"poison": col = Color(0.4, 0.9, 0.2)
		"lightning": col = Color(1.0, 0.9, 0.2)
		"magic": col = Color(0.8, 0.4, 1.0)
		"true": col = Color(1.0, 0.2, 0.3)
	_spawn_floating_text("-%d" % int(ceil(dmg)), col, pos + Vector2(0, -10), 12)

func _on_monster_died(reward: int, pos: Vector2, monster: Node2D = null) -> void:
	var mult = 1.0
	if is_instance_valid(combo_tracker):
		mult = combo_tracker.register_kill()
		
	var final_reward = int(ceil(reward * mult))
	if is_instance_valid(game_manager):
		game_manager.add_gold(final_reward)
		
	var txt = "+%d🪙" % final_reward
	if mult > 1.0:
		txt += " (x%.1f)" % mult
	_spawn_floating_text(txt, Color(1.0, 0.88, 0.25), pos, 15)

func _on_wave_completed(wave_num: int, is_last_wave: bool) -> void:
	if is_instance_valid(game_manager):
		game_manager.set_state(GameManager.GameState.BUILDING)
	if is_instance_valid(hud):
		hud.set_wave_button_enabled(true)
		hud.hide_boss_bar()
		
	if is_instance_valid(wave_controller) and not is_last_wave:
		_update_wave_preview(wave_num + 1)
		wave_controller.start_wave_countdown(GameManager.PRE_WAVE_TIME)

func _update_wave_preview(next_wave: int) -> void:
	if not is_instance_valid(hud):
		return
	var text = "🌊 Волна %d: Наступают полчища орков!" % next_wave
	if next_wave % 5 == 0:
		text = "⚠️ ВНИМАНИЕ! Волна %d: ПРИБЛИЖАЕТСЯ БОСС ОРДЫ! 👑" % next_wave
	hud.show_wave_preview(text)

func _on_all_waves_completed() -> void:
	if is_instance_valid(game_manager):
		game_manager.set_state(GameManager.GameState.VICTORY)
	if is_instance_valid(hud):
		hud.end_title.text = "👑 ПОБЕДА В БИОМЕ!"
		hud.end_subtitle.text = "Вы спасли королевство и защитили всех жителей!\nНачислено 30 Очков Славы!"
		hud.end_screen.visible = true
	if is_instance_valid(meta_manager):
		meta_manager.add_glory(30)
		meta_manager.record_map_stars(GlobalState.selected_map, 3)


func _on_lives_changed(new_lives: int) -> void:
	if is_instance_valid(hud):
		hud.update_girls_count(new_lives)
	if is_instance_valid(combo_tracker):
		combo_tracker.reset_combo()

func _on_game_state_changed(new_state: GameManager.GameState) -> void:
	if new_state == GameManager.GameState.GAME_OVER:
		if is_instance_valid(hud):
			hud.end_title.text = "💀 ПОРАЖЕНИЕ..."
			hud.end_subtitle.text = "Оркам удалось пленить всех девочек королевства.\nПопробуйте другую тактику!"
			hud.end_screen.visible = true

func _on_girl_rescued(girl_pos: Vector2) -> void:
	_spawn_floating_text("💖 Девочка спасена!", Color(1.0, 0.4, 0.8), girl_pos, 16)

func _on_spot_clicked(spot: BuildSpot) -> void:
	if is_instance_valid(game_manager):
		game_manager.select_spot(spot)
		if is_instance_valid(build_spots_container):
			for child in build_spots_container.get_children():
				if child is BuildSpot:
					child.set_selected(child == spot)
		queue_redraw()

func _spawn_floating_text(text: String, color: Color, pos: Vector2, font_size: int = 14) -> void:
	var ft = Node2D.new()
	ft.set_script(floating_text_script)
	ft.position = pos
	add_child(ft)
	ft.setup(text, color, font_size)


func _unhandled_input(event: InputEvent) -> void:
	var h_mgrs = get_tree().get_nodes_in_group("hero_manager")
	if h_mgrs.size() > 0 and h_mgrs[0].handle_input(event, get_global_mouse_position()):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				_on_start_wave_pressed()
			KEY_1: if is_instance_valid(hud): hud._cast_player_spell("meteor")
			KEY_2: if is_instance_valid(hud): hud._cast_player_spell("freeze")
			KEY_3: if is_instance_valid(hud): hud._cast_player_spell("gold_rain")
			KEY_4: if is_instance_valid(hud): hud._cast_player_spell("lightning")
			KEY_5: if is_instance_valid(hud): hud._cast_player_spell("vortex")
			KEY_6: if is_instance_valid(hud): hud._cast_player_spell("roots")
			KEY_7: if is_instance_valid(hud): hud._cast_player_spell("chronoshift")
			KEY_8: if is_instance_valid(hud): hud._cast_player_spell("stone_wall")
			KEY_Q: if is_instance_valid(hud): hud.set_game_speed(0.0)
			KEY_W: if is_instance_valid(hud): hud.set_game_speed(1.0)
			KEY_E: if is_instance_valid(hud): hud.set_game_speed(2.0)
			KEY_H: if is_instance_valid(hud): hud._on_help_clicked()
			KEY_T: if is_instance_valid(hud): hud._on_tech_tree_clicked()
			KEY_ESCAPE:
				if is_instance_valid(hud):
					if is_instance_valid(hud.tech_tree_modal) and hud.tech_tree_modal.visible:
						hud.tech_tree_modal.visible = false
					elif is_instance_valid(hud.help_modal) and hud.help_modal.visible:
						hud.help_modal.visible = false
					elif is_instance_valid(hud.bestiary_modal) and hud.bestiary_modal.visible:
						hud.bestiary_modal.visible = false
					elif is_instance_valid(hud.artifacts_modal) and hud.artifacts_modal.visible:
						hud.artifacts_modal.visible = false
					elif is_instance_valid(game_manager):
						game_manager.select_spot(null)
						if is_instance_valid(build_spots_container):
							for child in build_spots_container.get_children():
								if child is BuildSpot: child.set_selected(false)
						queue_redraw()

func _draw() -> void:
	var biome = GlobalState.selected_map
	
	# 1. Отрисовка стабильного и четкого ландшафта выбранного биома
	match biome:
		"swamp": _draw_swamp_biome()
		"caves": _draw_caves_biome()
		"frost_peak": _draw_frost_biome()
		"besieged_citadel": _draw_citadel_biome()
		_: _draw_valley_biome()
		
	# 2. Отрисовка погодных осадков
	_draw_weather_overlay()
	
	# 3. Интерактивная подсветка радиуса атаки выбранной башни
	if is_instance_valid(game_manager) and is_instance_valid(game_manager.selected_spot):
		var spot: BuildSpot = game_manager.selected_spot as BuildSpot
		if is_instance_valid(spot):
			var r = 190.0
			if spot.has_tower():
				r = spot.current_tower.get_effective_range()
			draw_circle(spot.position, r, Color(0.3, 0.8, 1.0, 0.08))
			draw_arc(spot.position, r, 0, TAU, 48, Color(0.4, 0.9, 1.0, 0.6), 2.0)

func _draw_valley_biome() -> void:
	var layout = _get_current_layout()
	# Изумрудная долина
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.30, 0.62, 0.23))
	var hill_col1 = Color(0.36, 0.70, 0.28)
	var hill_col2 = Color(0.25, 0.55, 0.20)
	draw_circle(Vector2(160, 140), 190, hill_col1)
	draw_circle(Vector2(520, 130), 220, hill_col1)
	draw_circle(Vector2(920, 150), 230, hill_col1)
	draw_circle(Vector2(140, 680), 200, hill_col2)
	draw_circle(Vector2(550, 680), 230, hill_col2)
	draw_circle(Vector2(1050, 680), 220, hill_col2)
	
	# Пруд и песчаный берег
	var pond_water = Color(0.35, 0.72, 0.90)
	var sand_col = Color(0.92, 0.84, 0.58)
	var br = layout.get("bridge", Vector2(550, 420))
	draw_circle(br, 75, sand_col)
	draw_circle(br, 60, pond_water)
	
	# Цветочные полянки
	for flower in flower_patches:
		draw_circle(flower["pos"], flower["size"], flower["col"])
		
	# Деревья
	_draw_trees()
		
	# Извилистая песчаная дорога
	_draw_road(Color(0.92, 0.82, 0.56), Color(0.58, 0.52, 0.38))
	
	# Деревянный мостик
	_draw_bridge(br)
	_draw_village(layout.get("village", Vector2(1120, 540)), Color(0.85, 0.35, 0.2))

func _draw_swamp_biome() -> void:
	var layout = _get_current_layout()
	# Грибные топи: мрачно-зеленая земля и кислотные лужи
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.16, 0.24, 0.18))
	draw_circle(Vector2(200, 150), 220, Color(0.13, 0.20, 0.15))
	draw_circle(Vector2(600, 180), 250, Color(0.13, 0.20, 0.15))
	draw_circle(Vector2(1000, 200), 240, Color(0.13, 0.20, 0.15))
	
	# Токсичные зеленые топи
	var slime_col = Color(0.22, 0.65, 0.30, 0.75)
	draw_circle(Vector2(450, 400), 75, slime_col)
	draw_circle(Vector2(800, 360), 85, slime_col)
	
	# Светящиеся грибы
	for m in swamp_mushrooms:
		draw_circle(m["pos"], m["size"], Color(0.2, 0.8, 0.4, 0.8))
		draw_circle(m["pos"] + Vector2(0, -m["size"] * 0.3), m["size"] * 0.4, Color(0.6, 1.0, 0.6))
		
	# Гнилая темная тропа
	_draw_road(Color(0.40, 0.35, 0.28), Color(0.25, 0.22, 0.18))
	_draw_bridge(layout.get("bridge", Vector2(640, 400)))
	_draw_village(layout.get("village", Vector2(1120, 460)), Color(0.45, 0.35, 0.55))

func _draw_caves_biome() -> void:
	var layout = _get_current_layout()
	# Хрустальные пещеры: глубокий базальт и светящиеся кристаллы
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.09, 0.09, 0.13))
	draw_circle(Vector2(250, 160), 200, Color(0.12, 0.12, 0.18))
	draw_circle(Vector2(650, 180), 230, Color(0.12, 0.12, 0.18))
	draw_circle(Vector2(1000, 180), 220, Color(0.12, 0.12, 0.18))
	
	# Кристальные друзы
	for cr in crystals:
		draw_circle(cr["pos"], cr["size"], cr["col"])
		draw_circle(cr["pos"], cr["size"] * 0.4, Color(1, 1, 1, 0.9))
		
	# Каменная дорога с лавово-энергетическими прожилками
	_draw_road(Color(0.28, 0.26, 0.35), Color(0.18, 0.16, 0.22))
	_draw_bridge(layout.get("bridge", Vector2(680, 350)))
	_draw_village(layout.get("village", Vector2(1120, 600)), Color(0.3, 0.5, 0.8))

func _draw_frost_biome() -> void:
	var layout = _get_current_layout()
	# Морозный пик: лед, снег и сине-белая палитра
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.82, 0.88, 0.94))
	draw_circle(Vector2(200, 150), 210, Color(0.88, 0.93, 0.98))
	draw_circle(Vector2(600, 170), 230, Color(0.88, 0.93, 0.98))
	draw_circle(Vector2(1000, 190), 220, Color(0.88, 0.93, 0.98))
	
	# Замерзший бирюзовый ледник
	var ice_col = Color(0.45, 0.80, 0.92, 0.85)
	draw_circle(Vector2(500, 380), 70, ice_col)
	draw_circle(Vector2(850, 360), 80, ice_col)
	
	# Заснеженная дорога
	_draw_road(Color(0.70, 0.78, 0.86), Color(0.50, 0.58, 0.66))
	_draw_bridge(layout.get("bridge", Vector2(600, 380)))
	_draw_village(layout.get("village", Vector2(1120, 200)), Color(0.4, 0.6, 0.85))

func _draw_citadel_biome() -> void:
	var layout = _get_current_layout()
	# Осажденный город: мощеная площадь, факелы и бастионы
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.22, 0.23, 0.26))
	draw_circle(Vector2(300, 160), 220, Color(0.27, 0.28, 0.32))
	draw_circle(Vector2(700, 180), 240, Color(0.27, 0.28, 0.32))
	draw_circle(Vector2(1050, 180), 230, Color(0.27, 0.28, 0.32))
	
	# Мощеная мостовая
	_draw_road(Color(0.38, 0.39, 0.42), Color(0.18, 0.19, 0.21))
	_draw_bridge(layout.get("bridge", Vector2(740, 360)))
	_draw_village(layout.get("village", Vector2(1120, 340)), Color(0.8, 0.2, 0.2))

func _draw_road(fill_col: Color, border_col: Color) -> void:
	if path2d and path2d.curve:
		var pts = path2d.curve.get_baked_points()
		if pts.size() > 1:
			draw_polyline(pts, Color(0.0, 0.0, 0.0, 0.25), 72.0)
			draw_polyline(pts, border_col, 62.0)
			draw_polyline(pts, fill_col, 48.0)
			draw_polyline(pts, fill_col.darkened(0.1), 22.0)

func _draw_bridge(b_pos: Vector2) -> void:
	draw_rect(Rect2(b_pos.x - 45, b_pos.y - 20, 90, 40), Color(0.55, 0.38, 0.22))
	for b_i in range(8):
		var px = b_pos.x - 40 + b_i * 11
		draw_rect(Rect2(px, b_pos.y - 22, 9, 44), Color(0.68, 0.48, 0.28))

func _draw_trees() -> void:
	for t in trees:
		var p = t["pos"]
		var s = t["scale"]
		draw_rect(Rect2(p.x - 4 * s, p.y, 8 * s, 14 * s), Color(0.45, 0.28, 0.15))
		draw_circle(p + Vector2(0, -4 * s), 16 * s, Color(0.18, 0.45, 0.18))
		draw_circle(p + Vector2(0, -12 * s), 12 * s, Color(0.24, 0.54, 0.22))

func _draw_village(v_pos: Vector2, roof_col: Color) -> void:
	draw_circle(v_pos + Vector2(80, 50), 90.0, Color(0.65, 0.62, 0.58))
	var h1 = v_pos + Vector2(25, -20)
	draw_rect(Rect2(h1.x, h1.y, 48, 42), Color(0.85, 0.80, 0.72))
	draw_polygon(PackedVector2Array([h1 + Vector2(-6, 0), h1 + Vector2(24, -24), h1 + Vector2(54, 0)]), PackedColorArray([roof_col, roof_col, roof_col]))
	
	var h2 = v_pos + Vector2(80, 15)
	draw_rect(Rect2(h2.x, h2.y, 42, 38), Color(0.80, 0.75, 0.68))
	draw_polygon(PackedVector2Array([h2 + Vector2(-5, 0), h2 + Vector2(21, -20), h2 + Vector2(47, 0)]), PackedColorArray([roof_col.darkened(0.15), roof_col.darkened(0.15), roof_col.darkened(0.15)]))

func _draw_weather_overlay() -> void:
	if not is_instance_valid(weather_system):
		return
		
	match weather_system.current_weather:
		"rain":
			# Анимированные капли дождя
			for i in range(70):
				var rx = fposmod(i * 47.0 + scene_anim_time * 500.0, 1280.0)
				var ry = fposmod(i * 31.0 + scene_anim_time * 800.0, 720.0)
				draw_line(Vector2(rx, ry), Vector2(rx - 6, ry + 16), Color(0.7, 0.85, 1.0, 0.45), 1.5)
		"snow":
			# Падающие снежинки
			for i in range(80):
				var sx = fposmod(i * 39.0 + sin(scene_anim_time + i) * 30.0, 1280.0)
				var sy = fposmod(i * 29.0 + scene_anim_time * 90.0, 720.0)
				draw_circle(Vector2(sx, sy), 2.5, Color(1.0, 1.0, 1.0, 0.75))
		"fog":
			# Туманная пелена
			draw_rect(Rect2(0, 0, 1280, 720), Color(0.85, 0.88, 0.92, 0.22 + sin(scene_anim_time * 1.5) * 0.05))
		"thunderstorm":
			# Ливень и вспышки молний
			for i in range(100):
				var tx = fposmod(i * 43.0 + scene_anim_time * 700.0, 1280.0)
				var ty = fposmod(i * 27.0 + scene_anim_time * 1000.0, 720.0)
				draw_line(Vector2(tx, ty), Vector2(tx - 10, ty + 24), Color(0.8, 0.9, 1.0, 0.6), 2.0)
			if lightning_flash_timer > 0.0:
				draw_rect(Rect2(0, 0, 1280, 720), Color(1.0, 1.0, 1.0, 0.35))
		"eclipse":
			# Затмение: фиолетово-темная виньетка
			draw_rect(Rect2(0, 0, 1280, 720), Color(0.12, 0.05, 0.20, 0.35))
