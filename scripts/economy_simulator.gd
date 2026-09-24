class_name EconomySimulator
extends RefCounted

## ==============================================================================
## Автоматизированный симулятор экономической модели и баланса (Раздел 38)
## Проверяет экономическую жизнеспособность, кривые дохода, проценты на депозит,
## контракты и отсутствие бесконтрольной инфляции на всех 59 стадиях кампании.
## ==============================================================================

const ARCHETYPES = {
	"greed": {
		"name": "Жадность (Greed)",
		"target_bank": 320,
		"spend_ratio": 0.45,
		"accept_contracts": true,
		"contract_risk_tolerance": "high",
		"min_defense_ratio": 0.85
	},
	"aggro": {
		"name": "Агрессия (Aggro)",
		"target_bank": 50,
		"spend_ratio": 0.90,
		"accept_contracts": true,
		"contract_risk_tolerance": "low",
		"min_defense_ratio": 1.25
	},
	"balanced": {
		"name": "Баланс (Balanced)",
		"target_bank": 180,
		"spend_ratio": 0.65,
		"accept_contracts": true,
		"contract_risk_tolerance": "medium",
		"min_defense_ratio": 1.05
	},
	"minimal_spend": {
		"name": "Минимальные траты (Budget)",
		"target_bank": 400,
		"spend_ratio": 0.30,
		"accept_contracts": false,
		"contract_risk_tolerance": "none",
		"min_defense_ratio": 0.70
	},
	"control": {
		"name": "Контроль / Элита (Control)",
		"target_bank": 150,
		"spend_ratio": 0.75,
		"accept_contracts": true,
		"contract_risk_tolerance": "medium",
		"min_defense_ratio": 1.15
	}
}

## Симуляция отдельной стадии кампании по выбранному архетипу
static func simulate_stage(stage_data: Dictionary, archetype_name: String = "balanced", rng_seed: int = 1234) -> Dictionary:
	var archetype = ARCHETYPES.get(archetype_name, ARCHETYPES["balanced"])
	var rng = RandomNumberGenerator.new()
	rng.seed = rng_seed
	
	var stage_id = stage_data.get("id", "c1_01")
	var chapter_num = int(stage_data.get("chapter_num", stage_data.get("chapter", 1)))
	var wave_count = int(stage_data.get("waves", stage_data.get("wave_count", 10)))
	var bonus_gold = int(stage_data.get("bonus_gold", stage_data.get("bonus_starting_gold", 0)))
	var max_tower_lvl = int(stage_data.get("max_tower_level", 3))
	
	var gold = 300 + bonus_gold
	var lives = 20
	var total_income = gold
	var total_spending = 0
	var interest_earned = 0
	var perfect_wave_bonus_total = 0
	var contract_bonus_total = 0
	var contracts_completed = 0
	var contracts_failed = 0
	var peak_gold = gold
	var lowest_gold = gold
	var towers_count = 0
	var highest_tower_lvl = 1
	var total_defense_power = 0.0
	
	# Chapter-based mechanics activation
	var interest_active = chapter_num >= 3
	var contracts_active = chapter_num >= 2 and archetype.get("accept_contracts", true)
	
	for wave in range(1, wave_count + 1):
		# 1. Pre-Wave: Contract acceptance (if active)
		var contract_accepted = false
		var contract_reward_mult = 1.0
		var contract_diff_mult = 1.0
		if contracts_active and rng.randf() < 0.65:
			contract_accepted = true
			var risk_mode = archetype.get("contract_risk_tolerance", "medium")
			match risk_mode:
				"high":
					contract_reward_mult = 1.45
					contract_diff_mult = 1.35
				"medium":
					contract_reward_mult = 1.25
					contract_diff_mult = 1.20
				_:
					contract_reward_mult = 1.15
					contract_diff_mult = 1.10

		# 2. Building / Upgrading phase before wave starts
		var target_bank = int(archetype.get("target_bank", 150))
		var spend_ratio = float(archetype.get("spend_ratio", 0.6))
		
		# Can we build or upgrade towers?
		var spendable_gold = max(0, gold - (target_bank if interest_active else 20))
		var budget = int(spendable_gold * spend_ratio)
		
		while budget >= 100:
			if towers_count < 10 and (towers_count == 0 or rng.randf() > 0.4):
				# Build new tower (cost 100)
				gold -= 100
				budget -= 100
				total_spending += 100
				towers_count += 1
				total_defense_power += 25.0
			elif towers_count > 0 and highest_tower_lvl < max_tower_lvl:
				# Upgrade tower (cost 120 - 250)
				var up_cost = 100 + highest_tower_lvl * 45
				if budget >= up_cost:
					gold -= up_cost
					budget -= up_cost
					total_spending += up_cost
					highest_tower_lvl = min(max_tower_lvl, highest_tower_lvl + 1)
					total_defense_power += 35.0 * highest_tower_lvl
				else:
					break
			else:
				break
				
		lowest_gold = min(lowest_gold, gold)
		
		# 3. Wave Combat Simulation
		var wave_required_power = (30.0 + wave * 18.0 * (1.0 + chapter_num * 0.25)) * contract_diff_mult
		var power_ratio = total_defense_power / max(1.0, wave_required_power)
		var perfect_wave = false
		
		if power_ratio >= 1.0:
			# Flawless defense
			perfect_wave = true
			if contract_accepted:
				contracts_completed += 1
		elif power_ratio >= archetype.get("min_defense_ratio", 0.8):
			# Minor breach (0-2 lives lost)
			var leak = rng.randi_range(1, 2)
			lives -= leak
			if contract_accepted:
				contracts_failed += 1
		else:
			# Significant breach
			var leak = rng.randi_range(3, 5)
			lives -= leak
			if contract_accepted:
				contracts_failed += 1
				
		if lives <= 0:
			# Defeat on this wave
			return {
				"stage_id": stage_id,
				"chapter": chapter_num,
				"archetype": archetype_name,
				"victory": false,
				"fail_wave": wave,
				"final_gold": gold,
				"peak_gold": peak_gold,
				"lowest_gold": lowest_gold,
				"total_income": total_income,
				"total_spending": total_spending,
				"interest_earned": interest_earned,
				"contracts_completed": contracts_completed,
				"towers_built": towers_count,
				"max_tower_level": highest_tower_lvl,
				"inflation_detected": false
			}

		# 4. Wave Rewards and Bounties
		var wave_clear_base = 30 + wave * 4
		var ch_mult = 1.0 + (chapter_num - 1) * 0.1
		var wave_reward = int(ceil(wave_clear_base * ch_mult * contract_reward_mult))
		gold += wave_reward
		total_income += wave_reward
		
		# Monster kill bounties for wave
		var enemy_count = 8 + wave * 2
		var avg_bounty = int(12 * (1.0 + chapter_num * 0.15))
		var wave_bounty = enemy_count * avg_bounty
		gold += wave_bounty
		total_income += wave_bounty
		
		# Perfect wave bonus
		if perfect_wave:
			var pw_bonus = 20 + wave * 2
			gold += pw_bonus
			total_income += pw_bonus
			perfect_wave_bonus_total += pw_bonus
			
		# Contract completion bonus
		if contract_accepted and perfect_wave:
			var c_bonus = int(wave_reward * 0.3)
			gold += c_bonus
			total_income += c_bonus
			contract_bonus_total += c_bonus
			
		# 5. Interest on Bank Deposit (Tiers: 0-99=0%, 100-199=5%, 200-299=10%, 300+=15% max 30)
		if interest_active:
			var rate = 0.0
			if gold >= 300: rate = 0.15
			elif gold >= 200: rate = 0.10
			elif gold >= 100: rate = 0.05
			
			var interest_amount = int(min(30, floor(gold * rate)))
			if interest_amount > 0:
				gold += interest_amount
				total_income += interest_amount
				interest_earned += interest_amount
				
		peak_gold = max(peak_gold, gold)

	# Check for uncontrolled hyperinflation: gold exceeds 6000 with low spend
	var inflation = gold > 6000 and total_spending < 1500

	return {
		"stage_id": stage_id,
		"chapter": chapter_num,
		"archetype": archetype_name,
		"victory": true,
		"fail_wave": 0,
		"final_gold": gold,
		"peak_gold": peak_gold,
		"lowest_gold": lowest_gold,
		"total_income": total_income,
		"total_spending": total_spending,
		"interest_earned": interest_earned,
		"perfect_wave_bonuses": perfect_wave_bonus_total,
		"contract_bonuses": contract_bonus_total,
		"contracts_completed": contracts_completed,
		"contracts_failed": contracts_failed,
		"towers_built": towers_count,
		"max_tower_level": highest_tower_lvl,
		"inflation_detected": inflation
	}

