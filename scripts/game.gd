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
var active_targeting_spell: String = ""
var active_spell_vfx: Array = []

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
	artifact_manager.grant_starter_artifacts()
	if is_instance_valid(hud) and is_instance_valid(hud.artifacts_modal):
		hud.artifacts_modal.set_artifact_manager(artifact_manager)
	
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
	spell_system.spell_cast_at.connect(_on_spell_cast_at)
	tech_tree_manager.research_points_changed.connect(hud.update_research_points)
	hud.spell_targeting_requested.connect(_on_spell_targeting_requested)
	
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
		
	if is_instance_valid(tech_tree_manager):
		tech_tree_manager.reset_tree(2)
	if is_instance_valid(artifact_manager):
		artifact_manager.grant_starter_artifacts()
		if is_instance_valid(hud) and is_instance_valid(hud.artifacts_modal):
			hud.artifacts_modal.set_artifact_manager(artifact_manager)
	
	if is_instance_valid(hud):
		hud.end_screen.visible = false
		hud.set_wave_button_enabled(true)
		hud.hide_boss_bar()
		hud.update_research_points(tech_tree_manager.research_points if tech_tree_manager else 0)
		
	if is_instance_valid(wave_controller):
		wave_controller.reset_waves()
		wave_controller.start_wave_countdown(GameManager.PRE_WAVE_TIME)
		_update_wave_preview(1)

func _process(delta: float) -> void:
	scene_anim_time += delta
	if lightning_flash_timer > 0.0:
		lightning_flash_timer -= delta
		
	# Process active spell effects
	if not active_spell_vfx.is_empty():
		var i = active_spell_vfx.size() - 1
		while i >= 0:
			var vfx = active_spell_vfx[i]
			vfx["t"] = float(vfx.get("t", 0.0)) + delta
			if vfx.get("type") == "gold_rain" and vfx.has("coins"):
				for c in vfx["coins"]:
					c["pos"].y += float(c.get("speed", 300.0)) * delta
			if vfx["t"] >= float(vfx.get("duration", 1.0)):
				active_spell_vfx.remove_at(i)
			i -= 1
		
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
	if dmg <= 0.0 or type == "blocked":
		_spawn_floating_text("🛡️ Броня!", Color(0.78, 0.80, 0.88), pos + Vector2(0, -10), 12)
		return
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
		
	# Начисление очков исследований
	var rp = 2 if wave_num % 5 == 0 else 1
	if is_instance_valid(tech_tree_manager):
		tech_tree_manager.add_points(rp)
	_spawn_floating_text("📜 +%d Очка Исследований!" % rp, Color(0.4, 0.85, 1.0), Vector2(640, 240), 18)
	
	# Пассивный доход древа технологий
	if is_instance_valid(tech_tree_manager) and is_instance_valid(game_manager):
		var bonus_gold = tech_tree_manager.get_end_wave_bonus_gold()
		if bonus_gold > 0:
			game_manager.add_gold(bonus_gold)
			_spawn_floating_text("🪙 +%d Золота (Технологии)!" % bonus_gold, Color(1.0, 0.9, 0.3), Vector2(640, 270), 16)
			
	# Разблокировка реликвий за волны
	if wave_num in [3, 7, 12, 16] and is_instance_valid(artifact_manager):
		var art_id = artifact_manager.unlock_next_artifact()
		if art_id != "":
			var art_data = artifact_manager.get_artifact_data(art_id)
			var aname = art_data.get("name", art_id)
			_spawn_floating_text("💎 Найдена реликвия: %s!" % aname, Color(1.0, 0.85, 0.2), Vector2(640, 180), 22)
			
	# Реликвия "Рог Изобилия" (horn_of_plenty): бесплатный метеор на четных волнах
	if wave_num % 2 == 0 and is_instance_valid(artifact_manager) and artifact_manager.has_active_effect("free_meteor_even_waves"):
		var enemies = get_tree().get_nodes_in_group("enemies")
		var meteor_pos = Vector2(500, 350)
		if enemies.size() > 0 and is_instance_valid(enemies[0]):
			meteor_pos = enemies[0].global_position
		spell_system.cast_spell("meteor", meteor_pos)
		_spawn_floating_text("📯 Рог Изобилия: Бесплатный Метеор!", Color(1.0, 0.6, 0.2), meteor_pos, 18)
		
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
	var lives = game_manager.lives if is_instance_valid(game_manager) else 5
	var stars = 3 if lives >= 5 else (2 if lives >= 3 else 1)
	if is_instance_valid(hud):
		hud.end_title.text = "👑 ПОБЕДА В БИОМЕ!"
		hud.end_subtitle.text = "Вы спасли королевство и защитили всех жителей!\nНачислено 30 Очков Славы! ⭐ x%d" % stars
		hud.end_screen.visible = true
	if is_instance_valid(meta_manager):
		meta_manager.add_glory(30)
		meta_manager.set_map_stars(GlobalState.selected_map, stars)


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
	if active_targeting_spell != "":
		if event is InputEventMouseMotion:
			queue_redraw()
		elif event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				var cast_pos = get_global_mouse_position()
				var s_id = active_targeting_spell
				active_targeting_spell = ""
				spell_system.cast_spell(s_id, cast_pos)
				queue_redraw()
				get_viewport().set_input_as_handled()
				return
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				active_targeting_spell = ""
				_spawn_floating_text("❌ Применение отменено", Color(0.8, 0.8, 0.8), get_global_mouse_position(), 14)
				queue_redraw()
				get_viewport().set_input_as_handled()
				return
		elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			active_targeting_spell = ""
			queue_redraw()
			get_viewport().set_input_as_handled()
			return

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
			
	# 4. Визуальные эффекты заклинаний
	_draw_spell_effects()
	
	# 5. Интерактивный прицел заклинания
	if active_targeting_spell != "":
		_draw_spell_targeting_reticle()

