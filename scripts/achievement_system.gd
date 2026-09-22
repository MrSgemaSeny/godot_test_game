class_name AchievementSystem
extends Node

## Система достижений (Этап 9)
## Проверяет выполнение условий 40 достижений и начисляет очки Славы

signal achievement_unlocked(id: String, name: String, glory_reward: int)

var achievements_db: Dictionary = {}
var unlocked_achievements: Array[String] = []

func _ready() -> void:
	add_to_group("achievement_system")
	_load_achievements_db()

func _load_achievements_db() -> void:
	if not FileAccess.file_exists("res://data/achievements.json"):
		return
	var f = FileAccess.open("res://data/achievements.json", FileAccess.READ)
	var json = JSON.new()
	if json.parse(f.get_as_text()) == OK and json.data is Dictionary:
		achievements_db = json.data.duplicate(true)

func unlock_achievement(achievement_id: String) -> bool:
	if not achievements_db.has(achievement_id):
		return false
	if achievement_id in unlocked_achievements:
		return false
		
	unlocked_achievements.append(achievement_id)
	var data = achievements_db[achievement_id]
	var ach_name = str(data.get("name", achievement_id))
	var glory = int(data.get("reward_glory", 10))
	
	# Award glory points to MetaManager if in tree
	if is_inside_tree() and get_tree():
		var meta = get_tree().get_first_node_in_group("meta_manager")
		if meta and meta.has_method("add_glory"):
			meta.add_glory(glory)
			
	achievement_unlocked.emit(achievement_id, ach_name, glory)
	return true

func is_unlocked(achievement_id: String) -> bool:
	return achievement_id in unlocked_achievements

func get_unlocked_count() -> int:
	return unlocked_achievements.size()

func get_total_count() -> int:
	return achievements_db.size()
