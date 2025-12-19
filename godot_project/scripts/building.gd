extends Node2D

class_name Building

@export var building_type: String = "village"  # village, castle, ruins, temple
@export var civ_id: int = -1  # Which civ owns this building (-1 for neutral)
@export var health: float = 200.0
@export var max_health: float = 200.0

var tile_coords: Vector2i
var hp_bar: Node2D

func _ready():
	add_to_group("buildings")
	_create_hp_bar()
	_create_building_sprite()

func _create_building_sprite():
	"""Create visual representation of the building."""
	var sprite_size = 12 if building_type == "castle" else 8
	var img = Image.create(sprite_size, sprite_size, false, Image.FORMAT_RGBA8)

	# Color based on building type
	var building_color: Color
	match building_type:
		"village":
			building_color = Color(0.8, 0.6, 0.4, 1.0)  # Tan
		"castle":
			building_color = Color(0.5, 0.5, 0.5, 1.0)  # Gray
		"ruins":
			building_color = Color(0.4, 0.4, 0.4, 1.0)  # Dark gray
		"temple":
			building_color = Color(0.9, 0.9, 0.5, 1.0)  # Gold
		_:
			building_color = Color(0.7, 0.7, 0.7, 1.0)

	# Fill the sprite
	for x in range(sprite_size):
		for y in range(sprite_size):
			img.set_pixel(x, y, building_color)

	var texture = ImageTexture.create_from_image(img)
	var sprite = Sprite2D.new()
	sprite.texture = texture
	sprite.name = "BuildingSprite"
	add_child(sprite)

func _create_hp_bar():
	"""Create health bar above building."""
	hp_bar = Node2D.new()
	hp_bar.name = "HPBar"
	hp_bar.position = Vector2(0, -10)
	add_child(hp_bar)

	# Background
	var bg = ColorRect.new()
	bg.size = Vector2(16, 3)
	bg.position = Vector2(-8, 0)
	bg.color = Color(0.2, 0.2, 0.2, 0.8)
	hp_bar.add_child(bg)

	# Foreground (health)
	var fg = ColorRect.new()
	fg.name = "HealthBar"
	fg.size = Vector2(16, 3)
	fg.position = Vector2(-8, 0)
	fg.color = Color(0.8, 0.8, 0.2, 1.0)  # Yellow for buildings
	hp_bar.add_child(fg)

func take_damage(amount: float):
	"""Apply damage to the building."""
	health -= amount
	health = max(0, health)
	_update_hp_bar()

	if health <= 0:
		_on_destroyed()

func _update_hp_bar():
	"""Update the health bar visual."""
	if not hp_bar:
		return

	var health_bar = hp_bar.get_node_or_null("HealthBar")
	if health_bar:
		var health_percent = health / max_health
		health_bar.size.x = 16 * health_percent

		# Color based on health
		if health_percent > 0.6:
			health_bar.color = Color(0.8, 0.8, 0.2, 1.0)  # Yellow
		elif health_percent > 0.3:
			health_bar.color = Color(1.0, 0.6, 0.2, 1.0)  # Orange
		else:
			health_bar.color = Color(1.0, 0.2, 0.2, 1.0)  # Red

func _on_destroyed():
	"""Called when building is destroyed."""
	Log.log_info("Building destroyed at %s" % tile_coords)
	# Convert to ruins or remove
	if building_type != "ruins":
		building_type = "ruins"
		civ_id = -1  # Neutral
		health = max_health * 0.5
		_update_sprite_for_ruins()
	else:
		queue_free()

func _update_sprite_for_ruins():
	"""Update sprite when building becomes ruins."""
	var sprite = get_node_or_null("BuildingSprite")
	if sprite:
		sprite.modulate = Color(0.4, 0.4, 0.4, 1.0)

func set_tile_coords(coords: Vector2i):
	"""Set the tile coordinates and update position."""
	tile_coords = coords
	if WorldManager.world_map_node:
		global_position = WorldManager.world_map_node.map_to_local(coords)

func get_territory_bonus() -> int:
	"""Return how many tiles this building adds to territory control."""
	match building_type:
		"village":
			return 5
		"castle":
			return 10
		"temple":
			return 8
		_:
			return 0
