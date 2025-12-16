extends Node2D

@onready var tile_map = $TileMap
@onready var civ_overlay_map = $CivOverlayMap
@onready var landmarks_map = $LandmarksMap
@onready var world_gen_ui = $CanvasLayer/WorldGenUI
@onready var camera = $Camera2D

@export var width = 1000
@export var height = 1000
@export var world_seed = 0

var generator: WorldGenerator = null # Keep a reference to the generator

var _tile_data: Dictionary = {}
var _civ_territories: Dictionary = {}
var _civ_capitals: Dictionary = {}

var _world_min_x = 0.0

var _world_max_x = 0.0
var _world_min_y = 0.0
var _world_max_y = 0.0

var _min_zoom = Vector2(1, 1)
var _max_zoom = Vector2(4, 4) # Arbitrary max zoom for now, can be adjusted.

var is_panning = false
const EDGE_SCROLL_MARGIN = 50
const EDGE_SCROLL_SPEED = 300

var last_hovered_tile: Vector2i = Vector2i(-9999, -9999) # Track last hovered tile

# Card targeting
var is_targeting_card: bool = false
var targeting_card: Card = null
var target_preview_tiles: Array[Vector2i] = []

# Tileset style selection
enum TilesetStyle {
	ORIGINAL,
	FANTASY_BORDERED,
	FANTASY_BORDERLESS
}
var current_tileset_style: TilesetStyle = TilesetStyle.ORIGINAL

# Pre-defined colors for civilizations
const CIV_COLORS = [
	Color(1, 0, 0, 0.6), Color(0, 1, 0, 0.6), Color(0, 0, 1, 0.6),
	Color(1, 1, 0, 0.6), Color(0, 1, 1, 0.6), Color(1, 0, 1, 0.6),
	Color(1, 0.5, 0, 0.6), Color(0.5, 0, 1, 0.6)
]

var WorldGeneratorScript = preload("res://scripts/world_generator.gd")

var _terrain_tile_source_ids = {} # New member variable to store the mapping

# Names corresponding to terrain_id for file naming (must match generate_tiles.py)
const TERRAIN_NAMES = {
	0: "water", 1: "sand", 2: "grass", 3: "forest", 4: "hills",
	5: "stone", 6: "mountains", 7: "deep_sea", 8: "chasm", 9: "lava",
	10: "snow_peak", 11: "ice_water", 12: "cold_water", 13: "jungle",
	14: "dry_grassland", 15: "rocky_peak"
}

# Rivers are allowed on these terrain_ids (must match generate_tiles.py)
const ALLOWS_RIVERS = [2, 3, 4, 5, 6, 10, 13, 14, 15]


func _ready():
	WorldManager.world_map_node = self # Register world_map instance with WorldManager
	Log.log_info("world_map.gd: _ready() called.")
	# Setup TileSets
	_create_terrain_tileset() # Call to setup tile_map.tile_set and _terrain_tile_source_ids
	Log.log_info("world_map.gd: _create_terrain_tileset() completed.")
	civ_overlay_map.tile_set = _create_civ_tileset()
	Log.log_info("world_map.gd: _create_civ_tileset() completed.")
	landmarks_map.tile_set = _create_landmark_tileset()
	Log.log_info("world_map.gd: _create_landmark_tileset() completed.")
	
	# Connect UI signal
	Log.log_info("world_map.gd: Connecting UI signal.")
	world_gen_ui.generate_world.connect(regenerate_world)
	Log.log_info("world_map.gd: UI signal connected. Calling generate_world().")
	generate_world() # No longer passing terrain_tile_source_ids
	Log.log_info("world_map.gd: generate_world() called from _ready().")

func regenerate_world(new_seed):
	Log.log_info("world_map.gd: regenerate_world() called with new_seed: %d." % new_seed)
	world_seed = new_seed
	_create_terrain_tileset() # Call to refresh tile_map.tile_set and _terrain_tile_source_ids
	Log.log_info("world_map.gd: _create_terrain_tileset() completed in regenerate_world().")
	generate_world() # No longer passing terrain_tile_source_ids
	Log.log_info("world_map.gd: generate_world() called from regenerate_world().")

