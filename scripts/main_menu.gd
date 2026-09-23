class_name MainMenu
extends Control

@onready var glory_label: Label = $MarginContainer/VBoxContainer/GloryLabel
@onready var campaign_btn: Button = $MarginContainer/VBoxContainer/Buttons/CampaignButton
@onready var modes_btn: Button = $MarginContainer/VBoxContainer/Buttons/ModesButton
@onready var meta_btn: Button = $MarginContainer/VBoxContainer/Buttons/MetaButton
@onready var bestiary_btn: Button = $MarginContainer/VBoxContainer/Buttons/BestiaryButton
@onready var achievements_btn: Button = $MarginContainer/VBoxContainer/Buttons/AchievementsButton
@onready var reset_btn: Button = $MarginContainer/VBoxContainer/Buttons/ResetButton

@onready var dim_backdrop: ColorRect = $DimBackdrop
@onready var bestiary_modal: PanelContainer = $BestiaryModal
@onready var achievements_modal: PanelContainer = $AchievementsModal
@onready var modes_modal: PanelContainer = $GameModesModal

var meta_manager: MetaManager = null

func _ready() -> void:
	meta_manager = MetaManager.new()
	add_child(meta_manager)
	
	meta_manager.glory_changed.connect(_update_glory_ui)
	_update_glory_ui(meta_manager.glory_points)
	
	if is_instance_valid(campaign_btn):
		campaign_btn.pressed.connect(_on_campaign_pressed)
	if is_instance_valid(modes_btn):
		modes_btn.pressed.connect(_on_modes_pressed)
	if is_instance_valid(meta_btn):
		meta_btn.pressed.connect(_on_meta_pressed)
	if is_instance_valid(bestiary_btn):
		bestiary_btn.pressed.connect(_on_bestiary_pressed)
	if is_instance_valid(achievements_btn):
		achievements_btn.pressed.connect(_on_achievements_pressed)
	if is_instance_valid(reset_btn):
		reset_btn.pressed.connect(_on_reset_pressed)
		
	if is_instance_valid(bestiary_modal):
		bestiary_modal.visible = false
		bestiary_modal.closed.connect(_on_modal_closed)
	if is_instance_valid(achievements_modal):
		achievements_modal.visible = false
		achievements_modal.closed.connect(_on_modal_closed)
	if is_instance_valid(modes_modal):
		modes_modal.visible = false
		modes_modal.closed.connect(_on_modal_closed)
	if is_instance_valid(dim_backdrop):
		dim_backdrop.visible = false

	_style_menu_buttons()

func _style_menu_buttons() -> void:
	var buttons = [campaign_btn, modes_btn, meta_btn, bestiary_btn, achievements_btn]
	for btn in buttons:
		if not is_instance_valid(btn): continue
		var normal_style = StyleBoxFlat.new()
		normal_style.bg_color = Color(0.11, 0.14, 0.19, 0.95)
		normal_style.border_width_left = 2
		normal_style.border_width_top = 1
		normal_style.border_width_right = 2
		normal_style.border_width_bottom = 2
		normal_style.border_color = Color(0.70, 0.55, 0.20, 0.8)
		normal_style.set_corner_radius_all(8)
		normal_style.content_margin_left = 16
		normal_style.content_margin_right = 16
		normal_style.content_margin_top = 8
		normal_style.content_margin_bottom = 8
		btn.add_theme_stylebox_override("normal", normal_style)
		
		var hover_style = StyleBoxFlat.new()
		hover_style.bg_color = Color(0.18, 0.24, 0.34, 1.0)
		hover_style.border_width_left = 3
		hover_style.border_width_top = 2
		hover_style.border_width_right = 3
		hover_style.border_width_bottom = 3
		hover_style.border_color = Color(1.0, 0.82, 0.25, 1.0)
		hover_style.set_corner_radius_all(8)
		hover_style.content_margin_left = 16
		hover_style.content_margin_right = 16
		hover_style.content_margin_top = 8
		hover_style.content_margin_bottom = 8
		hover_style.shadow_color = Color(1.0, 0.82, 0.25, 0.3)
		hover_style.shadow_size = 8
		btn.add_theme_stylebox_override("hover", hover_style)

	var sub = get_node_or_null("MarginContainer/VBoxContainer/Subtitle") as Label
	if is_instance_valid(sub):
		sub.text = "Полная кампания • 12 Биомов • 17 Башен • 8 Героев • 60+ Врагов • 40 Достижений"

func _on_modal_closed() -> void:
	if is_instance_valid(dim_backdrop):
		dim_backdrop.visible = false



func _update_glory_ui(amount: int) -> void:
	if is_instance_valid(glory_label):
		glory_label.text = "🏆 Очки Славы: %d" % amount

func _on_campaign_pressed() -> void:
	GlobalState.game_mode = "campaign"
	get_tree().change_scene_to_file("res://scenes/world_map.tscn")

func _on_modes_pressed() -> void:
	if is_instance_valid(dim_backdrop):
		dim_backdrop.visible = true
	if is_instance_valid(modes_modal):
		modes_modal.visible = true

func _on_meta_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/meta_tree.tscn")

func _on_bestiary_pressed() -> void:
	if is_instance_valid(dim_backdrop):
		dim_backdrop.visible = true
	if is_instance_valid(bestiary_modal):
		bestiary_modal.visible = true

func _on_achievements_pressed() -> void:
	if is_instance_valid(dim_backdrop):
		dim_backdrop.visible = true
	if is_instance_valid(achievements_modal):
		achievements_modal.refresh_ui()
		achievements_modal.visible = true


func _on_reset_pressed() -> void:
	if meta_manager:
		meta_manager.reset_meta()
