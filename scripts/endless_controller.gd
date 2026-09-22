class_name EndlessController
extends Node

## Контроллер бесконечного режима (Этап 8)
## Процедурная генерация волн с нарастающей сложностью и подсчетом рекордов

signal endless_wave_started(wave_number: int, difficulty_scale: float)
signal endless_record_broken(new_high_score: int)

var is_endless_active: bool = false
var current_wave: int = 0
var difficulty_scale: float = 1.0
var enemies_killed: int = 0
var gold_earned: int = 0
var high_score_wave: int = 0

const ENEMY_POOL: Array[String] = [
	"grunt", "berserker", "armored", "shaman", "troll", "stealth", "mosquito", "windwing", "shell_beetle"
]

const BOSS_POOL: Array[String] = [
	"warchief_boss", "archmage_boss"
]

func _ready() -> void:
	add_to_group("endless_controller")

func start_endless(from_wave: int = 26) -> void:
	is_endless_active = true
	current_wave = from_wave
	difficulty_scale = 1.0 + float(from_wave - 25) * 0.15
	enemies_killed = 0
	gold_earned = 0

func generate_next_wave() -> Dictionary:
	current_wave += 1
	# Каждые 5 волн difficulty_scale растет на +1.0
	difficulty_scale = 1.0 + float(current_wave / 5) * 1.0
	
	var is_boss_wave = (current_wave % 5 == 0)
	var wave_spawns: Array[Dictionary] = []
	var count = 12 + int(difficulty_scale * 3.0)
	
	for i in range(count):
		var enemy_type = ENEMY_POOL.pick_random()
		wave_spawns.append({
			"type": enemy_type,
			"delay": 0.8 + randf() * 0.5
		})
		
	if is_boss_wave:
		wave_spawns.append({
			"type": BOSS_POOL.pick_random(),
			"delay": 2.5
		})
		
	endless_wave_started.emit(current_wave, difficulty_scale)
	
	return {
		"wave_number": current_wave,
		"difficulty_scale": difficulty_scale,
		"is_boss_wave": is_boss_wave,
		"spawns": wave_spawns
	}

func record_kill(gold: int) -> void:
	enemies_killed += 1
	gold_earned += gold

func finish_endless() -> Dictionary:
	is_endless_active = false
	var is_new_record = current_wave > high_score_wave
	if is_new_record:
		high_score_wave = current_wave
		endless_record_broken.emit(high_score_wave)
		
	return {
		"final_wave": current_wave,
		"enemies_killed": enemies_killed,
		"gold_earned": gold_earned,
		"is_new_record": is_new_record,
		"high_score": high_score_wave
	}
