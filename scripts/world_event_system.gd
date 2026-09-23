class_name WorldEventSystem
extends Node

## Engine for handling random world events. Triggers between waves or based on region entry.
## Events present choices to the player with various risks and rewards.

signal event_triggered(event_data: Dictionary)
signal event_resolved(event_id: String, choice_idx: int, rewards: Dictionary)

var events_db: Dictionary = {}
var event_history: Array[String] = []

func _init() -> void:
	add_to_group("world_event_system")

func _ready() -> void:
	_load_events_db()

## Load events from JSON database
func _load_events_db() -> void:
	var path = "res://data/world_events.json"
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			if json.data is Array:
				for evt in json.data:
					if evt is Dictionary and evt.has("id"):
						events_db[evt["id"]] = evt
			elif json.data is Dictionary:
				events_db = json.data
	else:
		_setup_fallback_events()

func _setup_fallback_events() -> void:
	events_db["plague_outbreak"] = {
		"id": "plague_outbreak",
		"name": "Plague Outbreak",
		"description": "A deadly sickness spreads among your troops.",
		"trigger_conditions": ["swamp", "city"],
		"choices": [
			{"text": "Quarantine (Lose 5 lives)", "cost": {"lives": 5}, "reward": {}},
			{"text": "Buy Medicine (Cost 200 gold)", "cost": {"gold": 200}, "reward": {"reputation": 10}}
		]
	}
	events_db["wandering_merchant"] = {
		"id": "wandering_merchant",
		"name": "Wandering Merchant",
		"description": "A merchant offers a rare artifact.",
		"trigger_conditions": ["any"],
		"choices": [
			{"text": "Buy Artifact (Cost 500 gold)", "cost": {"gold": 500}, "reward": {"artifact": "random"}},
			{"text": "Ignore", "cost": {}, "reward": {}}
		]
	}

## Attempts to trigger a random event based on the current context.
func try_trigger_random_event(current_region: String, threat_level: int) -> bool:
	# Higher threat means higher chance of negative/challenging events
	var chance = 0.1 + (threat_level * 0.05)
	if randf() > chance:
		return false
		
	var valid_events = []
	for evt in events_db.values():
		var conditions = evt.get("trigger_conditions", ["any"])
		if "any" in conditions or current_region in conditions:
			if evt["id"] not in event_history or evt.get("repeatable", false):
				valid_events.append(evt)
				
	if valid_events.is_empty():
		return false
		
	var chosen = valid_events[randi() % valid_events.size()]
	trigger_event_by_id(chosen["id"])
	return true

## Triggers a specific event directly by its ID.
func trigger_event_by_id(event_id: String) -> void:
	if events_db.has(event_id):
		var evt = events_db[event_id]
		event_history.append(event_id)
		
		# Allow limiting history size to prevent memory leak on super long runs
		if event_history.size() > 100:
			event_history.pop_front()
			
		event_triggered.emit(evt)

## Resolves an event based on the player's choice index.
func resolve_event(event_id: String, choice_idx: int) -> Dictionary:
	if not events_db.has(event_id):
		return {"success": false, "error": "Event not found"}
		
	var evt = events_db[event_id]
	var choices = evt.get("choices", [])
	if choice_idx < 0 or choice_idx >= choices.size():
		return {"success": false, "error": "Invalid choice"}
		
	var choice = choices[choice_idx]
	var costs = choice.get("cost", {})
	var rewards = choice.get("reward", {})
	
	# Execute costs and rewards via signals or GameManager integration
	_apply_costs_and_rewards(costs, rewards)
	
	event_resolved.emit(event_id, choice_idx, rewards)
	return {"success": true, "rewards": rewards, "costs": costs}

func _apply_costs_and_rewards(costs: Dictionary, rewards: Dictionary) -> void:
	# In a full implementation, this calls GameManager to apply logic
	# For Phase 3 scope, we define the structure of applying these
	pass

func get_event_history() -> Array[String]:
	return event_history.duplicate()

func clear_history() -> void:
	event_history.clear()

func get_event_data(event_id: String) -> Dictionary:
	return events_db.get(event_id, {}).duplicate(true)

func save_state() -> Dictionary:
	return {
		"event_history": event_history.duplicate(true)
	}

func load_state(data: Dictionary) -> void:
	if data.has("event_history"):
		event_history = data["event_history"].duplicate(true)
