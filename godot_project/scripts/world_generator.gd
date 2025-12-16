class_name WorldGenerator
extends Object

# Movement costs for different terrain types
const TERRAIN_MOVEMENT_COSTS = {
	0: 100.0, # Water (effectively impassable for land units)
	1: 2.0,   # Sand
	2: 1.0,   # Grass
	3: 1.5,   # Forest
	4: 2.0,   # Hills
	5: 3.0,   # Stone
	6: 4.0,   # Mountains
	7: 200.0, # Deep Sea (more impassable than regular water)
	8: INF,   # Chasm (impassable)
	9: INF,   # Lava (impassable)
	10: 5.0,    # Snow Peak (difficult to traverse)
	11: INF,   # Ice Water (impassable)
	12: 100.0,  # Cold Water (very difficult)
	13: 1.2,    # Jungle (slightly slower than grass)
	14: 1.1,     # Dry Grassland (slightly slower than grass)
	15: 4.5      # Rocky Peak (slightly more difficult than mountains)
}

var RESOURCE_SPAWNING_RULES = {} # Changed to var, initialized in _init

var terrain_noise = FastNoiseLite.new()
var continental_noise = FastNoiseLite.new() # New continental noise
var chasm_noise = FastNoiseLite.new() # New chasm noise
var latitude_noise = FastNoiseLite.new() # New latitude/temperature noise
var jungle_noise = FastNoiseLite.new() # New jungle noise
var width
var height
var world_seed

func _init(p_width, p_height, p_seed):
	width = p_width
	height = p_height
	world_seed = p_seed

	terrain_noise.seed = world_seed
	terrain_noise.fractal_octaves = 4
	terrain_noise.fractal_lacunarity = 2.0
	terrain_noise.fractal_gain = 0.5
	terrain_noise.frequency = 0.015 # Slightly lower frequency for longer, snaking mountains
	
	continental_noise.seed = world_seed # Same seed for consistency
	continental_noise.noise_type = FastNoiseLite.TYPE_PERLIN # Use Perlin for continental shapes
	continental_noise.fractal_octaves = 5 # Increased for more detail
	continental_noise.fractal_lacunarity = 2.0
	continental_noise.fractal_gain = 0.5
	chasm_noise.fractal_octaves = 2
	chasm_noise.frequency = 0.05 # Higher frequency for snaking patterns
	
	latitude_noise.seed = world_seed + 3 # Different seed
	latitude_noise.frequency = 0.0005 # Very low frequency for broad latitudinal changes
	latitude_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX # Good for smooth gradients

	jungle_noise.seed = world_seed + 4 # Different seed
	jungle_noise.frequency = 0.01 # Moderate frequency for grouped patches
	jungle_noise.fractal_octaves = 2 # Few octaves for large features
	jungle_noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED # Can create interesting grouped shapes

	# Initialize RESOURCE_SPAWNING_RULES here
	RESOURCE_SPAWNING_RULES = {
		# terrain_id: {resource_type: {chance: float, min_amount: int, max_amount: int}}
		2: { # Grass
			"food": {"chance": 0.25, "min_amount": 20, "max_amount": 60},
			"wood": {"chance": 0.05, "min_amount": 5, "max_amount": 15},
			"water": {"chance": 0.15, "min_amount": 10, "max_amount": 40}
		},
		3: { # Forest
			"wood": {"chance": 0.35, "min_amount": 40, "max_amount": 120},
			"food": {"chance": 0.1, "min_amount": 15, "max_amount": 40}
		},
		4: { # Hills
			"stone": {"chance": 0.3, "min_amount": 30, "max_amount": 80},
			"metal_ore": {"chance": 0.05, "min_amount": 3, "max_amount": 10}
		},
		5: { # Stone
			"stone": {"chance": 0.4, "min_amount": 60, "max_amount": 150},
			"metal_ore": {"chance": 0.15, "min_amount": 5, "max_amount": 20}
		},
		6: { # Mountains
			"stone": {"chance": 0.35, "min_amount": 80, "max_amount": 200},
			"metal_ore": {"chance": 0.25, "min_amount": 10, "max_amount": 40}
		},
		0: { # Water
			"water": {"chance": 0.4, "min_amount": 200, "max_amount": 400}
		},
		1: { # Sand
			"water": {"chance": 0.05, "min_amount": 5, "max_amount": 20}
		}
	}

