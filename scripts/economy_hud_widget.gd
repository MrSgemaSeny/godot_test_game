class_name EconomyHUDWidget
extends Control

## ==============================================================================
## Виджет экономической информации и взаимодействия (Раздел 35-37)
## Включает:
## 1. Панель депозита: текущий процент и прогноз процентов на след. волну
## 2. Модальное окно выбора предволновых контрактов
## 3. Отчёт по доходам за завершённую волну (Wave Economy Breakdown)
## 4. Окно аудита и дебаггер транзакций (Transaction Log Viewer)
## ==============================================================================

signal contract_chosen(contract_id: String)
signal contract_dismissed()
signal wave_report_closed()
signal stage_briefing_closed()
signal boss_reward_selected(choice_id: String)

var economy_manager: EconomyManager = null

# UI Elements
var bank_bar: PanelContainer
var bank_label: Label
var interest_preview_label: Label

# Modals
var contract_modal: PanelContainer
var contract_container: HBoxContainer
var wave_summary_modal: PanelContainer
var wave_summary_content: VBoxContainer
var tx_log_modal: PanelContainer
var tx_log_list: VBoxContainer
var stage_briefing_modal: PanelContainer
var stage_briefing_content: VBoxContainer
var boss_choice_modal: PanelContainer

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_bank_bar()
	_build_contract_modal()
	_build_wave_summary_modal()
	_build_tx_log_modal()
	_build_stage_briefing_modal()
	_build_boss_choice_modal()

func setup(econ: EconomyManager) -> void:
	economy_manager = econ
	if economy_manager:
		if not economy_manager.gold_changed.is_connected(_on_gold_changed):
			economy_manager.gold_changed.connect(_on_gold_changed)
		if not economy_manager.interest_accrued.is_connected(_on_interest_accrued):
			economy_manager.interest_accrued.connect(_on_interest_accrued)
		update_bank_display()

func _on_gold_changed(_current_gold: int, _delta: int, _category: String) -> void:
	update_bank_display()

func _on_interest_accrued(_amount: int, _rate: float) -> void:
	update_bank_display()

# ==============================================================================
# 1. Bank & Interest Bar
# ==============================================================================

func _build_bank_bar() -> void:
	bank_bar = PanelContainer.new()
	bank_bar.name = "BankBar"
	bank_bar.custom_minimum_size = Vector2(230, 36)
	bank_bar.position = Vector2(10, 48)
	bank_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.12, 0.18, 0.88)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.25, 0.55, 0.85, 0.7)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	bank_bar.add_theme_stylebox_override("panel", style)
	
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 10)
	
	bank_label = Label.new()
	bank_label.text = "🏛️ Депозит: 0%"
	bank_label.add_theme_font_size_override("font_size", 13)
	bank_label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	hbox.add_child(bank_label)
	
	interest_preview_label = Label.new()
	interest_preview_label.text = "(+0🪙)"
	interest_preview_label.add_theme_font_size_override("font_size", 13)
	interest_preview_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
	hbox.add_child(interest_preview_label)
	
	var log_btn = Button.new()
	log_btn.text = "📜"
	log_btn.tooltip_text = "Открыть журнал транзакций"
	log_btn.pressed.connect(toggle_tx_log)
	hbox.add_child(log_btn)
	
	bank_bar.add_child(hbox)
	add_child(bank_bar)

func update_bank_display() -> void:
	if not economy_manager or not bank_label:
		return
		
	var rate = economy_manager.get_current_interest_rate()
	var preview_gain = economy_manager.calculate_interest()
	
	if not economy_manager.interest_enabled:
		bank_label.text = "🏛️ Депозит: выкл"
		interest_preview_label.text = ""
		return
		
	var rate_pct = int(rate * 100.0)
	bank_label.text = "🏛️ Депозит: %d%%" % rate_pct
	interest_preview_label.text = "(+%d🪙)" % preview_gain
	
	if rate_pct >= 15:
		interest_preview_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	elif rate_pct >= 5:
		interest_preview_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
	else:
		interest_preview_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))

# ==============================================================================
# 2. Pre-wave Contract Selection Modal
# ==============================================================================

