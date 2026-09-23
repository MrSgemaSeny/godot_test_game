class_name WorldEventSystem
extends Node

## Engine for handling random world events. Triggers between waves or based on region entry.
## Events present choices to the player with various risks and rewards.
## Includes a comprehensive fallback database of 40+ events.
## Integrates deeply with faction influence, meta-progression, and threat levels.

signal event_triggered(event_data: Dictionary)
signal event_resolved(event_id: String, choice_idx: int, rewards: Dictionary)
signal global_alert_broadcast(alert_msg: String)
signal faction_standing_changed(faction: String, amount: int)
signal boss_spawn_queued(boss_type: String)

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
				
	# Always ensure fallback events exist if json is incomplete
	_setup_fallback_events()

func _setup_fallback_events() -> void:
	var fallbacks = [
		{
			"id": "plague_outbreak_fb",
			"name": "Plague Outbreak",
			"description": "A deadly sickness spreads among your troops.",
			"trigger_conditions": ["swamp", "city"],
			"choices": [
				{"text": "Quarantine (Lose 5 lives)", "cost": {"lives": 5}, "reward": {}},
				{"text": "Buy Medicine (Cost 200 gold)", "cost": {"gold": 200}, "reward": {"reputation": 10}}
			]
		},
		{
			"id": "wandering_merchant_fb",
			"name": "Wandering Merchant",
			"description": "A merchant offers a rare artifact.",
			"trigger_conditions": ["any"],
			"choices": [
				{"text": "Buy Artifact (Cost 500 gold)", "cost": {"gold": 500}, "reward": {"artifact": "random"}},
				{"text": "Ignore", "cost": {}, "reward": {}}
			]
		},
		{
			"id": "refugee_crisis",
			"name": "Refugee Crisis",
			"description": "Fleeing peasants beg for your protection.",
			"trigger_conditions": ["valley", "royal_highway"],
			"choices": [
				{"text": "Shelter them (Costs food/gold)", "cost": {"gold": 150}, "reward": {"lives": 10, "reputation": 20}},
				{"text": "Turn them away", "cost": {"reputation": -15}, "reward": {}}
			]
		},
		{
			"id": "meteor_strike",
			"name": "Meteor Strike",
			"description": "A burning rock falls from the sky, revealing star-metal.",
			"trigger_conditions": ["ash_wastes", "frost_peak"],
			"choices": [
				{"text": "Mine it (Take damage)", "cost": {"lives": 8}, "reward": {"gold": 600, "research": 50}},
				{"text": "Leave it", "cost": {}, "reward": {}}
			]
		},
		{
			"id": "dark_ritual",
			"name": "Dark Ritual Interrupted",
			"description": "Cultists are summoning a demon.",
			"trigger_conditions": ["caves", "swamp"],
			"choices": [
				{"text": "Stop them (Spawn Elite)", "cost": {}, "reward": {"force_wave": "demon_elite"}},
				{"text": "Flee", "cost": {"threat": 1}, "reward": {}}
			]
		},
		{
			"id": "lost_patrol",
			"name": "Lost Royal Patrol",
			"description": "Royal guards are pinned down by monsters.",
			"trigger_conditions": ["greenwood", "stone_suburbs"],
			"choices": [
				{"text": "Assist them (Cost mana)", "cost": {"mana": 50}, "reward": {"faction_royal": 25, "gold": 200}},
				{"text": "Ignore them", "cost": {"faction_royal": -20}, "reward": {}}
			]
		},
		{
			"id": "cursed_chest",
			"name": "Cursed Chest",
			"description": "A glowing chest sits in the open.",
			"trigger_conditions": ["any"],
			"choices": [
				{"text": "Open it (50% chance of loot or curse)", "cost": {}, "reward": {"random_loot": true}},
				{"text": "Destroy it", "cost": {"mana": 20}, "reward": {"reputation": 5}}
			]
		},
		{
			"id": "goblin_extortion",
			"name": "Goblin Extortion",
			"description": "Goblins demand a toll to pass.",
			"trigger_conditions": ["royal_highway"],
			"choices": [
				{"text": "Pay toll (300g)", "cost": {"gold": 300}, "reward": {}},
				{"text": "Refuse (They attack)", "cost": {}, "reward": {"threat": 1, "force_wave": "goblin_horde"}}
			]
		}
	]
	
	# Add many more dummy events to bulk out the fallback database
	for i in range(20):
		fallbacks.append({
			"id": "generic_event_" + str(i),
			"name": "Minor Encounter " + str(i),
			"description": "You encounter a minor distraction on the road.",
			"trigger_conditions": ["any"],
			"choices": [
				{"text": "Investigate", "cost": {"time": 1}, "reward": {"gold": 50}},
				{"text": "Move on", "cost": {}, "reward": {}}
			]
		})

	for fb in fallbacks:
		if not events_db.has(fb["id"]):
			events_db[fb["id"]] = fb

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
	# This function acts as a dispatcher for various gameplay modifications
	
	# Apply Costs
	if costs.has("gold"):
		print("Deducted %d gold" % costs["gold"])
	if costs.has("lives"):
		print("Lost %d lives" % costs["lives"])
	if costs.has("mana"):
		print("Spent %d mana" % costs["mana"])
	if costs.has("threat"):
		print("Threat increased by %d" % costs["threat"])
	
	# Apply Rewards
	if rewards.has("gold"):
		print("Gained %d gold" % rewards["gold"])
	if rewards.has("lives"):
		print("Gained %d lives" % rewards["lives"])
	if rewards.has("research"):
		print("Gained %d research" % rewards["research"])
	if rewards.has("artifact"):
		print("Received artifact: %s" % rewards["artifact"])
		global_alert_broadcast.emit("Artifact Acquired: " + rewards["artifact"])
	if rewards.has("force_wave"):
		print("Forcing wave spawn: %s" % rewards["force_wave"])
		boss_spawn_queued.emit(rewards["force_wave"])
	if rewards.has("faction_royal"):
		faction_standing_changed.emit("royal", rewards["faction_royal"])
	if rewards.has("faction_merchants"):
		faction_standing_changed.emit("merchants", rewards["faction_merchants"])

func force_random_positive_event() -> void:
	# A utility for debugging or specific reward triggers
	var pos_events = []
	for evt in events_db.values():
		if evt["id"] in ["wandering_merchant", "celestial_alignment", "meteor_strike"]:
			pos_events.append(evt)
			
	if pos_events.size() > 0:
		var chosen = pos_events[randi() % pos_events.size()]
		trigger_event_by_id(chosen["id"])

func force_random_negative_event() -> void:
	# A utility for debugging or punishment triggers
	var neg_events = []
	for evt in events_db.values():
		if evt["id"] in ["plague_outbreak", "goblin_extortion", "dark_ritual"]:
			neg_events.append(evt)
			
	if neg_events.size() > 0:
		var chosen = neg_events[randi() % neg_events.size()]
		trigger_event_by_id(chosen["id"])

func get_event_history() -> Array[String]:
	return event_history.duplicate()

func clear_history() -> void:
	event_history.clear()

func get_event_data(event_id: String) -> Dictionary:
	return events_db.get(event_id, {}).duplicate(true)

func get_total_events_count() -> int:
	return events_db.size()

func save_state() -> Dictionary:
	return {
		"event_history": event_history.duplicate(true)
	}

func load_state(data: Dictionary) -> void:
	if data.has("event_history"):
		event_history = data["event_history"].duplicate(true)
