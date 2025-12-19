extends Node

# Victory/Loss conditions manager
signal game_over(victory: bool, reason: String)

# Victory conditions
const VICTORY_POPULATION = 50
const VICTORY_RESOURCES_EACH = 5000
const VICTORY_TERRITORY_PERCENT = 40.0

# Turn tracking
var current_turn: int = 0
var max_turns: int = 200  # Game ends in draw after 200 turns

# Game state
var game_ended: bool = false
var victory_type: String = ""

func _ready():
	Log.log_info("VictoryManager: Initialized")

func start_game():
	"""Reset and start tracking victory conditions."""
	current_turn = 0
	game_ended = false
	victory_type = ""
	Log.log_info("VictoryManager: Game started")

func advance_turn():
	"""Increment turn counter and check victory conditions."""
	if game_ended:
		return

	current_turn += 1
	Log.log_info("VictoryManager: Turn %d started" % current_turn)

	# Check victory conditions at end of turn
	check_victory_conditions()

func check_victory_conditions():
	"""Check all victory and loss conditions."""
	if game_ended:
		return

	var player_civ_id = GameManager.player_civ_id

	# Check loss conditions first
	if _check_loss_conditions():
		return

	# Check victory conditions
	if _check_population_victory():
		_end_game(true, "Population Victory - Your civilization has grown to %d citizens!" % get_player_citizen_count())
	elif _check_resource_victory():
		_end_game(true, "Resource Victory - You have amassed vast wealth!")
	elif _check_territory_victory():
		_end_game(true, "Territorial Victory - You control %d%% of the world!" % get_player_territory_percent())
	elif current_turn >= max_turns:
		_check_score_victory()

func _check_loss_conditions() -> bool:
	"""Check if player has lost."""
	var player_civ_id = GameManager.player_civ_id

	# Loss: No citizens left
	var citizen_count = get_player_citizen_count()
	if citizen_count == 0:
		_end_game(false, "Defeat - Your civilization has fallen. No citizens remain.")
		return true

	# Loss: Deck and discard empty, can't draw
	if CardManager.deck.is_empty() and CardManager.discard_pile.is_empty() and CardManager.hand.is_empty():
		_end_game(false, "Defeat - No divine power remains. Your cards have run out.")
		return true

	# Loss: Territory completely lost
	var territory_count = get_player_territory_count()
	if territory_count == 0:
		_end_game(false, "Defeat - Your civilization's territory has been completely conquered.")
		return true

	return false

func _check_population_victory() -> bool:
	"""Check population victory condition."""
	return get_player_citizen_count() >= VICTORY_POPULATION

func _check_resource_victory() -> bool:
	"""Check resource stockpile victory condition."""
	var resources = GameManager.get_player_resources()

	# Must have at least VICTORY_RESOURCES_EACH of each resource type
	for resource_type in ["food", "wood", "water", "stone", "metal_ore"]:
		if resources.get(resource_type, 0) < VICTORY_RESOURCES_EACH:
			return false

	return true

func _check_territory_victory() -> bool:
	"""Check territorial control victory."""
	var percent = get_player_territory_percent()
	return percent >= VICTORY_TERRITORY_PERCENT

func _check_score_victory():
	"""Determine winner by score after max turns."""
	var player_score = calculate_player_score()
	var highest_ai_score = calculate_highest_ai_score()

	if player_score > highest_ai_score:
		_end_game(true, "Score Victory - You have the highest score after %d turns!" % max_turns)
	else:
		_end_game(false, "Defeat - Your rival deity achieved a higher score.")

func calculate_player_score() -> int:
	"""Calculate player's total score."""
	var score = 0

	# Citizens worth 50 points each
	score += get_player_citizen_count() * 50

	# Territory tiles worth 10 points each
	score += get_player_territory_count() * 10

	# Resources worth 1 point per unit
	var resources = GameManager.get_player_resources()
	for resource_type in resources.keys():
		score += resources[resource_type]

	return score

func calculate_highest_ai_score() -> int:
	"""Calculate highest AI score."""
	var highest = 0
	var world_map = WorldManager.world_map_node

	if not world_map:
		return 0

	# Check each AI civilization
	for civ_id in world_map._civ_territories.keys():
		if civ_id == GameManager.player_civ_id:
			continue

		var score = 0

		# Count citizens
		var citizens = get_tree().get_nodes_in_group("citizens")
		var civ_citizen_count = 0
		for citizen in citizens:
			if citizen.civ_id == civ_id:
				civ_citizen_count += 1
		score += civ_citizen_count * 50

		# Count territory
		var territory = world_map._civ_territories.get(civ_id, [])
		score += territory.size() * 10

		if score > highest:
			highest = score

	return highest

func get_player_citizen_count() -> int:
	"""Get count of player's citizens."""
	var count = 0
	var citizens = get_tree().get_nodes_in_group("citizens")
	for citizen in citizens:
		if citizen.civ_id == GameManager.player_civ_id:
			count += 1
	return count

func get_player_territory_count() -> int:
	"""Get count of player's territory tiles."""
	var world_map = WorldManager.world_map_node
	if not world_map:
		return 0

	var territory = world_map._civ_territories.get(GameManager.player_civ_id, [])
	return territory.size()

func get_player_territory_percent() -> float:
	"""Get percentage of world controlled by player."""
	var world_map = WorldManager.world_map_node
	if not world_map:
		return 0.0

	var total_tiles = world_map._tile_data.size()
	var player_tiles = get_player_territory_count()

	if total_tiles == 0:
		return 0.0

	return (float(player_tiles) / float(total_tiles)) * 100.0

func _end_game(victory: bool, reason: String):
	"""End the game with victory or defeat."""
	if game_ended:
		return

	game_ended = true
	victory_type = reason

	Log.log_info("VictoryManager: Game ended - %s" % reason)
	game_over.emit(victory, reason)

func get_current_turn() -> int:
	return current_turn

func is_game_over() -> bool:
	return game_ended
