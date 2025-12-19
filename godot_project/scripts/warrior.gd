extends CharacterBody2D

class_name Warrior

@export var civ_id: int = -1
@export var speed: float = 120.0  # Slightly faster than workers (doubled)
@export var attack_damage: float = 25.0
@export var attack_range: float = 30.0
@export var attack_cooldown: float = 1.5  # Seconds between attacks

var current_tile_coords: Vector2i
var target_tile_coords: Vector2i
var path: Array = []
var target_enemy: Node2D = null  # Can target warriors, citizens, or buildings

# Combat stats
var health: float = 150.0  # More HP than workers
var max_health: float = 150.0
var attack_timer: float = 0.0

enum State {
	IDLE,
	MOVING_TO_TARGET,
	ATTACKING,
	DEFENDING,  # Stand ground near capital
	PATROLLING,  # Move around territory
}

enum Command {
	ATTACK,      # Hunt down enemies aggressively
	DEFEND,      # Defend near capital/territory
	PATROL,      # Move around territory borders
	GUARD,       # Stay in current position
}

var current_state: State = State.IDLE
var current_command: Command = Command.DEFEND

const CIV_COLORS = [
	Color(1, 0, 0, 1.0), Color(0, 1, 0, 1.0), Color(0, 0, 1, 1.0),
	Color(1, 1, 0, 1.0), Color(0, 1, 1, 1.0), Color(1, 0, 1, 1.0),
	Color(1, 0.5, 0, 1.0), Color(0.5, 0, 1, 1.0)
]

func _ready():
	add_to_group("citizens")  # For compatibility with existing systems
	add_to_group("warriors")
	if civ_id == -1:
		print("Warning: Warrior spawned without a civ_id.")

	# Create warrior sprite (different shape than workers)
	_create_warrior_sprite()

	# Create HP bar
	_create_hp_bar()

	current_state = State.IDLE
	if GameManager.player_civ_id == civ_id:
		print("Player Warrior spawned for civ: ", civ_id)

func _create_warrior_sprite():
	# Create a 6x6 pixel sprite for the warrior (larger than workers)
	var img = Image.create(6, 6, false, Image.FORMAT_RGBA8)

	# Get the color for this civ
	var civ_color = CIV_COLORS[civ_id % CIV_COLORS.size()]

	# Fill the sprite
	var border_color = Color(civ_color.r * 0.3, civ_color.g * 0.3, civ_color.b * 0.3, 1.0)

	# Fill all pixels with civ color
	img.fill(civ_color)

	# Create a sword/shield pattern
	# Top-left and bottom-right darker (shield)
	for x in range(3):
		for y in range(3):
			img.set_pixel(x, y, border_color)
	for x in range(3, 6):
		for y in range(3, 6):
			img.set_pixel(x, y, border_color)

	# Create texture from image
	var texture = ImageTexture.create_from_image(img)

	var sprite = Sprite2D.new()
	sprite.name = "WarriorSprite"
	sprite.texture = texture
	sprite.scale = Vector2(2, 2)  # 12x12 on screen
	add_child(sprite)

func _create_hp_bar():
	"""Create a health bar above the unit."""
	var hp_bar_container = Node2D.new()
	hp_bar_container.name = "HPBarContainer"
	hp_bar_container.position = Vector2(0, -14)  # Above sprite
	add_child(hp_bar_container)

	# Background (red)
	var bg = ColorRect.new()
	bg.name = "HPBarBackground"
	bg.size = Vector2(14, 2)
	bg.position = Vector2(-7, 0)  # Center it
	bg.color = Color(0.3, 0.0, 0.0, 0.8)
	hp_bar_container.add_child(bg)

	# Foreground (red for warriors)
	var fg = ColorRect.new()
	fg.name = "HPBarForeground"
	fg.size = Vector2(14, 2)
	fg.position = Vector2(-7, 0)
	fg.color = Color(0.8, 0.0, 0.0, 0.9)  # Red by default for warriors
	hp_bar_container.add_child(fg)

func _physics_process(delta):
	# Only process during simulation phase
	if not GameManager.is_units_active():
		return

	# Update attack timer
	if attack_timer > 0:
		attack_timer -= delta

	# Update health visual
	_update_health_visual()

	match current_state:
		State.IDLE:
			_idle_state()
		State.MOVING_TO_TARGET:
			_move_state(delta)
		State.ATTACKING:
			_attack_state(delta)
		State.DEFENDING:
			_defend_state()
		State.PATROLLING:
			_patrol_state()

func set_current_tile_coords(coords: Vector2i):
	current_tile_coords = coords
	global_position = WorldManager.world_map_node.map_to_local(coords)

func set_command(new_command: Command):
	"""Set the warrior's command."""
	current_command = new_command
	# Update state based on command
	match new_command:
		Command.ATTACK:
			current_state = State.IDLE  # Will search for enemies
		Command.DEFEND:
			current_state = State.DEFENDING
		Command.PATROL:
			current_state = State.PATROLLING
		Command.GUARD:
			current_state = State.DEFENDING  # Stay in place

func _idle_state():
	# Look for enemies
	var nearest_enemy = _find_nearest_enemy()
	if nearest_enemy:
		target_enemy = nearest_enemy
		current_state = State.MOVING_TO_TARGET
		_path_to_enemy()
	else:
		# No enemies, defend capital
		current_state = State.DEFENDING

