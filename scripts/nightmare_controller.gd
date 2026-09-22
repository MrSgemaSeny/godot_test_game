class_name NightmareController
extends Node

## Контроллер кошмарного режима (Этап 8)
## 1 жизнь, золото -50%, враги +50% HP, tech tree заблокировано

signal nightmare_mode_enabled()
signal nightmare_victory(secret_reward_id: String)
signal nightmare_defeat(attempt_count: int)

var is_nightmare_active: bool = false
var attempts: int = 0
var secret_reward: String = "infinity_stone"

func _ready() -> void:
	add_to_group("nightmare_controller")

func enable_nightmare() -> void:
	is_nightmare_active = true
	attempts += 1
	nightmare_mode_enabled.emit()

func disable_nightmare() -> void:
	is_nightmare_active = false

func get_starting_gold_multiplier() -> float:
	return 0.50 if is_nightmare_active else 1.0

func get_enemy_hp_multiplier() -> float:
	return 1.50 if is_nightmare_active else 1.0

func get_max_lives() -> int:
	return 1 if is_nightmare_active else 5

func is_tech_tree_allowed() -> bool:
	return not is_nightmare_active

func record_victory() -> String:
	if is_nightmare_active:
		nightmare_victory.emit(secret_reward)
		return secret_reward
	return ""

func record_defeat() -> void:
	if is_nightmare_active:
		nightmare_defeat.emit(attempts)
