class_name SaveMigrationV3
extends RefCounted

## Система миграции сохранений до Schema v3 (Фаза 10)
## Автоматически обновляет профили игроков, добавляя прогресс подземелий, NG+ и рекорды

const TARGET_SCHEMA_VERSION = 3

static func migrate_to_v3(raw_data: Dictionary) -> Dictionary:
	var result = raw_data.duplicate(true)
	var current_ver = int(result.get("schema_version", 1))
	
	if current_ver < 2:
		result = _migrate_v1_to_v2(result)
		
	if current_ver < 3:
		result = _migrate_v2_to_v3(result)
		
	result["schema_version"] = TARGET_SCHEMA_VERSION
	return result

static func _migrate_v1_to_v2(data: Dictionary) -> Dictionary:
	var v2 = data.duplicate(true)
	v2["schema_version"] = 2
	if not v2.has("glory_points"):
		v2["glory_points"] = int(v2.get("gold", 0))
	if not v2.has("meta_upgrades"):
		v2["meta_upgrades"] = {}
	if not v2.has("unlocked_artifacts"):
		v2["unlocked_artifacts"] = []
	if not v2.has("map_stars"):
		v2["map_stars"] = {"valley": 3}
	return v2

static func _migrate_v2_to_v3(data: Dictionary) -> Dictionary:
	var v3 = data.duplicate(true)
	v3["schema_version"] = 3
	
	# Add Phase 8-10 fields
	if not v3.has("ng_level"):
		v3["ng_level"] = 0
	if not v3.has("dungeon_best_floor"):
		v3["dungeon_best_floor"] = 0
	if not v3.has("daily_high_scores"):
		v3["daily_high_scores"] = {}
	if not v3.has("completed_challenges"):
		v3["completed_challenges"] = []
	if not v3.has("unlocked_modes"):
		v3["unlocked_modes"] = ["campaign", "nightmare", "endless", "boss_rush", "draft", "weekly"]
	if not v3.has("settings"):
		v3["settings"] = {
			"sfx_volume": 1.0,
			"music_volume": 0.8,
			"screen_shake": true,
			"damage_numbers": true,
			"high_contrast": false
		}
		
	return v3

static func is_save_valid_v3(data: Dictionary) -> bool:
	return data.get("schema_version", 0) >= 3 and data.has("glory_points") and data.has("map_stars")
