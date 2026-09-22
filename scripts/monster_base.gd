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
signal status_effect_applied(effect_type: StatusEffect.Type, stacks: int, duration: float)
signal status_effect_expired(effect_type: StatusEffect.Type)

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
var is_stealth: bool = false
var split_on_death: bool = false
var split_enemy_type: String = ""
var split_count: int = 0
var body_color: Color = Color(0.3, 0.5, 0.1)
var body_size: float = 18.0

# Resistances & Immunities
var resistances: Dictionary = {}
var immunities = []

# Modular Status Effects Container
var active_status_effects: Dictionary = {}

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

# Stage 4: Boss Phases & Special Enemy Mechanics
var burrow_timer: float = 0.0
var reflect_ratio: float = 0.0
var gold_thief_timer: float = 0.0
var boss_phase_controller = null

var slow_factor: float = 0.0
var slow_timer: float = 0.0
var freeze_timer: float = 0.0
var stun_timer: float = 0.0
var is_dead: bool = false
var hit_flash_timer: float = 0.0
var walk_anim: float = 0.0

var is_stunned: bool:
	get:
		return stun_timer > 0.0 or has_status_effect(StatusEffect.Type.STUN)

var is_frozen: bool:
	get:
		return freeze_timer > 0.0 or has_status_effect(StatusEffect.Type.FREEZE)

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
		is_stealth = bool(data.get("is_stealth", false))
		split_on_death = bool(data.get("split_on_death", false))
		split_enemy_type = str(data.get("split_enemy_type", ""))
		split_count = int(data.get("split_count", 0))
		body_color = Color.from_string(data.get("color", "#4d7c0f"), body_color)
		body_size = float(data.get("size", 18.0))
		
		# Resistances and Immunities from JSON
		if data.has("resistances") and data["resistances"] is Dictionary:
			resistances = {}
			for k in data["resistances"]:
				var r_val: float = float(data["resistances"][k])
				if is_nan(r_val) or is_inf(r_val):
					r_val = 0.0
				elif abs(r_val) >= 10.0:
					r_val = r_val / 100.0
				resistances[k] = clamp(r_val, -1.0, 1.0)
		if data.has("immunities") and data["immunities"] is Array:
			immunities = data["immunities"].duplicate()
			
		# Специальные механики
		heal_pulse = float(data.get("heal_pulse", 0.0))
		heal_interval = float(data.get("heal_interval", 0.0))
		heal_timer = heal_interval
		regen_per_sec = float(data.get("regen_per_sec", 0.0))
		shield = float(data.get("shield", 0.0))
		max_shield = shield
		aura_radius = float(data.get("aura_radius", 0.0))
		
		# Stage 4 mechanics
		reflect_ratio = float(data.get("reflect_ratio", 0.0))
		if data.has("gold_thief_timer"):
			gold_thief_timer = float(data["gold_thief_timer"])
		if data.has("phases") and data["phases"] is Array:
			var phase_script = load("res://scripts/boss_phase_controller.gd")
			if phase_script:
				boss_phase_controller = phase_script.new(self, data["phases"])

func _process(delta: float) -> void:
	if is_dead or current_state == MonsterState.FINISHED:
		return
		
	# Process modular status effects
	_process_status_effects(delta)
	if is_dead or current_state == MonsterState.FINISHED:
		return
		
	# Check complete immobilizations (freeze or stun)
	var is_frozen_now = freeze_timer > 0.0 or has_status_effect(StatusEffect.Type.FREEZE)
	var is_stunned_now = stun_timer > 0.0 or has_status_effect(StatusEffect.Type.STUN)
	
	if freeze_timer > 0.0:
		freeze_timer = max(0.0, freeze_timer - delta)
	if stun_timer > 0.0:
		stun_timer = max(0.0, stun_timer - delta)
	if burrow_timer > 0.0:
		burrow_timer = max(0.0, burrow_timer - delta)
	if gold_thief_timer > 0.0:
		gold_thief_timer = max(0.0, gold_thief_timer - delta)
		if gold_thief_timer <= 0.0:
			gold_reward = 0
		
	if is_frozen_now or is_stunned_now:
		speed = 0.0
		queue_redraw()
		return # Freezes all actions (advancing, retreating, heal pulses)
		
	# Process slow modifiers
	var eff_slow: float = 0.0
	if has_status_effect(StatusEffect.Type.SLOW):
		var s_eff = get_status_effect(StatusEffect.Type.SLOW)
		if s_eff:
			eff_slow = clamp(s_eff.power, 0.0, 0.95)
	elif slow_timer > 0.0:
		slow_timer = max(0.0, slow_timer - delta)
		eff_slow = clamp(slow_factor, 0.0, 0.95)
		if slow_timer <= 0.0:
			slow_factor = 0.0
	else:
		slow_factor = 0.0
		
	slow_factor = eff_slow
	speed = base_speed * (1.0 - slow_factor)
	walk_anim += delta * (speed / 10.0)
		
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

