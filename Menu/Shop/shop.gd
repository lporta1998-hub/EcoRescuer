class_name ShopMenu
extends Control
## Shop: spend the coins earned from collectibles.
##  - Personaggi: unlock characters (Pg.price).
##  - Potenziamenti: player buffs, bought up to 5 times (each level makes
##    them stronger) and switched on/off.
##  - Sfide: enemy buffs that make levels harder and raise the coins earned,
##    also with 5 levels.
## Buffs are defined in Progress.BUFFS; characters in the list below.

const CHARACTERS: Array[Pg] = [
	preload("res://Resources/Characters/Labra.tres"),
	preload("res://Resources/Characters/Ranger.tres"),
	preload("res://Resources/Characters/Nerd.tres"),
	preload("res://Resources/Characters/Boarman.tres"),
	preload("res://Resources/Characters/Mira.tres"),
	preload("res://Resources/Characters/Silvano.tres"),
	preload("res://Resources/Characters/ECO-9.tres"),
]
const COIN_ICON := preload("res://Collectibles/Assets/Sprites/coin.png")
const LOCK_ICON := preload("res://Menu/Shop/lock.png")
const TITLE_FONT := preload("res://Menu/Font/Bleeding_Cowboys.ttf")
const BACKGROUND := preload("res://Menu/Background/control.tscn")

const GREEN := Color(0.65, 0.95, 0.3)
const RED := Color(1.0, 0.45, 0.4)
const GOLD := Color(1.0, 0.83, 0.3)
const GREY := Color(0.7, 0.7, 0.72)

const TABS := [
	{"id": "character", "title": "Personaggi"},
	{"id": "player", "title": "Potenziamenti"},
	{"id": "enemy", "title": "Sfide"},
]

## Scene to go back to (main menu or character select).
static var return_scene := "res://main_menu.tscn"

var _tab := "character"
var _coins_label: Label
var _message: Label
var _summary: Label
var _scroll: ScrollContainer
var _row: HBoxContainer
var _tab_buttons := {}
var _cards := {}  # item id -> {"item": Dictionary, "button": Button, "icon": TextureRect, "lock": TextureRect, "card": Control}
var _scroll_at_press := 0


func _ready() -> void:
	_build()
	_show_tab("character")
	Progress.coins_changed.connect(func(_c): _refresh())


static func open_from(tree: SceneTree, from_scene: String) -> void:
	return_scene = from_scene
	tree.change_scene_to_file("res://Menu/Shop/shop.tscn")


# --- Items ---------------------------------------------------------------

func _items(kind: String) -> Array:
	var items := []
	if kind == "character":
		for pg in CHARACTERS:
			items.append({"id": Progress.character_id(pg), "kind": kind, "title": pg.title,
					"desc": pg.shop_description, "price": pg.price, "icon": pg.icon, "pg": pg})
	else:
		for id in Progress.buff_ids(kind):
			var b: Dictionary = Progress.BUFFS[id]
			items.append({"id": id, "kind": kind, "title": b.title, "desc": "",
					"icon": load(b.icon), "reward": b.get("reward", 0.0)})
	return items


func _owned(item: Dictionary) -> bool:
	if item.kind == "character":
		return Progress.is_unlocked(item.pg)
	return Progress.owns_buff(item.id)


# --- UI ------------------------------------------------------------------

