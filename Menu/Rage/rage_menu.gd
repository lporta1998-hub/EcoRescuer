class_name RageMenu
extends Control
## Rage mode setup: pick a map (unlocked in the campaign), a hero you own and
## which permanent perks to use, then play. Same look as the Shop.

const TITLE_FONT := preload("res://Menu/Font/Bleeding_Cowboys.ttf")
const BACKGROUND := preload("res://Menu/Background/control.tscn")
const LOCK_ICON := preload("res://Menu/Shop/lock.png")
const GOLD := Color(1.0, 0.83, 0.3)
const RED := Color(1.0, 0.45, 0.4)
const GREEN := Color(0.65, 0.95, 0.3)
const GREY := Color(0.7, 0.7, 0.72)

## Last choices, kept while the game is open.
static var last_map := ""
static var last_hero := ""

var _map: LevelData
var _hero: Pg
var _use_perks := true
var _map_cards := {}   # level path -> PanelContainer
var _hero_cards := {}  # character id -> PanelContainer
var _perk_box: HFlowContainer
var _perks_toggle: Button
var _press_at := Vector2.INF
## How far (px) a finger may move and still count as a tap.
const TAP_SLOP := 14.0


func _ready() -> void:
	Rage.stop()
	var maps := Rage.maps()
	var heroes := Rage.heroes()
	_map = maps[0]
	for m in maps:
		if m.resource_path == last_map:
			_map = m
	_hero = heroes[0]
	for h in heroes:
		if Progress.character_id(h) == last_hero:
			_hero = h
	_build(maps, heroes)
	_refresh()


func _build(maps: Array[LevelData], heroes: Array[Pg]) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(BACKGROUND.instantiate())
	var dim := ColorRect.new()
	dim.color = Color(0.12, 0.0, 0.02, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var title := _label("Rage mode", 52, RED)
	title.add_theme_font_override("font", TITLE_FONT)
	title.add_theme_constant_override("outline_size", 10)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_left = -300
	title.offset_right = 300
	title.offset_top = 8
	title.offset_bottom = 74
	add_child(title)

	var back := _button("Back", 30)
	back.position = Vector2(48, 24)
	back.custom_minimum_size = Vector2(125, 52)
	back.pressed.connect(func():
		SFXManager.play_sfx(preload("res://Audio/SFX/Eco/ui_back.wav"))
		get_tree().change_scene_to_file("res://main_menu.tscn"))
	add_child(back)

	var best := _label("Record: round %d" % Progress.stat("rage_best_round"), 22, GOLD)
	best.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	best.offset_left = -300
	best.offset_right = -48
	best.offset_top = 32
	best.offset_bottom = 64
	best.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(best)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 84
	scroll.offset_bottom = -84
	scroll.offset_left = 48
	scroll.offset_right = -48
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER  # drag to scroll, no bar
	add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)
	scroll.add_child(col)

	col.add_child(_label("Mappa (sbloccate nella campagna)", 22, Color.WHITE))
	col.add_child(_row_of(maps.map(func(m: LevelData): return _map_card(m))))
	col.add_child(_label("Eroe (solo quelli che hai comprato)", 22, Color.WHITE))
	col.add_child(_row_of(heroes.map(func(h: Pg): return _hero_card(h))))

	var perk_title := HBoxContainer.new()
	perk_title.add_theme_constant_override("separation", 16)
	perk_title.add_child(_label("Potenziamenti permanenti", 22, Color.WHITE))
	_perks_toggle = _button("", 18)
	_perks_toggle.pressed.connect(func():
		_use_perks = not _use_perks
		SFXManager.play_sfx(preload("res://Audio/SFX/Eco/ui_on.wav") if _use_perks else preload("res://Audio/SFX/Eco/ui_off.wav"))
		_refresh())
	perk_title.add_child(_perks_toggle)
	col.add_child(perk_title)
	_perk_box = HFlowContainer.new()
	_perk_box.add_theme_constant_override("h_separation", 8)
	_perk_box.add_theme_constant_override("v_separation", 8)
	col.add_child(_perk_box)

	var help := _label("Round infiniti di nemici, un boss ogni %d round. I potenziamenti del negozio che trovi a terra valgono solo qui: cuori, scudo e magnete fino a fine partita, velocità e forza fino a fine round." % Rage.BOSS_EVERY, 15, Color(0.9, 0.9, 0.9))
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(help)

	var play := _button("Gioca", 32)
	play.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	play.offset_left = -248
	play.offset_right = -48
	play.offset_top = -76
	play.offset_bottom = -16
	play.add_theme_stylebox_override("normal", _style(Color(0.55, 0.1, 0.1, 0.9)))
	play.pressed.connect(_on_play)
	add_child(play)


func _row_of(cards: Array) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER  # drag to scroll, no bar
	s.custom_minimum_size.y = (cards[0] as Control).custom_minimum_size.y + 12 if not cards.is_empty() else 0
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	for c in cards:
		row.add_child(c)
	s.add_child(row)
	return s