func _build_contract_modal() -> void:
	contract_modal = PanelContainer.new()
	contract_modal.name = "ContractModal"
	contract_modal.visible = false
	contract_modal.custom_minimum_size = Vector2(560, 260)
	contract_modal.position = Vector2(360, 200)
	contract_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.12, 0.96)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.9, 0.7, 0.2, 0.9)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	contract_modal.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	
	var title = Label.new()
	title.text = "📜 КОНТРАКТЫ НА ВОЛНУ (РИСК / НАГРАДА)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	vbox.add_child(title)
	
	contract_container = HBoxContainer.new()
	contract_container.alignment = BoxContainer.ALIGNMENT_CENTER
	contract_container.add_theme_constant_override("separation", 16)
	vbox.add_child(contract_container)
	
	var skip_btn = Button.new()
	skip_btn.text = "Пропустить контракты (Без риска)"
	skip_btn.custom_minimum_size = Vector2(220, 32)
	skip_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	skip_btn.pressed.connect(_on_skip_contract_pressed)
	vbox.add_child(skip_btn)
	
	contract_modal.add_child(vbox)
	add_child(contract_modal)

func show_contracts(contracts: Array[Dictionary]) -> void:
	if contracts.is_empty():
		return
		
	for c in contract_container.get_children():
		c.queue_free()
		
	for c_data in contracts:
		var card = PanelContainer.new()
		card.custom_minimum_size = Vector2(240, 150)
		var c_style = StyleBoxFlat.new()
		c_style.bg_color = Color(0.12, 0.15, 0.22, 0.9)
		c_style.border_width_left = 1
		c_style.border_width_top = 1
		c_style.border_width_right = 1
		c_style.border_width_bottom = 1
		c_style.border_color = Color(0.3, 0.5, 0.8, 0.7)
		c_style.corner_radius_top_left = 8
		c_style.corner_radius_top_right = 8
		c_style.corner_radius_bottom_right = 8
		c_style.corner_radius_bottom_left = 8
		card.add_theme_stylebox_override("panel", c_style)
		
		var cvbox = VBoxContainer.new()
		cvbox.add_theme_constant_override("separation", 6)
		
		var c_name = Label.new()
		c_name.text = str(c_data.get("name", "Контракт"))
		c_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c_name.add_theme_font_size_override("font_size", 14)
		c_name.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
		cvbox.add_child(c_name)
		
		var c_desc = Label.new()
		c_desc.text = str(c_data.get("description", ""))
		c_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		c_desc.add_theme_font_size_override("font_size", 11)
		c_desc.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
		cvbox.add_child(c_desc)
		
		var c_reward = Label.new()
		var r_mult = float(c_data.get("reward_mult", 1.25))
		c_reward.text = "Награда: +%.0f%% золота" % ((r_mult - 1.0) * 100.0)
		c_reward.add_theme_font_size_override("font_size", 12)
		c_reward.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
		cvbox.add_child(c_reward)
		
		var accept_btn = Button.new()
		accept_btn.text = "Подписать контракт"
		var cid = str(c_data.get("id", ""))
		accept_btn.pressed.connect(func(): _on_accept_contract_pressed(cid))
		cvbox.add_child(accept_btn)
		
		card.add_child(cvbox)
		contract_container.add_child(card)
		
	contract_modal.visible = true

func _on_accept_contract_pressed(contract_id: String) -> void:
	contract_modal.visible = false
	if economy_manager:
		economy_manager.accept_contract(contract_id)
	contract_chosen.emit(contract_id)

func _on_skip_contract_pressed() -> void:
	contract_modal.visible = false
	contract_dismissed.emit()

# ==============================================================================
# 3. Wave Economy Breakdown Modal
# ==============================================================================

