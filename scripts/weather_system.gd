class_name WeatherSystem
extends Node

## Погодная система уровней (Этап 7)
## Управляет модификаторами погодных условий (Дождь, Туман, Затмение, Снегопад, Гроза)

signal weather_changed(new_weather: String)
signal lightning_struck(target_pos: Vector2, damage: float)

enum WeatherType {
	CLEAR,
	RAIN,
	FOG,
	ECLIPSE,
	SNOW,
	THUNDERSTORM
}

var current_weather: String = "clear"
var thunderstorm_timer: float = 0.0

func _ready() -> void:
	add_to_group("weather_system")

func _process(delta: float) -> void:
	if current_weather == "thunderstorm":
		thunderstorm_timer -= delta
		if thunderstorm_timer <= 0.0:
			thunderstorm_timer = 20.0
			_trigger_weather_lightning()

func set_weather(weather_name: String) -> void:
	current_weather = weather_name.to_lower()
	if current_weather == "thunderstorm":
		thunderstorm_timer = 10.0
	weather_changed.emit(current_weather)

func get_damage_modifier(damage_type: String) -> float:
	match current_weather:
		"rain":
			if damage_type == "lightning": return 1.25
			elif damage_type == "fire": return 0.70
		"snow":
			if damage_type == "cold": return 1.20
		"thunderstorm":
			if damage_type == "lightning": return 1.40
	return 1.0

func get_tower_range_modifier() -> float:
	if current_weather == "fog":
		return 0.80 # -20% range in fog
	return 1.0

func get_enemy_speed_modifier() -> float:
	match current_weather:
		"eclipse": return 1.20 # +20% speed
		"snow": return 0.90 # -10% speed
	return 1.0

func get_gold_multiplier() -> float:
	if current_weather == "eclipse":
		return 2.0 # x2 gold in eclipse
	return 1.0

func are_traps_disabled() -> bool:
	return current_weather == "snow"

func _trigger_weather_lightning() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies") if is_inside_tree() else []
	if enemies.is_empty():
		return
	var rand_enemy = enemies.pick_random()
	if is_instance_valid(rand_enemy) and rand_enemy.has_method("take_damage"):
		rand_enemy.take_damage(100.0, "lightning")
		lightning_struck.emit(rand_enemy.global_position, 100.0)
