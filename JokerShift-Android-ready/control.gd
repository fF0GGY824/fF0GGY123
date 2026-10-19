
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
# Old defenses returned to the defender's hand can still be thrown
# against in this round. Store their ranks, not just visible cards.
var replaced_throw_ranks: Array[int] = []

var trump_mode: String = "suit"
var trump_suit: String = ""

# 0 = лёгкий, 1 = средний, 2 = сложный
var bot_difficulty: int = 1

# 0 = игрок атакует, 1 = бот атакует
var attacker: int = 0
var first_round: bool = true
var bot_takes: bool = false
var finished: bool = false

var player_nick: String = "Игрок"
var selected_index: int = -1
var selected_pair: int = -1
var status_text: String = ""
# Cache UI visual state to avoid reconstructing every card on status changes.
var last_table_visual_key: String = ""
var last_hand_visual_key: String = ""
var last_trump_visual_key: String = ""

var menu_screen: Control
var game_screen: Control
var nick_input: LineEdit
var difficulty_select: OptionButton
var avatar_dialog: FileDialog
var avatar_preview: TextureRect
var avatar_game: TextureRect
var avatar_placeholder_menu: Label
var avatar_placeholder_game: Label
var avatar_texture: Texture2D

const AVATAR_SAVE_PATH = "user://avatar.png"
const PROFILE_SAVE_PATH = "user://profile.cfg"
const MAX_AVATAR_FILE_BYTES: int = 8 * 1024 * 1024
const MAX_AVATAR_SIDE: int = 384

var rules_dialog: AcceptDialog
var result_dialog: AcceptDialog
var joker_dialog: ConfirmationDialog
var joker_options: VBoxContainer

var enemy_backs: HBoxContainer
var enemy_back_scroll: ScrollContainer
var motion_layer: Control
var animation_busy: bool = false
var animation_serial: int = 0
var animation_enabled: bool = true
var last_enemy_visual_key: String = ""
var remembered_table_faces: Dictionary = {}

var bot_label: Label
var player_label: Label
var deck_label: Label
var discard_label: Label
var trump_label: Label
var trump_icon_row: HBoxContainer
var status_label: Label

var table_grid: GridContainer
var hand_row: HBoxContainer
var hand_scroll: ScrollContainer
var deck_panel: PanelContainer
var field_panel: GameField
var battle_layout: GridContainer
var deck_info: HBoxContainer
var battle_scroll: ScrollContainer
var hand_actions_layout: GridContainer
var landscape_mode: bool = false
var slot_width: float = 78.0
var slot_height: float = 132.0

var card_width: float = 74.0
var card_height: float = 110.0