func _build_wave_summary_modal() -> void:
	wave_summary_modal = PanelContainer.new()
	wave_summary_modal.name = "WaveSummaryModal"
	wave_summary_modal.visible = false
	wave_summary_modal.custom_minimum_size = Vector2(420, 280)
	wave_summary_modal.position = Vector2(430, 200)
	wave_summary_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.10, 0.16, 0.96)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.7, 0.9, 0.9)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	wave_summary_modal.add_theme_stylebox_override("panel", style)
	
	wave_summary_content = VBoxContainer.new()
	wave_summary_content.add_theme_constant_override("separation", 8)
	
	var title = Label.new()
	title.text = "💰 ЭКОНОМИЧЕСКИЙ ОТЧЕТ ВОЛНЫ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	wave_summary_content.add_child(title)
	
	var close_btn = Button.new()
	close_btn.text = "Продолжить"
	close_btn.custom_minimum_size = Vector2(160, 32)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(func():
		wave_summary_modal.visible = false
		wave_report_closed.emit()
	)
	wave_summary_content.add_child(close_btn)
	
	wave_summary_modal.add_child(wave_summary_content)
	add_child(wave_summary_modal)

func show_wave_breakdown(breakdown: Dictionary) -> void:
	# Clear previous lines except title and button
	var children = wave_summary_content.get_children()
	for i in range(1, children.size() - 1):
		children[i].queue_free()
		
	var wave_num = int(breakdown.get("wave_num", 1))
	var wave_reward = int(breakdown.get("wave_reward", 0))
	var bounty_gold = int(breakdown.get("bounty_gold", 0))
	var interest_gold = int(breakdown.get("interest_gold", 0))
	var perfect_bonus = int(breakdown.get("perfect_wave_bonus", 0))
	var contract_reward = int(breakdown.get("contract_reward", 0))
	var total_gain = wave_reward + bounty_gold + interest_gold + perfect_bonus + contract_reward
	
	var list_box = VBoxContainer.new()
	list_box.add_theme_constant_override("separation", 4)
	
	_add_stat_row(list_box, "Базовая награда за волну %d:" % wave_num, "+%d🪙" % wave_reward, Color(0.9, 0.9, 0.9))
	_add_stat_row(list_box, "Трофеи за монстров:", "+%d🪙" % bounty_gold, Color(0.95, 0.8, 0.2))
	if interest_gold > 0:
		_add_stat_row(list_box, "Проценты на депозит (Банк):", "+%d🪙" % interest_gold, Color(0.4, 0.9, 0.5))
	if perfect_bonus > 0:
		_add_stat_row(list_box, "✨ Идеальная волна (0 урона):", "+%d🪙" % perfect_bonus, Color(0.4, 0.85, 1.0))
	if contract_reward > 0:
		_add_stat_row(list_box, "📜 Премия по контракту:", "+%d🪙" % contract_reward, Color(1.0, 0.7, 0.2))
		
	var sep = HSeparator.new()
	list_box.add_child(sep)
	_add_stat_row(list_box, "ИТОГО ПРИРОСТ КАЗНЫ:", "+%d🪙" % total_gain, Color(1.0, 0.9, 0.3))
	
	wave_summary_content.add_child(list_box)
	wave_summary_content.move_child(list_box, 1)
	wave_summary_modal.visible = true

func _add_stat_row(parent: Control, label_text: String, value_text: String, color: Color) -> void:
	var h = HBoxContainer.new()
	var l = Label.new()
	l.text = label_text
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", 12)
	h.add_child(l)
	
	var v = Label.new()
	v.text = value_text
	v.add_theme_font_size_override("font_size", 12)
	v.add_theme_color_override("font_color", color)
	h.add_child(v)
	parent.add_child(h)

# ==============================================================================
# 4. Transaction Log Viewer & Debugger
# ==============================================================================

func _build_tx_log_modal() -> void:
	tx_log_modal = PanelContainer.new()
	tx_log_modal.name = "TxLogModal"
	tx_log_modal.visible = false
	tx_log_modal.custom_minimum_size = Vector2(500, 360)
	tx_log_modal.position = Vector2(390, 160)
	tx_log_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.10, 0.96)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.4, 0.6, 0.8, 0.8)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	tx_log_modal.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	
	var title = Label.new()
	title.text = "📊 АУДИТ ТРАНЗАКЦИЙ КАЗНЫ (TRANSACTION LOG)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	vbox.add_child(title)
	
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(480, 270)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	tx_log_list = VBoxContainer.new()
	tx_log_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(tx_log_list)
	vbox.add_child(scroll)
	
	var close_btn = Button.new()
	close_btn.text = "Закрыть"
	close_btn.custom_minimum_size = Vector2(120, 28)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(func(): tx_log_modal.visible = false)
	vbox.add_child(close_btn)
	
	tx_log_modal.add_child(vbox)
	add_child(tx_log_modal)