## Симуляция всей кампании (59 стадий) для конкретного архетипа
static func run_campaign_simulation(campaign_data: Dictionary, archetype_name: String = "balanced") -> Dictionary:
	var chapters = campaign_data.get("chapters", [])
	var total_stages = 0
	var cleared_stages = 0
	var stage_results: Array[Dictionary] = []
	var total_interest = 0
	var sum_final_gold = 0
	var inflation_events = 0
	
	for chapter in chapters:
		var stages: Array = chapter.get("maps", chapter.get("stages", []))
		var ch_cap = int(chapter.get("max_tower_level", 3))
		var ch_num = int(chapter.get("chapter_num", chapter.get("chapter", 1)))
		for stage in stages:
			total_stages += 1
			var st_copy = stage.duplicate(true)
			if not st_copy.has("max_tower_level"):
				st_copy["max_tower_level"] = ch_cap
			if not st_copy.has("chapter_num"):
				st_copy["chapter_num"] = ch_num
			var res = simulate_stage(st_copy, archetype_name, 1000 + total_stages)
			stage_results.append(res)
			if res.get("victory", false):
				cleared_stages += 1
			total_interest += int(res.get("interest_earned", 0))
			sum_final_gold += int(res.get("final_gold", 0))
			if res.get("inflation_detected", false):
				inflation_events += 1
				
	var win_rate = float(cleared_stages) / float(max(1, total_stages))
	var avg_gold = float(sum_final_gold) / float(max(1, total_stages))
	
	return {
		"archetype": archetype_name,
		"total_stages": total_stages,
		"cleared_stages": cleared_stages,
		"win_rate": win_rate,
		"average_final_gold": avg_gold,
		"total_interest_earned": total_interest,
		"inflation_free": inflation_events == 0,
		"stage_results": stage_results
	}

## Комплексный стресс-тест всех 5 экономических архетипов по 59 стадиям
static func run_multi_archetype_stress_test(campaign_data: Dictionary) -> Dictionary:
	var archetype_reports: Dictionary = {}
	var all_viable = true
	
	for arch_key in ARCHETYPES.keys():
		var report = run_campaign_simulation(campaign_data, arch_key)
		archetype_reports[arch_key] = report
		# All major archetypes should have high clear rates in campaign
		if report.get("win_rate", 0.0) < 0.70:
			all_viable = false
			
	return {
		"all_archetypes_viable": all_viable,
		"tested_archetypes": ARCHETYPES.keys().size(),
		"reports": archetype_reports
	}
