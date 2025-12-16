extends PanelContainer
class_name CardUI

signal card_selected(card: Card)
signal card_hovered(card: Card)
signal card_unhovered

var card: Card
var is_hovered: bool = false
var is_selected: bool = false

var card_name_label: Label
var mana_cost_label: Label
var description_label: Label
var type_label: Label

func _init():
	# Create UI elements in constructor so they exist immediately
	_setup_ui()

func _ready():
	# Connect mouse events
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)

func _setup_ui():
	"""Create the card UI elements."""
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

	# Type
	type_label = Label.new()
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(type_label)

	# Description
	description_label = Label.new()
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	description_label.custom_minimum_size = Vector2(100, 60)
	vbox.add_child(description_label)

	# Set minimum size for the card
	custom_minimum_size = Vector2(120, 160)

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

	# Style based on card color
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = card.card_color.darkened(0.3)
	style_box.border_color = card.card_color
	style_box.border_width_left = 2
	style_box.border_width_top = 2
	style_box.border_width_right = 2
	style_box.border_width_bottom = 2
	style_box.set_corner_radius_all(6)
	add_theme_stylebox_override("panel", style_box)

	# Check if we can afford this card
	if card.mana_cost > CardManager.current_mana:
		modulate = Color(0.5, 0.5, 0.5, 1.0)
	else:
		modulate = Color(1.0, 1.0, 1.0, 1.0)

func _on_mouse_entered():
	is_hovered = true
	# Enlarge slightly on hover
	if card and card.mana_cost <= CardManager.current_mana:
		scale = Vector2(1.1, 1.1)
		z_index = 10
		card_hovered.emit(card)

func _on_mouse_exited():
	is_hovered = false
	scale = Vector2(1.0, 1.0)
	z_index = 0
	card_unhovered.emit()

func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if card and card.mana_cost <= CardManager.current_mana:
				card_selected.emit(card)

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