func _process_status_effects(delta: float) -> void:
	if active_status_effects.is_empty():
		return
		
	var expired: Array = []
	for effect_type in active_status_effects.keys():
		var effect: StatusEffect = active_status_effects.get(effect_type)
		if not effect:
			expired.append(effect_type)
			continue
			
		var res: Dictionary = effect.process(delta)
		
		# Process ticks (DoT)
		if res.get("triggered_tick", false) and not is_dead:
			var tick_dmg: float = float(res.get("power", 0.0)) * float(res.get("stacks", 1))
			match effect_type:
				StatusEffect.Type.BURN:
					take_damage(tick_dmg, "fire")
				StatusEffect.Type.POISON:
					take_damage(tick_dmg, "poison")
					
		if res.get("is_expired", false) or is_dead:
			expired.append(effect_type)
			
	for exp_type in expired:
		active_status_effects.erase(exp_type)
		if exp_type == StatusEffect.Type.SLOW:
			slow_factor = 0.0
			slow_timer = 0.0
		elif exp_type == StatusEffect.Type.FREEZE:
			freeze_timer = 0.0
		elif exp_type == StatusEffect.Type.STUN:
			stun_timer = 0.0
		status_effect_expired.emit(exp_type)
		
	if not expired.is_empty() and not is_frozen and not is_stunned:
		speed = base_speed * (1.0 - slow_factor)

func _pulse_heal_allies() -> void:
	if not is_inside_tree() or not get_tree():
		return
	var enemies = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if is_instance_valid(e) and e is MonsterBase and not e.is_dead and e != self:
			if global_position.distance_to(e.global_position) <= 150.0:
				e.heal(heal_pulse)

func _attempt_kidnap_girl() -> void:
	if not is_inside_tree() or not get_tree():
		return
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
				
			# Mana recovery from spell system
			if is_inside_tree() and get_tree():
				var spell_sys = get_tree().get_first_node_in_group("spell_system")
				if spell_sys and spell_sys.has_method("add_mana"):
					spell_sys.add_mana(6 if is_boss else 2)
					
			# Research bonus gold multiplier (econ_1: +20% gold)
			var final_gold = gold_reward
			if is_inside_tree() and get_tree():
				var tech = get_tree().get_first_node_in_group("tech_tree_manager") as TechTreeManager
				if tech and tech.has_method("get_gold_reward_mult"):
					final_gold = int(final_gold * (1.0 + tech.get_gold_reward_mult()))
					
			# Boss glory reward for meta progression
			if is_boss and is_inside_tree() and get_tree():
				var meta = get_tree().get_first_node_in_group("meta_manager") as MetaManager
				if meta and meta.has_method("add_glory"):
					meta.add_glory(10)
					
			if split_on_death and split_enemy_type != "" and split_count > 0:
				_spawn_split_children()
				
			died.emit(final_gold)
			finished.emit(EnemyOutcome.KILLED, final_gold)
			
		EnemyOutcome.ESCAPED_WITH_GIRL:
			if is_instance_valid(carried_girl):
				carried_girl.escaped_with_monster.emit(carried_girl)
				carried_girl.queue_free()
				carried_girl = null
			if is_inside_tree() and get_tree():
				var gm = get_tree().get_first_node_in_group("game_manager") as GameManager
				if gm:
					gm.reduce_lives(3 if is_boss else 1)
			escaped_with_girl.emit()
			finished.emit(EnemyOutcome.ESCAPED_WITH_GIRL, 0)
			
		EnemyOutcome.REACHED_BASE:
			if is_instance_valid(carried_girl):
				carried_girl.queue_free()
				carried_girl = null
			if is_inside_tree() and get_tree():
				var gm = get_tree().get_first_node_in_group("game_manager") as GameManager
				if gm:
					gm.reduce_lives(3 if is_boss else 1)
			escaped_with_girl.emit()
			finished.emit(EnemyOutcome.REACHED_BASE, 0)
			
	queue_free()

