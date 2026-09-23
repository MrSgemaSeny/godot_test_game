class_name WorldMap
extends Control

## Карта мира кампании (Этап 5)
## Управляет выбором локаций, биомами, условиями разблокировки, звездами и UI выбора карт

signal map_selected(map_id: String)

const MAP_CONFIGS: Dictionary = {
	"valley": {
		"name": "Кудрявая Долина",
		"biome": "plains",
		"icon": "🌾",
		"theme_color": Color(0.35, 0.75, 0.3),
		"description": "Изумрудные луга королевства. Один четкий маршрут. Идеально для начала обороны.",
		"unlock_req": {"type": "default"},
		"modifiers": ["Базовые правила"],
		"path_branches": 1,
		"max_waves": 10,
		"bonus_condition": "Не использовать заклинания"
	},
	"swamp": {
		"name": "Грибные Топи",
		"biome": "swamp",
		"icon": "🍄",
		"theme_color": Color(0.45, 0.65, 0.25),
		"description": "Болотный ядовитый воздух замедляет механизмы (-15% скор. атаки). Враги идут по 3 тропам.",
		"unlock_req": {"type": "stars", "map": "valley", "count": 2},
		"modifiers": ["☣️ Ядовитый воздух: -15% скор. атаки башен", "🔀 3 маршрута"],
		"path_branches": 3,
		"max_waves": 15,
		"bonus_condition": "Не потерять ни одной жизни"
	},
	"caves": {
		"name": "Хрустальные Пещеры",
		"biome": "crystal_cave",
		"icon": "💎",
		"theme_color": Color(0.3, 0.6, 0.85),
		"description": "Глубокие подземные туннели. Вечная темнота снижает обзор башен на -40%.",
		"unlock_req": {"type": "completed_maps", "count": 2},
		"modifiers": ["🌑 Глубокая тьма: -40% радиус обзора башен", "🔀 2 маршрута"],
		"path_branches": 2,
		"max_waves": 15,
		"bonus_condition": "Не строить башни огня"
	},
	"frost_peak": {
		"name": "Морозный Пик",
		"biome": "frost",
		"icon": "❄️",
		"theme_color": Color(0.65, 0.85, 1.0),
		"description": "Ледяные тропы ускоряют врагов (+20% скор.). Земля промёрзла — ловушки отключены.",
		"unlock_req": {"type": "both_maps", "maps": ["swamp", "caves"]},
		"modifiers": ["⚡ Скользкий лед: +20% скор. монстров", "🚫 Ловушки отключены"],
		"path_branches": 2,
		"max_waves": 20,
		"bonus_condition": "Пройти только магическими башнями"
	},
	"besieged_citadel": {
		"name": "Осаждённый Город",
		"biome": "citadel",
		"icon": "🏰",
		"theme_color": Color(0.9, 0.45, 0.3),
		"description": "Финальная битва за столицу королевства. Враги атакуют с 4 фронтов одновременно!",
		"unlock_req": {"type": "map_completed", "map": "frost_peak"},
		"modifiers": ["🛡️ Осада столицы", "🔀 4 фронта атаки", "👑 25 волн с мега-боссами"],
		"path_branches": 4,
		"max_waves": 25,
		"bonus_condition": "Спасти всех девочек во всех волнах"
	}
}

var current_selected_map: String = "valley"
var meta_manager: MetaManager = null

# UI references (когда скрипт загружен как сцена)
@onready var map_buttons_container: VBoxContainer = get_node_or_null("MarginContainer/HBoxContainer/LeftPanel/ScrollContainer/MapList")
@onready var title_label: Label = get_node_or_null("MarginContainer/HBoxContainer/RightPanel/VBox/TitleLabel")
@onready var desc_label: Label = get_node_or_null("MarginContainer/HBoxContainer/RightPanel/VBox/DescLabel")
@onready var modifiers_label: Label = get_node_or_null("MarginContainer/HBoxContainer/RightPanel/VBox/ModifiersLabel")
@onready var bonus_label: Label = get_node_or_null("MarginContainer/HBoxContainer/RightPanel/VBox/BonusLabel")
@onready var stars_label: Label = get_node_or_null("MarginContainer/HBoxContainer/RightPanel/VBox/StarsLabel")
@onready var start_battle_btn: Button = get_node_or_null("MarginContainer/HBoxContainer/RightPanel/VBox/StartBattleButton")
@onready var back_btn: Button = get_node_or_null("MarginContainer/HBoxContainer/RightPanel/VBox/BackButton")
@onready var total_stars_label: Label = get_node_or_null("MarginContainer/HBoxContainer/LeftPanel/TotalStarsLabel")

