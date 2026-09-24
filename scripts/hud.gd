class_name GameHUD
extends Control

signal start_wave_pressed()
signal restart_pressed()
signal tech_tree_pressed()
signal speed_changed(multiplier: float)
signal spell_targeting_requested(spell_id: String)

# Top Bar
@onready var gold_label: Label = $TopBar/MarginContainer/HBoxContainer/GoldLabel
@onready var mana_label: Label = $TopBar/MarginContainer/HBoxContainer/ManaLabel
@onready var girls_label: Label = $TopBar/MarginContainer/HBoxContainer/GirlsLabel
@onready var wave_label: Label = $TopBar/MarginContainer/HBoxContainer/WaveLabel
@onready var weather_label: Label = $TopBar/MarginContainer/HBoxContainer/WeatherLabel
@onready var timer_label: Label = $TopBar/MarginContainer/HBoxContainer/TimerLabel
@onready var tech_btn: Button = $TopBar/MarginContainer/HBoxContainer/TechTreeButton
@onready var bestiary_btn: Button = $TopBar/MarginContainer/HBoxContainer/BestiaryButton
@onready var artifacts_btn: Button = $TopBar/MarginContainer/HBoxContainer/ArtifactsButton
@onready var start_wave_btn: Button = $TopBar/MarginContainer/HBoxContainer/StartWaveButton
@onready var help_btn: Button = $TopBar/MarginContainer/HBoxContainer/HelpButton
@onready var wave_clock: WaveClock = $TopBar/MarginContainer/HBoxContainer/WaveClock

# Управление скоростью
@onready var pause_btn: Button = $TopBar/MarginContainer/HBoxContainer/SpeedBox/PauseBtn
@onready var speed1_btn: Button = $TopBar/MarginContainer/HBoxContainer/SpeedBox/Speed1Btn
@onready var speed2_btn: Button = $TopBar/MarginContainer/HBoxContainer/SpeedBox/Speed2Btn

# Панель заклинаний (8 кнопок)
@onready var spell_meteor_btn: Button = $SpellBar/Margin/HBox/MeteorBtn
@onready var spell_freeze_btn: Button = $SpellBar/Margin/HBox/FreezeBtn
@onready var spell_gold_btn: Button = $SpellBar/Margin/HBox/GoldRainBtn
@onready var spell_lightning_btn: Button = $SpellBar/Margin/HBox/LightningBtn
@onready var spell_vortex_btn: Button = $SpellBar/Margin/HBox/VortexBtn
@onready var spell_roots_btn: Button = $SpellBar/Margin/HBox/RootsBtn
@onready var spell_chrono_btn: Button = $SpellBar/Margin/HBox/ChronoBtn
@onready var spell_wall_btn: Button = $SpellBar/Margin/HBox/WallBtn

# Комбо-панель
@onready var combo_panel: PanelContainer = $ComboPanel
@onready var combo_streak_label: Label = $ComboPanel/MarginContainer/VBoxContainer/StreakLabel
@onready var combo_mult_label: Label = $ComboPanel/MarginContainer/VBoxContainer/MultLabel
@onready var combo_timer_bar: ProgressBar = $ComboPanel/MarginContainer/VBoxContainer/TimerBar

# Панель босса
@onready var boss_panel: PanelContainer = $BossPanel
@onready var boss_name_label: Label = $BossPanel/MarginContainer/VBoxContainer/BossNameLabel
@onready var boss_hp_bar: ProgressBar = $BossPanel/MarginContainer/VBoxContainer/BossHPBar
@onready var boss_phase_label: Label = $BossPanel/MarginContainer/VBoxContainer/BossPhaseLabel

# Превью волны
@onready var wave_preview_panel: PanelContainer = $WavePreviewPanel
@onready var wave_preview_label: Label = $WavePreviewPanel/MarginContainer/WavePreviewLabel

# Панель диалогов лора
@onready var dialogue_panel: PanelContainer = $DialoguePanel
@onready var dialogue_speaker: Label = $DialoguePanel/MarginContainer/VBoxContainer/SpeakerLabel
@onready var dialogue_text: Label = $DialoguePanel/MarginContainer/VBoxContainer/TextLabel

