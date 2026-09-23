class_name BestiaryModal
extends PanelContainer

## Модальное окно бестиария (Этап 9)
## Отображает всех 20 врагов, статы, описание, уязвимости и счетчик убийств

signal closed()

@onready var enemy_list: VBoxContainer = $MarginContainer/HBoxContainer/LeftColumn/ScrollContainer/EnemyList
@onready var name_label: Label = $MarginContainer/HBoxContainer/RightColumn/VBoxContainer/NameLabel
@onready var desc_label: Label = $MarginContainer/HBoxContainer/RightColumn/VBoxContainer/DescLabel
@onready var stats_label: Label = $MarginContainer/HBoxContainer/RightColumn/VBoxContainer/StatsLabel
@onready var weaknesses_label: Label = $MarginContainer/HBoxContainer/RightColumn/VBoxContainer/WeaknessesLabel
@onready var kills_label: Label = $MarginContainer/HBoxContainer/RightColumn/VBoxContainer/KillsLabel
@onready var close_btn: Button = $MarginContainer/HBoxContainer/RightColumn/VBoxContainer/CloseButton

var enemies_db: Dictionary = {}
var selected_enemy_id: String = "grunt"

func _ready() -> void:
	# Solid dark opaque theme with golden border
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

	_load_enemies()
	if is_instance_valid(close_btn):
		var close_style = StyleBoxFlat.new()
		close_style.bg_color = Color(0.65, 0.18, 0.18, 0.95)
		close_style.set_corner_radius_all(6)
		close_btn.add_theme_stylebox_override("normal", close_style)
		var close_hover = StyleBoxFlat.new()
		close_hover.bg_color = Color(0.85, 0.22, 0.22, 1.0)
		close_hover.set_corner_radius_all(6)
		close_btn.add_theme_stylebox_override("hover", close_hover)
		close_btn.text = "✖ Закрыть окно"
		close_btn.pressed.connect(func():
			visible = false
			closed.emit()
		)
	_populate_list()
	_show_enemy(selected_enemy_id)



func _load_enemies() -> void:
	if not FileAccess.file_exists("res://data/enemies.json"):
		return
	var f = FileAccess.open("res://data/enemies.json", FileAccess.READ)
	var json = JSON.new()
	if json.parse(f.get_as_text()) == OK and json.data is Dictionary:
		enemies_db = json.data.duplicate(true)

func _populate_list() -> void:
	if not is_instance_valid(enemy_list):
		return
		
	for c in enemy_list.get_children():
		c.queue_free()
		
	for e_id in enemies_db:
		var edata = enemies_db[e_id]
		var btn = Button.new()
		var icon = "👹"
		if edata.get("is_boss", false):
			icon = "👑"
		elif edata.get("is_flyer", false):
			icon = "🦇"
		elif edata.get("is_stealth", false) or edata.get("is_invisible", false):
			icon = "👻"
			
		btn.text = "%s %s" % [icon, edata.get("name", e_id)]
		btn.custom_minimum_size = Vector2(230, 40)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		var btn_normal = StyleBoxFlat.new()
		btn_normal.bg_color = Color(0.12, 0.15, 0.21, 0.95)
		btn_normal.set_corner_radius_all(6)
		btn_normal.content_margin_left = 12
		btn_normal.content_margin_right = 12
		btn.add_theme_stylebox_override("normal", btn_normal)
		
		var btn_hover = StyleBoxFlat.new()
		btn_hover.bg_color = Color(0.22, 0.28, 0.38, 1.0)
		btn_hover.border_width_left = 3
		btn_hover.border_color = Color(0.90, 0.75, 0.25, 1.0)
		btn_hover.set_corner_radius_all(6)
		btn_hover.content_margin_left = 12
		btn_hover.content_margin_right = 12
		btn.add_theme_stylebox_override("hover", btn_hover)
		
		btn.pressed.connect(func(): _show_enemy(e_id))
		enemy_list.add_child(btn)


func _show_enemy(e_id: String) -> void:
	selected_enemy_id = e_id
	if not enemies_db.has(e_id):
		return
	var edata = enemies_db[e_id]
	
	if is_instance_valid(name_label):
		var prefix = "👑 [БОСС] " if edata.get("is_boss", false) else ""
		name_label.text = "%s%s" % [prefix, edata.get("name", e_id)]
	if is_instance_valid(desc_label):
		desc_label.text = edata.get("description", "Информация уточняется...")
		
	if is_instance_valid(stats_label):
		stats_label.text = "❤️ Здоровье: %d   ⚡ Скорость: %d   🛡️ Броня: %d   🪙 Награда: %d" % [
			int(edata.get("max_health", 100)),
			int(edata.get("speed", 80)),
			int(edata.get("armor", 0)),
			int(edata.get("gold_reward", 10))
		]
		
	if is_instance_valid(weaknesses_label):
		var traits = []
		if edata.get("is_flyer", false): traits.append("🦅 Летающий (игнорирует ловушки и преграды)")
		if edata.get("is_stealth", false) or edata.get("is_invisible", false): traits.append("👻 Невидимый (требует вышки обзора)")
		if edata.get("split_on_death", false): traits.append("🦠 Разделяется на мелких при гибели")
		if edata.get("heal_aura", 0.0) > 0: traits.append("💖 Аура лечения союзников")
		if edata.get("reflect_ratio", 0.0) > 0: traits.append("🪞 Зеркало: отражает снаряды")
		
		var res_dict = edata.get("resistances", {})
		for r_type in res_dict:
			traits.append("🛡️ Сопротивление: %s (%d%%)" % [r_type, int(res_dict[r_type] * 100)])
			
		var imm_arr = edata.get("immunities", [])
		for imm in imm_arr:
			traits.append("⛔ Иммунитет: %s" % imm)
			
		if traits.is_empty():
			weaknesses_label.text = "Особенности: Стандартный пехотинец"
		else:
			weaknesses_label.text = "Особенности и уязвимости:\n • " + "\n • ".join(traits)

	if is_instance_valid(kills_label):
		kills_label.text = "⚔️ Статус: Зафиксирован в реестре королевства"