func _ready() -> void:
	meta_manager = MetaManager.new()
	add_child(meta_manager)
	
	_style_panels()
	
	if is_instance_valid(start_battle_btn):
		start_battle_btn.pressed.connect(_on_start_battle_pressed)
	if is_instance_valid(back_btn):
		back_btn.pressed.connect(_on_back_pressed)
		
	if is_instance_valid(map_buttons_container):
		_populate_map_buttons()
		_update_map_details(current_selected_map)

func _style_panels() -> void:
	var right_p = get_node_or_null("MarginContainer/HBoxContainer/RightPanel") as PanelContainer
	if is_instance_valid(right_p):
		var r_style = StyleBoxFlat.new()
		r_style.bg_color = Color(0.09, 0.11, 0.16, 0.98)
		r_style.border_width_left = 2
		r_style.border_width_top = 2
		r_style.border_width_right = 2
		r_style.border_width_bottom = 2
		r_style.border_color = Color(0.85, 0.68, 0.22, 1.0)
		r_style.set_corner_radius_all(12)
		r_style.shadow_color = Color(0, 0, 0, 0.85)
		r_style.shadow_size = 24
		r_style.content_margin_left = 28
		r_style.content_margin_right = 28
		r_style.content_margin_top = 24
		r_style.content_margin_bottom = 24
		right_p.add_theme_stylebox_override("panel", r_style)
		
	if is_instance_valid(start_battle_btn):
		var sb_style = StyleBoxFlat.new()
		sb_style.bg_color = Color(0.75, 0.55, 0.12, 1.0)
		sb_style.border_width_left = 2
		sb_style.border_width_top = 2
		sb_style.border_width_right = 2
		sb_style.border_width_bottom = 2
		sb_style.border_color = Color(1.0, 0.9, 0.4, 1.0)
		sb_style.set_corner_radius_all(8)
		sb_style.content_margin_top = 12
		sb_style.content_margin_bottom = 12
		start_battle_btn.add_theme_stylebox_override("normal", sb_style)
		
		var sb_hover = StyleBoxFlat.new()
		sb_hover.bg_color = Color(0.95, 0.72, 0.18, 1.0)
		sb_hover.border_width_left = 3
		sb_hover.border_width_top = 3
		sb_hover.border_width_right = 3
		sb_hover.border_width_bottom = 3
		sb_hover.border_color = Color(1, 1, 1, 1.0)
		sb_hover.set_corner_radius_all(8)
		sb_hover.content_margin_top = 12
		sb_hover.content_margin_bottom = 12
		sb_hover.shadow_color = Color(1.0, 0.8, 0.2, 0.4)
		sb_hover.shadow_size = 14
		start_battle_btn.add_theme_stylebox_override("hover", sb_hover)
		
	if is_instance_valid(back_btn):
		var bb_style = StyleBoxFlat.new()
		bb_style.bg_color = Color(0.12, 0.15, 0.20, 0.95)
		bb_style.border_width_left = 1
		bb_style.border_width_top = 1
		bb_style.border_width_right = 1
		bb_style.border_width_bottom = 1
		bb_style.border_color = Color(0.4, 0.5, 0.6)
		bb_style.set_corner_radius_all(6)
		back_btn.add_theme_stylebox_override("normal", bb_style)


func is_map_unlocked(map_id: String, meta: MetaManager = null) -> bool:
	if not MAP_CONFIGS.has(map_id):
		return false
	var conf = MAP_CONFIGS[map_id]
	var req = conf.get("unlock_req", {})
	var r_type = req.get("type", "default")
	
	if r_type == "default":
		return true
	if meta == null:
		meta = meta_manager
	if meta == null:
		return r_type == "default"
		
	match r_type:
		"stars":
			var target_map = req.get("map", "")
			var required_stars = int(req.get("count", 1))
			return meta.get_map_stars(target_map) >= required_stars
		"completed_maps":
			var required_count = int(req.get("count", 1))
			var comp = 0
			for m in MAP_CONFIGS:
				if meta.get_map_stars(m) >= 1:
					comp += 1
			return comp >= required_count
		"both_maps":
			var required_maps = req.get("maps", [])
			for rm in required_maps:
				if meta.get_map_stars(rm) < 1:
					return false
			return true
		"map_completed":
			var target_map = req.get("map", "")
			return meta.get_map_stars(target_map) >= 1
			
	return false