func generate_terrain():
	var tile_data = {}
	var land_tiles = []
	var rng = RandomNumberGenerator.new() # Added RNG for resource generation
	rng.seed = world_seed + 1 # Use a slightly different seed for resources
	
	for y in range(height):
		for x in range(width):
			var coords = Vector2i(x, y)
			# Modified data dictionary initialization
			var data = {
				"terrain_id": 0,
				"civ_id": -1,
				"elevation": 0.0,
				"has_river": false,
				"resources": {}, # New: empty dictionary for resources
				"movement_cost": 0.0 # New: will be set based on terrain
			}
			
			var terrain_val = terrain_noise.get_noise_2d(x, y)
			var continental_val = continental_noise.get_noise_2d(x, y)

			# Calculate latitude-based temperature value (0 at poles, 1 at equator)
			var normalized_y = float(y) / (height - 1) # 0.0 at top, 1.0 at bottom
			var latitude_factor = 1.0 - abs(normalized_y - 0.5) * 2.0 # 0.0 at poles, 1.0 at equator
			var temp_val = latitude_factor + latitude_noise.get_noise_2d(x, y) * 0.1 # Reduced noise for smoother bands
			temp_val = clamp(temp_val, 0.0, 1.0) # Ensure it's between 0 and 1

			# Bias continental generation towards the equator
			continental_val += (temp_val - 0.5) * 0.5 # Push more land towards warmer regions

			# Blend continental noise with terrain noise
			var blended_val = terrain_val + continental_val * 2.5 - 0.3 # Further increased continental influence, stronger global shift towards more water
			
			# Apply cold_bias to blended_val for land type determination
			# In cold regions, same noise input yields higher effective elevation, favoring rock/snow
			var cold_bias_factor = (1.0 - temp_val) * 0.2 # Increased bias at poles, 0 at equator
			var final_blended_val = blended_val + cold_bias_factor
			
			data.elevation = blended_val # Store base elevation

			# First, handle water types based on temperature
			if final_blended_val < -0.25: # Very low elevation (Deep Sea or colder variants)
				if temp_val < 0.2: # Very cold
					data.terrain_id = 11 # Ice Water
				elif temp_val < 0.4: # Cold
					data.terrain_id = 12 # Cold Water
				else:
					data.terrain_id = 7 # Deep Sea (regular)
			elif final_blended_val < -0.2: # Low elevation water (Water or colder variants)
				if temp_val < 0.2: # Very cold
					data.terrain_id = 11 # Ice Water
				elif temp_val < 0.4: # Cold
					data.terrain_id = 12 # Cold Water
				else:
					data.terrain_id = 0 # Water (regular)

			# Now, handle land types, influenced by temperature and other noise
			elif final_blended_val < -0.15: # Sand region
				if temp_val < 0.4: # In cold regions, convert Sand to Snow Peak
					data.terrain_id = 10 # Snow Peak
				else:
					data.terrain_id = 1 # Sand
			elif final_blended_val < 0.2: # Grass / Jungle / Dry Grassland region
				if temp_val < 0.4: # Very cold: what would be Grass/Jungle/DryGrass is now Snow Peak
					data.terrain_id = 10 # Snow Peak
				elif temp_val > 0.8 and jungle_noise.get_noise_2d(x, y) > 0.4 and rng.randf() < 0.1: # Hot & jungle noise for grouped rarity
					data.terrain_id = 13 # Jungle
				elif temp_val > 0.4 and temp_val < 0.7 and terrain_noise.get_noise_2d(x, y) < -0.1: # Moderate temp, slightly drier (lower terrain noise)
					data.terrain_id = 14 # Dry Grassland
				else:
					data.terrain_id = 2 # Grass
			elif final_blended_val < 0.4: # Forest region
				if temp_val < 0.4: # Very cold: what would be Forest is now Stone
					data.terrain_id = 5 # Stone
				else:
					data.terrain_id = 3 # Forest
			elif final_blended_val < 0.6: data.terrain_id = 4 # Hills
			# Chasm: very rare, specific elevation within hills/stone
			elif final_blended_val < 0.61 and rng.randf() < 0.2: data.terrain_id = 8 # Chasm
			elif final_blended_val < 0.7: data.terrain_id = 5 # Stone
			# Ultra rare Lava on higher elevations, more likely near equator
			elif final_blended_val < 0.72 and rng.randf() < (0.005 * (1.0 + temp_val)): data.terrain_id = 9 # Lava
			elif final_blended_val < 0.85: # Mountains (potentially Snow Peak or Rocky Peak)
				if final_blended_val >= 0.8: # Very high peaks
					if temp_val < 0.5: # Cold/Temperate very high peaks -> Snow Peak
						data.terrain_id = 10 # Snow Peak
					else: # Warmer/Central very high peaks -> Rocky Peak
						data.terrain_id = 15 # Rocky Peak
				elif temp_val < 0.4: # Colder mountains -> Snow Peak
					data.terrain_id = 10 # Snow Peak
				else: # Warmer mountains -> regular Mountains
					data.terrain_id = 6 # Mountains
			else: # Absolute highest elevations (always Snow Peak)
				data.terrain_id = 10 # Snow Peak

			data.movement_cost = TERRAIN_MOVEMENT_COSTS[data.terrain_id] # Set movement cost
			
			# Resource distribution logic
			if RESOURCE_SPAWNING_RULES.has(data.terrain_id):
				var rules_for_terrain = RESOURCE_SPAWNING_RULES[data.terrain_id]
				for resource_type in rules_for_terrain.keys():
					var rule = rules_for_terrain[resource_type]
					if rng.randf() < rule["chance"]:
						var initial_amount = rng.randi_range(rule["min_amount"], rule["max_amount"])
						data.resources[resource_type] = {
							"amount": initial_amount,
							"max_amount": rule["max_amount"],
							"regeneration_rate": 0.0 # Placeholder, will define later
					}
			
			tile_data[coords] = data
			
			# land_tiles should include Sand, Grass, Forest, Hills, Stone, Mountains, Snow Peak, Jungle, Dry Grassland, Rocky Peak
			if data.terrain_id in [1, 2, 3, 4, 5, 6, 10, 13, 14, 15]:
				land_tiles.append(coords)
	return [tile_data, land_tiles]

