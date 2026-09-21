class_name GameManager
extends Node

## Сигналы для UI и игровых систем
signal gold_changed(new_gold: int)
signal lives_changed(new_lives: int)
signal wave_changed(current_wave: int, total_waves: int)
signal state_changed(new_state: int)
signal tower_selection_changed(spot: Node)
signal ability_status_changed(is_ready: bool, active: bool, time_left: float)
signal path_changed(new_path: String)

enum GameState {
	BUILDING,
	WAVE_IN_PROGRESS,
	GAME_OVER,
	VICTORY
}

const BASE_GOLD: int = 200
const BASE_LIVES: int = 20
const TOTAL_WAVES: int = 10
const PRE_WAVE_TIME: float = 30.0

var gold: int = BASE_GOLD
var lives: int = BASE_LIVES
var current_wave: int = 0
var game_state: GameState = GameState.BUILDING
var selected_spot: Node = null
var selected_path: String = "military"

var tower_data: Dictionary = {}
var enemy_data: Dictionary = {}
var waves_data: Array = []
var paths_data: Dictionary = {}

# Ультимативная способность выбранного пути
var ability_ready: bool = true
var ability_active: bool = false
var ability_timer: float = 0.0
var ability_duration: float = 10.0
var discount_active_wave: bool = false

func _enter_tree() -> void:
	add_to_group("game_manager")

func _ready() -> void:
	load_all_data()

func load_all_data() -> void:
	tower_data = _load_json("res://data/towers.json")
	enemy_data = _load_json("res://data/enemies.json")
	waves_data = _load_json_array("res://data/waves.json")
	paths_data = _load_json("res://data/paths.json")

func set_chosen_path(path_id: String) -> void:
	selected_path = path_id
	path_changed.emit(selected_path)

func reset_game() -> void:
	var bonus_gold = 0
	var bonus_lives = 0
	var start_research = 0
	
	if is_inside_tree():
		var meta = get_tree().get_first_node_in_group("meta_manager") as MetaManager
		if meta:
			bonus_gold = meta.get_starting_gold_bonus()
			bonus_lives = meta.get_bonus_lives()
			start_research = meta.get_starting_research_bonus()
			
		var tech_tree = get_tree().get_first_node_in_group("tech_tree_manager") as TechTreeManager
		if tech_tree:
			tech_tree.reset_tree(start_research)
	
	gold = BASE_GOLD + bonus_gold
	lives = BASE_LIVES + bonus_lives
	current_wave = 0
	game_state = GameState.BUILDING
	selected_spot = null
	
	ability_ready = true
	ability_active = false
	ability_timer = 0.0
	discount_active_wave = false
	
	gold_changed.emit(gold)
	lives_changed.emit(lives)
	wave_changed.emit(current_wave, TOTAL_WAVES)
	state_changed.emit(game_state)
	tower_selection_changed.emit(null)
	ability_status_changed.emit(ability_ready, ability_active, 0.0)

func _process(delta: float) -> void:
	if ability_active:
		ability_timer -= delta
		if ability_timer <= 0.0:
			ability_active = false
			ability_timer = 0.0
			ability_status_changed.emit(ability_ready, ability_active, 0.0)
		else:
			ability_status_changed.emit(ability_ready, ability_active, ability_timer)

func on_wave_started() -> void:
	# Сброс перезарядки способности на каждый новый раунд
	ability_ready = true
	discount_active_wave = false
	ability_status_changed.emit(ability_ready, ability_active, ability_timer)

func trigger_path_ability() -> bool:
	if not ability_ready or game_state != GameState.WAVE_IN_PROGRESS:
		return false
		
	ability_ready = false
	
	if selected_path == "military":
		# Режим Берсерка: x2 скорость атаки на 10 сек
		ability_active = true
		ability_timer = ability_duration
		ability_status_changed.emit(ability_ready, ability_active, ability_timer)
		return true
	elif selected_path == "magic":
		# Аркан-сеть: Заморозка всех активных орков на карте на 3 сек
		if is_inside_tree():
			var enemies = get_tree().get_nodes_in_group("enemies")
			for enemy in enemies:
				if is_instance_valid(enemy) and enemy.has_method("apply_slow"):
					enemy.apply_slow(0.95, 3.0)
		ability_status_changed.emit(ability_ready, false, 0.0)
		return true
	elif selected_path == "economy":
		# Черный рынок: +150 золота и скидка на волну
		add_gold(150)
		discount_active_wave = true
		ability_status_changed.emit(ability_ready, false, 0.0)
		return true
		
	return false

func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)

func spend_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		gold_changed.emit(gold)
		return true
	return false

func reduce_lives(amount: int = 1) -> void:
	if game_state == GameState.GAME_OVER:
		return
	lives = max(0, lives - amount)
	lives_changed.emit(lives)
	if lives <= 0:
		set_state(GameState.GAME_OVER)

func set_state(new_state: GameState) -> void:
	game_state = new_state
	state_changed.emit(game_state)

func select_spot(spot: Node) -> void:
	selected_spot = spot
	tower_selection_changed.emit(selected_spot)

func get_available_towers() -> Array:
	if paths_data.has(selected_path):
		return paths_data[selected_path].get("available_towers", ["archer"])
	return ["archer"]

func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Файл не найден: " + path)
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		return json.data
	return {}

func _load_json_array(path: String) -> Array:
	if not FileAccess.file_exists(path):
		push_error("Файл не найден: " + path)
		return []
	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Array:
		return json.data
	return []
