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
var resource_trend_labels: Dictionary = {}  # Track resource trends
var previous_resources: Dictionary = {}  # Store previous resource values
var citizen_count_label: Label # New: Label for displaying citizen count
var hover_panel: PanelContainer # New: Panel for tile hover information
var hover_content_label: RichTextLabel # New: Label for hover content

# Card system UI
var hand_container: HBoxContainer
var card_uis: Array[Control] = []
var selected_card: Card = null
var mana_label: Label
var deck_info_label: Label
var turn_label: Label
var end_turn_button: Button
var enlarged_card_view: CardUI = null

# Minimap
var minimap: Minimap

# Action Log
var action_log: ActionLog

func _ready():
	generate_button.pressed.connect(_on_generate_pressed)
	random_seed_button.pressed.connect(_on_random_seed_pressed)
	snap_to_capital_button.pressed.connect(_on_snap_to_capital_pressed) # New: Connect snap to capital button

	_setup_resource_display()
	_setup_hover_panel()
	_setup_tileset_buttons()
	_setup_hand_ui()
	_setup_minimap()
	_setup_notifications()
	_setup_action_log()
	_setup_unit_commands()

	# Connect to GameManager's signals
	if GameManager:
		GameManager.player_resources_updated.connect(_on_player_resources_updated)
		GameManager.num_citizens_updated.connect(_on_num_citizens_updated) # New: Connect citizen update signal
		GameManager.phase_changed.connect(_on_phase_changed)
		# Update display with any initial resources
		_on_player_resources_updated(GameManager.get_player_resources())

	# Connect to VictoryManager
	if VictoryManager:
		VictoryManager.game_over.connect(_on_game_over)

	# Connect to CardManager signals
	if CardManager:
		CardManager.hand_changed.connect(_on_hand_changed)
		CardManager.mana_changed.connect(_on_mana_changed)
		CardManager.card_played.connect(_on_card_played)
		# Initial update
		_on_hand_changed()
		_on_mana_changed(CardManager.current_mana)

	# Connect to VictoryManager signals
	if VictoryManager:
		VictoryManager.game_over.connect(_on_game_over)

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

	# Position the background panel (moved higher to avoid overlap with hand panel)
	resource_background.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	resource_background.offset_left = 10
	resource_background.offset_bottom = -190 # Upwards from bottom edge, above hand panel
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
		# Create HBox for resource name and trend
		var hbox = HBoxContainer.new()
		resource_display.add_child(hbox)

		# Resource label
		var label = Label.new()
		label.name = "%sLabel" % res_name.capitalize()
		label.text = "%s: 0" % res_name.capitalize()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		resource_labels[res_name] = label
		hbox.add_child(label)

		# Trend indicator label
		var trend_label = Label.new()
		trend_label.name = "%sTrendLabel" % res_name.capitalize()
		trend_label.text = ""
		trend_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		trend_label.custom_minimum_size = Vector2(40, 0)
		resource_trend_labels[res_name] = trend_label
		hbox.add_child(trend_label)

		# Initialize previous resources
		previous_resources[res_name] = 0

