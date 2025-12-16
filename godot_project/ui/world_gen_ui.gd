extends Control

signal generate_world(new_seed)

@onready var seed_edit = $Panel/VBoxContainer/SeedEdit
@onready var generate_button = $Panel/VBoxContainer/HBoxContainer/GenerateButton
@onready var random_seed_button = $Panel/VBoxContainer/HBoxContainer/RandomSeedButton
@onready var snap_to_capital_button = $Panel/VBoxContainer/HBoxContainer/SnapToCapitalButton # New button

# Tileset toggle buttons (will be created dynamically)
var tileset_buttons: Dictionary = {}

# References to dynamically created resource labels
var resource_labels: Dictionary = {}
var citizen_count_label: Label # New: Label for displaying citizen count
var hover_panel: PanelContainer # New: Panel for tile hover information
var hover_content_label: Label # New: Label for hover content

# Card system UI
var hand_container: HBoxContainer
var card_uis: Array[Control] = []
var selected_card: Card = null
var mana_label: Label
var deck_info_label: Label
var end_turn_button: Button

func _ready():
	generate_button.pressed.connect(_on_generate_pressed)
	random_seed_button.pressed.connect(_on_random_seed_pressed)
	snap_to_capital_button.pressed.connect(_on_snap_to_capital_pressed) # New: Connect snap to capital button

	_setup_resource_display()
	_setup_hover_panel()
	_setup_tileset_buttons()
	_setup_hand_ui()

	# Connect to GameManager's signal
	if GameManager:
		GameManager.player_resources_updated.connect(_on_player_resources_updated)
		GameManager.num_citizens_updated.connect(_on_num_citizens_updated) # New: Connect citizen update signal
		# Update display with any initial resources
		_on_player_resources_updated(GameManager.get_player_resources())

	# Connect to CardManager signals
	if CardManager:
		CardManager.hand_changed.connect(_on_hand_changed)
		CardManager.mana_changed.connect(_on_mana_changed)
		CardManager.card_played.connect(_on_card_played)
		# Initial update
		_on_hand_changed()
		_on_mana_changed(CardManager.current_mana)

	# Set an initial random seed
	_on_random_seed_pressed()

func _on_snap_to_capital_pressed():
	var player_civ_id = GameManager.get_player_civ()
	if player_civ_id != -1:
		var capital_coords = WorldManager.world_map_node.get_civ_capital_coords(player_civ_id)
		if capital_coords != Vector2i.ZERO:
			WorldManager.world_map_node.snap_camera_to_coords(capital_coords)
		else:
			Log.log_warning("world_gen_ui.gd: Could not find capital for player civ %d to snap camera." % player_civ_id)
	else:
		Log.log_warning("world_gen_ui.gd: Player civ not set, cannot snap camera to capital.")

func _setup_resource_display():
	# Use self (the root Control node of this scene) as the parent for bottom-left positioning
	# This ensures it's relative to the entire viewport, not just the world gen panel.
	
	var resource_background = PanelContainer.new()
	resource_background.name = "ResourceBackground"
	add_child(resource_background) # Add to the root Control of this scene

	# Position the background panel
	resource_background.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	resource_background.offset_left = 10
	resource_background.offset_bottom = -10 # Upwards from bottom edge
	# Define a fixed size for the panel
	resource_background.offset_right = resource_background.offset_left + 150 # Width: 150px
	resource_background.offset_top = resource_background.offset_bottom - 200 # Height: 200px

	# Apply a pixel art-like StyleBoxFlat for the background
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.1, 0.1, 0.1, 0.8) # Dark, semi-transparent background
	
	# Set individual border widths instead of border_width_all
	style_box.border_width_left = 2
	style_box.border_width_top = 2
	style_box.border_width_right = 2
	style_box.border_width_bottom = 2
	
	style_box.border_color = Color(0.8, 0.8, 0.8, 1.0) # Light grey border
	style_box.set_corner_radius_all(8) # Sharp corners for pixel art feel
	resource_background.add_theme_stylebox_override("panel", style_box) # Apply to PanelContainer
	
	var resource_display = VBoxContainer.new()
	resource_display.name = "ResourceDisplay"
	resource_background.add_child(resource_display)
	
	# Ensure the ResourceDisplay expands within its background panel
	resource_display.set_v_size_flags(Control.SIZE_EXPAND_FILL)
	resource_display.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	
	# Add Citizen count label
	citizen_count_label = Label.new()
	citizen_count_label.name = "CitizenCountLabel"
	citizen_count_label.text = "Citizens: 0"
	resource_display.add_child(citizen_count_label)
	
	var resources_to_display = ["food", "wood", "water", "stone", "metal_ore"]
	for res_name in resources_to_display:
		var label = Label.new()
		label.name = "%sLabel" % res_name.capitalize()
		label.text = "%s: 0" % res_name.capitalize()
		resource_labels[res_name] = label
		resource_display.add_child(label)

