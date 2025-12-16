extends CharacterBody2D

class_name Citizen

@export var civ_id: int = -1
@export var speed: float = 50.0

var current_tile_coords: Vector2i
var target_tile_coords: Vector2i
var path: Array = [] # Stores path in tile coordinates
var current_resource_target: Vector2i
var current_resource_type: String
var inventory: Dictionary = {}

enum State {
	IDLE,
	MOVING_TO_RESOURCE,
	GATHERING,
	MOVING_TO_CIV,
	DEFENDING, # Future
	ATTACKING, # Future
	EXPANDING, # Future
}

var current_state: State = State.IDLE

const CIV_COLORS = [
	Color(1, 0, 0, 1.0), Color(0, 1, 0, 1.0), Color(0, 0, 1, 1.0),
	Color(1, 1, 0, 1.0), Color(0, 1, 1, 1.0), Color(1, 0, 1, 1.0),
	Color(1, 0.5, 0, 1.0), Color(0.5, 0, 1, 1.0)
]

func _ready():
	add_to_group("citizens")
	if civ_id == -1:
		print("Warning: Citizen spawned without a civ_id.")

	# Create 4x4 pixel sprite
	_create_pixel_sprite()

	# Placeholder for initial state
	current_state = State.IDLE
	if GameManager.player_civ_id == civ_id:
		print("Player Citizen spawned for civ: ", civ_id)

func _create_pixel_sprite():
	# Create a 4x4 pixel sprite
	var img = Image.create(4, 4, false, Image.FORMAT_RGBA8)

	# Get the color for this civ
	var civ_color = CIV_COLORS[civ_id % CIV_COLORS.size()]

	# Fill the 4x4 sprite - create a simple square character
	# Border (darker version of civ color)
	var border_color = Color(civ_color.r * 0.5, civ_color.g * 0.5, civ_color.b * 0.5, 1.0)

	# Fill all pixels with civ color
	img.fill(civ_color)

	# Add border for definition
	for x in range(4):
		img.set_pixel(x, 0, border_color) # Top edge
		img.set_pixel(x, 3, border_color) # Bottom edge
	for y in range(4):
		img.set_pixel(0, y, border_color) # Left edge
		img.set_pixel(3, y, border_color) # Right edge

	# Create texture from image
	var texture = ImageTexture.create_from_image(img)

	# Get or create the Sprite2D node
	var sprite = get_node_or_null("Sprite2D")
	if sprite:
		sprite.texture = texture
		sprite.scale = Vector2(2, 2) # Scale up 2x so it's 8x8 pixels on screen
	else:
		# Create new sprite if it doesn't exist
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		sprite.texture = texture
		sprite.scale = Vector2(2, 2)
		add_child(sprite)

func _physics_process(delta):
	match current_state:
		State.IDLE:
			_idle_state()
		State.MOVING_TO_RESOURCE:
			_move_state(delta)
		State.GATHERING:
			_gathering_state(delta)
		State.MOVING_TO_CIV:
			_move_state(delta)
		# Future states will go here

func set_current_tile_coords(coords: Vector2i):
	current_tile_coords = coords
	global_position = WorldManager.world_map_node.map_to_local(coords)

func _idle_state():
	# For now, immediately try to find a resource
	var resource_info = find_nearest_resource()
	if resource_info:
		current_resource_target = resource_info.coords
		current_resource_type = resource_info.resource_type
		current_state = State.MOVING_TO_RESOURCE
		# Placeholder for pathfinding
		path = WorldManager.world_map_node.get_path_from_world_coords(current_tile_coords, current_resource_target)
		if path.is_empty():
			print("Citizen ", self.name, ": No path found to resource at ", current_resource_target)
			current_state = State.IDLE # Go back to idle if no path
		else:
			if not path.is_empty() and path[0] == current_tile_coords:
				path.pop_front() # Remove starting node if present

			if not path.is_empty():
				target_tile_coords = path.pop_front()
			else:
				# This means the destination is the same as the start tile.
				current_state = State.GATHERING
				print("Citizen ", self.name, ": Already at resource. Starting to gather.")
	else:
		# No resources found, stay idle or wander (future)
		pass

func _move_state(delta):
	if path.is_empty() and current_tile_coords == target_tile_coords:
		# Reached final destination
		if current_state == State.MOVING_TO_RESOURCE:
			current_state = State.GATHERING
			print("Citizen ", self.name, ": Reached resource at ", current_resource_target, ". Starting to gather.")
		elif current_state == State.MOVING_TO_CIV:
			_deposit_resources()
			current_state = State.IDLE
			print("Citizen ", self.name, ": Reached civ capital. Deposited resources. Going IDLE.")
		return

	if current_tile_coords == target_tile_coords:
		# Reached intermediate tile in path
		if path.is_empty():
			# This should be handled by the check at the top
			return
		target_tile_coords = path.pop_front()

	var target_world_position = WorldManager.world_map_node.map_to_local(target_tile_coords)
	var direction = (target_world_position - global_position).normalized()
	velocity = direction * speed
	move_and_slide()

	# Update current_tile_coords when we are close enough to the center of the target tile
	if global_position.distance_to(target_world_position) < 5: # A small threshold
		current_tile_coords = target_tile_coords


