
extends Control

const SUITS = ["♠", "♥", "♦", "♣"]
const RANKS = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "В", "Д", "К", "Т"]

const BG = Color("#12091F")
const VIOLET = Color("#A45BFF")
const LIGHT = Color("#F5E8FF")
const GOLD = Color("#DDB5FF")

var deck: Array = []
var player_hand: Array = []
var bot_hand: Array = []
var table_cards: Array = []
var discard_pile: Array = []

var trump_mode: String = "suit"
var trump_suit: String = ""

# 0 = игрок атакует, 1 = бот атакует
var attacker: int = 0
var first_round: bool = true
var bot_takes: bool = false
var finished: bool = false

var player_nick: String = "Игрок"
var selected_index: int = -1
var selected_pair: int = -1
var status_text: String = ""

var menu_screen: Control
var game_screen: Control
var nick_input: LineEdit

var rules_dialog: AcceptDialog
var result_dialog: AcceptDialog
var joker_dialog: ConfirmationDialog
var joker_options: VBoxContainer

var bot_label: Label
var player_label: Label
var deck_label: Label
var trump_label: Label
var trump_icon_row: HBoxContainer
var status_label: Label

var table_grid: GridContainer
var hand_row: HBoxContainer
var deck_panel: PanelContainer
var field_panel: GameField

var card_width: float = 74.0
var card_height: float = 110.0

var pending_joker_action: String = ""
var pending_joker_index: int = -1
var pending_pair_index: int = -1


# ==========================================
# КАРТА
# ==========================================

# Symbols are painted with vector shapes instead of relying on Android font glyphs.
class SuitIcon extends Control:
	var suit: String = ""
	var ink: Color = Color("#251530")
	var card_icon: bool = false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		queue_redraw()

	func paint_poly(points: PackedVector2Array) -> void:
		draw_colored_polygon(points, ink)

	func _draw() -> void:
		if suit.is_empty():
			return

		var center: Vector2 = Vector2(size.x * 0.5, size.y * (0.60 if card_icon else 0.5))
		var r: float = minf(size.x * 0.30, size.y * (0.23 if card_icon else 0.36))
		if r < 2.0:
			return

		match suit:
			"♥":
				draw_circle(center + Vector2(-0.47 * r, -0.35 * r), 0.65 * r, ink)
				draw_circle(center + Vector2(0.47 * r, -0.35 * r), 0.65 * r, ink)
				paint_poly(PackedVector2Array([
					center + Vector2(-1.10 * r, -0.25 * r),
					center + Vector2(1.10 * r, -0.25 * r),
					center + Vector2(0.0, 1.28 * r)
				]))
			"♦":
				paint_poly(PackedVector2Array([
					center + Vector2(0.0, -1.28 * r),
					center + Vector2(0.95 * r, 0.0),
					center + Vector2(0.0, 1.28 * r),
					center + Vector2(-0.95 * r, 0.0)
				]))
			"♠":
				draw_circle(center + Vector2(-0.49 * r, 0.12 * r), 0.62 * r, ink)
				draw_circle(center + Vector2(0.49 * r, 0.12 * r), 0.62 * r, ink)
				paint_poly(PackedVector2Array([
					center + Vector2(0.0, -1.33 * r),
					center + Vector2(1.04 * r, 0.33 * r),
					center + Vector2(-1.04 * r, 0.33 * r)
				]))
				paint_poly(PackedVector2Array([
					center + Vector2(-0.20 * r, 0.30 * r),
					center + Vector2(0.20 * r, 0.30 * r),
					center + Vector2(0.47 * r, 1.12 * r),
					center + Vector2(-0.47 * r, 1.12 * r)
				]))
			"♣":
				draw_circle(center + Vector2(0.0, -0.66 * r), 0.63 * r, ink)
				draw_circle(center + Vector2(-0.59 * r, 0.16 * r), 0.63 * r, ink)
				draw_circle(center + Vector2(0.59 * r, 0.16 * r), 0.63 * r, ink)
				paint_poly(PackedVector2Array([
					center + Vector2(-0.20 * r, 0.0),
					center + Vector2(0.20 * r, 0.0),
					center + Vector2(0.47 * r, 1.10 * r),
					center + Vector2(-0.47 * r, 1.10 * r)
				]))
			"joker", "mark":
				var points: PackedVector2Array = PackedVector2Array()
				for i in range(10):
					var a: float = -PI * 0.5 + float(i) * PI / 5.0
					var length: float = r * (1.16 if i % 2 == 0 else 0.43)
					points.append(center + Vector2(cos(a), sin(a)) * length)
				paint_poly(points)


