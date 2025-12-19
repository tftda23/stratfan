extends Node

# Singleton for managing AI opponents

var ai_deities: Array[AIDeity] = []
var ai_turn_active: bool = false

func _ready():
	Log.log_info("AIManager: Initialized")

func create_ai_opponents(civ_territories: Dictionary, player_civ_id: int):
	"""Create AI opponents for non-player civilizations."""
	ai_deities.clear()

	var AIDeityScript = preload("res://scripts/ai_deity.gd")

	for civ_id in civ_territories.keys():
		if civ_id == player_civ_id:
			continue  # Skip player civ

		# Assign personality based on civ ID
		var personality = civ_id % 4  # Cycles through personalities
		var ai = AIDeityScript.new(civ_id, personality)
		ai.difficulty = 2  # Medium difficulty
		ai_deities.append(ai)

		Log.log_info("AIManager: Created AI for civ %d with personality %s" % [civ_id, ai.Personality.keys()[personality]])

	Log.log_info("AIManager: Created %d AI opponents" % ai_deities.size())

func take_ai_turns():
	"""Have all AI opponents take their turns."""
	if ai_turn_active:
		Log.log_warning("AIManager: AI turn already in progress")
		return

	if ai_deities.is_empty():
		Log.log_info("AIManager: No AI opponents to take turns")
		return

	ai_turn_active = true
	Log.log_info("AIManager: Starting AI turns...")

	# Take turns sequentially with delays for visual feedback
	_process_next_ai_turn(0)

func _process_next_ai_turn(index: int):
	"""Process the next AI turn with a delay."""
	if index >= ai_deities.size():
		# All AI turns complete
		ai_turn_active = false
		Log.log_info("AIManager: All AI turns complete")
		_on_all_ai_turns_complete()
		return

	var ai = ai_deities[index]
	Log.log_info("AIManager: AI Civ %d taking turn..." % ai.civ_id)

	# Take turn
	if WorldManager.world_map_node:
		ai.take_turn(WorldManager.world_map_node)

	# Wait before next AI turn (for visual feedback)
	await get_tree().create_timer(1.0).timeout

	# Process next AI
	_process_next_ai_turn(index + 1)

func _on_all_ai_turns_complete():
	"""Called when all AI turns are complete."""
	# Refresh minimap if it exists
	if WorldManager.world_map_node and WorldManager.world_map_node.world_gen_ui:
		var ui = WorldManager.world_map_node.world_gen_ui
		if ui.has_method("initialize_minimap"):
			ui.call_deferred("initialize_minimap")

	Log.log_info("AIManager: AI turns complete, player can continue")

func get_ai_count() -> int:
	"""Get the number of AI opponents."""
	return ai_deities.size()

func get_ai_for_civ(civ_id: int) -> AIDeity:
	"""Get the AI controller for a specific civilization."""
	for ai in ai_deities:
		if ai.civ_id == civ_id:
			return ai
	return null
