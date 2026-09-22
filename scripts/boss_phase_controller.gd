class_name BossPhaseController
extends RefCounted

## Контроллер фаз боссов (Этап 4)
## Управляет переходом между фазами по порогам HP, наложением щитов, призывом миньонов и берсерком

signal phase_triggered(boss: Node2D, phase_index: int, effect_type: String, effect_data: Dictionary)

var boss_node: Node2D = null
var phases: Array = []
var triggered_phases: Array[int] = []

func _init(p_boss: Node2D = null, p_phases: Array = []) -> void:
	boss_node = p_boss
	phases = p_phases.duplicate(true)
	triggered_phases.clear()

func check_phases(current_hp: float, max_hp: float) -> Array[Dictionary]:
	var triggered: Array[Dictionary] = []
	if max_hp <= 0.0 or not is_instance_valid(boss_node):
		return triggered
		
	var hp_ratio = clamp(current_hp / max_hp, 0.0, 1.0)
	
	for i in range(phases.size()):
		if i in triggered_phases:
			continue
			
		var phase = phases[i]
		if not phase is Dictionary:
			continue
			
		var threshold = float(phase.get("hp_threshold", 0.0))
		if hp_ratio <= threshold:
			triggered_phases.append(i)
			var effect = str(phase.get("effect", ""))
			_apply_phase_effect(i, effect, phase)
			triggered.append({
				"phase_index": i,
				"effect": effect,
				"data": phase
			})
			phase_triggered.emit(boss_node, i, effect, phase)
			
	return triggered

func _apply_phase_effect(phase_idx: int, effect: String, data: Dictionary) -> void:
	if not is_instance_valid(boss_node):
		return
		
	match effect:
		"gain_shield":
			var shield_amount = float(data.get("amount", 300.0))
			if "shield" in boss_node:
				boss_node.shield = float(boss_node.shield) + shield_amount
			if "max_shield" in boss_node:
				boss_node.max_shield = max(float(boss_node.max_shield), float(boss_node.shield))
				
		"berserk":
			var speed_mult = float(data.get("speed_mult", 1.5))
			if "speed" in boss_node:
				boss_node.speed = float(boss_node.speed) * speed_mult
			if "base_speed" in boss_node:
				boss_node.base_speed = float(boss_node.base_speed) * speed_mult
			if "resistances" in boss_node and data.has("damage_resist"):
				var r = float(data["damage_resist"])
				boss_node.resistances["physical"] = r
				boss_node.resistances["magic"] = r
				
		"summon_minions":
			var count = int(data.get("count", 3))
			var m_type = str(data.get("type", "grunt"))
			if boss_node.has_method("spawn_minions_around"):
				boss_node.spawn_minions_around(m_type, count)
				
		"invulnerable_burrow":
			var duration = float(data.get("duration", 3.0))
			if boss_node.has_method("enter_burrow"):
				boss_node.enter_burrow(duration)
