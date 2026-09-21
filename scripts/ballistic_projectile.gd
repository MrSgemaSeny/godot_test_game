class_name BallisticProjectile
extends Node2D

var start_pos: Vector2 = Vector2.ZERO
var target_pos: Vector2 = Vector2.ZERO
var flight_duration: float = 0.6
var elapsed_time: float = 0.0
var max_arc_height: float = 65.0
var damage: float = 40.0
var damage_type: String = "physical"
var splash_radius: float = 50.0
var stun_duration: float = 0.0
var projectile_type: String = "stone"

var target_node: Node2D = null

func init_ballistic(
	p_start: Vector2,
	p_target_pos: Vector2,
	p_duration: float,
	p_damage: float,
	p_splash: float,
	p_type: String = "stone",
	p_stun: float = 0.0
) -> void:
	start_pos = p_start
	target_pos = p_target_pos
	flight_duration = p_duration
	damage = p_damage
	splash_radius = p_splash
	projectile_type = p_type
	stun_duration = p_stun
	global_position = start_pos
	queue_redraw()

func _process(delta: float) -> void:
	elapsed_time += delta
	var t = clamp(elapsed_time / flight_duration, 0.0, 1.0)
	
	# Линейное движение точки на земле
	var ground_pos = start_pos.lerp(target_pos, t)
	
	# Параболическая высота
	var height = 4.0 * max_arc_height * t * (1.0 - t)
	
	global_position = ground_pos + Vector2(0, -height)
	queue_redraw()
	
	if t >= 1.0:
		_on_impact(ground_pos)

func _on_impact(impact_pos: Vector2) -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.get("is_dead"):
			var dist = impact_pos.distance_to(enemy.global_position)
			if dist <= splash_radius:
				var falloff = 1.0 - (dist / (splash_radius * 1.5))
				enemy.take_damage(damage * max(0.4, falloff), damage_type)
				if stun_duration > 0.0 and enemy.has_method("apply_freeze"):
					enemy.apply_freeze(stun_duration)
					
	queue_free()

func _draw() -> void:
	var t = clamp(elapsed_time / flight_duration, 0.0, 1.0)
	var height = 4.0 * max_arc_height * t * (1.0 - t)
	
	# Тень на земле
	var shadow_alpha = clamp(0.6 - (height / (max_arc_height * 2.0)), 0.15, 0.6)
	draw_circle(Vector2(0, height), 6.0 + (height * 0.05), Color(0.0, 0.0, 0.0, shadow_alpha))
	
	# Сам снаряд
	if projectile_type == "cannonball":
		draw_circle(Vector2.ZERO, 7.0, Color(0.2, 0.2, 0.25))
		draw_circle(Vector2(-2, -2), 2.5, Color(0.6, 0.6, 0.65))
	else:
		# Камень из пращи
		draw_circle(Vector2.ZERO, 5.0, Color(0.5, 0.45, 0.4))
		draw_circle(Vector2(-1, -1), 2.0, Color(0.7, 0.65, 0.6))
