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
var economic_role: String = "standard"
var banker_accumulated_gold: int = 0
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
		var raw_hp = float(data.get("max_health", 160.0))
		
		# Dynamic Health Scaling: wave, chapter, stage, contracts, nightmare, NG+
		var total_hp_mult: float = 1.0
		var wave_num: int = 1
		if is_inside_tree() and get_tree() != null:
			var gm = get_tree().get_first_node_in_group("game_manager") as GameManager
			if gm and gm.current_wave > 0:
				wave_num = gm.current_wave
		
		var cur_ch: int = 1
		var cur_st: int = 1
		if GlobalState.current_chapter > 0:
			cur_ch = GlobalState.current_chapter
		if GlobalState.current_stage > 0:
			cur_st = GlobalState.current_stage
			
		var wave_scale: float = 1.0 + float(wave_num - 1) * 0.18 + pow(float(max(0, wave_num - 1)), 1.35) * 0.03
		var ch_scale: float = 1.0 + float(cur_ch - 1) * 0.45
		var st_scale: float = 1.0 + float(cur_st - 1) * 0.04
		total_hp_mult = wave_scale * ch_scale * st_scale
		
		if is_inside_tree() and get_tree() != null:
			var econ = get_tree().get_first_node_in_group("economy_manager")
			if econ and "active_contract" in econ and not econ.active_contract.is_empty():
				var c_mods = econ.get_active_contract_modifiers()
				if c_mods.has("hp_mult"):
					total_hp_mult *= float(c_mods["hp_mult"])
					
			var nightmare = get_tree().get_first_node_in_group("nightmare_controller")
			if nightmare and nightmare.has_method("get_enemy_hp_multiplier"):
				total_hp_mult *= float(nightmare.get_enemy_hp_multiplier())
				
			var ng_ctrl = get_tree().get_first_node_in_group("ng_plus_controller")
			if ng_ctrl and ng_ctrl.has_method("get_ng_enemy_modifier"):
				var ng_mod = ng_ctrl.get_ng_enemy_modifier(monster_type)
				if ng_mod.has("hp_mult"):
					total_hp_mult *= float(ng_mod["hp_mult"])

		max_health = raw_hp * total_hp_mult
		current_health = max_health
		base_speed = float(data.get("speed", 85.0))
		speed = base_speed
		armor = float(data.get("armor", 0.0))
		gold_reward = int(data.get("gold_reward", 16))
		economic_role = str(data.get("economic_role", "boss" if bool(data.get("is_boss", false)) else "standard"))
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
					
			# Research bonus gold multiplier (econ_1: +20% gold) + Banker accumulated gold
			var final_gold = gold_reward + banker_accumulated_gold
			if is_inside_tree() and get_tree():
				var tech = get_tree().get_first_node_in_group("tech_tree_manager") as TechTreeManager
				if tech and tech.has_method("get_gold_reward_mult"):
					final_gold = int(final_gold * (1.0 + tech.get_gold_reward_mult()))
					
			# Boss glory reward for meta progression
			if is_boss and is_inside_tree() and get_tree():
				var meta = get_tree().get_first_node_in_group("meta_manager") as MetaManager
				if meta and meta.has_method("add_glory"):
					meta.add_glory(10)
					
			# Экономические роли врагов
			if is_inside_tree() and get_tree():
				# 1. Накопление золота банком-союзником поблизости (+25% за павшего рядом союзника)
				var enemies = get_tree().get_nodes_in_group("enemies")
				for other in enemies:
					if is_instance_valid(other) and other != self and other is MonsterBase and not other.is_dead:
						if other.economic_role == "banker" and global_position.distance_to(other.global_position) <= 220.0:
							other.banker_accumulated_gold += int(max(1, final_gold * 0.25))
							
				# 2. EconomyManager интеграция для сборщика податей (tax collector)
				var econ = get_tree().get_first_node_in_group("economy_manager") as EconomyManager
				if econ:
					if economic_role == "tax_collector":
						econ.refund_stolen_gold(final_gold)
					
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
				var econ = get_tree().get_first_node_in_group("economy_manager") as EconomyManager
				if econ:
					if economic_role == "thief":
						econ.register_gold_stolen(0.04)
					if gm:
						econ.register_life_lost(gm.lives)
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
				var econ = get_tree().get_first_node_in_group("economy_manager") as EconomyManager
				if econ:
					if economic_role == "thief":
						econ.register_gold_stolen(0.04)
					if gm:
						econ.register_life_lost(gm.lives)
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
		took_damage.emit(0.0, "blocked")
		hit_flash_timer = 0.05
		queue_redraw()
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
	var bs = body_size

	# --- Determine render color with status effects ---
	var draw_col = body_color
	if hit_flash_timer > 0.0:
		draw_col = Color(1.0, 1.0, 1.0, 0.95)
	elif freeze_timer > 0.0 or has_status_effect(StatusEffect.Type.FREEZE):
		draw_col = Color(0.3, 0.8, 1.0)
	elif stun_timer > 0.0 or has_status_effect(StatusEffect.Type.STUN):
		draw_col = Color(1.0, 0.9, 0.3)
	elif has_status_effect(StatusEffect.Type.BURN):
		draw_col = draw_col.lerp(Color(1.0, 0.3, 0.1), 0.6)
	elif has_status_effect(StatusEffect.Type.POISON):
		draw_col = draw_col.lerp(Color(0.2, 0.8, 0.2), 0.6)
	elif slow_timer > 0.0 or has_status_effect(StatusEffect.Type.SLOW):
		draw_col = draw_col.lerp(Color(0.2, 0.6, 1.0, 0.5), 0.5)

	# --- Burrow (underground = invisible) ---
	if burrow_timer > 0.0:
		draw_circle(Vector2(0, 4), bs * 0.55, Color(0.25, 0.18, 0.08, 0.35))
		_draw_hp_bar(bs, bounce)
		return

	# --- Stealth / Invisible ghost form ---
	if is_stealth or monster_type == "shadow_assassin" or monster_type == "phantom":
		var ghost_alpha = 0.38 + sin(walk_anim * 0.7) * 0.12
		draw_circle(Vector2(0, bounce), bs, Color(draw_col.r, draw_col.g, draw_col.b, ghost_alpha))
		draw_arc(Vector2(0, bounce), bs, 0, TAU, 20, Color(0.8, 0.6, 1.0, ghost_alpha * 1.6), 2.0)
		# Ghost wisp tail
		for i in range(3):
			var wy = bounce + bs * 0.5 + i * 6.0
			draw_circle(Vector2(0, wy), bs * (0.35 - i * 0.08), Color(0.85, 0.7, 1.0, ghost_alpha * 0.7))
		# Eyes glow
		draw_circle(Vector2(-4, bounce - 2), bs * 0.18, Color(1.0, 0.2, 1.0, 0.9))
		draw_circle(Vector2(4, bounce - 2), bs * 0.18, Color(1.0, 0.2, 1.0, 0.9))
		_draw_hp_bar(bs, bounce)
		return

	# --- Flying enemies (bats, dragons, etc.) ---
	if is_flyer:
		var wing_flap = sin(walk_anim * 2.5) * 0.3
		var w_col_dark = draw_col.darkened(0.3)
		var w_col_mid = draw_col.darkened(0.15)
		w_col_dark.a = 0.85
		w_col_mid.a = 0.7
		# Wing left
		var wl = PackedVector2Array([
			Vector2(0, bounce),
			Vector2(-bs * 1.8 - sin(walk_anim) * 4.0, bounce - bs * (0.8 + wing_flap)),
			Vector2(-bs * 0.7, bounce + bs * 0.3)
		])
		draw_polygon(wl, PackedColorArray([w_col_dark, w_col_mid, w_col_dark]))
		# Wing right
		var wr = PackedVector2Array([
			Vector2(0, bounce),
			Vector2(bs * 1.8 + sin(walk_anim) * 4.0, bounce - bs * (0.8 + wing_flap)),
			Vector2(bs * 0.7, bounce + bs * 0.3)
		])
		draw_polygon(wr, PackedColorArray([w_col_dark, w_col_mid, w_col_dark]))
		# Body core (bat/dragon)
		draw_circle(Vector2(0, bounce), bs * 0.7, draw_col)
		draw_arc(Vector2(0, bounce), bs * 0.7, 0, TAU, 18, draw_col.darkened(0.4), 2.0)
		# Eyes
		draw_circle(Vector2(-bs * 0.22, bounce - bs * 0.12), bs * 0.18, Color(1.0, 0.15, 0.15))
		draw_circle(Vector2(bs * 0.22, bounce - bs * 0.12), bs * 0.18, Color(1.0, 0.15, 0.15))
		_draw_hp_bar(bs, bounce)
		return


	# --- BOSS rendering ---
	if is_boss:
		# Shadow
		draw_circle(Vector2(3, bs + 4), bs * 1.1, Color(0, 0, 0, 0.3))
		# Outer glow aura
		var glow_r = bs + 6.0 + sin(walk_anim * 1.2) * 2.0
		draw_arc(Vector2(0, bounce), glow_r, 0, TAU, 32, Color(0.9, 0.3, 0.1, 0.35), 4.0)
		# Body
		draw_circle(Vector2(0, bounce), bs, draw_col)
		draw_circle(Vector2(-bs * 0.3, bounce - bs * 0.25), bs * 0.5, draw_col.lightened(0.2))
		draw_arc(Vector2(0, bounce), bs, 0, TAU, 24, Color(0.08, 0.04, 0.02), 3.0)
		# Armor plates
		if armor >= 30.0:
			for i in range(5):
				var ang = -PI * 0.8 + i * (PI * 0.4)
				var p1 = Vector2(cos(ang), sin(ang)) * (bs * 0.7) + Vector2(0, bounce)
				var p2 = Vector2(cos(ang), sin(ang)) * (bs + 1.0) + Vector2(0, bounce)
				draw_line(p1, p2, Color(0.75, 0.8, 0.85), 4.0)
		# Boss spikes (5 big horns)
		for i in range(5):
			var ang = -PI * 0.85 + i * (PI * 0.42)
			var p1 = Vector2(cos(ang), sin(ang)) * bs + Vector2(0, bounce)
			var p2 = Vector2(cos(ang), sin(ang)) * (bs + 13.0) + Vector2(0, bounce)
			draw_line(p1, p2, Color(0.22, 0.10, 0.05), 4.5)
		# Golden crown
		var crown_y = bounce - bs - 2.0
		var crown_pts = PackedVector2Array([
			Vector2(-14, crown_y),
			Vector2(-10, crown_y - 10),
			Vector2(-5, crown_y - 5),
			Vector2(0, crown_y - 16),
			Vector2(5, crown_y - 5),
			Vector2(10, crown_y - 10),
			Vector2(14, crown_y)
		])
		draw_polyline(crown_pts, Color(1.0, 0.85, 0.15), 3.5)
		draw_polyline(crown_pts, Color(1.0, 0.95, 0.5, 0.5), 1.5)
		# Crown gems
		draw_circle(Vector2(0, crown_y - 14), 3.5, Color(0.95, 0.15, 0.15))
		draw_circle(Vector2(-10, crown_y - 9), 2.5, Color(0.15, 0.5, 0.95))
		draw_circle(Vector2(10, crown_y - 9), 2.5, Color(0.95, 0.6, 0.15))
		# Boss eyes (larger, red)
		var look_dir = 1.0 if current_state == MonsterState.ADVANCING else -1.0
		var eye_y = bounce - bs * 0.2
		draw_circle(Vector2(-bs * 0.28 + look_dir, eye_y), bs * 0.3, Color(1.0, 1.0, 1.0))
		draw_circle(Vector2(bs * 0.28 + look_dir, eye_y), bs * 0.3, Color(1.0, 1.0, 1.0))
		draw_circle(Vector2(-bs * 0.28 + look_dir * 2.5, eye_y), bs * 0.15, Color(0.9, 0.05, 0.05))
		draw_circle(Vector2(bs * 0.28 + look_dir * 2.5, eye_y), bs * 0.15, Color(0.9, 0.05, 0.05))
		# Shield barrier ring
		if shield > 0.0:
			draw_arc(Vector2(0, bounce), bs + 8.0, 0, TAU, 24, Color(0.55, 0.25, 0.95, 0.8), 3.0)
		_draw_hp_bar(bs, bounce)
		return

	# --- Per monster_type distinct shapes ---
	# Shadow
	draw_circle(Vector2(2, bs * 0.8), bs * 0.85, Color(0.0, 0.0, 0.0, 0.25))

	
	var m_lower = monster_type.to_lower()
	if "slime" in m_lower or "lurker" in m_lower or "leech" in m_lower:
		# Slimes (wobbling jelly body, floating nuclei, translucent outer rim)
		var wobble_x = sin(walk_anim * 3.0) * bs * 0.2
		var wobble_y = cos(walk_anim * 4.0) * bs * 0.1
		draw_circle(Vector2(wobble_x, bounce + wobble_y), bs * 1.1, Color(draw_col.r, draw_col.g, draw_col.b, 0.6))
		draw_circle(Vector2(-wobble_x*0.5, bounce - wobble_y*0.5), bs * 0.4, draw_col.darkened(0.2))
		draw_circle(Vector2(wobble_x*0.3, bounce + wobble_y*0.8), bs * 0.2, draw_col.lightened(0.2))
		_draw_hp_bar(bs, bounce)
		return
	elif "treant" in m_lower or "sapling" in m_lower or "spriggan" in m_lower or "ent" in m_lower or "guardian" in m_lower:
		# Treants & Plants (wooden bark texture, leafy crests, glowing branch eyes, thorns)
		draw_circle(Vector2(0, bounce), bs * 0.9, Color(0.4, 0.25, 0.1))
		draw_circle(Vector2(0, bounce - bs * 0.8), bs * 0.6, Color(0.1, 0.5, 0.1, 0.8))
		draw_circle(Vector2(-bs*0.4, bounce - bs * 0.5), bs * 0.4, Color(0.1, 0.6, 0.1, 0.8))
		draw_circle(Vector2(bs*0.4, bounce - bs * 0.5), bs * 0.4, Color(0.1, 0.6, 0.1, 0.8))
		draw_circle(Vector2(-bs*0.2, bounce - bs*0.1), bs*0.15, Color(1.0, 0.8, 0.2))
		draw_circle(Vector2(bs*0.2, bounce - bs*0.1), bs*0.15, Color(1.0, 0.8, 0.2))
		_draw_hp_bar(bs, bounce)
		return
	elif "hydra" in m_lower or "serpent" in m_lower:
		# Hydras & Serpents (undulating serpentine segments, dual or triple heads)
		for i in range(4):
			var seg_x = sin(walk_anim * 2.0 - i * 0.5) * bs * 0.5
			draw_circle(Vector2(seg_x, bounce + i * bs * 0.4), bs * (0.8 - i*0.1), draw_col.darkened(i*0.1))
		draw_circle(Vector2(sin(walk_anim*2.0)*bs*0.5 - bs*0.3, bounce - bs*0.5), bs*0.4, draw_col)
		draw_circle(Vector2(sin(walk_anim*2.0)*bs*0.5 + bs*0.3, bounce - bs*0.5), bs*0.4, draw_col)
		_draw_hp_bar(bs, bounce)
		return
	elif "golem" in m_lower or "titan" in m_lower or "ram" in m_lower or "crusher" in m_lower:
		# Golems & Titans (faceted heavy stone/crystal polygons, runic cracks, heavy shoulder pauldrons)
		var pts = PackedVector2Array([
			Vector2(-bs, bounce - bs), Vector2(bs, bounce - bs),
			Vector2(bs*1.2, bounce), Vector2(bs*0.8, bounce + bs),
			Vector2(-bs*0.8, bounce + bs), Vector2(-bs*1.2, bounce)
		])
		draw_polygon(pts, PackedColorArray([draw_col, draw_col, draw_col, draw_col, draw_col, draw_col]))
		draw_polyline(pts, Color(0.8, 0.8, 0.8), 2.0)
		draw_circle(Vector2(-bs*0.8, bounce-bs), bs*0.5, draw_col.darkened(0.2))
		draw_circle(Vector2(bs*0.8, bounce-bs), bs*0.5, draw_col.darkened(0.2))
		_draw_hp_bar(bs, bounce)
		return
	elif "drake" in m_lower or "wurm" in m_lower or "harpy" in m_lower:
		# Drakes, Wyrms & Harpies (flapping wings, fire/frost breath trails, barbed tails)
		var wing_y = sin(walk_anim * 4.0) * bs * 0.5
		var wl = PackedVector2Array([Vector2(0, bounce), Vector2(-bs*2.0, bounce + wing_y - bs*0.5), Vector2(-bs, bounce + wing_y + bs*0.5)])
		var wr = PackedVector2Array([Vector2(0, bounce), Vector2(bs*2.0, bounce + wing_y - bs*0.5), Vector2(bs, bounce + wing_y + bs*0.5)])
		draw_polygon(wl, PackedColorArray([draw_col.darkened(0.3), draw_col.darkened(0.3), draw_col.darkened(0.3)]))
		draw_polygon(wr, PackedColorArray([draw_col.darkened(0.3), draw_col.darkened(0.3), draw_col.darkened(0.3)]))
		draw_circle(Vector2(0, bounce), bs * 0.7, draw_col)
		_draw_hp_bar(bs, bounce)
		return
	elif "elemental" in m_lower or "imp" in m_lower or "juggernaut" in m_lower or "behemoth" in m_lower:
		# Elementals (swirling core with orbiting fragments)
		draw_circle(Vector2(0, bounce), bs * 0.6, draw_col)
		for i in range(5):
			var ang = walk_anim * 3.0 + i * (TAU / 5.0)
			var px = cos(ang) * bs * 1.2
			var py = sin(ang) * bs * 1.2 + bounce
			draw_circle(Vector2(px, py), bs * 0.3, draw_col.lightened(0.4))
		_draw_hp_bar(bs, bounce)
		return
	elif "beetle" in m_lower or "carapace" in m_lower or "scarab" in m_lower or "bug" in m_lower:
		# 2.5D Тяжелый бронированный жук-панцирник
		var look_dir = 1.0 if current_state == MonsterState.ADVANCING else -1.0
		var ch_dark = Color(0.22, 0.12, 0.05)
		var ch_mid = draw_col
		var ch_highlight = Color(0.85, 0.65, 0.35)
		
		# Шесть суставчатых лапок жука в ракурсе
		for leg_i in range(3):
			var leg_stride = sin(walk_anim * 3.5 + leg_i * 1.5) * 4.0
			var lx = (-bs * 0.4 + leg_i * (bs * 0.4))
			draw_line(Vector2(lx, bounce), Vector2(lx - bs * 0.7, bounce - 5.0 + leg_stride), ch_dark, 2.5)
			draw_line(Vector2(lx - bs * 0.7, bounce - 5.0 + leg_stride), Vector2(lx - bs * 0.9, bounce + 6.0 + leg_stride), ch_dark, 2.0)
			draw_line(Vector2(lx, bounce), Vector2(lx + bs * 0.7, bounce - 5.0 - leg_stride), ch_dark, 2.5)
			draw_line(Vector2(lx + bs * 0.7, bounce - 5.0 - leg_stride), Vector2(lx + bs * 0.9, bounce + 6.0 - leg_stride), ch_dark, 2.0)
			
		# Куполообразный толстый хитиновый панцирь
		var shell_pts = PackedVector2Array([
			Vector2(-bs * 0.85, bounce + 2), Vector2(-bs * 0.6, bounce - bs * 0.8),
			Vector2(bs * 0.6, bounce - bs * 0.8), Vector2(bs * 0.85, bounce + 2),
			Vector2(bs * 0.5, bounce + bs * 0.7), Vector2(-bs * 0.5, bounce + bs * 0.7)
		])
		draw_colored_polygon(shell_pts, ch_mid)
		draw_polyline(shell_pts, ch_dark, 2.0)
		
		# Броневые щитки и центральный шов
		draw_line(Vector2(0, bounce - bs * 0.8), Vector2(0, bounce + bs * 0.7), ch_dark, 2.5)
		draw_line(Vector2(-bs * 0.6, bounce - bs * 0.2), Vector2(bs * 0.6, bounce - bs * 0.2), ch_dark, 1.8)
		draw_line(Vector2(-bs * 0.35, bounce - bs * 0.65), Vector2(-bs * 0.1, bounce - bs * 0.65), ch_highlight, 1.5)
		
		# Голова с клешнями-жвалами
		var head_x = bs * 0.75 * look_dir
		var head_pos = Vector2(head_x, bounce - 2)
		draw_circle(head_pos, bs * 0.35, ch_dark)
		draw_line(head_pos + Vector2(0, -3), head_pos + Vector2(7 * look_dir, -6), ch_highlight, 2.2)
		draw_line(head_pos + Vector2(0, 3), head_pos + Vector2(7 * look_dir, 6), ch_highlight, 2.2)
		# Глаза
		draw_circle(head_pos + Vector2(2 * look_dir, -3), 1.8, Color(1.0, 0.15, 0.2))
		draw_circle(head_pos + Vector2(2 * look_dir, 3), 1.8, Color(1.0, 0.15, 0.2))
		
		_draw_hp_bar(bs, bounce)
		return
	elif "crab" in m_lower or "crawler" in m_lower or "angler" in m_lower or "spider" in m_lower:
		# Crustaceans & Insects
		draw_circle(Vector2(0, bounce), bs * 0.8, draw_col)
		for i in range(3):
			var leg_ang = PI/4 + i * 0.2
			draw_line(Vector2(0, bounce), Vector2(cos(leg_ang)*bs*1.5, bounce + sin(leg_ang)*bs*1.5), draw_col.darkened(0.4), 3.0)
			draw_line(Vector2(0, bounce), Vector2(-cos(leg_ang)*bs*1.5, bounce + sin(leg_ang)*bs*1.5), draw_col.darkened(0.4), 3.0)
		_draw_hp_bar(bs, bounce)
		return
	elif "void" in m_lower or "stellar" in m_lower or "shifter" in m_lower or "horror" in m_lower or "anomaly" in m_lower:
		# Void Entities
		draw_circle(Vector2(0, bounce), bs * 0.9, Color(0, 0, 0))
		draw_arc(Vector2(0, bounce), bs * 1.1, 0, TAU, 24, Color(0.6, 0.1, 0.8, 0.8), 3.0)
		for i in range(4):
			var ang = walk_anim * 2.0 + i * (TAU/4.0)
			draw_line(Vector2(0, bounce), Vector2(cos(ang)*bs*1.5, bounce + sin(ang)*bs*1.5), Color(0.5, 0.0, 0.7), 2.0)
		_draw_hp_bar(bs, bounce)
		return
	elif "knight" in m_lower or "praetorian" in m_lower or "inquisitor" in m_lower or "archon" in m_lower or "templar" in m_lower or "dreadnought" in m_lower or "chariot" in m_lower or "outrider" in m_lower:
		# Armored Knights & Praetorians
		draw_rect(Rect2(-bs*0.6, bounce - bs, bs*1.2, bs*2.0), Color(0.7, 0.7, 0.75))
		draw_circle(Vector2(0, bounce - bs*1.2), bs*0.5, Color(0.6, 0.6, 0.65))
		draw_line(Vector2(-bs*0.2, bounce - bs*1.2), Vector2(bs*0.2, bounce - bs*1.2), Color(0, 1, 1), 3.0) # Visor
		draw_rect(Rect2(bs*0.6, bounce - bs*0.2, bs*0.8, bs*1.2), Color(0.2, 0.2, 0.8)) # Shield
		_draw_hp_bar(bs, bounce)
		return
	elif "wolf" in m_lower or "boar" in m_lower or "hound" in m_lower or "panther" in m_lower:
		# Beasts & Wolves
		draw_circle(Vector2(0, bounce), bs * 0.8, draw_col)
		draw_circle(Vector2(bs*0.8, bounce - bs*0.3), bs * 0.5, draw_col)
		draw_line(Vector2(bs*1.2, bounce - bs*0.3), Vector2(bs*1.5, bounce + bs*0.2), Color(1,1,1), 2.0) # Fang
		draw_line(Vector2(-bs*0.8, bounce), Vector2(-bs*1.5, bounce - bs*0.5), draw_col.darkened(0.2), 4.0) # Tail
		_draw_hp_bar(bs, bounce)
		return

	match monster_type:


		"berserker":
			# Big red beefy orc – wider, angrier
			draw_circle(Vector2(0, bounce), bs * 1.05, draw_col)
			# Muscular shoulders
			draw_circle(Vector2(-bs * 0.75, bounce - bs * 0.1), bs * 0.42, draw_col.lightened(0.1))
			draw_circle(Vector2(bs * 0.75, bounce - bs * 0.1), bs * 0.42, draw_col.lightened(0.1))
			draw_arc(Vector2(0, bounce), bs * 1.05, 0, TAU, 20, draw_col.darkened(0.5), 2.5)
			# 3 rage horns
			for i in range(3):
				var ang = -PI * 0.6 + i * (PI * 0.6)
				var p1 = Vector2(cos(ang), sin(ang)) * bs + Vector2(0, bounce)
				var p2 = Vector2(cos(ang), sin(ang)) * (bs + 9.0) + Vector2(0, bounce)
				draw_line(p1, p2, Color(0.6, 0.1, 0.0), 3.5)
			# Angry slash scar
			draw_line(Vector2(-bs * 0.35, bounce - bs * 0.35), Vector2(bs * 0.25, bounce + bs * 0.05), Color(0.8, 0.1, 0.1, 0.9), 2.5)

		"shaman":
			# Purple-robed shaman – tall narrow oval with staff
			draw_circle(Vector2(0, bounce), bs * 0.75, draw_col)  # robe body
			# Staff (left side)
			draw_line(Vector2(-bs * 0.6, bounce + bs * 0.9), Vector2(-bs * 0.6, bounce - bs * 1.3), Color(0.6, 0.4, 0.15), 3.0)
			# Staff orb
			draw_circle(Vector2(-bs * 0.6, bounce - bs * 1.3), 5.0, Color(0.6, 0.15, 0.95, 0.9))
			draw_circle(Vector2(-bs * 0.6, bounce - bs * 1.3), 3.0, Color(0.95, 0.6, 1.0))
			# Headdress
			var head_pts = PackedVector2Array([
				Vector2(-bs * 0.5, bounce - bs),
				Vector2(0, bounce - bs - 12),
				Vector2(bs * 0.5, bounce - bs)
			])
			draw_polygon(head_pts, PackedColorArray([draw_col.lightened(0.3), draw_col.lightened(0.5), draw_col.lightened(0.3)]))
			# Rune markings
			draw_arc(Vector2(0, bounce), bs * 0.55, -PI * 0.6, PI * 0.6, 12, Color(0.9, 0.6, 1.0, 0.7), 2.0)

		"troll":
			# Giant moss-green troll – huge, lumbering
			var troll_col = Color(0.2, 0.55, 0.15)
			draw_circle(Vector2(0, bounce + 4), bs * 1.25, troll_col)  # big body
			# Stone armor chunks
			draw_arc(Vector2(0, bounce + 4), bs * 1.1, -PI * 0.5, PI * 0.5, 10, Color(0.5, 0.5, 0.45), 4.5)
			draw_arc(Vector2(0, bounce + 4), bs * 0.9, 0, TAU, 18, troll_col.darkened(0.35), 2.0)
			# 2 short wide horns
			for i in range(2):
				var ang = -PI * 0.45 + i * (PI * 0.9)
				var p1 = Vector2(cos(ang), sin(ang)) * bs * 1.2 + Vector2(0, bounce + 4)
				var p2 = Vector2(cos(ang), sin(ang)) * (bs * 1.2 + 7.0) + Vector2(0, bounce + 4)
				draw_line(p1, p2, Color(0.55, 0.45, 0.2), 5.0)
			# Regen sparkle
			if regen_per_sec > 0.0:
				var sp = sin(walk_anim * 3.0)
				draw_circle(Vector2(bs * 0.6, bounce - bs * 0.3), 3.5 + sp * 1.0, Color(0.3, 1.0, 0.5, 0.7))

		"necromancer":
			# Dark mage skull robe
			var nc = Color(0.1, 0.05, 0.2)
			draw_circle(Vector2(0, bounce), bs * 0.8, nc)
			draw_arc(Vector2(0, bounce), bs * 0.8, 0, TAU, 18, Color(0.5, 0.1, 0.9, 0.8), 2.5)
			# Bone staff
			draw_line(Vector2(bs * 0.55, bounce + bs * 0.9), Vector2(bs * 0.55, bounce - bs * 1.2), Color(0.88, 0.88, 0.78), 2.5)
			draw_circle(Vector2(bs * 0.55, bounce - bs * 1.2), 4.5, Color(0.9, 0.85, 0.75))
			draw_circle(Vector2(bs * 0.55, bounce - bs * 1.2), 2.5, Color(0.1, 0.0, 0.1))
			# Floating skulls
			for i in range(2):
				var ang = walk_anim * 0.8 + i * PI
				var sp = Vector2(cos(ang) * bs * 1.1, sin(ang) * bs * 0.5 + bounce)
				draw_circle(sp, 4.0, Color(0.88, 0.85, 0.78, 0.85))
				draw_circle(sp + Vector2(-1.5, 0), 1.2, Color(0.05, 0.05, 0.05))
				draw_circle(sp + Vector2(1.5, 0), 1.2, Color(0.05, 0.05, 0.05))

		"spider":
			# Spider with 8 legs
			var sp_col = Color(0.12, 0.08, 0.05)
			# Legs (4 per side)
			for i in range(4):
				var leg_y = bounce - bs * 0.3 + i * (bs * 0.2)
				var leg_len = bs * 1.4 - i * (bs * 0.1)
				draw_line(Vector2(0, leg_y), Vector2(-leg_len, leg_y - 3.0), sp_col, 2.5)
				draw_line(Vector2(0, leg_y), Vector2(leg_len, leg_y - 3.0), sp_col, 2.5)
			# Body
			draw_circle(Vector2(0, bounce), bs * 0.75, draw_col)
			# Abdomen (rear)
			draw_circle(Vector2(0, bounce + bs * 0.9), bs * 0.6, draw_col.darkened(0.2))
			draw_arc(Vector2(0, bounce + bs * 0.9), bs * 0.6, 0, TAU, 14, sp_col, 1.5)
			# Fang eyes cluster
			for i in range(4):
				var ex = -bs * 0.3 + i * (bs * 0.2)
				draw_circle(Vector2(ex, bounce - bs * 0.2), bs * 0.1, Color(0.9, 0.15, 0.15))

		"archmage":
			# Archmage in shimmering robe + shield ring
			var am_col = Color(0.1, 0.2, 0.7)
			draw_circle(Vector2(0, bounce), bs * 0.72, am_col)
			# Animated shield ring
			var shield_ang = walk_anim * 1.5
			for i in range(6):
				var sa = shield_ang + i * (TAU / 6.0)
				var sp = Vector2(cos(sa), sin(sa)) * (bs + 7.0) + Vector2(0, bounce)
				draw_circle(sp, 3.2, Color(0.35, 0.65, 1.0, 0.85))
			# Staff
			draw_line(Vector2(-bs * 0.5, bounce + bs * 0.8), Vector2(-bs * 0.5, bounce - bs * 1.1), Color(0.7, 0.6, 0.3), 2.5)
			draw_circle(Vector2(-bs * 0.5, bounce - bs * 1.1), 5.5, Color(0.2, 0.5, 1.0, 0.9))
			draw_circle(Vector2(-bs * 0.5, bounce - bs * 1.1), 3.0, Color(0.8, 0.95, 1.0))
			# Robe shimmer lines
			for i in range(3):
				var ry = bounce - bs * 0.3 + i * (bs * 0.3)
				draw_line(Vector2(-bs * 0.5, ry), Vector2(bs * 0.5, ry), Color(0.4, 0.6, 1.0, 0.4), 1.5)

		_:
			# 2.5D БОЕВОЙ ОРК (Grunt / Soldier / Heavy и базовые типы)
			var look_dir = 1.0 if current_state == MonsterState.ADVANCING else -1.0
			var leg_stride = sin(walk_anim * 3.0) * (bs * 0.4)
			var skin_dark = draw_col.darkened(0.28)
			var skin_light = draw_col.lightened(0.18)
			var leather = Color(0.35, 0.22, 0.12)
			var iron = Color(0.45, 0.48, 0.52)
			var iron_dark = Color(0.22, 0.24, 0.26)
			
			# 1. Шагающие ноги в кожано-стальных поножах
			draw_circle(Vector2(-bs * 0.35 + leg_stride, bounce + bs * 0.75), bs * 0.25, leather)
			draw_circle(Vector2(bs * 0.35 - leg_stride, bounce + bs * 0.75), bs * 0.25, leather)
			
			# 2. Могучий торс в стеганом дублете с ремнями
			var torso = PackedVector2Array([
				Vector2(-bs * 0.65, bounce - bs * 0.2), Vector2(bs * 0.65, bounce - bs * 0.2),
				Vector2(bs * 0.45, bounce + bs * 0.65), Vector2(-bs * 0.45, bounce + bs * 0.65)
			])
			draw_colored_polygon(torso, draw_col)
			# Кожаный ремень с железной пряжкой
			draw_line(Vector2(-bs * 0.45, bounce + bs * 0.45), Vector2(bs * 0.45, bounce + bs * 0.45), leather, 2.8)
			draw_rect(Rect2(-2.5, bounce + bs * 0.45 - 2.5, 5, 5), Color(0.85, 0.72, 0.25))
			
			# Нагрудный железный панцирь для бронированных пехотинцев
			if armor >= 20.0:
				var plate = PackedVector2Array([
					Vector2(-bs * 0.5, bounce - bs * 0.15), Vector2(bs * 0.5, bounce - bs * 0.15),
					Vector2(bs * 0.35, bounce + bs * 0.35), Vector2(-bs * 0.35, bounce + bs * 0.35)
				])
				draw_colored_polygon(plate, iron)
				draw_polyline(plate, iron_dark, 1.5)
				draw_line(Vector2(-bs * 0.5, bounce - bs * 0.15), Vector2(bs * 0.35, bounce + bs * 0.35), iron_dark, 1.2)
				
			# 3. Руки и оружие
			# Левая рука со щитом-баклером
			var shield_x = -bs * 0.7 * look_dir
			var shield_y = bounce + bs * 0.15
			draw_circle(Vector2(shield_x, shield_y), bs * 0.38, iron_dark)
			draw_circle(Vector2(shield_x, shield_y), bs * 0.25, iron)
			draw_circle(Vector2(shield_x, shield_y), bs * 0.1, Color(0.85, 0.2, 0.2)) # Умбон щита
			
			# Правая рука с занесенным боевым топором
			var arm_swing = sin(walk_anim * 3.0) * 4.0
			var axe_x = bs * 0.75 * look_dir
			var axe_y = bounce - bs * 0.1 + arm_swing
			# Топорище
			draw_line(Vector2(axe_x - 3.0 * look_dir, axe_y + 10.0), Vector2(axe_x + 5.0 * look_dir, axe_y - 12.0), leather, 2.5)
			# Зубчатое железное лезвие топора
			var blade = PackedVector2Array([
				Vector2(axe_x + 5.0 * look_dir, axe_y - 12.0),
				Vector2(axe_x + 13.0 * look_dir, axe_y - 16.0),
				Vector2(axe_x + 15.0 * look_dir, axe_y - 8.0),
				Vector2(axe_x + 10.0 * look_dir, axe_y - 5.0)
			])
			draw_colored_polygon(blade, iron)
			draw_polyline(blade, Color(0.85, 0.88, 0.92), 1.2)
			
			# Шипастые наплечники (pauldrons)
			draw_circle(Vector2(-bs * 0.6, bounce - bs * 0.2), bs * 0.3, iron_dark)
			draw_circle(Vector2(bs * 0.6, bounce - bs * 0.2), bs * 0.3, iron_dark)
			draw_circle(Vector2(-bs * 0.6, bounce - bs * 0.2), bs * 0.18, iron)
			draw_circle(Vector2(bs * 0.6, bounce - bs * 0.2), bs * 0.18, iron)
			
			# 4. Голова орка: грозная челюсть, клыки, шлем и свирепые глаза
			var head_y = bounce - bs * 0.55
			# Остроконечные уши
			draw_colored_polygon(PackedVector2Array([
				Vector2(-bs * 0.45, head_y), Vector2(-bs * 0.8, head_y - 3), Vector2(-bs * 0.4, head_y + 4)
			]), draw_col)
			draw_colored_polygon(PackedVector2Array([
				Vector2(bs * 0.45, head_y), Vector2(bs * 0.8, head_y - 3), Vector2(bs * 0.4, head_y + 4)
			]), draw_col)
			
			# Череп
			draw_circle(Vector2(0, head_y), bs * 0.48, draw_col)
			
			# Железный боевой шлем с наносником
			draw_arc(Vector2(0, head_y), bs * 0.5, PI, TAU, 14, iron_dark, 3.5)
			draw_line(Vector2(0, head_y - bs * 0.5), Vector2(0, head_y + 2), iron, 2.5)
			# Рога на шлеме
			draw_line(Vector2(-bs * 0.35, head_y - bs * 0.3), Vector2(-bs * 0.65, head_y - bs * 0.7), Color(0.85, 0.80, 0.68), 3.0)
			draw_line(Vector2(bs * 0.35, head_y - bs * 0.3), Vector2(bs * 0.65, head_y - bs * 0.7), Color(0.85, 0.80, 0.68), 3.0)
			
			# Свирепые светящиеся янтарно-красные глаза под тяжелыми надбровными дугами
			draw_line(Vector2(-bs * 0.3, head_y - 1), Vector2(-bs * 0.08, head_y + 1), iron_dark, 2.5) # Бровь левая
			draw_line(Vector2(bs * 0.3, head_y - 1), Vector2(bs * 0.08, head_y + 1), iron_dark, 2.5)  # Бровь правая
			draw_circle(Vector2(-bs * 0.18 + look_dir * 1.5, head_y + 1.5), 1.8, Color(1.0, 0.3, 0.1)) # Светящийся зрачок
			draw_circle(Vector2(bs * 0.18 + look_dir * 1.5, head_y + 1.5), 1.8, Color(1.0, 0.3, 0.1))
			draw_circle(Vector2(-bs * 0.18 + look_dir * 1.5, head_y + 1.5), 0.8, Color(1.0, 0.95, 0.4))
			draw_circle(Vector2(bs * 0.18 + look_dir * 1.5, head_y + 1.5), 0.8, Color(1.0, 0.95, 0.4))
			
			# Массивные острые клыки из нижней челюсти
			var tusk_l = PackedVector2Array([
				Vector2(-bs * 0.25, head_y + bs * 0.35), Vector2(-bs * 0.2, head_y + bs * 0.1), Vector2(-bs * 0.15, head_y + bs * 0.35)
			])
			var tusk_r = PackedVector2Array([
				Vector2(bs * 0.15, head_y + bs * 0.35), Vector2(bs * 0.2, head_y + bs * 0.1), Vector2(bs * 0.25, head_y + bs * 0.35)
			])
			draw_colored_polygon(tusk_l, Color(0.95, 0.94, 0.85))
			draw_colored_polygon(tusk_r, Color(0.95, 0.94, 0.85))

	# --- Магический щитовой барьер ---
	if shield > 0.0 and not is_boss:
		draw_arc(Vector2(0, bounce), bs + 6.0, 0, TAU, 24, Color(0.4, 0.75, 1.0, 0.8), 2.5)
		draw_arc(Vector2(0, bounce), bs + 9.0, 0, TAU, 20, Color(0.6, 0.3, 1.0, 0.4), 1.5)

	_draw_hp_bar(bs, bounce)