func _draw_valley_biome() -> void:
	var layout = _get_current_layout()
	# 1. Богатый живописный ландшафт Изумрудной долины (холмы и луга)
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.26, 0.52, 0.20))
	
	# Мягкие контуры холмов и перепады рельефа
	var meadow_light = Color(0.32, 0.60, 0.24)
	var meadow_mid = Color(0.24, 0.48, 0.18)
	var meadow_shadow = Color(0.18, 0.38, 0.14)
	
	# Верхний ярус холмов
	var hill_poly_1 = PackedVector2Array([
		Vector2(0, 0), Vector2(1280, 0), Vector2(1280, 160),
		Vector2(950, 190), Vector2(650, 140), Vector2(350, 200), Vector2(0, 150)
	])
	draw_colored_polygon(hill_poly_1, meadow_light)
	draw_polyline(hill_poly_1, meadow_mid, 3.0)
	
	# Нижний ярус холмов
	var hill_poly_2 = PackedVector2Array([
		Vector2(0, 720), Vector2(1280, 720), Vector2(1280, 620),
		Vector2(1000, 580), Vector2(600, 640), Vector2(250, 590), Vector2(0, 650)
	])
	draw_colored_polygon(hill_poly_2, meadow_mid)
	draw_polyline(hill_poly_2, meadow_shadow, 2.5)
	
	# 2. Озеро с песчаной береговой линией, бирюзовой глубиной и водной пеной
	var br = layout.get("bridge", Vector2(550, 420))
	# Песчаный пологий берег
	draw_set_transform(br, 0.0, Vector2(1.2, 0.75))
	draw_circle(Vector2.ZERO, 78.0, Color(0.85, 0.75, 0.48))
	draw_circle(Vector2.ZERO, 72.0, Color(0.92, 0.84, 0.56))
	# Водная гладь: мелководье и глубокая вода
	draw_circle(Vector2.ZERO, 64.0, Color(0.35, 0.72, 0.85))
	draw_circle(Vector2(-4, -2), 48.0, Color(0.20, 0.52, 0.75))
	draw_circle(Vector2(-6, -4), 32.0, Color(0.12, 0.38, 0.62))
	# Береговая белая пенка
	draw_arc(Vector2.ZERO, 64.0, 0, TAU, 32, Color(1.0, 1.0, 1.0, 0.55), 1.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 1.0))
	
	# 3. Текстурные травинки и полевые цветы
	for flower in flower_patches:
		var fp = flower["pos"]
		var fcol: Color = flower["col"]
		# Стебель и лепестки
		draw_line(fp, fp + Vector2(0, -3), Color(0.18, 0.45, 0.15), 1.2)
		draw_circle(fp + Vector2(0, -4), 2.2, fcol)
		draw_circle(fp + Vector2(0, -4), 1.0, Color(1.0, 0.95, 0.5))
		
	# 4. Деревья и рощи
	_draw_trees()
		
	# 5. Извилистая мощеная дорога с каменной брусчаткой
	_draw_road(Color(0.82, 0.74, 0.55), Color(0.55, 0.48, 0.36))
	
	# 6. Деревянный мост и средневековая деревушка
	_draw_bridge(br)
	_draw_village(layout.get("village", Vector2(1120, 540)), Color(0.82, 0.30, 0.18))