func change_tileset_style(style: TilesetStyle):
	Log.log_info("world_map.gd: Changing tileset style to %d." % style)
	current_tileset_style = style
	_create_terrain_tileset()
	# Redraw the map with the new tileset
	_redraw_terrain()

func _redraw_terrain():
	# Redraw all tiles with the current tileset
	tile_map.clear()
	for coords in _tile_data.keys():
		var tile = _tile_data[coords]
		var terrain_id = tile.terrain_id
		var has_river = tile.has_river
		var source_id_key = str(terrain_id) + "_" + str(has_river)
		var source_id = _terrain_tile_source_ids.get(source_id_key)
		if source_id == null:
			source_id_key = str(terrain_id) + "_false"
			source_id = _terrain_tile_source_ids.get(source_id_key)
		if source_id != null:
			tile_map.set_cell(0, coords, source_id, Vector2i(0, 0))
	Log.log_info("world_map.gd: Terrain redrawn with new tileset style.")

# Removed _create_hexagon_image as we are loading textures now

func _create_landmark_tileset() -> TileSet:
	var tile_set = TileSet.new()
	tile_set.tile_shape = TileSet.TILE_SHAPE_HEXAGON
	tile_set.tile_layout = TileSet.TILE_LAYOUT_STACKED
	tile_set.tile_offset_axis = TileSet.TILE_OFFSET_AXIS_VERTICAL
	tile_set.tile_size = Vector2i(16, 16)
	
	var landmark_defs = {
		"castle": {"color": Color.DARK_VIOLET},
		"village": {"color": Color.SADDLE_BROWN},
		"ruins": {"color": Color.DARK_SLATE_GRAY},
	}
	
	var source_id = 0
	for landmark_name in landmark_defs.keys():
		var definition = landmark_defs[landmark_name]
		# For landmarks, we can still use simple shapes or load textures too if desired
		var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(Color.TRANSPARENT)
		img.fill_rect(Rect2i(4, 4, 8, 8), definition.color)
		img.fill_rect(Rect2i(6, 2, 4, 12), definition.color)
		img.fill_rect(Rect2i(2, 6, 12, 4), definition.color)

		var texture = ImageTexture.create_from_image(img)
		var source = TileSetAtlasSource.new()
		source.texture = texture
		source.create_tile(Vector2i(0, 0))
		tile_set.add_source(source, source_id)
		source_id += 1
		
	return tile_set

# Removed _create_river_hexagon_image as we are loading river textures now