func calculate_actual_damage(raw_amount: float, damage_type: String = "physical") -> float:
	if raw_amount <= 0.0:
		return 0.0
		
	var d_type = damage_type.to_lower()
	
	# True damage completely bypasses armor, resistances, and immunities
	if d_type == "true":
		return raw_amount
		
	# Check immunities
	if immunities is Array:
		if d_type in immunities or "all" in immunities:
			return 0.0
	elif immunities is Dictionary:
		var imm_dict: Dictionary = immunities
		if imm_dict.get(d_type, false) or imm_dict.get("all", false):
			return 0.0
		
	var actual: float = raw_amount
	
	# Physical armor mitigation: clamp(armor / 100.0, 0.0, 0.85)
	if d_type == "physical":
		var armor_reduction = clamp(armor / 100.0, 0.0, 0.85)
		actual = actual * (1.0 - armor_reduction)
		
	# Elemental / type resistances
	if resistances is Dictionary and resistances.has(d_type):
		var raw_res = resistances[d_type]
		if raw_res != null:
			var res: float = float(raw_res)
			if is_nan(res) or is_inf(res):
				res = 0.0
			elif abs(res) >= 10.0:
				res = res / 100.0
			res = clamp(res, -1.0, 1.0)
			actual = actual * (1.0 - res)
		
	# Tech tree boss damage bonus (defense_3 gives +30% damage to bosses)
	if is_boss and is_inside_tree() and get_tree():
		var tech = get_tree().get_first_node_in_group("tech_tree_manager") as TechTreeManager
		if tech and tech.has_method("get_boss_damage_bonus"):
			actual *= (1.0 + tech.get_boss_damage_bonus())
			
	return max(0.0, actual)

func take_damage(amount: float, damage_type: String = "physical", source: Node = null) -> void:
	if is_dead or amount <= 0.0 or burrow_timer > 0.0:
		return
		
	var d_type = damage_type.to_lower()
	var actual_damage = calculate_actual_damage(amount, d_type)
	if actual_damage <= 0.0:
		return
		
	# Mirror reflect mechanic
	if reflect_ratio > 0.0 and source != null and is_instance_valid(source) and source.has_method("take_damage"):
		source.take_damage(actual_damage * reflect_ratio, "magic")
		
	# True damage completely bypasses shield barriers directly to HP
	if d_type == "true":
		current_health -= actual_damage
	else:
		var damage_to_health = actual_damage
		if shield > 0.0:
			if shield >= damage_to_health:
				shield -= damage_to_health
				damage_to_health = 0.0
			else:
				damage_to_health -= shield
				shield = 0.0
		current_health -= damage_to_health
		
	if boss_phase_controller != null and is_boss and current_health > 0.0:
		boss_phase_controller.check_phases(current_health, max_health)
		
	hit_flash_timer = 0.1
	took_damage.emit(actual_damage, damage_type)
	queue_redraw()
	
	if current_health <= 0.0:
		_finish_enemy(EnemyOutcome.KILLED)

func enter_burrow(duration: float) -> void:
	burrow_timer = max(burrow_timer, duration)

func spawn_minions_around(m_type: String, count: int) -> void:
	if not is_inside_tree() or get_parent() == null:
		return
	var par = get_parent()
	for i in range(count):
		var minion = PathFollow2D.new()
		minion.set_script(get_script())
		minion.set("monster_type", m_type)
		minion.set("progress", max(0.0, progress - (i + 1) * 15.0))
		par.add_child(minion)

func _spawn_split_children() -> void:
	if not is_inside_tree() or get_parent() == null:
		return
	spawn_minions_around(split_enemy_type, split_count)

