class_name EnemyBase
extends PathFollow2D

signal died(gold_reward: int)
signal reached_end()

@export var enemy_type: String = "grunt"

var max_health: float = 80.0
var current_health: float = 80.0
var base_speed: float = 85.0
var speed: float = 85.0
var armor: float = 0.0
var shield: float = 0.0
var max_shield: float = 0.0
var gold_reward: int = 10
var body_color: Color = Color(0.3, 0.5, 0.1)
var body_size: float = 18.0
var is_boss: bool = false
var regen_per_sec: float = 0.0
var heal_interval: float = 0.0
var heal_pulse_amount: float = 0.0
var heal_timer: float = 0.0
var aura_radius: float = 0.0

var slow_factor: float = 0.0
var slow_timer: float = 0.0
var is_dead: bool = false
var hit_flash_timer: float = 0.0

func _ready() -> void:
	rotates = false
	loop = false
	_apply_enemy_data()
	queue_redraw()

func _apply_enemy_data() -> void:
	var game_manager = get_tree().get_first_node_in_group("game_manager") as GameManager
	if not game_manager:
		game_manager = get_tree().root.get_node_or_null("Game/GameManager")
		
	if game_manager and game_manager.enemy_data.has(enemy_type):
		var data = game_manager.enemy_data[enemy_type]
		max_health = data.get("max_health", max_health)
		current_health = max_health
		base_speed = data.get("speed", base_speed)
		speed = base_speed
		armor = data.get("armor", armor)
		gold_reward = data.get("gold_reward", gold_reward)
		is_boss = data.get("is_boss", false)
		shield = data.get("shield", 0.0)
		max_shield = shield
		regen_per_sec = data.get("regen_per_sec", 0.0)
		heal_interval = data.get("heal_interval", 0.0)
		heal_pulse_amount = data.get("heal_pulse", 0.0)
		aura_radius = data.get("aura_radius", 0.0)
		body_color = Color.from_string(data.get("color", "#4d7c0f"), body_color)
		body_size = data.get("size", body_size)
	else:
		current_health = max_health
		speed = base_speed

func _process(delta: float) -> void:
	if is_dead:
		return
		
	# Регенерация (тролли / боссы)
	if regen_per_sec > 0.0 and current_health < max_health:
		current_health = min(max_health, current_health + regen_per_sec * delta)
		queue_redraw()
		
	# Импульс лечения шамана
	if heal_interval > 0.0:
		heal_timer -= delta
		if heal_timer <= 0.0:
			heal_timer = heal_interval
			_trigger_shaman_heal()
			
	# Аура вождя (усиление соседей)
	if aura_radius > 0.0:
		_apply_warchief_aura()

	# Обработка замедления
	if slow_timer > 0.0:
		slow_timer -= delta
		speed = base_speed * (1.0 - slow_factor)
		if slow_timer <= 0.0:
			slow_factor = 0.0
			speed = base_speed
			queue_redraw()
	else:
		speed = base_speed

	# Вспышка урона
	if hit_flash_timer > 0.0:
		hit_flash_timer -= delta
		if hit_flash_timer <= 0.0:
			queue_redraw()

	progress += speed * delta
	
	if progress_ratio >= 1.0:
		_reach_destination()

func _trigger_shaman_heal() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.get("is_dead") and enemy != self:
			if global_position.distance_to(enemy.global_position) <= 120.0:
				enemy.heal(heal_pulse_amount)

func _apply_warchief_aura() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.get("is_dead") and enemy != self:
			if global_position.distance_to(enemy.global_position) <= aura_radius:
				enemy.speed = max(enemy.speed, enemy.base_speed * 1.25)

func heal(amount: float) -> void:
	if is_dead:
		return
	current_health = min(max_health, current_health + amount)
	queue_redraw()

