class_name DailyChallengeGenerator
extends Node

## Генератор ежедневных глобальных испытаний (Фаза 8)
## Формирует детерминированные испытания на каждый календарный день с подсчётом очков таблицы рекордов

signal challenge_ready(challenge_data: Dictionary)
signal score_calculated(final_score: int, breakdown: Dictionary)

const MUTATOR_POOL: Array[String] = [
	"speed_freaks", "thick_armor", "no_magic", "poverty",
	"dense_fog", "veteran", "berserk_frenzy", "chaos_path",
	"magic_only", "military_only", "inflation", "boss_parade"
]

const BIOMES: Array[String] = [
	"valley", "swamp", "caves", "frost_peak", "besieged_citadel"
]

var active_daily_challenge: Dictionary = {}

func _ready() -> void:
	add_to_group("daily_challenge_generator")
	generate_today_challenge()

func get_today_seed() -> int:
	var dt = Time.get_date_dict_from_system()
	var yr = int(dt.get("year", 2026))
	var mo = int(dt.get("month", 9))
	var da = int(dt.get("day", 24))
	return yr * 10000 + mo * 100 + da

func generate_today_challenge() -> Dictionary:
	var seed_val = get_today_seed()
	return generate_challenge_for_seed(seed_val)

func generate_challenge_for_seed(seed_val: int) -> Dictionary:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val
	
	var biome = BIOMES[rng.randi_range(0, BIOMES.size() - 1)]
	var mut_count = rng.randi_range(2, 3)
	var chosen_mutators: Array[String] = []
	var pool_copy = MUTATOR_POOL.duplicate()
	
	for i in range(mut_count):
		if pool_copy.is_empty(): break
		var idx = rng.randi_range(0, pool_copy.size() - 1)
		chosen_mutators.append(pool_copy[idx])
		pool_copy.remove_at(idx)
		
	var wave_count = rng.randi_range(12, 18)
	var gold_mult = 1.0 + (rng.randf_range(-0.2, 0.4))
	var score_multiplier = 1.0 + (chosen_mutators.size() * 0.25)
	
	active_daily_challenge = {
		"date_seed": seed_val,
		"title": "Ежедневный Вызов #%d" % (seed_val % 10000),
		"biome": biome,
		"total_waves": wave_count,
		"mutators": chosen_mutators,
		"starting_gold": int(200 * gold_mult),
		"score_multiplier": score_multiplier,
		"glory_reward": 150 + (chosen_mutators.size() * 50)
	}
	
	challenge_ready.emit(active_daily_challenge)
	return active_daily_challenge

func calculate_run_score(waves_cleared: int, lives_left: int, time_seconds: float, towers_built: int) -> Dictionary:
	var base_score = waves_cleared * 1000
	var lives_bonus = lives_left * 500
	var speed_bonus = max(0, int((900.0 - time_seconds) * 5.0))
	var efficiency_bonus = max(0, 500 - (towers_built * 25))
	
	var raw_total = base_score + lives_bonus + speed_bonus + efficiency_bonus
	var mult = float(active_daily_challenge.get("score_multiplier", 1.0))
	var final_score = int(raw_total * mult)
	
	var breakdown = {
		"base_score": base_score,
		"lives_bonus": lives_bonus,
		"speed_bonus": speed_bonus,
		"efficiency_bonus": efficiency_bonus,
		"multiplier": mult,
		"final_score": final_score
	}
	
	score_calculated.emit(final_score, breakdown)
	return breakdown