class GameCard extends Button:
	var game
	var card: Dictionary = {}
	var role: String = ""
	var hand_index: int = -1
	var pair_index: int = -1

	func _ready() -> void:
		text = ""
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

		mouse_entered.connect(_hover.bind(true))
		mouse_exited.connect(_hover.bind(false))

		var icon: SuitIcon = SuitIcon.new()
		icon.name = "SuitGlyph"
		icon.card_icon = true
		icon.suit = str(game.card_suit(card))
		icon.ink = Color("#D82E57") if icon.suit == "♥" or icon.suit == "♦" else Color("#251530")
		if game.is_mark(card):
			icon.suit = "mark"
			icon.ink = Color("#8732C8")
		elif game.is_joker(card):
			icon.suit = "joker"
			icon.ink = Color("#D82E57") if str(card.get("joker_color", "")) == "red" else Color("#251530")
		add_child(icon)
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _hover(active: bool) -> void:
		if not is_inside_tree():
			return

		pivot_offset = size / 2.0

		var tween: Tween = create_tween()
		tween.tween_property(
			self,
			"scale",
			Vector2(1.04, 1.04) if active else Vector2.ONE,
			0.13
		)

	func _draw() -> void:
		if card.is_empty():
			return

		var font: Font = get_theme_default_font()

		var rank: String = str(
			game.rank_name(game.card_rank(card))
		)

		var suit: String = str(
			game.card_suit(card)
		)

		var ink: Color = Color("#251530")

		if suit == "♥" or suit == "♦":
			ink = Color("#D82E57")

		if game.is_mark(card):
			rank = "М"
			suit = "✦"
			ink = Color("#8732C8")

		if game.is_joker(card):
			rank = "J"
			suit = "★"

			if str(card.get("joker_color", "")) == "red":
				ink = Color("#D82E57")
			else:
				ink = Color("#251530")

		var factor: float = size.x / 74.0
		var small_size: int = maxi(13, int(19.0 * factor))
		var big_size: int = maxi(27, int(48.0 * factor))

		draw_string(
			font,
			Vector2(7.0, 22.0 * factor),
			rank,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			small_size,
			ink
		)

		# The suit itself is drawn by SuitIcon without a font dependency.

		if game.is_joker(card):
			var subtitle: String = "ДЖОКЕР"

			if game.card_rank(card) == 100:
				subtitle = "МЕТКА"
			elif game.card_rank(card) >= 2:
				subtitle = (
					game.rank_name(game.card_rank(card))
					+ game.card_suit(card)
				)

			draw_string(
				font,
				Vector2(5.0, size.y - 8.0),
				subtitle,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				maxi(9, int(11.0 * factor)),
				ink
			)

	func _get_drag_data(_position: Vector2) -> Variant:
		if role != "hand":
			return null

		if game.finished:
			return null

		var preview: Label = Label.new()
		preview.text = game.card_name(card)
		preview.add_theme_font_size_override("font_size", 22)
		preview.add_theme_color_override(
			"font_color",
			Color("#E9C5FF")
		)

		var holder: Control = Control.new()
		holder.custom_minimum_size = Vector2(180, 50)
		holder.add_child(preview)
		set_drag_preview(holder)

		return {
			"type": "hand_card",
			"index": hand_index
		}

	func _can_drop_data(
		_position: Vector2,
		data: Variant
	) -> bool:
		if role == "hand":
			return false

		if typeof(data) != TYPE_DICTIONARY:
			return false

		return data.get("type", "") == "hand_card"

	func _drop_data(
		_position: Vector2,
		data: Variant
	) -> void:
		game.play_hand_card(
			int(data["index"]),
			role,
			pair_index
		)


# ==========================================
# ИГРОВОЕ ПОЛЕ
# ==========================================

class GameField extends PanelContainer:
	var game

	func _can_drop_data(
		_position: Vector2,
		data: Variant
	) -> bool:
		if typeof(data) != TYPE_DICTIONARY:
			return false

		return data.get("type", "") == "hand_card"

	func _drop_data(
		_position: Vector2,
		data: Variant
	) -> void:
		game.play_hand_card(
			int(data["index"]),
			"field",
			-1
		)


# ==========================================
# ЗАПУСК
# ==========================================

func _ready() -> void:
	randomize()

	set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	create_interface()

	get_viewport().size_changed.connect(
		adapt_layout
	)

	show_menu()


# ==========================================
# СТИЛИ
# ==========================================

func make_style(
	background: Color,
	border: Color,
	radius: int = 12
) -> StyleBoxFlat:
	var style_box: StyleBoxFlat = StyleBoxFlat.new()

	style_box.bg_color = background
	style_box.border_color = border
	style_box.set_border_width_all(2)
	style_box.set_corner_radius_all(radius)

	style_box.content_margin_left = 6
	style_box.content_margin_right = 6
	style_box.content_margin_top = 6
	style_box.content_margin_bottom = 6

	return style_box


func make_label(
	value: String,
	font_size: int = 16,
	color: Color = LIGHT
) -> Label:
	var result: Label = Label.new()

	result.text = value
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	result.add_theme_font_size_override(
		"font_size",
		font_size
	)

	result.add_theme_color_override(
		"font_color",
		color
	)

	return result


func make_button(
	value: String,
	callback: Callable
) -> Button:
	var button: Button = Button.new()

	button.text = value
	button.custom_minimum_size = Vector2(0, 46)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	button.add_theme_stylebox_override(
		"normal",
		make_style(Color("#48216E"), VIOLET)
	)

	button.add_theme_stylebox_override(
		"hover",
		make_style(Color("#7137A7"), GOLD)
	)

	button.add_theme_color_override(
		"font_color",
		LIGHT
	)

	button.add_theme_font_size_override(
		"font_size",
		15
	)

	button.pressed.connect(callback)

	return button


func clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


func animate_in(
	node: Control,
	delay: float = 0.0
) -> void:
	node.modulate.a = 0.0

	var tween: Tween = create_tween()

	tween.tween_property(
		node,
		"modulate:a",
		1.0,
		0.20
	).set_delay(delay)


func pulse(node: Control) -> void:
	if node == null:
		return

	var tween: Tween = create_tween()

	tween.tween_property(
		node,
		"modulate",
		Color("#D8B2FF"),
		0.12
	)

	tween.tween_property(
		node,
		"modulate",
		Color.WHITE,
		0.18
	)


# ==========================================
# СОЗДАНИЕ ИНТЕРФЕЙСА
# ==========================================

func create_interface() -> void:
	var background: ColorRect = ColorRect.new()

	background.color = BG
	background.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	background.mouse_filter = Control.MOUSE_FILTER_IGNORE

	add_child(background)

	create_menu()
	create_game_screen()
	create_dialogs()


# ==========================================
# ГЛАВНОЕ МЕНЮ
# ==========================================

func create_menu() -> void:
	menu_screen = Control.new()

	menu_screen.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	add_child(menu_screen)

	var center: CenterContainer = CenterContainer.new()

	center.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	menu_screen.add_child(center)

	var menu_panel: PanelContainer = PanelContainer.new()

	menu_panel.custom_minimum_size = Vector2(285, 345)

	menu_panel.add_theme_stylebox_override(
		"panel",
		make_style(
			Color("#26123B"),
			VIOLET,
			20
		)
	)

	center.add_child(menu_panel)

	var column: VBoxContainer = VBoxContainer.new()

	column.add_theme_constant_override(
		"separation",
		14
	)

	menu_panel.add_child(column)

	column.add_child(
		make_label("🃏", 48)
	)

	column.add_child(
		make_label("JokerShift", 34, GOLD)
	)

	column.add_child(
		make_label("Карточная игра", 15)
	)

	nick_input = LineEdit.new()
	nick_input.placeholder_text = "Введи свой ник"
	nick_input.text = "Игрок"
	nick_input.max_length = 18
	nick_input.custom_minimum_size = Vector2(250, 48)

	nick_input.add_theme_font_size_override(
		"font_size",
		17
	)

	column.add_child(nick_input)

	column.add_child(
		make_button("▶ ИГРАТЬ", start_game)
	)

	column.add_child(
		make_button("📖 ПРАВИЛА", show_rules)
	)


