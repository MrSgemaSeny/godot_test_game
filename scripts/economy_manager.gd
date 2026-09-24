class_name EconomyManager
extends Node

## EconomyManager — Главное ядро экономической модели TD (Переработка v2)
## Отвечает за Battle Gold, начисление наград, проценты на депозит (Interest),
## контракты риска/награды, лог транзакций и экономическую статистику.

signal gold_changed(current_gold: int, delta_amount: int, source_type: String)
signal transaction_recorded(entry: Dictionary)
signal contract_accepted(contract: Dictionary)
signal contract_completed(contract: Dictionary, bonus_gold: int)
signal contract_failed(contract: Dictionary)
signal interest_accrued(amount: int, tier_rate: float)
signal perfect_wave_rewarded(amount: int)
signal comeback_bonus_awarded(amount: int)
signal emergency_cache_triggered(amount: int)

# Валюта внутри катки
var current_gold: int = 350
var starting_gold: int = 350
var total_income: int = 0
var total_spending: int = 0

# Конфигурация экономики
var economy_data: Dictionary = {}
var interest_enabled: bool = true
var contracts_enabled: bool = true
var perfect_wave_enabled: bool = true
var base_sell_ratio: float = 0.65
var max_sell_ratio: float = 0.80

# Активный контракт на текущую волну
var active_contract: Dictionary = {}
var contract_history: Array[Dictionary] = []

# Лог транзакций для балансировки и отладки
var transaction_log: Array[Dictionary] = []
const MAX_LOG_ENTRIES: int = 1000

# Статистика экономической сессии
var stats: Dictionary = {
	"bounty_gold": 0,
	"wave_reward_gold": 0,
	"interest_gold": 0,
	"perfect_wave_gold": 0,
	"contract_gold": 0,
	"sell_return_gold": 0,
	"comeback_gold": 0,
	"emergency_gold": 0,
	"stolen_gold": 0,
	"refunded_gold": 0,
	"build_spending": 0,
	"upgrade_spending": 0,
	"sell_losses": 0,
	"peak_gold": 350,
	"lowest_gold": 350,
	"time_elapsed": 0.0,
	"bank_snapshots": []
}

# Вспомогательные таймеры
var bank_sample_timer: float = 0.0
var emergency_cache_used: bool = false
var pending_comeback_gold: int = 0

func _init() -> void:
	load_economy_config()

func _enter_tree() -> void:
	add_to_group("economy_manager")

func _ready() -> void:
	if economy_data.is_empty():
		load_economy_config()

func load_economy_config(path: String = "res://data/economy.json") -> void:
	if not FileAccess.file_exists(path):
		_init_default_economy_data()
		return
		
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var json = JSON.new()
		var err = json.parse(file.get_as_text())
		if err == OK and json.data is Dictionary:
			economy_data = json.data
			_apply_config_rules()
		else:
			_init_default_economy_data()

func _init_default_economy_data() -> void:
	economy_data = {
		"currency": "battle_gold",
		"starting_gold_default": 350,
		"sell_ratio_base": 0.65,
		"interest": {
			"enabled": true,
			"max_bonus": 30,
			"tiers": [
				{ "min_gold": 0, "max_gold": 99, "rate": 0.0 },
				{ "min_gold": 100, "max_gold": 199, "rate": 0.05 },
				{ "min_gold": 200, "max_gold": 299, "rate": 0.10 },
				{ "min_gold": 300, "max_gold": 99999, "rate": 0.15 }
			]
		},
		"wave_reward": { "base": 30, "growth_per_wave": 4 },
		"perfect_wave": { "bonus_gold_base": 20, "reward_multiplier": 1.15 }
	}
	_apply_config_rules()

func _apply_config_rules() -> void:
	base_sell_ratio = float(economy_data.get("sell_ratio_base", 0.65))
	max_sell_ratio = float(economy_data.get("sell_ratio_max", 0.80))