# Панель управления выбранным слотом
@onready var action_panel: PanelContainer = $ActionPanel
@onready var spot_title: Label = $ActionPanel/VBoxContainer/SpotTitle
@onready var spot_desc: Label = $ActionPanel/VBoxContainer/SpotDesc
@onready var build_buttons_box: HBoxContainer = $ActionPanel/VBoxContainer/BuildButtons
@onready var tower_action_box: HBoxContainer = $ActionPanel/VBoxContainer/TowerActions
@onready var upgrade_btn: Button = $ActionPanel/VBoxContainer/TowerActions/UpgradeBtn
@onready var evo_a_btn: Button = $ActionPanel/VBoxContainer/TowerActions/EvoABtn
@onready var evo_b_btn: Button = $ActionPanel/VBoxContainer/TowerActions/EvoBBtn
@onready var sell_btn: Button = $ActionPanel/VBoxContainer/TowerActions/SellBtn

# Окна
@onready var tech_tree_modal: TechTreeModal = $TechTreeModal
@onready var help_modal: HelpModal = $HelpModal
@onready var hint_label: Label = $HintContainer/HintLabel
@onready var evo_preview_modal: EvolutionPreviewModal = $EvolutionPreviewModal
@onready var bestiary_modal: PanelContainer = $BestiaryModal
@onready var artifacts_modal: PanelContainer = $ArtifactsModal

# Экран окончания
@onready var end_screen: PanelContainer = $EndScreen
@onready var end_title: Label = $EndScreen/VBoxContainer/EndTitle
@onready var end_subtitle: Label = $EndScreen/VBoxContainer/EndSubtitle
@onready var restart_btn: Button = $EndScreen/VBoxContainer/RestartButton
@onready var menu_btn: Button = $EndScreen/VBoxContainer/MenuButton

const EconomyHUDWidgetScript = preload("res://scripts/economy_hud_widget.gd")

var current_spot: BuildSpot = null
var wave_countdown: float = 0.0
var counting_down: bool = false
var current_speed: float = 1.0
var dialogue_timer: float = 0.0
var economy_widget = null

func _ready() -> void:
	economy_widget = EconomyHUDWidgetScript.new()
	economy_widget.name = "EconomyHUDWidget"
	add_child(economy_widget)
	
	if is_instance_valid(action_panel):
		action_panel.visible = false
		var ap_style = StyleBoxFlat.new()
		ap_style.bg_color = Color(0.08, 0.10, 0.15, 0.98)
		ap_style.border_width_left = 2
		ap_style.border_width_top = 2
		ap_style.border_width_right = 2
		ap_style.border_width_bottom = 2
		ap_style.border_color = Color(0.85, 0.68, 0.22, 1.0)
		ap_style.set_corner_radius_all(10)
		ap_style.shadow_color = Color(0, 0, 0, 0.85)
		ap_style.shadow_size = 20
		ap_style.content_margin_left = 20
		ap_style.content_margin_right = 20
		ap_style.content_margin_top = 10
		ap_style.content_margin_bottom = 10
		action_panel.add_theme_stylebox_override("panel", ap_style)
		
	if is_instance_valid(end_screen): end_screen.visible = false
	if is_instance_valid(tech_tree_modal): tech_tree_modal.visible = false
	if is_instance_valid(help_modal): help_modal.visible = false
	if is_instance_valid(combo_panel): combo_panel.visible = false
	if is_instance_valid(boss_panel): boss_panel.visible = false
	if is_instance_valid(dialogue_panel): dialogue_panel.visible = false
	if is_instance_valid(bestiary_modal): bestiary_modal.visible = false
	if is_instance_valid(artifacts_modal): artifacts_modal.visible = false

	
	if is_instance_valid(start_wave_btn): start_wave_btn.pressed.connect(_on_start_wave_clicked)
	if is_instance_valid(wave_clock): wave_clock.clicked.connect(_on_start_wave_clicked)
	if is_instance_valid(tech_btn): tech_btn.pressed.connect(_on_tech_tree_clicked)
	if is_instance_valid(help_btn): help_btn.pressed.connect(_on_help_clicked)
	if is_instance_valid(upgrade_btn): upgrade_btn.pressed.connect(_on_upgrade_clicked)
	if is_instance_valid(sell_btn): sell_btn.pressed.connect(_on_sell_clicked)
	if is_instance_valid(restart_btn): restart_btn.pressed.connect(_on_restart_clicked)
	if is_instance_valid(menu_btn): menu_btn.pressed.connect(_on_menu_clicked)
	
	if is_instance_valid(bestiary_btn):
		bestiary_btn.pressed.connect(func():
			if is_instance_valid(bestiary_modal):
				bestiary_modal.visible = not bestiary_modal.visible
		)
	if is_instance_valid(artifacts_btn):
		artifacts_btn.pressed.connect(func():
			if is_instance_valid(artifacts_modal):
				var art_mgr = get_tree().get_first_node_in_group("artifact_manager") as ArtifactManager
				if art_mgr and artifacts_modal.has_method("set_artifact_manager"):
					artifacts_modal.set_artifact_manager(art_mgr)
				artifacts_modal.visible = not artifacts_modal.visible
				if artifacts_modal.visible and artifacts_modal.has_method("refresh_ui"):
					artifacts_modal.refresh_ui()
		)
	
	# Evolution buttons
	if is_instance_valid(evo_a_btn): evo_a_btn.pressed.connect(_on_evo_a_clicked)
	if is_instance_valid(evo_b_btn): evo_b_btn.pressed.connect(_on_evo_b_clicked)
	if is_instance_valid(evo_preview_modal):
		evo_preview_modal.evolution_confirmed.connect(_on_evolution_confirmed)
		
	if is_instance_valid(pause_btn): pause_btn.pressed.connect(func(): set_game_speed(0.0))
	if is_instance_valid(speed1_btn): speed1_btn.pressed.connect(func(): set_game_speed(1.0))
	if is_instance_valid(speed2_btn): speed2_btn.pressed.connect(func(): set_game_speed(2.0))
		
	_setup_spell_buttons()