func generate_civs(tile_data, land_tiles):
	var rng = RandomNumberGenerator.new()
	rng.seed = world_seed
	var civ_territories = {}
	
	var num_civs = rng.randi_range(4, 6)
	var min_dist_between_civs = 15
	var civ_capitals_coords_list = [] # Temporary list for distance checking
	var civ_capitals_dict = {} # Stores civ_id -> capital_coords
	var civ_id_counter = 0
	land_tiles.shuffle()

	Log.log_info("WorldGenerator: generate_civs() - Starting capital placement loop.")
	for start_coord in land_tiles:
		if civ_id_counter >= num_civs: break
		var is_valid_capital = true
		if tile_data[start_coord].civ_id != -1: is_valid_capital = false
		for capital_coords in civ_capitals_coords_list: # Check against the temporary list
			if start_coord.distance_to(capital_coords) < min_dist_between_civs:
				is_valid_capital = false
				break
		
		if is_valid_capital:
			civ_capitals_coords_list.append(start_coord)
			var current_civ_id = civ_id_counter
			civ_capitals_dict[current_civ_id] = start_coord # Store in the dictionary
			civ_territories[current_civ_id] = []
			Log.log_info("WorldGenerator: generate_civs() - Capital for Civ %d placed at %s." % [current_civ_id, str(start_coord)])
			var civ_size = rng.randi_range(5, 10)
			var queue = [start_coord]
			var visited = {start_coord: true}
			
			Log.log_info("WorldGenerator: generate_civs() - Starting territory expansion for Civ %d (target size %d)." % [current_civ_id, civ_size])
			while not queue.is_empty() and civ_territories[current_civ_id].size() < civ_size:
				var current_coord = queue.pop_front()
				
				if tile_data.has(current_coord) and tile_data[current_coord].civ_id == -1 and tile_data[current_coord].terrain_id > 1:
					tile_data[current_coord].civ_id = current_civ_id
					civ_territories[current_civ_id].append(current_coord)
					var neighbors = get_hex_neighbors(current_coord)
					neighbors.shuffle()
					for neighbor in neighbors:
						if not visited.has(neighbor):
							visited[neighbor] = true
							queue.append(neighbor)
				else:
					Log.log_info("WorldGenerator: generate_civs() - Civ %d: Skipped coord %s (already taken, water, or invalid)." % [current_civ_id, str(current_coord)])
			Log.log_info("WorldGenerator: generate_civs() - Civ %d: Territory expansion finished. Final size %d." % [current_civ_id, civ_territories[current_civ_id].size()])
			civ_id_counter += 1
	Log.log_info("WorldGenerator: generate_civs() - Capital placement loop finished.")
	return [tile_data, civ_territories, civ_capitals_dict]

