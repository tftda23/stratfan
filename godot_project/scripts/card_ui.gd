extends PanelContainer
class_name CardUI

signal card_selected(card: Card)
signal card_hovered(card: Card)
signal card_unhovered
signal request_enlarged_view(card_ui: CardUI)
signal request_hide_enlarged_view

var card: Card
var is_hovered: bool = false
var is_selected: bool = false
var is_dragging: bool = false
var drag_start_pos: Vector2
var drag_ghost: Control = null

var card_name_label: Label
var mana_cost_label: Label
var description_label: Label
var type_label: Label
var illustration_rect: TextureRect

var hover_timer: Timer

const CARD_WIDTH = 150
const CARD_HEIGHT = 250

var card_background_texture: Texture2D = preload("res://assets/card_art/card_background.png")
var default_illustration_texture: Texture2D = preload("res://assets/card_art/illustrations/citizen.png")

func _init():
	# Create UI elements in constructor so they exist immediately
	_setup_ui()

func _ready():
	# Connect mouse events
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)

	# Setup hover timer
	hover_timer = Timer.new()
	add_child(hover_timer)
	hover_timer.wait_time = 1.0
	hover_timer.one_shot = true
	hover_timer.timeout.connect(_on_hover_timer_timeout)

func _setup_ui():
	"""Create the card UI elements."""
	custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	
	var background = TextureRect.new()
	background.texture = card_background_texture
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(background)

	var vbox = VBoxContainer.new()
	add_child(vbox)

	# Card name
	card_name_label = Label.new()
	card_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(card_name_label)

	# Mana cost
	mana_cost_label = Label.new()
	mana_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(mana_cost_label)
	
	# Illustration
	illustration_rect = TextureRect.new()
	illustration_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	illustration_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	illustration_rect.custom_minimum_size = Vector2(120, 100)
	vbox.add_child(illustration_rect)

	# Type
	type_label = Label.new()
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(type_label)

	# Description
	description_label = Label.new()
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	description_label.custom_minimum_size = Vector2(100, 60)
	vbox.add_child(description_label)

func set_card(new_card: Card):
	"""Set the card to display."""
	card = new_card
	_update_display()

func _update_display():
	"""Update the visual display of the card."""
	if not card:
		return

	card_name_label.text = card.card_name
	mana_cost_label.text = "⚡ %d" % card.mana_cost
	type_label.text = "[%s]" % card.card_type.capitalize()
	description_label.text = card.card_description
	
	var illustration_path = "res://assets/card_art/illustrations/%s.png" % card.card_name.to_lower().replace(" ", "_")
	if FileAccess.file_exists(illustration_path):
		illustration_rect.texture = load(illustration_path)
	else:
		illustration_rect.texture = default_illustration_texture

	# Style based on card color and rarity
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color.TRANSPARENT #card.card_color.darkened(0.3)
	style_box.border_color = card.get_rarity_color()  # Use rarity color for border
	style_box.border_width_left = 3
	style_box.border_width_top = 3
	style_box.border_width_right = 3
	style_box.border_width_bottom = 3
	style_box.set_corner_radius_all(6)
	add_theme_stylebox_override("panel", style_box)

	# Check if we can afford this card
	if card.mana_cost > CardManager.current_mana:
		modulate = Color(0.5, 0.5, 0.5, 1.0)
	else:
		modulate = Color(1.0, 1.0, 1.0, 1.0)

func _on_mouse_entered():
	is_hovered = true
	# Enlarge slightly on hover with smooth animation
	if card and card.mana_cost <= CardManager.current_mana:
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_BACK)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.2)
		z_index = 10
		card_hovered.emit(card)
		hover_timer.start()

func _on_mouse_exited():
	is_hovered = false
	# Smoothly return to normal size
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15)
	z_index = 0
	card_unhovered.emit()
	hover_timer.stop()
	request_hide_enlarged_view.emit()

func _on_hover_timer_timeout():
	if is_hovered:
		request_enlarged_view.emit(self)