func _draw_swamp_biome() -> void:
	var layout = _get_current_layout()
	# Мрачные торфяные болота
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.14, 0.20, 0.15))
	
	# Топи и трясина
	var mud_poly = PackedVector2Array([
		Vector2(0, 0), Vector2(1280, 0), Vector2(1280, 220),
		Vector2(850, 180), Vector2(500, 240), Vector2(0, 170)
	])
	draw_colored_polygon(mud_poly, Color(0.10, 0.16, 0.12))
	
	# Кислотные ядовитые заводи со светящейся ряской
	var br = layout.get("bridge", Vector2(640, 400))
	draw_set_transform(br, 0.0, Vector2(1.3, 0.7))
	draw_circle(Vector2.ZERO, 72.0, Color(0.18, 0.35, 0.22))
	draw_circle(Vector2.ZERO, 58.0, Color(0.25, 0.65, 0.32, 0.85))
	draw_circle(Vector2(-3, 0), 38.0, Color(0.35, 0.85, 0.40, 0.7))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 1.0))
	
	# Биолюминесцентные гигантские грибы
	for m in swamp_mushrooms:
		var mp = m["pos"]
		var ms = m["size"]
		# Ножка гриба
		draw_line(mp, mp + Vector2(0, -ms * 0.9), Color(0.75, 0.72, 0.65), 3.0)
		# Шляпка с точками
		var cap = PackedVector2Array([
			mp + Vector2(-ms, -ms * 0.7), mp + Vector2(0, -ms * 1.6), mp + Vector2(ms, -ms * 0.7)
		])
		draw_colored_polygon(cap, Color(0.20, 0.80, 0.45, 0.9))
		draw_circle(mp + Vector2(0, -ms * 1.2), ms * 0.2, Color(0.8, 1.0, 0.7))
		draw_circle(mp + Vector2(-ms * 0.4, -ms * 0.9), ms * 0.15, Color(0.8, 1.0, 0.7))
		draw_circle(mp + Vector2(ms * 0.4, -ms * 0.9), ms * 0.15, Color(0.8, 1.0, 0.7))
		
	# Гнилая гать / тропа
	_draw_road(Color(0.35, 0.30, 0.24), Color(0.22, 0.18, 0.14))
	_draw_bridge(br)
	_draw_village(layout.get("village", Vector2(1120, 460)), Color(0.40, 0.30, 0.50))

func _draw_caves_biome() -> void:
	var layout = _get_current_layout()
	# Базальтовые пещеры с кристаллами
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.08, 0.08, 0.11))
	
	# Гранитные уступы
	var rock_poly = PackedVector2Array([
		Vector2(0, 0), Vector2(1280, 0), Vector2(1280, 180),
		Vector2(900, 150), Vector2(500, 200), Vector2(0, 160)
	])
	draw_colored_polygon(rock_poly, Color(0.12, 0.12, 0.16))
	
	# Светящиеся кристаллические друзы с фасетками
	for cr in crystals:
		var cp = cr["pos"]
		var cs = cr["size"]
		var c_col: Color = cr["col"]
		var cr_poly = PackedVector2Array([
			cp + Vector2(0, -cs * 1.5), cp + Vector2(cs * 0.6, 0),
			cp + Vector2(0, cs * 0.4), cp + Vector2(-cs * 0.6, 0)
		])
		draw_colored_polygon(cr_poly, c_col)
		draw_colored_polygon(PackedVector2Array([cp + Vector2(0, -cs * 1.5), cp + Vector2(cs * 0.6, 0), cp + Vector2(0, cs * 0.4)]), c_col.lightened(0.4))
		draw_polyline(cr_poly, Color(1, 1, 1, 0.8), 1.2)
		
	# Дорога из вулканического камня
	_draw_road(Color(0.26, 0.24, 0.32), Color(0.16, 0.14, 0.20))
	_draw_bridge(layout.get("bridge", Vector2(680, 350)))
	_draw_village(layout.get("village", Vector2(1120, 600)), Color(0.25, 0.45, 0.75))

