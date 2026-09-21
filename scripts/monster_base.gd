class_name MonsterBase
extends PathFollow2D

signal died(gold_reward: int)
signal girl_kidnapped(girl: Node2D)
signal escaped_with_girl()

enum MonsterState {
	ADVANCING,
	RETREATING_WITH_GIRL,
	ESCAPED
}

@export var monster_type: String = "spiky"

var max_health: float = 65.0
var current_health: float = 65.0
var base_speed: float = 95.0
var speed: float = 95.0
var armor: float = 0.0
var gold_reward: int = 8
var is_boss: bool = false
var is_flyer: bool = false
var body_color: Color = Color(0.5, 0.8, 0.1)
var body_size: float = 16.0

var current_state: MonsterState = MonsterState.ADVANCING
var carried_girl: GirlNPC = null

var slow_factor: float = 0.0
var slow_timer: float = 0.0
var freeze_timer: float = 0.0
var is_dead: bool = false
var hit_flash_timer: float = 0.0
var walk_anim: float = 0.0

func _ready() -> void:
	rotates = false
	loop = false
	_load_monster_data()
	queue_redraw()

func _load_monster_data() -> void:
	if not FileAccess.file_exists("res://data/monsters_database.json"):
		return
	var file = FileAccess.open("res://data/monsters_database.json", FileAccess.READ)
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		if json.data.has(monster_type):
			var data = json.data[monster_type]
			max_health = data.get("max_health", max_health)
			current_health = max_health
			base_speed = data.get("speed", base_speed)
			speed = base_speed
			armor = data.get("armor", armor)
			gold_reward = data.get("gold_reward", gold_reward)
			is_boss = data.get("is_boss", false)
			is_flyer = data.get("is_flyer", false)
			body_color = Color.from_string(data.get("color", "#84cc16"), body_color)
			body_size = data.get("size", body_size)

func _process(delta: float) -> void:
	if is_dead:
		return
		
	walk_anim += delta * (speed / 10.0)
	
	# Заморозка (Абсолютный ноль / Лед)
	if freeze_timer > 0.0:
		freeze_timer -= delta
		queue_redraw()
		return
		
	# Замедление
	if slow_timer > 0.0:
		slow_timer -= delta
		speed = base_speed * (1.0 - slow_factor)
		if slow_timer <= 0.0:
			slow_factor = 0.0
			speed = base_speed
	else:
		speed = base_speed
		
	if hit_flash_timer > 0.0:
		hit_flash_timer -= delta
		
	# Движение по маршруту
	if current_state == MonsterState.ADVANCING:
		progress += speed * delta
		if progress_ratio >= 1.0:
			_attempt_kidnap_girl()
	elif current_state == MonsterState.RETREATING_WITH_GIRL:
		progress -= (speed * 0.75) * delta
		if progress_ratio <= 0.005 or progress <= 10.0:
			_complete_escape_with_girl()
			
	queue_redraw()

func _attempt_kidnap_girl() -> void:
	var girls = get_tree().get_nodes_in_group("girls")
	var target_girl: GirlNPC = null
	for g in girls:
		if is_instance_valid(g) and g.current_state == GirlNPC.State.IN_VILLAGE:
			target_girl = g
			break
			
	if is_instance_valid(target_girl):
		carried_girl = target_girl
		target_girl.get_kidnapped_by(self)
		current_state = MonsterState.RETREATING_WITH_GIRL
		girl_kidnapped.emit(target_girl)
	else:
		# Если свободных девочек нет (все уже похищены)
		var gm = get_tree().get_first_node_in_group("game_manager") as GameManager
		if gm:
			gm.reduce_lives(1)
		is_dead = true
		queue_free()

func _complete_escape_with_girl() -> void:
	if is_dead:
		return
	is_dead = true
	current_state = MonsterState.ESCAPED
	if is_instance_valid(carried_girl):
		carried_girl.escaped_with_monster.emit(carried_girl)
		carried_girl.queue_free()
		carried_girl = null
		
	var gm = get_tree().get_first_node_in_group("game_manager") as GameManager
	if gm:
		gm.reduce_lives(1)
	escaped_with_girl.emit()
	queue_free()