func _create_terrain_tileset():
	Log.log_info("world_map.gd: _create_terrain_tileset() called.")
	var tile_set = TileSet.new()
	tile_set.tile_shape = TileSet.TILE_SHAPE_HEXAGON
	tile_set.tile_layout = TileSet.TILE_LAYOUT_STACKED
	tile_set.tile_offset_axis = TileSet.TILE_OFFSET_AXIS_VERTICAL

	# Determine tile art path and size based on current tileset style
	var tile_art_path: String
	var tile_size: Vector2i

	match current_tileset_style:
		TilesetStyle.ORIGINAL:
			tile_art_path = "res://assets/tile_art/"
			tile_size = Vector2i(16, 16)
		TilesetStyle.FANTASY_BORDERED:
			tile_art_path = "res://assets/tile_art/fantasy_bordered/"
			tile_size = Vector2i(32, 32)
		TilesetStyle.FANTASY_BORDERLESS:
			tile_art_path = "res://assets/tile_art/fantasy_borderless/"
			tile_size = Vector2i(32, 32)

	tile_set.tile_size = tile_size
	Log.log_info("world_map.gd: Using tileset style %d with path: %s" % [current_tileset_style, tile_art_path])
	
	_terrain_tile_source_ids.clear()
	var source_id_counter = 0

	Log.log_info("world_map.gd: _create_terrain_tileset() - starting terrain type loop for 0-15.")
	for terrain_id in range(0, 16): # Iterate through all possible terrain_ids (0 to 15)
		if not TERRAIN_NAMES.has(terrain_id):
			Log.log_warning("world_map.gd: No name defined for terrain_id %d in TERRAIN_NAMES." % terrain_id)
			continue
		
		var name = TERRAIN_NAMES[terrain_id]
		
		# Load normal tile texture
		var texture_path = tile_art_path + name + ".png"
		var texture_normal = load(texture_path)

		# Fallback to original tileset if fantasy tiles are missing
		if texture_normal == null and current_tileset_style != TilesetStyle.ORIGINAL:
			var fallback_path = "res://assets/tile_art/" + name + ".png"
			texture_normal = load(fallback_path)
			if texture_normal != null:
				Log.log_warning("world_map.gd: Using fallback texture %s for terrain_id %d." % [fallback_path, terrain_id])

		if texture_normal == null:
			Log.log_error("world_map.gd: Failed to load texture: %s for terrain_id %d." % [texture_path, terrain_id])
			continue
		
		var source_normal = TileSetAtlasSource.new()
		source_normal.texture = texture_normal
		source_normal.create_tile(Vector2i(0, 0))
		tile_set.add_source(source_normal, source_id_counter)
		_terrain_tile_source_ids[str(terrain_id) + "_false"] = source_id_counter # Key: "terrain_id_has_river"
		source_id_counter += 1
		
		# Load river variant if allowed
		if terrain_id in ALLOWS_RIVERS:
			var river_texture_path = tile_art_path + name + "_river.png"
			var texture_river = load(river_texture_path)
			if texture_river == null:
				Log.log_error("world_map.gd: Failed to load river texture: %s for terrain_id %d." % [river_texture_path, terrain_id])
			else:
				var source_river = TileSetAtlasSource.new()
				source_river.texture = texture_river
				source_river.create_tile(Vector2i(0, 0))
				tile_set.add_source(source_river, source_id_counter)
				_terrain_tile_source_ids[str(terrain_id) + "_true"] = source_id_counter # Key: "terrain_id_has_river"
				source_id_counter += 1
			
	Log.log_info("world_map.gd: _create_terrain_tileset() - finished terrain type loop.")
	tile_map.tile_set = tile_set # Assign the created tile_set to tile_map
	# _terrain_tile_source_ids is already assigned above within the loop
	Log.log_info("world_map.gd: _create_terrain_tileset() finished.")


func _create_civ_tileset() -> TileSet:
	var tile_set = TileSet.new()
	tile_set.tile_shape = TileSet.TILE_SHAPE_HEXAGON
	tile_set.tile_layout = TileSet.TILE_LAYOUT_STACKED
	tile_set.tile_offset_axis = TileSet.TILE_OFFSET_AXIS_VERTICAL
	tile_set.tile_size = Vector2i(16, 16)

	var source_id = 0
	for civ_color in CIV_COLORS:
		# Create a circular/organic shape instead of hex shape
		var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)

		# Fill with transparent first
		img.fill(Color(0, 0, 0, 0))

		# Draw a soft circular gradient for more organic look
		var center = Vector2(8, 8)
		var radius = 7.0
		for y in range(16):
			for x in range(16):
				var pos = Vector2(x, y)
				var dist = pos.distance_to(center)
				if dist < radius:
					# Smooth falloff at edges
					var alpha = 0.3 * (1.0 - (dist / radius) * 0.3)
					img.set_pixel(x, y, Color(civ_color.r, civ_color.g, civ_color.b, alpha))

		var texture = ImageTexture.create_from_image(img)
		var source = TileSetAtlasSource.new()
		source.texture = texture
		source.create_tile(Vector2i(0, 0))
		tile_set.add_source(source, source_id)
		source_id += 1

	return tile_set

