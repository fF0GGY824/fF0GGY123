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
	verify(game.player_hand.size() == 6 and game.bot_hand.size() == 6, "Both players start with six cards")
	verify(game.deck.size() == 43, "Deck contains 52 normal cards, two jokers and one mark")

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
