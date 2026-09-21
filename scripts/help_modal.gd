class_name HelpModal
extends PanelContainer

signal closed()

@onready var close_btn: Button = $Margin/VBox/CloseButton
@onready var tabs: TabContainer = $Margin/VBox/TabContainer

func _ready() -> void:
	if is_instance_valid(close_btn):
		close_btn.pressed.connect(_on_close_pressed)

func open_modal() -> void:
	visible = true

func _on_close_pressed() -> void:
	visible = false
	closed.emit()