func _setup_spell_buttons() -> void:
	var spells = [
		{"btn": spell_meteor_btn, "id": "meteor", "name": "Метеор", "cost": 40, "desc": "350 огненного урона по площади в месте курсора"},
		{"btn": spell_freeze_btn, "id": "freeze", "name": "Заморозка", "cost": 30, "desc": "Останавливает всех врагов на 5 секунд"},
		{"btn": spell_gold_btn, "id": "gold_rain", "name": "Золотой дождь", "cost": 50, "desc": "+120 золота мгновенно"},
		{"btn": spell_lightning_btn, "id": "lightning", "name": "Молния", "cost": 25, "desc": "220 урона молнией ближайшему врагу"},
		{"btn": spell_vortex_btn, "id": "vortex", "name": "Вихрь", "cost": 35, "desc": "Отбрасывает монстров назад по тропе на 4 секунды"},
		{"btn": spell_roots_btn, "id": "roots", "name": "Корни", "cost": 25, "desc": "Опутывает монстров корнями в радиусе 150 на 6 секунд"},
		{"btn": spell_chrono_btn, "id": "chronoshift", "name": "Хроносдвиг", "cost": 45, "desc": "Замедляет время для монстров на 5 секунд"},
		{"btn": spell_wall_btn, "id": "stone_wall", "name": "Каменная стена", "cost": 20, "desc": "Каменная преграда на пути монстров на 8 секунд"}
	]
	
	for i in range(spells.size()):
		var sp = spells[i]
		var btn: Button = sp["btn"]
		if is_instance_valid(btn):
			var s_id = sp["id"]
			btn.pressed.connect(func(): _cast_player_spell(s_id))
			btn.tooltip_text = "[%d] %s (%d маны)\n%s" % [i + 1, sp["name"], sp["cost"], sp["desc"]]

func _process(delta: float) -> void:
	if counting_down:
		wave_countdown -= delta
		if wave_countdown > 0.0:
			if is_instance_valid(timer_label):
				timer_label.text = "⏱️ %ds (+10%% 🪙)" % int(ceil(wave_countdown))
		else:
			counting_down = false
			if is_instance_valid(timer_label):
				timer_label.text = "⚔️ Битва идет!"
				
	_update_spell_cooldown_ui()
	
	if dialogue_timer > 0.0:
		dialogue_timer -= delta
		if dialogue_timer <= 0.0 and is_instance_valid(dialogue_panel):
			dialogue_panel.visible = false

func set_game_speed(speed: float) -> void:
	current_speed = speed
	Engine.time_scale = speed
	speed_changed.emit(speed)
	
	if is_instance_valid(pause_btn) and is_instance_valid(speed1_btn) and is_instance_valid(speed2_btn):
		pause_btn.modulate = Color(1.2, 1.2, 0.4) if speed == 0.0 else Color(1, 1, 1)
		speed1_btn.modulate = Color(0.4, 1.2, 0.4) if speed == 1.0 else Color(1, 1, 1)
		speed2_btn.modulate = Color(0.4, 1.0, 1.4) if speed == 2.0 else Color(1, 1, 1)

