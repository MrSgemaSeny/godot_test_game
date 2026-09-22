class_name StatusEffect
extends RefCounted

enum Type {
	BURN,
	FREEZE,
	POISON,
	STUN,
	SLOW
}

var effect_type: Type = Type.SLOW
var duration: float = 0.0
var max_duration: float = 0.0
var power: float = 0.0
var tick_interval: float = 0.5
var tick_timer: float = 0.0
var stacks: int = 1
var max_stacks: int = 3

static func type_to_string(t: Type) -> String:
	match t:
		Type.BURN: return "burn"
		Type.FREEZE: return "freeze"
		Type.POISON: return "poison"
		Type.STUN: return "stun"
		Type.SLOW: return "slow"
	return "unknown"

static func string_to_type(s: String) -> Type:
	match s.to_lower():
		"burn": return Type.BURN
		"freeze": return Type.FREEZE
		"poison": return Type.POISON
		"stun": return Type.STUN
		"slow": return Type.SLOW
	return Type.SLOW

func _init(p_type: Type = Type.SLOW, p_duration: float = 2.0, p_power: float = 1.0, p_max_stacks: int = 3, p_tick_interval: float = 0.5) -> void:
	effect_type = p_type
	duration = p_duration
	max_duration = p_duration
	power = p_power
	max_stacks = p_max_stacks
	tick_interval = p_tick_interval
	tick_timer = 0.0
	stacks = 1

func refresh_or_stack(new_duration: float, new_power: float) -> void:
	duration = max(duration, new_duration)
	if stacks < max_stacks:
		stacks += 1
		power = max(power, new_power)
	else:
		power = max(power, new_power)

func process(delta: float) -> Dictionary:
	duration -= delta
	tick_timer += delta
	var triggered_tick = false
	if tick_timer >= tick_interval:
		tick_timer -= tick_interval
		triggered_tick = true
		
	return {
		"is_expired": duration <= 0.0,
		"triggered_tick": triggered_tick,
		"type": effect_type,
		"power": power,
		"stacks": stacks
	}