func toggle_tx_log() -> void:
	if not tx_log_modal:
		return
	tx_log_modal.visible = not tx_log_modal.visible
	if tx_log_modal.visible:
		refresh_tx_log()

func refresh_tx_log() -> void:
	if not economy_manager or not tx_log_list:
		return
	for c in tx_log_list.get_children():
		c.queue_free()
		
	var logs = economy_manager.get_formatted_log_strings()
	if logs.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "Транзакции пока отсутствуют."
		empty_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		tx_log_list.add_child(empty_lbl)
		return
		
	# Show most recent entries at top
	var reversed_logs = logs.duplicate()
	reversed_logs.reverse()
	for line in reversed_logs:
		var lbl = Label.new()
		lbl.text = line
		lbl.add_theme_font_size_override("font_size", 11)
		if line.contains("[-"):
			lbl.add_theme_color_override("font_color", Color(0.95, 0.45, 0.45))
		elif line.contains("[+"):
			lbl.add_theme_color_override("font_color", Color(0.45, 0.95, 0.55))
		else:
			lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
		tx_log_list.add_child(lbl)

# ==============================================================================
# 5. Phase 0 — Stage Briefing Modal (Раздел 28)
# ==============================================================================

func _build_stage_briefing_modal() -> void:
	stage_briefing_modal = PanelContainer.new()
	stage_briefing_modal.name = "StageBriefingModal"
	stage_briefing_modal.visible = false
	stage_briefing_modal.custom_minimum_size = Vector2(620, 420)
	stage_briefing_modal.position = Vector2(330, 130)
	stage_briefing_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.12, 0.98)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.85, 0.70, 0.25, 0.95)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	style.shadow_color = Color(0, 0, 0, 0.8)
	style.shadow_size = 24
	stage_briefing_modal.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 16)
	
	stage_briefing_content = VBoxContainer.new()
	stage_briefing_content.add_theme_constant_override("separation", 10)
	margin.add_child(stage_briefing_content)
	
	stage_briefing_modal.add_child(margin)
	add_child(stage_briefing_modal)

