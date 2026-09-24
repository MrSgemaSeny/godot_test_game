class_name GameModesModal
extends PanelContainer

## Модальное окно выбора режимов игры (Этап 8)
## Предоставляет выбор: Кошмар, Бесконечный режим, 20 Испытаний

signal closed()

@onready var nightmare_btn: Button = $MarginContainer/VBoxContainer/ModesContainer/NightmareCard/Margin/VBox/StartNightmareBtn
@onready var endless_btn: Button = $MarginContainer/VBoxContainer/ModesContainer/EndlessCard/Margin/VBox/StartEndlessBtn
@onready var challenges_list: VBoxContainer = $MarginContainer/VBoxContainer/ChallengesSection/ScrollContainer/ChallengesList
@onready var close_btn: Button = $MarginContainer/VBoxContainer/BottomRow/CloseButton

func _ready() -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.14, 1.0)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.85, 0.68, 0.22, 1.0)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.shadow_color = Color(0, 0, 0, 0.9)
	style.shadow_size = 24
	add_theme_stylebox_override("panel", style)

	if is_instance_valid(close_btn):
		close_btn.pressed.connect(func():
			visible = false
			closed.emit()
		)
	if is_instance_valid(nightmare_btn):
		nightmare_btn.pressed.connect(_on_nightmare_selected)
	if is_instance_valid(endless_btn):
		endless_btn.pressed.connect(_on_endless_selected)
		
	_setup_extra_mode_cards()
	_populate_challenges()


func _setup_extra_mode_cards() -> void:
	var container = get_node_or_null("MarginContainer/VBoxContainer/ModesContainer") as HBoxContainer
	if not is_instance_valid(container):
		return
		
	var br_card = _create_mode_card(
		"👹 Босс-Раш",
		Color(1.0, 0.4, 0.4),
		"10 свирепых боссов подряд! Награды за рубежи 3, 6, 9 боссов.",
		"👹 В бой с боссами",
		_on_boss_rush_selected
	)
	container.add_child(br_card)
	
	var ng_card = _create_mode_card(
		"👑 Новая Игра+",
		Color(1.0, 0.85, 0.3),
		"Усиленные враги, перенос башен и реликвий, новые модификаторы.",
		"👑 Начать NG+",
		_on_ng_plus_selected
	)
	container.add_child(ng_card)

func _create_mode_card(title_text: String, title_col: Color, desc_text: String, btn_text: String, on_press: Callable) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)
	
	var title = Label.new()
	title.text = title_text
	title.add_theme_color_override("font_color", title_col)
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)
	
	var desc = Label.new()
	desc.text = desc_text
	desc.add_theme_font_size_override("font_size", 13)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc)
	
	var btn = Button.new()
	btn.text = btn_text
	btn.custom_minimum_size = Vector2(0, 36)
	btn.pressed.connect(on_press)
	vbox.add_child(btn)
	
	return panel

func _populate_challenges() -> void:
	if not is_instance_valid(challenges_list):
		return
	for c in challenges_list.get_children():
		c.queue_free()
		
	var weekly_btn = Button.new()
	weekly_btn.custom_minimum_size = Vector2(0, 36)
	weekly_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	weekly_btn.text = "📅 ЕЖЕНЕДЕЛЬНОЕ ИСПЫТАНИЕ: Уникальные модификаторы недели и удвоенная Слава"
	weekly_btn.pressed.connect(func():
		GlobalState.game_mode = "weekly"
		GlobalState.selected_challenge = ""
		visible = false
		get_tree().change_scene_to_file("res://scenes/path_select.tscn")
	)
	challenges_list.add_child(weekly_btn)
	
	var draft_btn = Button.new()
	draft_btn.custom_minimum_size = Vector2(0, 36)
	draft_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	draft_btn.text = "🃏 ДРАФТ-РЕЖИМ: Случайный пул из 3 башен, без магазина"
	draft_btn.pressed.connect(func():
		GlobalState.game_mode = "draft"
		GlobalState.selected_challenge = ""
		visible = false
		get_tree().change_scene_to_file("res://scenes/path_select.tscn")
	)
	challenges_list.add_child(draft_btn)
		
	for ch_id in ChallengeManager.CHALLENGES_DB:
		var ch = ChallengeManager.CHALLENGES_DB[ch_id]
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(0, 36)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.text = "🎯 %s: %s" % [ch.get("name", ch_id), ch.get("description", "")]
		btn.pressed.connect(func(): _on_challenge_selected(ch_id))
		challenges_list.add_child(btn)

func _on_nightmare_selected() -> void:
	GlobalState.game_mode = "nightmare"
	GlobalState.selected_challenge = ""
	visible = false
	get_tree().change_scene_to_file("res://scenes/path_select.tscn")

func _on_endless_selected() -> void:
	GlobalState.game_mode = "endless"
	GlobalState.selected_challenge = ""
	visible = false
	get_tree().change_scene_to_file("res://scenes/path_select.tscn")

func _on_boss_rush_selected() -> void:
	GlobalState.game_mode = "boss_rush"
	GlobalState.selected_challenge = ""
	visible = false
	get_tree().change_scene_to_file("res://scenes/path_select.tscn")

func _on_ng_plus_selected() -> void:
	GlobalState.game_mode = "ng_plus"
	GlobalState.selected_challenge = ""
	visible = false
	get_tree().change_scene_to_file("res://scenes/path_select.tscn")

func _on_challenge_selected(ch_id: String) -> void:
	GlobalState.game_mode = "challenge"
	GlobalState.selected_challenge = ch_id
	visible = false
	get_tree().change_scene_to_file("res://scenes/path_select.tscn")
