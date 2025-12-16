extends Node

# Signals
signal card_drawn(card: Card)
signal card_played(card: Card)
signal hand_changed
signal mana_changed(new_mana: int)

# Deck management
var deck: Array[Card] = []
var hand: Array[Card] = []
var discard_pile: Array[Card] = []

# Game state
var current_mana: int = 3
var max_mana: int = 10
var max_hand_size: int = 7

func _ready():
	Log.log_info("CardManager: Initialized")
	_create_starter_deck()
	shuffle_deck()
	# Draw starting hand
	for i in range(5):
		draw_card()

func _create_starter_deck():
	"""Create the initial deck of deity cards."""
	deck.clear()

	# Terrain transformation cards
	deck.append(_create_card(
		"Divine Terraforming",
		"Transform target hex into fertile grassland",
		2,
		"terrain",
		"terrain_change",
		1,
		"single",
		Color(0.4, 0.8, 0.3),
		2  # grass terrain_id
	))

	deck.append(_create_card(
		"Sacred Grove",
		"Transform an area into a lush forest",
		3,
		"terrain",
		"terrain_change",
		1,
		"area_3",
		Color(0.2, 0.5, 0.2),
		3  # forest terrain_id
	))

	deck.append(_create_card(
		"Ocean's Blessing",
		"Create water on target hex",
		2,
		"terrain",
		"terrain_change",
		1,
		"single",
		Color(0.2, 0.5, 0.8),
		0  # water terrain_id
	))

	# Resource cards
	deck.append(_create_card(
		"Abundance",
		"Double all resources in target area",
		4,
		"boon",
		"resource_boost",
		2,
		"area_5",
		Color(0.9, 0.8, 0.3)
	))

	deck.append(_create_card(
		"Divine Harvest",
		"Add 100 food to target hex",
		2,
		"boon",
		"resource_add",
		2,
		"single",
		Color(0.8, 0.6, 0.2),
		-1,
		{"resource_type": "food"}
	))

	deck.append(_create_card(
		"Mineral Vein",
		"Add stone and metal ore to an area",
		3,
		"boon",
		"resource_add",
		3,
		"area_3",
		Color(0.6, 0.6, 0.7),
		-1,
		{"resource_type": "stone"}
	))

	# Destructive cards
	deck.append(_create_card(
		"Divine Wrath",
		"Destroy all resources in target area",
		3,
		"bane",
		"destroy",
		3,
		"area_3",
		Color(0.9, 0.2, 0.2)
	))

	deck.append(_create_card(
		"Eternal Winter",
		"Freeze target area into snow and ice",
		4,
		"bane",
		"freeze",
		1,
		"area_5",
		Color(0.7, 0.9, 1.0)
	))

	# Blessing/Curse cards
	deck.append(_create_card(
		"Deity's Favor",
		"Double resources in your civilization's territory",
		5,
		"boon",
		"boon",
		1,
		"area_7",
		Color(0.95, 0.85, 0.3)
	))

	deck.append(_create_card(
		"Divine Curse",
		"Halve enemy civilization resources",
		4,
		"bane",
		"bane",
		1,
		"area_5",
		Color(0.6, 0.2, 0.6)
	))

	# Summon cards
	deck.append(_create_card(
		"Call of the Faithful",
		"Summon 2 citizens at target location",
		3,
		"summon",
		"summon_citizens",
		2,
		"single",
		Color(0.3, 0.7, 0.9)
	))

	deck.append(_create_card(
		"Mass Migration",
		"Summon 3 citizens at target location",
		5,
		"summon",
		"summon_citizens",
		3,
		"single",
		Color(0.4, 0.6, 0.9)
	))

	# Add duplicates for larger deck
	var deck_copy = deck.duplicate()
	deck.append_array(deck_copy)

	Log.log_info("CardManager: Created deck with %d cards" % deck.size())

func _create_card(
	name: String,
	description: String,
	cost: int,
	type: String,
	effect: String,
	power: int,
	targeting: String,
	color: Color,
	terrain_change: int = -1,
	extra_data: Dictionary = {}
) -> Card:
	"""Helper to create a card."""
	var card = Card.new()
	card.card_name = name
	card.card_description = description
	card.mana_cost = cost
	card.card_type = type
	card.effect_type = effect
	card.effect_power = power
	card.target_type = targeting
	card.card_color = color
	card.terrain_change_to = terrain_change
	card.effect_data = extra_data
	return card

func shuffle_deck():
	"""Shuffle the deck."""
	deck.shuffle()
	Log.log_info("CardManager: Deck shuffled")

func draw_card() -> Card:
	"""Draw a card from the deck to the hand."""
	if hand.size() >= max_hand_size:
		Log.log_info("CardManager: Hand is full, cannot draw")
		return null

	if deck.is_empty():
		# Reshuffle discard into deck
		if discard_pile.is_empty():
			Log.log_info("CardManager: No cards left to draw")
			return null
		deck = discard_pile.duplicate()
		discard_pile.clear()
		shuffle_deck()

	var card = deck.pop_front()
	hand.append(card)
	card_drawn.emit(card)
	hand_changed.emit()
	Log.log_info("CardManager: Drew card '%s'" % card.card_name)
	return card

func play_card(card: Card, target_coords: Vector2i) -> bool:
	"""Play a card from hand."""
	if not hand.has(card):
		Log.log_warning("CardManager: Card not in hand")
		return false

	if card.mana_cost > current_mana:
		Log.log_warning("CardManager: Not enough mana")
		return false

	# Remove from hand
	hand.erase(card)
	discard_pile.append(card)

	# Spend mana
	current_mana -= card.mana_cost
	mana_changed.emit(current_mana)

	# Apply effect
	var world_map = WorldManager.world_map_node
	var success = card.apply_effect(world_map, target_coords)

	if success:
		card_played.emit(card)
		hand_changed.emit()
		Log.log_info("CardManager: Played card '%s' at %s" % [card.card_name, target_coords])

	return success

func gain_mana(amount: int):
	"""Add mana."""
	current_mana = min(current_mana + amount, max_mana)
	mana_changed.emit(current_mana)

func start_turn():
	"""Called at the start of each turn."""
	# Restore mana
	current_mana = max_mana
	mana_changed.emit(current_mana)

	# Draw a card
	draw_card()

	Log.log_info("CardManager: New turn started. Mana: %d" % current_mana)

func get_hand() -> Array[Card]:
	"""Get current hand."""
	return hand

func get_hand_size() -> int:
	"""Get size of hand."""
	return hand.size()

func get_deck_size() -> int:
	"""Get size of deck."""
	return deck.size()