func show_stage_briefing(stage_info: Dictionary) -> void:
	if not stage_briefing_modal:
		_build_stage_briefing_modal()
	if not stage_briefing_content:
		return
		
	for c in stage_briefing_content.get_children():
		c.queue_free()
		
	var ch_num = int(stage_info.get("chapter_num", 1))
	var st_num = int(stage_info.get("stage_num", 1))
	var st_title = str(stage_info.get("name", "Рубеж %d" % st_num))
	var biome = str(stage_info.get("biome", "plains"))
	var max_lvl = int(stage_info.get("max_tower_level", 3))
	var start_g = int(stage_info.get("start_gold", 350))
	var profile = str(stage_info.get("economy_profile", "standard"))
	var waves_count = int(stage_info.get("wave_count", 10))
	
	# Заголовок
	var title = Label.new()
	title.text = "📋 БОЕВАЯ РАЗВЕДКА РУБЕЖА: ГЛАВА %d — КАТКА %d" % [ch_num, st_num]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	stage_briefing_content.add_child(title)
	
	var sub = Label.new()
	sub.text = "«%s» | Биом: %s" % [st_title, biome.capitalize()]
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", Color(0.75, 0.85, 0.95))
	stage_briefing_content.add_child(sub)
	
	var sep = HSeparator.new()
	stage_briefing_content.add_child(sep)
	
	# Grid параметров
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 6)
	
	var lvl_text = "🔒 Макс. Ур. %d" % max_lvl
	if max_lvl == 5:
		lvl_text += " (👑 Открыта Эволюция A/B!)"
	elif max_lvl == 4:
		lvl_text += " (Мастерские формы)"
	else:
		lvl_text += " (Кадетский гарнизон)"
		
	var params = [
		["🛡️ Лимит башен:", lvl_text],
		["🪙 Стартовая казна:", "%d золота" % start_g],
		["📊 Профиль экономики:", "%s (Депозит до 15%%)" % profile.capitalize()],
		["🌊 Напор орды:", "%d волн атаки" % waves_count]
	]
	
	for p in params:
		var l1 = Label.new()
		l1.text = p[0]
		l1.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
		l1.add_theme_font_size_override("font_size", 12)
		var l2 = Label.new()
		l2.text = p[1]
		l2.add_theme_color_override("font_color", Color(1.0, 0.95, 0.75))
		l2.add_theme_font_size_override("font_size", 12)
		grid.add_child(l1)
		grid.add_child(l2)
	stage_briefing_content.add_child(grid)
	
	# Блок разведки угроз
	var intel_panel = PanelContainer.new()
	var ip_style = StyleBoxFlat.new()
	ip_style.bg_color = Color(0.10, 0.13, 0.18, 0.9)
	ip_style.set_corner_radius_all(6)
	ip_style.content_margin_left = 10
	ip_style.content_margin_right = 10
	ip_style.content_margin_top = 8
	ip_style.content_margin_bottom = 8
	intel_panel.add_theme_stylebox_override("panel", ip_style)
	
	var intel_vbox = VBoxContainer.new()
	var intel_lbl = Label.new()
	intel_lbl.text = "🎯 Боевые задачи (Звёзды):"
	intel_lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
	intel_lbl.add_theme_font_size_override("font_size", 12)
	intel_vbox.add_child(intel_lbl)
	
	var star_conds = [
		"⭐ 1: Оборонить рубеж от всех волн орды",
		"⭐ 2: Сохранить минимум 3 жизни королевских дев",
		"⭐ 3: Выполнить военный контракт или скопить >200 золота"
	]
	for sc in star_conds:
		var scl = Label.new()
		scl.text = "  • %s" % sc
		scl.add_theme_font_size_override("font_size", 11)
		scl.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
		intel_vbox.add_child(scl)
	intel_panel.add_child(intel_vbox)
	stage_briefing_content.add_child(intel_panel)
	
	# Кнопки действия
	var btn_hbox = HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 16)
	
	var ready_btn = Button.new()
	ready_btn.text = "⚔️ В БОЙ! (К обороне)"
	ready_btn.custom_minimum_size = Vector2(180, 36)
	ready_btn.pressed.connect(func():
		stage_briefing_modal.visible = false
		stage_briefing_closed.emit()
	)
	btn_hbox.add_child(ready_btn)
	
	var contracts_btn = Button.new()
	contracts_btn.text = "📜 Контракты на волну"
	contracts_btn.custom_minimum_size = Vector2(180, 36)
	contracts_btn.pressed.connect(func():
		stage_briefing_modal.visible = false
		if economy_manager:
			var contracts = economy_manager.get_available_contracts(2)
			if not contracts.is_empty():
				show_contracts(contracts)
	)
	btn_hbox.add_child(contracts_btn)
	stage_briefing_content.add_child(btn_hbox)
	
	stage_briefing_modal.visible = true

# ==============================================================================
# 6. Boss Victory Reward Choice Modal (Раздел 26)
# ==============================================================================

