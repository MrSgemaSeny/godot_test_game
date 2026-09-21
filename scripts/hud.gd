class_name GameHUD
extends Control

signal start_wave_pressed()
signal restart_pressed()
signal tech_tree_pressed()
signal speed_changed(multiplier: float)

@onready var gold_label: Label = $TopBar/MarginContainer/HBoxContainer/GoldLabel
@onready var mana_label: Label = $TopBar/MarginContainer/HBoxContainer/ManaLabel
@onready var girls_label: Label = $TopBar/MarginContainer/HBoxContainer/GirlsLabel
@onready var wave_label: Label = $TopBar/MarginContainer/HBoxContainer/WaveLabel
@onready var timer_label: Label = $TopBar/MarginContainer/HBoxContainer/TimerLabel
@onready var tech_btn: Button = $TopBar/MarginContainer/HBoxContainer/TechTreeButton
@onready var start_wave_btn: Button = $TopBar/MarginContainer/HBoxContainer/StartWaveButton
@onready var help_btn: Button = $TopBar/MarginContainer/HBoxContainer/HelpButton
@onready var wave_clock: WaveClock = $TopBar/MarginContainer/HBoxContainer/WaveClock

# Управление скоростью
@onready var pause_btn: Button = $TopBar/MarginContainer/HBoxContainer/SpeedBox/PauseBtn
@onready var speed1_btn: Button = $TopBar/MarginContainer/HBoxContainer/SpeedBox/Speed1Btn
@onready var speed2_btn: Button = $TopBar/MarginContainer/HBoxContainer/SpeedBox/Speed2Btn

# Панель заклинаний (Spell Bar)
@onready var spell_meteor_btn: Button = $SpellBar/Margin/HBox/MeteorBtn
@onready var spell_freeze_btn: Button = $SpellBar/Margin/HBox/FreezeBtn
@onready var spell_gold_btn: Button = $SpellBar/Margin/HBox/GoldRainBtn
@onready var spell_lightning_btn: Button = $SpellBar/Margin/HBox/LightningBtn

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

# Экран окончания
@onready var end_screen: PanelContainer = $EndScreen
@onready var end_title: Label = $EndScreen/VBoxContainer/EndTitle
@onready var end_subtitle: Label = $EndScreen/VBoxContainer/EndSubtitle
@onready var restart_btn: Button = $EndScreen/VBoxContainer/RestartButton
@onready var menu_btn: Button = $EndScreen/VBoxContainer/MenuButton

var current_spot: BuildSpot = null
var wave_countdown: float = 0.0
var counting_down: bool = false
var current_speed: float = 1.0
var hovered_tower_type: String = ""

func _ready() -> void:
	if is_instance_valid(action_panel):
		action_panel.visible = false
	if is_instance_valid(end_screen):
		end_screen.visible = false
	if is_instance_valid(tech_tree_modal):
		tech_tree_modal.visible = false
	if is_instance_valid(help_modal):
		help_modal.visible = false
	
	if is_instance_valid(start_wave_btn):
		start_wave_btn.pressed.connect(_on_start_wave_clicked)
	if is_instance_valid(wave_clock):
		wave_clock.clicked.connect(_on_start_wave_clicked)
	if is_instance_valid(tech_btn):
		tech_btn.pressed.connect(_on_tech_tree_clicked)
	if is_instance_valid(help_btn):
		help_btn.pressed.connect(_on_help_clicked)
	if is_instance_valid(upgrade_btn):
		upgrade_btn.pressed.connect(_on_upgrade_clicked)
	if is_instance_valid(sell_btn):
		sell_btn.pressed.connect(_on_sell_clicked)
	if is_instance_valid(restart_btn):
		restart_btn.pressed.connect(_on_restart_clicked)
	if is_instance_valid(menu_btn):
		menu_btn.pressed.connect(_on_menu_clicked)
		
	if is_instance_valid(pause_btn):
		pause_btn.pressed.connect(func(): set_game_speed(0.0))
	if is_instance_valid(speed1_btn):
		speed1_btn.pressed.connect(func(): set_game_speed(1.0))
	if is_instance_valid(speed2_btn):
		speed2_btn.pressed.connect(func(): set_game_speed(2.0))
		
	# Привязка кнопок заклинаний
	if is_instance_valid(spell_meteor_btn):
		spell_meteor_btn.pressed.connect(func(): _cast_player_spell("meteor"))
		spell_meteor_btn.tooltip_text = "☄️ [1] Метеор (40 маны)\nНаносит 350 урона по площади в месте клика."
	if is_instance_valid(spell_freeze_btn):
		spell_freeze_btn.pressed.connect(func(): _cast_player_spell("freeze"))
		spell_freeze_btn.tooltip_text = "❄️ [2] Заморозка (30 маны)\nОстанавливает всех монстров на карте на 5 секунд."
	if is_instance_valid(spell_gold_btn):
		spell_gold_btn.pressed.connect(func(): _cast_player_spell("gold_rain"))
		spell_gold_btn.tooltip_text = "💰 [3] Золотой дождь (50 маны)\nМгновенно приносит +120 золота в казну."
	if is_instance_valid(spell_lightning_btn):
		spell_lightning_btn.pressed.connect(func(): _cast_player_spell("lightning"))
		spell_lightning_btn.tooltip_text = "⚡ [4] Молния (25 маны)\nБьет ближайшего к курсору врага на 220 урона."

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
		"lightning": spell_lightning_btn
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
	return "✨"