func _on_player_resources_updated(resources_dict: Dictionary):
	for res_name in resource_labels.keys():
		if resource_labels.has(res_name):
			var label = resource_labels[res_name]
			var amount = resources_dict.get(res_name, 0) # Directly access the integer amount
			label.text = "%s: %d" % [res_name.capitalize(), amount]

			# Calculate trend
			if resource_trend_labels.has(res_name):
				var trend_label = resource_trend_labels[res_name]
				var previous = previous_resources.get(res_name, amount)
				var delta = amount - previous

				if delta > 0:
					trend_label.text = "+%d" % delta
					trend_label.add_theme_color_override("font_color", Color(0, 1, 0, 1))  # Green for gain
				elif delta < 0:
					trend_label.text = "%d" % delta  # Already has minus sign
					trend_label.add_theme_color_override("font_color", Color(1, 0, 0, 1))  # Red for loss
				else:
					trend_label.text = "="
					trend_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))  # Gray for stable

				# Store current as previous for next update
				previous_resources[res_name] = amount

			# Warning for low resources (food and water are critical)
			if res_name in ["food", "water"]:
				if amount < 10 and amount > 0:
					# Show warning color
					label.add_theme_color_override("font_color", Color(1, 0.5, 0, 1))
				elif amount == 0:
					# Show critical color
					label.add_theme_color_override("font_color", Color(1, 0, 0, 1))
					NotificationManager.notify_low_resources(res_name)
				else:
					# Normal color
					label.remove_theme_color_override("font_color")

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
	hover_content_label = RichTextLabel.new()
	hover_content_label.name = "HoverContent"
	hover_content_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	hover_content_label.add_theme_font_size_override("font_size", 12)
	hover_panel.add_child(hover_content_label)

	# Enable rich text for BBCode formatting (Godot 4 equivalent)
	# In Godot 4, RichTextLabel is needed for BBCode
	# Let's replace the Label with RichTextLabel
	hover_panel.remove_child(hover_content_label)
	hover_content_label.queue_free()

	hover_content_label = RichTextLabel.new()
	hover_content_label.name = "HoverContent"
	hover_content_label.bbcode_enabled = true
	hover_content_label.fit_content = true
	hover_content_label.scroll_active = false
	hover_content_label.add_theme_font_size_override("normal_font_size", 12)
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

	const LANDMARK_NAMES = {
		0: "Castle",
		1: "Village",
		2: "Ruins"
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
	info_text += "[b]Coords: (%d, %d)[/b]\n" % [coords.x, coords.y]
	info_text += "Terrain: %s\n" % terrain_name
	info_text += "Movement: %.1f\n" % movement_cost
	info_text += "Elevation: %.2f\n" % elevation

	if has_river:
		info_text += "[color=cyan]River: Yes[/color]\n"

	if civ_id >= 0:
		var civ_label = "Your Civ" if civ_id == GameManager.player_civ_id else "Civ %d" % civ_id
		var color = "cyan" if civ_id == GameManager.player_civ_id else "orange"
		info_text += "[color=%s]%s[/color]\n" % [color, civ_label]

	# Check for landmarks
	if WorldManager.world_map_node:
		var landmark_id = WorldManager.world_map_node.landmarks_map.get_cell_source_id(0, coords)
		if landmark_id >= 0:
			var landmark_name = LANDMARK_NAMES.get(landmark_id, "Unknown")
			info_text += "[color=purple]⚑ %s[/color]\n" % landmark_name

	# Check for citizens
	var citizens_here = _count_citizens_at_tile(coords)
	if citizens_here > 0:
		info_text += "[color=green]☺ Citizens: %d[/color]\n" % citizens_here

	# Show resources if any
	if not resources.is_empty():
		var has_resources = false
		var res_text = ""
		for res_type in resources.keys():
			var res_data = resources[res_type]
			var amount = res_data.get("amount", 0)
			if amount > 0:
				has_resources = true
				res_text += "  %s: %d\n" % [res_type.capitalize(), amount]

		if has_resources:
			info_text += "\n[color=yellow]Resources:[/color]\n" + res_text

	hover_content_label.text = info_text

func _count_citizens_at_tile(coords: Vector2i) -> int:
	"""Count how many citizens are at the given tile."""
	var count = 0
	if WorldManager.world_map_node:
		for child in WorldManager.world_map_node.get_children():
			if child.is_in_group("citizens"):
				if child.has_method("get_current_tile_coords"):
					if child.get_current_tile_coords() == coords:
						count += 1
	return count

func hide_hover_info():
	if hover_panel:
		hover_panel.visible = false

func _setup_tileset_buttons():
	# Create a panel for tileset buttons at the bottom-right
	var tileset_panel = PanelContainer.new()
	tileset_panel.name = "TilesetPanel"
	add_child(tileset_panel)

	# Position at bottom-right (moved to avoid overlap with hand panel)
	tileset_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	tileset_panel.offset_right = -10
	tileset_panel.offset_bottom = -190 # Above hand panel
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

	# Position at bottom center (increased height for full cards)
	hand_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hand_panel.offset_top = -240  # Increased to -240 to fully show cards (160px + top bar + padding)
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

	# Turn counter
	turn_label = Label.new()
	turn_label.text = "Turn: 0/200"
	top_bar.add_child(turn_label)

	# Spacer
	var spacer0 = Control.new()
	spacer0.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer0)

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
		card_ui.request_enlarged_view.connect(_on_request_enlarged_view)
		card_ui.request_hide_enlarged_view.connect(_on_request_hide_enlarged_view)
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
	"""End the current turn by processing actions and starting simulation phase."""
	Log.log_info("UI: End turn button pressed.")

	# Disable end turn button during processing/simulation
	end_turn_button.disabled = true

	# Change to processing phase
	GameManager.set_phase(GameManager.TurnPhase.PROCESSING)

	# Process all queued player actions
	var actions_processed = ActionQueue.process_actions()

	if actions_processed:
		Log.log_info("UI: Player actions processed.")

	# Play AI deity cards
	AIManager.take_ai_turns()

	# Start simulation phase (units move/act for a few seconds)
	GameManager.set_phase(GameManager.TurnPhase.SIMULATION)

	# Re-enable end turn button after simulation completes
	# This happens automatically when phase returns to PLAYER_TURN
	_update_turn_display()
	Log.log_info("UI: Simulation phase started.")