func show_menu() -> void:
	game_screen.hide()
	menu_screen.show()
	animate_in(menu_screen)


func start_game() -> void:
	player_nick = nick_input.text.strip_edges()

	if player_nick.is_empty():
		player_nick = "Игрок"

	menu_screen.hide()
	game_screen.show()

	new_game()


# ==========================================
# ИГРОВОЙ ЭКРАН
# ==========================================

func create_game_screen() -> void:
	game_screen = Control.new()

	game_screen.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	add_child(game_screen)

	var margin: MarginContainer = MarginContainer.new()

	margin.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)

	game_screen.add_child(margin)

	var root: VBoxContainer = VBoxContainer.new()

	root.add_theme_constant_override(
		"separation",
		6
	)

	margin.add_child(root)

	# Верхняя строка.
	var top: HBoxContainer = HBoxContainer.new()
	root.add_child(top)

	var title: Label = make_label(
		"🃏 JokerShift",
		21,
		GOLD
	)

	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)

	var menu_button: Button = make_button(
		"☰ Меню",
		show_menu
	)

	menu_button.custom_minimum_size = Vector2(86, 43)
	menu_button.size_flags_horizontal = Control.SIZE_SHRINK_END

	top.add_child(menu_button)

	# Счётчик бота.
	bot_label = make_label("", 16)
	root.add_child(bot_label)

	# Центральная часть: стол и колода.
	var middle: HBoxContainer = HBoxContainer.new()

	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 5)

	root.add_child(middle)

	field_panel = GameField.new()
	field_panel.game = self

	field_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	field_panel.add_theme_stylebox_override(
		"panel",
		make_style(
			Color("#1D0E30"),
			Color("#68379B"),
			14
		)
	)

	middle.add_child(field_panel)

	var field_column: VBoxContainer = VBoxContainer.new()

	field_column.mouse_filter = Control.MOUSE_FILTER_PASS
	field_panel.add_child(field_column)

	var field_title: Label = make_label(
		"ИГРОВОЙ СТОЛ",
		13,
		GOLD
	)

	field_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field_column.add_child(field_title)

	var table_scroll: ScrollContainer = ScrollContainer.new()

	table_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	table_scroll.mouse_filter = Control.MOUSE_FILTER_PASS

	field_column.add_child(table_scroll)

	table_grid = GridContainer.new()
	table_grid.columns = 2
	table_grid.mouse_filter = Control.MOUSE_FILTER_PASS

	table_grid.add_theme_constant_override(
		"h_separation",
		5
	)

	table_grid.add_theme_constant_override(
		"v_separation",
		6
	)

	table_scroll.add_child(table_grid)

	# Колода справа.
	var deck_column: VBoxContainer = VBoxContainer.new()

	deck_column.custom_minimum_size = Vector2(82, 0)
	deck_column.add_theme_constant_override(
		"separation",
		7
	)

	middle.add_child(deck_column)

	deck_column.add_child(
		make_label("КОЛОДА", 12, GOLD)
	)

	deck_panel = PanelContainer.new()
	deck_panel.custom_minimum_size = Vector2(78, 110)

	deck_panel.add_theme_stylebox_override(
		"panel",
		make_style(
			Color("#6324A1"),
			Color("#D9A5FF"),
			10
		)
	)

	deck_column.add_child(deck_panel)

	var deck_art: VBoxContainer = VBoxContainer.new()
	deck_panel.add_child(deck_art)

	deck_art.add_child(make_label("✦", 32))
	deck_art.add_child(make_label("JOKER", 11))
	deck_art.add_child(make_label("SHIFT", 11))

	# A permanent trump display, separate from the deck card.
	# The graphic never relies on unavailable playing-card font glyphs.
	deck_column.add_child(make_label("КОЗЫРЬ", 13, GOLD))
	trump_icon_row = HBoxContainer.new()
	trump_icon_row.alignment = BoxContainer.ALIGNMENT_CENTER
	trump_icon_row.custom_minimum_size = Vector2(82, 48)
	deck_column.add_child(trump_icon_row)

	trump_label = make_label("", 12, GOLD)
	deck_column.add_child(trump_label)

	deck_label = make_label("", 13)
	deck_column.add_child(deck_label)

	# Сообщение.
	status_label = make_label("", 13)
	status_label.custom_minimum_size = Vector2(0, 57)
	root.add_child(status_label)

	# Ник и счётчик.
	player_label = make_label("", 17, GOLD)
	root.add_child(player_label)

	# Рука игрока.
	var hand_scroll: ScrollContainer = ScrollContainer.new()

	hand_scroll.custom_minimum_size = Vector2(0, 120)
	root.add_child(hand_scroll)

	hand_row = HBoxContainer.new()

	hand_row.add_theme_constant_override(
		"separation",
		-5
	)

	hand_scroll.add_child(hand_row)

	# Кнопки.
	var actions: GridContainer = GridContainer.new()

	actions.columns = 2

	actions.add_theme_constant_override(
		"h_separation",
		5
	)

	actions.add_theme_constant_override(
		"v_separation",
		5
	)

	root.add_child(actions)

	actions.add_child(
		make_button("Добрать", draw_cards)
	)

	actions.add_child(
		make_button("Бито!", finish_round)
	)

	actions.add_child(
		make_button("Забрать", take_cards)
	)

	actions.add_child(
		make_button("Правила", show_rules)
	)


# ==========================================
# ДИАЛОГИ
# ==========================================

