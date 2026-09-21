extends Area2D
class_name Unit

signal unit_clicked(unit: Unit)

var is_selected: bool = false
var grid_position: Vector2i = Vector2i(2, 2)
const TILE_SIZE: int = 48

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	input_event.connect(_on_input_event)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	if sprite.texture == null:
		sprite.texture = _create_unit_texture()
	
	update_position_from_grid()

func _create_unit_texture() -> Texture2D:
	var img = Image.create(TILE_SIZE - 14, TILE_SIZE - 14, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.85, 0.22, 0.22, 1.0)) # Red warrior
	var w = img.get_width()
	var h = img.get_height()
	for x in range(w):
		for y in range(h):
			if x == 0 or y == 0 or x == w - 1 or y == h - 1:
				img.set_pixel(x, y, Color(1.0, 0.8, 0.8, 1.0))
			elif (x >= 6 and x <= 10) and (y >= 8 and y <= 12):
				img.set_pixel(x, y, Color(0.1, 0.1, 0.1, 1.0))
			elif (x >= w - 11 and x <= w - 7) and (y >= 8 and y <= 12):
				img.set_pixel(x, y, Color(0.1, 0.1, 0.1, 1.0))
			elif (x >= 8 and x <= w - 9) and (y >= h - 10 and y <= h - 8):
				img.set_pixel(x, y, Color(0.3, 0.1, 0.1, 1.0))
	return ImageTexture.create_from_image(img)

func update_position_from_grid() -> void:
	position = Vector2(
		grid_position.x * TILE_SIZE + TILE_SIZE / 2.0,
		grid_position.y * TILE_SIZE + TILE_SIZE / 2.0
	)

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		toggle_selection()
		unit_clicked.emit(self)
		get_viewport().set_input_as_handled()

func toggle_selection() -> void:
	set_selected(!is_selected)

func set_selected(val: bool) -> void:
	is_selected = val
	if is_selected:
		sprite.modulate = Color(1.8, 1.8, 0.6) # Glow yellow
		scale = Vector2(1.2, 1.2)
	else:
		sprite.modulate = Color.WHITE
		scale = Vector2(1.0, 1.0)

func _on_mouse_entered() -> void:
	if not is_selected:
		sprite.modulate = Color(1.3, 1.3, 1.3)

func _on_mouse_exited() -> void:
	if not is_selected:
		sprite.modulate = Color.WHITE