func initialize(start_gold_val: int = 350, chapter_num: int = 1) -> void:
	starting_gold = max(50, start_gold_val)
	current_gold = starting_gold
	total_income = starting_gold
	total_spending = 0
	emergency_cache_used = false
	pending_comeback_gold = 0
	active_contract.clear()
	contract_history.clear()
	transaction_log.clear()
	
	# Сброс статистики
	for k in stats:
		if stats[k] is int:
			stats[k] = 0
		elif stats[k] is float:
			stats[k] = 0.0
		elif stats[k] is Array:
			stats[k] = []
	stats["peak_gold"] = starting_gold
	stats["lowest_gold"] = starting_gold
	
	# Настройка правил по главам согласно разделу 21 спецификации
	apply_chapter_rules(chapter_num)
	
	_log_transaction("START_GOLD", starting_gold, "Стартовое золото катки (Глава %d)" % chapter_num)
	gold_changed.emit(current_gold, starting_gold, "start")

func apply_chapter_rules(chapter_num: int) -> void:
	match chapter_num:
		1:
			# Глава 1: Базовое золото, bounty, wave reward. Контракты и interest отключены
			contracts_enabled = false
			interest_enabled = false
			perfect_wave_enabled = true
		2:
			# Глава 2: Контракты включены, interest отключен
			contracts_enabled = true
			interest_enabled = false
			perfect_wave_enabled = true
		3, 4, 5:
			# Главы 3-5: Все экономические механизмы активны (Interest, Contracts, Perfect Wave)
			contracts_enabled = true
			interest_enabled = true
			perfect_wave_enabled = true
		_:
			contracts_enabled = true
			interest_enabled = true
			perfect_wave_enabled = true

func _process(delta: float) -> void:
	stats["time_elapsed"] = float(stats.get("time_elapsed", 0.0)) + delta
	bank_sample_timer += delta
	if bank_sample_timer >= 5.0:
		bank_sample_timer = 0.0
		var snapshots: Array = stats.get("bank_snapshots", [])
		if snapshots.size() < 200:
			snapshots.append(current_gold)

# ==============================================================================
# Основные операции с золотом
# ==============================================================================

func can_afford(cost: int) -> bool:
	return current_gold >= cost and cost >= 0

func add_gold(amount: int, source: String = "general", detail: String = "") -> void:
	if amount <= 0:
		return
	current_gold += amount
	total_income += amount
	
	if current_gold > int(stats.get("peak_gold", 0)):
		stats["peak_gold"] = current_gold
		
	# Обновление статистики по источникам
	match source:
		"bounty": stats["bounty_gold"] = int(stats.get("bounty_gold", 0)) + amount
		"wave_reward": stats["wave_reward_gold"] = int(stats.get("wave_reward_gold", 0)) + amount
		"interest": stats["interest_gold"] = int(stats.get("interest_gold", 0)) + amount
		"perfect_wave": stats["perfect_wave_gold"] = int(stats.get("perfect_wave_gold", 0)) + amount
		"contract": stats["contract_gold"] = int(stats.get("contract_gold", 0)) + amount
		"sell": stats["sell_return_gold"] = int(stats.get("sell_return_gold", 0)) + amount
		"comeback": stats["comeback_gold"] = int(stats.get("comeback_gold", 0)) + amount
		"emergency": stats["emergency_gold"] = int(stats.get("emergency_gold", 0)) + amount
		"refund": stats["refunded_gold"] = int(stats.get("refunded_gold", 0)) + amount

	_log_transaction(source.to_upper(), amount, detail)
	gold_changed.emit(current_gold, amount, source)

func spend_gold(amount: int, category: String = "build", detail: String = "") -> bool:
	if amount <= 0:
		return true
	if not can_afford(amount):
		return false
		
	current_gold -= amount
	total_spending += amount
	
	if current_gold < int(stats.get("lowest_gold", 999999)):
		stats["lowest_gold"] = current_gold
		
	match category:
		"build": stats["build_spending"] = int(stats.get("build_spending", 0)) + amount
		"upgrade": stats["upgrade_spending"] = int(stats.get("upgrade_spending", 0)) + amount
		
	_log_transaction("-" + category.to_upper(), -amount, detail)
	gold_changed.emit(current_gold, -amount, category)
	return true

# ==============================================================================
# Interest (Проценты на депозит)
# ==============================================================================

