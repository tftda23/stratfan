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
		2,  # grass terrain_id
		{},
		Card.Rarity.COMMON
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
		3,  # forest terrain_id
		{},
		Card.Rarity.UNCOMMON
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
		0,  # water terrain_id
		{},
		Card.Rarity.COMMON
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
		Color(0.9, 0.8, 0.3),
		-1,
		{},
		Card.Rarity.RARE
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

	# New cards (10 more)
	deck.append(_create_card(
		"Volcanic Fury",
		"Transform target area into molten lava",
		5,
		"terrain",
		"terrain_change",
		1,
		"area_3",
		Color(0.9, 0.3, 0.1),
		9  # lava terrain_id
	))

	deck.append(_create_card(
		"Desert Winds",
		"Turn water into sand, creating new land",
		3,
		"terrain",
		"terrain_change",
		1,
		"area_5",
		Color(0.8, 0.7, 0.4),
		1  # sand terrain_id
	))

	deck.append(_create_card(
		"Verdant Growth",
		"Transform barren land into jungle",
		4,
		"terrain",
		"terrain_change",
		1,
		"area_3",
		Color(0.2, 0.6, 0.2),
		13  # jungle terrain_id
	))

	deck.append(_create_card(
		"Mountain's Rise",
		"Raise mountains from the earth",
		4,
		"terrain",
		"terrain_change",
		1,
		"single",
		Color(0.5, 0.5, 0.5),
		6  # mountains terrain_id
	))

	deck.append(_create_card(
		"Blessed Ore",
		"Add 150 metal ore to target hex",
		3,
		"boon",
		"resource_add",
		3,
		"single",
		Color(0.6, 0.6, 0.7),
		-1,
		{"resource_type": "metal_ore"}
	))

	deck.append(_create_card(
		"Spring's Gift",
		"Add 120 water to an area",
		2,
		"boon",
		"resource_add",
		2,
		"area_3",
		Color(0.3, 0.6, 0.9),
		-1,
		{"resource_type": "water"}
	))

	deck.append(_create_card(
		"Timber Blessing",
		"Add 100 wood to target area",
		2,
		"boon",
		"resource_add",
		2,
		"area_3",
		Color(0.4, 0.3, 0.1),
		-1,
		{"resource_type": "wood"}
	))

	deck.append(_create_card(
		"Cataclysm",
		"Create a massive chasm, destroying everything",
		6,
		"bane",
		"terrain_change",
		1,
		"area_5",
		Color(0.2, 0.1, 0.2),
		8  # chasm terrain_id
	))

	deck.append(_create_card(
		"Divine Prosperity",
		"Triple resources in player territory",
		6,
		"boon",
		"resource_boost",
		3,
		"area_7",
		Color(1.0, 0.9, 0.4)
	))

	deck.append(_create_card(
		"Plague",
		"Destroy all resources in large enemy area",
		5,
		"bane",
		"destroy",
		4,
		"area_7",
		Color(0.5, 0.2, 0.5)
	))

	# UNIT SUMMON CARDS
	deck.append(_create_card(
		"Summon Villagers",
		"Summon 3 worker citizens at target hex",
		3,
		"summon",
		"summon_citizens",
		3,
		"single",
		Color(0.4, 0.7, 0.4),
		-1,
		{},
		Card.Rarity.COMMON
	))

	deck.append(_create_card(
		"Raise Army",
		"Summon 5 warrior units in target area",
		5,
		"summon",
		"summon_warriors",
		5,
		"area_3",
		Color(0.8, 0.2, 0.2),
		-1,
		{},
		Card.Rarity.RARE
	))

	deck.append(_create_card(
		"Divine Birth",
		"Summon 1 worker at your capital",
		2,
		"summon",
		"summon_citizens",
		1,
		"single",
		Color(0.5, 0.8, 0.5),
		-1,
		{},
		Card.Rarity.COMMON
	))

	# DIRECT RESOURCE CARDS
	deck.append(_create_card(
		"Manna from Heaven",
		"Add 200 food directly to your stockpile",
		2,
		"boon",
		"add_stockpile",
		200,
		"global",
		Color(0.9, 0.8, 0.4),
		-1,
		{"resource_type": "food"},
		Card.Rarity.COMMON
	))

	deck.append(_create_card(
		"Iron Blessing",
		"Add 150 metal ore to stockpile",
		3,
		"boon",
		"add_stockpile",
		150,
		"global",
		Color(0.6, 0.6, 0.7),
		-1,
		{"resource_type": "metal_ore"},
		Card.Rarity.UNCOMMON
	))

	deck.append(_create_card(
		"Timber Bounty",
		"Add 180 wood to stockpile",
		2,
		"boon",
		"add_stockpile",
		180,
		"global",
		Color(0.5, 0.3, 0.2),
		-1,
		{"resource_type": "wood"},
		Card.Rarity.COMMON
	))

	deck.append(_create_card(
		"Spring of Life",
		"Add 150 water to stockpile",
		2,
		"boon",
		"add_stockpile",
		150,
		"global",
		Color(0.4, 0.7, 0.9),
		-1,
		{"resource_type": "water"},
		Card.Rarity.COMMON
	))

	deck.append(_create_card(
		"Stone Gifts",
		"Add 200 stone to stockpile",
		2,
		"boon",
		"add_stockpile",
		200,
		"global",
		Color(0.6, 0.6, 0.6),
		-1,
		{"resource_type": "stone"},
		Card.Rarity.COMMON
	))

	# DAMAGE CARDS
	deck.append(_create_card(
		"Lightning Strike",
		"Deal 30 damage to units in target area",
		4,
		"bane",
		"damage_units",
		30,
		"area_3",
		Color(0.9, 0.9, 0.3),
		-1,
		{},
		Card.Rarity.UNCOMMON
	))

	deck.append(_create_card(
		"Meteor Shower",
		"Deal 50 damage to units and buildings in large area",
		6,
		"bane",
		"damage_all",
		50,
		"area_5",
		Color(0.9, 0.3, 0.1),
		-1,
		{},
		Card.Rarity.RARE
	))

	deck.append(_create_card(
		"Earthquake",
		"Deal 40 damage to buildings in target area",
		5,
		"bane",
		"damage_buildings",
		40,
		"area_5",
		Color(0.5, 0.3, 0.2),
		-1,
		{},
		Card.Rarity.RARE
	))

	deck.append(_create_card(
		"Smite",
		"Deal 50 damage to single target (unit or building)",
		3,
		"bane",
		"damage_single",
		50,
		"single",
		Color(1.0, 0.9, 0.2),
		-1,
		{},
		Card.Rarity.UNCOMMON
	))

	# HEALING/SUPPORT CARDS
	deck.append(_create_card(
		"Divine Healing",
		"Restore 40 HP to all your units",
		4,
		"boon",
		"heal_units",
		40,
		"global",
		Color(0.3, 0.9, 0.6),
		-1,
		{},
		Card.Rarity.UNCOMMON
	))

	deck.append(_create_card(
		"Fortify",
		"Restore 50 HP to buildings in area",
		4,
		"boon",
		"heal_buildings",
		50,
		"area_5",
		Color(0.6, 0.6, 0.8),
		-1,
		{},
		Card.Rarity.UNCOMMON
	))

	# SPECIAL EFFECT CARDS
	deck.append(_create_card(
		"Time Stop",
		"Freeze all enemy units for 2 turns",
		7,
		"bane",
		"freeze_units",
		2,
		"global",
		Color(0.6, 0.8, 1.0),
		-1,
		{},
		Card.Rarity.EPIC
	))

	deck.append(_create_card(
		"Mass Teleport",
		"Move all your units to target location",
		5,
		"boon",
		"teleport_units",
		1,
		"area_7",
		Color(0.7, 0.4, 0.9),
		-1,
		{},
		Card.Rarity.RARE
	))

	deck.append(_create_card(
		"Divine Shield",
		"Grant invulnerability to your units for 1 turn",
		6,
		"boon",
		"shield_units",
		1,
		"global",
		Color(0.9, 0.9, 1.0),
		-1,
		{},
		Card.Rarity.EPIC
	))

	deck.append(_create_card(
		"Famine",
		"Destroy all food in target area",
		3,
		"bane",
		"destroy_resource",
		1,
		"area_5",
		Color(0.4, 0.3, 0.2),
		-1,
		{"resource_type": "food"},
		Card.Rarity.UNCOMMON
	))

	deck.append(_create_card(
		"Drought",
		"Destroy all water in target area",
		3,
		"bane",
		"destroy_resource",
		1,
		"area_5",
		Color(0.7, 0.6, 0.4),
		-1,
		{"resource_type": "water"},
		Card.Rarity.UNCOMMON
	))

	# Add duplicates for larger deck
	var deck_copy = deck.duplicate()
	deck.append_array(deck_copy)

	Log.log_info("CardManager: Created deck with %d cards (%d unique)" % [deck.size(), deck.size() / 2])

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
	extra_data: Dictionary = {},
	card_rarity: int = Card.Rarity.COMMON
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
	card.rarity = card_rarity
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
	"""Queue a card to be played (executes at end of turn)."""
	if not hand.has(card):
		Log.log_warning("CardManager: Card not in hand")
		return false

	if card.mana_cost > current_mana:
		Log.log_warning("CardManager: Not enough mana")
		return false

	# Queue the action for end of turn
	ActionQueue.add_action(card, target_coords)

	# Remove from hand
	hand.erase(card)
	discard_pile.append(card)

	# Spend mana
	current_mana -= card.mana_cost
	mana_changed.emit(current_mana)

	card_played.emit(card)
	hand_changed.emit()
	NotificationManager.notify_card_played(card.card_name)
	Log.log_info("CardManager: Queued card '%s' at %s (executes at turn end)" % [card.card_name, target_coords])

	return true

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

	# Advance turn in VictoryManager
	VictoryManager.advance_turn()

	# Notify turn start
	NotificationManager.notify_turn_started(VictoryManager.get_current_turn())

	Log.log_info("CardManager: New turn started. Mana: %d" % current_mana)

	# Trigger AI turns
	AIManager.take_ai_turns()

func get_hand() -> Array[Card]:
	"""Get current hand."""
	return hand

func get_hand_size() -> int:
	"""Get size of hand."""
	return hand.size()

func get_deck_size() -> int:
	"""Get size of deck."""
	return deck.size()
