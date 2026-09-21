class_name Projectile
extends Node2D

@export var projectile_type: String = "arrow"
@export var speed: float = 450.0
@export var damage: float = 12.0
@export var damage_type: String = "physical"
@export var slow_factor: float = 0.0
@export var slow_duration: float = 0.0
@export var splash_radius: float = 0.0
@export var max_pierce: int = 1

var target: Node2D = null
var target_pos: Vector2 = Vector2.ZERO
var lifetime: float = 3.5
var pierced_enemies: Array = []

func _ready() -> void:
	if is_instance_valid(target):
		target_pos = target.global_position
	queue_redraw()

func init_projectile(
	p_target: Node2D,
	p_speed: float,
	p_damage: float,
	p_damage_type: String,
	p_slow_factor: float = 0.0,
	p_slow_duration: float = 0.0,
	p_type: String = "arrow",
	p_splash: float = 0.0,
	p_pierce: int = 1
) -> void:
	target = p_target
	speed = p_speed
	damage = p_damage
	damage_type = p_damage_type
	slow_factor = p_slow_factor
	slow_duration = p_slow_duration
	projectile_type = p_type
	splash_radius = p_splash
	max_pierce = p_pierce
	if is_instance_valid(target):
		target_pos = target.global_position
	queue_redraw()

func _process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
		
	if is_instance_valid(target) and not target.get("is_dead"):
		target_pos = target.global_position
	
	var dir = (target_pos - global_position).normalized()
	if dir != Vector2.ZERO:
		rotation = dir.angle()
	var step = speed * delta
	
	# Проверка пробивания для стрел/болтов
	if max_pierce > 1:
		_check_pierce_collision()
		global_position += dir * step
		if global_position.distance_to(target_pos) <= step:
			if pierced_enemies.size() >= max_pierce:
				queue_free()
	else:
		if global_position.distance_to(target_pos) <= step + 10.0:
			var hit_target = target if is_instance_valid(target) else null
			_on_hit(hit_target)
		else:
			global_position += dir * step

func _check_pierce_collision() -> void:
	if not is_inside_tree():
		return
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy) and not (enemy in pierced_enemies):
			if global_position.distance_to(enemy.global_position) <= 18.0:
				pierced_enemies.append(enemy)
				_apply_hit_effect(enemy)
				if pierced_enemies.size() >= max_pierce:
					queue_free()
					return

func _on_hit(hit_target = null) -> void:
	if is_instance_valid(hit_target):
		_apply_hit_effect(hit_target)
		
	# Если есть радиус взрыва (пушка, маг льда, ловушка)
	if splash_radius > 0.0 and is_inside_tree():
		var enemies = get_tree().get_nodes_in_group("enemies")
		for enemy in enemies:
			if is_instance_valid(enemy) and enemy != hit_target:
				var dist = global_position.distance_to(enemy.global_position)
				if dist <= splash_radius:
					_apply_hit_effect(enemy, 0.6)
					
	queue_free()

func _apply_hit_effect(enemy = null, mult: float = 1.0) -> void:
	if is_instance_valid(enemy) and enemy.has_method("take_damage"):
		enemy.take_damage(damage * mult, damage_type)
		if slow_factor > 0.0 and enemy.has_method("apply_slow"):
			enemy.apply_slow(slow_factor, slow_duration)

func _draw() -> void:
	match projectile_type:
		"arrow":
			draw_line(Vector2(-10, 0), Vector2(8, 0), Color(0.6, 0.4, 0.2), 2.0)
			draw_polygon(PackedVector2Array([Vector2(8, -3), Vector2(13, 0), Vector2(8, 3)]), PackedColorArray([Color(0.85, 0.85, 0.9), Color(0.85, 0.85, 0.9), Color(0.85, 0.85, 0.9)]))
		"bolt":
			draw_line(Vector2(-14, 0), Vector2(10, 0), Color(0.8, 0.2, 0.2), 3.0)
			draw_circle(Vector2(10, 0), 3.0, Color(1.0, 0.4, 0.4))
		"cannonball":
			draw_circle(Vector2.ZERO, 7.0, Color(0.2, 0.2, 0.25))
			draw_circle(Vector2(-2, -2), 2.5, Color(0.5, 0.5, 0.55))
		"frost_bolt":
			draw_circle(Vector2.ZERO, 6.0, Color(0.2, 0.7, 1.0, 0.9))
			draw_circle(Vector2.ZERO, 3.5, Color(0.9, 0.95, 1.0))
		"soul_bolt":
			draw_circle(Vector2.ZERO, 6.0, Color(0.6, 0.1, 0.9, 0.9))
			draw_circle(Vector2.ZERO, 3.0, Color(0.9, 0.4, 1.0))
		"time_pulse":
			draw_arc(Vector2.ZERO, 10.0, 0, TAU, 16, Color(0.4, 0.4, 1.0, 0.8), 2.5)
		"bullet":
			draw_circle(Vector2.ZERO, 3.0, Color(1.0, 0.8, 0.2))
		_:
			draw_circle(Vector2.ZERO, 4.0, Color(1.0, 1.0, 0.5))
