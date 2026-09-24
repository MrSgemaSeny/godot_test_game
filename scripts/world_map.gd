class_name WorldMap
extends Control

## Карта мира кампании (Этап 5)
## Управляет выбором локаций, биомами, условиями разблокировки, звездами и UI выбора карт

signal map_selected(map_id: String)

const MAP_CONFIGS: Dictionary = {
	"valley": {
		"name": "Кудрявая Долина",
		"chapter_num": 1,
		"chapter_title": "Глава 1: Изумрудная Долина",
		"biome": "plains",
		"icon": "🌾",
		"theme_color": Color(0.35, 0.75, 0.3),
		"description": "Изумрудные луга королевства. Уровень башен ограничен 3-м уровнем. 10 каток обороны.",
		"unlock_req": {"type": "default"},
		"modifiers": ["Базовые правила", "🔒 Макс. ур. башен: 3"],
		"path_branches": 1,
		"max_waves": 10,
		"bonus_condition": "Не использовать заклинания",
		"stages": [
			{"stage": 1, "name": "Дозорная застава", "waves": 5, "desc": "Первая линия обороны королевства."},
			{"stage": 2, "name": "Опушка леса", "waves": 6, "desc": "Орки прощупывают фланги через лесную чащу."},
			{"stage": 3, "name": "Мельничный ручей", "waves": 7, "desc": "Быстрые налетчики атакуют мельницу."},
			{"stage": 4, "name": "Перекресток караванов", "waves": 8, "desc": "Узел снабжения королевской армии."},
			{"stage": 5, "name": "Забытый курган", "waves": 8, "desc": "Шаманы поднимают древнюю нежить."},
			{"stage": 6, "name": "Каменные ворота", "waves": 9, "desc": "Узкое ущелье, идеальное для засады."},
			{"stage": 7, "name": "Пшеничные холмы", "waves": 9, "desc": "Волны берсерков на открытом пространстве."},
			{"stage": 8, "name": "Речная переправа", "waves": 10, "desc": "Враг форсирует реку с двух направлений."},
			{"stage": 9, "name": "Осадный лагерь", "waves": 10, "desc": "Штурмовой авангард армии орков."},
			{"stage": 10, "name": "Логово Вожака (Босс)", "waves": 10, "desc": "Финальная битва против Вождя Граш'нака!"}
		]
	},
	"swamp": {
		"name": "Грибные Топи",
		"chapter_num": 2,
		"chapter_title": "Глава 2: Грибные Топи",
		"biome": "swamp",
		"icon": "🍄",
		"theme_color": Color(0.45, 0.65, 0.25),
		"description": "Болотный ядовитый воздух замедляет механизмы (-15% скор. атаки). Открыт 4-й уровень башен! 10 каток.",
		"unlock_req": {"type": "stars", "map": "valley", "count": 2},
		"modifiers": ["☣️ Ядовитый воздух: -15% скор. атаки", "🔀 3 маршрута", "🔓 Доступен 4-й уровень башен"],
		"path_branches": 3,
		"max_waves": 15,
		"bonus_condition": "Не потерять ни одной жизни",
		"stages": [
			{"stage": 1, "name": "Гнилые топи", "waves": 8, "desc": "Ядовитые испарения и топкая почва."},
			{"stage": 2, "name": "Зыбучие мхи", "waves": 9, "desc": "Замедление механизмов башен."},
			{"stage": 3, "name": "Обитель пиявок", "waves": 9, "desc": "Полчища регенерирующих тварей."},
			{"stage": 4, "name": "Старая гать", "waves": 10, "desc": "Враги идут тремя извилистыми тропами."},
			{"stage": 5, "name": "Остров спор", "waves": 10, "desc": "Грибные мутанты распадаются на части при гибели."},
			{"stage": 6, "name": "Туманный брод", "waves": 11, "desc": "Невидимые лазутчики крадутся в тумане."},
			{"stage": 7, "name": "Чёрный ил", "waves": 12, "desc": "Тяжелая броня болотных троллей."},
			{"stage": 8, "name": "Трясина духов", "waves": 12, "desc": "Эфирные призраки игнорируют физический урон."},
			{"stage": 9, "name": "Алтарь чумы", "waves": 13, "desc": "Шаманы скверны готовят жертвоприношение."},
			{"stage": 10, "name": "Сердце Болот (Босс)", "waves": 15, "desc": "Чудовищная Болотная Матка!"}
		]
	},
	"caves": {
		"name": "Хрустальные Пещеры",
		"chapter_num": 3,
		"chapter_title": "Глава 3: Хрустальные Пещеры",
		"biome": "crystal_cave",
		"icon": "💎",
		"theme_color": Color(0.3, 0.6, 0.85),
		"description": "Глубокие подземные туннели. Открыта ЭВОЛЮЦИЯ (5-й уровень башен с выбором из 2 веток)! 12 каток.",
		"unlock_req": {"type": "completed_maps", "count": 2},
		"modifiers": ["🌑 Глубокая тьма: -40% обзор", "🔀 2 маршрута", "👑 Открыта Эволюция (Ур. 5: Выбор из 2)"],
		"path_branches": 2,
		"max_waves": 15,
		"bonus_condition": "Не строить башни огня",
		"stages": [
			{"stage": 1, "name": "Вход в грот", "waves": 8, "desc": "Тьма подземелий скрывает приближение врага."},
			{"stage": 2, "name": "Эхо глубин", "waves": 9, "desc": "Подземные толчки и летающие нетопыри."},
			{"stage": 3, "name": "Сапфировая жила", "waves": 10, "desc": "Кристаллы отражают свет и усиливают магию."},
			{"stage": 4, "name": "Обвал штольни", "waves": 10, "desc": "Узкий карниз над лавовым озером."},
			{"stage": 5, "name": "Подземный водопад", "waves": 11, "desc": "Водяные элементали и каменные големы."},
			{"stage": 6, "name": "Кристальный мост", "waves": 11, "desc": "Пространство ограничено, две тропы сходятся."},
			{"stage": 7, "name": "Базальтовый разлом", "waves": 12, "desc": "Огненные бесы атакуют с флангов."},
			{"stage": 8, "name": "Залы сталагмитов", "waves": 12, "desc": "Лабиринт колонн и укрытий."},
			{"stage": 9, "name": "Бездна тьмы", "waves": 13, "desc": "Невидимые тени и скрытные убийцы."},
			{"stage": 10, "name": "Серное логово", "waves": 13, "desc": "Взрывоопасные ползуны и токсичные газы."},
			{"stage": 11, "name": "Палата кристаллов", "waves": 14, "desc": "Элитные стражи древних глубин."},
			{"stage": 12, "name": "Глубинный Ужас (Босс)", "waves": 15, "desc": "Исполинский Кристальный Голем пробудился!"}
		]
	},
	"frost_peak": {
		"name": "Морозный Пик",
		"chapter_num": 4,
		"chapter_title": "Глава 4: Морозный Пик",
		"biome": "frost",
		"icon": "❄️",
		"theme_color": Color(0.65, 0.85, 1.0),
		"description": "Ледяные тропы ускоряют врагов (+20% скор.). Полный арсенал 5 уровней башен. 12 каток.",
		"unlock_req": {"type": "both_maps", "maps": ["swamp", "caves"]},
		"modifiers": ["⚡ Скользкий лед: +20% скор. монстров", "🚫 Ловушки отключены", "👑 Доступны все 5 уровней"],
		"path_branches": 2,
		"max_waves": 20,
		"bonus_condition": "Пройти только магическими башнями",
		"stages": [
			{"stage": 1, "name": "Снежное подножие", "waves": 10, "desc": "Ледяной ветер и ускоренные монстры."},
			{"stage": 2, "name": "Ледяной перевал", "waves": 10, "desc": "Скользкая корка льда удваивает скорость врагов."},
			{"stage": 3, "name": "Замёрзшее озеро", "waves": 11, "desc": "Открытое ледяное плато без укрытий."},
			{"stage": 4, "name": "Ледниковая трещина", "waves": 12, "desc": "Снежные великаны с ледяной броней."},
			{"stage": 5, "name": "Ветреный хребет", "waves": 12, "desc": "Порывы бурана снижают дальность башен."},
			{"stage": 6, "name": "Забытая часовня", "waves": 13, "desc": "Оскверненное горное святилище."},
			{"stage": 7, "name": "Буранная тропа", "waves": 14, "desc": "Шторм скрывает летающих гарпий."},
			{"stage": 8, "name": "Обвал карниза", "waves": 14, "desc": "Опасный узкий карниз над пропастью."},
			{"stage": 9, "name": "Снежный бастион", "waves": 15, "desc": "Штурм древней пограничной крепости."},
			{"stage": 10, "name": "Морозный грот", "waves": 16, "desc": "Ледяные элементали с иммунитетом к холоду."},
			{"stage": 11, "name": "Ледяной пик", "waves": 18, "desc": "Преддверие цитадели вечной зимы."},
			{"stage": 12, "name": "Владыка Льда (Босс)", "waves": 20, "desc": "Древний Морозный Дракон Имир!"}
		]
	},
	"besieged_citadel": {
		"name": "Осаждённый Город",
		"chapter_num": 5,
		"chapter_title": "Глава 5: Осаждённая Цитадель",
		"biome": "citadel",
		"icon": "🏰",
		"theme_color": Color(0.9, 0.45, 0.3),
		"description": "Финальная битва за столицу королевства. 15 грандиозных каток с атаками с 4 фронтов!",
		"unlock_req": {"type": "map_completed", "map": "frost_peak"},
		"modifiers": ["🛡️ Осада столицы", "🔀 4 фронта атаки", "👑 15 каток до мега-босса"],
		"path_branches": 4,
		"max_waves": 25,
		"bonus_condition": "Спасти всех девочек во всех волнах",
		"stages": [
			{"stage": 1, "name": "Внешний ров", "waves": 12, "desc": "Первая линия укреплений осаждённой столицы."},
			{"stage": 2, "name": "Разрушенный мост", "waves": 12, "desc": "Осаждающие наводят штурмовые мостки."},
			{"stage": 3, "name": "Предместья столицы", "waves": 13, "desc": "Бои в пылающих домах ремесленников."},
			{"stage": 4, "name": "Баррикады торговых рядов", "waves": 14, "desc": "Враг рвется к складам зерна."},
			{"stage": 5, "name": "Западный барбакан", "waves": 14, "desc": "Осадные башни и катапульты противника."},
			{"stage": 6, "name": "Площадь фонтанов", "waves": 15, "desc": "Атака с четырех улиц одновременно."},
			{"stage": 7, "name": "Прорыв южных ворот", "waves": 16, "desc": "Таран пробивает железные створки ворот."},
			{"stage": 8, "name": "Верхний город", "waves": 17, "desc": "Рыцари и маги держат оборону квартала."},
			{"stage": 9, "name": "Бастион стражи", "waves": 18, "desc": "Элитная королевская гвардия вступает в бой."},
			{"stage": 10, "name": "Арсенал столицы", "waves": 18, "desc": "Защита пороховых складов от диверсантов."},
			{"stage": 11, "name": "Мост триумфа", "waves": 20, "desc": "Узкий парадный мост к замку короля."},
			{"stage": 12, "name": "Внутренние сады", "waves": 20, "desc": "Битва на террасах королевского дворца."},
			{"stage": 13, "name": "Тронная площадь", "waves": 22, "desc": "Орда демонов и орков окружает тронный зал."},
			{"stage": 14, "name": "Последний рубеж", "waves": 23, "desc": "Оборона королевской семьи и реликвий."},
			{"stage": 15, "name": "Финальный Штурм (Мега-Босс)", "waves": 25, "desc": "Верховный Повелитель Скверны и его полчища!"}
		]
	}
}