func calculate_interest(bank_amount: int = -1) -> int:
	if not interest_enabled:
		return 0
	var check_gold = current_gold if bank_amount < 0 else bank_amount
	var interest_cfg = economy_data.get("interest", {})
	if not bool(interest_cfg.get("enabled", true)):
		return 0
		
	var tiers = interest_cfg.get("tiers", [])
	var max_bonus = int(interest_cfg.get("max_bonus", 30))
	var rate: float = 0.0
	
	for tier in tiers:
		var min_g = int(tier.get("min_gold", 0))
		var max_g = int(tier.get("max_gold", 99999))
		if check_gold >= min_g and check_gold <= max_g:
			rate = float(tier.get("rate", 0.0))
			break
			
	var int_p = float(active_relic_effects.get("interest_rate_penalty", active_relic_effects.get("interest_penalty_pct", 0.0)))
	if int_p != 0.0:
		rate = max(0.0, rate + int_p)
		
	var interest_gold = int(floor(check_gold * rate))
	return int(clamp(interest_gold, 0, max_bonus))

func get_current_interest_rate() -> float:
	if not interest_enabled:
		return 0.0
	var interest_cfg = economy_data.get("interest", {})
	var tiers = interest_cfg.get("tiers", [])
	var rate: float = 0.0
	for tier in tiers:
		var min_g = int(tier.get("min_gold", 0))
		var max_g = int(tier.get("max_gold", 99999))
		if current_gold >= min_g and current_gold <= max_g:
			rate = float(tier.get("rate", 0.0))
			break
	var int_p = float(active_relic_effects.get("interest_rate_penalty", active_relic_effects.get("interest_penalty_pct", 0.0)))
	if int_p != 0.0:
		rate = max(0.0, rate + int_p)
	return rate

func apply_interest() -> int:
	if not interest_enabled:
		return 0
	var rate = get_current_interest_rate()
	var interest_amount = calculate_interest()
	if interest_amount > 0:
		add_gold(interest_amount, "interest", "Проценты на остаток (+%.0f%%)" % (rate * 100.0))
		interest_accrued.emit(interest_amount, rate)
	return interest_amount

# ==============================================================================
# Wave Rewards & Perfect Wave
# ==============================================================================

func calculate_wave_reward(wave_num: int, chapter_num: int = 1) -> int:
	var wr_cfg = economy_data.get("wave_reward", {})
	var base_r = int(wr_cfg.get("base", 30))
	var growth = int(wr_cfg.get("growth_per_wave", 4))
	var mults = wr_cfg.get("chapter_multiplier", [1.0, 1.1, 1.2, 1.3, 1.5])
	
	var ch_mult = 1.0
	var c_idx = clamp(chapter_num - 1, 0, mults.size() - 1)
	if c_idx < mults.size():
		ch_mult = float(mults[c_idx])
		
	var reward = int(ceil((base_r + wave_num * growth) * ch_mult))
	var wr_b = float(active_relic_effects.get("wave_reward_bonus", active_relic_effects.get("wave_reward_bonus_pct", 0.0)))
	if wr_b != 0.0:
		reward = int(ceil(float(reward) * (1.0 + wr_b)))
	return reward

func apply_wave_reward(wave_num: int, chapter_num: int = 1) -> int:
	var reward = calculate_wave_reward(wave_num, chapter_num)
	add_gold(reward, "wave_reward", "Награда за волну %d (Глава %d)" % [wave_num, chapter_num])
	return reward

func evaluate_perfect_wave(wave_num: int, lives_lost_this_wave: int, girls_lost: int = 0) -> int:
	if not perfect_wave_enabled:
		return 0
	if lives_lost_this_wave > 0 or girls_lost > 0:
		return 0
		
	var pw_cfg = economy_data.get("perfect_wave", {})
	var base_gold = int(pw_cfg.get("bonus_gold_base", 20))
	var growth = int(pw_cfg.get("bonus_gold_per_wave", 2))
	var bonus = base_gold + wave_num * growth
	
	add_gold(bonus, "perfect_wave", "Идеальная волна %d (0 урона базе)" % wave_num)
	perfect_wave_rewarded.emit(bonus)
	return bonus

# ==============================================================================
# Контракты (Contracts System — Раздел 3 & 10 спецификации)
# ==============================================================================

var active_relic_effects: Dictionary = {}
signal boss_reward_chosen(reward_type: String)