func apply_status_effect(
	effect_type,
	duration: float,
	intensity: float = 1.0,
	max_stacks: int = 3,
	tick_interval: float = 0.5
) -> void:
	if is_dead or duration <= 0.0:
		return
		
	var typed_effect: StatusEffect.Type
	if typeof(effect_type) == TYPE_STRING:
		typed_effect = StatusEffect.string_to_type(effect_type)
	else:
		typed_effect = effect_type as StatusEffect.Type
		
	var type_str = StatusEffect.type_to_string(typed_effect)
	if immunities is Array:
		if type_str in immunities or str(typed_effect) in immunities or "all" in immunities:
			return
	elif immunities is Dictionary:
		var imm_dict: Dictionary = immunities
		if imm_dict.get(type_str, false) or imm_dict.get(typed_effect, false) or imm_dict.get("all", false):
			return
		
	if active_status_effects.has(typed_effect):
		var effect = active_status_effects[typed_effect] as StatusEffect
		if effect:
			effect.max_stacks = max_stacks
			effect.refresh_or_stack(duration, intensity)
	else:
		var effect = StatusEffect.new(typed_effect, duration, intensity, max_stacks, tick_interval)
		active_status_effects[typed_effect] = effect
		
	# Synchronize legacy variables for backward compatibility
	if typed_effect == StatusEffect.Type.SLOW:
		slow_factor = max(slow_factor, clamp(intensity, 0.0, 0.95))
		slow_timer = max(slow_timer, duration)
		if not is_frozen and not is_stunned:
			speed = base_speed * (1.0 - slow_factor)
	elif typed_effect == StatusEffect.Type.FREEZE:
		freeze_timer = max(freeze_timer, duration)
		speed = 0.0
	elif typed_effect == StatusEffect.Type.STUN:
		stun_timer = max(stun_timer, duration)
		speed = 0.0
		
	var current_stacks = active_status_effects[typed_effect].stacks if active_status_effects.has(typed_effect) else 1
	status_effect_applied.emit(typed_effect, current_stacks, duration)
	queue_redraw()

func has_status_effect(effect_type) -> bool:
	var typed = StatusEffect.string_to_type(effect_type) if typeof(effect_type) == TYPE_STRING else (effect_type as StatusEffect.Type)
	return active_status_effects.has(typed) and active_status_effects[typed].duration > 0.0

func get_status_effect(effect_type) -> StatusEffect:
	var typed = StatusEffect.string_to_type(effect_type) if typeof(effect_type) == TYPE_STRING else (effect_type as StatusEffect.Type)
	return active_status_effects.get(typed, null)

func get_status_effect_stacks(effect_type) -> int:
	var effect = get_status_effect(effect_type)
	return effect.stacks if effect else 0

func get_effective_speed() -> float:
	if is_dead or current_state == MonsterState.FINISHED:
		return 0.0
	if is_frozen or is_stunned or freeze_timer > 0.0 or stun_timer > 0.0:
		return 0.0
	var eff_slow: float = 0.0
	if has_status_effect(StatusEffect.Type.SLOW):
		var s_eff = get_status_effect(StatusEffect.Type.SLOW)
		if s_eff:
			eff_slow = clamp(s_eff.power, 0.0, 0.95)
	elif slow_timer > 0.0 or slow_factor > 0.0:
		eff_slow = clamp(slow_factor, 0.0, 0.95)
	return max(0.0, base_speed * (1.0 - eff_slow))

func remove_status_effect(effect_type) -> void:
	var typed = StatusEffect.string_to_type(effect_type) if typeof(effect_type) == TYPE_STRING else (effect_type as StatusEffect.Type)
	if active_status_effects.has(typed):
		active_status_effects.erase(typed)
		if typed == StatusEffect.Type.SLOW:
			slow_factor = 0.0
			slow_timer = 0.0
		elif typed == StatusEffect.Type.FREEZE:
			freeze_timer = 0.0
		elif typed == StatusEffect.Type.STUN:
			stun_timer = 0.0
		if not is_frozen and not is_stunned:
			speed = base_speed * (1.0 - slow_factor)
		status_effect_expired.emit(typed)
		queue_redraw()

func clear_all_status_effects() -> void:
	var keys = active_status_effects.keys()
	active_status_effects.clear()
	slow_factor = 0.0
	slow_timer = 0.0
	freeze_timer = 0.0
	stun_timer = 0.0
	speed = base_speed
	for k in keys:
		status_effect_expired.emit(k)
	queue_redraw()