var current_selected_map: String = "valley"
var current_selected_stage: int = 1
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
		
	_populate_stages_ui(map_id)

func _populate_stages_ui(map_id: String) -> void:
	var vbox = get_node_or_null("MarginContainer/HBoxContainer/RightPanel/VBox")
	if not is_instance_valid(vbox):
		return
		
	var stages_panel = vbox.get_node_or_null("StagesPanel") as PanelContainer
	if not is_instance_valid(stages_panel):
		stages_panel = PanelContainer.new()
		stages_panel.name = "StagesPanel"
		var s_style = StyleBoxFlat.new()
		s_style.bg_color = Color(0.06, 0.08, 0.12, 0.85)
		s_style.border_width_left = 1
		s_style.border_width_top = 1
		s_style.border_width_right = 1
		s_style.border_width_bottom = 1
		s_style.border_color = Color(0.3, 0.4, 0.5, 0.6)
		s_style.set_corner_radius_all(8)
		s_style.content_margin_left = 12
		s_style.content_margin_right = 12
		s_style.content_margin_top = 10
		s_style.content_margin_bottom = 10
		stages_panel.add_theme_stylebox_override("panel", s_style)
		
		var inner_vbox = VBoxContainer.new()
		inner_vbox.name = "InnerVBox"
		inner_vbox.add_theme_constant_override("separation", 8)
		stages_panel.add_child(inner_vbox)
		
		var stages_hdr = Label.new()
		stages_hdr.name = "StagesHeader"
		stages_hdr.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
		stages_hdr.add_theme_font_size_override("font_size", 16)
		inner_vbox.add_child(stages_hdr)
		
		var scroll = ScrollContainer.new()
		scroll.name = "StagesScroll"
		scroll.custom_minimum_size = Vector2(0, 140)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		inner_vbox.add_child(scroll)
		
		var flow = HFlowContainer.new()
		flow.name = "StagesFlow"
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 8)
		flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(flow)
		
		var spacer = vbox.get_node_or_null("Spacer")
		if is_instance_valid(spacer):
			vbox.add_child(stages_panel)
			vbox.move_child(stages_panel, spacer.get_index())
		else:
			vbox.add_child(stages_panel)

	var inner_vbox = stages_panel.get_node("InnerVBox")
	var stages_hdr = inner_vbox.get_node("StagesHeader") as Label
	var flow = inner_vbox.get_node("StagesScroll/StagesFlow") as HFlowContainer
	
	for child in flow.get_children():
		child.queue_free()
		
	var conf = MAP_CONFIGS.get(map_id, {})
	var stages = conf.get("stages", [])
	var unlocked_stage = meta_manager.get_unlocked_stage(map_id, stages.size()) if meta_manager != null else 1
	var map_unlocked = is_map_unlocked(map_id, meta_manager)
	
	current_selected_stage = clamp(current_selected_stage, 1, max(1, stages.size()))
	if current_selected_stage > unlocked_stage:
		current_selected_stage = unlocked_stage
		
	var completed_count = 0
	for st in stages:
		var s_idx = int(st.get("stage", 1))
		var s_stars = meta_manager.get_stage_stars(map_id, s_idx) if meta_manager != null else 0
		if s_stars > 0:
			completed_count += 1
			
	stages_hdr.text = "🎮 Катки главы: %s (Пройдено: %d / %d)" % [conf.get("chapter_title", conf.get("name", "")), completed_count, stages.size()]
	
	for st in stages:
		var s_idx = int(st.get("stage", 1))
		var s_name = str(st.get("name", "Катка %d" % s_idx))
		var s_waves = int(st.get("waves", 10))
		var s_stars = meta_manager.get_stage_stars(map_id, s_idx) if meta_manager != null else 0
		var is_stage_unlocked = map_unlocked and (s_idx <= unlocked_stage)
		var is_selected = (s_idx == current_selected_stage)
		
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(105, 48)
		
		var b_style = StyleBoxFlat.new()
		b_style.set_corner_radius_all(6)
		if is_selected:
			b_style.bg_color = Color(0.25, 0.45, 0.75, 1.0)
			b_style.border_width_left = 2
			b_style.border_width_top = 2
			b_style.border_width_right = 2
			b_style.border_width_bottom = 2
			b_style.border_color = Color(1.0, 0.88, 0.3)
		elif is_stage_unlocked:
			b_style.bg_color = Color(0.12, 0.16, 0.24, 0.95)
			b_style.border_width_left = 1
			b_style.border_width_top = 1
			b_style.border_width_right = 1
			b_style.border_width_bottom = 1
			b_style.border_color = Color(0.4, 0.5, 0.65, 0.7)
		else:
			b_style.bg_color = Color(0.08, 0.09, 0.11, 0.7)
			b_style.border_width_left = 1
			b_style.border_color = Color(0.2, 0.2, 0.2)
		btn.add_theme_stylebox_override("normal", b_style)
		
		var star_icons = ""
		for s in range(3):
			star_icons += "★" if s < s_stars else "☆"
			
		if is_stage_unlocked:
			btn.text = "⚔️ #%d\n%s" % [s_idx, star_icons]
			btn.tooltip_text = "%s\nВолн: %d\n%s" % [s_name, s_waves, st.get("desc", "")]
			btn.pressed.connect(func():
				current_selected_stage = s_idx
				_populate_stages_ui(map_id)
				_update_battle_button(map_id)
			)
		else:
			btn.text = "🔒 #%d\n[Закрыто]" % s_idx
			btn.disabled = true
			
		flow.add_child(btn)
		
	_update_battle_button(map_id)

func _update_battle_button(map_id: String) -> void:
	if not is_instance_valid(start_battle_btn):
		return
	var conf = MAP_CONFIGS.get(map_id, {})
	var stages = conf.get("stages", [])
	var st = null
	for s in stages:
		if s.get("stage") == current_selected_stage:
			st = s
			break
	var s_title = st.get("name", "Катка %d" % current_selected_stage) if st else ("Катка %d" % current_selected_stage)
	var s_waves = st.get("waves", conf.get("max_waves", 10)) if st else conf.get("max_waves", 10)
	var ch_num = conf.get("chapter_num", 1)
	
	start_battle_btn.text = "⚔️ В БОЙ: Глава %d | Катка %d: %s (%d волн)!" % [ch_num, current_selected_stage, s_title, s_waves]
	start_battle_btn.disabled = not is_map_unlocked(map_id, meta_manager)

func _on_start_battle_pressed() -> void:
	GlobalState.selected_map = current_selected_map
	var conf = MAP_CONFIGS.get(current_selected_map, {})
	GlobalState.current_chapter = int(conf.get("chapter_num", 1))
	GlobalState.current_stage = current_selected_stage
	get_tree().change_scene_to_file("res://scenes/path_select.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
