class_name GameHUD
extends Control

signal start_wave_pressed()
signal restart_pressed()
signal tech_tree_pressed()

@onready var gold_label: Label = $TopBar/MarginContainer/HBoxContainer/GoldLabel
@onready var mana_label: Label = $TopBar/MarginContainer/HBoxContainer/ManaLabel
@onready var girls_label: Label = $TopBar/MarginContainer/HBoxContainer/GirlsLabel
@onready var wave_label: Label = $TopBar/MarginContainer/HBoxContainer/WaveLabel
@onready var timer_label: Label = $TopBar/MarginContainer/HBoxContainer/TimerLabel
@onready var tech_btn: Button = $TopBar/MarginContainer/HBoxContainer/TechTreeButton
@onready var start_wave_btn: Button = $TopBar/MarginContainer/HBoxContainer/StartWaveButton

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

# Окно дерева исследований
@onready var tech_tree_modal: TechTreeModal = $TechTreeModal

# Экран окончания
@onready var end_screen: PanelContainer = $EndScreen
@onready var end_title: Label = $EndScreen/VBoxContainer/EndTitle
@onready var end_subtitle: Label = $EndScreen/VBoxContainer/EndSubtitle
@onready var restart_btn: Button = $EndScreen/VBoxContainer/RestartButton
@onready var menu_btn: Button = $EndScreen/VBoxContainer/MenuButton

var current_spot: BuildSpot = null
var wave_countdown: float = 0.0
var counting_down: bool = false
var spell_targeting_mode: String = ""

func _ready() -> void:
	action_panel.visible = false
	end_screen.visible = false
	if tech_tree_modal:
		tech_tree_modal.visible = false
	
	start_wave_btn.pressed.connect(_on_start_wave_clicked)
	tech_btn.pressed.connect(_on_tech_tree_clicked)
	upgrade_btn.pressed.connect(_on_upgrade_clicked)
	sell_btn.pressed.connect(_on_sell_clicked)
	restart_btn.pressed.connect(_on_restart_clicked)
	if menu_btn:
		menu_btn.pressed.connect(_on_menu_clicked)
		
	# Привязка кнопок заклинаний
	spell_meteor_btn.pressed.connect(func(): _cast_player_spell("meteor"))
	spell_freeze_btn.pressed.connect(func(): _cast_player_spell("freeze"))
	spell_gold_btn.pressed.connect(func(): _cast_player_spell("gold_rain"))
	spell_lightning_btn.pressed.connect(func(): _cast_player_spell("lightning"))

func _process(delta: float) -> void:
	if counting_down:
		wave_countdown -= delta
		if wave_countdown > 0.0:
			timer_label.text = "⏱️ %ds (+10%%)" % int(ceil(wave_countdown))
		else:
			counting_down = false
			timer_label.text = "⚔️ Битва идет!"

func _cast_player_spell(spell_id: String) -> void:
	var spell_sys = get_tree().get_first_node_in_group("spell_system") as SpellSystem
	if not spell_sys:
		return
		
	var mouse_pos = get_viewport().get_mouse_position()
	spell_sys.cast_spell(spell_id, mouse_pos)

func set_countdown(seconds: float) -> void:
	wave_countdown = seconds
	counting_down = true

func stop_countdown() -> void:
	counting_down = false
	timer_label.text = "⚔️ Защищайте девочек!"

func update_gold(amount: int) -> void:
	gold_label.text = "🪙 %d" % amount
	_refresh_action_panel()

func update_mana(cur: int, max_m: int) -> void:
	mana_label.text = "🧪 %d/%d" % [cur, max_m]
	var spell_sys = get_tree().get_first_node_in_group("spell_system") as SpellSystem
	if spell_sys:
		spell_meteor_btn.disabled = not spell_sys.can_cast("meteor")
		spell_freeze_btn.disabled = not spell_sys.can_cast("freeze")
		spell_gold_btn.disabled = not spell_sys.can_cast("gold_rain")
		spell_lightning_btn.disabled = not spell_sys.can_cast("lightning")

func update_girls_count(girls_left: int) -> void:
	girls_label.text = "👧 %d" % girls_left

func update_wave(current: int, total: int) -> void:
	wave_label.text = "🌊 %d/%d" % [current, total]

func update_research_points(amount: int) -> void:
	tech_btn.text = "📜 Древо (%d)" % amount

func set_wave_button_enabled(enabled: bool) -> void:
	start_wave_btn.disabled = not enabled

func show_spot_panel(spot: BuildSpot) -> void:
	current_spot = spot
	if not spot:
		action_panel.visible = false
		return
		
	action_panel.visible = true
	_refresh_action_panel()

func _refresh_action_panel() -> void:
	if not is_instance_valid(current_spot):
		action_panel.visible = false
		return
		
	var game_manager = get_tree().get_first_node_in_group("game_manager") as GameManager
	var current_gold = game_manager.gold if game_manager else 0
	
	if not current_spot.has_tower():
		spot_title.text = "Площадка под башню"
		spot_desc.text = "Выберите защитное орудие для постройки:"
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
			
			var btn = Button.new()
			btn.custom_minimum_size = Vector2(110, 40)
			btn.text = "%s (%dg)" % [tname, cost]
			btn.disabled = current_gold < cost
			btn.pressed.connect(func(): _on_build_clicked(tower_id))
			build_buttons_box.add_child(btn)
	else:
		var tower = current_spot.current_tower
		spot_title.text = "%s (Ур. %d)" % [tower.tower_name, tower.current_level]
		
		var d_info = "Урон: %.0f | Скор.: %.1f/с | Радиус: %.0f" % [tower.get_effective_damage(), tower.get_effective_attack_speed(), tower.get_effective_range()]
		if tower.slow_factor > 0.0:
			d_info += "\nЗамедление: %.0f%% на %.1fc" % [tower.slow_factor * 100.0, tower.slow_duration]
		spot_desc.text = d_info
		
		build_buttons_box.visible = false
		tower_action_box.visible = true
		
		if tower.can_upgrade():
			var tech = get_tree().get_first_node_in_group("tech_tree_manager") as TechTreeManager
			var mult = 1.0 - (tech.get_cost_discount() if tech else 0.0)
			var cost = max(10, int(tower.upgrade_cost * mult))
			upgrade_btn.text = "⬆️ Улучшить (%dg)" % cost
			upgrade_btn.disabled = current_gold < cost
			upgrade_btn.visible = true
		else:
			upgrade_btn.text = "⭐ Макс. уровень"
			upgrade_btn.disabled = true
			upgrade_btn.visible = true
			
		sell_btn.text = "💰 Продать (+%dg)" % tower.get_sell_value()

func show_game_over(won: bool) -> void:
	end_screen.visible = true
	if won:
		end_title.text = "👑 ПОБЕДА! ДЕВОЧКИ СПАСЕНЫ!"
		end_title.modulate = Color(0.2, 0.95, 0.3)
		end_subtitle.text = "Все монстры разбиты! Сказочная долина в безопасности!\n+50 Очков Славы!"
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
	if tech_tree_modal:
		tech_tree_modal.open_modal()
	tech_tree_pressed.emit()

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
