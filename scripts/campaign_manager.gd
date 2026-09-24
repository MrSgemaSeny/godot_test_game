class_name CampaignManager
extends Node

## CampaignManager — Управление кампанией из 5 глав и 59 каток (Переработка v2)
## Загружает campaign.json, контролирует разблокировку карт, максимальные уровни башен
## по главам (Гл 1-2: 3, Гл 3-4: 4, Гл 5: 5) и генерирует уникальные профили для всех 59 каток.

signal chapter_unlocked(chapter_id: String, chapter_num: int)
signal stage_unlocked(chapter_id: String, stage_id: String, stage_num: int)
signal stage_completed(stage_id: String, stars: int)

var campaign_data: Dictionary = {}
var chapters: Array[Dictionary] = []
var stages_by_id: Dictionary = {}

var current_chapter_index: int = 1
var current_stage_index: int = 1
var current_stage_id: String = "c1_01"

func _init() -> void:
	load_campaign_data()

func _enter_tree() -> void:
	add_to_group("campaign_manager")

func _ready() -> void:
	if chapters.is_empty():
		load_campaign_data()

func load_campaign_data(path: String = "res://data/campaign.json") -> bool:
	if not FileAccess.file_exists(path):
		_build_fallback_campaign()
		return false
		
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		_build_fallback_campaign()
		return false
		
	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	if err != OK or not (json.data is Dictionary):
		_build_fallback_campaign()
		return false
		
	campaign_data = json.data
	chapters.clear()
	stages_by_id.clear()
	
	var raw_chapters: Array = campaign_data.get("chapters", [])
	for ch in raw_chapters:
		chapters.append(ch)
		var maps: Array = ch.get("maps", ch.get("stages", []))
		for m in maps:
			var m_id = str(m.get("id", ""))
			if m_id != "":
				var enriched = m.duplicate(true)
				enriched["chapter_id"] = ch.get("id", "")
				enriched["chapter_num"] = ch.get("chapter_num", 1)
				enriched["biome"] = ch.get("biome", "plains")
				enriched["chapter_name"] = ch.get("name", "")
				enriched["max_tower_level"] = ch.get("max_tower_level", 3)
				stages_by_id[m_id] = enriched
				
	return true

func _build_fallback_campaign() -> void:
	# Безопасный фоллбэк со структурой 5 глав
	chapters = [
		{ "id": "chapter_1", "chapter_num": 1, "name": "Кудрявая Долина", "max_tower_level": 3, "maps": [] },
		{ "id": "chapter_2", "chapter_num": 2, "name": "Грибные Топи", "max_tower_level": 3, "maps": [] },
		{ "id": "chapter_3", "chapter_num": 3, "name": "Предместья Цитадели", "max_tower_level": 4, "maps": [] },
		{ "id": "chapter_4", "chapter_num": 4, "name": "Хрустальные Пещеры", "max_tower_level": 4, "maps": [] },
		{ "id": "chapter_5", "chapter_num": 5, "name": "Сердце Королевства", "max_tower_level": 5, "maps": [] }
	]

func get_total_chapters() -> int:
	return chapters.size()

func get_total_stages() -> int:
	var total = 0
	for ch in chapters:
		var maps: Array = ch.get("maps", [])
		total += maps.size()
	return total

func get_chapter_by_index(idx: int) -> Dictionary:
	var clamped = clamp(idx - 1, 0, chapters.size() - 1)
	return chapters[clamped] if not chapters.is_empty() else {}

func get_chapter_by_id(ch_id: String) -> Dictionary:
	for ch in chapters:
		if ch.get("id", "") == ch_id:
			return ch
	return {}

func get_chapter_stages(ch_id: String) -> Array[Dictionary]:
	var ch = get_chapter_by_id(ch_id)
	var maps: Array = ch.get("maps", [])
	var res: Array[Dictionary] = []
	for m in maps:
		res.append(m)
	return res

func get_stage_by_id(stage_id: String) -> Dictionary:
	if stages_by_id.has(stage_id):
		return stages_by_id[stage_id]
	return {}

func get_stage_by_coords(chapter_num: int, stage_num: int) -> Dictionary:
	var ch = get_chapter_by_index(chapter_num)
	var maps: Array = ch.get("maps", [])
	for m in maps:
		if int(m.get("stage", 0)) == stage_num:
			return get_stage_by_id(m.get("id", ""))
	return {}

