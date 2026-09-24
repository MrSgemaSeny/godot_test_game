class_name SettingsModal
extends PanelContainer

## Модальное окно настроек и доступности (Фаза 10)
## Управляет громкостью, тряской экрана, цифрами урона и языком

signal closed()
signal settings_changed(settings: Dictionary)

var current_settings = {
	"sfx_volume": 1.0,
	"music_volume": 0.8,
	"screen_shake": true,
	"damage_numbers": true,
	"high_contrast": false,
	"language": "ru"
}

func _ready() -> void:
	_style_panel()
	_build_ui()

func _style_panel() -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.14, 0.98)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.85, 0.68, 0.22, 1.0)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(0, 0, 0, 0.9)
	style.shadow_size = 24
	add_theme_stylebox_override("panel", style)

func _build_ui() -> void:
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)
	
	var title = Label.new()
	title.text = "⚙️ НАСТРОЙКИ И ДОСТУПНОСТЬ"
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title)
	
	# SFX Slider
	vbox.add_child(_create_slider_row("🔊 Эффекты (SFX):", current_settings["sfx_volume"], func(val):
		current_settings["sfx_volume"] = val
		settings_changed.emit(current_settings)
	))
	
	# Music Slider
	vbox.add_child(_create_slider_row("🎵 Музыка:", current_settings["music_volume"], func(val):
		current_settings["music_volume"] = val
		settings_changed.emit(current_settings)
	))
	
	# Checkboxes
	vbox.add_child(_create_check_row("💥 Тряска экрана при взрывах", current_settings["screen_shake"], func(active):
		current_settings["screen_shake"] = active
		settings_changed.emit(current_settings)
	))
	
	vbox.add_child(_create_check_row("🔢 Всплывающие цифры урона", current_settings["damage_numbers"], func(active):
		current_settings["damage_numbers"] = active
		settings_changed.emit(current_settings)
	))
	
	vbox.add_child(_create_check_row("👁️ Режим высокой контрастности", current_settings["high_contrast"], func(active):
		current_settings["high_contrast"] = active
		settings_changed.emit(current_settings)
	))
	
	# Close button
	var btn_close = Button.new()
	btn_close.text = "Готово"
	btn_close.custom_minimum_size = Vector2(160, 36)
	btn_close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_close.pressed.connect(func():
		visible = false
		closed.emit()
	)
	vbox.add_child(btn_close)

func _create_slider_row(label_text: String, initial_val: float, on_change: Callable) -> HBoxContainer:
	var row = HBoxContainer.new()
	var lbl = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(180, 0)
	row.add_child(lbl)
	
	var slider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = initial_val
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(on_change)
	row.add_child(slider)
	return row

func _create_check_row(label_text: String, initial_val: bool, on_change: Callable) -> CheckBox:
	var chk = CheckBox.new()
	chk.text = label_text
	chk.button_pressed = initial_val
	chk.toggled.connect(on_change)
	return chk
