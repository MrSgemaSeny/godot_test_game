class_name CombatBalanceSimulator
extends RefCounted

## Симулятор баланса и тестирования проходимости (Фаза 9)
## Моделирует математический исход волн без рендера, вычисляет TTK и эффективность башен

static func simulate_wave(wave_data: Dictionary, towers_data: Array[Dictionary], enemies_db: Dictionary) -> Dictionary:
	var total_monster_hp: float = 0.0
	var enemy_count: int = 0
	
	for group in wave_data.get("spawn_groups", []):
		var e_type = group.get("enemy_type", "grunt")
		var count = int(group.get("count", 1))
		var e_info = enemies_db.get(e_type, {})
		var hp = float(e_info.get("health", 100.0))
		total_monster_hp += hp * count
		enemy_count += count
		
	# Calculate total tower DPS
	var total_tower_dps: float = 0.0
	for t in towers_data:
		var dmg = float(t.get("damage", 10.0))
		var rate = float(t.get("fire_rate", 1.0))
		total_tower_dps += dmg * rate
		
	var estimated_clear_time = 0.0
	var is_winnable = true
	
	if total_tower_dps > 0.0:
		estimated_clear_time = total_monster_hp / total_tower_dps
	else:
		is_winnable = false
		
	# If clear time exceeds 60 seconds for a normal wave, mark as extreme difficulty
	var difficulty_rating = clamp(estimated_clear_time / 45.0, 0.1, 5.0)
	
	return {
		"winnable": is_winnable and (estimated_clear_time < 90.0),
		"total_hp": total_monster_hp,
		"enemy_count": enemy_count,
		"total_dps": total_tower_dps,
		"estimated_ttk": estimated_clear_time,
		"difficulty_rating": difficulty_rating
	}

static func run_full_campaign_simulation(waves_list: Array, towers_comp: Array[Dictionary], enemies_db: Dictionary) -> Dictionary:
	var results: Array[Dictionary] = []
	var passed_waves = 0
	
	for w in waves_list:
		var sim = simulate_wave(w, towers_comp, enemies_db)
		results.append(sim)
		if sim.get("winnable", false):
			passed_waves += 1
			
	return {
		"total_waves": waves_list.size(),
		"cleared_waves": passed_waves,
		"is_campaign_beatable": passed_waves == waves_list.size(),
		"wave_details": results
	}
