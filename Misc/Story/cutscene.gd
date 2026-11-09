class_name Cutscene
extends Control
## Story cutscene: full-screen illustrations with typewriter text.
## Tap / click / Space: finish the line, then the next panel. "Salta" skips.
##   Cutscene.play(get_tree(), Cutscene.INTRO, "res://SelezionePg/Scenes/menu_selezione.tscn")

const ART := "res://Misc/Story/Art/"
const CHARS_PER_SECOND := 45.0

const INTRO := [
	{"image": "01_island", "title": "L'isola", "text": "C'era una volta un'isola verde, piena di boschi, laghi limpidi e cristalli che brillavano nella neve."},
	{"image": "02_polluters", "title": "Gli Inquinatori", "text": "Poi arrivarono gli Inquinatori. Di notte scaricano rifiuti tossici ovunque, e i politici che hanno pagato fanno finta di non vedere."},
	{"image": "03_nexus", "title": "NEXUS", "text": "Dietro di loro c'è NEXUS, un'intelligenza artificiale creata per fare profitto. Ha calcolato che inquinare costa meno di qualsiasi altra cosa."},
	{"image": "04_baron", "title": "Il Barone dei Rifiuti", "text": "Il Barone dei Rifiuti guida la banda e protegge il nucleo di NEXUS nella sua fortezza, in cima alla discarica."},
	{"image": "05_team", "title": "Gli EcoRescuer", "text": "Ma qualcuno ha deciso di reagire: ragazzi coraggiosi, una scienziata, un antico dio della natura e perfino un robot ribelle. Sono gli EcoRescuer, e tu sei uno di loro."},
	{"image": "06_mission", "title": "La missione", "text": "In ogni zona raccogli i sacchi di rifiuti, sconfiggi gli Inquinatori e porta tutto al punto di raccolta. Cerca anche i dossier segreti: sveleranno i piani di NEXUS."},
]

## Shown after the final boss. The last panel's text depends on the dossiers.
const ENDING := [
	{"image": "07_fall", "title": "La caduta", "text": "Il MECCA-RIFIUTI crolla tra le scintille. Il Barone fugge nella notte e il nucleo di NEXUS si spegne per sempre."},
	{"image": "08_healed", "title": "L'isola respira", "text": "Senza più scarichi l'isola torna a respirare: gli alberi ricrescono, il lago torna limpido e i cristalli brillano di nuovo."},
	{"image": "05_team", "title": "Grazie, EcoRescuer!", "text": "{dossiers}"},
]

static var _panels: Array = []
static var _next_scene := "res://main_menu.tscn"
static var _on_done: Callable

var _index := -1
var _last_tap_ms := 0
var _shown := 0.0
var _full_text := ""
var _image: TextureRect
var _title: Label
var _text: Label
var _hint: Label
var _skip: Button


static func play(tree: SceneTree, panels: Array, next_scene: String) -> void:
	_panels = panels
	_next_scene = next_scene
	tree.change_scene_to_file("res://Misc/Story/cutscene.tscn")


## After the epilogue chapter (the Barone caught).
const EPILOGUE := [
	{"image": "04_baron", "title": "Fine della fuga", "text": "Il Barone dei Rifiuti non sale sulla sua nave: la polizia dell'isola lo aspetta sul molo. Il MECCA-RIFIUTI finisce in un impianto di riciclo."},
	{"image": "05_team", "title": "La squadra", "text": "Il porto è pulito e la banda degli Inquinatori non ha più un capo. La squadra EcoRescuer resta di guardia: se qualcuno sporca l'isola, lo saprà."},
]


