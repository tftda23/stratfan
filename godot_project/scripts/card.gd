extends Resource
class_name Card

# Card metadata
@export var card_name: String = "Unknown Card"
@export var card_description: String = "No description"
@export var mana_cost: int = 1
@export var card_type: String = "action"  # action, boon, bane, summon, terrain

# Card effect data
@export var effect_type: String = "none"  # terrain_change, resource_boost, destroy, freeze, etc.
@export var effect_power: int = 1
@export var target_type: String = "single"  # single, area_3, area_5, area_7, global
@export var terrain_change_to: int = -1  # -1 means no terrain change

# Visual
@export var card_color: Color = Color.WHITE
@export var icon_path: String = ""

# Card effect parameters
@export var effect_data: Dictionary = {}

func get_display_text() -> String:
	var text = "[b]%s[/b]\n" % card_name
	text += "[color=yellow]Cost: %d[/color]\n\n" % mana_cost
	text += "%s" % card_description
	return text

func apply_effect(world_map, target_coords: Vector2i) -> bool:
	"""Apply this card's effect to the target location."""
	match effect_type:
		"terrain_change":
			return _apply_terrain_change(world_map, target_coords)
		"resource_boost":
			return _apply_resource_boost(world_map, target_coords)
		"resource_add":
			return _apply_resource_add(world_map, target_coords)
		"destroy":
			return _apply_destroy(world_map, target_coords)
		"freeze":
			return _apply_freeze(world_map, target_coords)
		"boon":
			return _apply_boon(world_map, target_coords)
		"bane":
			return _apply_bane(world_map, target_coords)
		"summon_citizens":
			return _apply_summon_citizens(world_map, target_coords)
	return false

func get_affected_tiles(world_map, target_coords: Vector2i) -> Array[Vector2i]:
	"""Get all tiles that would be affected by playing this card."""
	var tiles: Array[Vector2i] = []

	match target_type:
		"single":
			tiles.append(target_coords)
		"area_3":
			tiles = _get_area_tiles(world_map, target_coords, 1)
		"area_5":
			tiles = _get_area_tiles(world_map, target_coords, 2)
		"area_7":
			tiles = _get_area_tiles(world_map, target_coords, 3)
		"global":
			# Global affects all tiles (return empty for now, handled specially)
			pass

	return tiles

func _get_area_tiles(world_map, center: Vector2i, radius: int) -> Array[Vector2i]:
	"""Get all tiles within radius of center using hex distance."""
	var tiles: Array[Vector2i] = [center]
	var visited = {center: true}
	var queue = [center]

	# Use hex neighbor function from generator
	var generator = world_map.generator
	if not generator:
		return tiles

	for r in range(radius):
		var new_queue = []
		for tile in queue:
			var neighbors = generator.get_hex_neighbors(tile)
			for neighbor in neighbors:
				if not visited.has(neighbor):
					visited[neighbor] = true
					tiles.append(neighbor)
					new_queue.append(neighbor)
		queue = new_queue

	return tiles

func _apply_terrain_change(world_map, target_coords: Vector2i) -> bool:
	"""Change terrain type of affected tiles."""
	if terrain_change_to < 0:
		return false

	var tiles = get_affected_tiles(world_map, target_coords)
	for tile in tiles:
		if world_map._tile_data.has(tile):
			world_map._tile_data[tile].terrain_id = terrain_change_to
			world_map._tile_data[tile].movement_cost = world_map.generator.TERRAIN_MOVEMENT_COSTS.get(terrain_change_to, 1.0)

	world_map._redraw_terrain()
	return true

func _apply_resource_boost(world_map, target_coords: Vector2i) -> bool:
	"""Multiply existing resources in area."""
	var tiles = get_affected_tiles(world_map, target_coords)
	var multiplier = effect_power

	for tile in tiles:
		if world_map._tile_data.has(tile):
			var tile_data = world_map._tile_data[tile]
			if tile_data.has("resources"):
				for resource_type in tile_data.resources.keys():
					var current = tile_data.resources[resource_type].get("amount", 0)
					tile_data.resources[resource_type]["amount"] = current * multiplier

	return true

func _apply_resource_add(world_map, target_coords: Vector2i) -> bool:
	"""Add specific resources to tiles."""
	var tiles = get_affected_tiles(world_map, target_coords)
	var resource_type = effect_data.get("resource_type", "food")
	var amount = effect_power * 50

	for tile in tiles:
		if world_map._tile_data.has(tile):
			var tile_data = world_map._tile_data[tile]
			if not tile_data.has("resources"):
				tile_data["resources"] = {}

			if tile_data.resources.has(resource_type):
				tile_data.resources[resource_type]["amount"] += amount
			else:
				tile_data.resources[resource_type] = {
					"amount": amount,
					"max_amount": amount * 2,
					"regeneration_rate": 0.0
				}

	return true

func _apply_destroy(world_map, target_coords: Vector2i) -> bool:
	"""Remove all resources and structures from area."""
	var tiles = get_affected_tiles(world_map, target_coords)

	for tile in tiles:
		if world_map._tile_data.has(tile):
			var tile_data = world_map._tile_data[tile]
			tile_data["resources"] = {}
			# Could also remove landmarks here if we want

	return true

func _apply_freeze(world_map, target_coords: Vector2i) -> bool:
	"""Freeze tiles (change to ice/snow terrain)."""
	var tiles = get_affected_tiles(world_map, target_coords)

	for tile in tiles:
		if world_map._tile_data.has(tile):
			var current_terrain = world_map._tile_data[tile].terrain_id
			# Change water to ice_water, land to snow_peak
			if current_terrain in [0, 7]:  # Water or deep sea
				world_map._tile_data[tile].terrain_id = 11  # Ice water
			elif current_terrain > 1:  # Land
				world_map._tile_data[tile].terrain_id = 10  # Snow peak

	world_map._redraw_terrain()
	return true

func _apply_boon(world_map, target_coords: Vector2i) -> bool:
	"""Apply positive effect to civilization's territory."""
	var tiles = get_affected_tiles(world_map, target_coords)

	# Boost all resources in civ territory
	for tile in tiles:
		if world_map._tile_data.has(tile):
			var tile_data = world_map._tile_data[tile]
			if tile_data.get("civ_id", -1) == GameManager.player_civ_id:
				# Double resources
				if tile_data.has("resources"):
					for resource_type in tile_data.resources.keys():
						var current = tile_data.resources[resource_type].get("amount", 0)
						tile_data.resources[resource_type]["amount"] = current * 2

	return true

func _apply_bane(world_map, target_coords: Vector2i) -> bool:
	"""Apply negative effect - reduce enemy resources."""
	var tiles = get_affected_tiles(world_map, target_coords)

	for tile in tiles:
		if world_map._tile_data.has(tile):
			var tile_data = world_map._tile_data[tile]
			var civ_id = tile_data.get("civ_id", -1)
			# Only affect enemy civilizations
			if civ_id >= 0 and civ_id != GameManager.player_civ_id:
				if tile_data.has("resources"):
					for resource_type in tile_data.resources.keys():
						var current = tile_data.resources[resource_type].get("amount", 0)
						tile_data.resources[resource_type]["amount"] = max(0, current / 2)

	return true

func _apply_summon_citizens(world_map, target_coords: Vector2i) -> bool:
	"""Summon new citizens at target location."""
	var num_citizens = effect_power

	for i in range(num_citizens):
		world_map._spawn_single_citizen(target_coords, GameManager.player_civ_id)

	return true