var gathering_timer: float = 0.0
var gathering_duration: float = 3.0 # seconds per unit of resource

func _gathering_state(delta):
	gathering_timer += delta
	if gathering_timer >= gathering_duration:
		gathering_timer = 0.0
		gather_resource(current_resource_type, current_resource_target)
		
		# After gathering one unit, decide if more can be gathered or if we should return
		var resource_amount_left = WorldManager.world_map_node.get_resource_amount(current_resource_target, current_resource_type)
		if resource_amount_left <= 0 or inventory.get(current_resource_type, 0) >= 5: # Max 5 units
			print("Citizen ", self.name, ": Finished gathering or inventory full. Returning to civ.")
			current_state = State.MOVING_TO_CIV
			var civ_capital_coords = WorldManager.world_map_node.get_civ_capital_coords(civ_id)
			if civ_capital_coords:
				path = WorldManager.world_map_node.get_path_from_world_coords(current_tile_coords, civ_capital_coords)
				if path.is_empty():
					print("Citizen ", self.name, ": No path found to civ capital at ", civ_capital_coords)
					current_state = State.IDLE # Go back to idle if no path
				else:
					if not path.is_empty() and path[0] == current_tile_coords:
						path.pop_front() # Remove starting node if present

					if not path.is_empty():
						target_tile_coords = path.pop_front()
					else:
						# Already at destination, deposit and go idle
						_deposit_resources()
						current_state = State.IDLE
						print("Citizen ", self.name, ": Already at civ capital. Deposited resources. Going IDLE.")
			else:
				print("Citizen ", self.name, ": Could not find civ capital for civ_id ", civ_id)
				current_state = State.IDLE
		else:
			print("Citizen ", self.name, ": Gathered one unit. Continuing to gather. Inventory: ", inventory)


func gather_resource(resource_type: String, coords: Vector2i):
	var gathered_amount = WorldManager.world_map_node.deplete_resource(coords, resource_type, 1) # Deplete 1 unit
	if gathered_amount > 0:
		inventory[resource_type] = inventory.get(resource_type, 0) + gathered_amount
		print("Citizen ", self.name, ": Gathered ", gathered_amount, " ", resource_type, ". Inventory: ", inventory)
	else:
		print("Citizen ", self.name, ": Tried to gather ", resource_type, " at ", coords, " but none left.")
		current_state = State.IDLE # Resource depleted, go back to idle to find new one

func _deposit_resources():
	for res_type in inventory.keys():
		var amount = inventory[res_type]
		if amount > 0:
			GameManager.add_player_resources(res_type, amount)
			inventory[res_type] = 0 # Clear inventory for this resource
			print("Citizen ", self.name, ": Deposited ", amount, " ", res_type, ". Remaining inventory: ", inventory)


func find_nearest_resource() -> Dictionary:
	var world_data = WorldManager.world_map_node.get_world_data()
	var civ_capital_coords = WorldManager.world_map_node.get_civ_capital_coords(civ_id)
	if not civ_capital_coords:
		return {}


	var search_radius = 50 # tiles
	var nearest_resource_coords: Vector2i = Vector2i.ZERO
	var nearest_resource_type: String = ""
	var min_distance_sq: float = INF
	
	# Simple radial search for now, could be optimized with a resource manager later
	for x in range(current_tile_coords.x - search_radius, current_tile_coords.x + search_radius + 1):
		for y in range(current_tile_coords.y - search_radius, current_tile_coords.y + search_radius + 1):
			var coords = Vector2i(x, y)
			if world_data.has(coords):
				var tile = world_data[coords]
				if tile.has("resources") and not tile["resources"].is_empty():
					for res_type in tile["resources"].keys():
						if tile["resources"][res_type]["amount"] > 0:
							var distance_sq = float(coords.x - current_tile_coords.x) * (coords.x - current_tile_coords.x) + \
											  float(coords.y - current_tile_coords.y) * (coords.y - current_tile_coords.y)
							if distance_sq < min_distance_sq:
								min_distance_sq = distance_sq
								nearest_resource_coords = coords
								nearest_resource_type = res_type
	
	if nearest_resource_coords != Vector2i.ZERO:
		return {"coords": nearest_resource_coords, "resource_type": nearest_resource_type}
	
	return {}
