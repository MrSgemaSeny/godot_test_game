class_name MainMenu
extends Control

@onready var glory_label: Label = $MarginContainer/VBoxContainer/GloryLabel
@onready var play_btn: Button = $MarginContainer/VBoxContainer/Buttons/PlayButton
@onready var meta_btn: Button = $MarginContainer/VBoxContainer/Buttons/MetaButton
@onready var reset_btn: Button = $MarginContainer/VBoxContainer/Buttons/ResetButton

var meta_manager: MetaManager = null

func _ready() -> void:
	meta_manager = MetaManager.new()
	add_child(meta_manager)
	
	meta_manager.glory_changed.connect(_update_glory_ui)
	_update_glory_ui(meta_manager.glory_points)
	
	play_btn.pressed.connect(_on_play_pressed)
	meta_btn.pressed.connect(_on_meta_pressed)
	reset_btn.pressed.connect(_on_reset_pressed)

func _update_glory_ui(amount: int) -> void:
	glory_label.text = "🏆 Очки Славы: %d" % amount

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/path_select.tscn")

func _on_meta_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/meta_tree.tscn")

func _on_reset_pressed() -> void:
	if meta_manager:
		meta_manager.reset_meta()
