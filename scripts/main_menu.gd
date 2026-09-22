class_name MainMenu
extends Control

@onready var glory_label: Label = $MarginContainer/VBoxContainer/GloryLabel
@onready var campaign_btn: Button = $MarginContainer/VBoxContainer/Buttons/CampaignButton
@onready var modes_btn: Button = $MarginContainer/VBoxContainer/Buttons/ModesButton
@onready var meta_btn: Button = $MarginContainer/VBoxContainer/Buttons/MetaButton
@onready var bestiary_btn: Button = $MarginContainer/VBoxContainer/Buttons/BestiaryButton
@onready var achievements_btn: Button = $MarginContainer/VBoxContainer/Buttons/AchievementsButton
@onready var reset_btn: Button = $MarginContainer/VBoxContainer/Buttons/ResetButton

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
	if is_instance_valid(achievements_modal):
		achievements_modal.visible = false
	if is_instance_valid(modes_modal):
		modes_modal.visible = false

func _update_glory_ui(amount: int) -> void:
	if is_instance_valid(glory_label):
		glory_label.text = "🏆 Очки Славы: %d" % amount

func _on_campaign_pressed() -> void:
	GlobalState.game_mode = "campaign"
	get_tree().change_scene_to_file("res://scenes/world_map.tscn")

func _on_modes_pressed() -> void:
	if is_instance_valid(modes_modal):
		modes_modal.visible = true

func _on_meta_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/meta_tree.tscn")

func _on_bestiary_pressed() -> void:
	if is_instance_valid(bestiary_modal):
		bestiary_modal.visible = true

func _on_achievements_pressed() -> void:
	if is_instance_valid(achievements_modal):
		achievements_modal.refresh_ui()
		achievements_modal.visible = true

func _on_reset_pressed() -> void:
	if meta_manager:
		meta_manager.reset_meta()
