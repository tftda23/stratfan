extends PanelContainer
class_name ActionLog

var log_container: VBoxContainer
var scroll_container: ScrollContainer
var max_log_entries: int = 50
var log_entries: Array = []

func _ready():
	_setup_ui()

	# Connect to NotificationManager to capture all notifications
	if NotificationManager:
		NotificationManager.notification_added.connect(_on_notification_added)

func _setup_ui():
	"""Setup the action log UI."""
	# Style the panel
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.05, 0.05, 0.1, 0.9)
	style_box.border_width_left = 2
	style_box.border_width_top = 2
	style_box.border_width_right = 2
	style_box.border_width_bottom = 2
	style_box.border_color = Color(0.6, 0.6, 0.7, 1.0)
	style_box.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", style_box)

	# Create vbox for layout
	var vbox = VBoxContainer.new()
	add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "Action Log"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)

	# Separator
	var separator = HSeparator.new()
	vbox.add_child(separator)

	# Scroll container
	scroll_container = ScrollContainer.new()
	scroll_container.custom_minimum_size = Vector2(0, 150)
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	vbox.add_child(scroll_container)

	# Log container
	log_container = VBoxContainer.new()
	log_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.add_child(log_container)

	# Add initial message
	add_log_entry("Game started", Color(0.7, 0.7, 0.7))

func add_log_entry(message: String, color: Color = Color.WHITE):
	"""Add an entry to the action log."""
	# Get timestamp
	var time = Time.get_ticks_msec() / 1000.0
	var minutes = int(time / 60)
	var seconds = int(time) % 60

	# Create entry
	var entry = RichTextLabel.new()
	entry.bbcode_enabled = true
	entry.fit_content = true
	entry.scroll_active = false
	entry.custom_minimum_size = Vector2(0, 20)
	entry.add_theme_font_size_override("normal_font_size", 11)

	# Format with timestamp and color
	var color_hex = color.to_html(false)
	entry.text = "[color=#888888][%02d:%02d][/color] [color=#%s]%s[/color]" % [minutes, seconds, color_hex, message]

	# Add to container
	log_container.add_child(entry)
	log_entries.append(entry)

	# Limit entries
	if log_entries.size() > max_log_entries:
		var oldest = log_entries.pop_front()
		oldest.queue_free()

	# Auto-scroll to bottom
	await get_tree().process_frame
	if scroll_container:
		scroll_container.scroll_vertical = int(scroll_container.get_v_scroll_bar().max_value)

func _on_notification_added(message: String, type: String):
	"""Handle notifications from NotificationManager."""
	var color = Color.WHITE

	match type:
		"INFO":
			color = Color(0.6, 0.7, 0.9)
		"SUCCESS":
			color = Color(0.6, 0.9, 0.6)
		"WARNING":
			color = Color(0.9, 0.7, 0.4)
		"ERROR":
			color = Color(0.9, 0.4, 0.4)
		"ACHIEVEMENT":
			color = Color(1.0, 0.9, 0.4)

	add_log_entry(message, color)

# Additional game-specific log methods
func log_card_played(player: String, card_name: String):
	add_log_entry("%s played %s" % [player, card_name], Color(0.6, 0.9, 0.6))

func log_resource_gathered(resource: String, amount: int):
	add_log_entry("Gathered %d %s" % [amount, resource], Color(0.8, 0.8, 0.5))

func log_citizen_spawn(count: int):
	add_log_entry("Spawned %d citizen(s)" % count, Color(0.6, 0.8, 0.9))

func log_citizen_death():
	add_log_entry("Citizen died", Color(0.9, 0.4, 0.4))

func log_turn_change(turn: int):
	add_log_entry("═══ Turn %d ═══" % turn, Color(0.9, 0.9, 0.5))