func generate_world(): # Removed terrain_tile_source_ids parameter
	Log.log_info("world_map.gd: generate_world() starting. Width: %d, Height: %d, Seed: %d" % [width, height, world_seed])
	
	# The tile_map.tile_set is already set in _ready or regenerate_world
	# with the correct tile_set returned by _create_terrain_tileset()

	tile_map.clear()
	civ_overlay_map.clear()
	landmarks_map.clear()
	Log.log_info("world_map.gd: TileMaps cleared.")
	generator = WorldGeneratorScript.new(width, height, world_seed)
	Log.log_info("world_map.gd: WorldGeneratorScript instance created.")
	
	var terrain_result = generator.generate_terrain()
	_tile_data = terrain_result[0]
	var land_tiles = terrain_result[1]
	Log.log_info("world_map.gd: Terrain generation completed. Number of tiles: %d, Land tiles: %d." % [_tile_data.size(), land_tiles.size()])
	
	for coords in _tile_data.keys():
		var data = _tile_data[coords]
		var source_id_key = str(data.terrain_id) + "_" + str(data.has_river)
		var source_id = _terrain_tile_source_ids[source_id_key]
		tile_map.set_cell(0, coords, source_id, Vector2i(0, 0))
	Log.log_info("world_map.gd: Terrain tiles populated.")

	var civ_result = generator.generate_civs(_tile_data, land_tiles)
	_tile_data = civ_result[0]
	_civ_territories = civ_result[1]
	_civ_capitals = civ_result[2]
	Log.log_info("world_map.gd: Civ generation completed. Number of civs: %d." % _civ_territories.size())
	
	# Select a player civ and update GameManager
	if _civ_territories.size() > 0:
		var player_civ_id = _civ_territories.keys()[0] # Pick the first civ
		GameManager.set_player_civ(player_civ_id)
		
		var aggregated_resources = {}
		for coord in _civ_territories[player_civ_id]:
			var tile_resources = _tile_data[coord].resources
			for res_name in tile_resources.keys():
				# Ensure 'amount' key exists before accessing
				if tile_resources[res_name].has("amount"):
					aggregated_resources[res_name] = aggregated_resources.get(res_name, 0) + tile_resources[res_name].amount
				else:
					Log.log_warning("world_map.gd: Resource '%s' on tile %s for civ %d has no 'amount' key." % [res_name, str(coord), player_civ_id])
		
		GameManager.set_player_resources(aggregated_resources)
		Log.log_info("world_map.gd: Player civ %d assigned with resources: %s." % [player_civ_id, aggregated_resources])


	for civ_id in _civ_territories.keys():
		for coord in _civ_territories[civ_id]:
			civ_overlay_map.set_cell(0, coord, civ_id, Vector2i(0, 0))
	Log.log_info("world_map.gd: Civ overlay populated.")

	_spawn_citizens() # New function call to spawn citizens

	# Set camera to the first civ's location
	if _civ_capitals.size() > 0:
		var first_civ_id = _civ_capitals.keys()[0]
		var first_civ_tile_coord = _civ_capitals[first_civ_id]
		var civ_pixel_pos = tile_map.map_to_local(first_civ_tile_coord)
		camera.position = civ_pixel_pos
		camera.zoom = _min_zoom # Start with the entire map visible
		Log.log_info("world_map.gd: Camera set to initial civ location: %s" % civ_pixel_pos)

	var landmarks = generator.generate_landmarks(_tile_data, land_tiles, _civ_territories)
	for coord in landmarks.keys():
		landmarks_map.set_cell(0, coord, landmarks[coord], Vector2i(0, 0))
	Log.log_info("world_map.gd: Landmarks populated. Number of landmarks: %d." % landmarks.size())
		
	# Generate rivers
	Log.log_info("world_map.gd: Calling generate_rivers().")
	_tile_data = generator.generate_rivers(_tile_data, land_tiles)
	Log.log_info("world_map.gd: generate_rivers() completed.")
	
	_calculate_world_boundaries()
	Log.log_info("world_map.gd: World boundaries calculated.")
	Log.log_info("world_map.gd: generate_world() finished.")

