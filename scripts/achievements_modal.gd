class_name AchievementsModal
extends PanelContainer

## Модальное окно достижений (Этап 9)
## Отображает 40 достижений, статус выполнения и награды в очках Славы

signal closed()

@onready var achievements_list: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/AchievementsList
@onready var progress_label: Label = $MarginContainer/VBoxContainer/TopRow/ProgressLabel
@onready var close_btn: Button = $MarginContainer/VBoxContainer/BottomRow/CloseButton

var achievement_system: AchievementSystem = null

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
	if achievement_system == null:
		achievement_system = AchievementSystem.new()
		add_child(achievement_system)
	refresh_ui()


func refresh_ui() -> void:
	if not is_instance_valid(achievements_list) or not is_instance_valid(achievement_system):
		return
		
	for c in achievements_list.get_children():
		c.queue_free()
		
	var unlocked_count = achievement_system.get_unlocked_count()
	var total_count = achievement_system.get_total_count()
	if is_instance_valid(progress_label):
		progress_label.text = "🏆 Открыто: %d / %d" % [unlocked_count, total_count]
		
	for ach_id in achievement_system.achievements_db:
		var data = achievement_system.achievements_db[ach_id]
		var is_unlocked = achievement_system.is_unlocked(ach_id)
		
		var p = PanelContainer.new()
		var m = MarginContainer.new()
		m.add_theme_constant_override("margin_left", 12)
		m.add_theme_constant_override("margin_top", 8)
		m.add_theme_constant_override("margin_right", 12)
		m.add_theme_constant_override("margin_bottom", 8)
		p.add_child(m)
		
		var h = HBoxContainer.new()
		m.add_child(h)
		
		var icon_lbl = Label.new()
		icon_lbl.text = "🏆" if is_unlocked else "🔒"
		icon_lbl.add_theme_font_size_override("font_size", 20)
		h.add_child(icon_lbl)
		
		var v = VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		
		var name_lbl = Label.new()
		name_lbl.text = str(data.get("name", ach_id))
		name_lbl.add_theme_font_size_override("font_size", 16)
		name_lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.3) if is_unlocked else Color(0.7, 0.7, 0.7))
		v.add_child(name_lbl)
		
		var desc_lbl = Label.new()
		desc_lbl.text = str(data.get("description", ""))
		desc_lbl.add_theme_font_size_override("font_size", 13)
		desc_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		v.add_child(desc_lbl)
		
		var reward_lbl = Label.new()
		reward_lbl.text = "+%d 🏆 Славы" % int(data.get("reward_glory", 10))
		reward_lbl.add_theme_font_size_override("font_size", 14)
		reward_lbl.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4) if is_unlocked else Color(0.5, 0.5, 0.5))
		h.add_child(reward_lbl)
		
		achievements_list.add_child(p)