func apply_relic_trade_offs(relic_ids: Array) -> void:
	active_relic_effects.clear()
	var trade_offs = economy_data.get("relic_trade_offs", {})
	for r_id in relic_ids:
		var r_str = str(r_id)
		if trade_offs.has(r_str):
			var t_cfg = trade_offs[r_str]
			for k in t_cfg:
				active_relic_effects[k] = float(t_cfg[k])
				
	# Немедленный бонус / штраф к стартовому золоту
	if active_relic_effects.has("starting_gold_penalty"):
		starting_gold = max(50, starting_gold + int(active_relic_effects["starting_gold_penalty"]))
		current_gold = starting_gold
	if active_relic_effects.has("starting_gold_bonus"):
		starting_gold += int(active_relic_effects["starting_gold_bonus"])
		current_gold = starting_gold

func get_available_contracts(count: int = 2) -> Array[Dictionary]:
	if not contracts_enabled:
		return []
	var pool: Array = economy_data.get("contracts", [])
	if pool.is_empty():
		return []
		
	var available: Array[Dictionary] = []
	var pool_copy = pool.duplicate(true)
	pool_copy.shuffle()
	
	# Underdog контракт при низком балансе или критических жизнях (Раздел 24)
	var underdog_threshold = int(economy_data.get("catch_up_mechanics", {}).get("underdog_threshold_gold", 150))
	if current_gold < underdog_threshold:
		var underdog = {
			"id": "underdog_subsidy",
			"name": "🛡️ Субсидия Короны (Камбэк)",
			"description": "Помощь от короля для терпящего бедствие рубежа: враги не усилены.",
			"reward_text": "+50% золота за волну",
			"hp_mult": 1.0,
			"speed_mult": 1.0,
			"reward_mult": 1.50,
			"risk_level": "easy"
		}
		available.append(underdog)
	
	var take_count = min(count, pool_copy.size())
	for i in range(take_count):
		if available.size() >= count:
			break
		var item = pool_copy[i]
		var already_has = false
		for av in available:
			if av.get("id") == item.get("id"):
				already_has = true
				break
		if not already_has:
			available.append(item)
			
	return available

func accept_contract(contract_id: String) -> bool:
	if not contracts_enabled:
		return false
	var pool: Array = economy_data.get("contracts", [])
	var candidate: Dictionary = {}
	for c in pool:
		if c.get("id", "") == contract_id:
			candidate = c
			break
	if candidate.is_empty() and contract_id == "underdog_subsidy":
		candidate = {
			"id": "underdog_subsidy",
			"name": "🛡️ Субсидия Короны (Камбэк)",
			"description": "Помощь от короля для терпящего бедствие рубежа: враги не усилены.",
			"reward_text": "+50% золота за волну",
			"hp_mult": 1.0,
			"speed_mult": 1.0,
			"reward_mult": 1.50,
			"risk_level": "easy"
		}
		
	if not candidate.is_empty():
		active_contract = candidate.duplicate(true)
		contract_accepted.emit(active_contract)
		_log_transaction("CONTRACT_ACCEPT", 0, "Принят контракт: %s" % active_contract.get("name", ""))
		if active_contract.has("immediate_gold"):
			var imm_gold = int(active_contract["immediate_gold"])
			add_gold(imm_gold, "contract", "Аванс по контракту '%s'" % active_contract.get("name", ""))
		return true
	return false

func resolve_contract(success: bool) -> int:
	if active_contract.is_empty():
		return 0
		
	var c = active_contract.duplicate(true)
	active_contract.clear()
	
	if success:
		var mult = float(c.get("reward_mult", 1.25)) - 1.0
		var bonus_gold = int(ceil(calculate_wave_reward(1) * mult))
		if bonus_gold <= 0:
			bonus_gold = int(c.get("bonus_gold", 25))
		if bonus_gold > 0:
			add_gold(bonus_gold, "contract", "Выполнен контракт: %s" % c.get("name", ""))
		contract_history.append({"contract": c, "status": "success", "reward": bonus_gold})
		contract_completed.emit(c, bonus_gold)
		return bonus_gold
	else:
		contract_history.append({"contract": c, "status": "failed", "reward": 0})
		contract_failed.emit(c)
		_log_transaction("CONTRACT_FAIL", 0, "Провален контракт: %s" % c.get("name", ""))
		return 0