# Preload Citizen scene
const CITIZEN_SCENE = preload("res://scenes/citizen.tscn")

func _spawn_citizens():
	# Clear existing citizens if regenerating world
	for child in get_children():
		if child.is_in_group("citizens"):
			child.queue_free()
	
	for civ_id in _civ_capitals.keys():
		var capital_coords = _civ_capitals[civ_id]
		var num_citizens_to_spawn = 3 # Example: spawn 3 citizens per civ
		
		for i in range(num_citizens_to_spawn):
			var citizen = CITIZEN_SCENE.instantiate()
			citizen.civ_id = civ_id
			add_child(citizen)
			GameManager.add_citizen_to_civ(civ_id) # Register citizen with GameManager
			citizen.set_current_tile_coords(capital_coords)
			citizen.name = "Citizen_Civ%d_%d" % [civ_id, i]
			Log.log_info("Spawned Citizen %s for Civ %d at %s." % [citizen.name, civ_id, capital_coords])


func _calculate_world_boundaries():
	if not tile_map.get_used_rect().has_area():
		Log.log_warning("world_map.gd: TileMap has no used area, cannot calculate boundaries.")
		return

	var used_rect = tile_map.get_used_rect()
	var tile_size = tile_map.tile_set.tile_size # This is the base size, for hex it's the bounding box

	# Get the local position of the top-left corner of the top-leftmost tile
	var top_left_tile_coord = used_rect.position
	var top_left_local_pos = tile_map.map_to_local(top_left_tile_coord)

	# Get the local position of the bottom-right corner of the bottom-rightmost tile
	# For hex tiles, width is `tile_size.x`, height is `tile_size.y * 0.75` for vertical stacking,
	# but `map_to_local` gives the center. Need to add half tile extent.
	var bottom_right_tile_coord = used_rect.position + used_rect.size - Vector2i(1, 1)
	var bottom_right_local_pos = tile_map.map_to_local(bottom_right_tile_coord)
	
	# Adjust for hex tile dimensions and origin point (usually center)
	# Assuming map_to_local gives the center of the tile.
	# The actual width of a hex tile from point-to-point is tile_size.x
	# The actual height of a hex tile from flat-to-flat is tile_size.y
	# If stacked vertically, vertical distance between centers is tile_size.y * 0.75
	# Horizontal distance is tile_size.x

	# For now, a simpler bounding box based on extremes of map_to_local and adding half a tile.
	# This might need fine-tuning based on exact hex tile rendering.
	_world_min_x = top_left_local_pos.x - tile_size.x / 2.0
	_world_max_x = bottom_right_local_pos.x + tile_size.x / 2.0
	_world_min_y = top_left_local_pos.y - tile_size.y / 2.0
	_world_max_y = bottom_right_local_pos.y + tile_size.y / 2.0
	
	Log.log_info("world_map.gd: World Boundaries calculated: X(%f, %f), Y(%f, %f)" % [_world_min_x, _world_max_x, _world_min_y, _world_max_y])
	_update_zoom_limits()

func _update_zoom_limits():
	var world_width = _world_max_x - _world_min_x
	var world_height = _world_max_y - _world_min_y
	
	var viewport_size_current = get_viewport_rect().size # Renamed to avoid conflict
	
	if world_width <= 0 or world_height <= 0 or viewport_size_current.x <= 0 or viewport_size_current.y <= 0:
		Log.log_warning("world_map.gd: Invalid dimensions for zoom limit calculation.")
		return

	var min_zoom_x = viewport_size_current.x / world_width
	var min_zoom_y = viewport_size_current.y / world_height
	
	# Choose the smaller zoom to ensure the entire map fits, with a small margin
	_min_zoom = Vector2(min(min_zoom_x, min_zoom_y), min(min_zoom_x, min_zoom_y))
	
	Log.log_info("world_map.gd: Zoom limits updated: Min Zoom: %s, Max Zoom: %s" % [_min_zoom, _max_zoom])

# Methods for Citizens and other game elements to interact with the map data
func get_world_data() -> Dictionary:
	return _tile_data

