extends Node

# This script is intended to be an autoloaded singleton.
# It will manage the overall game state.

var player_civ_id: int = -1
var player_resources: Dictionary = {}
var citizens_by_civ: Dictionary = {} # New: Tracks citizen count per civ

# Turn-based system
enum TurnPhase {
	PLAYER_TURN,      # Player selects and plays cards (units paused)
	PROCESSING,       # Card actions execute (units paused, brief phase)
	SIMULATION        # Units move and act (brief phase before next turn)
}
var current_phase: TurnPhase = TurnPhase.PLAYER_TURN
var simulation_timer: float = 0.0
var simulation_duration: float = 5.0  # Units act for 5 seconds (increased for more movement)

signal player_resources_updated(resources_dict)
signal num_citizens_updated(civ_id, new_count) # New signal
signal phase_changed(new_phase: TurnPhase)

func _ready():
	# Initialize citizens_by_civ for all civs that might exist, or as they are encountered
	# For now, we'll assume it's populated as civs are created or citizens added.
	print("GameManager is ready.")

func set_player_civ(civ_id: int):
	player_civ_id = civ_id

func get_player_civ() -> int:
	return player_civ_id

func set_player_resources(resources: Dictionary):
	player_resources = resources
	player_resources_updated.emit(player_resources)

func add_player_resources(resource_type: String, amount: int):
	player_resources[resource_type] = player_resources.get(resource_type, 0) + amount
	player_resources_updated.emit(player_resources)

func get_player_resources() -> Dictionary:
	return player_resources

func add_citizen_to_civ(civ_id: int):
	citizens_by_civ[civ_id] = citizens_by_civ.get(civ_id, 0) + 1
	num_citizens_updated.emit(civ_id, citizens_by_civ[civ_id])

func remove_citizen_from_civ(civ_id: int):
	if citizens_by_civ.has(civ_id):
		citizens_by_civ[civ_id] -= 1
		if citizens_by_civ[civ_id] < 0:
			citizens_by_civ[civ_id] = 0 # Prevent negative counts
		num_citizens_updated.emit(civ_id, citizens_by_civ[civ_id])

func is_units_active() -> bool:
	"""Returns true if units should be moving/acting."""
	return current_phase == TurnPhase.SIMULATION

func set_phase(new_phase: TurnPhase):
	"""Change the current turn phase."""
	current_phase = new_phase
	simulation_timer = 0.0
	phase_changed.emit(new_phase)
	Log.log_info("GameManager: Phase changed to %s" % TurnPhase.keys()[new_phase])

func _process(delta):
	"""Handle automatic phase transitions."""
	if current_phase == TurnPhase.SIMULATION:
		simulation_timer += delta
		if simulation_timer >= simulation_duration:
			# Simulation phase complete, start new player turn
			set_phase(TurnPhase.PLAYER_TURN)
			CardManager.start_turn()  # Draw card, restore mana