func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(BACKGROUND.instantiate())

	var dim := ColorRect.new()
	dim.color = Color(0, 0.12, 0.09, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var title := Label.new()
	title.text = "Negozio"
	title.add_theme_font_override("font", TITLE_FONT)
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_left = -250
	title.offset_right = 250
	title.offset_top = 10
	title.offset_bottom = 84
	add_child(title)

	var back := _make_button("Back", 30)
	back.position = Vector2(48, 30)
	back.custom_minimum_size = Vector2(125, 52)
	back.pressed.connect(_on_back_pressed)
	add_child(back)

	# Coin counter, top right
	var wallet := HBoxContainer.new()
	wallet.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	wallet.offset_left = -260
	wallet.offset_right = -48
	wallet.offset_top = 36
	wallet.offset_bottom = 84
	wallet.alignment = BoxContainer.ALIGNMENT_END
	wallet.add_theme_constant_override("separation", 10)
	var coin := TextureRect.new()
	coin.texture = COIN_ICON
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.custom_minimum_size = Vector2(34, 40)
	_coins_label = _make_label("0", 34)
	wallet.add_child(coin)
	wallet.add_child(_coins_label)
	add_child(wallet)

	# Tabs
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 12)
	tabs.set_anchors_preset(Control.PRESET_CENTER_TOP)
	tabs.offset_left = -330
	tabs.offset_right = 330
	tabs.offset_top = 92
	tabs.offset_bottom = 136
	add_child(tabs)
	for t in TABS:
		var b := _make_button(t.title, 22)
		b.custom_minimum_size = Vector2(190, 44)
		b.pressed.connect(func():
			SFXManager.play_sfx(preload("res://Audio/SFX/Eco/ui_tab.wav"))
			_show_tab(t.id))
		tabs.add_child(b)
		_tab_buttons[t.id] = b

	# Cards (scrolls sideways if they don't fit)
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.offset_top = 146
	_scroll.offset_bottom = -78
	_scroll.offset_left = 24
	_scroll.offset_right = -24
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.add_child(center)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 16)
	_row.mouse_filter = Control.MOUSE_FILTER_PASS
	center.add_child(_row)

	_summary = _make_label("", 20)
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary.add_theme_color_override("font_color", GOLD)
	_summary.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_summary.offset_left = -400
	_summary.offset_right = 400
	_summary.offset_top = -76
	_summary.offset_bottom = -48
	add_child(_summary)

	_message = _make_label("", 20)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_message.offset_left = -420
	_message.offset_right = 420
	_message.offset_top = -46
	_message.offset_bottom = -16
	add_child(_message)


func _show_tab(kind: String) -> void:
	_tab = kind
	for id in _tab_buttons:
		var b: Button = _tab_buttons[id]
		var on: bool = id == kind
		b.add_theme_stylebox_override("normal", _button_style(Color(0.2, 0.45, 0.25, 0.9) if on else Color(0, 0, 0, 0.35)))
	for child in _row.get_children():
		child.queue_free()
	_cards.clear()
	for item in _items(kind):
		_row.add_child(_make_card(item))
	_scroll.scroll_horizontal = 0
	_show_message("", Color.WHITE)
	_refresh()


func _make_card(item: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(196, 300 if item.kind == "character" else 370)
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.6) if item.kind != "enemy" else Color(0.2, 0.02, 0.04, 0.65)
	style.set_border_width_all(4)
	style.border_color = Color(1, 1, 1, 0.85) if item.kind != "enemy" else Color(1.0, 0.55, 0.5, 0.9)
	style.set_corner_radius_all(16)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_child(box)

	var portrait := Control.new()
	portrait.custom_minimum_size = Vector2(0, 100 if item.kind == "character" else 76)
	portrait.mouse_filter = Control.MOUSE_FILTER_PASS
	var icon := TextureRect.new()
	icon.texture = item.icon
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if item.kind == "character":
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	else:  # 16px icons: draw them at 4x, centred
		icon.set_anchors_preset(Control.PRESET_CENTER)
		icon.offset_left = -32
		icon.offset_right = 32
		icon.offset_top = -32
		icon.offset_bottom = 32
	portrait.add_child(icon)
	var lock := TextureRect.new()
	lock.texture = LOCK_ICON
	lock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	lock.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	lock.set_anchors_preset(Control.PRESET_CENTER)
	lock.offset_left = -26
	lock.offset_right = 26
	lock.offset_top = -26
	lock.offset_bottom = 26
	lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock.visible = item.kind == "character"
	portrait.add_child(lock)
	box.add_child(portrait)

	var name_label := _make_label(item.title, 24)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(name_label)

	var pips: Control = null
	if item.kind != "character":
		pips = Control.new()
		pips.custom_minimum_size = Vector2(0, 22)
		pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pips.draw.connect(_draw_pips.bind(pips, item.id))
		box.add_child(pips)

	var desc := _make_label(item.desc, 15)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(168, 0)
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc.max_lines_visible = 4  # never push the price button off the card
	desc.clip_text = true
	box.add_child(desc)

	var reward: Label = null
	if item.get("reward", 0.0) > 0.0:
		reward = _make_label("", 17)
		reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		reward.add_theme_color_override("font_color", GOLD)
		box.add_child(reward)

	var button := _make_button("", 22)
	button.custom_minimum_size = Vector2(0, 50)
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.expand_icon = false
	button.add_theme_constant_override("icon_max_width", 20)
	button.button_down.connect(func(): _scroll_at_press = _scroll.scroll_horizontal)
	button.pressed.connect(_on_card_pressed.bind(item, card))
	box.add_child(button)

	# Buffs: on/off switch under the upgrade button.
	var toggle: Button = null
	if item.kind != "character":
		toggle = _make_button("", 18)
		toggle.custom_minimum_size = Vector2(0, 40)
		toggle.mouse_filter = Control.MOUSE_FILTER_PASS
		toggle.button_down.connect(func(): _scroll_at_press = _scroll.scroll_horizontal)
		toggle.pressed.connect(_on_toggle_pressed.bind(item))
		box.add_child(toggle)

	_cards[item.id] = {"item": item, "button": button, "icon": icon, "lock": lock, "card": card,
			"desc": desc, "pips": pips, "reward": reward, "toggle": toggle}
	return card