func take_damage(amount: float, damage_type: String = "physical") -> void:
	if is_dead:
		return
		
	var actual_damage = amount
	
	# Бонус урона по боссам от дерева технологий
	var tech = get_tree().get_first_node_in_group("tech_tree_manager") as TechTreeManager
	if is_boss and tech:
		actual_damage *= (1.0 + tech.get_boss_damage_bonus())
	
	# Сначала урон поглощается магическим щитом
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
	queue_redraw()
	
	if current_health <= 0.0:
		_die()

func apply_slow(factor: float, duration: float) -> void:
	if is_dead:
		return
	slow_factor = max(slow_factor, clamp(factor, 0.1, 0.95))
	slow_timer = max(slow_timer, duration)
	queue_redraw()

func _reach_destination() -> void:
	if is_dead:
		return
	is_dead = true
	var lives_lost = 3 if is_boss else 1
	var gm = get_tree().get_first_node_in_group("game_manager") as GameManager
	if gm:
		gm.reduce_lives(lives_lost)
	reached_end.emit()
	queue_free()

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	
	# Бонус золота от дерева исследований
	var tech = get_tree().get_first_node_in_group("tech_tree_manager") as TechTreeManager
	var reward = gold_reward
	if tech:
		reward = int(reward * (1.0 + tech.get_gold_reward_mult()))
		
	# Очки Славы за боссов
	if is_boss:
		var meta = get_tree().get_first_node_in_group("meta_manager") as MetaManager
		if meta:
			meta.add_glory(10)
			
	died.emit(reward)
	queue_free()

func _draw() -> void:
	var draw_color = body_color
	if hit_flash_timer > 0.0:
		draw_color = Color(1.0, 0.9, 0.9)
	elif slow_timer > 0.0:
		draw_color = draw_color.lerp(Color(0.2, 0.6, 1.0), 0.5)
		
	# Отрисовка тела орка
	draw_circle(Vector2.ZERO, body_size, draw_color)
	draw_arc(Vector2.ZERO, body_size, 0, TAU, 20, Color(0.1, 0.1, 0.1, 0.8), 2.0)
	
	# Глаза
	var eye_color = Color(1.0, 0.1, 0.1) if (enemy_type == "berserker" or is_boss) else Color(0.9, 0.8, 0.2)
	draw_circle(Vector2(-body_size * 0.3, -body_size * 0.2), body_size * 0.18, eye_color)
	draw_circle(Vector2(body_size * 0.3, -body_size * 0.2), body_size * 0.18, eye_color)
	
	# Корона / рога для боссов
	if is_boss:
		draw_polygon(
			PackedVector2Array([Vector2(-body_size * 0.8, -body_size * 0.7), Vector2(0, -body_size * 1.3), Vector2(body_size * 0.8, -body_size * 0.7)]),
			PackedColorArray([Color(1.0, 0.8, 0.2), Color(1.0, 0.8, 0.2), Color(1.0, 0.8, 0.2)])
		)
		
	# Магический щит
	if shield > 0.0:
		draw_arc(Vector2.ZERO, body_size + 4.0, 0, TAU, 24, Color(0.4, 0.6, 1.0, 0.9), 2.5)
	
	# HP Bar
	var bar_w = body_size * 2.4
	var bar_h = 5.0 if is_boss else 4.0
	var bar_y = -body_size - (14.0 if is_boss else 8.0)
	var bg_rect = Rect2(-bar_w / 2.0, bar_y, bar_w, bar_h)
	draw_rect(bg_rect, Color(0.1, 0.1, 0.1, 0.85))
	
	var health_ratio = clamp(current_health / max_health, 0.0, 1.0)
	var hp_color = Color(0.2, 0.85, 0.2).lerp(Color(0.9, 0.1, 0.1), 1.0 - health_ratio)
	var fg_rect = Rect2(-bar_w / 2.0, bar_y, bar_w * health_ratio, bar_h)
	draw_rect(fg_rect, hp_color)
	draw_rect(bg_rect, Color(0.0, 0.0, 0.0, 0.9), false, 1.0)