func get_active_contract_modifiers() -> Dictionary:
	if active_contract.is_empty():
		return { "hp_mult": 1.0, "speed_mult": 1.0, "bonus_armor": 0, "stealth_chance": 0.0, "kill_bounty_mult": 1.0 }
	return {
		"hp_mult": float(active_contract.get("hp_mult", 1.0)),
		"speed_mult": float(active_contract.get("speed_mult", 1.0)),
		"bonus_armor": int(active_contract.get("bonus_armor", 0)),
		"stealth_chance": float(active_contract.get("stealth_chance", 0.0)),
		"kill_bounty_mult": float(active_contract.get("kill_bounty_mult", 1.0))
	}

# ==============================================================================
# Kill Bounty и экономические роли врагов (Разделы 12 & 25)
# ==============================================================================

func calculate_kill_bounty(base_reward: int, role: String = "standard", combo_mult: float = 1.0) -> int:
	var roles_cfg = economy_data.get("economic_roles", {})
	var r_info = roles_cfg.get(role, {})
	var role_mult = float(r_info.get("bounty_mult", 1.0))
	
	# Контрактный множитель
	var contract_bounty_mult = 1.0
	if not active_contract.is_empty():
		contract_bounty_mult = float(active_contract.get("kill_bounty_mult", 1.0))
		
	var relic_bounty_mult = 1.0
	if role in ["elite", "boss"]:
		var eb = float(active_relic_effects.get("elite_bounty_bonus", active_relic_effects.get("elite_bounty_bonus_pct", 0.0)))
		relic_bounty_mult += eb
	elif role == "standard":
		var sp = float(active_relic_effects.get("standard_bounty_penalty", active_relic_effects.get("standard_bounty_penalty_pct", 0.0)))
		relic_bounty_mult += sp
		
	var final_bounty = int(ceil(base_reward * role_mult * combo_mult * contract_bounty_mult * max(0.1, relic_bounty_mult)))
	return max(1, final_bounty)

func register_enemy_kill(base_reward: int, role: String = "standard", combo_mult: float = 1.0, enemy_name: String = "") -> int:
	var bounty = calculate_kill_bounty(base_reward, role, combo_mult)
	var detail_text = enemy_name if enemy_name != "" else role
	add_gold(bounty, "bounty", detail_text)
	return bounty

func register_gold_stolen(percent: float) -> int:
	var stolen = int(ceil(current_gold * clamp(percent, 0.01, 0.20)))
	if stolen > 0 and current_gold >= stolen:
		current_gold -= stolen
		stats["stolen_gold"] = int(stats.get("stolen_gold", 0)) + stolen
		_log_transaction("THEFT", -stolen, "Вор похитил золото!")
		gold_changed.emit(current_gold, -stolen, "theft")
		return stolen
	return 0

func refund_stolen_gold(amount: int) -> int:
	var refund_mult = 1.5
	var refund = int(ceil(amount * refund_mult))
	if refund > 0:
		add_gold(refund, "refund", "Возврат похищенного золота с компенсацией (+50%)")
	return refund

# ==============================================================================
# Продажа башен (Sell Value — Раздел 15)
# ==============================================================================

func calculate_sell_value(total_invested: int, tech_bonus: float = 0.0) -> int:
	var ratio = clamp(base_sell_ratio + tech_bonus, base_sell_ratio, max_sell_ratio)
	var sell_val = int(floor(total_invested * ratio))
	return max(10, sell_val)

func register_tower_sold(total_invested: int, tech_bonus: float = 0.0, tower_name: String = "Башня") -> int:
	var sell_val = calculate_sell_value(total_invested, tech_bonus)
	var loss = total_invested - sell_val
	stats["sell_losses"] = int(stats.get("sell_losses", 0)) + loss
	add_gold(sell_val, "sell", "Продажа: %s (Вложено %d, Возврат %d)" % [tower_name, total_invested, sell_val])
	return sell_val

# ==============================================================================
# Catch-Up Mechanics (Раздел 24 спецификации)
# ==============================================================================

