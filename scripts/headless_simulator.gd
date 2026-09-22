class_name HeadlessSimulator
extends RefCounted

## Симулятор баланса и проходимости волн без рендера (Этап 10)
## Автоматически проверяет баланс, time-to-kill (TTK) и проходимость волн

static func calculate_ttk(enemy_health: float, enemy_armor: float, enemy_resists: Dictionary, dps: float, damage_type: String = "physical") -> float:
	if dps <= 0.0:
		return 999999.0
		
	var actual_dps = dps
	if damage_type == "physical":
		var armor_red = clamp(enemy_armor / 100.0, 0.0, 0.85)
		actual_dps *= (1.0 - armor_red)
	elif enemy_resists.has(damage_type):
		var res = clamp(float(enemy_resists[damage_type]), -1.0, 1.0)
		actual_dps *= (1.0 - res)
		
	if actual_dps <= 0.0:
		return 999999.0
	return enemy_health / actual_dps

static func simulate_wave_winnable(wave_enemies: Array, total_tower_dps: float, path_travel_time: float) -> Dictionary:
	var total_enemy_hp = 0.0
	for e in wave_enemies:
		total_enemy_hp += float(e.get("health", 100.0))
		
	var time_required_to_kill_all = total_enemy_hp / max(1.0, total_tower_dps)
	var is_winnable = time_required_to_kill_all <= path_travel_time * 1.5
	
	return {
		"is_winnable": is_winnable,
		"total_hp": total_enemy_hp,
		"time_required": time_required_to_kill_all,
		"path_time": path_travel_time,
		"margin_ratio": path_travel_time / max(0.1, time_required_to_kill_all)
	}
