class_name ComboTracker
extends Node

## Комбо-трекер наград и убийств (Этап 6)
## Отслеживает цепочки убийств, умножает золото и сбрасывается при простое или потере жизней

signal combo_updated(current_streak: int, multiplier: float)
signal combo_broken()

var current_streak: int = 0
var current_multiplier: float = 1.0
var window_duration: float = 2.5
var timer: float = 0.0

func _ready() -> void:
	add_to_group("combo_tracker")

func _process(delta: float) -> void:
	if current_streak > 0:
		timer -= delta
		if timer <= 0.0:
			reset_combo()

func register_kill() -> float:
	current_streak += 1
	timer = window_duration
	
	# Множитель: 1.0 на старте, +0.1 за каждые 3 убийства, максимум 2.5x
	current_multiplier = min(2.5, 1.0 + float(current_streak / 3) * 0.1)
	combo_updated.emit(current_streak, current_multiplier)
	return current_multiplier

func reset_combo() -> void:
	if current_streak > 0:
		current_streak = 0
		current_multiplier = 1.0
		timer = 0.0
		combo_broken.emit()