func map_to_local(coords: Vector2i) -> Vector2:
	return tile_map.map_to_local(coords)

func get_resource_amount(coords: Vector2i, resource_type: String) -> int:
	if _tile_data.has(coords):
		var tile = _tile_data[coords]
		if tile.has("resources") and tile.resources.has(resource_type):
			return tile.resources[resource_type].amount
	return 0

func deplete_resource(coords: Vector2i, resource_type: String, amount: int) -> int:
	if _tile_data.has(coords):
		var tile = _tile_data[coords]
		if tile.has("resources") and tile.resources.has(resource_type):
			var current_amount = tile.resources[resource_type].amount
			var depleted = min(current_amount, amount) # Use min for integer min
			tile.resources[resource_type].amount -= depleted
			# TODO: Potentially emit a signal here to update resource visuals if implemented
			return depleted
	return 0

func get_civ_capital_coords(civ_id: int) -> Vector2i:
	if _civ_capitals.has(civ_id):
		return _civ_capitals[civ_id]
	return Vector2i.ZERO # Return zero or handle error if capital not found

func get_path_from_world_coords(start_coords: Vector2i, end_coords: Vector2i) -> Array[Vector2i]:
	if generator:
		return generator.find_path(start_coords, end_coords, _tile_data)
	return []

func snap_camera_to_coords(coords: Vector2i):
	var world_pixel_pos = tile_map.map_to_local(coords)
	camera.position = world_pixel_pos
	# Optional: Adjust zoom level when snapping, e.g., zoom to a predefined level
	# camera.zoom = Vector2(1.0, 1.0) # Example: set to a fixed zoom level

func _process(delta):
	var move_dir = Vector2.ZERO
	# Keyboard Pan
	if Input.is_action_pressed("camera_pan_right"): move_dir.x += 1
	if Input.is_action_pressed("camera_pan_left"): move_dir.x -= 1
	if Input.is_action_pressed("camera_pan_down"): move_dir.y += 1
	if Input.is_action_pressed("camera_pan_up"): move_dir.y -= 1
	
	# Edge Scroll
	var mouse_pos = get_viewport().get_mouse_position()
	var viewport_size_process = get_viewport().size # Renamed to avoid conflict
	if mouse_pos.x < EDGE_SCROLL_MARGIN: move_dir.x -= 1
	if mouse_pos.x > viewport_size_process.x - EDGE_SCROLL_MARGIN: move_dir.x += 1
	if mouse_pos.y < EDGE_SCROLL_MARGIN: move_dir.y -= 1
	if mouse_pos.y > viewport_size_process.y - EDGE_SCROLL_MARGIN: move_dir.y += 1

	camera.position += move_dir.normalized() * EDGE_SCROLL_SPEED * delta / camera.zoom.x

	# Clamp camera position to world boundaries
	var viewport_size = get_viewport_rect().size
	var camera_visible_half_width = (viewport_size.x / camera.zoom.x) / 2.0
	var camera_visible_half_height = (viewport_size.y / camera.zoom.y) / 2.0


	var min_x_clamp = _world_min_x + camera_visible_half_width
	var max_x_clamp = _world_max_x - camera_visible_half_width
	var min_y_clamp = _world_min_y + camera_visible_half_height
	var max_y_clamp = _world_max_y - camera_visible_half_height

	# Ensure the clamps are valid (world is larger than visible camera area)
	if min_x_clamp > max_x_clamp:
		# If the world is smaller than the camera's visible area, center it
		camera.position.x = (_world_min_x + _world_max_x) / 2.0
	else:
		camera.position.x = clamp(camera.position.x, min_x_clamp, max_x_clamp)

	if min_y_clamp > max_y_clamp:
		camera.position.y = (_world_min_y + _world_max_y) / 2.0
	else:
		camera.position.y = clamp(camera.position.y, min_y_clamp, max_y_clamp)

	# Update hover info based on mouse position
	_update_hover_info()