func _move_state(delta):
	if path.is_empty() and current_tile_coords == target_tile_coords:
		# Reached destination
		if target_enemy and is_instance_valid(target_enemy):
			# Close enough to attack?
			var dist = global_position.distance_to(target_enemy.global_position)
			if dist <= attack_range:
				current_state = State.ATTACKING
				return
			else:
				# Enemy moved, repath
				_path_to_enemy()
		else:
			current_state = State.IDLE
		return

	if current_tile_coords == target_tile_coords:
		if path.is_empty():
			return
		target_tile_coords = path.pop_front()

	var target_world_position = WorldManager.world_map_node.map_to_local(target_tile_coords)
	var direction = (target_world_position - global_position).normalized()
	velocity = direction * speed
	move_and_slide()

	if global_position.distance_to(target_world_position) < 5:
		current_tile_coords = target_tile_coords

func _attack_state(delta):
	if not target_enemy or not is_instance_valid(target_enemy):
		current_state = State.IDLE
		return

	# Face enemy
	var dist = global_position.distance_to(target_enemy.global_position)

	if dist > attack_range:
		# Enemy moved away, chase
		current_state = State.MOVING_TO_TARGET
		_path_to_enemy()
		return

	# Attack if cooldown ready
	if attack_timer <= 0:
		_perform_attack()
		attack_timer = attack_cooldown

func _defend_state():
	# Stay near capital, look for enemies
	var nearest_enemy = _find_nearest_enemy()
	if nearest_enemy:
		target_enemy = nearest_enemy
		current_state = State.MOVING_TO_TARGET
		_path_to_enemy()

func _patrol_state():
	# TODO: Implement patrol logic
	current_state = State.IDLE

func _find_nearest_enemy() -> Node2D:
	"""Find nearest enemy unit (citizen, warrior, or building)."""
	var nearest: Node2D = null
	var min_distance = INF

	# Check all citizens and warriors
	for unit in get_tree().get_nodes_in_group("citizens"):
		if unit == self or not unit.has_method("get") or unit.civ_id == civ_id:
			continue

		var dist = global_position.distance_to(unit.global_position)
		if dist < min_distance:
			min_distance = dist
			nearest = unit

	# Check all buildings
	for building in get_tree().get_nodes_in_group("buildings"):
		if building.civ_id == civ_id or building.civ_id == -1:  # Skip own buildings and neutral
			continue

		var dist = global_position.distance_to(building.global_position)
		if dist < min_distance:
			min_distance = dist
			nearest = building

	return nearest

func _path_to_enemy():
	"""Calculate path to current target enemy."""
	if not target_enemy or not is_instance_valid(target_enemy):
		return

	var enemy_coords = WorldManager.world_map_node.tile_map.local_to_map(target_enemy.global_position)
	path = WorldManager.world_map_node.get_path_from_world_coords(current_tile_coords, enemy_coords)

	if path.is_empty():
		current_state = State.IDLE
		return

	if not path.is_empty() and path[0] == current_tile_coords:
		path.pop_front()

	if not path.is_empty():
		target_tile_coords = path.pop_front()

func _perform_attack():
	"""Deal damage to target enemy (unit or building)."""
	if not target_enemy or not is_instance_valid(target_enemy):
		return

	# Check if target is a building (has take_damage method) or a unit (has health property)
	if target_enemy.has_method("take_damage"):
		# It's a building
		target_enemy.take_damage(attack_damage)
		Log.log_info("Warrior %s attacked building, dealing %d damage" % [name, attack_damage])
	elif "health" in target_enemy:
		# It's a unit
		target_enemy.health -= attack_damage
		Log.log_info("Warrior %s attacked unit, dealing %d damage" % [name, attack_damage])

		# Check if unit died
		if target_enemy.health <= 0:
			GameManager.remove_citizen_from_civ(target_enemy.civ_id)
			target_enemy.queue_free()
			target_enemy = null
			current_state = State.IDLE
			return

	# Visual feedback
	_create_attack_effect()

func _create_attack_effect():
	"""Visual effect for attacking."""
	if not target_enemy or not is_instance_valid(target_enemy):
		return

	# Create a line/flash between attacker and target
	var line = Line2D.new()
	line.add_point(global_position)
	line.add_point(target_enemy.global_position)
	line.width = 2
	line.default_color = Color(1, 0, 0, 0.8)
	get_parent().add_child(line)

	# Fade out and delete
	var tween = line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.2)
	tween.tween_callback(line.queue_free)

func _update_health_visual():
	"""Update HP bar based on health."""
	var hp_bar_container = get_node_or_null("HPBarContainer")
	if not hp_bar_container:
		return

	var fg = hp_bar_container.get_node_or_null("HPBarForeground")
	if not fg:
		return

	# Update HP bar width based on health percentage
	var hp_percent = health / max_health
	fg.size.x = 14 * hp_percent

	# Change color based on health (warriors use red/orange/dark red)
	if hp_percent > 0.6:
		fg.color = Color(0.8, 0.0, 0.0, 0.9)  # Red
	elif hp_percent > 0.3:
		fg.color = Color(0.9, 0.5, 0.0, 0.9)  # Orange
	else:
		fg.color = Color(0.5, 0.0, 0.0, 0.9)  # Dark red
