class_name ChallengeManager
extends Node

## Менеджер испытаний (Этап 8)
## Предоставляет 20 уникальных режимов испытаний с модификаторами правил

signal challenge_started(challenge_id: String)
signal challenge_completed(challenge_id: String)

const CHALLENGES_DB: Dictionary = {
	"no_magic": {
		"name": "Без магии",
		"description": "Заклинания полностью заблокированы.",
		"mutators": ["disable_spells"]
	},
	"poverty": {
		"name": "Нищета",
		"description": "Стартовое золото снижено до 50 вместо 200.",
		"mutators": ["start_gold_50"]
	},
	"pacifist": {
		"name": "Пацифист",
		"description": "Разрешено строить только башни поддержки и ловушки.",
		"mutators": ["only_support_and_traps"]
	},
	"veteran": {
		"name": "Ветеран",
		"description": "Здоровье всех врагов увеличено на +100%.",
		"mutators": ["enemy_hp_double"]
	},
	"speed_freaks": {
		"name": "Спринтеры",
		"description": "Скорость всех врагов увеличена на +50%.",
		"mutators": ["enemy_speed_150"]
	},
	"no_sales": {
		"name": "Без продаж",
		"description": "Продажа построенных башен запрещена.",
		"mutators": ["disable_selling"]
	},
	"ironman": {
		"name": "Железный человек",
		"description": "Только 1 жизнь. Любая потерянная девочка приводит к поражению.",
		"mutators": ["one_life"]
	},
	"magic_only": {
		"name": "Обитель магов",
		"description": "Разрешены только магические башни (лед, некромант, время).",
		"mutators": ["magic_towers_only"]
	},
	"military_only": {
		"name": "Стальной легион",
		"description": "Разрешены только военные башни (лучники, пушки, бастион).",
		"mutators": ["military_towers_only"]
	},
	"inflation": {
		"name": "Инфляция",
		"description": "Стоимость всех башен и улучшений увеличена на +50%.",
		"mutators": ["cost_mult_150"]
	},
	"thick_armor": {
		"name": "Тяжелая броня",
		"description": "Все враги получают +40 к показателю брони.",
		"mutators": ["all_enemies_armored"]
	},
	"magic_immune": {
		"name": "Антимагия",
		"description": "Все враги невосприимчивы к магическому урону.",
		"mutators": ["enemies_magic_immune"]
	},
	"stealth_swarm": {
		"name": "Теневая орда",
		"description": "Все враги становятся скрытными/невидимыми.",
		"mutators": ["all_enemies_stealth"]
	},
	"dense_fog": {
		"name": "Мгла",
		"description": "Радиус атаки всех башен снижен на -35%.",
		"mutators": ["range_reduced_35"]
	},
	"berserk_frenzy": {
		"name": "Безумие",
		"description": "Враги ускоряются в 2 раза при здоровье ниже 50%.",
		"mutators": ["enrage_at_half_hp"]
	},
	"curse_of_greed": {
		"name": "Проклятие жадности",
		"description": "Убийства врагов не дают золота (золото дают только торговые посты).",
		"mutators": ["zero_kill_gold"]
	},
	"boss_parade": {
		"name": "Парад вождей",
		"description": "Каждые 3 волны появляется полноценный босс.",
		"mutators": ["frequent_bosses"]
	},
	"glass_citadel": {
		"name": "Хрупкая цитадель",
		"description": "Башни имеют стоимость постройки в 2 раза ниже, но наносят половинный урон.",
		"mutators": ["half_cost_half_dmg"]
	},
	"chaos_path": {
		"name": "Хаос",
		"description": "Погода меняется каждую волну.",
		"mutators": ["random_weather_per_wave"]
	},
	"ultimate_gauntlet": {
		"name": "Абсолютное испытание",
		"description": "Враги +50% HP, +25% скорости, без заклинаний, 2 жизни.",
		"mutators": ["gauntlet_extreme"]
	}
}

var active_challenge_id: String = ""

func _ready() -> void:
	add_to_group("challenge_manager")

func start_challenge(challenge_id: String) -> bool:
	if not CHALLENGES_DB.has(challenge_id):
		return false
	active_challenge_id = challenge_id
	challenge_started.emit(challenge_id)
	return true

func stop_challenge() -> void:
	active_challenge_id = ""

func is_challenge_active() -> bool:
	return active_challenge_id != ""

func has_mutator(mutator_name: String) -> bool:
	if active_challenge_id == "" or not CHALLENGES_DB.has(active_challenge_id):
		return false
	var muts = CHALLENGES_DB[active_challenge_id].get("mutators", [])
	return mutator_name in muts

func get_challenge_name(challenge_id: String) -> String:
	return CHALLENGES_DB.get(challenge_id, {}).get("name", "")
