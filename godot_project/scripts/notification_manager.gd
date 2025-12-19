extends Node

# Singleton for managing toast notifications

signal notification_added(message: String, type: String)

enum NotificationType {
	INFO,      # Blue
	SUCCESS,   # Green
	WARNING,   # Yellow
	ERROR,     # Red
	ACHIEVEMENT # Gold
}

var notification_queue: Array = []
var active_notifications: Array = []
var max_visible_notifications: int = 5
var notification_container: VBoxContainer = null

func _ready():
	Log.log_info("NotificationManager: Initialized")

func setup_ui(parent: Control):
	"""Setup the notification UI container."""
	notification_container = VBoxContainer.new()
	notification_container.name = "NotificationContainer"
	parent.add_child(notification_container)

	# Position at top-right, below hover panel
	notification_container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	notification_container.offset_right = -10
	notification_container.offset_top = 200  # Below hover panel
	notification_container.offset_left = notification_container.offset_right - 300
	notification_container.custom_minimum_size = Vector2(300, 0)
	notification_container.add_theme_constant_override("separation", 5)

	Log.log_info("NotificationManager: UI setup complete")

func notify(message: String, type: NotificationType = NotificationType.INFO, duration: float = 3.0):
	"""Show a notification to the player."""
	if not notification_container:
		Log.log_warning("NotificationManager: UI not setup, cannot show notification")
		return

	# Create notification panel
	var notification = _create_notification_panel(message, type, duration)
	notification_container.add_child(notification)
	active_notifications.append(notification)

	# Remove old notifications if too many
	while active_notifications.size() > max_visible_notifications:
		var oldest = active_notifications.pop_front()
		if oldest and is_instance_valid(oldest):
			oldest.queue_free()

	Log.log_info("Notification: [%s] %s" % [NotificationType.keys()[type], message])
	notification_added.emit(message, NotificationType.keys()[type])

func _create_notification_panel(message: String, type: NotificationType, duration: float) -> PanelContainer:
	"""Create a notification panel with styling."""
	var panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Style based on type
	var style_box = StyleBoxFlat.new()
	style_box.set_corner_radius_all(6)
	style_box.border_width_left = 3
	style_box.border_width_top = 3
	style_box.border_width_right = 3
	style_box.border_width_bottom = 3

	match type:
		NotificationType.INFO:
			style_box.bg_color = Color(0.1, 0.2, 0.4, 0.95)
			style_box.border_color = Color(0.3, 0.5, 0.9, 1.0)
		NotificationType.SUCCESS:
			style_box.bg_color = Color(0.1, 0.3, 0.1, 0.95)
			style_box.border_color = Color(0.3, 0.9, 0.3, 1.0)
		NotificationType.WARNING:
			style_box.bg_color = Color(0.4, 0.3, 0.1, 0.95)
			style_box.border_color = Color(0.9, 0.7, 0.3, 1.0)
		NotificationType.ERROR:
			style_box.bg_color = Color(0.4, 0.1, 0.1, 0.95)
			style_box.border_color = Color(0.9, 0.3, 0.3, 1.0)
		NotificationType.ACHIEVEMENT:
			style_box.bg_color = Color(0.3, 0.2, 0.1, 0.95)
			style_box.border_color = Color(1.0, 0.8, 0.2, 1.0)

	panel.add_theme_stylebox_override("panel", style_box)

	# Add content
	var hbox = HBoxContainer.new()
	panel.add_child(hbox)

	# Icon
	var icon_label = Label.new()
	match type:
		NotificationType.INFO:
			icon_label.text = "ℹ"
		NotificationType.SUCCESS:
			icon_label.text = "✓"
		NotificationType.WARNING:
			icon_label.text = "⚠"
		NotificationType.ERROR:
			icon_label.text = "✖"
		NotificationType.ACHIEVEMENT:
			icon_label.text = "★"

	icon_label.add_theme_font_size_override("font_size", 20)
	hbox.add_child(icon_label)

	# Message
	var message_label = Label.new()
	message_label.text = message
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	message_label.custom_minimum_size = Vector2(250, 0)
	message_label.add_theme_font_size_override("font_size", 14)
	hbox.add_child(message_label)

	# Animate in
	panel.modulate.a = 0.0
	var tween = panel.create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.3)

	# Auto-dismiss after duration
	if duration > 0:
		var notification_ref = weakref(panel)
		get_tree().create_timer(duration).timeout.connect(func():
			var notif = notification_ref.get_ref()
			if notif:
				_dismiss_notification(notif)
		)

	return panel

func _dismiss_notification(notification: PanelContainer):
	"""Dismiss a notification with fade out animation."""
	if not is_instance_valid(notification):
		return

	# Fade out
	var tween = notification.create_tween()
	tween.tween_property(notification, "modulate:a", 0.0, 0.3)
	tween.finished.connect(func():
		if is_instance_valid(notification):
			# Remove from active list
			active_notifications.erase(notification)
			# Delete
			notification.queue_free()
	)

# Convenience methods
func notify_info(message: String):
	notify(message, NotificationType.INFO)

func notify_success(message: String):
	notify(message, NotificationType.SUCCESS)

func notify_warning(message: String):
	notify(message, NotificationType.WARNING)

func notify_error(message: String):
	notify(message, NotificationType.ERROR)

func notify_achievement(message: String):
	notify(message, NotificationType.ACHIEVEMENT, 5.0)  # Longer duration

# Game-specific notifications
func notify_citizen_died(citizen_name: String):
	notify_error("Citizen died from starvation!")

func notify_low_resources(resource_type: String):
	notify_warning("Low %s! Citizens may starve!" % resource_type)

func notify_ai_played_card(civ_id: int, card_name: String):
	notify_info("Civ %d played: %s" % [civ_id, card_name])

func notify_card_played(card_name: String):
	notify_success("Played: %s" % card_name)

func notify_turn_started(turn_number: int):
	notify_info("Turn %d" % turn_number)

func notify_resource_milestone(resource_type: String, amount: int):
	notify_achievement("%s reached %d!" % [resource_type.capitalize(), amount])

func notify_civilization_destroyed(civ_id: int):
	notify_error("Civilization %d destroyed!" % civ_id)
