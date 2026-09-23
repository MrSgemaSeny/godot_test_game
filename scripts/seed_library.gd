class_name SeedLibrary
extends Node

## SeedLibrary manages a curated and player-defined collection of procedural generation seeds.
## It allows saving, searching, rating, and sharing (CSV import/export) interesting seeds.

signal seed_saved(seed: int, name: String)
signal seed_removed(seed: int)

## A predefined curated list of heavily-tested, interesting seeds
const SEEDS: Dictionary = {
	"Serpentine Valley": 1337,
	"Death March": 42069,
	"Crystalmaze": 8675309,
	"The Long Winding Road": 10001,
	"Short Stop": 10002,
	"Twin Peaks": 10003,
	"Mushroom Grove": 10004,
	"Riverside Run": 10005,
	"Goblin Ambush": 10006,
	"The Gauntlet": 10007,
	"Frozen Wastes": 10008,
	"Lava Tubes": 10009,
	"City Square": 10010,
	"Spider's Nest": 10011,
	"Breezy Hills": 10012,
	"Muddy Trench": 10013,
	"Slippery Slope": 10014,
	"Dark Chasm": 10015,
	"Broken Bridge": 10016,
	"Hidden Sanctuary": 10017,
	"Desolate Path": 10018,
	"Raging River": 10019,
	"Thunder Pass": 10020,
	"Quiet Glade": 10021,
	"Mystic Ruins": 10022,
	"Lost City": 10023,
	"Abyssal Drop": 10024,
	"King's Road": 10025,
	"Overgrown Citadel": 10026
}

var player_saved_seeds: Array[Dictionary] = []

func _init() -> void:
	add_to_group("seed_library")
	
func _ready() -> void:
	_load_player_seeds()

## Saves a new seed into the player's personal library.
func save_seed(seed_val: int, name_str: String, biome: String, notes: String = "") -> void:
	# Avoid duplicates
	for s in player_saved_seeds:
		if s["seed"] == seed_val:
			s["name"] = name_str
			s["biome"] = biome
			s["notes"] = notes
			s["date_saved"] = Time.get_datetime_string_from_system()
			_save_player_seeds()
			seed_saved.emit(seed_val, name_str)
			return
			
	player_saved_seeds.append({
		"seed": seed_val,
		"name": name_str,
		"biome": biome,
		"date_saved": Time.get_datetime_string_from_system(),
		"star_rating": 0,
		"notes": notes
	})
	_save_player_seeds()
	seed_saved.emit(seed_val, name_str)

## Removes a seed from the player's personal library.
func remove_saved_seed(seed_val: int) -> void:
	for i in range(player_saved_seeds.size()):
		if player_saved_seeds[i]["seed"] == seed_val:
			player_saved_seeds.remove_at(i)
			_save_player_seeds()
			seed_removed.emit(seed_val)
			return

## Returns a combined list of both curated and player saved seeds in a uniform format.
func get_all_seeds() -> Array[Dictionary]:
	var combined: Array[Dictionary] = []
	for k in SEEDS.keys():
		combined.append({
			"seed": SEEDS[k],
			"name": k,
			"biome": "any",
			"date_saved": "Curated",
			"star_rating": 5, # Curated are implicitly 5 star
			"notes": "Curated Developer Seed",
			"is_curated": true
		})
	for p in player_saved_seeds:
		var pd = p.duplicate()
		pd["is_curated"] = false
		combined.append(pd)
	return combined

## Searches both curated and player saved seeds by partial name match.
func search_seeds(query: String) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var q_lower = query.to_lower()
	var all_seeds = get_all_seeds()
	for s in all_seeds:
		if q_lower in s["name"].to_lower() or (s.has("notes") and q_lower in s["notes"].to_lower()):
			results.append(s)
	return results

## Picks a random seed from the curated list.
func get_random_curated() -> Dictionary:
	var keys = SEEDS.keys()
	if keys.is_empty():
		return {}
	var random_key = keys[randi() % keys.size()]
	return {
		"name": random_key,
		"seed": SEEDS[random_key],
		"biome": "any",
		"is_curated": true
	}

## Picks a consistent seed for the day from the curated list, based on the current date.
func get_daily_seed_entry() -> Dictionary:
	var dt = Time.get_datetime_dict_from_system()
	var day_val = dt["year"] + dt["month"] * 31 + dt["day"]
	var keys = SEEDS.keys()
	if keys.is_empty():
		return {}
	var daily_key = keys[day_val % keys.size()]
	return {
		"name": daily_key,
		"seed": SEEDS[daily_key],
		"biome": "any",
		"is_curated": true
	}

## Rates a saved seed from 1 to 5 stars.
func rate_seed(seed_val: int, stars: int) -> void:
	var clamped_stars = clamp(stars, 1, 5)
	for s in player_saved_seeds:
		if s["seed"] == seed_val:
			s["star_rating"] = clamped_stars
			_save_player_seeds()
			return

## Gets the top rated seeds from the combined library.
func get_top_rated(count: int = 10) -> Array[Dictionary]:
	var all_seeds = get_all_seeds()
	all_seeds.sort_custom(func(a, b): return a.get("star_rating", 0) > b.get("star_rating", 0))
	var top: Array[Dictionary] = []
	for i in range(min(count, all_seeds.size())):
		top.append(all_seeds[i])
	return top

## Exports the player's saved seeds to a CSV string.
func export_seed_list() -> String:
	var csv = "seed,name,biome,star_rating,notes\n"
	for s in player_saved_seeds:
		var safe_name = s["name"].replace(",", ";")
		var safe_biome = s["biome"].replace(",", ";")
		var safe_notes = s["notes"].replace(",", ";")
		csv += "%d,%s,%s,%d,%s\n" % [s["seed"], safe_name, safe_biome, s.get("star_rating", 0), safe_notes]
	return csv

## Imports a CSV string of seeds, adding them to the player's library.
func import_seed_list(csv: String) -> int:
	var lines = csv.split("\n")
	var imported_count = 0
	
	for i in range(1, lines.size()): # Skip header
		var line = lines[i].strip_edges()
		if line.is_empty(): continue
		var cols = line.split(",")
		if cols.size() >= 3:
			var s_val = cols[0].to_int()
			var s_name = cols[1]
			var s_biome = cols[2]
			var s_stars = 0
			if cols.size() >= 4: s_stars = cols[3].to_int()
			var s_notes = ""
			if cols.size() >= 5: s_notes = cols[4]
			
			save_seed(s_val, s_name, s_biome, s_notes)
			rate_seed(s_val, s_stars)
			imported_count += 1
			
	return imported_count

## Internal method to load player seeds from user directory.
func _load_player_seeds() -> void:
	var path = "user://seed_library.json"
	if not FileAccess.file_exists(path):
		return
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			if json.data is Array:
				player_saved_seeds.clear()
				for item in json.data:
					if item is Dictionary:
						player_saved_seeds.append({
							"seed": int(item.get("seed", 0)),
							"name": str(item.get("name", "Unknown")),
							"biome": str(item.get("biome", "valley")),
							"date_saved": str(item.get("date_saved", "")),
							"star_rating": int(item.get("star_rating", 0)),
							"notes": str(item.get("notes", ""))
						})

## Internal method to save player seeds to user directory.
func _save_player_seeds() -> void:
	var path = "user://seed_library.json"
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		var json_str = JSON.stringify(player_saved_seeds, "\t")
		file.store_string(json_str)
