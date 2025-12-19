extends Node

# Singleton for queueing and processing game actions
# This allows for a "commit phase" at the end of a turn,
# where all player actions are resolved at once.

var action_queue: Array = []

# Action structure:
# {
#   "card": Card,
#   "target_coords": Vector2i
# }

func _ready():
	Log.log_info("ActionQueue: Initialized")

func add_action(card: Card, target_coords: Vector2i):
	"""Add a new action to the queue."""
	var action = {
		"card": card,
		"target_coords": target_coords
	}
	action_queue.append(action)
	Log.log_info("ActionQueue: Added action for card '%s' at %s" % [card.card_name, target_coords])

func process_actions() -> bool:
	"""
	Process all actions in the queue.
	Returns true if any actions were processed.
	"""
	if action_queue.is_empty():
		return false

	Log.log_info("ActionQueue: Processing %d actions..." % action_queue.size())

	for action in action_queue:
		var card: Card = action.card
		var target_coords: Vector2i = action.target_coords

		if not is_instance_valid(card):
			Log.log_warning("ActionQueue: Skipping action with invalid card.")
			continue

		# Apply the card's effect on the world map
		if WorldManager.world_map_node:
			card.apply_effect(WorldManager.world_map_node, target_coords)
			Log.log_info("ActionQueue: Applied effect for card '%s' at %s" % [card.card_name, target_coords])
		else:
			Log.log_error("ActionQueue: WorldMap node not found, cannot apply card effect.")

	# Clear the queue after processing
	clear_queue()
	Log.log_info("ActionQueue: All actions processed.")
	return true

func clear_queue():
	"""Clear all actions from the queue."""
	action_queue.clear()
	Log.log_info("ActionQueue: Queue cleared.")

func get_queued_actions() -> Array:
	"""Return a copy of the current action queue."""
	return action_queue.duplicate()