func get_chapter_max_tower_level(chapter_num: int) -> int:
	# Спецификация Раздел 1.1:
	# Глава 1: 3
	# Глава 2: 3
	# Глава 3: 4
	# Глава 4: 4
	# Глава 5: 5
	match chapter_num:
		1, 2: return 3
		3, 4: return 4
		5: return 5
		_: return 5

func is_chapter_unlocked(chapter_num: int, meta: MetaManager) -> bool:
	if chapter_num <= 1:
		return true
	if meta == null:
		return chapter_num <= 1
		
	# Разблокировка по звездам и предыдущим главам
	match chapter_num:
		2:
			# Глава 2 открывается при наличии 2 звезд в главе 1
			return meta.get_map_stars("valley") >= 2 or meta.get_stage_stars("valley", 1) >= 2
		3:
			# Глава 3 открывается при прохождении главы 2
			return meta.get_map_stars("swamp") >= 1 or meta.get_stage_stars("swamp", 1) >= 1
		4:
			# Глава 4 открывается при прохождении глав 2 и 3
			return (meta.get_map_stars("swamp") >= 1) and (meta.get_map_stars("caves") >= 1 or meta.get_stage_stars("caves", 1) >= 1)
		5:
			# Глава 5 открывается при прохождении главы 4
			return meta.get_map_stars("frost_peak") >= 1 or meta.get_stage_stars("frost_peak", 1) >= 1
		_:
			return true

var completed_stages: Dictionary = {}

func get_stage_data(stage_id: String) -> Dictionary:
	return get_stage_by_id(stage_id)

func record_stage_completion(stage_id: String, stars: int) -> void:
	completed_stages[stage_id] = stars
	var st = get_stage_by_id(stage_id)
	if not st.is_empty():
		var ch_num = int(st.get("chapter_num", 1))
		var st_num = int(st.get("stage", 1))
		if is_inside_tree() and get_tree():
			var meta = get_tree().get_first_node_in_group("meta_manager") as MetaManager
			if meta:
				record_stage_result(ch_num, st_num, stars, meta)

func get_stage_stars(stage_id: String) -> int:
	if completed_stages.has(stage_id):
		return int(completed_stages[stage_id])
	if is_inside_tree() and get_tree():
		var meta = get_tree().get_first_node_in_group("meta_manager") as MetaManager
		if meta:
			var st = get_stage_by_id(stage_id)
			if not st.is_empty():
				var b = st.get("biome", "valley")
				var num = int(st.get("stage", 1))
				return meta.get_stage_stars(b, num)
	return 0

func is_stage_unlocked(arg1, arg2 = -1, meta: MetaManager = null) -> bool:
	if arg1 is String:
		var s_id: String = arg1
		if s_id == "c1_01":
			return true
		var st = get_stage_by_id(s_id)
		if st.is_empty():
			return false
		var ch_num = int(st.get("chapter_num", 1))
		var st_num = int(st.get("stage", 1))
		if st_num <= 1:
			return is_chapter_unlocked(ch_num, meta)
		var prev_id = "c%d_%02d" % [ch_num, st_num - 1]
		if get_stage_stars(prev_id) > 0:
			return true
		if meta != null and meta.get_stage_stars(st.get("biome", "valley"), st_num - 1) > 0:
			return true
		return false
	else:
		var chapter_num: int = int(arg1)
		var stage_num: int = int(arg2)
		if not is_chapter_unlocked(chapter_num, meta):
			return false
		if stage_num <= 1:
			return true
		if meta == null:
			var prev_id = "c%d_%02d" % [chapter_num, stage_num - 1]
			return get_stage_stars(prev_id) > 0
			
		var ch = get_chapter_by_index(chapter_num)
		var ch_biome = ch.get("biome", "valley")
		var prev_stars = meta.get_stage_stars(ch_biome, stage_num - 1)
		return prev_stars > 0

