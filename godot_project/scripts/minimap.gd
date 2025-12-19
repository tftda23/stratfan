extends Control
class_name Minimap

@onready var minimap_viewport: SubViewport
@onready var minimap_texture_rect: TextureRect
@onready var camera_indicator: ColorRect

var world_map: Node2D
var minimap_image: Image
var minimap_texture: ImageTexture
var minimap_size: Vector2i = Vector2i(200, 200)

# Display modes
enum DisplayMode {
	TERRAIN,
	CIVILIZATIONS,
	RESOURCES
}
var current_mode: DisplayMode = DisplayMode.CIVILIZATIONS

func _ready():
	custom_minimum_size = minimap_size

	# Create minimap texture rect
	minimap_texture_rect = TextureRect.new()
	minimap_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	minimap_texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	minimap_texture_rect.custom_minimum_size = minimap_size
	minimap_texture_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(minimap_texture_rect)

	# Create camera indicator
	camera_indicator = ColorRect.new()
	camera_indicator.color = Color(1, 1, 1, 0.5)
	camera_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(camera_indicator)

	# Connect click events
	minimap_texture_rect.gui_input.connect(_on_minimap_clicked)

func initialize(map: Node2D):
	"""Initialize the minimap with the world map reference."""
	world_map = map
	_generate_minimap()

func _generate_minimap():
	"""Generate the minimap image from world data."""
	if not world_map:
		return

	var tile_data = world_map._tile_data
	if tile_data.is_empty():
		return

	# Find world bounds
	var min_x = INF
	var max_x = -INF
	var min_y = INF
	var max_y = -INF

	for coords in tile_data.keys():
		min_x = min(min_x, coords.x)
		max_x = max(max_x, coords.x)
		min_y = min(min_y, coords.y)
		max_y = max(max_y, coords.y)

	var world_width = int(max_x - min_x + 1)
	var world_height = int(max_y - min_y + 1)

	# Create image
	minimap_image = Image.create(world_width, world_height, false, Image.FORMAT_RGBA8)

	# Fill with tile data
	for coords in tile_data.keys():
		var tile = tile_data[coords]
		var pixel_x = int(coords.x - min_x)
		var pixel_y = int(coords.y - min_y)

		var color = _get_tile_color(tile, coords)
		minimap_image.set_pixel(pixel_x, pixel_y, color)

	# Create texture
	minimap_texture = ImageTexture.create_from_image(minimap_image)
	minimap_texture_rect.texture = minimap_texture

	Log.log_info("Minimap: Generated %dx%d map" % [world_width, world_height])

func _get_tile_color(tile: Dictionary, coords: Vector2i) -> Color:
	"""Get the color for a tile based on current display mode."""
	match current_mode:
		DisplayMode.TERRAIN:
			return _get_terrain_color(tile.terrain_id)
		DisplayMode.CIVILIZATIONS:
			var civ_id = tile.get("civ_id", -1)
			if civ_id >= 0:
				return world_map.CIV_COLORS[civ_id % world_map.CIV_COLORS.size()]
			else:
				return _get_terrain_color(tile.terrain_id).darkened(0.5)
		DisplayMode.RESOURCES:
			return _get_resource_density_color(tile)

	return Color.BLACK

func _get_terrain_color(terrain_id: int) -> Color:
	"""Get a color representing the terrain type."""
	match terrain_id:
		0: return Color(0.2, 0.4, 0.8)  # Water - blue
		1: return Color(0.8, 0.7, 0.4)  # Sand - tan
		2: return Color(0.3, 0.7, 0.3)  # Grass - green
		3: return Color(0.2, 0.5, 0.2)  # Forest - dark green
		4: return Color(0.6, 0.5, 0.3)  # Hills - brown
		5: return Color(0.5, 0.5, 0.5)  # Stone - gray
		6: return Color(0.4, 0.4, 0.4)  # Mountains - dark gray
		7: return Color(0.1, 0.2, 0.5)  # Deep sea - dark blue
		8: return Color(0.2, 0.1, 0.2)  # Chasm - purple-black
		9: return Color(0.9, 0.3, 0.1)  # Lava - red-orange
		10: return Color(0.9, 0.9, 1.0)  # Snow peak - white
		11: return Color(0.7, 0.8, 0.9)  # Ice water - light blue
		12: return Color(0.4, 0.6, 0.8)  # Cold water - cool blue
		13: return Color(0.2, 0.6, 0.3)  # Jungle - vibrant green
		14: return Color(0.7, 0.7, 0.4)  # Dry grassland - yellow-green
		15: return Color(0.6, 0.6, 0.7)  # Rocky peak - blue-gray
	return Color.BLACK