## The ending, with the last line depending on how many dossiers were found.
static func ending_panels() -> Array:
	var found := Progress.dossiers_found()
	var total := Story.main_chapters().size()
	var last: String
	if found >= total:
		last = "Con tutti i %d dossier come prova, i politici corrotti vengono arrestati e gli Inquinatori non torneranno mai più. L'isola è salva per sempre!" % total
	else:
		last = "L'isola è salva, per ora. Hai trovato %d dossier su %d: trovali tutti per mandare in prigione i politici corrotti e vedere il finale completo." % [found, total]
	var out := []
	for p in ENDING:
		var q: Dictionary = p.duplicate()
		q.text = String(q.text).replace("{dossiers}", last)
		out.append(q)
	# the hook to the post-game chapter
	out.append({"image": "04_baron", "title": "Il Barone è fuggito",
			"text": "Ma il Barone dei Rifiuti è scappato al porto, in attesa di una nave. Nuovo capitolo sbloccato: \"La fuga del Barone\"."})
	return out


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.05, 0.05)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_image = TextureRect.new()
	_image.set_anchors_preset(Control.PRESET_FULL_RECT)
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_image)

	var box := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.06, 0.05, 0.86)
	style.set_corner_radius_all(14)
	style.set_border_width_all(3)
	style.border_color = Color(0.55, 0.85, 0.4, 0.9)
	style.content_margin_left = 26
	style.content_margin_right = 26
	style.content_margin_top = 14
	style.content_margin_bottom = 16
	box.add_theme_stylebox_override("panel", style)
	box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	box.offset_left = 60
	box.offset_right = -60
	box.offset_top = -196
	box.offset_bottom = -28
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	box.add_child(col)
	_title = _label(30, Color(0.65, 0.95, 0.4))
	col.add_child(_title)
	_text = _label(22, Color(0.94, 0.96, 0.92))
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_text)
	_hint = _label(16, Color(0.75, 0.8, 0.75))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(_hint)

	_skip = Button.new()
	_skip.text = "Salta"
	_skip.add_theme_font_size_override("font_size", 22)
	_skip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_skip.offset_left = -150
	_skip.offset_right = -40
	_skip.offset_top = 30
	_skip.offset_bottom = 80
	_skip.pressed.connect(_finish)
	add_child(_skip)

	if _panels.is_empty():
		_panels = INTRO
	_next()


func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	return l


func _process(delta: float) -> void:
	if _shown < _full_text.length():
		_shown = minf(_full_text.length(), _shown + delta * CHARS_PER_SECOND)
		_text.visible_characters = int(_shown)
	_hint.text = ("Tocca per continuare" if _index < _panels.size() - 1 else "Tocca per iniziare") \
			if _shown >= _full_text.length() else ""


func _input(event: InputEvent) -> void:
	var pos := Vector2.INF
	if event is InputEventScreenTouch and event.pressed:
		pos = event.position
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and not DisplayServer.is_touchscreen_available():
		pos = event.position  # on phones the touch above already counts
	if pos == Vector2.INF:
		return
	if _skip.get_global_rect().has_point(pos):
		return  # let "Salta" handle it
	get_viewport().set_input_as_handled()
	# one tap can arrive twice (touch + the mouse click emulated from it)
	var now := Time.get_ticks_msec()
	if now - _last_tap_ms < 150:
		return
	_last_tap_ms = now
	_advance()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_advance()


func _advance() -> void:
	if _shown < _full_text.length():
		_shown = _full_text.length()  # first tap: show the whole line
		_text.visible_characters = -1
		return
	SFXManager.play_sfx(preload("res://Audio/SFX/Eco/ui_page.wav"))
	_next()


func _next() -> void:
	_index += 1
	if _index >= _panels.size():
		_finish()
		return
	var p: Dictionary = _panels[_index]
	_image.texture = load(ART + p.image + ".png")
	_title.text = p.title
	_full_text = p.text
	_text.text = _full_text
	_shown = 0.0
	_text.visible_characters = 0
	_image.modulate.a = 0.0
	create_tween().tween_property(_image, "modulate:a", 1.0, 0.4)


func _finish() -> void:
	set_process(false)
	get_tree().change_scene_to_file(_next_scene)