func _draw_hp_bar(bs: float, bounce: float) -> void:
	var bar_w = bs * 2.5
	var bar_h = 5.0 if is_boss else 4.2
	var bar_y = -bs - (18.0 if is_boss else 12.0) + bounce
	
	# Стальная рамка подложки
	var bg_frame = Rect2(-bar_w / 2.0 - 1.5, bar_y - 1.0, bar_w + 3.0, bar_h + 2.0)
	draw_rect(bg_frame, Color(0.12, 0.14, 0.16, 0.95))
	draw_rect(Rect2(-bar_w / 2.0, bar_y, bar_w, bar_h), Color(0.04, 0.04, 0.06, 0.9))
	
	# Заполнение здоровья с сочным градиентом
	var ratio = clamp(current_health / max_health, 0.0, 1.0)
	if ratio > 0.0:
		var hp_col = Color(0.15, 0.85, 0.25).lerp(Color(0.95, 0.18, 0.15), 1.0 - ratio)
		draw_rect(Rect2(-bar_w / 2.0, bar_y, bar_w * ratio, bar_h), hp_col)
		# Глянцевый блик по верхней кромке бара
		draw_line(Vector2(-bar_w / 2.0, bar_y + 0.5), Vector2(-bar_w / 2.0 + bar_w * ratio, bar_y + 0.5), Color(1.0, 1.0, 1.0, 0.45), 1.0)
		
	# Тонкая золотая окантовка для боссов
	if is_boss:
		draw_rect(bg_frame, Color(0.95, 0.80, 0.25, 0.9), false, 1.2)
	else:
		draw_rect(bg_frame, Color(0.25, 0.28, 0.32, 0.85), false, 1.0)
		
	# Индикатор щита
	if shield > 0.0 and max_shield > 0.0:
		var shld_ratio = clamp(shield / max_shield, 0.0, 1.0)
		draw_rect(Rect2(-bar_w / 2.0, bar_y - bar_h - 1.5, bar_w * shld_ratio, bar_h - 1.0), Color(0.35, 0.75, 1.0, 0.9))

	# Экономический бейдж роли (вор, банкир, сборщик, скупщик)
	if economic_role != "standard" and economic_role != "boss":
		var badge_x = bar_w / 2.0 + 4.0
		var badge_y = bar_y + bar_h / 2.0
		match economic_role:
			"thief":
				draw_circle(Vector2(badge_x, badge_y), 3.5, Color(0.8, 0.2, 0.8))
				draw_arc(Vector2(badge_x, badge_y), 3.5, 0, TAU, 10, Color(1.0, 0.8, 0.2), 1.0)
			"banker":
				draw_circle(Vector2(badge_x, badge_y), 4.0, Color(1.0, 0.85, 0.2))
				draw_arc(Vector2(badge_x, badge_y), 4.0, 0, TAU, 12, Color(0.5, 0.35, 0.05), 1.2)
			"tax_collector":
				draw_circle(Vector2(badge_x, badge_y), 4.0, Color(0.1, 0.8, 0.5))
				draw_line(Vector2(badge_x - 2, badge_y), Vector2(badge_x + 2, badge_y), Color.WHITE, 1.2)
			"miser":
				draw_circle(Vector2(badge_x, badge_y), 3.5, Color(0.2, 0.6, 0.9))