func _update_spell_cooldown_ui() -> void:
	var spell_sys = get_tree().get_first_node_in_group("spell_system") as SpellSystem
	if not spell_sys:
		return
		
	var btn_map = {
		"meteor": spell_meteor_btn,
		"freeze": spell_freeze_btn,
		"gold_rain": spell_gold_btn,
		"lightning": spell_lightning_btn,
		"vortex": spell_vortex_btn,
		"roots": spell_roots_btn,
		"chronoshift": spell_chrono_btn,
		"stone_wall": spell_wall_btn
	}
	
	for s_id in btn_map:
		var btn = btn_map[s_id]
		if not is_instance_valid(btn):
			continue
		var cd = spell_sys.cooldowns.get(s_id, 0.0)
		if cd > 0.0:
			btn.disabled = true
			btn.text = "%s\n%.1fc" % [_get_spell_icon(s_id), cd]
		else:
			btn.disabled = not spell_sys.can_cast(s_id)
			btn.text = "%s" % _get_spell_icon(s_id)

func _get_spell_icon(s_id: String) -> String:
	match s_id:
		"meteor": return "☄️ [1]"
		"freeze": return "❄️ [2]"
		"gold_rain": return "💰 [3]"
		"lightning": return "⚡ [4]"
		"vortex": return "🌪️ [5]"
		"roots": return "🌿 [6]"
		"chronoshift": return "⏳ [7]"
		"stone_wall": return "🧱 [8]"
	return "✨"

func _cast_player_spell(spell_id: String) -> void:
	var spell_sys = get_tree().get_first_node_in_group("spell_system") as SpellSystem
	if not spell_sys:
		return
	if not spell_sys.can_cast(spell_id):
		return
	if spell_id in ["freeze", "gold_rain", "chronoshift"]:
		spell_sys.cast_spell(spell_id)
	else:
		spell_targeting_requested.emit(spell_id)


func set_countdown(seconds: float) -> void:
	wave_countdown = seconds
	counting_down = true
	if is_instance_valid(wave_clock):
		wave_clock.set_countdown(seconds, GameManager.PRE_WAVE_TIME)

func stop_countdown() -> void:
	counting_down = false
	if is_instance_valid(wave_clock):
		wave_clock.set_countdown(0.0)
	if is_instance_valid(timer_label):
		timer_label.text = "⚔️ Защищайте девочек!"

func update_gold(amount: int) -> void:
	if is_instance_valid(gold_label):
		gold_label.text = "🪙 %d" % amount
	_refresh_action_panel()

func update_mana(cur: int, max_m: int) -> void:
	if is_instance_valid(mana_label):
		mana_label.text = "🧪 %d/%d" % [cur, max_m]

func update_girls_count(girls_left: int) -> void:
	if is_instance_valid(girls_label):
		var hearts = ""
		for i in range(girls_left):
			hearts += "❤️"
		girls_label.text = "👧 %s (%d)" % [hearts, girls_left]

func update_wave(current: int, total: int) -> void:
	if is_instance_valid(wave_label):
		wave_label.text = "🌊 Волна %d/%d" % [current, total]

func update_weather(weather_name: String) -> void:
	if not is_instance_valid(weather_label):
		return
	var text = "🌤️ Ясно"
	var tip = "Обычная ясная погода. Без штрафов."
	match weather_name:
		"rain":
			text = "🌧️ Дождь"
			tip = "Дождь: +25% урон молнией, -30% урон огнем"
		"snow":
			text = "❄️ Снегопад"
			tip = "Снегопад: +20% урон льдом, -10% скорость монстров"
		"fog":
			text = "🌫️ Туман"
			tip = "Густой туман: -20% дальность обзора башен"
		"thunderstorm":
			text = "⛈️ Гроза"
			tip = "Гроза: +40% урон молнией, периодические удары молний по полю"
		"eclipse":
			text = "🌑 Затмение"
			tip = "Затмение: монстры в ярости (+20% скорость передвижения)"
	weather_label.text = text
	weather_label.tooltip_text = tip