func _draw_frost_biome() -> void:
	var layout = _get_current_layout()
	# Заснеженные горы и ледник
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.84, 0.90, 0.95))
	
	# Лазурные снежные сугробы
	var drift_poly = PackedVector2Array([
		Vector2(0, 0), Vector2(1280, 0), Vector2(1280, 190),
		Vector2(880, 150), Vector2(480, 210), Vector2(0, 170)
	])
	draw_colored_polygon(drift_poly, Color(0.75, 0.84, 0.92))
	
	# Замерзшее лазурное озеро с трещинами
	var br = layout.get("bridge", Vector2(600, 380))
	draw_set_transform(br, 0.0, Vector2(1.2, 0.65))
	draw_circle(Vector2.ZERO, 68.0, Color(0.45, 0.80, 0.92, 0.85))
	draw_circle(Vector2.ZERO, 45.0, Color(0.60, 0.90, 0.98, 0.9))
	# Трещины во льду
	draw_line(Vector2(-30, -10), Vector2(25, 15), Color(1.0, 1.0, 1.0, 0.85), 1.5)
	draw_line(Vector2(5, 0), Vector2(-10, 25), Color(1.0, 1.0, 1.0, 0.7), 1.2)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 1.0))
	
	# Заснеженная дорога
	_draw_road(Color(0.68, 0.76, 0.84), Color(0.46, 0.54, 0.62))
	_draw_bridge(br)
	_draw_village(layout.get("village", Vector2(1120, 200)), Color(0.35, 0.55, 0.80))

func _draw_citadel_biome() -> void:
	var layout = _get_current_layout()
	# Каменная площадь имперской цитадели
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.24, 0.25, 0.28))
	
	# Каменные стены крепости
	var fort_poly = PackedVector2Array([
		Vector2(0, 0), Vector2(1280, 0), Vector2(1280, 170),
		Vector2(950, 140), Vector2(550, 180), Vector2(0, 150)
	])
	draw_colored_polygon(fort_poly, Color(0.30, 0.32, 0.36))
	
	# Мощеная мостовая
	_draw_road(Color(0.38, 0.40, 0.44), Color(0.18, 0.19, 0.22))
	_draw_bridge(layout.get("bridge", Vector2(740, 360)))
	_draw_village(layout.get("village", Vector2(1120, 340)), Color(0.85, 0.25, 0.20))

func _draw_road(fill_col: Color, border_col: Color) -> void:
	if path2d and path2d.curve:
		var pts = path2d.curve.get_baked_points()
		if pts.size() > 1:
			# 1. Мягкая внешняя грунтовая тень
			draw_polyline(pts, Color(0.0, 0.0, 0.0, 0.28), 68.0)
			# 2. Земляной бордюр дороги
			draw_polyline(pts, border_col, 56.0)
			# 3. Основная песчано-гравийная насыпь
			draw_polyline(pts, fill_col, 44.0)
			# 4. Колеи от повозок
			draw_polyline(pts, fill_col.darkened(0.16), 18.0)
			# 5. Каменные булыжники вдоль дороги (брусчатка)
			for i in range(0, pts.size(), 4):
				var p = pts[i]
				var stone_col = fill_col.lightened(0.15) if (i % 8 == 0) else fill_col.darkened(0.12)
				draw_circle(p + Vector2(sin(float(i)) * 6.0, cos(float(i)) * 4.0), 2.2, stone_col)