func _build_boss_choice_modal() -> void:
	boss_choice_modal = PanelContainer.new()
	boss_choice_modal.name = "BossChoiceModal"
	boss_choice_modal.visible = false
	boss_choice_modal.custom_minimum_size = Vector2(580, 290)
	boss_choice_modal.position = Vector2(350, 190)
	boss_choice_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.12, 0.98)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(1.0, 0.85, 0.25, 1.0)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_right = 14
	style.corner_radius_bottom_left = 14
	style.shadow_color = Color(0, 0, 0, 0.85)
	style.shadow_size = 28
	boss_choice_modal.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	
	var title = Label.new()
	title.text = "👑 ТРИУМФ НАД БОССОМ ГЛАВЫ!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	vbox.add_child(title)
	
	var sub = Label.new()
	sub.text = "Король лично жалует вам выбор великой награды рубежа:"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	vbox.add_child(sub)
	
	var cards_hbox = HBoxContainer.new()
	cards_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_hbox.add_theme_constant_override("separation", 18)
	
	# Card A: Королевская Казна
	var card_a = PanelContainer.new()
	card_a.custom_minimum_size = Vector2(250, 160)
	var ca_style = StyleBoxFlat.new()
	ca_style.bg_color = Color(0.12, 0.16, 0.24, 0.95)
	ca_style.border_width_left = 2
	ca_style.border_width_top = 2
	ca_style.border_width_right = 2
	ca_style.border_width_bottom = 2
	ca_style.border_color = Color(0.4, 0.85, 0.4, 0.8)
	ca_style.set_corner_radius_all(8)
	ca_style.content_margin_left = 12
	ca_style.content_margin_right = 12
	ca_style.content_margin_top = 10
	ca_style.content_margin_bottom = 10
	card_a.add_theme_stylebox_override("panel", ca_style)
	
	var ca_vbox = VBoxContainer.new()
	ca_vbox.add_theme_constant_override("separation", 6)
	var ca_title = Label.new()
	ca_title.text = "💰 Королевская Казна"
	ca_title.add_theme_font_size_override("font_size", 14)
	ca_title.add_theme_color_override("font_color", Color(0.4, 0.95, 0.4))
	ca_vbox.add_child(ca_title)
	var ca_desc = Label.new()
	ca_desc.text = "• +150 Очков Славы (Glory)\n• +100 золота в следующей катке\n\nМощный экономический старт."
	ca_desc.add_theme_font_size_override("font_size", 11)
	ca_desc.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	ca_vbox.add_child(ca_desc)
	var ca_btn = Button.new()
	ca_btn.text = "Выбрать Казну"
	ca_btn.pressed.connect(func(): _on_boss_reward_picked("treasury"))
	ca_vbox.add_child(ca_btn)
	card_a.add_child(ca_vbox)
	cards_hbox.add_child(card_a)
	
	# Card B: Печать Мастера
	var card_b = PanelContainer.new()
	card_b.custom_minimum_size = Vector2(250, 160)
	var cb_style = StyleBoxFlat.new()
	cb_style.bg_color = Color(0.18, 0.12, 0.16, 0.95)
	cb_style.border_width_left = 2
	cb_style.border_width_top = 2
	cb_style.border_width_right = 2
	cb_style.border_width_bottom = 2
	cb_style.border_color = Color(0.95, 0.45, 0.25, 0.8)
	cb_style.set_corner_radius_all(8)
	cb_style.content_margin_left = 12
	cb_style.content_margin_right = 12
	cb_style.content_margin_top = 10
	cb_style.content_margin_bottom = 10
	card_b.add_theme_stylebox_override("panel", cb_style)
	
	var cb_vbox = VBoxContainer.new()
	cb_vbox.add_theme_constant_override("separation", 6)
	var cb_title = Label.new()
	cb_title.text = "⚔️ Печать Мастера"
	cb_title.add_theme_font_size_override("font_size", 14)
	cb_title.add_theme_color_override("font_color", Color(1.0, 0.65, 0.25))
	cb_vbox.add_child(cb_title)
	var cb_desc = Label.new()
	cb_desc.text = "• +100 Очков Славы (Glory)\n• +10% к урону всех башен\n\nБоевое мастерство гарнизона."
	cb_desc.add_theme_font_size_override("font_size", 11)
	cb_desc.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	cb_vbox.add_child(cb_desc)
	var cb_btn = Button.new()
	cb_btn.text = "Выбрать Печать"
	cb_btn.pressed.connect(func(): _on_boss_reward_picked("master_seal"))
	cb_vbox.add_child(cb_btn)
	card_b.add_child(cb_vbox)
	cards_hbox.add_child(card_b)
	
	vbox.add_child(cards_hbox)
	margin.add_child(vbox)
	boss_choice_modal.add_child(margin)
	add_child(boss_choice_modal)

func show_boss_choice() -> void:
	if not boss_choice_modal:
		_build_boss_choice_modal()
	if boss_choice_modal:
		boss_choice_modal.visible = true

func _on_boss_reward_picked(choice_id: String) -> void:
	if boss_choice_modal:
		boss_choice_modal.visible = false
	if economy_manager:
		economy_manager.grant_boss_reward(choice_id)
	boss_reward_selected.emit(choice_id)