func _on_player_resources_updated(resources_dict: Dictionary):
	for res_name in resource_labels.keys():
		if resource_labels.has(res_name):
			var label = resource_labels[res_name]
			var amount = resources_dict.get(res_name, 0) # Directly access the integer amount
			label.text = "%s: %d" % [res_name.capitalize(), amount]

func _on_num_citizens_updated(civ_id: int, new_count: int):
	if civ_id == GameManager.player_civ_id:
		citizen_count_label.text = "Citizens: %d" % new_count

func _on_generate_pressed():
	var seed_text = seed_edit.text
	var new_world_seed = 0
	
	if seed_text.is_empty():
		# If empty, use a random seed
		new_world_seed = randi()
		seed_edit.text = str(new_world_seed)
	elif seed_text.is_valid_int():
		# If it's a number, use it
		new_world_seed = seed_text.to_int()
	else:
		# If it's a string, hash it to get a seed
		new_world_seed = seed_text.hash()
		
	emit_signal("generate_world", new_world_seed)

func _on_random_seed_pressed():
	var new_world_seed = randi()
	seed_edit.text = str(new_world_seed)
	_on_generate_pressed()

func _setup_hover_panel():
	# Create hover info panel positioned at top-right
	hover_panel = PanelContainer.new()
	hover_panel.name = "HoverPanel"
	hover_panel.visible = false # Hidden by default
	add_child(hover_panel)

	# Position at top-right
	hover_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	hover_panel.offset_right = -10
	hover_panel.offset_top = 10
	hover_panel.offset_left = hover_panel.offset_right - 250 # Width: 250px
	hover_panel.offset_bottom = hover_panel.offset_top + 180 # Height: 180px

	# Style the panel
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.1, 0.1, 0.15, 0.9) # Dark background
	style_box.border_width_left = 2
	style_box.border_width_top = 2
	style_box.border_width_right = 2
	style_box.border_width_bottom = 2
	style_box.border_color = Color(0.6, 0.7, 0.9, 1.0) # Light blue border
	style_box.set_corner_radius_all(4)
	hover_panel.add_theme_stylebox_override("panel", style_box)

	# Create content label
	hover_content_label = Label.new()
	hover_content_label.name = "HoverContent"
	hover_content_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	hover_panel.add_child(hover_content_label)

func update_hover_info(tile_data: Dictionary, coords: Vector2i):
	if not tile_data or tile_data.is_empty():
		hover_panel.visible = false
		return

	hover_panel.visible = true

	# Terrain type names
	const TERRAIN_NAMES = {
		0: "Water", 1: "Sand", 2: "Grass", 3: "Forest", 4: "Hills",
		5: "Stone", 6: "Mountains", 7: "Deep Sea", 8: "Chasm", 9: "Lava",
		10: "Snow Peak", 11: "Ice Water", 12: "Cold Water", 13: "Jungle",
		14: "Dry Grassland", 15: "Rocky Peak"
	}

	var terrain_id = tile_data.get("terrain_id", 0)
	var terrain_name = TERRAIN_NAMES.get(terrain_id, "Unknown")
	var movement_cost = tile_data.get("movement_cost", 0.0)
	var elevation = tile_data.get("elevation", 0.0)
	var has_river = tile_data.get("has_river", false)
	var civ_id = tile_data.get("civ_id", -1)
	var resources = tile_data.get("resources", {})

	# Build info text
	var info_text = ""
	info_text += "Coords: (%d, %d)\n" % [coords.x, coords.y]
	info_text += "Terrain: %s\n" % terrain_name
	info_text += "Movement Cost: %.1f\n" % movement_cost
	info_text += "Elevation: %.2f\n" % elevation

	if has_river:
		info_text += "River: Yes\n"

	if civ_id >= 0:
		info_text += "Civ ID: %d\n" % civ_id

	# Show resources if any
	if not resources.is_empty():
		info_text += "\nResources:\n"
		for res_type in resources.keys():
			var res_data = resources[res_type]
			var amount = res_data.get("amount", 0)
			if amount > 0:
				info_text += "  %s: %d\n" % [res_type.capitalize(), amount]

	hover_content_label.text = info_text

func hide_hover_info():
	if hover_panel:
		hover_panel.visible = false