func _update_turn_display():
	"""Update turn counter display."""
	if turn_label and VictoryManager:
		turn_label.text = "Turn: %d/%d" % [VictoryManager.get_current_turn(), VictoryManager.max_turns]

func _on_phase_changed(new_phase: GameManager.TurnPhase):
	"""Called when turn phase changes."""
	if new_phase == GameManager.TurnPhase.PLAYER_TURN:
		# Re-enable end turn button for player's turn
		if end_turn_button:
			end_turn_button.disabled = false
		_update_turn_display()
	elif new_phase == GameManager.TurnPhase.SIMULATION:
		# Show simulation phase notification
		NotificationManager.notify_info("Units acting...")

func _setup_minimap():
	"""Set up the minimap in the top-left corner."""
	# Load minimap script
	var MinimapScript = preload("res://scripts/minimap.gd")
	minimap = MinimapScript.new()
	minimap.name = "Minimap"
	add_child(minimap)

	# Position at top-left
	minimap.set_anchors_preset(Control.PRESET_TOP_LEFT)
	minimap.offset_left = 10
	minimap.offset_top = 10
	minimap.offset_right = minimap.offset_left + 200
	minimap.offset_bottom = minimap.offset_top + 200

	# Style the minimap with a border
	var panel = PanelContainer.new()
	panel.name = "MinimapPanel"
	minimap.add_child(panel)
	minimap.move_child(panel, 0)  # Move to back

	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0, 0, 0, 0.9)
	style_box.border_width_left = 2
	style_box.border_width_top = 2
	style_box.border_width_right = 2
	style_box.border_width_bottom = 2
	style_box.border_color = Color(0.8, 0.8, 0.8, 1.0)
	style_box.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style_box)

	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Add mode toggle buttons
	var mode_hbox = HBoxContainer.new()
	mode_hbox.name = "MinimapModeButtons"
	minimap.add_child(mode_hbox)

	# Position buttons below minimap using proper offset
	mode_hbox.set_anchors_preset(Control.PRESET_TOP_LEFT)
	mode_hbox.offset_left = 0
	mode_hbox.offset_top = 205

	var terrain_btn = Button.new()
	terrain_btn.text = "T"
	terrain_btn.tooltip_text = "Terrain Mode"
	terrain_btn.custom_minimum_size = Vector2(30, 20)
	terrain_btn.pressed.connect(func(): minimap.change_mode(0))
	mode_hbox.add_child(terrain_btn)

	var civ_btn = Button.new()
	civ_btn.text = "C"
	civ_btn.tooltip_text = "Civilization Mode"
	civ_btn.custom_minimum_size = Vector2(30, 20)
	civ_btn.pressed.connect(func(): minimap.change_mode(1))
	mode_hbox.add_child(civ_btn)

	var res_btn = Button.new()
	res_btn.text = "R"
	res_btn.tooltip_text = "Resource Mode"
	res_btn.custom_minimum_size = Vector2(30, 20)
	res_btn.pressed.connect(func(): minimap.change_mode(2))
	mode_hbox.add_child(res_btn)

	Log.log_info("UI: Minimap setup complete")

func initialize_minimap():
	"""Initialize minimap with world data (call after world generation)."""
	if minimap and WorldManager.world_map_node:
		minimap.initialize(WorldManager.world_map_node)
		Log.log_info("UI: Minimap initialized with world data")

func _setup_notifications():
	"""Setup the notification system."""
	NotificationManager.setup_ui(self)
	Log.log_info("UI: Notification system setup complete")

func _setup_action_log():
	"""Setup the action log panel."""
	var ActionLogScript = preload("res://scripts/action_log.gd")
	action_log = ActionLogScript.new()
	action_log.name = "ActionLog"
	add_child(action_log)

	# Position at left side, above resource panel
	action_log.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	action_log.offset_left = 10
	action_log.offset_bottom = -400  # Above resource panel
	action_log.offset_right = action_log.offset_left + 350
	action_log.offset_top = action_log.offset_bottom - 200

	Log.log_info("UI: Action log setup complete")

