extends Node

# Visual effects manager for card effects

func create_effect_at_position(effect_type: String, world_position: Vector2, world_map) -> void:
	"""Create a visual effect at the given world position."""
	match effect_type:
		"terrain_change":
			_create_terrain_change_effect(world_position, world_map)
		"resource_boost":
			_create_resource_boost_effect(world_position, world_map)
		"resource_add":
			_create_resource_add_effect(world_position, world_map)
		"destroy":
			_create_destroy_effect(world_position, world_map)
		"freeze":
			_create_freeze_effect(world_position, world_map)
		"boon":
			_create_boon_effect(world_position, world_map)
		"bane":
			_create_bane_effect(world_position, world_map)
		"summon_citizens":
			_create_summon_effect(world_position, world_map)

func _create_terrain_change_effect(world_position: Vector2, world_map) -> void:
	"""Create terrain change effect (earth burst)."""
	var particles = _create_particle_burst(
		world_position,
		Color(0.6, 0.5, 0.3),  # Brown/earth color
		20,  # particle count
		100.0,  # spread
		0.8  # lifetime
	)
	world_map.add_child(particles)

func _create_resource_boost_effect(world_position: Vector2, world_map) -> void:
	"""Create resource boost effect (golden sparkles)."""
	var particles = _create_particle_burst(
		world_position,
		Color(1.0, 0.9, 0.3),  # Golden
		30,
		80.0,
		1.0
	)
	world_map.add_child(particles)

func _create_resource_add_effect(world_position: Vector2, world_map) -> void:
	"""Create resource addition effect (green sparkles)."""
	var particles = _create_particle_burst(
		world_position,
		Color(0.3, 0.9, 0.3),  # Green
		25,
		70.0,
		0.9
	)
	world_map.add_child(particles)

func _create_destroy_effect(world_position: Vector2, world_map) -> void:
	"""Create destruction effect (red explosion)."""
	var particles = _create_particle_burst(
		world_position,
		Color(0.9, 0.2, 0.2),  # Red
		40,
		120.0,
		1.2
	)
	world_map.add_child(particles)

func _create_freeze_effect(world_position: Vector2, world_map) -> void:
	"""Create freeze effect (blue/white crystals)."""
	var particles = _create_particle_burst(
		world_position,
		Color(0.7, 0.9, 1.0),  # Ice blue
		35,
		90.0,
		1.0
	)
	world_map.add_child(particles)

func _create_boon_effect(world_position: Vector2, world_map) -> void:
	"""Create blessing effect (divine light)."""
	var particles = _create_particle_burst(
		world_position,
		Color(1.0, 1.0, 0.8),  # Bright yellow/white
		30,
		100.0,
		1.5
	)
	world_map.add_child(particles)

func _create_bane_effect(world_position: Vector2, world_map) -> void:
	"""Create curse effect (dark purple)."""
	var particles = _create_particle_burst(
		world_position,
		Color(0.6, 0.2, 0.6),  # Dark purple
		30,
		100.0,
		1.3
	)
	world_map.add_child(particles)

func _create_summon_effect(world_position: Vector2, world_map) -> void:
	"""Create summoning effect (bright blue portal)."""
	var particles = _create_particle_burst(
		world_position,
		Color(0.3, 0.7, 1.0),  # Bright blue
		50,
		60.0,
		1.8
	)
	world_map.add_child(particles)

func _create_particle_burst(
	position: Vector2,
	color: Color,
	particle_count: int,
	spread: float,
	lifetime: float
) -> Node2D:
	"""Create a simple particle burst effect using sprites."""
	var particle_container = Node2D.new()
	particle_container.position = position
	particle_container.name = "ParticleEffect"

	# Create multiple particle sprites
	for i in range(particle_count):
		var particle = _create_particle_sprite(color, spread, lifetime)
		particle_container.add_child(particle)

	# Auto-delete after lifetime + buffer
	var timer = Timer.new()
	timer.wait_time = lifetime + 0.5
	timer.one_shot = true
	timer.autostart = true  # Auto-start when added to scene tree
	timer.timeout.connect(func(): particle_container.queue_free())
	particle_container.add_child(timer)

	return particle_container

func _create_particle_sprite(color: Color, spread: float, lifetime: float) -> Sprite2D:
	"""Create a single particle sprite with animation."""
	var particle = Sprite2D.new()

	# Create a simple 4x4 pixel texture
	var img = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(color)
	var texture = ImageTexture.create_from_image(img)
	particle.texture = texture

	# Random direction and speed
	var angle = randf() * TAU
	var speed = randf_range(spread * 0.5, spread)
	var velocity = Vector2(cos(angle), sin(angle)) * speed

	# Initial position at center
	particle.position = Vector2.ZERO

	# Animate the particle (bound to particle lifetime)
	var tween = particle.create_tween()
	tween.set_parallel(true)

	# Move outward
	tween.tween_property(particle, "position", velocity, lifetime)

	# Fade out
	tween.tween_property(particle, "modulate:a", 0.0, lifetime)

	# Scale down
	tween.tween_property(particle, "scale", Vector2(0.1, 0.1), lifetime)

	return particle

func create_area_effect_highlight(tiles: Array[Vector2i], world_map, color: Color = Color(1, 1, 0, 0.3)) -> void:
	"""Highlight the affected area before card is played."""
	# Clear previous highlights
	_clear_highlights(world_map)

	for tile_coords in tiles:
		var tile_pos = world_map.tile_map.map_to_local(tile_coords)
		var highlight = _create_hex_highlight(tile_pos, color)
		highlight.name = "AreaHighlight"
		world_map.add_child(highlight)

func _clear_highlights(world_map) -> void:
	"""Remove all area highlights."""
	var highlights = world_map.get_tree().get_nodes_in_group("area_highlights")
	for highlight in highlights:
		highlight.queue_free()

func _create_hex_highlight(position: Vector2, color: Color) -> Polygon2D:
	"""Create a hexagon highlight overlay."""
	var hex_highlight = Polygon2D.new()
	hex_highlight.add_to_group("area_highlights")
	hex_highlight.position = position
	hex_highlight.color = color

	# Create hexagon vertices (16x16 hex)
	var size = 8.0  # Match the exact hex size from tile generation
	var vertices = PackedVector2Array()
	for i in range(6):
		var angle = (TAU / 6.0) * i  # Start at 0 degrees for flat-top hex (no offset)
		vertices.append(Vector2(cos(angle), sin(angle)) * size)

	hex_highlight.polygon = vertices

	# Animate pulsing (bound to hex_highlight lifetime)
	var tween = hex_highlight.create_tween()
	tween.set_loops()
	tween.tween_property(hex_highlight, "modulate:a", 0.5, 0.5)
	tween.tween_property(hex_highlight, "modulate:a", 0.2, 0.5)

	return hex_highlight
