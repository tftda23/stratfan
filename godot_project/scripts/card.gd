extends Resource
class_name Card

# Card metadata
@export var card_name: String = "Unknown Card"
@export var card_description: String = "No description"
@export var mana_cost: int = 1
@export var card_type: String = "action"  # action, boon, bane, summon, terrain

# Card rarity
enum Rarity {
	COMMON,     # Gray
	UNCOMMON,   # Green
	RARE,       # Blue
	EPIC,       # Purple
	LEGENDARY   # Gold
}
@export var rarity: Rarity = Rarity.COMMON

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

func get_rarity_color() -> Color:
	"""Get the border color for this card's rarity."""
	match rarity:
		Rarity.COMMON:
			return Color(0.6, 0.6, 0.6)  # Gray
		Rarity.UNCOMMON:
			return Color(0.3, 0.9, 0.3)  # Green
		Rarity.RARE:
			return Color(0.3, 0.6, 1.0)  # Blue
		Rarity.EPIC:
			return Color(0.7, 0.3, 0.9)  # Purple
		Rarity.LEGENDARY:
			return Color(1.0, 0.8, 0.2)  # Gold
	return Color.WHITE

func get_rarity_name() -> String:
	"""Get the rarity name as a string."""
	return Rarity.keys()[rarity]

func apply_effect(world_map, target_coords: Vector2i) -> bool:
	"""Apply this card's effect to the target location."""
	# Create visual effect at target position
	var world_pos = world_map.tile_map.map_to_local(target_coords)
	CardVisualEffects.create_effect_at_position(effect_type, world_pos, world_map)

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
		"summon_warriors":
			return _apply_summon_warriors(world_map, target_coords)
		"add_stockpile":
			return _apply_add_stockpile(world_map, target_coords)
		"damage_units":
			return _apply_damage_units(world_map, target_coords)
		"damage_buildings":
			return _apply_damage_buildings(world_map, target_coords)
		"damage_all":
			return _apply_damage_all(world_map, target_coords)
		"damage_single":
			return _apply_damage_single(world_map, target_coords)
		"heal_units":
			return _apply_heal_units(world_map, target_coords)
		"heal_buildings":
			return _apply_heal_buildings(world_map, target_coords)
		"destroy_resource":
			return _apply_destroy_resource(world_map, target_coords)
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
	var tiles = get_affected_tiles(world_map, target_coords)

	if tiles.is_empty():
		tiles = [target_coords]

	for i in range(num_citizens):
		var spawn_tile = tiles[i % tiles.size()]
		world_map._spawn_single_citizen(spawn_tile, GameManager.player_civ_id)

	return true

func _apply_summon_warriors(world_map, target_coords: Vector2i) -> bool:
	"""Summon warrior units at target location."""
	var num_warriors = effect_power
	var tiles = get_affected_tiles(world_map, target_coords)

	if tiles.is_empty():
		tiles = [target_coords]

	# Load warrior script
	var WarriorScript = load("res://scripts/warrior.gd")

	for i in range(num_warriors):
		var spawn_tile = tiles[i % tiles.size()]
		var warrior = CharacterBody2D.new()
		warrior.set_script(WarriorScript)
		warrior.civ_id = GameManager.player_civ_id
		world_map.add_child(warrior)
		warrior.set_current_tile_coords(spawn_tile)
		Log.log_info("Card: Summoned warrior at %s" % spawn_tile)

	return true

func _apply_add_stockpile(world_map, target_coords: Vector2i) -> bool:
	"""Add resources directly to player stockpile."""
	var resource_type = effect_data.get("resource_type", "food")
	var amount = effect_power

	GameManager.add_player_resources(resource_type, amount)
	Log.log_info("Card: Added %d %s to player stockpile" % [amount, resource_type])
	NotificationManager.notify_success("+%d %s" % [amount, resource_type.capitalize()])

	return true

func _apply_damage_units(world_map, target_coords: Vector2i) -> bool:
	"""Deal damage to units in area."""
	var tiles = get_affected_tiles(world_map, target_coords)
	if tiles.is_empty() and target_type == "global":
		# Global targeting - damage all enemy units
		for child in world_map.get_children():
			if child.is_in_group("citizens") and child.civ_id != GameManager.player_civ_id:
				child.health -= effect_power
				if child.health <= 0:
					child.queue_free()
		return true

	var damaged = 0
	for tile in tiles:
		for child in world_map.get_children():
			if child.is_in_group("citizens"):
				if child.current_tile_coords == tile and child.civ_id != GameManager.player_civ_id:
					child.health -= effect_power
					damaged += 1
					if child.health <= 0:
						child.queue_free()

	Log.log_info("Card: Damaged %d units" % damaged)
	return true

func _apply_damage_buildings(world_map, target_coords: Vector2i) -> bool:
	"""Deal damage to buildings in area."""
	# Buildings not implemented yet - placeholder
	Log.log_info("Card: Damage buildings (not yet implemented)")
	return true

func _apply_damage_all(world_map, target_coords: Vector2i) -> bool:
	"""Deal damage to both units and buildings."""
	_apply_damage_units(world_map, target_coords)
	_apply_damage_buildings(world_map, target_coords)
	return true

func _apply_damage_single(world_map, target_coords: Vector2i) -> bool:
	"""Deal damage to single unit or building at target."""
	for child in world_map.get_children():
		if child.is_in_group("citizens"):
			if child.current_tile_coords == target_coords:
				child.health -= effect_power
				if child.health <= 0:
					child.queue_free()
				return true
	return true

func _apply_heal_units(world_map, target_coords: Vector2i) -> bool:
	"""Restore HP to units."""
	var tiles = get_affected_tiles(world_map, target_coords)

	if tiles.is_empty() and target_type == "global":
		# Global targeting - heal all player units
		for child in world_map.get_children():
			if child.is_in_group("citizens") and child.civ_id == GameManager.player_civ_id:
				child.health = min(child.max_health, child.health + effect_power)
		return true

	var healed = 0
	for tile in tiles:
		for child in world_map.get_children():
			if child.is_in_group("citizens"):
				if child.current_tile_coords == tile and child.civ_id == GameManager.player_civ_id:
					child.health = min(child.max_health, child.health + effect_power)
					healed += 1

	Log.log_info("Card: Healed %d units" % healed)
	return true

func _apply_heal_buildings(world_map, target_coords: Vector2i) -> bool:
	"""Restore HP to buildings."""
	# Buildings not implemented yet - placeholder
	Log.log_info("Card: Heal buildings (not yet implemented)")
	return true

func _apply_destroy_resource(world_map, target_coords: Vector2i) -> bool:
	"""Destroy specific resource type in area."""
	var resource_type = effect_data.get("resource_type", "food")
	var tiles = get_affected_tiles(world_map, target_coords)

	for tile in tiles:
		if world_map._tile_data.has(tile):
			var tile_data = world_map._tile_data[tile]
			if tile_data.has("resources") and tile_data.resources.has(resource_type):
				tile_data.resources[resource_type]["amount"] = 0

	Log.log_info("Card: Destroyed %s in %d tiles" % [resource_type, tiles.size()])
	return true