func _refresh() -> void:
	_coins_label.text = str(Progress.coins)
	for id in _cards:
		var c: Dictionary = _cards[id]
		var item: Dictionary = c.item
		var button: Button = c.button
		var owned := _owned(item)
		if item.kind == "character":
			c.lock.visible = not owned
			c.icon.modulate = Color.WHITE if owned else Color(0.35, 0.35, 0.4)
		else:
			c.icon.modulate = Color.WHITE if owned else Color(0.6, 0.6, 0.65)
		button.remove_theme_color_override("font_color")
		button.remove_theme_color_override("font_hover_color")
		button.remove_theme_color_override("font_disabled_color")
		if item.kind != "character":
			_refresh_buff_card(c)
		elif not owned:
			button.text = " %d" % item.price
			button.icon = COIN_ICON
			button.disabled = false
			var col := Color.WHITE if Progress.can_afford(item.price) else RED
			button.add_theme_color_override("font_color", col)
			button.add_theme_color_override("font_hover_color", col)
		else:
			button.text = "Posseduto" if item.price > 0 else "Gratis"
			button.icon = null
			button.disabled = true
			button.add_theme_color_override("font_disabled_color", GREEN)
	match _tab:
		"enemy":
			var bonus := roundi((Progress.coin_multiplier() - 1.0) * 100.0)
			_summary.text = "Bonus monete con le sfide attive: +%d%%" % bonus if bonus > 0 \
					else "Attiva le sfide per rendere i livelli più difficili e guadagnare più monete."
		"player":
			_summary.text = "Ogni potenziamento si compra fino a 5 volte: ogni livello lo rende più forte."
		_:
			_summary.text = ""


func _refresh_buff_card(c: Dictionary) -> void:
	var id: String = c.item.id
	var lvl := Progress.buff_level(id)
	var on := Progress.is_active(id)
	var maxed := Progress.is_max_level(id)
	var button: Button = c.button
	c.icon.modulate = Color.WHITE if lvl > 0 else Color(0.6, 0.6, 0.65)
	c.pips.queue_redraw()
	if lvl == 0:
		c.desc.text = Progress.effect_text(id, 1)
	elif maxed:
		c.desc.text = Progress.effect_text(id, lvl)
	else:
		c.desc.text = "%s\n→ %s" % [Progress.effect_text(id, lvl), Progress.effect_text(id, lvl + 1)]
	if c.reward:
		c.reward.text = "+%d%% monete" % roundi(Progress.reward_at(id, maxi(lvl, 1)) * 100.0)
		c.reward.modulate.a = 1.0 if on or lvl == 0 else 0.5
	if maxed:
		button.text = "MAX"
		button.icon = null
		button.disabled = true
		button.add_theme_color_override("font_disabled_color", GOLD)
	else:
		var price := Progress.next_price(id)
		button.text = " %d" % price
		button.icon = COIN_ICON
		button.disabled = false
		var col := Color.WHITE if Progress.can_afford(price) else RED
		button.add_theme_color_override("font_color", col)
		button.add_theme_color_override("font_hover_color", col)
	var toggle: Button = c.toggle
	toggle.visible = lvl > 0
	toggle.text = "ATTIVO" if on else "SPENTO"
	toggle.add_theme_color_override("font_color", GREEN if on else GREY)
	toggle.add_theme_color_override("font_hover_color", GREEN if on else GREY)