func create_dialogs() -> void:
	rules_dialog = AcceptDialog.new()
	rules_dialog.title = "Правила JokerShift"
	rules_dialog.ok_button_text = "Понятно"

	add_child(rules_dialog)

	var rules: Label = make_label(
		"JokerShift — это «Дурак» с особенностями!\n\n"
		+ "🃏 Джокер копирует карту со стола и может переводить.\n\n"
		+ "✦ Метка отбивает любую карту.\n\n"
		+ "♥♦ или ♠♣ могут стать козырями одного цвета.\n\n"
		+ "↪ Перевод — картой того же достоинства.\n\n"
		+ "✨ Упрощение — замени защиту более дешёвой картой.\n\n"
		+ "Побеждает тот, кто первым избавится от карт. "
		+ "Если остались только особые карты — проигрыш.",
		15
	)

	rules.custom_minimum_size = Vector2(280, 355)
	rules_dialog.add_child(rules)

	joker_dialog = ConfirmationDialog.new()
	joker_dialog.title = "Джокер — выбери карту"
	joker_dialog.ok_button_text = "Закрыть"

	add_child(joker_dialog)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(280, 230)

	joker_dialog.add_child(scroll)

	joker_options = VBoxContainer.new()
	scroll.add_child(joker_options)

	result_dialog = AcceptDialog.new()
	result_dialog.title = "JokerShift"
	result_dialog.ok_button_text = "Играть снова"

	add_child(result_dialog)

	result_dialog.confirmed.connect(new_game)


func show_rules() -> void:
	rules_dialog.popup_centered()


# ==========================================
# РАЗМЕР ЭКРАНА
# ==========================================

func adapt_layout() -> void:
	var width: float = get_viewport_rect().size.x

	card_width = clampf(width * 0.19, 54.0, 82.0)
	card_height = card_width * 1.48

	if table_grid != null:
		if width < 550.0:
			table_grid.columns = 2
		else:
			table_grid.columns = 3

	if game_screen != null and game_screen.visible:
		update_ui()


# ==========================================
# НОВАЯ ИГРА
# ==========================================

func new_game() -> void:
	deck.clear()
	player_hand.clear()
	bot_hand.clear()
	table_cards.clear()
	discard_pile.clear()

	attacker = 0
	first_round = true
	bot_takes = false
	finished = false

	selected_index = -1
	selected_pair = -1

	joker_dialog.hide()
	result_dialog.hide()

	for suit in SUITS:
		for rank in range(2, 15):
			deck.append({
				"rank": rank,
				"suit": suit,
				"special": "",
				"joker_color": "",
				"copy_rank": -1,
				"copy_suit": ""
			})

	for joker_color in ["red", "black"]:
		deck.append({
			"rank": 20,
			"suit": "",
			"special": "joker",
			"joker_color": joker_color,
			"copy_rank": -1,
			"copy_suit": ""
		})

	deck.append({
		"rank": 22,
		"suit": "",
		"special": "mark",
		"joker_color": "",
		"copy_rank": -1,
		"copy_suit": ""
	})

	deck.shuffle()

	setup_trump(deck[0])

	draw_to_six(player_hand)
	draw_to_six(bot_hand)

	status_text = "Твой ход! Выбери карту и нажми на стол."

	adapt_layout()
	update_ui()
	pulse(deck_panel)


func setup_trump(card: Dictionary) -> void:
	if is_mark(card):
		trump_mode = "none"
		trump_suit = "НЕТ"

	elif is_joker(card):
		if str(card["joker_color"]) == "red":
			trump_mode = "red"
			trump_suit = "♥ ♦"
		else:
			trump_mode = "black"
			trump_suit = "♠ ♣"

	else:
		trump_mode = "suit"
		trump_suit = str(card["suit"])


func trump_display_name() -> String:
	match trump_mode:
		"none":
			return "БЕЗ\nКОЗЫРЯ"
		"red":
			return "ЧЕРВЫ\nБУБНЫ"
		"black":
			return "ПИКИ\nТРЕФЫ"
		_:
			match trump_suit:
				"♥":
					return "ЧЕРВЫ"
				"♦":
					return "БУБНЫ"
				"♠":
					return "ПИКИ"
				"♣":
					return "ТРЕФЫ"
				_:
					return "НЕТ"


func update_trump_symbol() -> void:
	if trump_icon_row == null:
		return
	clear_children(trump_icon_row)
	var suits_to_draw: Array[String] = []
	match trump_mode:
		"red":
			suits_to_draw = ["♥", "♦"]
		"black":
			suits_to_draw = ["♠", "♣"]
		"none":
			suits_to_draw = ["mark"]
		_:
			suits_to_draw = [trump_suit]

	for suit in suits_to_draw:
		var icon: SuitIcon = SuitIcon.new()
		icon.name = "TrumpSuit"
		icon.suit = suit
		icon.ink = Color("#D82E57") if suit == "♥" or suit == "♦" else Color("#F5E8FF")
		if suit == "mark":
			icon.ink = GOLD
		icon.custom_minimum_size = Vector2(36, 44)
		trump_icon_row.add_child(icon)


func draw_to_six(hand: Array) -> void:
	while hand.size() < 6 and not deck.is_empty():
		hand.append(deck.pop_back())


# ==========================================
# СВОЙСТВА КАРТ
# ==========================================

func is_joker(card: Dictionary) -> bool:
	return str(card.get("special", "")) == "joker"


func is_mark(card: Dictionary) -> bool:
	return str(card.get("special", "")) == "mark"


func is_special(card: Dictionary) -> bool:
	return is_joker(card) or is_mark(card)


func card_rank(card: Dictionary) -> int:
	if is_mark(card):
		return 100

	if is_joker(card):
		return int(card.get("copy_rank", -1))

	return int(card["rank"])


func card_suit(card: Dictionary) -> String:
	if is_mark(card):
		return ""

	if is_joker(card):
		return str(card.get("copy_suit", ""))

	return str(card["suit"])


func rank_name(rank: int) -> String:
	if rank < 2 or rank > 14:
		return "?"

	return str(RANKS[rank - 2])