func select_map(map_id: String, meta: MetaManager = null) -> bool:
	if not is_map_unlocked(map_id, meta):
		return false
	current_selected_map = map_id
	map_selected.emit(map_id)
	if is_instance_valid(title_label):
		_update_map_details(map_id)
	return true

func get_map_stars_and_status(map_id: String, meta: MetaManager = null) -> Dictionary:
	var unlocked = is_map_unlocked(map_id, meta)
	var stars = meta.get_map_stars(map_id) if meta != null else (meta_manager.get_map_stars(map_id) if meta_manager != null else 0)
	var conf = MAP_CONFIGS.get(map_id, {})
	return {
		"map_id": map_id,
		"name": conf.get("name", ""),
		"biome": conf.get("biome", ""),
		"unlocked": unlocked,
		"stars": stars,
		"max_waves": conf.get("max_waves", 10),
		"modifiers": conf.get("modifiers", [])
	}

func _populate_map_buttons() -> void:
	if not is_instance_valid(map_buttons_container):
		return
		
	for child in map_buttons_container.get_children():
		child.queue_free()
		
	var sum_stars = 0
	for m_id in ["valley", "swamp", "caves", "frost_peak", "besieged_citadel"]:
		var conf = MAP_CONFIGS[m_id]
		var unlocked = is_map_unlocked(m_id, meta_manager)
		var stars = meta_manager.get_map_stars(m_id) if meta_manager != null else 0
		sum_stars += stars
		
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(300, 60)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		var star_str = ""
		for s in range(3):
			star_str += "⭐" if s < stars else "☆"
			
		var btn_style = StyleBoxFlat.new()
		btn_style.bg_color = Color(0.12, 0.15, 0.22, 0.95) if unlocked else Color(0.08, 0.09, 0.11, 0.8)
		btn_style.border_width_left = 4 if unlocked else 1
		btn_style.border_color = conf.theme_color if unlocked else Color(0.3, 0.3, 0.3)
		btn_style.set_corner_radius_all(8)
		btn_style.content_margin_left = 14
		btn_style.content_margin_right = 14
		btn_style.content_margin_top = 8
		btn_style.content_margin_bottom = 8
		btn.add_theme_stylebox_override("normal", btn_style)
		
		var hover_style = StyleBoxFlat.new()
		hover_style.bg_color = Color(0.20, 0.26, 0.36, 1.0)
		hover_style.border_width_left = 5
		hover_style.border_color = Color(1.0, 0.85, 0.3)
		hover_style.set_corner_radius_all(8)
		hover_style.content_margin_left = 14
		hover_style.content_margin_right = 14
		hover_style.content_margin_top = 8
		hover_style.content_margin_bottom = 8
		btn.add_theme_stylebox_override("hover", hover_style)

		if unlocked:
			btn.text = " %s %s\n  %s | Волн: %d" % [conf.icon, conf.name, star_str, conf.max_waves]
			btn.add_theme_color_override("font_color", Color(1, 1, 1))
			btn.pressed.connect(func(): select_map(m_id))
		else:
			btn.text = " 🔒 %s %s\n  [Заблокировано]" % [conf.icon, conf.name]
			btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			btn.disabled = true
			
		map_buttons_container.add_child(btn)

		
	if is_instance_valid(total_stars_label):
		total_stars_label.text = "⭐ Всего звезд кампании: %d / 15" % sum_stars

func _update_map_details(map_id: String) -> void:
	var conf = MAP_CONFIGS.get(map_id, {})
	var stars = meta_manager.get_map_stars(map_id) if meta_manager != null else 0
	
	if is_instance_valid(title_label):
		title_label.text = "%s %s" % [conf.get("icon", "📍"), conf.get("name", "")]
	if is_instance_valid(desc_label):
		desc_label.text = conf.get("description", "")
	if is_instance_valid(modifiers_label):
		var mods = conf.get("modifiers", [])
		var mod_text = "Особенности биома:\n"
		for m in mods:
			mod_text += " • %s\n" % str(m)
		modifiers_label.text = mod_text
	if is_instance_valid(bonus_label):
		bonus_label.text = "🎯 Задание на 3-ю звезду:\n • %s" % conf.get("bonus_condition", "Выжить")
	if is_instance_valid(stars_label):
		var s_text = "Звёзды локации: "
		for s in range(3):
			s_text += "⭐" if s < stars else "☆"
		stars_label.text = s_text
		
	if is_instance_valid(start_battle_btn):
		start_battle_btn.disabled = not is_map_unlocked(map_id, meta_manager)

func _on_start_battle_pressed() -> void:
	GlobalState.selected_map = current_selected_map
	get_tree().change_scene_to_file("res://scenes/path_select.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