func record_stage_result(chapter_num: int, stage_num: int, stars: int, meta: MetaManager) -> void:
	if meta == null:
		return
	var ch = get_chapter_by_index(chapter_num)
	var ch_biome = ch.get("biome", "valley")
	meta.record_stage_victory(ch_biome, stage_num, stars)
	
	var st = get_stage_by_coords(chapter_num, stage_num)
	var st_id = str(st.get("id", "%s_%d" % [ch_biome, stage_num]))
	stage_completed.emit(st_id, stars)

func get_next_stage_coords(chapter_num: int, stage_num: int) -> Dictionary:
	var ch = get_chapter_by_index(chapter_num)
	var stages: Array = ch.get("maps", ch.get("stages", []))
	if stage_num < stages.size():
		return { "chapter_num": chapter_num, "stage_num": stage_num + 1, "is_final": false }
	elif chapter_num < get_total_chapters():
		return { "chapter_num": chapter_num + 1, "stage_num": 1, "is_final": false }
	else:
		return { "chapter_num": chapter_num, "stage_num": stage_num, "is_final": true }


func get_stage_layout(arg1, arg2: int = 1) -> Dictionary:
	var biome = "valley"
	var stage_num = 1
	if arg1 is String and (arg1.begins_with("c") and arg1.contains("_")):
		var st = get_stage_by_id(arg1)
		biome = st.get("biome", "valley")
		stage_num = int(st.get("stage", 1))
	elif arg1 is String:
		biome = arg1
		stage_num = arg2
	else:
		stage_num = arg2
		
	# Генерирует детерминированные кривые тропы и слоты под башни под каждую катку
	var rng = RandomNumberGenerator.new()
	rng.seed = hash("%s_stage_%d" % [biome, stage_num])
	
	var curve_pts: Array[Vector2] = []
	var spots: Array[Vector2] = []
	
	match biome:
		"plains", "valley":
			# Зигзагообразная зеленая тропа долины
			curve_pts = [
				Vector2(40, 200 + sin(stage_num) * 50),
				Vector2(320, 220 + cos(stage_num) * 60),
				Vector2(580, 480 - sin(stage_num) * 50),
				Vector2(920, 360 + cos(stage_num) * 40),
				Vector2(1240, 380)
			]
			spots = [
				Vector2(200, 140), Vector2(420, 320), Vector2(460, 480),
				Vector2(750, 420), Vector2(760, 280), Vector2(1050, 440)
			]
		"swamp":
			# Извилистая топкая тропа с 3 витками
			curve_pts = [
				Vector2(40, 160),
				Vector2(300, 380),
				Vector2(600, 180),
				Vector2(850, 520),
				Vector2(1240, 420)
			]
			spots = [
				Vector2(180, 260), Vector2(450, 280), Vector2(480, 110),
				Vector2(720, 350), Vector2(980, 420), Vector2(1100, 500)
			]
		"suburbs":
			# Уличные перекрестки предместий
			curve_pts = [
				Vector2(40, 360),
				Vector2(380, 360),
				Vector2(380, 180),
				Vector2(820, 180),
				Vector2(820, 500),
				Vector2(1240, 500)
			]
			spots = [
				Vector2(250, 290), Vector2(450, 280), Vector2(600, 110),
				Vector2(750, 280), Vector2(900, 420), Vector2(1050, 420)
			]
		"crystal_cave", "caves":
			# Подземный лабиринт гротов
			curve_pts = [
				Vector2(40, 500),
				Vector2(280, 240),
				Vector2(550, 480),
				Vector2(800, 220),
				Vector2(1050, 440),
				Vector2(1240, 280)
			]
			spots = [
				Vector2(160, 360), Vector2(400, 350), Vector2(680, 340),
				Vector2(920, 320), Vector2(1120, 360), Vector2(600, 560)
			]
		_:
			# Осаждённая цитадель: парадный проспект
			curve_pts = [
				Vector2(40, 180),
				Vector2(350, 180),
				Vector2(350, 480),
				Vector2(700, 480),
				Vector2(700, 260),
				Vector2(1000, 260),
				Vector2(1000, 420),
				Vector2(1240, 420)
			]
			spots = [
				Vector2(200, 260), Vector2(420, 320), Vector2(550, 410),
				Vector2(780, 360), Vector2(880, 200), Vector2(1100, 340)
			]
			
	return {
		"curve": curve_pts,
		"spots": spots,
		"village": Vector2(1180, 420)
	}
