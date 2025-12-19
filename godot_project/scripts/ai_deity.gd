extends Node
class_name AIDeity

# AI personality
enum Personality {
	AGGRESSIVE,  # Focuses on destructive cards against enemies
	DEFENSIVE,   # Protects own civilization
	ECONOMIC,    # Focuses on resource generation
	BALANCED     # Mix of all strategies
}

var civ_id: int = -1
var personality: Personality = Personality.BALANCED
var difficulty: int = 1  # 1 = Easy, 2 = Medium, 3 = Hard

# Card management
var deck: Array[Card] = []
var hand: Array[Card] = []
var discard_pile: Array[Card] = []
var current_mana: int = 10
var max_mana: int = 10
var max_hand_size: int = 7

# AI state
var last_action_turn: int = -1
var aggression_level: float = 0.5  # 0 = passive, 1 = very aggressive

func _init(civilization_id: int, ai_personality: Personality = Personality.BALANCED):
	civ_id = civilization_id
	personality = ai_personality
	_create_ai_deck()
	_shuffle_deck()
	# Draw starting hand
	for i in range(5):
		_draw_card()

func _create_ai_deck():
	"""Create a deck for the AI based on personality."""
	deck.clear()

	# Base cards that all AI get
	var base_cards = [
		_create_basic_card("AI Terraforming", "terrain_change", 2, "single", 2),
		_create_basic_card("AI Abundance", "resource_boost", 4, "area_3", 2),
		_create_basic_card("AI Harvest", "resource_add", 2, "single", 2),
	]

	# Personality-specific cards
	match personality:
		Personality.AGGRESSIVE:
			deck.append(_create_basic_card("AI Wrath", "destroy", 3, "area_3", 3))
			deck.append(_create_basic_card("AI Freeze", "freeze", 4, "area_5", 1))
			deck.append(_create_basic_card("AI Bane", "bane", 4, "area_5", 1))
			deck.append(_create_basic_card("AI Plague", "destroy", 5, "area_7", 4))
			aggression_level = 0.8

		Personality.DEFENSIVE:
			deck.append(_create_basic_card("AI Blessing", "boon", 5, "area_7", 1))
			deck.append(_create_basic_card("AI Prosperity", "resource_boost", 6, "area_7", 3))
			deck.append(_create_basic_card("AI Growth", "summon_citizens", 3, "single", 2))
			aggression_level = 0.2

		Personality.ECONOMIC:
			deck.append(_create_basic_card("AI Mining", "resource_add", 3, "area_3", 3))
			deck.append(_create_basic_card("AI Farming", "resource_add", 2, "area_3", 2))
			deck.append(_create_basic_card("AI Multiply", "resource_boost", 4, "area_5", 2))
			aggression_level = 0.3

		Personality.BALANCED:
			deck.append(_create_basic_card("AI Wrath", "destroy", 3, "area_3", 3))
			deck.append(_create_basic_card("AI Blessing", "boon", 5, "area_7", 1))
			deck.append(_create_basic_card("AI Growth", "summon_citizens", 3, "single", 2))
			aggression_level = 0.5

	# Add base cards
	deck.append_array(base_cards)

	# Duplicate for larger deck
	var deck_copy = deck.duplicate()
	deck.append_array(deck_copy)

	Log.log_info("AI Deity %d: Created %s deck with %d cards" % [civ_id, Personality.keys()[personality], deck.size()])

func _create_basic_card(name: String, effect: String, cost: int, targeting: String, power: int) -> Card:
	"""Helper to create a basic AI card."""
	var card = Card.new()
	card.card_name = name
	card.card_description = "AI card: " + effect
	card.mana_cost = cost
	card.card_type = "action"
	card.effect_type = effect
	card.effect_power = power
	card.target_type = targeting
	card.card_color = Color(0.5, 0.5, 0.5)

	# Set terrain change if it's a terrain card
	if effect == "terrain_change":
		card.terrain_change_to = [2, 3, 0].pick_random()  # grass, forest, or water

	return card

func _shuffle_deck():
	"""Shuffle the deck."""
	deck.shuffle()

func _draw_card() -> Card:
	"""Draw a card from the deck."""
	if hand.size() >= max_hand_size:
		return null

	if deck.is_empty():
		if discard_pile.is_empty():
			return null
		deck = discard_pile.duplicate()
		discard_pile.clear()
		_shuffle_deck()

	var card = deck.pop_front()
	hand.append(card)
	return card