var pending_joker_action: String = ""
var pending_joker_index: int = -1
var pending_pair_index: int = -1
var pending_slot_id: int = -1


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

		var center: Vector2 = Vector2(size.x * 0.5, size.y * (0.55 if card_icon else 0.5))
		var r: float = minf(size.x * 0.29, size.y * (0.19 if card_icon else 0.36))
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
			# Show the suit or Mark copied onto the played Joker.
			if game.card_rank(card) == 100:
				icon.suit = "mark"
				icon.ink = Color("#8732C8")
			elif game.card_rank(card) >= 2 and not game.card_suit(card).is_empty():
				icon.suit = game.card_suit(card)
				icon.ink = (
					Color("#D82E57")
					if icon.suit == "♥" or icon.suit == "♦"
					else Color("#251530")
				)
			else:
				icon.suit = "joker"
				icon.ink = Color("#D82E57") if str(card.get("joker_color", "")) == "red" else Color("#251530")
		add_child(icon)
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

		# A second, smaller vector suit in the upper-right corner
		# makes suits identifiable even on compact portrait cards.
		var corner: SuitIcon = SuitIcon.new()
		corner.name = "SuitCorner"
		corner.suit = str(game.card_suit(card))
		if corner.suit.is_empty():
			corner.suit = icon.suit
		corner.ink = (
			Color("#D82E57")
			if corner.suit == "♥" or corner.suit == "♦"
			else Color("#251530")
		)
		if corner.suit == "joker" or corner.suit == "mark":
			corner.ink = icon.ink
		corner.anchor_left = 1.0
		corner.anchor_right = 1.0
		corner.anchor_top = 0.0
		corner.anchor_bottom = 0.0
		corner.offset_left = -23.0
		corner.offset_right = -3.0
		corner.offset_top = 3.0
		corner.offset_bottom = 24.0
		add_child(corner)

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
			if game.card_rank(card) == 100:
				ink = Color("#8732C8")
			elif game.card_rank(card) >= 2:
				ink = (
					Color("#D82E57")
					if game.card_suit(card) == "♥" or game.card_suit(card) == "♦"
					else Color("#251530")
				)
			elif str(card.get("joker_color", "")) == "red":
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

		# A readable suit name under the vector icon. No playing-card
		# characters are needed from the system font.
		if not game.is_special(card):
			var caption: String = game.suit_short_name(suit)
			var caption_size: int = maxi(9, int(11.0 * factor))
			var caption_width: float = font.get_string_size(
				caption,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				caption_size
			).x
			draw_string(
				font,
				Vector2(maxf(2.0, (size.x - caption_width) * 0.5), size.y - 7.0),
				caption,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				caption_size,
				ink
			)

		if game.is_joker(card):
			var subtitle: String = "ДЖОКЕР"

			if game.card_rank(card) == 100:
				subtitle = "→ МЕТКА"
			elif game.card_rank(card) >= 2:
				subtitle = (
					"→ "
					+ game.rank_name(game.card_rank(card))
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

	func _can_drop_data(_position: Vector2, data: Variant) -> bool:
		if role == "hand" or typeof(data) != TYPE_DICTIONARY:
			return false
		if data.get("type", "") != "hand_card":
			return false
		var slot_id: int = game.slot_for_pair(pair_index)
		return game.can_drop_on_slot(int(data.get("index", -1)), slot_id)

	func _drop_data(_position: Vector2, data: Variant) -> void:
		game.place_in_slot(
			int(data["index"]),
			game.slot_for_pair(pair_index)
		)


# ==========================================
# ИГРОВОЕ ПОЛЕ
# ==========================================

# Each square of the 5x2 table is an actual touch and drag target.
class TableSlot extends Control:
	var game
	var slot_id: int = 0
	var hover: bool = false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(_on_hover.bind(true))
		mouse_exited.connect(_on_hover.bind(false))

	func _on_hover(active: bool) -> void:
		hover = active
		queue_redraw()

	func _draw() -> void:
		if game == null:
			return
		if game.selected_index < 0 or game.selected_index >= game.player_hand.size():
			return
		if not game.can_drop_on_slot(game.selected_index, slot_id):
			return
		var color: Color = game.GOLD if hover else game.VIOLET
		draw_rect(Rect2(Vector2.ZERO, size), color, false, 2.0)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				game.place_selected_on_slot(slot_id)
				accept_event()

	func _can_drop_data(_position: Vector2, data: Variant) -> bool:
		return (
			typeof(data) == TYPE_DICTIONARY
			and data.get("type", "") == "hand_card"
			and game.can_drop_on_slot(int(data.get("index", -1)), slot_id)
		)

	func _drop_data(_position: Vector2, data: Variant) -> void:
		game.place_in_slot(int(data["index"]), slot_id)


class GameField extends PanelContainer:
	var game

	# Drops are handled by individual TableSlot nodes, not the entire field.
	func _can_drop_data(_position: Vector2, _data: Variant) -> bool:
		return false


# ==========================================
# ЗАПУСК
# ==========================================

func _ready() -> void:
	randomize()
	load_profile()
	load_saved_avatar()

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


func make_card_back(width: float = 49.0, height: float = 66.0) -> PanelContainer:
	var back: PanelContainer = PanelContainer.new()
	back.custom_minimum_size = Vector2(width, height)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_theme_stylebox_override(
		"panel", make_style(Color("#51218C"), Color("#E2B6FF"), 9)
	)
	var symbol: Label = make_label("✦\nJS", 13, GOLD)
	symbol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(symbol)
	return back


func refresh_enemy_backs() -> void:
	if enemy_backs == null:
		return
	var key: String = str(bot_hand.size()) + "|" + str(snapped(card_width, 1.0))
	if key == last_enemy_visual_key:
		return
	last_enemy_visual_key = key
	clear_children(enemy_backs)
	var back_width: float = clampf(card_width * 0.62, 32.0, 58.0)
	for i in range(bot_hand.size()):
		var back: PanelContainer = make_card_back(back_width, back_width * 1.34)
		back.name = "EnemyBack_%d" % i
		enemy_backs.add_child(back)


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

# Profile and avatar stay local on the phone/computer.
# A native file picker is available on Android 10+ and desktop OSes.
func make_style_avatar_box(side: int) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(side, side)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.add_theme_stylebox_override(
		"panel",
		make_style(Color("#381957"), GOLD, 14)
	)
	return panel


func create_avatar_holder(side: int, is_menu: bool) -> Control:
	var holder: Control = Control.new()
	holder.custom_minimum_size = Vector2(side, side)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.clip_contents = true
	var picture: TextureRect = TextureRect.new()
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(picture)
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var placeholder: Label = make_label("JS", 21, GOLD)
	placeholder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(placeholder)
	placeholder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	if is_menu:
		avatar_preview = picture
		avatar_placeholder_menu = placeholder
	else:
		avatar_game = picture
		avatar_placeholder_game = placeholder
	refresh_avatar_views()
	return holder


func refresh_avatar_views() -> void:
	if avatar_preview != null:
		avatar_preview.texture = avatar_texture
	if avatar_game != null:
		avatar_game.texture = avatar_texture
	if avatar_placeholder_menu != null:
		avatar_placeholder_menu.visible = avatar_texture == null
	if avatar_placeholder_game != null:
		avatar_placeholder_game.visible = avatar_texture == null


func load_profile() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(PROFILE_SAVE_PATH) != OK:
		return
	player_nick = str(config.get_value("player", "nickname", "Игрок"))
	bot_difficulty = clampi(int(config.get_value("game", "difficulty", 1)), 0, 2)


func save_profile() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("player", "nickname", player_nick)
	config.set_value("game", "difficulty", bot_difficulty)
	config.save(PROFILE_SAVE_PATH)


func on_difficulty_changed(index: int) -> void:
	bot_difficulty = clampi(index, 0, 2)
	save_profile()


func load_saved_avatar() -> void:
	if not FileAccess.file_exists(AVATAR_SAVE_PATH):
		return
	var img: Image = Image.new()
	if img.load(AVATAR_SAVE_PATH) == OK and not img.is_empty():
		avatar_texture = ImageTexture.create_from_image(img)


func open_avatar_picker() -> void:
	if avatar_dialog != null:
		avatar_dialog.popup_centered_ratio(0.85)


func on_avatar_file_selected(path: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		OS.alert("Не удалось открыть фото. Выбери JPG или PNG.", "JokerShift")
		return
	if file.get_length() > MAX_AVATAR_FILE_BYTES:
		OS.alert("Фото слишком большое (максимум 8 МБ).", "JokerShift")
		return
	var data: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	var img: Image = Image.new()
	var ext: String = path.get_extension().to_lower()
	var err: Error = ERR_FILE_UNRECOGNIZED
	match ext:
		"png":
			err = img.load_png_from_buffer(data)
		"jpg", "jpeg":
			err = img.load_jpg_from_buffer(data)
		"webp":
			err = img.load_webp_from_buffer(data)
	if err != OK or img.is_empty():
		OS.alert("Не удалось прочитать изображение. Подходит JPG, PNG или WebP.", "JokerShift")
		return
	var longest: int = maxi(img.get_width(), img.get_height())
	if longest > MAX_AVATAR_SIDE:
		var scale_factor: float = float(MAX_AVATAR_SIDE) / float(longest)
		img.resize(
			maxi(1, int(img.get_width() * scale_factor)),
			maxi(1, int(img.get_height() * scale_factor)),
			Image.INTERPOLATE_LANCZOS
		)
	if img.save_png(AVATAR_SAVE_PATH) != OK:
		OS.alert("Не удалось сохранить аватарку.", "JokerShift")
		return
	avatar_texture = ImageTexture.create_from_image(img)
	refresh_avatar_views()


func clear_avatar() -> void:
	avatar_texture = null
	if FileAccess.file_exists(AVATAR_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(AVATAR_SAVE_PATH))
	refresh_avatar_views()


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

	menu_panel.custom_minimum_size = Vector2(310, 485)

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

	# Personal avatar: an image chosen from the device, not an online account.
	var avatar_row: HBoxContainer = HBoxContainer.new()
	avatar_row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(avatar_row)
	var avatar_box: PanelContainer = make_style_avatar_box(68)
	avatar_row.add_child(avatar_box)
	var avatar_view: Control = create_avatar_holder(64, true)
	avatar_box.add_child(avatar_view)

	var avatar_actions: VBoxContainer = VBoxContainer.new()
	avatar_row.add_child(avatar_actions)
	var choose_avatar_button: Button = make_button("Выбрать фото", open_avatar_picker)
	choose_avatar_button.custom_minimum_size = Vector2(166, 43)
	avatar_actions.add_child(choose_avatar_button)
	var reset_avatar_button: Button = make_button("Убрать фото", clear_avatar)
	reset_avatar_button.custom_minimum_size = Vector2(166, 40)
	avatar_actions.add_child(reset_avatar_button)

	nick_input = LineEdit.new()
	nick_input.placeholder_text = "Введи свой ник"
	nick_input.text = player_nick
	nick_input.max_length = 18
	nick_input.custom_minimum_size = Vector2(250, 48)

	nick_input.add_theme_font_size_override(
		"font_size",
		17
	)

	column.add_child(nick_input)

	column.add_child(make_label("СЛОЖНОСТЬ СОПЕРНИКА", 14, GOLD))
	difficulty_select = OptionButton.new()
	difficulty_select.add_item("Лёгкий", 0)
	difficulty_select.add_item("Средний", 1)
	difficulty_select.add_item("Сложный", 2)
	difficulty_select.select(clampi(bot_difficulty, 0, 2))
	difficulty_select.custom_minimum_size = Vector2(270, 44)
	difficulty_select.add_theme_font_size_override("font_size", 17)
	difficulty_select.item_selected.connect(on_difficulty_changed)
	column.add_child(difficulty_select)

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

	bot_difficulty = difficulty_select.selected
	save_profile()
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

	animation_enabled = DisplayServer.get_name() != "headless"
	# Transparent overlay for moving cards. It NEVER intercepts touches.
	motion_layer = Control.new()
	motion_layer.name = "CardMotionLayer"
	motion_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_screen.add_child(motion_layer)
	motion_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Keep the hand and action buttons accessible on short or landscape
	# screens. This prevents the main column from being clipped.
	var screen_scroll: ScrollContainer = ScrollContainer.new()
	screen_scroll.name = "GameScroll"
	screen_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	screen_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	screen_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	screen_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	game_screen.add_child(screen_scroll)

	var margin: MarginContainer = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.custom_minimum_size = Vector2(0, 585)
	screen_scroll.add_child(margin)

	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)

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

	# Visible opponent cards, backs only.
	enemy_back_scroll = ScrollContainer.new()
	enemy_back_scroll.name = "EnemyCards"
	enemy_back_scroll.custom_minimum_size = Vector2(0, 69)
	enemy_back_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_back_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	enemy_back_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(enemy_back_scroll)

	enemy_backs = HBoxContainer.new()
	enemy_backs.name = "EnemyCardBacks"
	enemy_backs.add_theme_constant_override("separation", -12)
	enemy_back_scroll.add_child(enemy_backs)

	# Five slots in each of two rows. Portrait stacks the compact
	# trump/deck information underneath the table; landscape uses a rail.
	battle_layout = GridContainer.new()
	battle_layout.name = "BattleLayout"
	battle_layout.columns = 2
	battle_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	battle_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	battle_layout.add_theme_constant_override("h_separation", 8)
	battle_layout.add_theme_constant_override("v_separation", 6)
	root.add_child(battle_layout)

	field_panel = GameField.new()
	field_panel.name = "BattleField"
	field_panel.game = self
	field_panel.custom_minimum_size = Vector2(280, 225)
	field_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	field_panel.add_theme_stylebox_override(
		"panel", make_style(Color("#1D0E30"), Color("#68379B"), 14)
	)
	battle_layout.add_child(field_panel)

	var field_column: VBoxContainer = VBoxContainer.new()
	field_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	field_column.mouse_filter = Control.MOUSE_FILTER_PASS
	field_column.add_theme_constant_override("separation", 6)
	field_panel.add_child(field_column)

	var field_title: Label = make_label("ИГРОВОЙ СТОЛ · 2 × 5", 13, GOLD)
	field_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field_column.add_child(field_title)

	battle_scroll = ScrollContainer.new()
	battle_scroll.name = "TableScroll"
	battle_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	battle_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	battle_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	battle_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	battle_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	field_column.add_child(battle_scroll)

	var grid_center: CenterContainer = CenterContainer.new()
	grid_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_center.mouse_filter = Control.MOUSE_FILTER_PASS
	battle_scroll.add_child(grid_center)

	table_grid = GridContainer.new()
	table_grid.name = "TableSlots"
	table_grid.columns = 5
	table_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	table_grid.mouse_filter = Control.MOUSE_FILTER_PASS
	table_grid.add_theme_constant_override("h_separation", 6)
	table_grid.add_theme_constant_override("v_separation", 7)
	grid_center.add_child(table_grid)

	# Compact info rail: can sit at the right or below the table.
	deck_info = HBoxContainer.new()
	deck_info.name = "DeckInfo"
	deck_info.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	deck_info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	deck_info.add_theme_constant_override("separation", 12)
	battle_layout.add_child(deck_info)

	var deck_section: VBoxContainer = VBoxContainer.new()
	deck_section.add_theme_constant_override("separation", 4)
	deck_info.add_child(deck_section)
	deck_section.add_child(make_label("КОЛОДА", 12, GOLD))

	deck_panel = PanelContainer.new()
	deck_panel.custom_minimum_size = Vector2(68, 82)
	deck_panel.add_theme_stylebox_override(
		"panel", make_style(Color("#6324A1"), Color("#D9A5FF"), 10)
	)
	deck_section.add_child(deck_panel)

	var deck_art: VBoxContainer = VBoxContainer.new()
	deck_art.add_theme_constant_override("separation", 0)
	deck_panel.add_child(deck_art)
	deck_art.add_child(make_label("✦", 23))
	deck_art.add_child(make_label("JOKER", 10))
	deck_art.add_child(make_label("SHIFT", 10))

	deck_label = make_label("", 12)
	deck_section.add_child(deck_label)
	discard_label = make_label("БИТО: 0", 11, GOLD)
	deck_section.add_child(discard_label)

	var trump_section: VBoxContainer = VBoxContainer.new()
	trump_section.add_theme_constant_override("separation", 4)
	deck_info.add_child(trump_section)
	trump_section.add_child(make_label("КОЗЫРЬ", 12, GOLD))

	trump_icon_row = HBoxContainer.new()
	trump_icon_row.alignment = BoxContainer.ALIGNMENT_CENTER
	trump_icon_row.custom_minimum_size = Vector2(74, 44)
	trump_section.add_child(trump_icon_row)

	trump_label = make_label("", 12, GOLD)
	trump_label.custom_minimum_size = Vector2(74, 29)
	trump_section.add_child(trump_label)

	# Сообщение.
	status_label = make_label("", 13)
	status_label.custom_minimum_size = Vector2(0, 57)
	root.add_child(status_label)

	# Nickname and avatar beside the player's hand.
	var player_row: HBoxContainer = HBoxContainer.new()
	player_row.name = "PlayerInfoRow"
	player_row.alignment = BoxContainer.ALIGNMENT_CENTER
	player_row.custom_minimum_size = Vector2(0, 52)
	player_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	player_row.add_theme_constant_override("separation", 10)
	root.add_child(player_row)

	var player_avatar_box: PanelContainer = make_style_avatar_box(46)
	player_avatar_box.name = "PlayerAvatar"
	player_row.add_child(player_avatar_box)
	player_avatar_box.add_child(create_avatar_holder(42, false))

	player_label = make_label("", 17, GOLD)
	player_label.name = "PlayerNickname"
	# Wrapping this label made it one character wide; its enormous
	# height pushed the hand and buttons below the window.
	player_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	player_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	player_label.custom_minimum_size = Vector2(154, 40)
	player_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	player_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	player_row.add_child(player_label)

	# Landscape: hand and controls share one line; portrait stacks them.
	hand_actions_layout = GridContainer.new()
	hand_actions_layout.name = "HandActionsLayout"
	hand_actions_layout.columns = 2
	hand_actions_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_actions_layout.add_theme_constant_override("h_separation", 12)
	hand_actions_layout.add_theme_constant_override("v_separation", 7)
	root.add_child(hand_actions_layout)

	hand_scroll = ScrollContainer.new()
	hand_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	hand_scroll.name = "HandScroll"
	hand_scroll.custom_minimum_size = Vector2(0, 134)
	hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hand_actions_layout.add_child(hand_scroll)

	hand_row = HBoxContainer.new()

	hand_row.add_theme_constant_override(
		"separation",
		-5
	)

	hand_scroll.add_child(hand_row)

	# Кнопки.
	var actions: GridContainer = GridContainer.new()
	actions.name = "ActionButtons"
	actions.columns = 2

	actions.add_theme_constant_override(
		"h_separation",
		5
	)

	actions.add_theme_constant_override(
		"v_separation",
		5
	)

	actions.size_flags_horizontal = Control.SIZE_SHRINK_END
	hand_actions_layout.add_child(actions)
	# Card ghosts must render above the scrolling table and hands.
	game_screen.move_child(motion_layer, game_screen.get_child_count() - 1)

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
	avatar_dialog = FileDialog.new()
	avatar_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	avatar_dialog.access = FileDialog.ACCESS_FILESYSTEM
	avatar_dialog.use_native_dialog = true
	avatar_dialog.title = "Выбрать аватарку"
	avatar_dialog.filters = PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp;Изображения"])
	avatar_dialog.file_selected.connect(on_avatar_file_selected)
	add_child(avatar_dialog)

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
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	# Portrait: wide table + deck beneath it.
	# Landscape: wide table + compact deck to its right.
	var portrait: bool = viewport_size.y >= viewport_size.x
	landscape_mode = not portrait

	if battle_layout != null:
		battle_layout.columns = 1 if portrait else 2
	if hand_actions_layout != null:
		hand_actions_layout.columns = 1 if portrait else 2
	if deck_info != null:
		deck_info.size_flags_horizontal = (
			Control.SIZE_SHRINK_CENTER if portrait
			else Control.SIZE_SHRINK_END
		)

	var reserved: float = 28.0 if portrait else 214.0
	var table_space: float = maxf(270.0, viewport_size.x - reserved)
	# Exactly 5 visible places per row. Defense overlaps attack
	# inside the same slot instead of producing a third/fourth row.
	card_width = clampf((table_space - 48.0) / 5.0 - 9.0, 42.0, 94.0)
	# Avoid a tall table pushing the hand below the fold in landscape.
	if not portrait and viewport_size.y < 760.0:
		card_width = minf(
			card_width,
			clampf((viewport_size.y - 455.0) / 2.8, 42.0, 94.0)
		)
	card_height = card_width * 1.40
	slot_width = card_width + 9.0
	slot_height = card_height + 26.0

	if field_panel != null:
		field_panel.custom_minimum_size = Vector2(
			slot_width * 5.0 + 4.0 * 6.0 + 16.0,
			slot_height * 2.0 + 7.0 + 48.0
		)

	if table_grid != null:
		table_grid.columns = 5

	last_table_visual_key = ""
	last_hand_visual_key = ""

	if game_screen != null and game_screen.visible:
		update_ui()

# ==========================================
# НОВАЯ ИГРА
# ==========================================

func new_game() -> void:
	last_table_visual_key = ""
	last_hand_visual_key = ""
	replaced_throw_ranks.clear()
	remembered_table_faces.clear()
	last_enemy_visual_key = ""
	animation_serial += 1
	animation_busy = false
	if hand_row != null:
		hand_row.modulate.a = 1.0
	if enemy_backs != null:
		enemy_backs.modulate.a = 1.0
	if table_grid != null:
		table_grid.modulate.a = 1.0
	if motion_layer != null:
		clear_children(motion_layer)
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
	pending_slot_id = -1

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

	attacker = determine_first_attacker()
	if attacker == 1:
		status_text = "У компьютера младший козырь — он ходит первым."
	else:
		status_text = "Твой первый ход: у тебя младший козырь или ничья."

	adapt_layout()
	update_ui()
	pulse(deck_panel)

	if animation_enabled:
		play_deal_animation()
	elif attacker == 1:
		bot_attack()


# First lead is decided by the lowest ordinary trump in either hand.
# Special cards have no ordinary trump rank; ties favor the player.
func lowest_trump_rank(hand: Array) -> int:
	var lowest: int = 999
	for card in hand:
		if is_special(card):
			continue
		if is_trump(card):
			lowest = mini(lowest, card_rank(card))
	return lowest


func determine_first_attacker() -> int:
	var player_lowest: int = lowest_trump_rank(player_hand)
	var bot_lowest: int = lowest_trump_rank(bot_hand)
	if bot_lowest < player_lowest:
		return 1
	return 0


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
	var visual_key: String = trump_mode + "|" + trump_suit
	if visual_key == last_trump_visual_key:
		return
	last_trump_visual_key = visual_key
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


func suit_short_name(suit: String) -> String:
	match suit:
		"♥":
			return "ЧЕРВ"
		"♦":
			return "БУБ"
		"♠":
			return "ПИК"
		"♣":
			return "ТРЕФ"
		_:
			return ""


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

func can_beat(card: Dictionary, target: Dictionary) -> bool:
	# A Joker can copy ANY visible card, including Mark or another Joker.
	# After copying it can cover an attack as a special card.
	if is_mark(card):
		return true
	if is_joker(card):
		return card_rank(card) >= 2

	if card_rank(target) == 100:
		return false
	if is_trump(card) and is_trump(target):
		return card_rank(card) > card_rank(target)
	if is_trump(card):
		return true
	if is_trump(target):
		return false
	return card_suit(card) == card_suit(target) and card_rank(card) > card_rank(target)

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
	if replaced_throw_ranks.has(rank):
		return true
	for pair in table_cards:
		if card_rank(pair["attack"]) == rank:
			return true

		if not pair["defense"].is_empty():
			if card_rank(pair["defense"]) == rank:
				return true

	return false


# A pair can live in any visible square. Old saved/test pairs without
# slot_id fall back to insertion order for backward compatibility.
func slot_for_pair(pair_index: int) -> int:
	if pair_index < 0 or pair_index >= table_cards.size():
		return -1
	return int(table_cards[pair_index].get("slot_id", pair_index))


func pair_at_slot(slot_id: int) -> int:
	if slot_id < 0 or slot_id >= 10:
		return -1
	for i in range(table_cards.size()):
		if slot_for_pair(i) == slot_id:
			return i
	return -1


func free_table_slot(preferred: int = -1) -> int:
	if preferred >= 0 and preferred < 10 and pair_at_slot(preferred) == -1:
		return preferred
	for slot_id in range(10):
		if pair_at_slot(slot_id) == -1:
			return slot_id
	return -1


# Validate potential drops BEFORE showing a drop marker; invalid moves
# leave cards in the player's hand rather than silently moving them.
func can_drop_on_slot(hand_index: int, slot_id: int) -> bool:
	if animation_busy:
		return false
	if finished or hand_index < 0 or hand_index >= player_hand.size():
		return false
	if slot_id < 0 or slot_id >= 10:
		return false
	var card: Dictionary = player_hand[hand_index]
	var pair_index: int = pair_at_slot(slot_id)

	if attacker == 0:
		if pair_index != -1:
			return false
		if table_cards.is_empty():
			return not is_special(card)
		if table_cards.size() >= round_limit():
			return false
		if not bot_takes and not all_defended():
			return false
		# Jokers can copy one of the ranks already on the table.
		return (
			is_joker(card)
			or (card_rank(card) != 100 and table_has_rank(card_rank(card)))
		)

	if pair_index != -1:
		var pair: Dictionary = table_cards[pair_index]
		if pair["defense"].is_empty():
			return is_joker(card) or can_beat(card, pair["attack"])
		return (
			is_joker(card)
			or (
				can_beat(card, pair["attack"])
				and economy_cost(card) < economy_cost(pair["defense"])
			)
		)

	# Translation is deliberately performed by placing an equal-rank
	# card into an EMPTY square, not on top of an attacking card.
	if not can_transfer():
		return false
	if bot_hand.size() < table_cards.size() + 1:
		return false
	if is_joker(card):
		return true
	return card_rank(card) != 100 and table_has_rank(card_rank(card))


func place_selected_on_slot(slot_id: int) -> void:
	if selected_index < 0 or selected_index >= player_hand.size():
		status_text = "Сначала выбери карту из руки."
		update_ui()
		return
	place_in_slot(selected_index, slot_id)


func place_in_slot(hand_index: int, slot_id: int) -> void:
	if not can_drop_on_slot(hand_index, slot_id):
		status_text = "Сюда эту карту положить нельзя."
		update_ui()
		return

	selected_index = hand_index
	var card: Dictionary = player_hand[hand_index]
	var pair_index: int = pair_at_slot(slot_id)

	if attacker == 0:
		if table_cards.is_empty():
			player_attack(hand_index, slot_id)
		elif is_joker(card):
			pending_slot_id = slot_id
			show_joker_choices("throw", hand_index, -1)
		else:
			player_throw(hand_index, card, slot_id)
		return

	if pair_index == -1:
		if is_joker(card):
			pending_slot_id = slot_id
			show_joker_choices("transfer", hand_index, -1)
		else:
			player_transfer(hand_index, card, slot_id)
		return

	if table_cards[pair_index]["defense"].is_empty():
		if is_joker(card):
			show_joker_choices("defend", hand_index, pair_index)
		else:
			player_defend(hand_index, pair_index, card)
	else:
		if is_joker(card):
			show_joker_choices("replace", hand_index, pair_index)
		else:
			player_replace(hand_index, pair_index, card)


func can_transfer() -> bool:
	if table_cards.is_empty():
		return false

	if table_cards.size() >= round_limit():
		return false
	if free_table_slot() == -1:
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
	if finished or animation_busy or index < 0 or index >= player_hand.size():
		return
	selected_index = index
	if attacker == 0:
		status_text = (
			"Карта выбрана. Нажми свободную ячейку для хода."
		)
	else:
		status_text = (
			"На атаку — отбиться; в пустую ячейку — перевести."
		)
	update_ui()


func field_pressed() -> void:
	place_selected_on_slot(free_table_slot())


func table_card_pressed(role: String, pair_index: int) -> void:
	if pair_index < 0 or pair_index >= table_cards.size():
		return
	var slot_id: int = slot_for_pair(pair_index)
	if selected_index >= 0:
		place_selected_on_slot(slot_id)
	elif role == "attack" and attacker == 1:
		selected_pair = pair_index
		status_text = "Выбери карту для защиты и нажми на атаку."
		update_ui()


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
			table_has_rank(card_rank(card))
			and table_cards.size() < round_limit()
		)

	if action == "transfer":
		return (
			can_transfer()
			and bot_hand.size() >= table_cards.size() + 1
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
		status_text = "Джокеру нечего копировать для перевода."
		update_ui()
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
				copied,
				pending_slot_id
			)

		"transfer":
			player_transfer(
				pending_joker_index,
				copied,
				pending_slot_id
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

func player_attack(index: int, slot_id: int = 0) -> void:
	if attacker != 0:
		return

	if not table_cards.is_empty():
		return
	if slot_id < 0 or slot_id >= 10 or pair_at_slot(slot_id) != -1:
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
		"defense": {},
		"slot_id": slot_id
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
		# Replaced defense remains a legal throw-in rank this round,
		# even though the old card physically returns to the hand.
		if not replaced_throw_ranks.has(card_rank(old_card)):
			replaced_throw_ranks.append(card_rank(old_card))
		table_cards[pair_index]["defense"] = card
		player_hand[index] = reset_joker(old_card)
		selected_index = -1
		status_text = (
			"Защита заменена! Бот может подкинуть достоинство старой карты."
		)
		update_ui()
		if all_defended():
			bot_throw()
		return

	update_ui()


# ==========================================
# ПОДКИДЫВАНИЕ
# ==========================================

func player_throw(
	index: int,
	card: Dictionary,
	slot_id: int = -1
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

	if slot_id == -1:
		slot_id = free_table_slot()
	if slot_id < 0 or slot_id >= 10 or pair_at_slot(slot_id) != -1:
		status_text = "Выбери свободную ячейку для подкидывания."
		update_ui()
		return

	if (
		(card_rank(card) == 100 and not is_joker(card))
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
		"defense": {},
		"slot_id": slot_id
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
	card: Dictionary,
	slot_id: int = -1
) -> void:
	if attacker != 1:
		return

	if not can_transfer():
		return

	if (
		(card_rank(card) == 100 and not is_joker(card))
		or not table_has_rank(card_rank(card))
		or bot_hand.size() < table_cards.size() + 1
	):
		status_text = "Перевод невозможен."
		update_ui()
		return

	if slot_id == -1:
		slot_id = free_table_slot()
	if slot_id < 0 or slot_id >= 10 or pair_at_slot(slot_id) != -1:
		status_text = "Для перевода выбери свободную ячейку."
		update_ui()
		return

	player_hand.remove_at(index)

	table_cards.append({
		"attack": card,
		"defense": {},
		"slot_id": slot_id
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
		# Marks and already-copied Jokers are also valid targets.
		var copied: Dictionary = copy_joker(
			card,
			target
		)

		if table_has_rank(card_rank(copied)):
			return copied

	return {}


func bot_try_transfer() -> bool:
	if bot_difficulty == 0:
		# Easy bot does not transfer attacks.
		return false
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

	var transfer_chance: int = 40 if bot_difficulty == 1 else 85
	if randi_range(1, 100) > transfer_chance:
		return false

	bot_hand.remove_at(best_index)

	table_cards.append({
		"attack": best_card,
		"defense": {},
		"slot_id": free_table_slot()
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

	# Even on easy difficulty, the bot tries to defend rather than
	# randomly picking up before looking at its cards.
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
					if bot_difficulty == 0:
						cost = randi_range(0, 999)
					elif bot_difficulty == 2:
						cost += 70 if is_trump(test_card) else 0
						cost += 100 if is_joker(test_card) else 0

					if cost < best_cost:
						best_index = i
						best_card = test_card
						best_cost = cost

		if best_index == -1:
			# One card at a time. Retry this attack after EACH draw.
			# It can draw beyond six when defense requires it.
			if not deck.is_empty():
				bot_hand.append(deck.pop_back())
				status_text = "Компьютер добирает 1 карту для защиты..."
				update_ui()
				fly_back(
					local_ghost_point(deck_panel),
					local_ghost_point(enemy_back_scroll),
					0.27
				)
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
	if free_table_slot() == -1:
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

	var throw_chance: int = 20 if bot_difficulty == 0 else (70 if bot_difficulty == 1 else 100)
	if randi_range(1, 100) > throw_chance:
		status_text = (
			"Компьютер больше не подкидывает. "
			+ "Нажми «Бито!»."
		)
		update_ui()
		return

	bot_hand.remove_at(best_index)

	table_cards.append({
		"attack": best_card,
		"defense": {},
		"slot_id": free_table_slot()
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
	var best_score: int = 99999

	for i in range(bot_hand.size()):
		var candidate: Dictionary = bot_hand[i]
		if is_special(candidate):
			continue

		if bot_difficulty == 0:
			# Easy chooses a random ordinary card.
			if best_index == -1 or randi_range(0, 1) == 0:
				best_index = i
		else:
			var score: int = card_rank(candidate)
			if bot_difficulty == 2:
				score = economy_cost(candidate)
				# Hard favors ranks it can throw again.
				for j in range(bot_hand.size()):
					if i != j and card_rank(bot_hand[j]) == card_rank(candidate):
						score -= 12
			if score < best_score:
				best_index = i
				best_score = score

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
		"defense": {},
		"slot_id": free_table_slot()
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
	if finished or animation_busy:
		return

	if deck.is_empty():
		status_text = "Колода закончилась."

	elif player_hand.size() >= 6:
		status_text = "У тебя уже 6 карт."

	else:
		player_hand.append(deck.pop_back())
		status_text = "Добрана 1 карта."
		pulse(deck_panel)

	update_ui()


# ==========================================
# ЗАБРАТЬ
# ==========================================

func take_cards() -> void:
	if finished or animation_busy:
		return

	if attacker != 1 or table_cards.is_empty():
		return

	var animation_expected: int = animation_serial
	if animation_enabled:
		status_text = "Карты возвращаются в твою руку..."
		update_ui()
		await animate_collection(false)
		if animation_expected != animation_serial:
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
	replaced_throw_ranks.clear()
	remembered_table_faces.clear()

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
	if finished or animation_busy:
		return

	if table_cards.is_empty():
		return

	# Wait for the Bito animation before removing the actual cards.
	if not bot_takes and not all_defended():
		status_text = "Нельзя Бито: не все карты отбиты."
		update_ui()
		return
	var animation_expected: int = animation_serial
	if animation_enabled:
		status_text = (
			"Бот забирает карты..."
			if bot_takes else "Бито! Карты уходят в отбой..."
		)
		update_ui()
		await animate_collection(bot_takes, not bot_takes)
		if animation_expected != animation_serial:
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
		replaced_throw_ranks.clear()
		remembered_table_faces.clear()

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
		replaced_throw_ranks.clear()
		remembered_table_faces.clear()

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
	if finished or not deck.is_empty() or not table_cards.is_empty():
		return
	var result: String = ""
	if player_hand.is_empty() and bot_hand.is_empty():
		result = "Ничья!"
	elif player_hand.is_empty():
		result = player_nick + ", ты победил!"
	elif bot_hand.is_empty():
		result = "Компьютер победил!"
	# A final Joker or Mark is NOT a loss while the opponent attacks.
	elif only_special(player_hand) and attacker == 0:
		result = "Компьютер победил! У тебя остались особые карты."
	elif only_special(bot_hand) and attacker == 1:
		result = player_nick + ", ты победил! У бота остались особые карты."
	if result.is_empty():
		return
	finished = true
	result_dialog.dialog_text = result
	result_dialog.popup_centered()

# ==========================================
# СОЗДАНИЕ КАРТ НА ЭКРАНЕ
# ==========================================

# ==================================================
# CARD ANIMATIONS (no images/textures required)
# ==================================================

func local_ghost_point(control: Control) -> Vector2:
	if control == null or motion_layer == null:
		return Vector2.ZERO
	return control.get_global_rect().get_center() - motion_layer.get_global_rect().position


func fly_back(start: Vector2, finish: Vector2, duration: float = 0.23) -> void:
	if not animation_enabled or motion_layer == null:
		return
	var ghost: PanelContainer = make_card_back(
		maxf(37.0, card_width * 0.60),
		maxf(49.0, card_width * 0.80)
	)
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	motion_layer.add_child(ghost)
	ghost.position = start - ghost.custom_minimum_size * 0.5
	var tween: Tween = create_tween()
	tween.tween_property(
		ghost, "position",
		finish - ghost.custom_minimum_size * 0.5,
		duration
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(ghost, "modulate:a", 0.20, duration)
	tween.tween_callback(ghost.queue_free)


func fly_face(card: Dictionary, start: Vector2, finish: Vector2, duration: float = 0.32) -> void:
	if not animation_enabled or motion_layer == null:
		return
	var ghost: GameCard = make_card_view(card, "ghost", -1, -1)
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.disabled = true
	motion_layer.add_child(ghost)
	ghost.position = start - ghost.custom_minimum_size * 0.5
	var tween: Tween = create_tween()
	tween.tween_property(
		ghost, "position",
		finish - ghost.custom_minimum_size * 0.5,
		duration
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(ghost, "modulate:a", 0.12, duration)
	tween.tween_callback(ghost.queue_free)


# Animated shuffle followed by twelve cards dealt one at a time.
# Logical hands are created immediately so the game state is always
# consistent; gestures are locked while their visual deal completes.
func play_deal_animation() -> void:
	animation_busy = true
	var serial: int = animation_serial
	hand_row.modulate.a = 0.0
	enemy_backs.modulate.a = 0.0
	status_text = "Перемешиваем колоду..."
	update_ui()

	# Small crossing motions depict a shuffle.
	for i in range(5):
		if serial != animation_serial:
			return
		var center: Vector2 = local_ghost_point(deck_panel)
		var direction: float = -1.0 if i % 2 == 0 else 1.0
		fly_back(
			center + Vector2(direction * 19.0, -14.0),
			center + Vector2(-direction * 19.0, 14.0),
			0.19
		)
		await get_tree().create_timer(0.075).timeout

	if serial != animation_serial:
		return
	status_text = "Раздаём карты..."
	update_ui()

	# Six rounds, one card to each side per round.
	for i in range(6):
		if serial != animation_serial:
			return
		var deck_center: Vector2 = local_ghost_point(deck_panel)
		fly_back(deck_center, local_ghost_point(enemy_back_scroll), 0.23)
		await get_tree().create_timer(0.07).timeout
		if serial != animation_serial:
			return
		fly_back(deck_center, local_ghost_point(hand_scroll), 0.23)
		await get_tree().create_timer(0.09).timeout

	if serial != animation_serial:
		return
	hand_row.modulate.a = 1.0
	enemy_backs.modulate.a = 1.0
	animation_busy = false
	status_text = (
		"Первым ходит компьютер."
		if attacker == 1
		else "Твой ход."
	)
	update_ui()
	if attacker == 1:
		bot_attack()


# The table is deliberately not cleared until this animation finishes.
# User input is locked, so Bito cannot be pressed twice.
func animate_collection(to_bot: bool, to_discard: bool = false) -> void:
	if not animation_enabled or motion_layer == null:
		return
	animation_busy = true
	var serial: int = animation_serial
	var destination: Control = (
		deck_panel if to_discard
		else (enemy_back_scroll if to_bot else hand_scroll)
	)
	var finish: Vector2 = local_ghost_point(destination)

	for pair_index in range(table_cards.size()):
		var pair: Dictionary = table_cards[pair_index]
		var slot: int = slot_for_pair(pair_index)
		if slot < 0 or slot >= table_grid.get_child_count():
			continue
		var slot_node: Control = table_grid.get_child(slot) as Control
		var start: Vector2 = local_ghost_point(slot_node)
		fly_face(pair["attack"], start, finish, 0.34)
		if not pair["defense"].is_empty():
			fly_face(
				pair["defense"],
				start + Vector2(8.0, 18.0),
				finish + Vector2(12.0, 0.0),
				0.36
			)

	table_grid.modulate.a = 0.42
	await get_tree().create_timer(0.41).timeout
	if serial != animation_serial:
		return
	table_grid.modulate.a = 1.0
	animation_busy = false


# New played cards slide into their chosen slot. Attacks enter from
# the owner, defenses land diagonally on top of the attack.
func animate_table_card(card_view: GameCard, defense: bool, from_bot: bool) -> void:
	if not animation_enabled:
		return
	var target: Vector2 = card_view.position
	var offset: Vector2
	if defense:
		offset = Vector2(-16.0, 52.0)
	else:
		offset = Vector2(0.0, -88.0 if from_bot else 86.0)
	card_view.position = target + offset
	card_view.modulate.a = 0.45
	var tween: Tween = create_tween()
	tween.tween_property(
		card_view, "position", target, 0.22
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(card_view, "modulate:a", 1.0, 0.22)


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

	refresh_enemy_backs()
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
	discard_label.text = "БИТО: %d" % discard_pile.size()
	trump_label.text = trump_display_name()
	update_trump_symbol()

	deck_panel.visible = not deck.is_empty()
	status_label.text = status_text

	var table_key: String = (
		JSON.stringify(table_cards)
		+ "|" + str(snapped(card_width, 0.1))
		+ "|" + str(selected_index)
		+ "|" + str(attacker)
		+ "|" + str(bot_takes)
	)
	if table_key != last_table_visual_key:
		last_table_visual_key = table_key
		clear_children(table_grid)

		for i in range(10):
			# Every square is a touch target and an actual drop destination.
			var slot: TableSlot = TableSlot.new()
			slot.name = "Slot_%d" % i
			slot.game = self
			slot.slot_id = i
			slot.custom_minimum_size = Vector2(slot_width, slot_height)
			table_grid.add_child(slot)

			var pair_index: int = pair_at_slot(i)
			if pair_index == -1:
				# Decorative empty cell does not block taps or drag-drop.
				var empty_place: PanelContainer = PanelContainer.new()
				empty_place.mouse_filter = Control.MOUSE_FILTER_IGNORE
				empty_place.custom_minimum_size = Vector2(card_width, card_height)
				empty_place.add_theme_stylebox_override(
					"panel",
					make_style(
						Color("#241238"),
						Color("#58377A"),
						9
					)
				)
				slot.add_child(empty_place)
				empty_place.position = Vector2(4, 2)

				if selected_index >= 0 and can_drop_on_slot(selected_index, i):
					var hint: Label = make_label(
						"ХОД" if attacker == 0 else "ПЕРЕВОД",
						10,
						GOLD
					)
					hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
					hint.custom_minimum_size = Vector2(card_width, 30)
					slot.add_child(hint)
					hint.position = Vector2(4, card_height * 0.40)
				continue

			var pair: Dictionary = table_cards[pair_index]
			var attack_card: GameCard = make_card_view(
				pair["attack"], "attack", -1, pair_index
			)
			slot.add_child(attack_card)
			attack_card.position = Vector2.ZERO
			var attack_visual_key: String = "%d:attack" % i
			var attack_signature: String = JSON.stringify(pair["attack"])
			if remembered_table_faces.get(attack_visual_key, "") != attack_signature:
				remembered_table_faces[attack_visual_key] = attack_signature
				animate_table_card(attack_card, false, attacker == 1)

			if pair["defense"].is_empty():
				var defend_button: Button = make_button(
					"↘ ЗАЩИТА", table_card_pressed.bind("attack", pair_index)
				)
				defend_button.custom_minimum_size = Vector2(card_width, 26)
				defend_button.add_theme_font_size_override("font_size", 10)
				slot.add_child(defend_button)
				defend_button.position = Vector2(0, card_height + 1)
			else:
				var defense_card: GameCard = make_card_view(
					pair["defense"], "defense", -1, pair_index
				)
				slot.add_child(defense_card)
				defense_card.position = Vector2(9, 20)
				var defense_visual_key: String = "%d:defense" % i
				var defense_signature: String = JSON.stringify(pair["defense"])
				if remembered_table_faces.get(defense_visual_key, "") != defense_signature:
					remembered_table_faces[defense_visual_key] = defense_signature
					animate_table_card(defense_card, true, attacker == 0)

			animate_in(slot, minf(float(i) * 0.02, 0.16))

	# Карты игрока.
	var hand_key: String = JSON.stringify(player_hand) + "|" + str(selected_index)
	if hand_key != last_hand_visual_key:
		last_hand_visual_key = hand_key
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
