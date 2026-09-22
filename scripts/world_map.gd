class_name WorldMap
extends Control

## Карта мира кампании (Этап 5)
## Управляет выбором локаций, биомами, условиями разблокировки и звездами

signal map_selected(map_id: String)

const MAP_CONFIGS: Dictionary = {
	"valley": {
		"name": "Кудрявая Долина",
		"biome": "plains",
		"description": "Зеленые луга королевства. Один четкий маршрут. Идеально для обучения.",
		"unlock_req": {"type": "default"},
		"modifiers": [],
		"path_branches": 1,
		"max_waves": 10,
		"bonus_condition": "Не использовать заклинания"
	},
	"swamp": {
		"name": "Грибные Топи",
		"biome": "swamp",
		"description": "Болотный ядовитый воздух замедляет механизмы (-15% attack_speed). Три маршрута.",
		"unlock_req": {"type": "stars", "map": "valley", "count": 2},
		"modifiers": [{"type": "attack_speed_debuff", "value": 0.15}],
		"path_branches": 3,
		"max_waves": 15,
		"bonus_condition": "Не потерять ни одной жизни"
	},
	"caves": {
		"name": "Хрустальные Пещеры",
		"biome": "crystal_cave",
		"description": "Глубокие подземные туннели. Темнота снижает радиус башен (-40% range).",
		"unlock_req": {"type": "completed_maps", "count": 2},
		"modifiers": [{"type": "range_debuff", "value": 0.40}],
		"path_branches": 2,
		"max_waves": 15,
		"bonus_condition": "Не строить башни огня"
	},
	"frost_peak": {
		"name": "Морозный Пик",
		"biome": "frost",
		"description": "Ледяные тропы ускоряют врагов (+20% speed). Ловушки замерзают и не срабатывают.",
		"unlock_req": {"type": "both_maps", "maps": ["swamp", "caves"]},
		"modifiers": [{"type": "enemy_speed_buff", "value": 0.20}, {"type": "disable_traps"}],
		"path_branches": 2,
		"max_waves": 20,
		"bonus_condition": "Пройти только магическими башнями"
	},
	"besieged_citadel": {
		"name": "Осаждённый Город",
		"biome": "citadel",
		"description": "Финальная битва. Четыре фронта наступления на центральную цитадель.",
		"unlock_req": {"type": "map_completed", "map": "frost_peak"},
		"modifiers": [],
		"path_branches": 4,
		"max_waves": 25,
		"bonus_condition": "Спасти всех девочек во всех волнах"
	}
}

var current_selected_map: String = "valley"

func is_map_unlocked(map_id: String, meta: MetaManager = null) -> bool:
	if not MAP_CONFIGS.has(map_id):
		return false
	var conf = MAP_CONFIGS[map_id]
	var req = conf.get("unlock_req", {})
	var r_type = req.get("type", "default")
	
	if r_type == "default":
		return true
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
	return true

func get_map_stars_and_status(map_id: String, meta: MetaManager = null) -> Dictionary:
	var unlocked = is_map_unlocked(map_id, meta)
	var stars = meta.get_map_stars(map_id) if meta != null else 0
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