func _draw_bridge(b_pos: Vector2) -> void:
	# 2.5D Арочный бревенчатый мост через реку
	var wood_dark = Color(0.35, 0.22, 0.12)
	var wood_mid = Color(0.55, 0.38, 0.22)
	var wood_light = Color(0.70, 0.50, 0.30)
	
	# Тень моста на воде
	draw_rect(Rect2(b_pos.x - 48, b_pos.y - 12, 96, 38), Color(0.0, 0.0, 0.0, 0.35))
	
	# Несущие сваи в воде
	draw_rect(Rect2(b_pos.x - 42, b_pos.y - 24, 8, 48), wood_dark)
	draw_rect(Rect2(b_pos.x + 34, b_pos.y - 24, 8, 48), wood_dark)
	
	# Настил из дубовых досок
	for b_i in range(9):
		var px = b_pos.x - 44 + b_i * 10
		var plank_col = wood_mid if b_i % 2 == 0 else wood_light
		draw_rect(Rect2(px, b_pos.y - 20, 9, 40), plank_col)
		# Шляпки гвоздей
		draw_circle(Vector2(px + 4.5, b_pos.y - 17), 1.0, Color(0.2, 0.2, 0.2))
		draw_circle(Vector2(px + 4.5, b_pos.y + 17), 1.0, Color(0.2, 0.2, 0.2))
		
	# Перила моста (верхние и нижние)
	draw_line(Vector2(b_pos.x - 46, b_pos.y - 20), Vector2(b_pos.x + 46, b_pos.y - 20), wood_dark, 3.5)
	draw_line(Vector2(b_pos.x - 46, b_pos.y + 20), Vector2(b_pos.x + 46, b_pos.y + 20), wood_dark, 3.5)

func _draw_trees() -> void:
	for t in trees:
		var p = t["pos"]
		var s = t["scale"]
		# Тень под кроной дерева в ракурсе 2.5D
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2(p.x + 6 * s, (p.y + 14 * s) / 0.45), 18.0 * s, Color(0.0, 0.0, 0.0, 0.32))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 1.0))
		
		# Кряжистый ствол с корой и корнями
		var trunk_dark = Color(0.32, 0.18, 0.08)
		var trunk_light = Color(0.48, 0.28, 0.14)
		draw_rect(Rect2(p.x - 4 * s, p.y - 4 * s, 8 * s, 18 * s), trunk_dark)
		draw_line(Vector2(p.x - 1 * s, p.y - 4 * s), Vector2(p.x - 1 * s, p.y + 14 * s), trunk_light, 2.0 * s)
		# Корни дерева
		draw_line(Vector2(p.x - 3 * s, p.y + 12 * s), Vector2(p.x - 7 * s, p.y + 16 * s), trunk_dark, 2.0 * s)
		draw_line(Vector2(p.x + 3 * s, p.y + 12 * s), Vector2(p.x + 7 * s, p.y + 16 * s), trunk_dark, 2.0 * s)
		
		# Объемная многоярусная листва с освещением сверху-слева
		var fol_shadow = Color(0.12, 0.32, 0.14)
		var fol_mid = Color(0.20, 0.50, 0.22)
		var fol_light = Color(0.34, 0.68, 0.28)
		var fol_highlight = Color(0.50, 0.82, 0.35)
		
		# Нижний теневой ярус
		draw_circle(p + Vector2(0, -6 * s), 18 * s, fol_shadow)
		# Средний ярус
		draw_circle(p + Vector2(0, -12 * s), 15 * s, fol_mid)
		# Освещенный верхний ярус
		draw_circle(p + Vector2(-3 * s, -16 * s), 11 * s, fol_light)
		# Солнечный блик
		draw_circle(p + Vector2(-5 * s, -18 * s), 5 * s, fol_highlight)

