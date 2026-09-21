class_name WaveController
extends Node

signal wave_countdown_started(duration: float, is_boss: bool)
signal wave_countdown_tick(time_left: float, total_time: float, is_boss: bool)
signal wave_started(wave_number: int, total_waves: int, is_boss: bool)
signal enemy_spawn_requested(enemy_type: String)
signal wave_completed(wave_number: int, is_last_wave: bool)
signal all_waves_completed()

const DEFAULT_PRE_WAVE_TIME: float = 30.0

var wave_data: Array = []
var current_wave_index: int = 0
var is_wave_active: bool = false
var is_counting_down: bool = false
var countdown_timer: float = 0.0
var countdown_total: float = DEFAULT_PRE_WAVE_TIME

# Счетчик для точного отслеживания завершения волны
var total_to_spawn: int = 0
var spawned_count: int = 0
var finished_count: int = 0

# Очередь спавна для текущей волны
var spawn_queue: Array = []
var wave_time_elapsed: float = 0.0

func _ready() -> void:
	load_waves_data()

func load_waves_data() -> void:
	if not FileAccess.file_exists("res://data/waves.json"):
		return
	var file = FileAccess.open("res://data/waves.json", FileAccess.READ)
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Array:
		wave_data = json.data

func reset_waves() -> void:
	current_wave_index = 0
	is_wave_active = false
	is_counting_down = false
	countdown_timer = 0.0
	spawned_count = 0
	finished_count = 0
	total_to_spawn = 0
	wave_time_elapsed = 0.0
	spawn_queue.clear()

func get_total_waves() -> int:
	return wave_data.size() if wave_data.size() > 0 else 10

func is_next_wave_boss() -> bool:
	if current_wave_index < wave_data.size():
		var w = wave_data[current_wave_index]
		for g in w.get("spawn_groups", []):
			var etype = g.get("enemy_type", "")
			if etype.contains("boss"):
				return true
	return false

func start_wave_countdown(duration: float = DEFAULT_PRE_WAVE_TIME) -> void:
	if is_wave_active:
		return
	is_counting_down = true
	countdown_total = duration
	countdown_timer = duration
	var is_boss = is_next_wave_boss()
	wave_countdown_started.emit(duration, is_boss)
	wave_countdown_tick.emit(duration, countdown_total, is_boss)

func stop_countdown() -> void:
	is_counting_down = false
	countdown_timer = 0.0

func start_current_wave(is_early: bool = false) -> bool:
	if is_wave_active:
		return false
		
	stop_countdown()
	
	if current_wave_index >= wave_data.size():
		all_waves_completed.emit()
		return false
		
	var w = wave_data[current_wave_index]
	var w_num = current_wave_index + 1
	var is_boss = is_next_wave_boss()
	
	is_wave_active = true
	wave_time_elapsed = 0.0
	spawned_count = 0
	finished_count = 0
	total_to_spawn = 0
	spawn_queue.clear()
	
	# Формирование очереди спавна из групп
	var groups = w.get("spawn_groups", [])
	for g in groups:
		var etype = g.get("enemy_type", "grunt")
		var count = int(g.get("count", 1))
		var interval = float(g.get("interval", 1.0))
		var delay = float(g.get("delay", 0.0))
		
		total_to_spawn += count
		for i in range(count):
			var spawn_time = delay + (i * interval)
			spawn_queue.append({
				"time": spawn_time,
				"enemy_type": etype,
				"spawned": false
			})
			
	# Сортировка очереди по времени
	spawn_queue.sort_custom(func(a, b): return a["time"] < b["time"])
	
	wave_started.emit(w_num, get_total_waves(), is_boss)
	return true

func _process(delta: float) -> void:
	if is_counting_down:
		countdown_timer -= delta
		var is_boss = is_next_wave_boss()
		if countdown_timer > 0.0:
			wave_countdown_tick.emit(countdown_timer, countdown_total, is_boss)
		else:
			is_counting_down = false
			start_current_wave(false)
			return
			
	if is_wave_active:
		_process_spawns(delta)

func _process_spawns(delta: float) -> void:
	wave_time_elapsed += delta
	for item in spawn_queue:
		if not item["spawned"] and wave_time_elapsed >= item["time"]:
			item["spawned"] = true
			spawned_count += 1
			enemy_spawn_requested.emit(item["enemy_type"])
			
	_check_wave_completion()

func register_enemy_finished(_outcome: MonsterBase.EnemyOutcome = MonsterBase.EnemyOutcome.KILLED, _reward: int = 0) -> void:
	finished_count += 1
	if is_wave_active:
		_check_wave_completion()

func _check_wave_completion() -> void:
	if not is_wave_active:
		return
		
	# Волна завершена ТОЛЬКО если все враги заспавнены И все завершили свой жизненный цикл
	if spawned_count >= total_to_spawn and finished_count >= total_to_spawn:
		is_wave_active = false
		wave_time_elapsed = 0.0
		var completed_wave_num = current_wave_index + 1
		current_wave_index += 1
		var is_last = (current_wave_index >= wave_data.size())
		
		wave_completed.emit(completed_wave_num, is_last)
		if is_last:
			all_waves_completed.emit()
