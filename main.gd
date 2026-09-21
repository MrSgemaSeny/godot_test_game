extends Node2D

const MAP_WIDTH: int = 10
const MAP_HEIGHT: int = 10
const TILE_SIZE: int = 48

const TILE_GRASS: int = 0
const TILE_WATER: int = 1

@onready var tile_map: TileMap = $TileMap
@onready var unit: Unit = $Unit
@onready var info_label: Label = $CanvasLayer/InfoLabel

func _ready() -> void:
	_setup_tileset()
	_generate_map()
	_setup_ui()
	if unit:
		unit.grid_position = Vector2i(3, 3)
		unit.update_position_from_grid()
		unit.unit_clicked.connect(_on_unit_clicked)

func _setup_tileset() -> void:
	var tileset = TileSet.new()
	tileset.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	
	# 1. Текстура Травы (Grass)
	var grass_img = Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	grass_img.fill(Color(0.32, 0.68, 0.32))
	for x in range(TILE_SIZE):
		for y in range(TILE_SIZE):
			if x == 0 or y == 0 or x == TILE_SIZE - 1 or y == TILE_SIZE - 1:
				grass_img.set_pixel(x, y, Color(0.24, 0.54, 0.24))
			elif (x * 3 + y * 7) % 13 == 0:
				grass_img.set_pixel(x, y, Color(0.38, 0.78, 0.38))
	var grass_tex = ImageTexture.create_from_image(grass_img)
	
	var grass_source = TileSetAtlasSource.new()
	grass_source.texture = grass_tex
	grass_source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	grass_source.create_tile(Vector2i(0, 0))
	tileset.add_source(grass_source, TILE_GRASS)
	
	# 2. Текстура Воды (Water)
	var water_img = Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	water_img.fill(Color(0.2, 0.45, 0.82))
	for x in range(TILE_SIZE):
		for y in range(TILE_SIZE):
			if x == 0 or y == 0 or x == TILE_SIZE - 1 or y == TILE_SIZE - 1:
				water_img.set_pixel(x, y, Color(0.14, 0.35, 0.68))
			elif (x * 2 + y * 5) % 11 == 0:
				water_img.set_pixel(x, y, Color(0.35, 0.6, 0.95))
	var water_tex = ImageTexture.create_from_image(water_img)
	
	var water_source = TileSetAtlasSource.new()
	water_source.texture = water_tex
	water_source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	water_source.create_tile(Vector2i(0, 0))
	tileset.add_source(water_source, TILE_WATER)
	
	tile_map.tile_set = tileset

func _generate_map() -> void:
	for x in range(MAP_WIDTH):
		for y in range(MAP_HEIGHT):
			var cell = Vector2i(x, y)
			# По краям вода, в центре трава + небольшое озеро
			var is_water = (x == 0 or x == MAP_WIDTH - 1 or y == 0 or y == MAP_HEIGHT - 1)
			if (x == 6 and y == 6) or (x == 7 and y == 6) or (x == 7 and y == 7):
				is_water = true
				
			var source_id = TILE_WATER if is_water else TILE_GRASS
			tile_map.set_cell(0, cell, source_id, Vector2i(0, 0))

func _setup_ui() -> void:
	if info_label:
		info_label.text = "Карта 10x10 (Трава и Вода)\nКликните по Юниту (красный квадрат) для выбора.\nКликните по клетке травы для перемещения."

func _on_unit_clicked(u: Unit) -> void:
	if info_label:
		if u.is_selected:
			info_label.text = "Юнит ВЫБРАН!\nПозиция: (" + str(u.grid_position.x) + ", " + str(u.grid_position.y) + ")\nКликните по любой клетке травы, чтобы переместить его."
		else:
			info_label.text = "Выделение снято.\nКликните по юниту для выбора."

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if unit and unit.is_selected:
			var mouse_pos = get_global_mouse_position()
			var cell = tile_map.local_to_map(mouse_pos)
			
			if cell.x >= 0 and cell.x < MAP_WIDTH and cell.y >= 0 and cell.y < MAP_HEIGHT:
				var source_id = tile_map.get_cell_source_id(0, cell)
				if source_id == TILE_GRASS:
					unit.grid_position = cell
					unit.update_position_from_grid()
					_on_unit_clicked(unit)
				elif source_id == TILE_WATER:
					if info_label:
						info_label.text = "Клетка (" + str(cell.x) + ", " + str(cell.y) + ") — это Вода!\nЮнит не может туда пойти."