func take_turn(world_map):
	"""AI takes its turn - plays cards strategically."""
	if not world_map:
		return

	last_action_turn = VictoryManager.get_current_turn()

	# Restore mana
	current_mana = max_mana

	# Draw a card
	_draw_card()

	Log.log_info("AI Deity %d: Taking turn (Mana: %d, Hand: %d cards)" % [civ_id, current_mana, hand.size()])

	# Play cards until out of mana or can't find good targets
	var cards_played = 0
	var max_cards_per_turn = 3  # Limit to prevent AI from playing entire hand

	while current_mana > 0 and cards_played < max_cards_per_turn:
		var card_to_play = _choose_card_to_play()
		if not card_to_play:
			break

		var target = _choose_target(card_to_play, world_map)
		if not target:
			# Remove card from consideration if we can't find a target
			hand.erase(card_to_play)
			discard_pile.append(card_to_play)
			continue

		# Play the card
		if _play_card(card_to_play, target, world_map):
			cards_played += 1
			NotificationManager.notify_ai_played_card(civ_id, card_to_play.card_name)
			Log.log_info("AI Deity %d: Played '%s' at %s" % [civ_id, card_to_play.card_name, target])
		else:
			break

	Log.log_info("AI Deity %d: Turn ended (Played %d cards, Mana left: %d)" % [civ_id, cards_played, current_mana])

func _choose_card_to_play() -> Card:
	"""Choose which card to play from hand."""
	# Filter affordable cards
	var affordable = hand.filter(func(c): return c.mana_cost <= current_mana)
	if affordable.is_empty():
		return null

	# Sort by priority based on personality and difficulty
	affordable.sort_custom(func(a, b): return _get_card_priority(a) > _get_card_priority(b))

	return affordable[0]

func _get_card_priority(card: Card) -> float:
	"""Calculate priority score for a card based on personality."""
	var priority = 0.0

	match personality:
		Personality.AGGRESSIVE:
			if card.effect_type in ["destroy", "bane", "freeze"]:
				priority += 10.0
			if card.effect_type in ["boon", "resource_boost"]:
				priority += 2.0

		Personality.DEFENSIVE:
			if card.effect_type in ["boon", "resource_boost", "summon_citizens"]:
				priority += 10.0
			if card.effect_type in ["destroy", "bane"]:
				priority += 3.0

		Personality.ECONOMIC:
			if card.effect_type in ["resource_add", "resource_boost"]:
				priority += 10.0
			if card.effect_type in ["terrain_change"]:
				priority += 5.0

		Personality.BALANCED:
			priority += 5.0

	# Higher difficulty = better card selection
	priority += difficulty * 2.0

	# Prefer cards that cost more mana (more powerful)
	priority += card.effect_power * 0.5

	return priority

func _choose_target(card: Card, world_map) -> Vector2i:
	"""Choose a target location for the card."""
	var tile_data = world_map._tile_data
	var civ_territories = world_map._civ_territories

	# Get player civ id
	var player_civ_id = GameManager.player_civ_id
	var ai_territory = civ_territories.get(civ_id, [])
	var player_territory = civ_territories.get(player_civ_id, [])

	if ai_territory.is_empty():
		# AI civ doesn't exist, pick random tile
		var all_tiles = tile_data.keys()
		if all_tiles.is_empty():
			return Vector2i(-1, -1)
		return all_tiles.pick_random()

	var target = Vector2i(-1, -1)

	# Choose target based on card type and personality
	match card.effect_type:
		"destroy", "bane", "freeze":
			# Offensive cards - target player territory
			if not player_territory.is_empty() and randf() < aggression_level:
				target = player_territory.pick_random()
			else:
				# Target another random civ
				target = _get_random_enemy_territory(world_map)

		"boon", "resource_boost", "resource_add", "summon_citizens":
			# Beneficial cards - target own territory
			target = ai_territory.pick_random()

		"terrain_change":
			# Terraform - depends on personality
			if randf() < 0.5:
				target = ai_territory.pick_random()
			else:
				target = player_territory.pick_random()

		_:
			# Default to own territory
			target = ai_territory.pick_random()

	return target

func _get_random_enemy_territory(world_map) -> Vector2i:
	"""Get a random tile from an enemy civilization."""
	var civ_territories = world_map._civ_territories
	var enemy_civs = civ_territories.keys().filter(func(id): return id != civ_id)

	if enemy_civs.is_empty():
		# No enemies, return random tile
		var all_tiles = world_map._tile_data.keys()
		if all_tiles.is_empty():
			return Vector2i(-1, -1)
		return all_tiles.pick_random()

	var enemy_civ = enemy_civs.pick_random()
	var enemy_territory = civ_territories[enemy_civ]

	if enemy_territory.is_empty():
		return Vector2i(-1, -1)

	return enemy_territory.pick_random()

func _play_card(card: Card, target: Vector2i, world_map) -> bool:
	"""Play a card at the target location."""
	if not hand.has(card):
		return false

	if card.mana_cost > current_mana:
		return false

	if target == Vector2i(-1, -1):
		return false

	# Remove from hand
	hand.erase(card)
	discard_pile.append(card)

	# Spend mana
	current_mana -= card.mana_cost

	# Apply effect
	var success = card.apply_effect(world_map, target)

	return success
