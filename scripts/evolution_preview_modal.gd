class_name EvolutionPreviewModal
extends PanelContainer

## Модальное окно выбора эволюции башни (Stage 3)
## Показывает сравнение двух веток специализации и подтверждение выбора

signal evolution_confirmed(branch: String)

@onready var title_label: Label = $VBox/TitleLabel
@onready var warning_label: Label = $VBox/WarningLabel

# Колонка ветки A
@onready var evo_a_name: Label = $VBox/Columns/ColumnA/EvoAName
@onready var evo_a_desc: Label = $VBox/Columns/ColumnA/EvoADesc
@onready var evo_a_stats: Label = $VBox/Columns/ColumnA/EvoAStats
@onready var evo_a_ability: Label = $VBox/Columns/ColumnA/EvoAAbility
@onready var confirm_a_btn: Button = $VBox/Columns/ColumnA/ConfirmABtn

# Колонка ветки B
@onready var evo_b_name: Label = $VBox/Columns/ColumnB/EvoBName
@onready var evo_b_desc: Label = $VBox/Columns/ColumnB/EvoBDesc
@onready var evo_b_stats: Label = $VBox/Columns/ColumnB/EvoBStats
@onready var evo_b_ability: Label = $VBox/Columns/ColumnB/EvoBAbility
@onready var confirm_b_btn: Button = $VBox/Columns/ColumnB/ConfirmBBtn

@onready var close_btn: Button = $VBox/CloseBtn

var pending_tower: TowerBase = null

func _ready() -> void:
	visible = false
	if is_instance_valid(confirm_a_btn):
		confirm_a_btn.pressed.connect(_on_confirm_a)
	if is_instance_valid(confirm_b_btn):
		confirm_b_btn.pressed.connect(_on_confirm_b)
	if is_instance_valid(close_btn):
		close_btn.pressed.connect(close_modal)

func show_preview(tower: TowerBase) -> void:
	if not is_instance_valid(tower) or not tower.can_evolve():
		return
	
	pending_tower = tower
	
	var info_a = tower.get_evolution_info("evolution_a")
	var info_b = tower.get_evolution_info("evolution_b")
	
	if is_instance_valid(title_label):
		title_label.text = "⚔️ %s — Выберите специализацию" % tower.tower_name
	if is_instance_valid(warning_label):
		warning_label.text = "⚠️ Выбор необратим! Башня навсегда получит выбранную специализацию."
	
	# Заполняем данные ветки A
	_fill_column_a(info_a)
	_fill_column_b(info_b)
	
	visible = true

func _fill_column_a(info: Dictionary) -> void:
	if is_instance_valid(evo_a_name):
		evo_a_name.text = "🔵 %s" % info.get("name", "Ветка A")
	if is_instance_valid(evo_a_desc):
		evo_a_desc.text = str(info.get("description", ""))
	if is_instance_valid(evo_a_stats):
		evo_a_stats.text = _format_stats(info)
	if is_instance_valid(evo_a_ability):
		var ability = info.get("special_ability", "")
		evo_a_ability.text = "✨ %s" % _translate_ability(ability) if ability != "" else ""
	if is_instance_valid(confirm_a_btn):
		confirm_a_btn.text = "✅ Выбрать: %s" % info.get("name", "A")
		confirm_a_btn.disabled = info.is_empty()

func _fill_column_b(info: Dictionary) -> void:
	if is_instance_valid(evo_b_name):
		evo_b_name.text = "🔴 %s" % info.get("name", "Ветка B")
	if is_instance_valid(evo_b_desc):
		evo_b_desc.text = str(info.get("description", ""))
	if is_instance_valid(evo_b_stats):
		evo_b_stats.text = _format_stats(info)
	if is_instance_valid(evo_b_ability):
		var ability = info.get("special_ability", "")
		evo_b_ability.text = "✨ %s" % _translate_ability(ability) if ability != "" else ""
	if is_instance_valid(confirm_b_btn):
		confirm_b_btn.text = "✅ Выбрать: %s" % info.get("name", "B")
		confirm_b_btn.disabled = info.is_empty()

func _format_stats(info: Dictionary) -> String:
	var dmg = info.get("damage", 0)
	var rng = info.get("range", 0)
	var spd = info.get("attack_speed", 0)
	var lines: Array = []
	if dmg > 0:
		lines.append("⚔️ Урон: %.0f" % float(dmg))
	if rng > 0:
		lines.append("🎯 Радиус: %.0f" % float(rng))
	if spd > 0:
		lines.append("⚡ Скор.: %.1f/с" % float(spd))
	var splash = info.get("splash_radius", 0)
	if splash > 0:
		lines.append("💥 Сплэш: %.0f" % float(splash))
	var pierce = info.get("pierce", 0)
	if pierce > 1:
		lines.append("🔗 Пробитие: %d целей" % int(pierce))
	var gold = info.get("gold_per_sec", 0)
	if gold > 0:
		lines.append("🪙 Доход: %d/сек" % int(gold))
	var slow = info.get("slow_factor", 0)
	if slow > 0:
		lines.append("❄️ Замедление: %.0f%%" % (float(slow) * 100.0))
	return "\n".join(lines)

func _translate_ability(ability_key: String) -> String:
	# Человекочитаемые описания спецспособностей
	match ability_key:
		"crit_20_percent": return "20% шанс критического удара (x3 урон)"
		"pierce_5": return "Пробивает насквозь до 5 целей"
		"reveal_stealth": return "Обнаруживает невидимых врагов"
		"armor_pierce": return "Игнорирует 50% брони цели"
		"true_damage": return "Наносит чистый урон (обход брони и щитов)"
		"triple_burst": return "Тройной залп за одну атаку"
		"homing_missiles": return "Самонаводящиеся ракеты (не промахиваются)"
		"aura_buff_towers": return "Баффает ближайшие башни (+25% урон, +15% скорость)"
		"melee_damage_ring": return "Кольцо урона вокруг крепости"
		"freeze_chance_30": return "30% шанс заморозить цель на 2 сек"
		"time_stop_periodic": return "Каждые 8 сек останавливает всех врагов в радиусе"
		"summon_undead": return "Призывает нежить из убитых врагов"
		"poison_aoe_on_death": return "Ядовитое облако при гибели врага в радиусе"
		"teleport_back": return "Телепортирует врагов назад по маршруту"
		"buff_allies_speed": return "Все башни рядом: +30% скорость атаки"
		"massive_gold": return "Утроенный доход золотом"
		"random_wave_buff": return "Случайный бафф каждую волну"
		"nuclear_blast": return "Гигантский одиночный взрыв (1000 урон)"
		"triple_mines": return "3 мины вместо одной, быстрая перезарядка"
		"gatling_fire": return "Безумная скорострельность (8+ атак/сек)"
		"railgun_pierce": return "Лазерный луч пронзает всю линию врагов"
	return ability_key

func _on_confirm_a() -> void:
	evolution_confirmed.emit("evolution_a")
	close_modal()

func _on_confirm_b() -> void:
	evolution_confirmed.emit("evolution_b")
	close_modal()

func close_modal() -> void:
	visible = false
	pending_tower = null
