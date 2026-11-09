class_name CodexMenu
extends Control
## Codex: everything the player has found so far.
##  - Traguardi: achievements (Achievements.LIST), with progress.
##  - Nemici: the enemies met in the campaign, with a tip for each.
##  - Dossier: the secret files found, to reread the story.
##  - Statistiche: lifetime counters.
## Built in code, with the same look as the Shop.

const TITLE_FONT := preload("res://Menu/Font/Bleeding_Cowboys.ttf")
const BACKGROUND := preload("res://Menu/Background/control.tscn")
const LOCK_ICON := preload("res://Menu/Shop/lock.png")
const STAR_ICON := preload("res://Menu/Stars/star_full.png")
const DOSSIER_ICON := preload("res://Misc/Story/Art/dossier.png")

const GREEN := Color(0.65, 0.95, 0.3)
const GOLD := Color(1.0, 0.83, 0.3)
const GREY := Color(0.7, 0.7, 0.72)

const TABS := [
	{"id": "achievements", "title": "Traguardi"},
	{"id": "enemies", "title": "Nemici"},
	{"id": "dossiers", "title": "Dossier"},
	{"id": "stats", "title": "Statistiche"},
]

## Enemies of the Codex. `type` is the Story.ENEMIES key (its name, tip and
## first chapter come from there); the others say it themselves.
## `sheet` + `frame` = the first frame of the sprite sheet, used as the icon.
const ENEMIES := [
	{"name": "Inquinatore", "tip": "il soldato semplice della banda: attacca da vicino. Colpiscilo e allontanati.",
		"sheet": "res://Default_Enemy/Assets/Sprites/Bracconiere.png", "frame": 48, "chapter": 0},
	{"name": "Elite", "tip": "un caposquadra più resistente e più forte: tienilo a distanza e non farti circondare.",
		"sheet": "res://EliteEnemy/Assets/Spirtes/BracconiereElite.png", "frame": 48, "chapter": 0},
	{"type": "sprayer", "sheet": "res://Enemies/Sprayer/sheet.png", "frame": 40},
	{"type": "bomber", "sheet": "res://Enemies/Bomber/sheet.png", "frame": 40},
	{"type": "brute", "sheet": "res://Enemies/Brute/sheet.png", "frame": 56},
	{"type": "drone", "sheet": "res://Enemies/Drone/sheet.png", "frame": 32},
	{"name": "MECCA-RIFIUTI", "tip": "l'armatura del Barone dei Rifiuti: carica, lancia barili tossici e chiama rinforzi. Schiva le cariche e colpiscilo quando si ferma.",
		"sheet": "res://Boss/mecca_rifiuti.png", "frame": 128, "boss": true},
]

const STATS := [
	["kills", "Inquinatori sconfitti"],
	["elites", "Elite sconfitti"],
	["boss_kills", "MECCA-RIFIUTI distrutti"],
	["bags", "Sacchi raccolti"],
	["coins", "Monete verdi raccolte"],
	["barrels", "Barili messi in sicurezza"],
	["chests", "Forzieri aperti"],
	["runs_completed", "Livelli completati"],
	["flawless", "Livelli senza danni"],
	["deaths", "Sconfitte"],
	["daily_done", "Sfide del giorno completate"],
	["rage_matches", "Partite in Rage mode"],
	["rage_best_round", "Miglior round in Rage mode"],
	["rage_bosses", "Boss sconfitti in Rage mode"],
]

## Scene to go back to.
static var return_scene := "res://main_menu.tscn"

var _tab_buttons := {}
var _list: VBoxContainer
var _scroll: ScrollContainer
var _summary: Label


func _ready() -> void:
	_build()
	_show_tab("achievements")


static func open_from(tree: SceneTree, from_scene: String) -> void:
	return_scene = from_scene
	tree.change_scene_to_file("res://Menu/Codex/codex.tscn")


# --- UI ------------------------------------------------------------------

func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(BACKGROUND.instantiate())

	var dim := ColorRect.new()
	dim.color = Color(0, 0.12, 0.09, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var title := Label.new()
	title.text = "Codex"
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

	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 12)
	tabs.set_anchors_preset(Control.PRESET_CENTER_TOP)
	tabs.offset_left = -420
	tabs.offset_right = 420
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

	_scroll = ScrollContainer.new()
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.offset_top = 148
	_scroll.offset_bottom = -52
	_scroll.offset_left = 60
	_scroll.offset_right = -60
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	_list.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.add_child(_list)

	_summary = _make_label("", 20)
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary.add_theme_color_override("font_color", GOLD)
	_summary.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_summary.offset_left = -400
	_summary.offset_right = 400
	_summary.offset_top = -46
	_summary.offset_bottom = -14
	add_child(_summary)


func _show_tab(id: String) -> void:
	for t in _tab_buttons:
		var b: Button = _tab_buttons[t]
		b.add_theme_stylebox_override("normal", _button_style(Color(0.2, 0.45, 0.25, 0.9) if t == id else Color(0, 0, 0, 0.35)))
	for child in _list.get_children():
		child.queue_free()
	_scroll.scroll_vertical = 0
	match id:
		"achievements":
			_fill_achievements()
		"enemies":
			_fill_enemies()
		"dossiers":
			_fill_dossiers()
		"stats":
			_fill_stats()


