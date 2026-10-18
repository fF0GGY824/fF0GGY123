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

	game.attacker = 1
	game.table_cards = [{"attack": attack, "defense": stronger}]
	game.player_hand = [cheaper]
	game.player_replace(0, 0, cheaper)
	verify(game.card_rank(game.table_cards[0]["defense"]) == 7, "Simplification replaces defense with a cheaper card")
	verify(game.card_rank(game.player_hand[0]) == 10, "Previous defense returns to the player's hand")

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

	if failures == 0:
		print("JOKERSHIFT FULL-GAME SMOKE TEST PASSED")
	quit(1 if failures > 0 else 0)
