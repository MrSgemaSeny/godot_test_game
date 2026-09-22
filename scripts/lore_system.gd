class_name LoreSystem
extends Node

## Система лора и контекстных диалогов (Этап 9)
## Выдает реплики персонажей по триггерам без прерывания геймплея

signal dialogue_spoken(speaker: String, text: String)

var lore_entries: Array = []
var shown_entries: Array[int] = []

func _ready() -> void:
	add_to_group("lore_system")
	_load_lore_db()

func _load_lore_db() -> void:
	if not FileAccess.file_exists("res://data/lore.json"):
		return
	var f = FileAccess.open("res://data/lore.json", FileAccess.READ)
	var json = JSON.new()
	if json.parse(f.get_as_text()) == OK and json.data is Array:
		lore_entries = json.data.duplicate(true)

func trigger_event(map_id: String, wave_number: int, trigger_type: String) -> Dictionary:
	for i in range(lore_entries.size()):
		if i in shown_entries:
			continue
		var entry = lore_entries[i]
		if entry.get("map") == map_id and int(entry.get("wave", 0)) == wave_number and entry.get("trigger") == trigger_type:
			shown_entries.append(i)
			var spk = str(entry.get("speaker", "Голос"))
			var txt = str(entry.get("text", ""))
			dialogue_spoken.emit(spk, txt)
			return entry
	return {}

func reset_session() -> void:
	shown_entries.clear()