func _get_resource_density_color(tile: Dictionary) -> Color:
	"""Get color based on resource density."""
	var resources = tile.get("resources", {})
	var total = 0

	for res_type in resources.keys():
		total += resources[res_type].get("amount", 0)

	# Color from black (no resources) to yellow (high resources)
	var intensity = clamp(total / 500.0, 0.0, 1.0)
	return Color(intensity, intensity * 0.8, 0, 1.0)

func _process(_delta):
	"""Update camera indicator position."""
	# Only update if we have valid data and are visible
	if not visible or not world_map or not minimap_texture:
		return

	_update_camera_indicator()

func _update_camera_indicator():
	"""Update the camera view rectangle on minimap."""
	var camera = world_map.camera
	var viewport_size = get_viewport_rect().size

	# Get camera bounds in world space
	var camera_half_size = viewport_size / (camera.zoom * 2.0)
	var camera_top_left = camera.position - camera_half_size
	var camera_bottom_right = camera.position + camera_half_size

	# Convert to tile coordinates
	var top_left_tile = world_map.tile_map.local_to_map(camera_top_left)
	var bottom_right_tile = world_map.tile_map.local_to_map(camera_bottom_right)

	# Find world bounds
	var tile_data = world_map._tile_data
	var min_x = INF
	var max_x = -INF
	var min_y = INF
	var max_y = -INF

	for coords in tile_data.keys():
		min_x = min(min_x, coords.x)
		max_x = max(max_x, coords.x)
		min_y = min(min_y, coords.y)
		max_y = max(max_y, coords.y)

	var world_width = max_x - min_x + 1
	var world_height = max_y - min_y + 1

	# Convert to minimap pixel coordinates
	var minimap_rect = minimap_texture_rect.get_rect()
	var scale_x = minimap_rect.size.x / world_width
	var scale_y = minimap_rect.size.y / world_height

	var indicator_pos = Vector2(
		(top_left_tile.x - min_x) * scale_x,
		(top_left_tile.y - min_y) * scale_y
	)

	var indicator_size = Vector2(
		(bottom_right_tile.x - top_left_tile.x) * scale_x,
		(bottom_right_tile.y - top_left_tile.y) * scale_y
	)

	camera_indicator.position = indicator_pos
	camera_indicator.size = indicator_size

func _on_minimap_clicked(event: InputEvent):
	"""Handle clicks on the minimap."""
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# Get click position relative to minimap
			var click_pos = event.position
			var minimap_rect = minimap_texture_rect.get_rect()

			# Find world bounds
			var tile_data = world_map._tile_data
			var min_x = INF
			var max_x = -INF
			var min_y = INF
			var max_y = -INF

			for coords in tile_data.keys():
				min_x = min(min_x, coords.x)
				max_x = max(max_x, coords.x)
				min_y = min(min_y, coords.y)
				max_y = max(max_y, coords.y)

			var world_width = max_x - min_x + 1
			var world_height = max_y - min_y + 1

			# Convert click to tile coordinates
			var scale_x = world_width / minimap_rect.size.x
			var scale_y = world_height / minimap_rect.size.y

			var tile_x = int(click_pos.x * scale_x + min_x)
			var tile_y = int(click_pos.y * scale_y + min_y)
			var tile_coords = Vector2i(tile_x, tile_y)

			# Jump camera to this location
			world_map.snap_camera_to_coords(tile_coords)
			Log.log_info("Minimap: Jumped to %s" % tile_coords)

func change_mode(mode: DisplayMode):
	"""Change the minimap display mode."""
	current_mode = mode
	_generate_minimap()
	Log.log_info("Minimap: Changed to mode %d" % mode)

func refresh():
	"""Regenerate the minimap (call after world changes)."""
	_generate_minimap()
