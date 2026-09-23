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
		
	_populate_challenges()


func _populate_challenges() -> void:
	if not is_instance_valid(challenges_list):
		return
	for c in challenges_list.get_children():
		c.queue_free()
		
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

func _on_challenge_selected(ch_id: String) -> void:
	GlobalState.game_mode = "challenge"
	GlobalState.selected_challenge = ch_id
	visible = false
	get_tree().change_scene_to_file("res://scenes/path_select.tscn")