func _setup_unit_commands():
	"""Setup unit command buttons for both workers and warriors."""
	# Worker Commands Panel
	var worker_panel = PanelContainer.new()
	worker_panel.name = "WorkerCommandPanel"
	add_child(worker_panel)

	# Position at top-right, below hover panel
	worker_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	worker_panel.offset_right = -10
	worker_panel.offset_top = 200
	worker_panel.offset_left = worker_panel.offset_right - 200
	worker_panel.offset_bottom = worker_panel.offset_top + 200

	# Style panel
	var worker_style = StyleBoxFlat.new()
	worker_style.bg_color = Color(0.1, 0.1, 0.15, 0.85)
	worker_style.border_width_left = 2
	worker_style.border_width_top = 2
	worker_style.border_width_right = 2
	worker_style.border_width_bottom = 2
	worker_style.border_color = Color(0.5, 0.7, 0.5, 1.0)
	worker_style.set_corner_radius_all(6)
	worker_panel.add_theme_stylebox_override("panel", worker_style)

	var worker_vbox = VBoxContainer.new()
	worker_panel.add_child(worker_vbox)

	# Title
	var worker_title = Label.new()
	worker_title.text = "Worker Commands"
	worker_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	worker_title.add_theme_font_size_override("font_size", 14)
	worker_vbox.add_child(worker_title)

	# Worker command buttons
	var worker_commands = [
		{"text": "Gather Food/Water", "command": 0},
		{"text": "Gather Materials", "command": 1},
		{"text": "Defend", "command": 2},
		{"text": "Seek & Destroy", "command": 3},
		{"text": "Expand Territory", "command": 4},
	]

	for cmd_data in worker_commands:
		var btn = Button.new()
		btn.text = cmd_data.text
		btn.pressed.connect(_on_worker_command_pressed.bind(cmd_data.command))
		worker_vbox.add_child(btn)

	# Warrior Commands Panel
	var warrior_panel = PanelContainer.new()
	warrior_panel.name = "WarriorCommandPanel"
	add_child(warrior_panel)

	# Position below worker panel
	warrior_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	warrior_panel.offset_right = -10
	warrior_panel.offset_top = 410
	warrior_panel.offset_left = warrior_panel.offset_right - 200
	warrior_panel.offset_bottom = warrior_panel.offset_top + 160

	# Style panel
	var warrior_style = StyleBoxFlat.new()
	warrior_style.bg_color = Color(0.15, 0.1, 0.1, 0.85)
	warrior_style.border_width_left = 2
	warrior_style.border_width_top = 2
	warrior_style.border_width_right = 2
	warrior_style.border_width_bottom = 2
	warrior_style.border_color = Color(0.7, 0.5, 0.5, 1.0)
	warrior_style.set_corner_radius_all(6)
	warrior_panel.add_theme_stylebox_override("panel", warrior_style)

	var warrior_vbox = VBoxContainer.new()
	warrior_panel.add_child(warrior_vbox)

	# Title
	var warrior_title = Label.new()
	warrior_title.text = "Warrior Commands"
	warrior_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warrior_title.add_theme_font_size_override("font_size", 14)
	warrior_vbox.add_child(warrior_title)

	# Warrior command buttons
	var warrior_commands = [
		{"text": "Attack", "command": 0},      # Warrior.Command.ATTACK
		{"text": "Defend", "command": 1},     # Warrior.Command.DEFEND
		{"text": "Patrol", "command": 2},     # Warrior.Command.PATROL
		{"text": "Guard", "command": 3},      # Warrior.Command.GUARD
	]

	for cmd_data in warrior_commands:
		var btn = Button.new()
		btn.text = cmd_data.text
		btn.pressed.connect(_on_warrior_command_pressed.bind(cmd_data.command))
		warrior_vbox.add_child(btn)

	Log.log_info("UI: Worker and warrior commands setup complete")

func _on_worker_command_pressed(command: int):
	"""Set all player workers to the given command."""
	if not WorldManager.world_map_node:
		return

	var player_civ = GameManager.get_player_civ()
	var workers_updated = 0

	for child in WorldManager.world_map_node.get_children():
		if child.is_in_group("citizens") and not child.is_in_group("warriors") and child.civ_id == player_civ:
			child.set_command(command)
			workers_updated += 1

	var command_names = ["Gather Food/Water", "Gather Materials", "Defend", "Seek & Destroy", "Expand Territory"]
	NotificationManager.notify_success("%d workers set to: %s" % [workers_updated, command_names[command]])
	Log.log_info("UI: Set %d player workers to command %d" % [workers_updated, command])

