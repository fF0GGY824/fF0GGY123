extends Control

const SUITS = ["♠", "♥", "♦", "♣"]
const RANKS = ["6", "7", "8", "9", "10", "В", "Д", "К", "Т"]
var deck: Array = []
var hand: Array = []
var enemy: Array = []
var attacks: Array = []
var defenses: Array = []
var trump: String = ""
var player_attacks := true
var game_over := false
var info: Label
var board: VBoxContainer
var cards: HFlowContainer
var enemy_label: Label
var deck_label: Label
var action_button: Button
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	_make_ui()
	new_game()

func _make_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#180d29")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 15)
	margin.add_child(root)
	var title := Label.new()
	title.text = "🃏 JOKERSHIFT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	root.add_child(title)
	enemy_label = Label.new()
	enemy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(enemy_label)
	deck_label = Label.new()
	deck_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(deck_label)
	info = Label.new()
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(info)
	board = VBoxContainer.new()
	root.add_child(board)
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(gap)
	var hand_title := Label.new()
	hand_title.text = "Твои карты — нажми для хода"
	root.add_child(hand_title)
	cards = HFlowContainer.new()
	cards.add_theme_constant_override("h_separation", 7)
	cards.add_theme_constant_override("v_separation", 7)
	root.add_child(cards)
	action_button = Button.new()
	action_button.custom_minimum_size.y = 58
	action_button.pressed.connect(_action)
	root.add_child(action_button)
	var restart := Button.new()
	restart.text = "Новая игра"
	restart.pressed.connect(new_game)
	root.add_child(restart)

func _card(rank: int, suit: String) -> Dictionary:
	return {"rank": rank, "suit": suit}

func _name(c: Dictionary) -> String:
	if c.get("rank", -1) == 99:
		return "🃏 Джокер"
	return RANKS[int(c["rank"])] + str(c["suit"])

func _power(c: Dictionary) -> int:
	if int(c["rank"]) == 99:
		return 100
	return int(c["rank"]) + (20 if str(c["suit"]) == trump else 0)

func _beats(a: Dictionary, d: Dictionary) -> bool:
	if int(d["rank"]) == 99:
		return true
	if int(a["rank"]) == 99:
		return false
	if str(a["suit"]) == str(d["suit"]):
		return int(d["rank"]) > int(a["rank"])
	return str(d["suit"]) == trump and str(a["suit"]) != trump

func new_game() -> void:
	deck.clear()
	hand.clear()
	enemy.clear()
	attacks.clear()
	defenses.clear()
	game_over = false
	player_attacks = true
	for s in SUITS:
		for r in range(RANKS.size()):
			deck.append(_card(r, s))
	deck.append({"rank": 99, "suit": ""})
	deck.append({"rank": 99, "suit": ""})
	deck.shuffle()
	trump = str(SUITS[rng.randi_range(0, 3)])
	for i in range(6):
		hand.append(deck.pop_back())
		enemy.append(deck.pop_back())
	info.text = "Твой ход: атакуй картой"
	_refresh()

func _refresh() -> void:
	for child in board.get_children():
		child.queue_free()
	for child in cards.get_children():
		child.queue_free()
	enemy_label.text = "Соперник: %d карт" % enemy.size()
	deck_label.text = "Колода: %d | Козырь: %s" % [deck.size(), trump]
	var table := Label.new()
	table.text = "Стол: "
	for i in range(attacks.size()):
		table.text += _name(attacks[i])
		if i < defenses.size():
			table.text += " → " + _name(defenses[i])
		table.text += "    "
	table.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	board.add_child(table)
	for i in range(hand.size()):
		var b := Button.new()
		b.text = _name(hand[i])
		b.custom_minimum_size = Vector2(78, 105)
		b.add_theme_font_size_override("font_size", 20)
		b.pressed.connect(_play.bind(i))
		cards.add_child(b)
	action_button.text = "Забрать" if not player_attacks else "Бито / завершить"
	action_button.disabled = game_over
	if game_over:
		action_button.text = "Игра окончена"

func _play(index: int) -> void:
	if game_over or index >= hand.size():
		return
	var c: Dictionary = hand[index]
	if player_attacks:
		if not attacks.is_empty() and not _same_rank(c):
			info.text = "Можно подкидывать только совпадающие значения"
			return
		if attacks.size() >= 6 or attacks.size() >= enemy.size() + defenses.size():
			info.text = "Больше карт подкинуть нельзя"
			return
		hand.remove_at(index)
		attacks.append(c)
		_bot_defend()
	else:
		if attacks.size() <= defenses.size():
			return
		if not _beats(attacks[defenses.size()], c):
			info.text = "Эта карта не бьёт атаку"
			return
		hand.remove_at(index)
		defenses.append(c)
		info.text = "Отбился! Нажми «Бито»"
	_refresh()

func _same_rank(c: Dictionary) -> bool:
	for x in attacks + defenses:
		if int(x["rank"]) == int(c["rank"]):
			return true
	return false

func _bot_defend() -> void:
	var attack: Dictionary = attacks.back()
	var best := -1
	for i in range(enemy.size()):
		if _beats(attack, enemy[i]):
			if best == -1 or _power(enemy[i]) < _power(enemy[best]):
				best = i
	if best == -1:
		for c in attacks + defenses:
			enemy.append(c)
		attacks.clear()
		defenses.clear()
		_draw_cards()
		info.text = "Бот забрал карты. Твой ход"
	else:
		defenses.append(enemy[best])
		enemy.remove_at(best)
		info.text = "Бот отбился. Можно подкинуть или нажать «Бито»"

func _action() -> void:
	if game_over:
		return
	if player_attacks:
		if attacks.is_empty():
			info.text = "Сначала выбери карту"
			return
		if defenses.size() != attacks.size():
			info.text = "Дождись ответа бота"
			return
		attacks.clear()
		defenses.clear()
		_draw_cards()
		player_attacks = false
		_bot_attack()
	else:
		for c in attacks + defenses:
			hand.append(c)
		attacks.clear()
		defenses.clear()
		_draw_cards()
		player_attacks = false
		info.text = "Ты забрал карты"
		_bot_attack()
	_check_end()
	_refresh()

func _bot_attack() -> void:
	if enemy.is_empty():
		_check_end()
		return
	var best := 0
	for i in range(1, enemy.size()):
		if _power(enemy[i]) < _power(enemy[best]):
			best = i
	attacks.append(enemy[best])
	enemy.remove_at(best)
	info.text = "Бот атакует: " + _name(attacks.back()) + ". Отбей или забери"
	_refresh()

func _draw_cards() -> void:
	while hand.size() < 6 and not deck.is_empty():
		hand.append(deck.pop_back())
	while enemy.size() < 6 and not deck.is_empty():
		enemy.append(deck.pop_back())
	_check_end()

func _check_end() -> void:
	if not deck.is_empty() or not attacks.is_empty():
		return
	if hand.is_empty():
		game_over = true
		info.text = "Победа! 🎉"
	elif enemy.is_empty():
		game_over = true
		info.text = "Бот победил. Попробуй снова!"