func _draw_village(v_pos: Vector2, roof_col: Color) -> void:
	# Деревенский мощеный двор
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.6))
	draw_circle(Vector2(v_pos.x + 60, (v_pos.y + 40) / 0.6), 75.0, Color(0.58, 0.55, 0.50, 0.8))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 1.0))
	
	# Домик 1: Главная фахверковая изба с каменной трубой
	var h1 = v_pos + Vector2(15, -25)
	# Каменный цоколь и стены
	draw_rect(Rect2(h1.x, h1.y + 10, 52, 35), Color(0.88, 0.84, 0.76))
	# Деревянные фахверковые балки
	draw_line(Vector2(h1.x, h1.y + 10), Vector2(h1.x + 52, h1.y + 10), Color(0.32, 0.20, 0.10), 2.5)
	draw_line(Vector2(h1.x, h1.y + 45), Vector2(h1.x + 52, h1.y + 45), Color(0.32, 0.20, 0.10), 2.5)
	draw_line(Vector2(h1.x + 26, h1.y + 10), Vector2(h1.x + 26, h1.y + 45), Color(0.32, 0.20, 0.10), 2.0)
	# Дверь и светящееся окошко
	draw_rect(Rect2(h1.x + 8, h1.y + 24, 12, 21), Color(0.42, 0.24, 0.12))
	draw_rect(Rect2(h1.x + 32, h1.y + 20, 12, 12), Color(0.98, 0.85, 0.35))
	draw_line(Vector2(h1.x + 38, h1.y + 20), Vector2(h1.x + 38, h1.y + 32), Color(0.32, 0.20, 0.10), 1.2)
	draw_line(Vector2(h1.x + 32, h1.y + 26), Vector2(h1.x + 44, h1.y + 26), Color(0.32, 0.20, 0.10), 1.2)
	
	# Каменная печная труба с дымком
	draw_rect(Rect2(h1.x + 38, h1.y - 18, 8, 20), Color(0.45, 0.46, 0.50))
	draw_circle(Vector2(h1.x + 42, h1.y - 24), 3.0, Color(0.85, 0.85, 0.90, 0.6))
	draw_circle(Vector2(h1.x + 45, h1.y - 30), 4.5, Color(0.85, 0.85, 0.90, 0.4))
	
	# Черепичная остроконечная крыша
	var roof1 = PackedVector2Array([
		Vector2(h1.x - 6, h1.y + 10), Vector2(h1.x + 26, h1.y - 16), Vector2(h1.x + 58, h1.y + 10)
	])
	draw_colored_polygon(roof1, roof_col)
	draw_polyline(roof1, roof_col.darkened(0.3), 2.2)
	
	# Домик 2: Уютный амбар
	var h2 = v_pos + Vector2(75, 12)
	draw_rect(Rect2(h2.x, h2.y + 8, 44, 30), Color(0.75, 0.70, 0.62))
	var roof2 = PackedVector2Array([
		Vector2(h2.x - 4, h2.y + 8), Vector2(h2.x + 22, h2.y - 12), Vector2(h2.x + 48, h2.y + 8)
	])
	draw_colored_polygon(roof2, roof_col.darkened(0.18))
	draw_polyline(roof2, roof_col.darkened(0.4), 2.0)

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

func _on_spell_targeting_requested(spell_id: String) -> void:
	active_targeting_spell = spell_id
	queue_redraw()
	_spawn_floating_text("🎯 Выберите область [ЛКМ]", Color(1.0, 0.85, 0.3), get_global_mouse_position(), 15)

func _on_spell_cast_at(spell_id: String, target_pos: Vector2) -> void:
	match spell_id:
		"meteor":
			active_spell_vfx.append({
				"type": "meteor",
				"start": target_pos + Vector2(-140, -440),
				"target": target_pos,
				"t": 0.0,
				"duration": 0.35,
				"radius": 130.0
			})
			_spawn_floating_text("☄️ МЕТЕОР! 350 УРОНА", Color(1.0, 0.45, 0.1), target_pos, 18)
		"lightning":
			active_spell_vfx.append({
				"type": "lightning",
				"target": target_pos,
				"t": 0.0,
				"duration": 0.35
			})
			_spawn_floating_text("⚡ УДАР МОЛНИИ!", Color(0.4, 0.85, 1.0), target_pos, 18)
		"freeze":
			active_spell_vfx.append({
				"type": "freeze_screen",
				"t": 0.0,
				"duration": 1.0
			})
			_spawn_floating_text("❄️ ВСЯ ОРДА ЗАМОРОЖЕНА (5с)!", Color(0.35, 0.9, 1.0), Vector2(640, 200), 22)
		"gold_rain":
			active_spell_vfx.append({
				"type": "gold_rain",
				"t": 0.0,
				"duration": 1.5,
				"coins": _generate_gold_rain_coins()
			})
			_spawn_floating_text("💰 ЗОЛОТОЙ ДОЖДЬ! +120🪙", Color(1.0, 0.9, 0.2), Vector2(640, 200), 22)
		"vortex":
			active_spell_vfx.append({
				"type": "vortex",
				"pos": target_pos,
				"radius": 200.0,
				"t": 0.0,
				"duration": 3.0
			})
			_spawn_floating_text("🌪️ ВИХРЬ!", Color(0.3, 0.9, 1.0), target_pos, 18)
		"roots":
			active_spell_vfx.append({
				"type": "roots",
				"pos": target_pos,
				"radius": 150.0,
				"t": 0.0,
				"duration": 4.0
			})
			_spawn_floating_text("🌿 КОРНИ ЗЕМЛИ!", Color(0.3, 0.95, 0.3), target_pos, 18)
		"chronoshift":
			active_spell_vfx.append({
				"type": "chronoshift",
				"t": 0.0,
				"duration": 1.2
			})
			_spawn_floating_text("⏳ ВРЕМЯ ЗАМЕДЛЕНО!", Color(0.9, 0.7, 1.0), Vector2(640, 200), 22)
		"stone_wall":
			active_spell_vfx.append({
				"type": "stone_wall",
				"pos": target_pos,
				"t": 0.0,
				"duration": 6.0
			})
			_spawn_floating_text("🧱 КАМЕННЫЙ БАРЬЕР!", Color(0.85, 0.8, 0.75), target_pos, 18)
	queue_redraw()