func _setup_tileset_buttons():
	# Create a panel for tileset buttons at the bottom-right
	var tileset_panel = PanelContainer.new()
	tileset_panel.name = "TilesetPanel"
	add_child(tileset_panel)

	# Position at bottom-right
	tileset_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	tileset_panel.offset_right = -10
	tileset_panel.offset_bottom = -10
	tileset_panel.offset_left = tileset_panel.offset_right - 180 # Width: 180px
	tileset_panel.offset_top = tileset_panel.offset_bottom - 100 # Height: 100px

	# Style the panel
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	style_box.border_width_left = 2
	style_box.border_width_top = 2
	style_box.border_width_right = 2
	style_box.border_width_bottom = 2
	style_box.border_color = Color(0.8, 0.8, 0.8, 1.0)
	style_box.set_corner_radius_all(8)
	tileset_panel.add_theme_stylebox_override("panel", style_box)

	# Create VBox for buttons
	var vbox = VBoxContainer.new()
	vbox.name = "TilesetVBox"
	tileset_panel.add_child(vbox)

	# Add title label
	var title_label = Label.new()
	title_label.text = "Tile Style:"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)

	# Create buttons for each tileset style
	var button_names = ["Original", "Fantasy", "Fantasy (No Border)"]
	var tileset_styles = [0, 1, 2] # Correspond to TilesetStyle enum

	for i in range(button_names.size()):
		var button = Button.new()
		button.text = button_names[i]
		button.pressed.connect(_on_tileset_button_pressed.bind(tileset_styles[i]))
		vbox.add_child(button)
		tileset_buttons[tileset_styles[i]] = button

func _on_tileset_button_pressed(style: int):
	# Call the world map's change_tileset_style function
	if WorldManager.world_map_node:
		WorldManager.world_map_node.change_tileset_style(style)

func _setup_hand_ui():
	"""Set up the card hand UI at the bottom of the screen."""
	# Create main hand panel
	var hand_panel = PanelContainer.new()
	hand_panel.name = "HandPanel"
	add_child(hand_panel)

	# Position at bottom center
	hand_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hand_panel.offset_top = -180
	hand_panel.offset_left = 300
	hand_panel.offset_right = -300
	hand_panel.offset_bottom = -10

	# Style the panel
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.1, 0.1, 0.15, 0.85)
	style_box.border_width_left = 2
	style_box.border_width_top = 2
	style_box.border_width_right = 2
	style_box.border_width_bottom = 2
	style_box.border_color = Color(0.7, 0.6, 0.3, 1.0)
	style_box.set_corner_radius_all(8)
	hand_panel.add_theme_stylebox_override("panel", style_box)

	# Create vbox for panel content
	var panel_vbox = VBoxContainer.new()
	hand_panel.add_child(panel_vbox)

	# Create top bar with mana and deck info
	var top_bar = HBoxContainer.new()
	panel_vbox.add_child(top_bar)

	# Mana display
	mana_label = Label.new()
	mana_label.text = "⚡ Mana: 3/10"
	top_bar.add_child(mana_label)

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)

	# Deck info
	deck_info_label = Label.new()
	deck_info_label.text = "Deck: 0 | Hand: 0/7"
	top_bar.add_child(deck_info_label)

	# Spacer
	var spacer2 = Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer2)

	# End turn button
	end_turn_button = Button.new()
	end_turn_button.text = "End Turn"
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	top_bar.add_child(end_turn_button)

	# Create hand container
	hand_container = HBoxContainer.new()
	hand_container.alignment = BoxContainer.ALIGNMENT_CENTER
	panel_vbox.add_child(hand_container)

func _on_hand_changed():
	"""Update the hand display when cards change."""
	# Clear existing card UIs
	for card_ui in card_uis:
		card_ui.queue_free()
	card_uis.clear()

	# Create new card UIs for each card in hand
	var hand = CardManager.get_hand()
	for card in hand:
		var card_ui = preload("res://scripts/card_ui.gd").new()
		card_ui.set_card(card)
		card_ui.card_selected.connect(_on_card_selected)
		hand_container.add_child(card_ui)
		card_uis.append(card_ui)

	# Update deck info
	deck_info_label.text = "Deck: %d | Hand: %d/%d" % [
		CardManager.get_deck_size(),
		CardManager.get_hand_size(),
		CardManager.max_hand_size
	]

func _on_mana_changed(new_mana: int):
	"""Update mana display."""
	mana_label.text = "⚡ Mana: %d/%d" % [new_mana, CardManager.max_mana]

	# Update card affordability
	for card_ui in card_uis:
		if card_ui.card:
			if card_ui.card.mana_cost > new_mana:
				card_ui.modulate = Color(0.5, 0.5, 0.5, 1.0)
			else:
				card_ui.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _on_card_selected(card: Card):
	"""Called when a card is selected from the hand."""
	selected_card = card
	Log.log_info("UI: Selected card '%s'" % card.card_name)

	# Highlight selected card
	for card_ui in card_uis:
		card_ui.set_selected(card_ui.card == card)

	# Enable targeting mode
	if WorldManager.world_map_node:
		WorldManager.world_map_node.start_card_targeting(card)

func _on_card_played(card: Card):
	"""Called when a card is played."""
	selected_card = null
	Log.log_info("UI: Card '%s' was played" % card.card_name)

func _on_end_turn_pressed():
	"""End the current turn."""
	CardManager.start_turn()
	Log.log_info("UI: Turn ended, new turn started")
