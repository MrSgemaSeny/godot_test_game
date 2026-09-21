class_name MonsterBase
extends PathFollow2D

enum EnemyOutcome {
	KILLED,
	ESCAPED_WITH_GIRL,
	REACHED_BASE
}

signal died(gold_reward: int)
signal girl_kidnapped(girl: Node2D)
signal escaped_with_girl()
signal finished(outcome: EnemyOutcome, reward: int)
signal took_damage(amount: float, damage_type: String)
signal healed(amount: float)

enum MonsterState {
	ADVANCING,
	RETREATING_WITH_GIRL,
	FINISHED
}

@export var monster_type: String = "grunt"

var monster_name: String = "Рядовой орк"
var max_health: float = 80.0
var current_health: float = 80.0
var base_speed: float = 85.0
var speed: float = 85.0
var armor: float = 0.0
var gold_reward: int = 10
var is_boss: bool = false
var is_flyer: bool = false
var body_color: Color = Color(0.3, 0.5, 0.1)
var body_size: float = 18.0

# Способности
var heal_pulse: float = 0.0
var heal_interval: float = 0.0
var heal_timer: float = 0.0
var regen_per_sec: float = 0.0
var shield: float = 0.0
var max_shield: float = 0.0
var aura_radius: float = 0.0

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
	add_to_group("enemies")
	_load_enemy_data()
	queue_redraw()

func _load_enemy_data() -> void:
	if not FileAccess.file_exists("res://data/enemies.json"):
		return
	var file = FileAccess.open("res://data/enemies.json", FileAccess.READ)
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		var dict = json.data
		var key = monster_type
		if not dict.has(key):
			key = "grunt" # Default fallback
			
		var data = dict.get(key, {})
		monster_name = data.get("name", "Орк")
		max_health = float(data.get("max_health", 80.0))
		current_health = max_health
		base_speed = float(data.get("speed", 85.0))
		speed = base_speed
		armor = float(data.get("armor", 0.0))
		gold_reward = int(data.get("gold_reward", 10))
		is_boss = bool(data.get("is_boss", false))
		is_flyer = bool(data.get("is_flyer", false))
		body_color = Color.from_string(data.get("color", "#4d7c0f"), body_color)
		body_size = float(data.get("size", 18.0))
		
		# Специальные механики
		heal_pulse = float(data.get("heal_pulse", 0.0))
		heal_interval = float(data.get("heal_interval", 0.0))
		heal_timer = heal_interval
		regen_per_sec = float(data.get("regen_per_sec", 0.0))
		shield = float(data.get("shield", 0.0))
		max_shield = shield
		aura_radius = float(data.get("aura_radius", 0.0))

func _process(delta: float) -> void:
	if is_dead or current_state == MonsterState.FINISHED:
		return
		
	walk_anim += delta * (speed / 10.0)
	
	if freeze_timer > 0.0:
		freeze_timer -= delta
		queue_redraw()
		return
		
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
		
	# Регенерация здоровья (тролль / архимаг)
	if regen_per_sec > 0.0 and current_health < max_health:
		current_health = min(max_health, current_health + regen_per_sec * delta)
		
	# Периодическое лечение союзников (шаман)
	if heal_pulse > 0.0 and heal_interval > 0.0:
		heal_timer -= delta
		if heal_timer <= 0.0:
			heal_timer = heal_interval
			_pulse_heal_allies()
		
	if current_state == MonsterState.ADVANCING:
		progress += speed * delta
		if progress_ratio >= 1.0:
			_attempt_kidnap_girl()
	elif current_state == MonsterState.RETREATING_WITH_GIRL:
		progress -= (speed * 0.75) * delta
		if progress_ratio <= 0.005 or progress <= 10.0:
			_complete_escape_with_girl()
			
	queue_redraw()

func _pulse_heal_allies() -> void:
	var tree = get_tree()
	if not tree:
		return
	var enemies = tree.get_nodes_in_group("enemies")
	for e in enemies:
		if is_instance_valid(e) and e is MonsterBase and not e.is_dead and e != self:
			if global_position.distance_to(e.global_position) <= 150.0:
				e.heal(heal_pulse)

func _attempt_kidnap_girl() -> void:
	var tree = get_tree()
	var girls = tree.get_nodes_in_group("girls") if tree else []
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
		# Девочек больше нет в деревне — монстр проник в цитадель и наносит урон жизням
		_finish_enemy(EnemyOutcome.REACHED_BASE)

func _complete_escape_with_girl() -> void:
	_finish_enemy(EnemyOutcome.ESCAPED_WITH_GIRL)

func _finish_enemy(outcome: EnemyOutcome) -> void:
	if is_dead:
		return
	is_dead = true
	current_state = MonsterState.FINISHED
	
	match outcome:
		EnemyOutcome.KILLED:
			if is_instance_valid(carried_girl):
				carried_girl._start_running_home()
				carried_girl = null
			var spell_sys = (get_tree().get_first_node_in_group("spell_system") if is_inside_tree() and get_tree() else null)
			if spell_sys and spell_sys.has_method("add_mana"):
				spell_sys.add_mana(6 if is_boss else 2)
			died.emit(gold_reward)
			finished.emit(EnemyOutcome.KILLED, gold_reward)
			
		EnemyOutcome.ESCAPED_WITH_GIRL:
			if is_instance_valid(carried_girl):
				carried_girl.escaped_with_monster.emit(carried_girl)
				carried_girl.queue_free()
				carried_girl = null
			var gm = (get_tree().get_first_node_in_group("game_manager") as GameManager if is_inside_tree() and get_tree() else null)
			if gm:
				gm.reduce_lives(1)
			escaped_with_girl.emit()
			finished.emit(EnemyOutcome.ESCAPED_WITH_GIRL, 0)
			
		EnemyOutcome.REACHED_BASE:
			if is_instance_valid(carried_girl):
				carried_girl.queue_free()
				carried_girl = null
			var gm = (get_tree().get_first_node_in_group("game_manager") as GameManager if is_inside_tree() and get_tree() else null)
			if gm:
				gm.reduce_lives(1)
			escaped_with_girl.emit()
			finished.emit(EnemyOutcome.REACHED_BASE, 0)

			
	queue_free()