func _generate_gold_rain_coins() -> Array:
	var coins: Array = []
	for i in range(25):
		coins.append({
			"pos": Vector2(randf_range(80, 1200), randf_range(-60, 100)),
			"speed": randf_range(350, 600),
			"size": randf_range(5.0, 8.0)
		})
	return coins

func _draw_spell_effects() -> void:
	for vfx in active_spell_vfx:
		var vtype = vfx.get("type", "")
		var t = float(vfx.get("t", 0.0))
		var dur = float(vfx.get("duration", 1.0))
		var progress = clampf(t / max(0.01, dur), 0.0, 1.0)
		var alpha = 1.0 - progress
		
		match vtype:
			"meteor":
				var start_pos: Vector2 = vfx.get("start", Vector2.ZERO)
				var target_pos: Vector2 = vfx.get("target", Vector2.ZERO)
				var fly_dur = dur * 0.65
				if t < fly_dur:
					var p = t / fly_dur
					var cur_pos = start_pos.lerp(target_pos, p)
					# Fiery tail
					var tail_start = cur_pos + (start_pos - target_pos).normalized() * 60.0
					draw_line(tail_start, cur_pos, Color(1.0, 0.35, 0.0, 0.8), 8.0)
					draw_line(cur_pos + (start_pos - target_pos).normalized() * 30.0, cur_pos, Color(1.0, 0.85, 0.2, 0.95), 4.0)
					# Flaming core
					draw_circle(cur_pos, 16.0, Color(0.9, 0.2, 0.0))
					draw_circle(cur_pos, 10.0, Color(1.0, 0.6, 0.1))
					draw_circle(cur_pos, 5.0, Color(1.0, 1.0, 0.7))
				else:
					var exp_p = (t - fly_dur) / max(0.01, (dur - fly_dur))
					var exp_alpha = 1.0 - exp_p
					var cur_r = 130.0 * sin(exp_p * PI * 0.5)
					# Explosion blast
					draw_circle(target_pos, cur_r, Color(1.0, 0.3, 0.05, 0.3 * exp_alpha))
					draw_arc(target_pos, cur_r, 0, TAU, 36, Color(1.0, 0.8, 0.2, exp_alpha), 4.0)
					draw_arc(target_pos, cur_r * 0.6, 0, TAU, 28, Color(1.0, 0.2, 0.0, exp_alpha), 3.0)
					
			"lightning":
				var target_pos: Vector2 = vfx.get("target", Vector2.ZERO)
				var segments = 7
				var prev = Vector2(target_pos.x + randf_range(-30, 30), 0)
				for s in range(segments):
					var p_next = prev.lerp(target_pos, float(s + 1) / float(segments))
					if s < segments - 1:
						p_next.x += randf_range(-35, 35)
					draw_line(prev, p_next, Color(0.2, 0.8, 1.0, 0.4 * alpha), 8.0)
					draw_line(prev, p_next, Color(0.5, 0.9, 1.0, 0.8 * alpha), 4.0)
					draw_line(prev, p_next, Color(1.0, 1.0, 1.0, alpha), 2.0)
					prev = p_next
				draw_circle(target_pos, 40.0 * (1.0 - progress), Color(0.4, 0.9, 1.0, 0.5 * alpha))
				
			"freeze_screen":
				draw_rect(Rect2(0, 0, 1280, 720), Color(0.25, 0.65, 1.0, 0.20 * alpha))
				# Icy border
				draw_rect(Rect2(0, 0, 1280, 720), Color(0.6, 0.9, 1.0, 0.35 * alpha), false, 12.0)
				
			"gold_rain":
				if vfx.has("coins"):
					for c in vfx["coins"]:
						var cp: Vector2 = c["pos"]
						var cs = float(c.get("size", 6.0))
						draw_circle(cp, cs, Color(1.0, 0.85, 0.1, alpha))
						draw_circle(cp, cs * 0.65, Color(1.0, 1.0, 0.6, alpha))
						draw_arc(cp, cs, 0, TAU, 12, Color(0.85, 0.6, 0.0, alpha), 1.5)
						
			"vortex":
				var vpos = vfx.get("pos", Vector2.ZERO)
				var vr = float(vfx.get("radius", 200.0))
				var angle = t * 7.0
				draw_circle(vpos, vr, Color(0.1, 0.7, 0.9, 0.08 * alpha))
				draw_arc(vpos, vr, angle, angle + PI * 1.2, 32, Color(0.3, 0.85, 1.0, 0.7 * alpha), 3.0)
				draw_arc(vpos, vr * 0.65, -angle * 1.3, -angle * 1.3 + PI * 1.2, 24, Color(0.5, 0.95, 1.0, 0.8 * alpha), 2.5)
				draw_arc(vpos, vr * 0.3, angle * 2.0, angle * 2.0 + PI * 1.2, 16, Color(0.8, 1.0, 1.0, alpha), 2.0)
				
			"roots":
				var rpos = vfx.get("pos", Vector2.ZERO)
				var rr = float(vfx.get("radius", 150.0))
				draw_circle(rpos, rr, Color(0.15, 0.45, 0.15, 0.15 * alpha))
				draw_arc(rpos, rr, 0, TAU, 32, Color(0.25, 0.75, 0.25, 0.8 * alpha), 3.0)
				for k in range(8):
					var a = (k * PI / 4.0) + sin(t * 2.0 + k) * 0.2
					var branch_end = rpos + Vector2(cos(a), sin(a)) * rr * 0.85
					draw_line(rpos, branch_end, Color(0.35, 0.25, 0.15, alpha), 3.0)
					draw_circle(branch_end, 5.0, Color(0.2, 0.8, 0.2, alpha))
					
			"chronoshift":
				var cr = 600.0 * progress
				draw_circle(Vector2(640, 360), cr, Color(0.7, 0.4, 1.0, 0.12 * alpha))
				draw_arc(Vector2(640, 360), cr, 0, TAU, 48, Color(0.9, 0.7, 1.0, 0.7 * alpha), 3.0)
				
			"stone_wall":
				var wpos = vfx.get("pos", Vector2.ZERO)
				draw_rect(Rect2(wpos.x - 30, wpos.y - 15, 60, 30), Color(0.4, 0.42, 0.45, alpha))
				draw_rect(Rect2(wpos.x - 30, wpos.y - 15, 60, 30), Color(0.75, 0.75, 0.8, alpha), false, 2.5)
				draw_line(Vector2(wpos.x - 30, wpos.y), Vector2(wpos.x + 30, wpos.y), Color(0.25, 0.25, 0.3, alpha), 2.0)

