extends Control

# Main menu buttons
var new_game_button: Button
var settings_button: Button
var quit_button: Button

# Title label
var title_label: Label

# Settings panel (hidden by default)
var settings_panel: PanelContainer
var is_settings_open: bool = false

func _ready():
	_setup_ui()
	Log.log_info("MainMenu: Ready")

func _setup_ui():
	"""Create the main menu UI."""
	# Create background
	var background = ColorRect.new()
	background.color = Color(0.1, 0.1, 0.15, 1.0)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	# Create center container
	var center_container = VBoxContainer.new()
	center_container.name = "CenterContainer"
	center_container.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(center_container)

	# Center the container
	center_container.set_anchors_preset(Control.PRESET_CENTER)
	center_container.offset_left = -200
	center_container.offset_right = 200
	center_container.offset_top = -300
	center_container.offset_bottom = 300

	# Title
	title_label = Label.new()
	title_label.text = "STRATFAN"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 72)
	center_container.add_child(title_label)

	# Subtitle
	var subtitle = Label.new()
	subtitle.text = "Table of the Gods"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 24)
	center_container.add_child(subtitle)

	# Spacer
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 50)
	center_container.add_child(spacer1)

	# New Game button
	new_game_button = Button.new()
	new_game_button.text = "New Game"
	new_game_button.custom_minimum_size = Vector2(300, 60)
	new_game_button.pressed.connect(_on_new_game_pressed)
	center_container.add_child(new_game_button)

	# Spacer
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 20)
	center_container.add_child(spacer2)

	# Settings button
	settings_button = Button.new()
	settings_button.text = "Settings"
	settings_button.custom_minimum_size = Vector2(300, 60)
	settings_button.pressed.connect(_on_settings_pressed)
	center_container.add_child(settings_button)

	# Spacer
	var spacer3 = Control.new()
	spacer3.custom_minimum_size = Vector2(0, 20)
	center_container.add_child(spacer3)

	# Quit button
	quit_button = Button.new()
	quit_button.text = "Quit"
	quit_button.custom_minimum_size = Vector2(300, 60)
	quit_button.pressed.connect(_on_quit_pressed)
	center_container.add_child(quit_button)

	# Version label
	var spacer4 = Control.new()
	spacer4.custom_minimum_size = Vector2(0, 50)
	center_container.add_child(spacer4)

	var version_label = Label.new()
	version_label.text = "Alpha 0.1 - Development Build"
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version_label.modulate = Color(0.7, 0.7, 0.7, 0.8)
	center_container.add_child(version_label)

	# Create settings panel (hidden by default)
	_setup_settings_panel()

func _setup_settings_panel():
	"""Create the settings panel."""
	settings_panel = PanelContainer.new()
	settings_panel.name = "SettingsPanel"
	settings_panel.visible = false
	add_child(settings_panel)

	# Center the panel
	settings_panel.set_anchors_preset(Control.PRESET_CENTER)
	settings_panel.offset_left = -300
	settings_panel.offset_right = 300
	settings_panel.offset_top = -250
	settings_panel.offset_bottom = 250

	# Style the panel
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.15, 0.15, 0.2, 0.95)
	style_box.border_width_left = 3
	style_box.border_width_top = 3
	style_box.border_width_right = 3
	style_box.border_width_bottom = 3
	style_box.border_color = Color(0.7, 0.6, 0.3, 1.0)
	style_box.set_corner_radius_all(10)
	settings_panel.add_theme_stylebox_override("panel", style_box)

	# Create content
	var vbox = VBoxContainer.new()
	settings_panel.add_child(vbox)

	# Title
	var settings_title = Label.new()
	settings_title.text = "Settings"
	settings_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_title.add_theme_font_size_override("font_size", 36)
	vbox.add_child(settings_title)

	# Spacer
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 30)
	vbox.add_child(spacer1)

	# Fullscreen option
	var fullscreen_container = HBoxContainer.new()
	vbox.add_child(fullscreen_container)

	var fullscreen_label = Label.new()
	fullscreen_label.text = "Fullscreen:"
	fullscreen_label.custom_minimum_size = Vector2(200, 0)
	fullscreen_container.add_child(fullscreen_label)

	var fullscreen_checkbox = CheckBox.new()
	fullscreen_checkbox.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen_checkbox.toggled.connect(_on_fullscreen_toggled)
	fullscreen_container.add_child(fullscreen_checkbox)

	# Spacer
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer2)

	# Volume slider (placeholder for now)
	var volume_container = HBoxContainer.new()
	vbox.add_child(volume_container)

	var volume_label = Label.new()
	volume_label.text = "Master Volume:"
	volume_label.custom_minimum_size = Vector2(200, 0)
	volume_container.add_child(volume_label)

	var volume_slider = HSlider.new()
	volume_slider.min_value = 0
	volume_slider.max_value = 100
	volume_slider.value = 80
	volume_slider.custom_minimum_size = Vector2(200, 0)
	volume_slider.value_changed.connect(_on_volume_changed)
	volume_container.add_child(volume_slider)

	# Spacer
	var spacer3 = Control.new()
	spacer3.custom_minimum_size = Vector2(0, 50)
	vbox.add_child(spacer3)

	# Back button
	var back_button = Button.new()
	back_button.text = "Back"
	back_button.custom_minimum_size = Vector2(200, 50)
	back_button.pressed.connect(_on_settings_back_pressed)
	vbox.add_child(back_button)

func _on_new_game_pressed():
	"""Start a new game."""
	Log.log_info("MainMenu: Starting new game")
	get_tree().change_scene_to_file("res://scenes/world_map.tscn")

func _on_settings_pressed():
	"""Open settings panel."""
	Log.log_info("MainMenu: Opening settings")
	settings_panel.visible = true
	is_settings_open = true

func _on_settings_back_pressed():
	"""Close settings panel."""
	Log.log_info("MainMenu: Closing settings")
	settings_panel.visible = false
	is_settings_open = false

func _on_quit_pressed():
	"""Quit the game."""
	Log.log_info("MainMenu: Quitting game")
	get_tree().quit()

func _on_fullscreen_toggled(enabled: bool):
	"""Toggle fullscreen mode."""
	if enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	Log.log_info("MainMenu: Fullscreen %s" % ("enabled" if enabled else "disabled"))

func _on_volume_changed(value: float):
	"""Change master volume (placeholder for now)."""
	# TODO: Implement actual audio system
	Log.log_info("MainMenu: Volume changed to %d%%" % int(value))

func _input(event: InputEvent):
	"""Handle input events."""
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if is_settings_open:
				_on_settings_back_pressed()