func update_combo(streak: int, multiplier: float, time_left: float, max_time: float) -> void:
	if not is_instance_valid(combo_panel):
		return
	if streak <= 0:
		combo_panel.visible = false
		return
		
	combo_panel.visible = true
	if is_instance_valid(combo_streak_label):
		combo_streak_label.text = "🔥 СЕРИЯ: %d" % streak
	if is_instance_valid(combo_mult_label):
		combo_mult_label.text = "x%.1f ЗОЛОТО" % multiplier
	if is_instance_valid(combo_timer_bar):
		combo_timer_bar.max_value = max_time
		combo_timer_bar.value = time_left

func show_boss_bar(boss_name: String, current_hp: float, max_hp: float, shield: float, max_shield: float, phase_text: String) -> void:
	if not is_instance_valid(boss_panel):
		return
	boss_panel.visible = true
	if is_instance_valid(boss_name_label):
		boss_name_label.text = "👑 %s" % boss_name
	if is_instance_valid(boss_hp_bar):
		boss_hp_bar.max_value = max_hp
		boss_hp_bar.value = current_hp
	if is_instance_valid(boss_phase_label):
		if shield > 0.0:
			boss_phase_label.text = "🛡️ Щит: %d / %d | %s" % [int(shield), int(max_shield), phase_text]
		else:
			boss_phase_label.text = phase_text

func hide_boss_bar() -> void:
	if is_instance_valid(boss_panel):
		boss_panel.visible = false

func show_wave_preview(text: String) -> void:
	if not is_instance_valid(wave_preview_panel) or not is_instance_valid(wave_preview_label):
		return
	wave_preview_label.text = text
	wave_preview_panel.visible = text != ""

func show_dialogue(speaker: String, text: String, duration: float = 6.0) -> void:
	if not is_instance_valid(dialogue_panel):
		return
	if is_instance_valid(dialogue_speaker):
		dialogue_speaker.text = "🗣️ %s" % speaker
	if is_instance_valid(dialogue_text):
		dialogue_text.text = text
	dialogue_panel.visible = true
	dialogue_timer = duration

func update_research_points(amount: int) -> void:
	if is_instance_valid(tech_btn):
		tech_btn.text = "📜 Древо (%d)" % amount
		tech_btn.modulate = Color(1.2, 1.1, 0.3) if amount > 0 else Color(1, 1, 1)
	if is_instance_valid(tech_tree_modal) and tech_tree_modal.visible:
		tech_tree_modal._update_ui(amount)

func set_wave_button_enabled(enabled: bool) -> void:
	if is_instance_valid(start_wave_btn):
		start_wave_btn.disabled = not enabled

func set_hint(text_msg: String) -> void:
	if is_instance_valid(hint_label):
		hint_label.text = text_msg

func show_spot_panel(spot: BuildSpot) -> void:
	current_spot = spot
	if not is_instance_valid(action_panel):
		return
	if not spot:
		action_panel.visible = false
		return
		
	action_panel.visible = true
	_refresh_action_panel()

