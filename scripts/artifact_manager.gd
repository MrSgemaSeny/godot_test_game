class_name ArtifactManager
extends Node

## Менеджер пассивных артефактов (Этап 6)
## Управляет хранилищем артефактов, слотами экипировки и расчетом бонусов

signal artifact_equipped(artifact_id: String, slot_idx: int)
signal artifact_unequipped(slot_idx: int)
signal artifact_unlocked(artifact_id: String)

var artifacts_db: Dictionary = {}
var unlocked_artifacts: Array[String] = []
var equipped_slots: Array = ["", "", ""] # 3 слота экипировки
var max_slots: int = 3

func _ready() -> void:
	add_to_group("artifact_manager")
	_load_artifacts_db()

func _load_artifacts_db() -> void:
	if not FileAccess.file_exists("res://data/artifacts.json"):
		return
	var f = FileAccess.open("res://data/artifacts.json", FileAccess.READ)
	var json = JSON.new()
	if json.parse(f.get_as_text()) == OK and json.data is Dictionary:
		artifacts_db = json.data.duplicate(true)

func unlock_artifact(artifact_id: String) -> bool:
	if not artifacts_db.has(artifact_id):
		return false
	if not (artifact_id in unlocked_artifacts):
		unlocked_artifacts.append(artifact_id)
		artifact_unlocked.emit(artifact_id)
		return true
	return false

func is_unlocked(artifact_id: String) -> bool:
	return artifact_id in unlocked_artifacts

func equip_artifact(artifact_id: String, slot_idx: int) -> bool:
	if slot_idx < 0 or slot_idx >= max_slots:
		return false
	if not is_unlocked(artifact_id):
		return false
	if is_equipped(artifact_id):
		# Unequip from other slot first
		var prev_idx = equipped_slots.find(artifact_id)
		if prev_idx != -1:
			equipped_slots[prev_idx] = ""
			
	equipped_slots[slot_idx] = artifact_id
	artifact_equipped.emit(artifact_id, slot_idx)
	return true

func unequip_slot(slot_idx: int) -> bool:
	if slot_idx < 0 or slot_idx >= max_slots:
		return false
	if equipped_slots[slot_idx] == "":
		return false
	equipped_slots[slot_idx] = ""
	artifact_unequipped.emit(slot_idx)
	return true

func is_equipped(artifact_id: String) -> bool:
	return artifact_id in equipped_slots

func get_artifact_data(artifact_id: String) -> Dictionary:
	return artifacts_db.get(artifact_id, {})

func has_active_effect(effect_name: String) -> bool:
	for art_id in equipped_slots:
		if art_id != "" and artifacts_db.has(art_id):
			if artifacts_db[art_id].get("effect") == effect_name:
				return true
	return false

func get_effect_value(effect_name: String, default_val: float = 0.0) -> float:
	for art_id in equipped_slots:
		if art_id != "" and artifacts_db.has(art_id):
			var data = artifacts_db[art_id]
			if data.get("effect") == effect_name:
				return float(data.get("value", default_val))
	return default_val
