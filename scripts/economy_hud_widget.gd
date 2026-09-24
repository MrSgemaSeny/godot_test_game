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

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_bank_bar()
	_build_contract_modal()
	_build_wave_summary_modal()
	_build_tx_log_modal()

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
