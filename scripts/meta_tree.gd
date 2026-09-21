class_name MetaTreeUI
extends Control

@onready var glory_label: Label = $MarginContainer/VBoxContainer/Header/GloryLabel
@onready var cards_container: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/CardsList
@onready var back_btn: Button = $MarginContainer/VBoxContainer/BackButton

var meta_manager: MetaManager = null

func _ready() -> void:
	meta_manager = MetaManager.new()
	add_child(meta_manager)
	
	meta_manager.glory_changed.connect(_on_glory_changed)
	meta_manager.meta_upgraded.connect(_on_meta_upgraded)
	
	back_btn.pressed.connect(_on_back_pressed)
	
	_render_cards()
	_update_glory_label(meta_manager.glory_points)

func _update_glory_label(amount: int) -> void:
	glory_label.text = "🏆 Доступно Очков Славы: %d" % amount

func _on_glory_changed(amount: int) -> void:
	_update_glory_label(amount)
	_render_cards()

func _on_meta_upgraded(_id: String, _lvl: int) -> void:
	_render_cards()

func _render_cards() -> void:
	for child in cards_container.get_children():
		child.queue_free()
		
	for item in meta_manager.meta_tree_data:
		var item_id = item.get("id", "")
		var item_name = item.get("name", "")
		var item_desc = item.get("description", "")
		var max_lvl = item.get("max_level", 1)
		var cur_lvl = meta_manager.get_level(item_id)
		var cost_base = item.get("cost_per_level", 10)
		var cost = cost_base * (cur_lvl + 1)
		
		var panel = PanelContainer.new()
		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 16)
		margin.add_theme_constant_override("margin_right", 16)
		margin.add_theme_constant_override("margin_top", 12)
		margin.add_theme_constant_override("margin_bottom", 12)
		
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 16)
		
		var vbox = VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var title_lbl = Label.new()
		title_lbl.text = "%s (Уровень %d / %d)" % [item_name, cur_lvl, max_lvl]
		title_lbl.add_theme_font_size_override("font_size", 16)
		title_lbl.modulate = Color(1.0, 0.85, 0.2) if cur_lvl > 0 else Color(1.0, 1.0, 1.0)
		
		var desc_lbl = Label.new()
		desc_lbl.text = item_desc
		desc_lbl.add_theme_font_size_override("font_size", 13)
		desc_lbl.modulate = Color(0.75, 0.75, 0.75)
		
		vbox.add_child(title_lbl)
		vbox.add_child(desc_lbl)
		
		var buy_btn = Button.new()
		buy_btn.custom_minimum_size = Vector2(160, 40)
		if cur_lvl >= max_lvl:
			buy_btn.text = "⭐ Максимум"
			buy_btn.disabled = true
		else:
			buy_btn.text = "Купить (%d 🏆)" % cost
			buy_btn.disabled = meta_manager.glory_points < cost
			buy_btn.pressed.connect(func(): meta_manager.buy_upgrade(item_id))
			
		hbox.add_child(vbox)
		hbox.add_child(buy_btn)
		margin.add_child(hbox)
		panel.add_child(margin)
		cards_container.add_child(panel)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
