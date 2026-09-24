class_name ArtifactsModal
extends PanelContainer

## Модальное окно артефактов (Этап 6)
## Отображает 3 активных слота, каталог найденных реликвий и пассивные свойства

signal closed()

@onready var slots_container: HBoxContainer = $MarginContainer/VBoxContainer/SlotsRow/SlotsContainer
@onready var artifact_list: VBoxContainer = $MarginContainer/VBoxContainer/HBoxContainer/ScrollContainer/ArtifactList
@onready var desc_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/DetailsPanel/VBox/DescLabel
@onready var rarity_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/DetailsPanel/VBox/RarityLabel
@onready var equip_btn: Button = $MarginContainer/VBoxContainer/HBoxContainer/DetailsPanel/VBox/EquipButton
@onready var close_btn: Button = $MarginContainer/VBoxContainer/BottomRow/CloseButton

var artifact_manager: ArtifactManager = null
var selected_artifact_id: String = ""

func _ready() -> void:
	if not artifact_manager and is_inside_tree() and get_tree():
		var mgr = get_tree().get_first_node_in_group("artifact_manager") as ArtifactManager
		if mgr:
			set_artifact_manager(mgr)
	if is_instance_valid(close_btn):
		close_btn.pressed.connect(func():
			visible = false
			closed.emit()
		)
	if is_instance_valid(equip_btn):
		equip_btn.pressed.connect(_on_equip_clicked)

func set_artifact_manager(mgr: ArtifactManager) -> void:
	artifact_manager = mgr
	if artifact_manager:
		if not artifact_manager.artifact_equipped.is_connected(_on_artifact_changed_any):
			artifact_manager.artifact_equipped.connect(_on_artifact_changed_any)
		if not artifact_manager.artifact_unequipped.is_connected(_on_artifact_changed_any):
			artifact_manager.artifact_unequipped.connect(_on_artifact_changed_any)
		if not artifact_manager.artifact_unlocked.is_connected(_on_artifact_changed_any):
			artifact_manager.artifact_unlocked.connect(_on_artifact_changed_any)
	refresh_ui()

func _on_artifact_changed_any(_a = null, _b = null) -> void:
	refresh_ui()

func refresh_ui() -> void:
	if not is_instance_valid(artifact_manager):
		return
	_update_slots()
	_populate_artifact_list()
	if selected_artifact_id != "":
		_show_artifact(selected_artifact_id)

func _update_slots() -> void:
	if not is_instance_valid(slots_container) or not is_instance_valid(artifact_manager):
		return
	var buttons = slots_container.get_children()
	for i in range(min(buttons.size(), artifact_manager.equipped_slots.size())):
		var btn: Button = buttons[i]
		var art_id = artifact_manager.equipped_slots[i]
		for conn in btn.pressed.get_connections():
			btn.pressed.disconnect(conn.callable)
		var slot_idx = i
		btn.pressed.connect(func():
			if is_instance_valid(artifact_manager) and artifact_manager.equipped_slots[slot_idx] != "":
				artifact_manager.unequip_slot(slot_idx)
				refresh_ui()
		)
		if art_id != "" and artifact_manager.artifacts_db.has(art_id):
			var data = artifact_manager.artifacts_db[art_id]
			btn.text = "Слот %d: 💎 %s\n(Клик для снятия)" % [i + 1, data.get("name", art_id)]
			btn.modulate = Color(1.0, 1.0, 1.0)
		else:
			btn.text = "Слот %d: [Пусто]\n(Выберите реликвию)" % [i + 1]
			btn.modulate = Color(0.7, 0.7, 0.7)

func _populate_artifact_list() -> void:
	if not is_instance_valid(artifact_list) or not is_instance_valid(artifact_manager):
		return
	for c in artifact_list.get_children():
		c.queue_free()
		
	for art_id in artifact_manager.artifacts_db:
		var data = artifact_manager.artifacts_db[art_id]
		var is_unlocked = artifact_manager.is_unlocked(art_id)
		var is_eq = artifact_manager.is_equipped(art_id)
		
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(0, 36)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		var prefix = "💎 " if is_unlocked else "🔒 "
		var suffix = " [Экипирован]" if is_eq else ""
		btn.text = "%s%s%s" % [prefix, data.get("name", art_id), suffix]
		
		var col = _get_rarity_color(data.get("rarity", "common"))
		if not is_unlocked:
			col = Color(0.5, 0.5, 0.5)
		btn.add_theme_color_override("font_color", col)
		btn.pressed.connect(func(): _show_artifact(art_id))
		artifact_list.add_child(btn)

func _show_artifact(art_id: String) -> void:
	selected_artifact_id = art_id
	if not is_instance_valid(artifact_manager) or not artifact_manager.artifacts_db.has(art_id):
		return
	var data = artifact_manager.artifacts_db[art_id]
	var is_unlocked = artifact_manager.is_unlocked(art_id)
	var is_eq = artifact_manager.is_equipped(art_id)
	
	if is_instance_valid(desc_label):
		desc_label.text = "%s\n\n%s" % [data.get("name", art_id), data.get("description", "")]
	if is_instance_valid(rarity_label):
		var r_name = data.get("rarity", "common").to_upper()
		rarity_label.text = "Редкость: %s" % r_name
		rarity_label.add_theme_color_override("font_color", _get_rarity_color(data.get("rarity", "common")))
		
	if is_instance_valid(equip_btn):
		if not is_unlocked:
			equip_btn.text = "🔒 Не открыто"
			equip_btn.disabled = true
		elif is_eq:
			equip_btn.text = "Снять из слота"
			equip_btn.disabled = false
		else:
			equip_btn.text = "Экипировать в свободный слот"
			equip_btn.disabled = false

func _on_equip_clicked() -> void:
	if not is_instance_valid(artifact_manager) or selected_artifact_id == "":
		return
	if artifact_manager.is_equipped(selected_artifact_id):
		var s_idx = artifact_manager.equipped_slots.find(selected_artifact_id)
		if s_idx != -1:
			artifact_manager.unequip_slot(s_idx)
	else:
		for i in range(artifact_manager.max_slots):
			if artifact_manager.equipped_slots[i] == "":
				artifact_manager.equip_artifact(selected_artifact_id, i)
				break
	refresh_ui()

func _get_rarity_color(rarity: String) -> Color:
	match rarity.to_lower():
		"uncommon": return Color(0.3, 0.85, 0.4) # Green
		"rare": return Color(0.3, 0.6, 1.0) # Blue
		"epic": return Color(0.75, 0.35, 0.95) # Purple
		"legendary": return Color(1.0, 0.75, 0.1) # Gold
	return Color(0.85, 0.85, 0.85)
