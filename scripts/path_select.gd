class_name PathSelect
extends Control

@onready var military_btn: Button = $MarginContainer/VBoxContainer/CardsContainer/MilitaryCard/Margin/VBox/SelectMilitaryBtn
@onready var magic_btn: Button = $MarginContainer/VBoxContainer/CardsContainer/MagicCard/Margin/VBox/SelectMagicBtn
@onready var economy_btn: Button = $MarginContainer/VBoxContainer/CardsContainer/EconomyCard/Margin/VBox/SelectEconomyBtn
@onready var back_btn: Button = $MarginContainer/VBoxContainer/BackButton

func _ready() -> void:
	military_btn.pressed.connect(func(): _choose_path("military"))
	magic_btn.pressed.connect(func(): _choose_path("magic"))
	economy_btn.pressed.connect(func(): _choose_path("economy"))
	back_btn.pressed.connect(_on_back_pressed)

func _choose_path(path_id: String) -> void:
	GlobalState.selected_path = path_id
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