func _input(event):
	# Mouse Wheel Zoom
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: camera.zoom /= 1.2
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: camera.zoom *= 1.2
		# Middle mouse button panning start/stop
		if event.button_index == MOUSE_BUTTON_MIDDLE: is_panning = event.is_pressed()
	
	# Trackpad Pinch Zoom
	if event is InputEventMagnifyGesture:
		camera.zoom /= event.factor

	# Clamp zoom level
	camera.zoom = camera.zoom.clamp(_min_zoom, _max_zoom)
	
	# Mouse drag panning
	if event is InputEventMouseMotion and is_panning:
		camera.position -= event.relative / camera.zoom

func _update_hover_info():
	# Get mouse position in viewport
	var mouse_pos = get_viewport().get_mouse_position()

	# Convert to world coordinates (accounting for camera)
	var world_pos = camera.get_global_transform_with_canvas().affine_inverse() * mouse_pos

	# Convert world position to tile coordinates
	var tile_coords = tile_map.local_to_map(world_pos)

	# Check if we're hovering over a different tile
	if tile_coords != last_hovered_tile:
		last_hovered_tile = tile_coords

		# Check if this tile exists in our tile data
		if _tile_data.has(tile_coords):
			var tile_data = _tile_data[tile_coords]
			world_gen_ui.update_hover_info(tile_data, tile_coords)
		else:
			# Mouse is outside the valid tile area
			world_gen_ui.hide_hover_info()
	elif not _tile_data.has(tile_coords):
		# Make sure to hide if we're still outside valid tiles
		world_gen_ui.hide_hover_info()

	# Update card targeting preview
	if is_targeting_card and targeting_card:
		_update_target_preview(tile_coords)

func start_card_targeting(card: Card):
	"""Start targeting mode for playing a card."""
	is_targeting_card = true
	targeting_card = card
	Log.log_info("WorldMap: Started targeting for card '%s'" % card.card_name)

func cancel_card_targeting():
	"""Cancel card targeting mode."""
	is_targeting_card = false
	targeting_card = null
	target_preview_tiles.clear()
	_clear_target_preview()
	Log.log_info("WorldMap: Cancelled card targeting")

func _update_target_preview(tile_coords: Vector2i):
	"""Update the visual preview of which tiles will be affected."""
	if not targeting_card:
		return

	# Get affected tiles
	var affected = targeting_card.get_affected_tiles(self, tile_coords)

	# Clear old preview
	_clear_target_preview()

	# Store new preview tiles
	target_preview_tiles = affected

	# Visual feedback would go here (could highlight tiles, change colors, etc.)
	# For now just log
	if not affected.is_empty() and affected != target_preview_tiles:
		Log.log_info("WorldMap: Targeting %d tiles" % affected.size())

func _clear_target_preview():
	"""Clear target preview visuals."""
	# Would remove highlights here
	pass

func _unhandled_input(event: InputEvent):
	"""Handle card playing clicks."""
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if is_targeting_card and targeting_card:
				# Get clicked tile
				var mouse_pos = get_viewport().get_mouse_position()
				var world_pos = camera.get_global_transform_with_canvas().affine_inverse() * mouse_pos
				var tile_coords = tile_map.local_to_map(world_pos)

				if _tile_data.has(tile_coords):
					# Try to play the card
					if CardManager.play_card(targeting_card, tile_coords):
						Log.log_info("WorldMap: Played card at %s" % tile_coords)
						cancel_card_targeting()
					else:
						Log.log_warning("WorldMap: Failed to play card")

		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# Right click cancels targeting
			if is_targeting_card:
				cancel_card_targeting()

func _spawn_single_citizen(coords: Vector2i, civ_id: int):
	"""Spawn a single citizen at the given coordinates."""
	var citizen_scene = preload("res://scenes/citizen.tscn")
	var citizen = citizen_scene.instantiate()
	citizen.civ_id = civ_id
	add_child(citizen)
	citizen.set_current_tile_coords(coords)
	Log.log_info("WorldMap: Spawned citizen for civ %d at %s" % [civ_id, coords])