func _fill_achievements() -> void:
	var done := 0
	for a in Achievements.LIST:
		var unlocked := Progress.has_achievement(a.id)
		if unlocked:
			done += 1
		var target := Achievements.target_of(a)
		var value := mini(Achievements.value_of(a), target)
		var right := "+%d monete" % a.reward if unlocked else "%d / %d" % [value, target]
		_list.add_child(_row(STAR_ICON if unlocked else LOCK_ICON, a.title, a.text, right,
				GOLD if unlocked else GREY))
	_summary.text = "Traguardi sbloccati: %d / %d" % [done, Achievements.LIST.size()]


func _fill_enemies() -> void:
	var met := 0
	for e in ENEMIES:
		var info: Dictionary = Story.ENEMIES.get(e.get("type", ""), {})
		var name: String = e.get("name", info.get("name", "?"))
		var tip: String = e.get("tip", info.get("tip", ""))
		if _enemy_met(e):
			met += 1
			var icon := AtlasTexture.new()
			icon.atlas = load(e.sheet)
			icon.region = Rect2(0, 0, e.frame, e.frame)
			_list.add_child(_row(icon, name, tip.substr(0, 1).to_upper() + tip.substr(1), "", Color.WHITE))
		else:
			_list.add_child(_row(LOCK_ICON, "???", "Non l'hai ancora incontrato: continua la campagna.", "", GREY))
	_summary.text = "Nemici incontrati: %d / %d" % [met, ENEMIES.size()]


## True once the player has reached the chapter the enemy first appears in.
func _enemy_met(e: Dictionary) -> bool:
	if e.get("boss", false):
		if Progress.stat("boss_kills") > 0:
			return true
		for ch in Story.chapters():
			if ch.get("boss", false):
				return Progress.is_level_completed(load(ch.level))
		return false
	var first := int(e.get("chapter", -1))
	if first < 0:
		var list := Story.chapters()
		for i in list.size():
			if list[i].get("enemies", {}).has(e.type):
				first = i
				break
	if first < 0:
		return false
	# the player has reached that chapter: it's the first one, or they
	# finished it or the one before
	if first == 0:
		return true
	var list := Story.chapters()
	return Progress.is_level_completed(load(list[first].level)) \
			or Progress.is_level_completed(load(list[first - 1].level))


func _fill_dossiers() -> void:
	var found := 0
	var list := Story.chapters()
	for i in list.size():
		var ch: Dictionary = list[i]
		var level: LevelData = load(ch.level)
		var label := ("Epilogo" if ch.get("epilogue", false) else "Capitolo %d" % (i + 1)) + " · " + String(ch.title)
		if Progress.quest_done(level, "dossier"):
			found += 1
			_list.add_child(_row(DOSSIER_ICON, label, ch.dossier, "", GOLD))
		else:
			_list.add_child(_row(LOCK_ICON, label, "Dossier non ancora trovato: è nascosto in %s." % level.level_name, "", GREY))
	_summary.text = "Dossier trovati: %d / %d" % [found, list.size()]


func _fill_stats() -> void:
	for s in STATS:
		_list.add_child(_row(null, s[1], "", str(Progress.stat(s[0])), Color.WHITE))
	_list.add_child(_row(null, "Stelle", "", "%d / %d" % [Progress.campaign_stars(),
			Story.main_chapters().size() * Progress.MAX_STARS_PER_LEVEL], GOLD))
	_list.add_child(_row(null, "Eroi che hanno completato un livello", "", str(Progress.heroes_won()), Color.WHITE))
	for pg in ShopMenu.CHARACTERS:
		var wins := Progress.wins_with(pg)
		if wins > 0:
			_list.add_child(_row(pg.icon, "Vittorie con %s" % pg.title, "", str(wins), Color.WHITE))
	_summary.text = ""


## One line of the list: icon, title, description and a value on the right.
func _row(icon: Texture2D, title: String, text: String, right: String, color: Color) -> Control:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.55)
	style.set_border_width_all(3)
	style.border_color = Color(color, 0.7)
	style.set_corner_radius_all(12)
	style.content_margin_left = 12
	style.content_margin_right = 16
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(row)
	if icon:
		var tex := TextureRect.new()
		tex.texture = icon
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.custom_minimum_size = Vector2(52, 52)
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(tex)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var t := _make_label(title, 22)
	t.add_theme_color_override("font_color", color)
	col.add_child(t)
	if text != "":
		var d := _make_label(text, 16)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92))
		col.add_child(d)
	if right != "":
		var r := _make_label(right, 22)
		r.add_theme_color_override("font_color", color)
		r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(r)
	return panel


func _make_label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _make_button(text: String, font_size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_stylebox_override("normal", _button_style(Color(0, 0, 0, 0)))
	b.add_theme_stylebox_override("hover", _button_style(Color(0.337, 0.337, 0.337)))
	b.add_theme_stylebox_override("pressed", _button_style(Color(0.106, 0.106, 0.106)))
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


func _on_back_pressed() -> void:
	SFXManager.play_sfx(preload("res://Audio/SFX/Eco/ui_back.wav"))
	get_tree().change_scene_to_file(return_scene)