## Five level pips (filled up to the bought level) plus "Lv 2/5".
func _draw_pips(pips: Control, id: String) -> void:
	var lvl := Progress.buff_level(id)
	var on := Progress.is_active(id)
	var fill := (GREEN if Progress.BUFFS[id].kind == "player" else Color(1.0, 0.5, 0.45)) if on else GREY
	var font := get_theme_default_font()
	var label := "Lv %d/%d" % [lvl, Progress.MAX_BUFF_LEVEL]
	var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	var r := 6.0
	var gap := 4.0
	var total := Progress.MAX_BUFF_LEVEL * (r * 2.0 + gap) + 6.0 + lw
	var x := (pips.size.x - total) / 2.0 + r
	var y := pips.size.y / 2.0
	for i in Progress.MAX_BUFF_LEVEL:
		pips.draw_circle(Vector2(x, y), r, Color(0, 0, 0, 0.7))
		if i < lvl:
			pips.draw_circle(Vector2(x, y), r - 1.5, fill)
		else:
			pips.draw_arc(Vector2(x, y), r - 1.5, 0, TAU, 16, Color(1, 1, 1, 0.35), 1.5, true)
		x += r * 2.0 + gap
	var tx := x - r + 2.0
	pips.draw_string_outline(font, Vector2(tx, y + 5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color(0, 0, 0, 0.8))
	pips.draw_string(font, Vector2(tx, y + 5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)


func _make_label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	return label


## Same look as the other menu buttons (white border, dark when pressed).
func _make_button(text: String, font_size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_stylebox_override("normal", _button_style(Color(0, 0, 0, 0)))
	b.add_theme_stylebox_override("hover", _button_style(Color(0.337, 0.337, 0.337)))
	b.add_theme_stylebox_override("pressed", _button_style(Color(0.106, 0.106, 0.106)))
	b.add_theme_stylebox_override("disabled", _button_style(Color(0, 0, 0, 0.3)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


func _button_style(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_border_width_all(5)
	s.border_blend = true
	s.set_corner_radius_all(16)
	s.shadow_size = 5
	s.shadow_offset = Vector2(0, -2)
	s.content_margin_left = 12
	s.content_margin_right = 12
	return s


# --- Actions -------------------------------------------------------------

func _on_card_pressed(item: Dictionary, card: Control) -> void:
	# A finger drag that scrolled the cards is not a tap on this card.
	if absi(_scroll.scroll_horizontal - _scroll_at_press) > 8:
		return
	if item.kind == "character" and _owned(item):
		return
	var price: int = item.price if item.kind == "character" else Progress.next_price(item.id)
	if price < 0:
		return  # buff already at max level
	var bought := Progress.buy_character(item.pg) if item.kind == "character" else Progress.buy_buff(item.id)
	if bought:
		SFXManager.play_sfx(preload("res://Audio/SFX/Eco/ui_buy.wav"))
		if item.kind == "character":
			_show_message("%s sbloccato! Sceglilo in selezione personaggio." % item.title, GREEN)
		else:
			var lvl := Progress.buff_level(item.id)
			_show_message("%s livello %d: %s. È attivo." % [item.title, lvl, Progress.effect_text(item.id, lvl)], GREEN)
		card.pivot_offset = card.size / 2.0
		var t := create_tween()
		t.tween_property(card, "scale", Vector2(1.08, 1.08), 0.1)
		t.tween_property(card, "scale", Vector2.ONE, 0.15)
	else:
		SFXManager.play_sfx(preload("res://Audio/SFX/Eco/ui_denied.wav"))
		_show_message("Ti mancano %d monete: raccogli oggetti nei livelli!" % (price - Progress.coins), RED)
		card.pivot_offset = card.size / 2.0
		var t := create_tween()
		for r in [0.04, -0.04, 0.025, 0.0]:
			t.tween_property(card, "rotation", r, 0.05)
	_refresh()


func _on_toggle_pressed(item: Dictionary) -> void:
	if absi(_scroll.scroll_horizontal - _scroll_at_press) > 8 or not Progress.owns_buff(item.id):
		return
	var on := not Progress.is_active(item.id)
	Progress.set_buff_active(item.id, on)
	SFXManager.play_sfx(preload("res://Audio/SFX/Eco/ui_on.wav") if on else preload("res://Audio/SFX/Eco/ui_off.wav"))
	_show_message("%s %s." % [item.title, "attivato" if on else "spento"], GREEN if on else GREY)
	_refresh()


func _show_message(text: String, color: Color) -> void:
	_message.text = text
	_message.add_theme_color_override("font_color", color)


func _on_back_pressed() -> void:
	SFXManager.play_sfx(preload("res://Audio/SFX/Eco/ui_back.wav"))
	get_tree().change_scene_to_file(return_scene)
