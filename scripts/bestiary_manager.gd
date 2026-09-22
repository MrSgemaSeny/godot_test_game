class_name BestiaryManager
extends Node

## Менеджер бестиария (Этап 9)
## Отслеживает встречи, число убийств и открывает уязвимости врагов

signal enemy_discovered(enemy_type: String)
signal weakness_revealed(enemy_type: String)

var discoveries: Dictionary = {} # enemy_type -> {"kills": int, "seen": bool, "weakness_revealed": bool}

func _ready() -> void:
	add_to_group("bestiary_manager")

func register_encounter(enemy_type: String) -> void:
	if not discoveries.has(enemy_type):
		discoveries[enemy_type] = {
			"kills": 0,
			"seen": true,
			"weakness_revealed": false
		}
		enemy_discovered.emit(enemy_type)

func register_kill(enemy_type: String) -> void:
	register_encounter(enemy_type)
	discoveries[enemy_type]["kills"] += 1
	
	# При 5+ убийствах открываются уязвимости врага
	if discoveries[enemy_type]["kills"] >= 5 and not discoveries[enemy_type]["weakness_revealed"]:
		discoveries[enemy_type]["weakness_revealed"] = true
		weakness_revealed.emit(enemy_type)

func is_discovered(enemy_type: String) -> bool:
	return discoveries.has(enemy_type) and discoveries[enemy_type].get("seen", false)

func is_weakness_known(enemy_type: String) -> bool:
	return discoveries.has(enemy_type) and discoveries[enemy_type].get("weakness_revealed", false)

func get_kill_count(enemy_type: String) -> int:
	return discoveries.get(enemy_type, {}).get("kills", 0)