func take_damage(amount: float, damage_type: String = "physical") -> void:
	if is_dead:
		return
		
	var actual_damage = amount
	
	# Поглощение щитом
	if shield > 0.0:
		if shield >= actual_damage:
			shield -= actual_damage
			actual_damage = 0.0
		else:
			actual_damage -= shield
			shield = 0.0
			
	if actual_damage > 0.0:
		if damage_type == "physical":
			var damage_reduction = clamp(armor / 100.0, 0.0, 0.85)
			actual_damage = actual_damage * (1.0 - damage_reduction)
			
		current_health -= actual_damage
		hit_flash_timer = 0.1
		took_damage.emit(actual_damage, damage_type)
		queue_redraw()
		
		if current_health <= 0.0:
			_finish_enemy(EnemyOutcome.KILLED)

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
	healed.emit(amount)
	queue_redraw()

func _draw() -> void:
	var bounce = sin(walk_anim) * 3.0
	
	# Тень
	draw_circle(Vector2(0, body_size * 0.8), body_size * 0.85, Color(0.0, 0.0, 0.0, 0.28))
	
	var draw_col = body_color
	if hit_flash_timer > 0.0:
		draw_col = Color(1.0, 1.0, 1.0)
	elif freeze_timer > 0.0:
		draw_col = Color(0.3, 0.8, 1.0)
	elif slow_timer > 0.0:
		draw_col = draw_col.lerp(Color(0.2, 0.6, 1.0), 0.5)
		
	# Магический щит (Архимаг)
	if shield > 0.0:
		draw_arc(Vector2(0, bounce), body_size + 6.0, 0, TAU, 24, Color(0.6, 0.3, 1.0, 0.7), 2.5)
		
	# Тело орка / монстра
	draw_circle(Vector2(0, bounce), body_size, draw_col)
	draw_circle(Vector2(-body_size * 0.3, bounce - body_size * 0.3), body_size * 0.45, draw_col.lightened(0.25))
	draw_arc(Vector2(0, bounce), body_size, 0, TAU, 22, Color(0.12, 0.18, 0.1, 0.85), 2.5)
	
	# Броня для бронированных
	if armor >= 40.0:
		draw_arc(Vector2(0, bounce), body_size * 0.9, -PI * 0.7, PI * 0.7, 12, Color(0.8, 0.85, 0.9), 3.5)
		
	# Рога вождя / колючки
	if is_boss or monster_type == "grunt" or monster_type == "berserker":
		for i in range(5 if is_boss else 3):
			var angle = -PI * 0.75 + i * (PI * 0.35)
			var p1 = Vector2(cos(angle), sin(angle)) * body_size + Vector2(0, bounce)
			var p2 = Vector2(cos(angle), sin(angle)) * (body_size + (9.0 if is_boss else 5.0)) + Vector2(0, bounce)
			draw_line(p1, p2, Color(0.25, 0.15, 0.08), 3.0)
			
	if is_boss:
		# Золотая корона Вождя
		var crown_poly = PackedVector2Array([
			Vector2(-14, bounce - body_size),
			Vector2(-7, bounce - body_size - 14),
			Vector2(0, bounce - body_size - 8),
			Vector2(7, bounce - body_size - 14),
			Vector2(14, bounce - body_size)
		])
		draw_polygon(crown_poly, PackedColorArray([Color(1.0, 0.85, 0.2), Color(1.0, 0.9, 0.3), Color(1.0, 0.85, 0.2), Color(1.0, 0.9, 0.3), Color(1.0, 0.85, 0.2)]))
	
	# Глаза
	var look_dir = 1.0 if current_state == MonsterState.ADVANCING else -1.0
	var eye_center = Vector2(3.0 * look_dir, -3.0 + bounce)
	
	draw_circle(eye_center + Vector2(-4, 0), body_size * 0.24, Color(1.0, 1.0, 1.0))
	draw_circle(eye_center + Vector2(4, 0), body_size * 0.24, Color(1.0, 1.0, 1.0))
	draw_circle(eye_center + Vector2(-4 + look_dir * 1.5, 0), body_size * 0.12, Color(0.8, 0.1, 0.1) if is_boss else Color(0.1, 0.1, 0.12))
	draw_circle(eye_center + Vector2(4 + look_dir * 1.5, 0), body_size * 0.12, Color(0.8, 0.1, 0.1) if is_boss else Color(0.1, 0.1, 0.12))
	
	# HP Bar
	var bar_w = body_size * 2.4
	var bar_h = 5.0 if is_boss else 4.0
	var bar_y = -body_size - (16.0 if is_boss else 9.0) + bounce
	var bg_rect = Rect2(-bar_w / 2.0, bar_y, bar_w, bar_h)
	draw_rect(bg_rect, Color(0.1, 0.1, 0.12, 0.85))
	
	var health_ratio = clamp(current_health / max_health, 0.0, 1.0)
	var hp_color = Color(0.2, 0.9, 0.2).lerp(Color(0.95, 0.15, 0.15), 1.0 - health_ratio)
	var fg_rect = Rect2(-bar_w / 2.0, bar_y, bar_w * health_ratio, bar_h)
	draw_rect(fg_rect, hp_color)
	draw_rect(bg_rect, Color(0.0, 0.0, 0.0, 0.9), false, 1.0)