func _refresh_action_panel() -> void:
	if not is_instance_valid(action_panel) or not is_instance_valid(build_buttons_box) or not is_instance_valid(tower_action_box):
		return
	if not is_instance_valid(current_spot):
		action_panel.visible = false
		return
		
	var game_manager = get_tree().get_first_node_in_group("game_manager") as GameManager
	var current_gold = game_manager.gold if game_manager else 0
	
	if not current_spot.has_tower():
		if is_instance_valid(spot_title): spot_title.text = "🏗️ Свободная площадка под башню"
		if is_instance_valid(spot_desc): spot_desc.text = "Выберите защитное сооружение для постройки:"
		build_buttons_box.visible = true
		tower_action_box.visible = false
		_rebuild_tower_buttons(current_gold)
	else:
		var tower = current_spot.current_tower
		var t_name = tower.tower_name if "tower_name" in tower else "Башня"
		var t_lvl = tower.current_level if "current_level" in tower else 1
		var t_dmg = tower.get_effective_damage() if tower.has_method("get_effective_damage") else 0.0
		var t_rng = tower.get_effective_range() if tower.has_method("get_effective_range") else 0.0
		var t_spd = tower.get_effective_attack_speed() if tower.has_method("get_effective_attack_speed") else 0.0

		if is_instance_valid(spot_title):
			spot_title.text = "🏰 %s (Ур. %d)" % [t_name, t_lvl]
		if is_instance_valid(spot_desc):
			spot_desc.text = "⚔️ Урон: %.1f | 🎯 Дальность: %.0f | ⚡ Скорость: %.2f/с" % [t_dmg, t_rng, t_spd]

		build_buttons_box.visible = false
		tower_action_box.visible = true

		var can_evo = current_spot.can_evolve_tower()
		if can_evo:
			upgrade_btn.visible = false
			evo_a_btn.visible = true
			evo_b_btn.visible = true

			var a_data = tower.get_evolution_info("evolution_a")
			var b_data = tower.get_evolution_info("evolution_b")
			var a_cost = int(a_data.get("cost", 240))
			var b_cost = int(b_data.get("cost", 240))
			evo_a_btn.text = "👑 %s (%d🪙)" % [a_data.get("name", "Ветка A"), a_cost]
			evo_b_btn.text = "👑 %s (%d🪙)" % [b_data.get("name", "Ветка B"), b_cost]
			evo_a_btn.disabled = current_gold < a_cost
			evo_b_btn.disabled = current_gold < b_cost
		else:
			evo_a_btn.visible = false
			evo_b_btn.visible = false
			upgrade_btn.visible = true

			if tower.has_method("can_upgrade") and tower.can_upgrade():
				var up_cost = int(tower.upgrade_cost) if "upgrade_cost" in tower else 0
				upgrade_btn.text = "⬆️ Улучшить (%d 🪙)" % up_cost
				upgrade_btn.disabled = current_gold < up_cost
			else:
				var ch_max = tower.get_chapter_max_level() if tower.has_method("get_chapter_max_level") else 5
				if t_lvl == 3 and ch_max == 3:
					upgrade_btn.text = "🔒 Ур. 4 доступен с Главы 2"
				elif t_lvl == 4 and ch_max == 4:
					upgrade_btn.text = "🔒 Эволюция (Ур. 5) с Главы 3"
				elif t_lvl >= 5:
					upgrade_btn.text = "👑 Легендарный уровень (Макс)"
				else:
					upgrade_btn.text = "⭐ Макс. уровень"
				upgrade_btn.disabled = true

		var sell_val = current_spot.get_sell_value()
		sell_btn.text = "💰 Продать (+%d 🪙)" % sell_val


func _rebuild_tower_buttons(current_gold: int) -> void:
	for child in build_buttons_box.get_children():
		child.queue_free()
	
	var game_manager = get_tree().get_first_node_in_group("game_manager") as GameManager
	if not game_manager:
		return
	
	var avail = game_manager.get_available_towers()
	for t_type in avail:
		var tdata = game_manager.tower_data.get(t_type, {})
		var cost = int(tdata.get("cost", 100))
		var t_name = str(tdata.get("name", t_type))
		
		var btn = Button.new()
		btn.text = "%s\n%d 🪙" % [t_name, cost]
		btn.custom_minimum_size = Vector2(150, 52)
		btn.disabled = current_gold < cost
		
		var b_norm = StyleBoxFlat.new()
		b_norm.bg_color = Color(0.12, 0.16, 0.22, 0.95)
		b_norm.border_width_left = 2
		b_norm.border_width_top = 1
		b_norm.border_width_right = 2
		b_norm.border_width_bottom = 2
		b_norm.border_color = Color(0.70, 0.55, 0.20, 0.8)
		b_norm.set_corner_radius_all(8)
		btn.add_theme_stylebox_override("normal", b_norm)
		
		var b_hov = StyleBoxFlat.new()
		b_hov.bg_color = Color(0.20, 0.28, 0.40, 1.0)
		b_hov.border_width_left = 3
		b_hov.border_width_top = 2
		b_hov.border_width_right = 3
		b_hov.border_width_bottom = 3
		b_hov.border_color = Color(1.0, 0.85, 0.25, 1.0)
		b_hov.set_corner_radius_all(8)
		btn.add_theme_stylebox_override("hover", b_hov)

		btn.pressed.connect(func(): _on_build_tower_clicked(t_type))
		btn.mouse_entered.connect(func(): _on_tower_btn_hover(t_type, true))
		btn.mouse_exited.connect(func(): _on_tower_btn_hover(t_type, false))
		build_buttons_box.add_child(btn)