func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Start potential drag
				if card and card.mana_cost <= CardManager.current_mana:
					drag_start_pos = event.position
					is_dragging = false  # Will become true if mouse moves enough
			else:
				# Mouse released
				if is_dragging:
					_end_drag(event)
				else:
					# Just a click, select the card
					if card and card.mana_cost <= CardManager.current_mana:
						card_selected.emit(card)

	if event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			# Check if we should start dragging
			if not is_dragging and drag_start_pos.distance_to(event.position) > 5:
				_start_drag()

			if is_dragging:
				_update_drag(event)

func set_selected(selected: bool):
	"""Mark this card as selected."""
	is_selected = selected
	if selected:
		var style_box = get_theme_stylebox("panel")
		if style_box is StyleBoxFlat:
			style_box.border_color = Color.YELLOW
			style_box.border_width_left = 4
			style_box.border_width_top = 4
			style_box.border_width_right = 4
			style_box.border_width_bottom = 4
	else:
		_update_display()

func _start_drag():
	"""Start dragging the card."""
	if not card or card.mana_cost > CardManager.current_mana:
		return

	is_dragging = true
	Log.log_info("CardUI: Started dragging card '%s'" % card.card_name)

	# Create drag ghost
	_create_drag_ghost()

	# Hide original card while dragging
	modulate.a = 0.5

	# Start targeting mode
	if WorldManager.world_map_node:
		WorldManager.world_map_node.start_card_targeting(card)

func _update_drag(event: InputEventMouseMotion):
	"""Update drag ghost position."""
	if drag_ghost:
		# Get mouse position in viewport
		var viewport = get_viewport()
		var mouse_pos = viewport.get_mouse_position()
		drag_ghost.global_position = mouse_pos - drag_ghost.size / 2

func _end_drag(event: InputEventMouseButton):
	"""End dragging and try to play the card."""
	if not is_dragging:
		return

	is_dragging = false
	modulate.a = 1.0

	# Remove drag ghost
	if drag_ghost:
		drag_ghost.queue_free()
		drag_ghost = null

	# Get mouse position and try to play card
	var viewport = get_viewport()
	var mouse_pos = viewport.get_mouse_position()

	# Check if we're over the world map
	if WorldManager.world_map_node:
		var world_map = WorldManager.world_map_node
		var camera = world_map.camera
		var world_pos = camera.get_global_transform_with_canvas().affine_inverse() * mouse_pos
		var tile_coords = world_map.tile_map.local_to_map(world_pos)

		# Try to play the card
		if world_map._tile_data.has(tile_coords):
			if CardManager.play_card(card, tile_coords):
				Log.log_info("CardUI: Played card at %s via drag" % tile_coords)
			else:
				Log.log_warning("CardUI: Failed to play card via drag")

		# Cancel targeting mode
		world_map.cancel_card_targeting()

	Log.log_info("CardUI: Ended dragging card")

func _create_drag_ghost():
	"""Create a visual ghost of the card that follows the mouse."""
	if drag_ghost:
		drag_ghost.queue_free()

	drag_ghost = PanelContainer.new()
	drag_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_ghost.z_index = 100

	# Copy the style
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = card.card_color.darkened(0.3)
	style_box.border_color = card.card_color.lightened(0.3)
	style_box.border_width_left = 3
	style_box.border_width_top = 3
	style_box.border_width_right = 3
	style_box.border_width_bottom = 3
	style_box.set_corner_radius_all(8)
	drag_ghost.add_theme_stylebox_override("panel", style_box)

	# Add card info
	var vbox = VBoxContainer.new()
	drag_ghost.add_child(vbox)

	var name_label = Label.new()
	name_label.text = card.card_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)

	var mana_label = Label.new()
	mana_label.text = "⚡ %d" % card.mana_cost
	mana_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(mana_label)

	# Set size
	drag_ghost.custom_minimum_size = Vector2(120, 80)

	# Add to viewport
	get_viewport().add_child(drag_ghost)
	drag_ghost.modulate = Color(1, 1, 1, 0.8)

	# Animate ghost appearing
	drag_ghost.scale = Vector2(0.8, 0.8)
	var tween = drag_ghost.create_tween()
	tween.tween_property(drag_ghost, "scale", Vector2(1.0, 1.0), 0.15)