func take_damage(amount: float, damage_type: String = "physical") -> void:
	if is_dead:
		return
		
	var actual_damage = amount
	if damage_type == "physical":
		var damage_reduction = clamp(armor / 100.0, 0.0, 0.85)
		actual_damage = amount * (1.0 - damage_reduction)
		
	current_health -= actual_damage
	hit_flash_timer = 0.1
	queue_redraw()
	
	if current_health <= 0.0:
		_die()

func apply_slow(factor: float, duration: float) -> void:
	if is_dead:
		return
	slow_factor = max(slow_factor, clamp(factor, 0.1, 0.95))
	slow_timer = max(slow_timer, duration)

func apply_freeze(duration: float) -> void:
	if is_dead:
		return
	freeze_timer = max(freeze_timer, duration)

func heal(amount: float) -> void:
	if is_dead:
		return
	current_health = min(max_health, current_health + amount)
	queue_redraw()

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	
	# Если нес девочку — отпускаем её домой
	if is_instance_valid(carried_girl):
		carried_girl._start_running_home()
		carried_girl = null
		
	# Добавляем ману игроку за убийство
	var spell_sys = get_tree().get_first_node_in_group("spell_system")
	if spell_sys and spell_sys.has_method("add_mana"):
		spell_sys.add_mana(5 if is_boss else 2)
		
	died.emit(gold_reward)
	queue_free()

func _draw() -> void:
	var bounce = sin(walk_anim) * 2.5
	var draw_col = body_color
	
	if hit_flash_timer > 0.0:
		draw_col = Color(1.0, 1.0, 1.0)
	elif freeze_timer > 0.0:
		draw_col = Color(0.3, 0.8, 1.0)
	elif slow_timer > 0.0:
		draw_col = draw_col.lerp(Color(0.2, 0.6, 1.0), 0.5)
		
	# Тело монстра (овальное / круглое с покачиванием)
	draw_circle(Vector2(0, bounce), body_size, draw_col)
	draw_arc(Vector2(0, bounce), body_size, 0, TAU, 18, Color(0.1, 0.15, 0.1, 0.8), 2.0)
	
	# Рожки или колючки
	if monster_type == "spiky" or is_boss:
		for i in range(5):
			var angle = -PI * 0.8 + i * (PI * 0.4)
			var spike_p1 = Vector2(cos(angle), sin(angle)) * body_size + Vector2(0, bounce)
			var spike_p2 = Vector2(cos(angle), sin(angle)) * (body_size + 6.0) + Vector2(0, bounce)
			draw_line(spike_p1, spike_p2, Color(0.2, 0.4, 0.05), 2.5)
	
	# Глазки
	var eye_offset = Vector2(-4, -3 + bounce) if current_state == MonsterState.ADVANCING else Vector2(4, -3 + bounce)
	draw_circle(eye_offset + Vector2(-3, 0), body_size * 0.22, Color(1.0, 1.0, 1.0))
	draw_circle(eye_offset + Vector2(3, 0), body_size * 0.22, Color(1.0, 1.0, 1.0))
	draw_circle(eye_offset + Vector2(-2, 0), body_size * 0.1, Color(0.1, 0.1, 0.1))
	draw_circle(eye_offset + Vector2(4, 0), body_size * 0.1, Color(0.1, 0.1, 0.1))
	
	# Крылышки для летунов
	if is_flyer:
		var wing_y = -body_size + sin(walk_anim * 2.0) * 4.0
		draw_circle(Vector2(-body_size * 0.8, wing_y), 6.0, Color(0.8, 0.95, 1.0, 0.7))
		draw_circle(Vector2(body_size * 0.8, wing_y), 6.0, Color(0.8, 0.95, 1.0, 0.7))
		
	# HP Bar
	var bar_w = body_size * 2.4
	var bar_h = 4.0
	var bar_y = -body_size - 8.0 + bounce
	var bg_rect = Rect2(-bar_w / 2.0, bar_y, bar_w, bar_h)
	draw_rect(bg_rect, Color(0.1, 0.1, 0.1, 0.8))
	
	var health_ratio = clamp(current_health / max_health, 0.0, 1.0)
	var hp_color = Color(0.2, 0.9, 0.2).lerp(Color(0.9, 0.1, 0.1), 1.0 - health_ratio)
	var fg_rect = Rect2(-bar_w / 2.0, bar_y, bar_w * health_ratio, bar_h)
	draw_rect(fg_rect, hp_color)