func register_life_lost(lives_left: int) -> int:
	var catch_cfg = economy_data.get("catch_up_mechanics", {})
	var cb_cfg = catch_cfg.get("comeback_bounty", {})
	
	if bool(cb_cfg.get("enabled", true)):
		var per_life = int(cb_cfg.get("gold_per_life_lost", 12))
		var max_cb = int(cb_cfg.get("max_comeback_gold", 60))
		var bonus = min(per_life, max_cb)
		pending_comeback_gold += bonus
		add_gold(bonus, "comeback", "Поддержка при потере жизни (+%d золота)" % bonus)
		comeback_bonus_awarded.emit(bonus)
		
	# Emergency cache trigger if critical lives
	var cache_cfg = catch_cfg.get("emergency_cache", {})
	var threshold = int(cache_cfg.get("trigger_lives_threshold", 5))
	if lives_left <= threshold and not emergency_cache_used:
		emergency_cache_used = true
		var cache_gold = int(cache_cfg.get("bonus_gold", 75))
		add_gold(cache_gold, "emergency", "🚨 Аварийный схрон королевства!")
		emergency_cache_triggered.emit(cache_gold)
		
	return pending_comeback_gold

# ==============================================================================
# Transaction Log & Statistics (Раздел 37)
# ==============================================================================

func _log_transaction(action_type: String, amount: int, detail: String) -> void:
	var entry = {
		"id": transaction_log.size() + 1,
		"timestamp": stats.get("time_elapsed", 0.0),
		"action": action_type,
		"amount": amount,
		"balance_after": current_gold,
		"detail": detail
	}
	transaction_log.append(entry)
	if transaction_log.size() > MAX_LOG_ENTRIES:
		transaction_log.remove_at(0)
	transaction_recorded.emit(entry)

func get_transaction_log() -> Array[Dictionary]:
	return transaction_log

func get_formatted_log_strings() -> Array[String]:
	var result: Array[String] = []
	for e in transaction_log:
		var sign_str = "+" if int(e["amount"]) > 0 else ""
		var amount_str = "%s%d" % [sign_str, int(e["amount"])] if int(e["amount"]) != 0 else "--"
		var line = "[%s] %s (Банк: %d) — %s" % [e["action"], amount_str, e["balance_after"], e["detail"]]
		result.append(line)
	return result

func get_economic_summary() -> Dictionary:
	var time_min = max(0.1, float(stats.get("time_elapsed", 1.0)) / 60.0)
	var snapshots: Array = stats.get("bank_snapshots", [])
	var avg_bank: float = float(current_gold)
	if not snapshots.is_empty():
		var sum_b = 0.0
		for s in snapshots:
			sum_b += float(s)
		avg_bank = sum_b / float(snapshots.size())
		
	return {
		"current_gold": current_gold,
		"total_income": total_income,
		"total_spending": total_spending,
		"income_per_minute": total_income / time_min,
		"spending_per_minute": total_spending / time_min,
		"average_bank": avg_bank,
		"peak_gold": stats.get("peak_gold", starting_gold),
		"lowest_gold": stats.get("lowest_gold", starting_gold),
		"bounty_gold": stats.get("bounty_gold", 0),
		"wave_reward_gold": stats.get("wave_reward_gold", 0),
		"interest_profit": stats.get("interest_gold", 0),
		"perfect_wave_profit": stats.get("perfect_wave_gold", 0),
		"contract_profit": stats.get("contract_gold", 0),
		"sell_losses": stats.get("sell_losses", 0),
		"comeback_profit": stats.get("comeback_gold", 0),
		"stolen_gold": stats.get("stolen_gold", 0),
		"contracts_completed": contract_history.filter(func(c): return c["status"] == "success").size(),
		"contracts_failed": contract_history.filter(func(c): return c["status"] == "failed").size()
	}

# ==============================================================================
# Boss Economy (Раздел 26 — Выбор награды босса: A vs B)
# ==============================================================================

func grant_boss_reward(choice_id: String) -> Dictionary:
	var result: Dictionary = {}
	if choice_id == "treasury":
		result = {
			"id": "treasury",
			"name": "Королевская Казна",
			"glory": 150,
			"next_stage_gold_bonus": 100,
			"damage_buff": 0.0,
			"description": "+150 Очков Славы и +100 золота в следующей катке"
		}
		_log_transaction("BOSS_REWARD", 150, "Награда за босса: Королевская Казна (+150 Славы)")
	else:
		result = {
			"id": "master_seal",
			"name": "Печать Мастера",
			"glory": 100,
			"next_stage_gold_bonus": 0,
			"damage_buff": 0.10,
			"description": "+100 Очков Славы и постоянный бонус +10% к урону всех башен"
		}
		_log_transaction("BOSS_REWARD", 100, "Награда за босса: Печать Мастера (+100 Славы, +10% урон)")
		
	boss_reward_chosen.emit(choice_id)
	return result