func _draw_spell_targeting_reticle() -> void:
	var mpos = get_global_mouse_position()
	var r = 130.0
	var col = Color(1.0, 0.5, 0.1)
	match active_targeting_spell:
		"meteor":
			r = 130.0
			col = Color(1.0, 0.45, 0.1)
		"lightning":
			r = 70.0
			col = Color(0.3, 0.85, 1.0)
		"vortex":
			r = 200.0
			col = Color(0.2, 0.85, 1.0)
		"roots":
			r = 150.0
			col = Color(0.25, 0.9, 0.3)
		"stone_wall":
			r = 55.0
			col = Color(0.8, 0.8, 0.85)
			
	var pulse = 1.0 + sin(scene_anim_time * 6.0) * 0.05
	var eff_r = r * pulse
	
	# Radius area
	draw_circle(mpos, eff_r, Color(col.r, col.g, col.b, 0.18))
	draw_arc(mpos, eff_r, 0, TAU, 48, Color(col.r, col.g, col.b, 0.9), 2.5)
	
	# Crosshairs
	draw_line(mpos - Vector2(eff_r * 0.25, 0), mpos + Vector2(eff_r * 0.25, 0), Color(1.0, 1.0, 1.0, 0.9), 2.0)
	draw_line(mpos - Vector2(0, eff_r * 0.25), mpos + Vector2(0, eff_r * 0.25), Color(1.0, 1.0, 1.0, 0.9), 2.0)
	draw_circle(mpos, 4.0, Color(1.0, 1.0, 1.0, 0.95))
