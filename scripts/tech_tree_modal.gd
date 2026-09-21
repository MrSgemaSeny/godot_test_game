class_name TechTreeModal
extends PanelContainer

signal closed()

@onready var points_label: Label = $MarginContainer/VBoxContainer/Header/PointsLabel
@onready var defense_box: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/HBoxContainer/DefenseBranch/VBox
@onready var econ_box: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/HBoxContainer/EconBranch/VBox
@onready var special_box: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/HBoxContainer/SpecialBranch/VBox
@onready var close_btn: Button = $MarginContainer/VBoxContainer/CloseButton

var tech_tree: TechTreeManager = null

func _ready() -> void:
	close_btn.pressed.connect(_on_close_pressed)

func open_modal() -> void:
	tech_tree = get_tree().get_first_node_in_group("tech_tree_manager") as TechTreeManager
	if tech_tree:
		if not tech_tree.research_points_changed.is_connected(_update_ui):
			tech_tree.research_points_changed.connect(_update_ui)
		if not tech_tree.node_unlocked.is_connected(_on_node_unlocked):
			tech_tree.node_unlocked.connect(_on_node_unlocked)
	visible = true
	_update_ui(tech_tree.research_points if tech_tree else 0)

func _on_node_unlocked(_id: String) -> void:
	_update_ui(tech_tree.research_points if tech_tree else 0)

func _update_ui(points: int) -> void:
	points_label.text = "📜 Очки исследований: %d" % points
	_render_nodes()

func _render_nodes() -> void:
	if not tech_tree:
		return
		
	_clear_container(defense_box)
	_clear_container(econ_box)
	_clear_container(special_box)
	
	for node in tech_tree.tech_nodes_data:
		var branch = node.get("branch", "defense")
		var target_box = defense_box
		if branch == "economy":
			target_box = econ_box
		elif branch == "special":
			target_box = special_box
			
		_create_node_card(node, target_box)

func _clear_container(box: VBoxContainer) -> void:
	if is_instance_valid(box):
		for child in box.get_children():
			child.queue_free()

func _create_node_card(node_data: Dictionary, container: VBoxContainer) -> void:
	var node_id = node_data.get("id", "")
	var node_name = node_data.get("name", "")
	var node_desc = node_data.get("description", "")
	var cost = node_data.get("cost", 1)
	
	var card = PanelContainer.new()
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	
	var title = Label.new()
	title.text = node_name
	title.add_theme_font_size_override("font_size", 14)
	
	var desc = Label.new()
	desc.text = node_desc
	desc.add_theme_font_size_override("font_size", 11)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.modulate = Color(0.8, 0.8, 0.8)
	
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(0, 32)
	btn.add_theme_font_size_override("font_size", 12)
	
	if tech_tree.is_unlocked(node_id):
		btn.text = "✅ Изучено"
		btn.disabled = true
		title.modulate = Color(0.3, 0.9, 0.3)
	elif tech_tree.is_blocked(node_id):
		btn.text = "⛔ Заблокировано"
		btn.disabled = true
		title.modulate = Color(0.9, 0.3, 0.3)
	elif tech_tree.can_unlock(node_id):
		btn.text = "Изучить (%d очк.)" % cost
		btn.disabled = false
		btn.pressed.connect(func(): tech_tree.unlock_node(node_id))
		title.modulate = Color(1.0, 0.85, 0.2)
	else:
		btn.text = "🔒 Требуются условия"
		btn.disabled = true
		title.modulate = Color(0.5, 0.5, 0.5)
		
	vbox.add_child(title)
	vbox.add_child(desc)
	vbox.add_child(btn)
	margin.add_child(vbox)
	card.add_child(margin)
	container.add_child(card)

func _on_close_pressed() -> void:
	visible = false
	closed.emit()