func _cast_player_spell(spell_id: String) -> void:
	var spell_sys = get_tree().get_first_node_in_group("spell_system") as SpellSystem
	if not spell_sys:
		return
		
	var mouse_pos = get_viewport().get_mouse_position()
	spell_sys.cast_spell(spell_id, mouse_pos)

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

func update_research_points(amount: int) -> void:
	if is_instance_valid(tech_btn):
		tech_btn.text = "📜 Древо (%d)" % amount
		tech_btn.modulate = Color(1.2, 1.1, 0.3) if amount > 0 else Color(1, 1, 1)

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
		if is_instance_valid(spot_title):
			spot_title.text = "🏗️ Свободная площадка под башню"
		if is_instance_valid(spot_desc):
			spot_desc.text = "Выберите защитное сооружение для отражения набега:"
		build_buttons_box.visible = true
		tower_action_box.visible = false
		
		for child in build_buttons_box.get_children():
			child.queue_free()
			
		var default_towers = ["archer", "ice_mage", "siege_cannon", "bastion"]
		if game_manager:
			default_towers = game_manager.get_available_towers()
			
		for tower_id in default_towers:
			if not game_manager or not game_manager.tower_data.has(tower_id):
				continue
			var tdata = game_manager.tower_data[tower_id]
			var tname = tdata.get("name", tower_id)
			var cost = current_spot.get_tower_cost(tower_id)
			var icon = _get_tower_icon(tower_id)
			
			var btn = Button.new()
			btn.custom_minimum_size = Vector2(130, 48)
			btn.text = "%s %s\n%d 🪙" % [icon, tname, cost]
			btn.disabled = current_gold < cost
			btn.pressed.connect(func(): _on_build_clicked(tower_id))
			
			# Тултип с подробным описанием характеристик
			btn.tooltip_text = "%s %s (%d🪙)\n%s" % [icon, tname, cost, tdata.get("description", "")]
			build_buttons_box.add_child(btn)
	else:
		var tower = current_spot.current_tower
		var icon = _get_tower_icon(tower.tower_type)
		spot_title.text = "%s %s (Уровень %d)" % [icon, tower.tower_name, tower.current_level]
		
		var d_info = "⚔️ Урон: %.0f  |  ⚡ Скор.: %.1f/с  |  🎯 Радиус: %.0f" % [tower.get_effective_damage(), tower.get_effective_attack_speed(), tower.get_effective_range()]
		if tower.slow_factor > 0.0:
			d_info += "  |  ❄️ Замедление: %.0f%%" % (tower.slow_factor * 100.0)
		spot_desc.text = d_info
		
		build_buttons_box.visible = false
		tower_action_box.visible = true
		
		if tower.can_upgrade():
			var tech = get_tree().get_first_node_in_group("tech_tree_manager") as TechTreeManager
			var mult = 1.0 - (tech.get_cost_discount() if tech else 0.0)
			var cost = max(10, int(tower.upgrade_cost * mult))
			upgrade_btn.text = "⬆️ Улучшить (+Урон) — %dg" % cost
			upgrade_btn.disabled = current_gold < cost
			upgrade_btn.visible = true
		else:
			upgrade_btn.text = "⭐ Максимальный уровень"
			upgrade_btn.disabled = true
			upgrade_btn.visible = true
			
		sell_btn.text = "💰 Продать (+%dg)" % tower.get_sell_value()

func _get_tower_icon(t_type: String) -> String:
	match t_type:
		"archer": return "🏹"
		"ice_mage": return "❄️"
		"siege_cannon": return "💣"
		"bastion": return "🛡️"
		"sling": return "🪨"
	return "🏰"

func show_game_over(won: bool) -> void:
	if not is_instance_valid(end_screen):
		return
	end_screen.visible = true
	if won:
		end_title.text = "👑 ПОБЕДА! ДЕВОЧКИ СПАСЕНЫ!"
		end_title.modulate = Color(0.2, 0.95, 0.3)
		end_subtitle.text = "Все монстры разбиты! Сказочная долина в безопасности!\n🏆 +50 Очков Славы!"
		var meta = get_tree().get_first_node_in_group("meta_manager") as MetaManager
		if meta:
			meta.add_glory(50)
	else:
		end_title.text = "💀 ПОРАЖЕНИЕ! ДЕВОЧКИ ПОХИЩЕНЫ!"
		end_title.modulate = Color(0.95, 0.2, 0.2)
		end_subtitle.text = "Монстры утащили всех девочек в своё темное логово..."

func _on_start_wave_clicked() -> void:
	start_wave_pressed.emit()

func _on_tech_tree_clicked() -> void:
	if is_instance_valid(tech_tree_modal):
		tech_tree_modal.open_modal()
	tech_tree_pressed.emit()

func _on_help_clicked() -> void:
	if is_instance_valid(help_modal):
		help_modal.open_modal()

func _on_build_clicked(type: String) -> void:
	if is_instance_valid(current_spot):
		if current_spot.build_tower(type):
			_refresh_action_panel()

func _on_upgrade_clicked() -> void:
	if is_instance_valid(current_spot):
		if current_spot.upgrade_tower():
			_refresh_action_panel()

func _on_sell_clicked() -> void:
	if is_instance_valid(current_spot):
		current_spot.sell_tower()
		_refresh_action_panel()

func _on_restart_clicked() -> void:
	restart_pressed.emit()

func _on_menu_clicked() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
