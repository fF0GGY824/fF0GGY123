extends SceneTree

var failures: int = 0

func verify(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		push_error("FAIL: " + description)
		failures += 1

func normal_card(rank: int, suit: String) -> Dictionary:
	return {
		"rank": rank,
		"suit": suit,
		"special": "",
		"joker_color": "",
		"copy_rank": -1,
		"copy_suit": ""
	}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: PackedScene = load("res://control.tscn")
	if scene == null:
		push_error("Main game scene missing")
		quit(1)
		return
	var game: Variant = scene.instantiate()
	root.add_child(game)
	verify(game.menu_screen != null and game.game_screen != null, "Original menu and game screen initialize")
	verify(game.rules_dialog != null and game.joker_dialog != null, "Rules and joker selection dialogs initialize")
	# Readable, phone-friendly help: BBCode headings and own scroll view.
	var rules_content: RichTextLabel = game.rules_dialog.find_child("RulesContent", true, false) as RichTextLabel
	verify(rules_content != null, "Rules window has a rich-text reading panel")
	if rules_content != null:
		verify(rules_content.bbcode_enabled and rules_content.scroll_active, "Formatted rules support scrolling in portrait mode")
		verify(rules_content.text.contains("ПОДКИДЫВАНИЕ") and rules_content.text.contains("ДЖОКЕР"), "Rules have short highlighted sections")
		verify(rules_content.text.contains("ещё 2") and rules_content.text.contains("пока тебя атакуют"), "Rules explain six-card throw cap and final Joker defense")

	# The user supplied only ranks 1–10 and two Joker drawings.
	# Verify exact sheet coordinates and avoid blank image regions for J/Q/K/A.
	var atlas_image: Image = Image.create(
		14 * game.CARD_ATLAS_W, 5 * game.CARD_ATLAS_H,
		false, Image.FORMAT_RGBA8
	)
	game.card_atlas = ImageTexture.create_from_image(atlas_image)
	var two_hearts: AtlasTexture = game.card_face_texture(
		normal_card(2, "♥")
	) as AtlasTexture
	verify(two_hearts != null, "Original hearts rank 2 uses user artwork")
	if two_hearts != null:
		verify(
			two_hearts.region.position == Vector2(128, 0),
			"Hearts rank 2 reads second face in original hearts row"
		)
	var ten_spades: AtlasTexture = game.card_face_texture(
		normal_card(10, "♠")
	) as AtlasTexture
	verify(
		ten_spades != null and ten_spades.region.position == Vector2(1152, 588),
		"Original magenta spade 10 reads correct artwork"
	)
	verify(
		game.card_face_texture(normal_card(11, "♥")) == null
		and game.card_face_texture(normal_card(14, "♠")) == null,
		"Unprovided J/Q/K/A have original fallback instead of blank cards"
	)
	var art_mark: Dictionary = {
		"special": "mark", "rank": 22, "suit": "",
		"joker_color": "", "copy_rank": -1, "copy_suit": ""
	}
	var art_joker: Dictionary = {
		"special": "joker", "rank": 20, "suit": "",
		"joker_color": "red", "copy_rank": -1, "copy_suit": ""
	}
	verify(
		game.card_face_texture(art_mark) == null,
		"Mark not supplied in original images uses vector fallback"
	)
	var red_joker_art: AtlasTexture = game.card_face_texture(
		art_joker
	) as AtlasTexture
	verify(
		red_joker_art != null and red_joker_art.region.position == Vector2(0, 784),
		"Original red Joker illustration is selected in sprite sheet"
	)
	game.card_atlas = null

	game.start_game()
	verify(game.game_screen.visible and not game.menu_screen.visible, "Start button shows the game")
	# Regression: the player nickname used to wrap into a thin vertical strip,
	# enlarging the avatar row and pushing cards and buttons offscreen.
	var game_scroll: ScrollContainer = game.game_screen.get_node("GameScroll")
	var info_row: HBoxContainer = game.game_screen.find_child("PlayerInfoRow", true, false)
	var avatar_box: PanelContainer = game.game_screen.find_child("PlayerAvatar", true, false)
	var nickname: Label = game.game_screen.find_child("PlayerNickname", true, false)
	var hand_scroll: ScrollContainer = game.game_screen.find_child("HandScroll", true, false)
	var action_buttons: GridContainer = game.game_screen.find_child("ActionButtons", true, false)
	verify(game_scroll != null and hand_scroll != null and action_buttons != null, "Main game has a scrollable screen with hand and action buttons")
	verify(nickname != null and nickname.autowrap_mode == TextServer.AUTOWRAP_OFF, "Player nickname never wraps vertically")
	if game_scroll != null and nickname != null and avatar_box != null and info_row != null:
		for width in [1152, 360]:
			get_root().size = Vector2i(width, 648)
			await process_frame
			await process_frame
			game.adapt_layout()
			await process_frame
			print("UI_LAYOUT width=", width, " viewport=", game_scroll.size, " row=", info_row.size, " avatar=", avatar_box.size, " nickname=", nickname.size, " hand=", hand_scroll.size, " actions=", action_buttons.size)
			verify(info_row.size.y <= 64.0 and avatar_box.size.y <= 60.0, "Player info stays compact at width " + str(width))
			verify(nickname.size.x >= 150.0, "Nickname remains readable at width " + str(width))
			verify(hand_scroll.size.y >= 120.0 and action_buttons.size.y >= 90.0, "Hand and action buttons have usable space at width " + str(width))
	get_root().size = Vector2i(720, 1280)
	await process_frame
	game.adapt_layout()
	# Responsive battle layout: ten slots in two rows of five, both orientations.
	var battle_layout: GridContainer = game.game_screen.find_child("BattleLayout", true, false)
	var hand_actions_layout: GridContainer = game.game_screen.find_child("HandActionsLayout", true, false)
	var table_grid: GridContainer = game.game_screen.find_child("TableSlots", true, false)
	var battle_scroll: ScrollContainer = game.game_screen.find_child("TableScroll", true, false)
	var deck_info: HBoxContainer = game.game_screen.find_child("DeckInfo", true, false)
	verify(battle_layout != null and table_grid != null and deck_info != null, "Responsive field, deck and slot grid exist")
	if battle_layout != null and table_grid != null and battle_scroll != null:
		for test_size in [Vector2i(1152, 648), Vector2i(360, 648), Vector2i(720, 1280)]:
			get_root().size = test_size
			await process_frame
			game.adapt_layout()
			await process_frame
			verify(table_grid.columns == 5 and table_grid.get_child_count() == 10, "Five columns with ten places at " + str(test_size))
			var expected_columns: int = 1 if test_size.y >= test_size.x else 2
			verify(battle_layout.columns == expected_columns, "Portrait/landscape deck reflow at " + str(test_size))
			verify(hand_actions_layout != null and hand_actions_layout.columns == expected_columns, "Hand and buttons reflow with orientation at " + str(test_size))
			verify(table_grid.size.x <= battle_scroll.size.x + 3.0, "Ten places fit available table width at " + str(test_size))
		game.table_cards.clear()
		for i in range(10):
			game.table_cards.append({"attack": normal_card(i + 2, "♥"), "defense": {}})
		game.update_ui()
		verify(table_grid.get_child_count() == 10, "Ten attack cards occupy exactly two rows")
		game.table_cards[0]["defense"] = normal_card(14, "♥")
		game.update_ui()
		verify(table_grid.get_child_count() == 10 and table_grid.get_child(0).get_child_count() == 2, "Covering defense overlaps its attack in the same slot")
		game.new_game()
	get_root().size = Vector2i(720, 1280)
	await process_frame
	game.adapt_layout()

	verify(game.player_hand.size() == 6, "Player starts with six cards")
	verify(game.bot_hand.size() + game.table_cards.size() == 6, "Bot starts with six cards, possibly leading first")
	verify(game.attacker == 0 or game.attacker == 1, "First move belongs to one of the players")
	verify(game.deck.size() == 43, "Deck contains 52 normal cards, two jokers and one mark")

	# First move: compare the lowest trump in both hands, not the lowest rank overall.
	game.trump_mode = "suit"
	game.trump_suit = "♠"
	game.player_hand = [normal_card(7, "♠"), normal_card(2, "♥")]
	game.bot_hand = [normal_card(3, "♠"), normal_card(8, "♣")]
	verify(game.determine_first_attacker() == 1, "Computer with three of trumps starts before player's seven")
	game.bot_hand = [normal_card(9, "♠")]
	verify(game.determine_first_attacker() == 0, "Player with lower trump starts first")
	game.player_hand = [normal_card(7, "♠")]
	game.bot_hand = [normal_card(7, "♠")]
	verify(game.determine_first_attacker() == 0, "Equal lowest trumps give the player first move")
	game.trump_mode = "red"
	game.player_hand = [normal_card(5, "♥")]
	game.bot_hand = [normal_card(3, "♦")]
	verify(game.determine_first_attacker() == 1, "Both red suits count as trump in double trump mode")
	game.trump_mode = "none"
	verify(game.determine_first_attacker() == 0, "No trump gives player the first move")

	verify(game.difficulty_select.item_count == 3, "Menu contains three bot difficulty choices")
	for level in range(3):
		game.difficulty_select.select(level)
		game.start_game()
		verify(game.bot_difficulty == level, "Bot difficulty selection applies level " + str(level))
	game.difficulty_select.select(1)
	game.start_game()

	# Loading a selected photo stores a capped image in user://.
	var tiny_image: Image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	tiny_image.fill(Color("#b759eb"))
	var chosen_file: String = ProjectSettings.globalize_path("user://test-avatar.png")
	verify(tiny_image.save_png(chosen_file) == OK, "Test avatar PNG can be created")
	game.on_avatar_file_selected(chosen_file)
	verify(game.avatar_texture != null and FileAccess.file_exists(game.AVATAR_SAVE_PATH), "Chosen avatar is saved and shown")
	game.load_saved_avatar()
	verify(game.avatar_texture != null, "Avatar survives profile reload")
	game.clear_avatar()
	verify(game.avatar_texture == null and not FileAccess.file_exists(game.AVATAR_SAVE_PATH), "Avatar can be removed")
	DirAccess.remove_absolute(chosen_file)

	# Updating labels must not destroy and recreate unchanged card controls.
	game.new_game()
	var first_card_view: Node = game.hand_row.get_child(0)
	game.update_ui()
	verify(game.hand_row.get_child(0) == first_card_view, "Unchanged hand views are reused")
	game.new_game()

	# Pressing "Draw" must take exactly one card, not refill the entire hand.
	game.player_hand.resize(3)
	var previous_deck_count: int = game.deck.size()
	game.draw_cards()
	verify(game.player_hand.size() == 4, "Draw button adds exactly one card")
	verify(game.deck.size() == previous_deck_count - 1, "Draw button removes exactly one card from deck")
	game.new_game()


	# Regression: standard Android fonts may not contain suit glyphs.
	# Card suits must be vector graphics and the trump remains visible.
	var hearts_card: Variant = game.make_card_view(normal_card(8, "♥"), "hand", 0, -1)
	root.add_child(hearts_card)
	var hearts_glyph: Variant = hearts_card.get_node_or_null("SuitGlyph")
	verify(hearts_glyph != null and hearts_glyph.suit == "♥", "Heart suit renders through a vector symbol")
	var corner_glyph: Variant = hearts_card.get_node_or_null("SuitCorner")
	verify(corner_glyph != null and corner_glyph.suit == "♥", "Suit is also visible in the corner")
	for test_suit in ["♠", "♥", "♦", "♣"]:
		verify(game.suit_short_name(test_suit) != "", "Readable suit label exists for " + test_suit)
	hearts_card.queue_free()

	game.trump_mode = "suit"
	game.trump_suit = "♠"
	game.update_ui()
	verify(game.trump_label.text == "ПИКИ" and game.trump_icon_row.get_child_count() == 1, "Normal trump is clearly labeled and drawn")
	game.trump_mode = "red"
	game.update_ui()
	verify(game.trump_label.text.contains("ЧЕРВЫ") and game.trump_icon_row.get_child_count() == 2, "Dual red trump shows both vector suits")
	game.trump_mode = "black"
	game.update_ui()
	verify(game.trump_label.text.contains("ТРЕФЫ") and game.trump_icon_row.get_child_count() == 2, "Dual black trump shows both vector suits")
	game.trump_mode = "none"
	game.update_ui()
	verify(game.trump_label.text.contains("БЕЗ") and game.trump_icon_row.get_child_count() == 1, "No-trump mode is clearly shown")
	game.deck.clear()
	game.update_ui()
	verify(game.trump_label.visible and game.trump_icon_row.visible, "Trump display stays visible after deck runs out")
	game.new_game()

	# Each of the ten squares is an actual interactive drop target.
	game.new_game()
	game.trump_mode = "suit"
	game.trump_suit = "♠"
	game.bot_difficulty = 1
	game.attacker = 0
	game.bot_takes = false
	game.table_cards.clear()
	game.player_hand = [normal_card(12, "♥"), normal_card(11, "♥")]
	game.bot_hand = [normal_card(2, "♣"), normal_card(3, "♣"), normal_card(4, "♣"), normal_card(5, "♣"), normal_card(6, "♣"), normal_card(7, "♣")]
	game.deck.clear()
	game.update_ui()
	var square: Variant = table_grid.get_child(7)
	verify(square.name == "Slot_7", "All ten squares have stable identifiers")
	verify(square._can_drop_data(Vector2.ZERO, {"type": "hand_card", "index": 0}), "Can drag attack into chosen empty square")
	game.place_in_slot(0, 7)
	verify(game.table_cards.size() == 1 and game.pair_at_slot(7) == 0, "Player attack stays in chosen square 8")
	var remaining: int = game.player_hand.size()
	game.place_in_slot(0, 7)
	verify(game.player_hand.size() == remaining and game.table_cards.size() == 1, "Illegal drop does not consume a card")

	game.attacker = 1
	game.bot_takes = false
	game.table_cards = [{"attack": normal_card(6, "♣"), "defense": {}, "slot_id": 4}]
	game.player_hand = [normal_card(8, "♣"), normal_card(6, "♥")]
	game.bot_hand = []
	game.update_ui()
	verify(game.can_drop_on_slot(0, 4), "Valid defender can be placed on occupied square")
	verify(not game.can_drop_on_slot(0, 5), "Different rank cannot be translated into empty square")
	var defending_square: Variant = table_grid.get_child(4)
	verify(defending_square._can_drop_data(Vector2.ZERO, {"type": "hand_card", "index": 0}), "Attacked square accepts dragged covering card")
	game.place_in_slot(0, 4)
	verify(game.card_rank(game.table_cards[0]["defense"]) == 8 and game.pair_at_slot(4) == 0, "Defense covers attack in selected square")

	game.attacker = 1
	game.bot_takes = false
	game.table_cards = [{"attack": normal_card(6, "♣"), "defense": {}, "slot_id": 2}]
	game.player_hand = [normal_card(6, "♦")]
	game.bot_hand = [normal_card(2, "♥"), normal_card(3, "♥"), normal_card(4, "♥"), normal_card(5, "♥")]
	game.deck.clear()
	game.update_ui()
	verify(game.can_drop_on_slot(0, 9), "Matching rank can be translated into any empty square")
	game.place_in_slot(0, 9)
	verify(game.attacker == 0 and game.pair_at_slot(9) == 1, "Transfer changes defender and stays in chosen empty square")
	game.new_game()

	var attack: Dictionary = normal_card(6, "♣")
	var stronger: Dictionary = normal_card(10, "♣")
	var cheaper: Dictionary = normal_card(7, "♣")
	var mark: Dictionary = {"rank": 22, "suit": "", "special": "mark", "joker_color": "", "copy_rank": -1, "copy_suit": ""}
	var joker: Dictionary = {"rank": 20, "suit": "", "special": "joker", "joker_color": "red", "copy_rank": -1, "copy_suit": ""}
	game.trump_mode = "suit"
	game.trump_suit = "♠"
	verify(game.can_beat(stronger, attack), "Higher card of same suit beats attack")
	verify(game.can_beat(mark, attack), "Mark beats a normal card")
	verify(not game.can_beat(attack, mark), "Normal card cannot beat mark")
	var copy: Dictionary = game.copy_joker(joker, attack)
	verify(game.is_joker(copy) and game.card_rank(copy) == 6 and game.card_suit(copy) == "♣", "Joker copies rank and suit")

	# Joker copies ALL visible table cards: attack, defense, played Joker, Mark.
	var played_joker: Dictionary = game.copy_joker(joker, normal_card(9, "♥"))
	var joker_mark_copy: Dictionary = game.copy_joker(joker, mark)
	verify(game.card_rank(joker_mark_copy) == 100, "Joker also copies a Mark")
	verify(game.can_beat(copy, normal_card(14, "♦")), "Joker copied from a non-trump can beat an unrelated attack")
	verify(game.can_beat(joker_mark_copy, attack), "Joker copying Mark can cover an attack")
	game.attacker = 1
	game.finished = false
	game.table_cards = [
		{"attack": attack, "defense": {}, "slot_id": 0},
		{"attack": normal_card(10, "♥"), "defense": normal_card(11, "♥"), "slot_id": 1},
		{"attack": mark, "defense": normal_card(7, "♦"), "slot_id": 2},
		{"attack": played_joker, "defense": {}, "slot_id": 3}
	]
	game.player_hand = [joker.duplicate(true)]
	game.bot_hand = [normal_card(2, "♣"), normal_card(3, "♣")]
	game.show_joker_choices("defend", 0, 0)
	verify(game.joker_options.get_child_count() == 6, "Joker choice dialog offers all six distinct visible card values, including Mark and copied Joker")
	game.choose_joker(mark)
	verify(game.is_joker(game.table_cards[0]["defense"]) and game.card_rank(game.table_cards[0]["defense"]) == 100, "Chosen copied Mark is stored on the table as a Joker")
	var mark_joker_view: Variant = game.make_card_view(joker_mark_copy, "hand", -1, -1)
	root.add_child(mark_joker_view)
	verify(mark_joker_view.get_node("SuitGlyph").suit == "mark", "Copied Mark is drawn as Mark on the Joker")
	verify(game.card_name(joker_mark_copy).contains("Метка"), "Copied Mark name appears on Joker card")
	verify(mark_joker_view.get_node_or_null("JokerCopiedValue") != null, "Copied Joker has large copy badge")
	verify(mark_joker_view.get_node("JokerCopiedValue/CopyInfo/CopiedCard").text == "МЕТКА", "Copied Mark is readable in the middle of Joker card")
	mark_joker_view.queue_free()
	var hearts_joker_view: Variant = game.make_card_view(played_joker, "hand", -1, -1)
	root.add_child(hearts_joker_view)
	verify(hearts_joker_view.get_node("SuitGlyph").suit == "♥", "Copied heart is drawn visibly on the Joker")
	verify(game.card_name(played_joker).contains("9♥"), "Joker name contains copied suit and value")
	verify(hearts_joker_view.get_node("JokerCopiedValue/CopyInfo/CopiedCard").text == "9♥", "Joker card visibly tells which rank and suit it copied")
	hearts_joker_view.queue_free()

	# Translation with a Joker must copy a visible rank into a chosen empty square.
	game.attacker = 1
	game.finished = false
	game.bot_takes = false
	game.table_cards = [{"attack": normal_card(6, "♣"), "defense": {}, "slot_id": 2}]
	game.player_hand = [joker.duplicate(true)]
	game.bot_hand = [normal_card(2, "♥"), normal_card(3, "♥"), normal_card(4, "♥")]
	game.place_in_slot(0, 8)
	verify(game.joker_options.get_child_count() == 1, "Joker transfer dialog lists matching visible card")
	game.choose_joker(game.table_cards[0]["attack"])
	verify(game.attacker == 0 and game.pair_at_slot(8) == 1 and game.card_rank(game.table_cards[1]["attack"]) == 6, "Joker transfer uses copied rank in chosen empty square")

	# Last special card is not defeat when computer is attacking.
	game.deck.clear()
	game.table_cards.clear()
	game.attacker = 1
	game.finished = false
	game.player_hand = [joker.duplicate(true)]
	game.bot_hand = [normal_card(4, "♥")]
	game.check_winner()
	verify(not game.finished, "Final Joker is not an automatic loss when computer attacks")
	game.attacker = 0
	game.check_winner()
	verify(game.finished, "Special-only hand loses when player must start attack")
	game.new_game()


	game.attacker = 1
	game.table_cards = [{"attack": attack, "defense": stronger}]
	game.player_hand = [cheaper]
	game.player_replace(0, 0, cheaper)
	verify(game.card_rank(game.table_cards[0]["defense"]) == 7, "Simplification replaces defense with a cheaper card")
	verify(game.card_rank(game.player_hand[0]) == 10, "Previous defense returns to the player's hand")

	# Replacing a high normal defense with a small trump is legal,
	# but should require explicit confirmation before any card changes.
	game.attacker = 1
	game.bot_takes = false
	game.finished = false
	game.trump_mode = "suit"
	game.trump_suit = "♥"
	game.table_cards = [{
		"attack": normal_card(4, "♦"),
		"defense": normal_card(14, "♦"),
		"slot_id": 3
	}]
	game.player_hand = [normal_card(2, "♥")]
	game.bot_hand = []
	verify(game.can_drop_on_slot(0, 3), "A small trump can be dragged onto a defense covering four diamonds")
	game.player_replace(0, 0, game.player_hand[0])
	verify(not game.pending_replacement.is_empty(), "An expensive or trump replacement prompts for confirmation")
	verify(game.card_rank(game.table_cards[0]["defense"]) == 14, "Confirmation does not instantly replace the old defense")
	verify(game.card_rank(game.player_hand[0]) == 2, "Before confirming, the trump remains in the hand")
	verify(game.replace_confirmation.dialog_text.contains("козырь"), "Confirmation warns that a trump will be spent")
	game.confirm_replacement()
	verify(game.card_rank(game.table_cards[0]["defense"]) == 2 and game.card_suit(game.table_cards[0]["defense"]) == "♥", "Confirmed trump replacement covers the original attack")
	verify(game.card_rank(game.player_hand[0]) == 14, "Old ace defense returns to hand after confirmed swap")
	verify(game.replaced_throw_ranks.has(14), "Old ace rank stays legal for opponent throw-in")
	game.replace_confirmation.hide()
	game.new_game()

	game.attacker = 1
	game.bot_takes = true
	game.table_cards = [{"attack": attack, "defense": {}}]
	game.player_hand = [attack.duplicate(true)]
	game.bot_hand = [normal_card(8, "♦"), normal_card(9, "♥")]
	game.player_transfer(0, game.player_hand[0])
	verify(game.attacker == 0 and game.table_cards.size() == 2, "Transfer changes the defender and preserves both attacks")

	game.attacker = 1
	game.bot_takes = false
	game.bot_hand.clear()
	game.table_cards = [{"attack": attack, "defense": {}}]
	game.player_hand = [mark]
	game.player_defend(0, 0, mark)
	verify(game.card_rank(game.table_cards[0]["defense"]) == 100, "Mark can be played as a defense")


	# Animated UI is disabled by the headless runner but its live nodes,
	# state flags and render targets must be wired correctly.
	verify(not game.animation_enabled or game.motion_layer != null, "Card animation layer is initialized")
	verify(game.has_method("play_deal_animation") and game.has_method("animate_collection") and game.has_method("animate_table_card"), "Shuffle, deal, pickup, and move animations are present")
	game.new_game()
	verify(game.enemy_backs != null and game.enemy_backs.get_child_count() == game.bot_hand.size(), "Computer hand is shown as separate card backs")
	verify(game.discard_label != null and game.discard_label.text.contains("БИТО"), "Visible discard counter exists")


	# Bot draws up to a hand of SIX when defending; never above that.
	game.attacker = 0
	game.bot_takes = false
	game.finished = false
	game.bot_difficulty = 1
	game.trump_mode = "suit"
	game.trump_suit = "♠"
	game.table_cards = [{"attack": normal_card(10, "♣"), "defense": {}, "slot_id": 0}]
	game.bot_hand = [
		normal_card(2, "♥"), normal_card(3, "♥"),
		normal_card(4, "♥"), normal_card(5, "♥"),
		normal_card(6, "♥"), normal_card(7, "♥")
	]
	game.deck = [normal_card(12, "♣"), normal_card(8, "♦")]
	game.bot_defend()
	verify(game.deck.size() == 2, "Bot at six cards never draws a seventh")
	verify(game.bot_hand.size() == 6 and game.bot_takes, "Bot takes the table instead of exceeding six-card hand")

	game.bot_takes = false
	game.bot_hand = [
		normal_card(2, "♥"), normal_card(3, "♥"),
		normal_card(4, "♥"), normal_card(5, "♥")
	]
	game.table_cards = [{"attack": normal_card(10, "♣"), "defense": {}, "slot_id": 0}]
	game.deck = [normal_card(12, "♣"), normal_card(8, "♦")]
	game.bot_defend()
	verify(game.deck.is_empty(), "Bot draws cards one at a time while under six")
	verify(
		not game.table_cards[0]["defense"].is_empty()
		and game.card_rank(game.table_cards[0]["defense"]) == 12,
		"Bot defends with the matching card drawn from the deck"
	)
	verify(game.bot_hand.size() == 5, "After defense the bot has no more than six cards")
	verify(not game.bot_takes, "A matching drawn card prevents taking the table")

	game.bot_hand = [normal_card(2, "♥")]
	game.table_cards = [{"attack": normal_card(10, "♣"), "defense": {}, "slot_id": 0}]
	game.deck.clear()
	game.bot_takes = false
	game.bot_defend()
	verify(game.bot_takes, "With empty deck and no defense bot takes cards")

	# With four covered cards and two cards remaining in defender's hand,
	# the attacking player may throw at most two additional cards.
	game.first_round = false
	game.attacker = 0
	game.table_cards.clear()
	for i in range(4):
		game.table_cards.append({
			"attack": normal_card(6 + i, "♣"),
			"defense": normal_card(7 + i, "♣"),
			"slot_id": i
		})
	game.bot_hand = [normal_card(2, "♥"), normal_card(3, "♥")]
	verify(game.defender_attack_limit() == 6, "Four defenses and two cards left permit at most six attacks")
	for i in range(2):
		game.table_cards.append({
			"attack": normal_card(10 + i, "♦"),
			"defense": {},
			"slot_id": i + 4
		})
	verify(game.defender_attack_limit() == 6, "Seventh throw is blocked after two additional cards")
	game.new_game()

	# The old defense rank stays playable as a throw-in AFTER player
	# swaps 10 clubs for 7 clubs. Hard difficulty always throws a legal card.
	game.new_game()
	game.bot_difficulty = 2
	game.attacker = 1
	game.bot_takes = false
	game.trump_mode = "suit"
	game.trump_suit = "♠"
	game.table_cards = [
		{"attack": normal_card(6, "♣"), "defense": normal_card(10, "♣"), "slot_id": 0}
	]
	game.player_hand = [normal_card(7, "♣")]
	game.bot_hand = [normal_card(10, "♥")]
	game.player_replace(0, 0, game.player_hand[0])
	verify(game.replaced_throw_ranks.has(10), "Previous defense rank remains legal after player changes their covering card")
	verify(game.table_has_rank(10), "Bot knows it can throw the replaced card rank")
	verify(game.table_cards.size() == 2, "Hard bot throws matching rank returned by replaced defense")
	verify(game.card_rank(game.table_cards[1]["attack"]) == 10, "Bot's added card matches replaced defense rank")

	# Bito must be rejected when any card remains uncovered.
	game.new_game()
	game.bot_takes = false
	game.attacker = 1
	game.table_cards = [{"attack": normal_card(9, "♣"), "defense": {}, "slot_id": 3}]
	game.finish_round()
	verify(game.table_cards.size() == 1, "Bito cannot clear an unbeaten attack")
	game.table_cards[0]["defense"] = normal_card(10, "♣")
	game.deck.clear()
	game.finish_round()
	verify(game.table_cards.is_empty(), "Finished Bito clears the field")
	verify(game.discard_pile.size() >= 2, "Bito cards move to a visible discard counter")
	game.new_game()

	if failures == 0:
		print("JOKERSHIFT FULL-GAME SMOKE TEST PASSED")
	quit(1 if failures > 0 else 0)