func _map_card(level: LevelData) -> Control:
	var card := _card(Vector2(170, 128))
	var box := card.get_child(0)
	var img := TextureRect.new()
	img.texture = level.preview_image
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.custom_minimum_size = Vector2(150, 80)
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(img)
	box.add_child(_label(level.level_name, 16, Color.WHITE, true))
	card.gui_input.connect(func(e: InputEvent): if _tapped(e): _select_map(level))
	_map_cards[level.resource_path] = card
	return card


func _hero_card(hero: Pg) -> Control:
	var card := _card(Vector2(110, 128))
	var box := card.get_child(0)
	var img := TextureRect.new()
	img.texture = hero.icon
	img.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.custom_minimum_size = Vector2(80, 80)
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(img)
	box.add_child(_label(hero.title, 16, Color.WHITE, true))
	card.gui_input.connect(func(e: InputEvent): if _tapped(e): _select_hero(hero))
	_hero_cards[Progress.character_id(hero)] = card
	return card


func _card(min_size: Vector2) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = min_size
	# PASS, not STOP: a finger drag on a card must reach the ScrollContainer
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	return card


## A tap or click on a card: released close to where it was pressed (a
## finger that dragged to scroll the row doesn't select anything).
func _tapped(e: InputEvent) -> bool:
	if not (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT):
		return false  # touches arrive as emulated mouse clicks too
	if e.pressed:
		_press_at = e.global_position
		return false
	return e.global_position.distance_to(_press_at) < TAP_SLOP


func _select_map(level: LevelData) -> void:
	SFXManager.play_sfx(preload("res://Audio/SFX/Eco/ui_tab.wav"))
	_map = level
	_refresh()


func _select_hero(hero: Pg) -> void:
	SFXManager.play_sfx(preload("res://Audio/SFX/Eco/ui_tab.wav"))
	_hero = hero
	_refresh()


func _refresh() -> void:
	for path in _map_cards:
		_map_cards[path].add_theme_stylebox_override("panel", _card_style(path == _map.resource_path))
	for id in _hero_cards:
		_hero_cards[id].add_theme_stylebox_override("panel", _card_style(id == Progress.character_id(_hero)))
	_perks_toggle.text = "Attivi" if _use_perks else "Spenti"
	_perks_toggle.add_theme_color_override("font_color", GREEN if _use_perks else GREY)
	for c in _perk_box.get_children():
		c.queue_free()
	var any := false
	for id in Rage.PERKS:
		var lvl := int(Progress.rage_perks.get(id, 0))
		if lvl <= 0:
			continue
		any = true
		var on := _use_perks and not Progress.rage_perks_off.has(id)
		var b := _button("%s Lv%d" % [Rage.PERKS[id].title, lvl], 16)
		b.icon = load(Rage.PERKS[id].icon)
		b.add_theme_constant_override("icon_max_width", 22)
		b.add_theme_color_override("font_color", GREEN if on else GREY)
		b.add_theme_stylebox_override("normal", _style(Color(0.1, 0.3, 0.12, 0.9) if on else Color(0, 0, 0, 0.5)))
		b.disabled = not _use_perks
		b.tooltip_text = Rage.PERKS[id].text
		b.pressed.connect(func():
			Progress.set_rage_perk_on(id, Progress.rage_perks_off.has(id))
			_refresh())
		_perk_box.add_child(b)
	if not any:
		var l := _label("Nessuno ancora: sconfiggi un boss (ogni %d round) per sceglierne uno." % Rage.BOSS_EVERY, 16, GREY)
		_perk_box.add_child(l)
	_perks_toggle.visible = any


func _on_play() -> void:
	SFXManager.play_sfx(preload("res://Audio/SFX/Eco/ui_confirm.wav"))
	last_map = _map.resource_path
	last_hero = Progress.character_id(_hero)
	Rage.start(get_tree(), _map, _hero, _use_perks)


# --- Style ------------------------------------------------------------------------

func _label(text: String, size: int, color: Color, center := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _button(text: String, font_size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_stylebox_override("normal", _style(Color(0, 0, 0, 0.35)))
	b.add_theme_stylebox_override("hover", _style(Color(0.337, 0.337, 0.337)))
	b.add_theme_stylebox_override("pressed", _style(Color(0.106, 0.106, 0.106)))
	b.add_theme_stylebox_override("disabled", _style(Color(0, 0, 0, 0.3)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


func _style(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_border_width_all(4)
	s.border_blend = true
	s.set_corner_radius_all(14)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s


func _card_style(selected: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.35, 0.05, 0.05, 0.85) if selected else Color(0, 0, 0, 0.55)
	s.set_border_width_all(4 if selected else 2)
	s.border_color = GOLD if selected else Color(1, 1, 1, 0.5)
	s.set_corner_radius_all(12)
	s.set_content_margin_all(8)
	return s