func card_name(card: Dictionary) -> String:
	if is_mark(card):
		return "МЕТКА"

	if is_joker(card):
		var name: String = "Красный джокер"

		if str(card["joker_color"]) == "black":
			name = "Чёрный джокер"

		if card_rank(card) == 100:
			return name + " → Метка"

		if card_rank(card) >= 2:
			return (
				name
				+ " → "
				+ rank_name(card_rank(card))
				+ card_suit(card)
			)

		return name

	return (
		rank_name(card_rank(card))
		+ card_suit(card)
	)


func is_trump(card: Dictionary) -> bool:
	var suit: String = card_suit(card)

	match trump_mode:
		"none":
			return false

		"red":
			return suit == "♥" or suit == "♦"

		"black":
			return suit == "♠" or suit == "♣"

		_:
			return suit == trump_suit


func copy_joker(
	joker: Dictionary,
	target: Dictionary
) -> Dictionary:
	var result: Dictionary = joker.duplicate(true)

	result["copy_rank"] = card_rank(target)
	result["copy_suit"] = card_suit(target)

	return result


func reset_joker(card: Dictionary) -> Dictionary:
	if not is_joker(card):
		return card

	var result: Dictionary = card.duplicate(true)

	result["copy_rank"] = -1
	result["copy_suit"] = ""

	return result


# ==========================================
# ПРАВИЛА ЗАЩИТЫ
# ==========================================

func can_beat(
	card: Dictionary,
	target: Dictionary
) -> bool:
	if is_mark(card):
		return true

	if is_joker(card) and card_rank(card) == 100:
		return true

	if card_rank(target) == 100:
		return false

	if is_joker(card):
		return (
			is_trump(target)
			and card_rank(card) == card_rank(target)
			and card_suit(card) == card_suit(target)
		)

	if is_trump(card) and is_trump(target):
		return card_rank(card) > card_rank(target)

	if is_trump(card):
		return true

	if is_trump(target):
		return false

	return (
		card_suit(card) == card_suit(target)
		and card_rank(card) > card_rank(target)
	)


func round_limit() -> int:
	return 8 if first_round else 10


func unbeaten_pair() -> int:
	for i in range(table_cards.size()):
		if table_cards[i]["defense"].is_empty():
			return i

	return -1


func all_defended() -> bool:
	return unbeaten_pair() == -1


func table_has_rank(rank: int) -> bool:
	for pair in table_cards:
		if card_rank(pair["attack"]) == rank:
			return true

		if not pair["defense"].is_empty():
			if card_rank(pair["defense"]) == rank:
				return true

	return false


func can_transfer() -> bool:
	if table_cards.is_empty():
		return false

	if table_cards.size() >= round_limit():
		return false

	for pair in table_cards:
		if not pair["defense"].is_empty():
			return false

	return true


func economy_cost(card: Dictionary) -> int:
	if is_mark(card):
		return 1000

	if is_joker(card):
		return 500

	var cost: int = card_rank(card)

	if is_trump(card):
		cost += 100

	return cost


# ==========================================
# НАЖАТИЯ И ПЕРЕТАСКИВАНИЕ
# ==========================================

func select_card(index: int) -> void:
	if finished:
		return

	if index < 0 or index >= player_hand.size():
		return

	selected_index = index

	status_text = (
		"Выбрана "
		+ card_name(player_hand[index])
		+ ". Нажми на стол."
	)

	update_ui()


func field_pressed() -> void:
	if selected_index >= 0:
		play_hand_card(
			selected_index,
			"field",
			-1
		)


func table_card_pressed(
	role: String,
	pair_index: int
) -> void:
	if selected_index >= 0:
		play_hand_card(
			selected_index,
			role,
			pair_index
		)

	elif role == "attack" and attacker == 1:
		selected_pair = pair_index

		status_text = (
			"Выбрана атака. "
			+ "Теперь выбери карту из руки."
		)

		update_ui()


func play_hand_card(
	index: int,
	role: String,
	pair_index: int
) -> void:
	if finished:
		return

	if index < 0 or index >= player_hand.size():
		return

	var card: Dictionary = player_hand[index]
	selected_index = index

	if table_cards.is_empty():
		if attacker == 0:
			player_attack(index)
		return

	if attacker == 0:
		if is_joker(card):
			show_joker_choices("throw", index, -1)
		else:
			player_throw(index, card)
		return

	if role == "defense":
		if is_joker(card):
			show_joker_choices(
				"replace",
				index,
				pair_index
			)
		else:
			player_replace(
				index,
				pair_index,
				card
			)
		return

	if role == "attack" and pair_index >= 0:
		selected_pair = pair_index

	var target_pair: int = selected_pair

	if (
		target_pair < 0
		or target_pair >= table_cards.size()
	):
		target_pair = unbeaten_pair()

	if is_joker(card):
		if (
			can_transfer()
			and bot_hand.size() >= table_cards.size() + 1
		):
			show_joker_choices(
				"transfer",
				index,
				target_pair
			)
		else:
			show_joker_choices(
				"defend",
				index,
				target_pair
			)
		return

	if can_transfer() and table_has_rank(card_rank(card)):
		player_transfer(index, card)

	elif target_pair >= 0:
		player_defend(
			index,
			target_pair,
			card
		)


# ==========================================
# ДЖОКЕР
# ==========================================

func table_targets() -> Array:
	var targets: Array = []

	for pair in table_cards:
		targets.append(pair["attack"])

		if not pair["defense"].is_empty():
			targets.append(pair["defense"])

	return targets


func joker_action_valid(
	card: Dictionary,
	action: String,
	pair_index: int
) -> bool:
	if action == "throw":
		return (
			card_rank(card) != 100
			and table_has_rank(card_rank(card))
			and table_cards.size() < round_limit()
		)

	if action == "transfer":
		return (
			can_transfer()
			and bot_hand.size() >= table_cards.size() + 1
			and card_rank(card) != 100
			and table_has_rank(card_rank(card))
		)

	if (
		pair_index < 0
		or pair_index >= table_cards.size()
	):
		return false

	var pair: Dictionary = table_cards[pair_index]

	if action == "defend":
		return (
			pair["defense"].is_empty()
			and can_beat(card, pair["attack"])
		)

	if action == "replace":
		return (
			not pair["defense"].is_empty()
			and can_beat(card, pair["attack"])
			and economy_cost(card) < economy_cost(pair["defense"])
		)

	return false