func generate_landmarks(tile_data, land_tiles, civ_territories):
	var rng = RandomNumberGenerator.new()
	rng.seed = world_seed
	var occupied_landmark_tiles = {}
	var landmarks = {} # Key: coord, Value: landmark_id

	for civ_id in civ_territories.keys():
		var territory = civ_territories[civ_id]
		if territory.is_empty(): continue
		
		var capital_coord = territory[0]
		landmarks[capital_coord] = 0 # 0 = castle
		occupied_landmark_tiles[capital_coord] = true
		
		var num_villages = rng.randi_range(0, int(territory.size() / 3.0))
		for i in range(num_villages):
			var coord = territory[rng.randi_range(0, territory.size() - 1)]
			if not occupied_landmark_tiles.has(coord):
				landmarks[coord] = 1 # 1 = village
				occupied_landmark_tiles[coord] = true
				
	var num_ruins = rng.randi_range(10, 25)
	var potential_ruin_tiles = land_tiles.filter(func(coord): return tile_data[coord].civ_id == -1)
	potential_ruin_tiles.shuffle()
	for i in range(min(num_ruins, potential_ruin_tiles.size())):
		var coord = potential_ruin_tiles[i]
		if not occupied_landmark_tiles.has(coord):
			landmarks[coord] = 2 # 2 = ruins
	
	return landmarks

func generate_rivers(tile_data: Dictionary, land_tiles: Array) -> Dictionary:
	var rng = RandomNumberGenerator.new()
	rng.seed = world_seed
	
	# Find potential river sources (e.g., mountain tiles or high elevation)
	var potential_sources = []
	for coord in land_tiles:
		if tile_data[coord].terrain_id == 6 or tile_data[coord].terrain_id == 10: # Mountains or Snow Peak
			potential_sources.append(coord)
	
	# Limit the number of rivers for performance/aesthetic reasons
	var num_rivers = min(10, potential_sources.size()) # Max 10 rivers, or fewer if less sources
	potential_sources.shuffle()
	
	for i in range(num_rivers):
		if potential_sources.is_empty(): break
		var current_coord = potential_sources.pop_front()
		
		# Ensure river starts on land and not already a river
		if tile_data[current_coord].terrain_id < 2 or tile_data[current_coord].has_river:
			continue

		var river_path = [current_coord]
		var max_river_length = 100 # Prevent excessively long rivers
		
		while river_path.size() < max_river_length:
			var neighbors = get_hex_neighbors(current_coord)
			var next_coord = Vector2i()
			var lowest_elevation = tile_data[current_coord].elevation
			var found_next_step = false
			
			# Prioritize steepest descent
			for neighbor in neighbors:
				if tile_data.has(neighbor):
					var neighbor_data = tile_data[neighbor]
					# River should flow downwards, and not go back on itself immediately
					if neighbor_data.elevation < lowest_elevation and not river_path.has(neighbor):
						lowest_elevation = neighbor_data.elevation
						next_coord = neighbor
						found_next_step = true
			
			if found_next_step:
				# If we hit water, the river ends here
				if tile_data[next_coord].terrain_id == 0: # Water
					tile_data[current_coord].has_river = true
					break
				# Mark current tile as river
				tile_data[current_coord].has_river = true
				river_path.append(next_coord)
				current_coord = next_coord
			else:
				# River cannot find a lower path or reached a basin/plateau
				# Mark current tile as river and terminate
				tile_data[current_coord].has_river = true
				break
	
	return tile_data


