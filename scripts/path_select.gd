class_name PathSelect
extends Control

@onready var military_btn: Button = $MarginContainer/VBoxContainer/CardsContainer/MilitaryCard/Margin/VBox/SelectMilitaryBtn
@onready var magic_btn: Button = $MarginContainer/VBoxContainer/CardsContainer/MagicCard/Margin/VBox/SelectMagicBtn
@onready var economy_btn: Button = $MarginContainer/VBoxContainer/CardsContainer/EconomyCard/Margin/VBox/SelectEconomyBtn
@onready var back_btn: Button = $MarginContainer/VBoxContainer/BackButton

func _ready() -> void:
	_style_cards()
	military_btn.pressed.connect(func(): _choose_path("military"))
	magic_btn.pressed.connect(func(): _choose_path("magic"))
	economy_btn.pressed.connect(func(): _choose_path("economy"))
	back_btn.pressed.connect(_on_back_pressed)

func _style_cards() -> void:
	var mil_card = get_node_or_null("MarginContainer/VBoxContainer/CardsContainer/MilitaryCard") as PanelContainer
	var mag_card = get_node_or_null("MarginContainer/VBoxContainer/CardsContainer/MagicCard") as PanelContainer
	var eco_card = get_node_or_null("MarginContainer/VBoxContainer/CardsContainer/EconomyCard") as PanelContainer
	
	_apply_card_theme(mil_card, military_btn, Color(0.86, 0.15, 0.15), "⚔️ Выбрать Путь Стали")
	_apply_card_theme(mag_card, magic_btn, Color(0.55, 0.36, 0.96), "🔮 Выбрать Путь Магии")
	_apply_card_theme(eco_card, economy_btn, Color(0.92, 0.70, 0.05), "🪙 Выбрать Путь Золота")
	
	if is_instance_valid(back_btn):
		var b_style = StyleBoxFlat.new()
		b_style.bg_color = Color(0.12, 0.15, 0.20, 0.95)
		b_style.border_width_left = 1
		b_style.border_width_top = 1
		b_style.border_width_right = 1
		b_style.border_width_bottom = 1
		b_style.border_color = Color(0.4, 0.5, 0.6)
		b_style.set_corner_radius_all(6)
		b_style.content_margin_left = 16
		b_style.content_margin_right = 16
		b_style.content_margin_top = 8
		b_style.content_margin_bottom = 8
		back_btn.add_theme_stylebox_override("normal", b_style)

func _apply_card_theme(card: PanelContainer, btn: Button, border_col: Color, btn_text: String) -> void:
	if not is_instance_valid(card): return
	var c_style = StyleBoxFlat.new()
	c_style.bg_color = Color(0.09, 0.11, 0.15, 0.98)
	c_style.border_width_left = 2
	c_style.border_width_top = 2
	c_style.border_width_right = 2
	c_style.border_width_bottom = 2
	c_style.border_color = border_col
	c_style.set_corner_radius_all(12)
	c_style.shadow_color = Color(border_col.r, border_col.g, border_col.b, 0.35)
	c_style.shadow_size = 18
	card.add_theme_stylebox_override("panel", c_style)
	
	if is_instance_valid(btn):
		btn.text = btn_text
		var btn_normal = StyleBoxFlat.new()
		btn_normal.bg_color = Color(border_col.r * 0.4, border_col.g * 0.4, border_col.b * 0.4, 0.9)
		btn_normal.border_width_left = 2
		btn_normal.border_width_top = 1
		btn_normal.border_width_right = 2
		btn_normal.border_width_bottom = 2
		btn_normal.border_color = border_col
		btn_normal.set_corner_radius_all(8)
		btn_normal.content_margin_top = 10
		btn_normal.content_margin_bottom = 10
		btn.add_theme_stylebox_override("normal", btn_normal)
		
		var btn_hover = StyleBoxFlat.new()
		btn_hover.bg_color = Color(border_col.r * 0.7, border_col.g * 0.7, border_col.b * 0.7, 1.0)
		btn_hover.border_width_left = 2
		btn_hover.border_width_top = 2
		btn_hover.border_width_right = 2
		btn_hover.border_width_bottom = 2
		btn_hover.border_color = Color(1, 1, 1)
		btn_hover.set_corner_radius_all(8)
		btn_hover.content_margin_top = 10
		btn_hover.content_margin_bottom = 10
		btn.add_theme_stylebox_override("hover", btn_hover)


func _choose_path(path_id: String) -> void:
	GlobalState.selected_path = path_id
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