func show_joker_choices(
	action: String,
	index: int,
	pair_index: int
) -> void:
	if index < 0 or index >= player_hand.size():
		return

	pending_joker_action = action
	pending_joker_index = index
	pending_pair_index = pair_index

	clear_children(joker_options)

	var count: int = 0
	var seen: Array = []

	for target in table_targets():
		var key: String = (
			str(card_rank(target))
			+ card_suit(target)
		)

		if seen.has(key):
			continue

		seen.append(key)

		var copied: Dictionary = copy_joker(
			player_hand[index],
			target
		)

		if not joker_action_valid(
			copied,
			action,
			pair_index
		):
			continue

		var button: Button = make_button(
			"Копировать " + card_name(target),
			choose_joker.bind(target.duplicate(true))
		)

		joker_options.add_child(button)
		count += 1

	if count == 0 and action == "transfer":
		show_joker_choices(
			"defend",
			index,
			pair_index
		)
		return

	if count == 0:
		status_text = (
			"Нет подходящей карты для копирования."
		)
		update_ui()
		return

	joker_dialog.popup_centered(
		Vector2i(320, 300)
	)


func choose_joker(target: Dictionary) -> void:
	joker_dialog.hide()

	if (
		pending_joker_index < 0
		or pending_joker_index >= player_hand.size()
	):
		return

	var copied: Dictionary = copy_joker(
		player_hand[pending_joker_index],
		target
	)

	if not joker_action_valid(
		copied,
		pending_joker_action,
		pending_pair_index
	):
		return

	match pending_joker_action:
		"throw":
			player_throw(
				pending_joker_index,
				copied
			)

		"transfer":
			player_transfer(
				pending_joker_index,
				copied
			)

		"defend":
			player_defend(
				pending_joker_index,
				pending_pair_index,
				copied
			)

		"replace":
			player_replace(
				pending_joker_index,
				pending_pair_index,
				copied
			)


# ==========================================
# АТАКА ИГРОКА
# ==========================================

func player_attack(index: int) -> void:
	if attacker != 0:
		return

	if not table_cards.is_empty():
		return

	var card: Dictionary = player_hand[index]

	if is_special(card):
		status_text = (
			"Джокер и метка не начинают атаку."
		)
		update_ui()
		return

	player_hand.remove_at(index)

	table_cards.append({
		"attack": card,
		"defense": {}
	})

	selected_index = -1

	status_text = "Компьютер отбивается..."
	update_ui()

	bot_defend()


# ==========================================
# ЗАЩИТА ИГРОКА
# ==========================================

func player_defend(
	index: int,
	pair_index: int,
	card: Dictionary
) -> void:
	if attacker != 1:
		return

	if (
		pair_index < 0
		or pair_index >= table_cards.size()
	):
		return

	if not table_cards[pair_index]["defense"].is_empty():
		return

	if not can_beat(
		card,
		table_cards[pair_index]["attack"]
	):
		status_text = (
			"Эта карта не отбивает атаку."
		)
		update_ui()
		return

	player_hand.remove_at(index)
	table_cards[pair_index]["defense"] = card

	selected_index = -1
	selected_pair = -1

	status_text = "Отбито!"
	update_ui()

	if all_defended():
		bot_throw()


# ==========================================
# УПРОЩЕНИЕ
# ==========================================

func player_replace(
	index: int,
	pair_index: int,
	card: Dictionary
) -> void:
	if attacker != 1:
		return

	if (
		pair_index < 0
		or pair_index >= table_cards.size()
	):
		return

	var pair: Dictionary = table_cards[pair_index]

	if pair["defense"].is_empty():
		return

	var old_card: Dictionary = pair["defense"]

	if not can_beat(card, pair["attack"]):
		status_text = (
			"Новая карта не отбивает атаку."
		)

	elif economy_cost(card) >= economy_cost(old_card):
		status_text = (
			"Новая карта не экономнее старой."
		)

	else:
		table_cards[pair_index]["defense"] = card
		player_hand[index] = reset_joker(old_card)

		selected_index = -1

		status_text = (
			"Упрощение! Старая карта вернулась в руку."
		)

	update_ui()


# ==========================================
# ПОДКИДЫВАНИЕ
# ==========================================

func player_throw(
	index: int,
	card: Dictionary
) -> void:
	if attacker != 0:
		return

	if table_cards.is_empty():
		return

	if not bot_takes and not all_defended():
		status_text = "Компьютер ещё отбивается."
		update_ui()
		return

	if table_cards.size() >= round_limit():
		status_text = "Лимит карт на столе."
		update_ui()
		return

	if (
		card_rank(card) == 100
		or not table_has_rank(card_rank(card))
	):
		status_text = (
			"Нельзя подкинуть эту карту."
		)
		update_ui()
		return

	player_hand.remove_at(index)

	table_cards.append({
		"attack": card,
		"defense": {}
	})

	selected_index = -1

	status_text = "Карта подкинута!"
	update_ui()

	if not bot_takes:
		bot_defend()


# ==========================================
# ПЕРЕВОД
# ==========================================

func player_transfer(
	index: int,
	card: Dictionary
) -> void:
	if attacker != 1:
		return

	if not can_transfer():
		return

	if (
		card_rank(card) == 100
		or not table_has_rank(card_rank(card))
		or bot_hand.size() < table_cards.size() + 1
	):
		status_text = "Перевод невозможен."
		update_ui()
		return

	player_hand.remove_at(index)

	table_cards.append({
		"attack": card,
		"defense": {}
	})

	attacker = 0
	selected_index = -1
	selected_pair = -1

	status_text = (
		"Перевод! Компьютер защищается."
	)

	update_ui()
	bot_defend()


# ==========================================
# ЛОГИКА БОТА
# ==========================================

func bot_cost(card: Dictionary) -> int:
	return economy_cost(card)