func _on_tower_btn_hover(tower_type: String, is_hover: bool) -> void:
	if is_hover:
		var game_manager = get_tree().get_first_node_in_group("game_manager") as GameManager
		if game_manager:
			var tdata = game_manager.tower_data.get(tower_type, {})
			var levels = tdata.get("levels", [])
			if not levels.is_empty():
				var l1 = levels[0]
				var desc = str(tdata.get("description", "Защитное сооружение."))
				spot_desc.text = "%s\n[⚔️ Урон: %d | 🎯 Дальность: %d | ⚡ Скор: %.1f/с]" % [
					desc, int(l1.get("damage", 0)), int(l1.get("range", 0)), float(l1.get("attack_speed", 1.0))
				]
	else:
		spot_desc.text = "Выберите защитное сооружение для постройки:"


func _on_build_tower_clicked(tower_type: String) -> void:
	if not is_instance_valid(current_spot):
		return
	# build_tower() handles gold spending internally
	if current_spot.build_tower(tower_type):
		_refresh_action_panel()

func _on_upgrade_clicked() -> void:
	if not is_instance_valid(current_spot) or not current_spot.has_tower():
		return
	# upgrade_tower() handles gold spending internally
	if current_spot.upgrade_tower():
		_refresh_action_panel()


func _on_evo_a_clicked() -> void:
	_open_evolution_preview("a")

func _on_evo_b_clicked() -> void:
	_open_evolution_preview("b")

func _open_evolution_preview(_branch: String) -> void:
	if not is_instance_valid(current_spot) or not current_spot.has_tower():
		return
	var tower = current_spot.current_tower
	if not tower:
		return
		
	if is_instance_valid(evo_preview_modal):
		evo_preview_modal.show_preview(tower)

func _on_evolution_confirmed(branch: String) -> void:
	if not is_instance_valid(current_spot) or not current_spot.has_tower():
		return
	var game_manager = get_tree().get_first_node_in_group("game_manager") as GameManager
	if not game_manager:
		return
		
	var tower = current_spot.current_tower
	var branch_data = tower.get_evolution_info(branch)
	var cost = int(branch_data.get("cost", 100))
	
	if game_manager.spend_gold(cost):
		current_spot.evolve_tower(branch)
		_refresh_action_panel()

func _on_sell_clicked() -> void:
	if not is_instance_valid(current_spot) or not current_spot.has_tower():
		return
	var game_manager = get_tree().get_first_node_in_group("game_manager") as GameManager
	if not game_manager:
		return
		
	var val = current_spot.get_sell_value()
	game_manager.add_gold(val)
	current_spot.sell_tower()
	_refresh_action_panel()

func _on_start_wave_clicked() -> void:
	start_wave_pressed.emit()

func _on_restart_clicked() -> void:
	restart_pressed.emit()

func _on_menu_clicked() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_tech_tree_clicked() -> void:
	if is_instance_valid(tech_tree_modal):
		if not tech_tree_modal.visible:
			tech_tree_modal.open_modal()
		else:
			tech_tree_modal.visible = false
		tech_tree_pressed.emit()

func _on_help_clicked() -> void:
	if is_instance_valid(help_modal):
		help_modal.visible = not help_modal.visible
# ---------------------------------------------------------
# HERO UI INTEGRATION (PHASE 5)
# ---------------------------------------------------------
func setup_hero_ui(hero_class: String) -> void:
	print("Hero UI initialized for: ", hero_class)
	# In a real setup, we would instance a HeroPanel.tscn here and add to HUD.

func update_hero_health(current: float, max_val: float) -> void:
	pass

func update_hero_mana(current: float, max_val: float) -> void:
	pass

func update_hero_xp(level: int, current_xp: int, next_xp: int) -> void:
	pass

func update_hero_ability_cooldown(slot: int, current_cd: float, max_cd: float) -> void:
	pass

# ---------------------------------------------------------
# ECONOMY WIDGET INTEGRATION
# ---------------------------------------------------------
func setup_economy(econ) -> void:
	if is_instance_valid(economy_widget):
		economy_widget.setup(econ)

func show_contracts(contracts: Array[Dictionary]) -> void:
	if is_instance_valid(economy_widget):
		economy_widget.show_contracts(contracts)

func show_wave_breakdown(breakdown: Dictionary) -> void:
	if is_instance_valid(economy_widget):
		economy_widget.show_wave_breakdown(breakdown)

func toggle_tx_log() -> void:
	if is_instance_valid(economy_widget):
		economy_widget.toggle_tx_log()