func apply_slow(factor: float, duration: float) -> void:
	if is_dead:
		return
	apply_status_effect(StatusEffect.Type.SLOW, duration, factor)
	if not is_frozen and not is_stunned:
		speed = base_speed * (1.0 - slow_factor)

func apply_freeze(duration: float) -> void:
	if is_dead:
		return
	apply_status_effect(StatusEffect.Type.FREEZE, duration, 1.0)
	if is_frozen or freeze_timer > 0.0:
		speed = 0.0

func apply_stun(duration: float) -> void:
	if is_dead:
		return
	apply_status_effect(StatusEffect.Type.STUN, duration, 1.0)
	if is_stunned or stun_timer > 0.0:
		speed = 0.0

func heal(amount: float) -> void:
	if is_dead:
		return
	current_health = min(max_health, current_health + amount)
	healed.emit(amount)
	queue_redraw()

func _draw() -> void:
	var bounce = sin(walk_anim) * 3.0
	
	# Shadow
	draw_circle(Vector2(0, body_size * 0.8), body_size * 0.85, Color(0.0, 0.0, 0.0, 0.28))
	
	var draw_col = body_color
	if hit_flash_timer > 0.0:
		draw_col = Color(1.0, 1.0, 1.0)
	elif freeze_timer > 0.0 or has_status_effect(StatusEffect.Type.FREEZE):
		draw_col = Color(0.3, 0.8, 1.0)
	elif stun_timer > 0.0 or has_status_effect(StatusEffect.Type.STUN):
		draw_col = Color(1.0, 0.9, 0.3)
	elif has_status_effect(StatusEffect.Type.BURN):
		draw_col = draw_col.lerp(Color(1.0, 0.3, 0.1), 0.6)
	elif has_status_effect(StatusEffect.Type.POISON):
		draw_col = draw_col.lerp(Color(0.2, 0.8, 0.2), 0.6)
	elif slow_timer > 0.0 or has_status_effect(StatusEffect.Type.SLOW):
		draw_col = draw_col.lerp(Color(0.2, 0.6, 1.0), 0.5)
		
	# Magic Shield (Archmage / Buffs)
	if shield > 0.0:
		draw_arc(Vector2(0, bounce), body_size + 6.0, 0, TAU, 24, Color(0.6, 0.3, 1.0, 0.7), 2.5)
		
	# Body
	draw_circle(Vector2(0, bounce), body_size, draw_col)
	draw_circle(Vector2(-body_size * 0.3, bounce - body_size * 0.3), body_size * 0.45, draw_col.lightened(0.25))
	draw_arc(Vector2(0, bounce), body_size, 0, TAU, 22, Color(0.12, 0.18, 0.1, 0.85), 2.5)
	
	# Armor plates for armored units
	if armor >= 40.0:
		draw_arc(Vector2(0, bounce), body_size * 0.9, -PI * 0.7, PI * 0.7, 12, Color(0.8, 0.85, 0.9), 3.5)
		
	# Horns / Spikes
	if is_boss or monster_type == "grunt" or monster_type == "berserker":
		for i in range(5 if is_boss else 3):
			var angle = -PI * 0.75 + i * (PI * 0.35)
			var p1 = Vector2(cos(angle), sin(angle)) * body_size + Vector2(0, bounce)
			var p2 = Vector2(cos(angle), sin(angle)) * (body_size + (9.0 if is_boss else 5.0)) + Vector2(0, bounce)
			draw_line(p1, p2, Color(0.25, 0.15, 0.08), 3.0)
			
	if is_boss:
		# Golden crown for Boss
		var crown_poly = PackedVector2Array([
			Vector2(-14, bounce - body_size),
			Vector2(-7, bounce - body_size - 14),
			Vector2(0, bounce - body_size - 8),
			Vector2(7, bounce - body_size - 14),
			Vector2(14, bounce - body_size)
		])
		draw_polygon(crown_poly, PackedColorArray([Color(1.0, 0.85, 0.2), Color(1.0, 0.9, 0.3), Color(1.0, 0.85, 0.2), Color(1.0, 0.9, 0.3), Color(1.0, 0.85, 0.2)]))
	
	# Eyes
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