func bot_matching_card(index: int) -> Dictionary:
	var card: Dictionary = bot_hand[index]

	if is_mark(card):
		return {}

	if not is_joker(card):
		if table_has_rank(card_rank(card)):
			return card

		return {}

	for target in table_targets():
		if card_rank(target) == 100:
			continue

		var copied: Dictionary = copy_joker(
			card,
			target
		)

		if table_has_rank(card_rank(copied)):
			return copied

	return {}


func bot_try_transfer() -> bool:
	if attacker != 0:
		return false

	if not can_transfer():
		return false

	if player_hand.size() < table_cards.size() + 1:
		return false

	var best_index: int = -1
	var best_card: Dictionary = {}
	var best_cost: int = 9999

	for i in range(bot_hand.size()):
		var candidate: Dictionary = bot_matching_card(i)

		if candidate.is_empty():
			continue

		if bot_cost(candidate) < best_cost:
			best_index = i
			best_card = candidate
			best_cost = bot_cost(candidate)

	if best_index == -1:
		return false

	if randi_range(1, 100) > 45:
		return false

	bot_hand.remove_at(best_index)

	table_cards.append({
		"attack": best_card,
		"defense": {}
	})

	attacker = 1
	selected_pair = -1

	status_text = (
		"Компьютер перевёл! Защищайся."
	)

	update_ui()
	return true


func bot_defend() -> void:
	if bot_takes:
		status_text = (
			"Компьютер забирает. "
			+ "Подкинь или нажми «Бито!»."
		)
		update_ui()
		return

	if bot_try_transfer():
		return

	while true:
		var pair_index: int = unbeaten_pair()

		if pair_index == -1:
			break

		var attack_card: Dictionary = (
			table_cards[pair_index]["attack"]
		)

		var best_index: int = -1
		var best_card: Dictionary = {}
		var best_cost: int = 9999

		for i in range(bot_hand.size()):
			var candidate: Dictionary = bot_hand[i]
			var possibilities: Array = []

			if is_joker(candidate):
				for target in table_targets():
					possibilities.append(
						copy_joker(candidate, target)
					)
			else:
				possibilities.append(candidate)

			for test_card in possibilities:
				if can_beat(test_card, attack_card):
					var cost: int = bot_cost(test_card)

					if cost < best_cost:
						best_index = i
						best_card = test_card
						best_cost = cost

		if best_index == -1:
			if bot_hand.size() < 6 and not deck.is_empty():
				draw_to_six(bot_hand)
				continue

			bot_takes = true

			status_text = (
				"Компьютер забирает! "
				+ "Подкинь или нажми «Бито!»."
			)

			update_ui()
			return

		bot_hand.remove_at(best_index)

		table_cards[pair_index]["defense"] = (
			best_card
		)

	status_text = (
		"Компьютер отбился. "
		+ "Подкинь или нажми «Бито!»."
	)

	update_ui()


func bot_throw() -> void:
	if attacker != 1:
		return

	if not all_defended():
		return

	if (
		table_cards.size() >= round_limit()
		or player_hand.is_empty()
	):
		status_text = "Нажми «Бито!»."
		update_ui()
		return

	var best_index: int = -1
	var best_card: Dictionary = {}
	var best_cost: int = 9999

	for i in range(bot_hand.size()):
		var candidate: Dictionary = bot_matching_card(i)

		if candidate.is_empty():
			continue

		if bot_cost(candidate) < best_cost:
			best_index = i
			best_card = candidate
			best_cost = bot_cost(candidate)

	if best_index == -1:
		status_text = (
			"Компьютеру нечего подкинуть. "
			+ "Нажми «Бито!»."
		)
		update_ui()
		return

	if randi_range(1, 100) > 70:
		status_text = (
			"Компьютер больше не подкидывает. "
			+ "Нажми «Бито!»."
		)
		update_ui()
		return

	bot_hand.remove_at(best_index)

	table_cards.append({
		"attack": best_card,
		"defense": {}
	})

	selected_pair = table_cards.size() - 1

	status_text = (
		"Компьютер подкинул "
		+ card_name(best_card)
	)

	update_ui()


func bot_attack() -> void:
	draw_to_six(bot_hand)

	var best_index: int = -1

	for i in range(bot_hand.size()):
		if is_special(bot_hand[i]):
			continue

		if best_index == -1:
			best_index = i

		elif (
			card_rank(bot_hand[i])
			< card_rank(bot_hand[best_index])
		):
			best_index = i

	if best_index == -1:
		check_winner()

		if finished:
			return

		attacker = 0

		status_text = (
			"Компьютер пропускает ход. Твой ход!"
		)

		update_ui()
		return

	var card: Dictionary = bot_hand[best_index]

	bot_hand.remove_at(best_index)

	table_cards.append({
		"attack": card,
		"defense": {}
	})

	attacker = 1
	selected_pair = 0
	bot_takes = false

	status_text = (
		"Компьютер атакует: "
		+ card_name(card)
	)

	update_ui()


# ==========================================
# ДОБОР
# ==========================================

func draw_cards() -> void:
	if finished:
		return

	if deck.is_empty():
		status_text = "Колода закончилась."

	elif player_hand.size() >= 6:
		status_text = "У тебя уже 6 карт."

	else:
		var before: int = player_hand.size()

		draw_to_six(player_hand)

		status_text = (
			"Добрано карт: %d"
			% (player_hand.size() - before)
		)

		pulse(deck_panel)

	update_ui()


# ==========================================
# ЗАБРАТЬ
# ==========================================

func take_cards() -> void:
	if finished:
		return

	if attacker != 1 or table_cards.is_empty():
		return

	for pair in table_cards:
		player_hand.append(
			reset_joker(pair["attack"])
		)

		if not pair["defense"].is_empty():
			player_hand.append(
				reset_joker(pair["defense"])
			)

	table_cards.clear()

	draw_to_six(player_hand)
	draw_to_six(bot_hand)

	first_round = false
	selected_index = -1
	selected_pair = -1
	attacker = 1
	bot_takes = false

	check_winner()

	if finished:
		return

	status_text = (
		"Ты забрал карты. Ход компьютера."
	)

	update_ui()
	bot_attack()