func _on_warrior_command_pressed(command: int):
	"""Set all player warriors to the given command."""
	if not WorldManager.world_map_node:
		return

	var player_civ = GameManager.get_player_civ()
	var warriors_updated = 0

	for child in WorldManager.world_map_node.get_children():
		if child.is_in_group("warriors") and child.civ_id == player_civ:
			child.set_command(command)
			warriors_updated += 1

	var command_names = ["Attack", "Defend", "Patrol", "Guard"]
	NotificationManager.notify_success("%d warriors set to: %s" % [warriors_updated, command_names[command]])
	Log.log_info("UI: Set %d player warriors to command %d" % [warriors_updated, command])

func _on_game_over(victory: bool, reason: String):
	"""Display victory/loss screen."""
	# Pause the game
	get_tree().paused = true

	# Create victory/loss screen
	var overlay = ColorRect.new()
	overlay.name = "GameOverOverlay"
	overlay.color = Color(0, 0, 0, 0.8)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -300
	panel.offset_right = 300
	panel.offset_top = -200
	panel.offset_bottom = 200
	overlay.add_child(panel)

	# Style
	var style = StyleBoxFlat.new()
	if victory:
		style.bg_color = Color(0.2, 0.6, 0.2, 0.95)
		style.border_color = Color(0.4, 1.0, 0.4, 1.0)
	else:
		style.bg_color = Color(0.6, 0.2, 0.2, 0.95)
		style.border_color = Color(1.0, 0.4, 0.4, 1.0)
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	panel.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "VICTORY!" if victory else "DEFEAT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	vbox.add_child(title)

	# Spacer
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer1)

	# Reason
	var reason_label = Label.new()
	reason_label.text = reason
	reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	reason_label.custom_minimum_size = Vector2(500, 0)
	vbox.add_child(reason_label)

	# Stats
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer2)

	var stats = VBoxContainer.new()
	vbox.add_child(stats)

	var turn_stat = Label.new()
	turn_stat.text = "Turns Survived: %d" % VictoryManager.get_current_turn()
	turn_stat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_child(turn_stat)

	var citizen_stat = Label.new()
	citizen_stat.text = "Citizens: %d" % VictoryManager.get_player_citizen_count()
	citizen_stat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_child(citizen_stat)

	var territory_stat = Label.new()
	territory_stat.text = "Territory: %d tiles (%.1f%%)" % [VictoryManager.get_player_territory_count(), VictoryManager.get_player_territory_percent()]
	territory_stat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_child(territory_stat)

	var score_stat = Label.new()
	score_stat.text = "Final Score: %d" % VictoryManager.calculate_player_score()
	score_stat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_child(score_stat)

	# Buttons
	var spacer3 = Control.new()
	spacer3.custom_minimum_size = Vector2(0, 30)
	vbox.add_child(spacer3)

	var button_hbox = HBoxContainer.new()
	button_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(button_hbox)

	var restart_btn = Button.new()
	restart_btn.text = "New Game"
	restart_btn.custom_minimum_size = Vector2(150, 40)
	restart_btn.pressed.connect(_on_restart_game)
	button_hbox.add_child(restart_btn)

	var spacer4 = Control.new()
	spacer4.custom_minimum_size = Vector2(20, 0)
	button_hbox.add_child(spacer4)

	var quit_btn = Button.new()
	quit_btn.text = "Quit"
	quit_btn.custom_minimum_size = Vector2(150, 40)
	quit_btn.pressed.connect(_on_quit_game)
	button_hbox.add_child(quit_btn)

func _on_restart_game():
	"""Restart the game."""
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_quit_game():
	"""Quit to desktop."""
	get_tree().quit()

func _on_request_enlarged_view(card_ui: CardUI):
	if enlarged_card_view:
		enlarged_card_view.queue_free()
		enlarged_card_view = null

	enlarged_card_view = preload("res://scripts/card_ui.gd").new()
	enlarged_card_view.set_card(card_ui.card)

	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 10
	add_child(canvas_layer)
	canvas_layer.add_child(enlarged_card_view)

	enlarged_card_view.scale = Vector2(2.0, 2.0)
	var viewport_size = get_viewport().get_visible_rect().size
	enlarged_card_view.position = (viewport_size - enlarged_card_view.get_rect().size * 2) / 2

func _on_request_hide_enlarged_view():
	if enlarged_card_view:
		enlarged_card_view.get_parent().queue_free()
		enlarged_card_view = null