func get_hex_neighbors(coords: Vector2i) -> Array[Vector2i]:
	var is_odd_row = coords.y % 2 != 0
	var neighbor_dirs = []
	if is_odd_row:
		neighbor_dirs = [Vector2i(1, 0), Vector2i(0, -1), Vector2i(1, -1), Vector2i(0, 1), Vector2i(1, 1), Vector2i(-1, 0)]
	else:
		neighbor_dirs = [Vector2i(1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(-1, 0)]
	
	var results: Array[Vector2i] = []
	for dir in neighbor_dirs:
		results.append(coords + dir)
	return results

func find_path(start_coords: Vector2i, end_coords: Vector2i, tile_data: Dictionary) -> Array[Vector2i]:
	if not tile_data.has(start_coords) or not tile_data.has(end_coords):
		Log.log_warning("Pathfinding: Start or end coordinates not in tile_data.")
		return []

	# Check if start or end are impassable
	if TERRAIN_MOVEMENT_COSTS.get(tile_data[start_coords].terrain_id, INF) == INF or \
	   TERRAIN_MOVEMENT_COSTS.get(tile_data[end_coords].terrain_id, INF) == INF:
		Log.log_warning("Pathfinding: Start or end tile is impassable.")
		return []

	var open_set = [start_coords]
	var came_from: Dictionary = {}

	var g_score: Dictionary = {start_coords: 0.0}
	var f_score: Dictionary = {start_coords: _heuristic(start_coords, end_coords)}

	while not open_set.is_empty():
		# Get the node in open_set with the lowest f_score
		var current = open_set[0]
		for node in open_set:
			if f_score.get(node, INF) < f_score.get(current, INF):
				current = node

		if current == end_coords:
			return _reconstruct_path(came_from, current)

		open_set.erase(current)

		for neighbor in get_hex_neighbors(current):
			if not tile_data.has(neighbor):
				continue
			
			var neighbor_terrain_id = tile_data[neighbor].terrain_id
			var movement_cost = TERRAIN_MOVEMENT_COSTS.get(neighbor_terrain_id, INF)

			if movement_cost == INF: # Impassable terrain
				continue

			var tentative_g_score = g_score.get(current, INF) + movement_cost

			if tentative_g_score < g_score.get(neighbor, INF):
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g_score
				f_score[neighbor] = tentative_g_score + _heuristic(neighbor, end_coords)
				if not open_set.has(neighbor):
					open_set.append(neighbor)
	
	Log.log_warning("Pathfinding: No path found from %s to %s." % [start_coords, end_coords])
	return [] # No path found

func _reconstruct_path(came_from: Dictionary, current: Vector2i) -> Array[Vector2i]:
	var total_path: Array[Vector2i] = [current]
	while came_from.has(current):
		current = came_from[current]
		total_path.append(current)
	total_path.reverse()
	return total_path

func _heuristic(a: Vector2i, b: Vector2i) -> float:
	# Hexagonal distance heuristic (approximated)
	# This is a common heuristic for hex grids, assuming movement cost is somewhat uniform.
	# For axial coordinates (which Godot's TileMap uses internally for hex, or can be derived from offset)
	# The distance is max(dx, dy, dz) where dz = -(dx+dy) for cube coords.
	# For offset coordinates, a simple approximation is usually sufficient for A* to work.
	var dx = abs(a.x - b.x)
	var dy = abs(a.y - b.y)
	return sqrt(pow(dx, 2) + pow(dy, 2)) # Euclidean distance as a simple heuristic