# ==========================================
# БИТО
# ==========================================

func finish_round() -> void:
	if finished:
		return

	if table_cards.is_empty():
		return

	if bot_takes:
		for pair in table_cards:
			bot_hand.append(
				reset_joker(pair["attack"])
			)

			if not pair["defense"].is_empty():
				bot_hand.append(
					reset_joker(pair["defense"])
				)

		table_cards.clear()

		bot_takes = false
		attacker = 0

	elif all_defended():
		for pair in table_cards:
			discard_pile.append(pair["attack"])

			if not pair["defense"].is_empty():
				discard_pile.append(
					pair["defense"]
				)

		table_cards.clear()

		if attacker == 0:
			draw_to_six(player_hand)
			draw_to_six(bot_hand)
			attacker = 1

		else:
			draw_to_six(bot_hand)
			draw_to_six(player_hand)
			attacker = 0

	else:
		status_text = (
			"Сначала отбей все карты "
			+ "или забери их."
		)

		update_ui()
		return

	draw_to_six(player_hand)
	draw_to_six(bot_hand)

	first_round = false
	selected_index = -1
	selected_pair = -1

	check_winner()

	if finished:
		return

	if attacker == 0:
		status_text = "Твой ход!"
	else:
		status_text = "Ход компьютера."

	update_ui()

	if attacker == 1:
		bot_attack()


# ==========================================
# ПОБЕДА
# ==========================================

func only_special(hand: Array) -> bool:
	if hand.is_empty():
		return false

	for card in hand:
		if not is_special(card):
			return false

	return true


func check_winner() -> void:
	if finished:
		return

	if not deck.is_empty():
		return

	if not table_cards.is_empty():
		return

	var result: String = ""

	if only_special(player_hand) and only_special(bot_hand):
		result = "Ничья! У обоих особые карты."

	elif only_special(player_hand):
		result = (
			player_nick
			+ ", ты проиграл! "
			+ "Остались особые карты."
		)

	elif only_special(bot_hand):
		result = (
			player_nick
			+ ", ты победил!"
		)

	elif player_hand.is_empty() and bot_hand.is_empty():
		result = "Ничья!"

	elif player_hand.is_empty():
		result = (
			player_nick
			+ ", ты победил!"
		)

	elif bot_hand.is_empty():
		result = "Компьютер победил!"

	if result.is_empty():
		return

	finished = true

	result_dialog.dialog_text = result
	result_dialog.popup_centered()


# ==========================================
# СОЗДАНИЕ КАРТ НА ЭКРАНЕ
# ==========================================

func make_card_view(
	card: Dictionary,
	role: String,
	hand_index: int,
	pair_index: int
) -> GameCard:
	var view: GameCard = GameCard.new()

	view.game = self
	view.card = card.duplicate(true)
	view.role = role
	view.hand_index = hand_index
	view.pair_index = pair_index

	view.custom_minimum_size = Vector2(
		card_width,
		card_height
	)

	var background: Color = Color("#FFF8FF")
	var border: Color = Color("#8D50BC")

	if (
		role == "hand"
		and hand_index == selected_index
	):
		background = Color("#E4C6FF")
		border = Color.WHITE

	view.add_theme_stylebox_override(
		"normal",
		make_style(background, border, 9)
	)

	view.add_theme_stylebox_override(
		"hover",
		make_style(
			Color("#F1DCFF"),
			Color.WHITE,
			9
		)
	)

	view.add_theme_stylebox_override(
		"pressed",
		make_style(
			Color("#E4C6FF"),
			Color.WHITE,
			9
		)
	)

	if role == "hand":
		view.pressed.connect(
			select_card.bind(hand_index)
		)

	else:
		view.pressed.connect(
			table_card_pressed.bind(
				role,
				pair_index
			)
		)

	return view


# ==========================================
# ОБНОВЛЕНИЕ ИНТЕРФЕЙСА
# ==========================================

func update_ui() -> void:
	if game_screen == null:
		return

	if not game_screen.visible:
		return

	bot_label.text = (
		"КОМПЬЮТЕР · %d карт"
		% bot_hand.size()
	)

	player_label.text = (
		"%s · %d карт"
		% [
			player_nick,
			player_hand.size()
		]
	)

	deck_label.text = "%d карт" % deck.size()
	trump_label.text = trump_display_name()
	update_trump_symbol()

	deck_panel.visible = not deck.is_empty()
	status_label.text = status_text

	clear_children(table_grid)

	# Пустой стол.
	if table_cards.is_empty():
		var empty_button: Button = make_button(
			"НАЖМИ СЮДА\nДЛЯ ХОДА",
			field_pressed
		)

		empty_button.custom_minimum_size = Vector2(
			135,
			90
		)

		table_grid.add_child(empty_button)

	# Карты на столе.
	for i in range(table_cards.size()):
		var pair: Dictionary = table_cards[i]

		var column: VBoxContainer = VBoxContainer.new()

		column.add_theme_constant_override(
			"separation",
			3
		)

		var attack_card: GameCard = make_card_view(
			pair["attack"],
			"attack",
			-1,
			i
		)

		column.add_child(attack_card)

		if pair["defense"].is_empty():
			var defense_target: Button = make_button(
				"↓ Защита",
				table_card_pressed.bind(
					"attack",
					i
				)
			)

			defense_target.custom_minimum_size = Vector2(
				card_width,
				35
			)

			column.add_child(defense_target)

		else:
			var defense_card: GameCard = make_card_view(
				pair["defense"],
				"defense",
				-1,
				i
			)

			column.add_child(defense_card)

		table_grid.add_child(column)

		animate_in(
			column,
			minf(float(i) * 0.035, 0.15)
		)

	# Карты игрока.
	clear_children(hand_row)

	for i in range(player_hand.size()):
		var hand_card: GameCard = make_card_view(
			player_hand[i],
			"hand",
			i,
			-1
		)

		hand_row.add_child(hand_card)

		animate_in(
			hand_card,
			minf(float(i) * 0.025, 0.15)
		)
