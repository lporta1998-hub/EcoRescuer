class_name TutorialMenu
extends CanvasLayer
## "Come si gioca": a step-by-step guide to the game, as an overlay.
##
## It opens on top of whatever is on screen (main menu or pause menu) and
## works while the game is paused. Pages: goal, controls, combat, items,
## stars and secrets, heroes, game modes, tips. Arrows / A-D switch page,
## Esc closes it.
##
## The main menu opens it by itself the first time the player presses Start
## (see `seen()`); after that it's always one tap away from the main menu and
## the pause menu.

signal closed

const SAVE_PATH := "user://tutorial.cfg"
const TITLE_FONT := preload("res://Misc/UI/Fonts/pixel_title_font.tres")

const GREEN := Color(0.65, 0.95, 0.3)
const GOLD := Color(1.0, 0.83, 0.3)
const CYAN := Color(0.55, 0.9, 1.0)
const GREY := Color(0.7, 0.7, 0.72)

const ICON_BAG := preload("res://Collectibles/Assets/Sprites/toxic_waste.png")
const ICON_STATION := preload("res://Misc/LevelExit/recycle_station.png")
const ICON_STAR := preload("res://Menu/Stars/star_full.png")
const ICON_COIN := preload("res://Collectibles/Assets/Sprites/coin.png")
const ICON_CHEST := preload("res://Collectibles/Assets/Sprites/eco_chest.png")
const ICON_CRATE := preload("res://Collectibles/Assets/Sprites/recycling_crate.png")
const ICON_FEATHER := preload("res://Collectibles/Assets/Sprites/Feather.png")
const ICON_BARREL := preload("res://Collectibles/Assets/Sprites/pixellab-oil-barrel-1773596908433.png")
const ICON_BATTERY := preload("res://Collectibles/Assets/Sprites/battery.png")
const ICON_HEART := preload("res://Collectibles/Assets/Sprites/Heart.png")
const ICON_DOSSIER := preload("res://Misc/Story/Art/dossier.png")
const ICON_LOCK := preload("res://Menu/Shop/lock.png")
const ICON_BOOT := preload("res://Menu/Shop/Icons/boot.png")
const ICON_FIST := preload("res://Menu/Shop/Icons/fist.png")
const ICON_BOLT := preload("res://Menu/Shop/Icons/bolt.png")
const ICON_SWORD := preload("res://Menu/Shop/Icons/sword.png")
const ICON_SHIELD := preload("res://Menu/Shop/Icons/shield.png")
const ICON_ARMOR := preload("res://Menu/Shop/Icons/armor.png")
const ICON_RUSH := preload("res://Menu/Shop/Icons/rush.png")
const ICON_MAGNET := preload("res://Menu/Shop/Icons/magnet.png")
const ICON_BROKEN := preload("res://Menu/Shop/Icons/broken_heart.png")

## Marker for the touch-screen drawing in a page's rows.
const DIAGRAM := "diagram"

## The moves of each hero (Pg.title -> text), shown on the Heroes page.
const HERO_MOVES := {
	"Labra": "ATTACCA: combo da vicino.  LATTINA: lancia una lattina riciclata che torna indietro come un boomerang.",
	"Ranger": "ATTACCA: colpo da vicino.  TIRA: scocca una freccia per colpire da lontano.",
	"Nerd": "ATTACCA: fendente ampio che pulisce l'area.  ZAP: una scarica che salta da un nemico all'altro.",
	"Boarman": "ATTACCA: colpo da vicino.  FRANA: onda d'urto a terra con una pioggia di rocce. Ha 4 cuori.",
	"Mira": "POZIONE: lancia pozioni a danno doppio.  BASTONE: colpo da vicino che rompe vasi e casse e respinge i colpi. Solo 2 cuori.",
	"Silvano": "PUGNO: pugni pesanti.  SEMI: una raffica di semi a ventaglio. 4 cuori, ma è lento e il veleno lo ferisce il doppio.",
	"ECO-9": "COLPO: forza enorme.  LASER: raggio che trapassa i nemici e consuma energia. Niente cuori: l'energia cala col tempo, ricaricala con le batterie.",
}

var _page := 0
## On phones and tablets: bigger text and buttons, swipe to change page.
var _mobile := false
var _swipe_from := Vector2.INF
var _swipe_index := -1
var _pages: Array = []
var _margin: MarginContainer
var _panel: PanelContainer
var _title: Label
var _step: Label
var _intro: Label
var _body: MarginContainer
var _scroll: ScrollContainer
var _dots: HBoxContainer
var _prev: Button
var _next: Button
## The animated "swipe" hint under the page (phones, until the first swipe).
var _hint: SwipeHint
var _next_pulse: Tween
## How far the page is pushed sideways while the finger drags it.
var _drag := 0.0


## Opens the guide on top of `parent` (any node of the current scene).
static func open(parent: Node) -> TutorialMenu:
	var t := TutorialMenu.new()
	parent.add_child(t)
	return t


## True once the player has opened the guide at least once.
static func seen() -> bool:
	var cfg := ConfigFile.new()
	return cfg.load(SAVE_PATH) == OK and bool(cfg.get_value("general", "seen", false))


static func _mark_seen() -> void:
	_save_flag("seen")


## True once the player has turned a page by swiping: the hint can go.
static func _swiped() -> bool:
	var cfg := ConfigFile.new()
	return cfg.load(SAVE_PATH) == OK and bool(cfg.get_value("general", "swiped", false))


static func _save_flag(key: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)  # keep the other flags
	cfg.set_value("general", key, true)
	cfg.save(SAVE_PATH)


func _ready() -> void:
	layer = 40  # above the pause menu, story cards and touch controls
	process_mode = Node.PROCESS_MODE_ALWAYS
	_mark_seen()
	_mobile = TouchControls.enabled
	_pages = _make_pages()
	_build()
	_show_page(0)


# --- Content ---------------------------------------------------------------

## Every page: {title, intro, rows: [[icon, title, text, (right)]]}.
## A row with a null icon and empty text is a section header; an int icon is
## a numbered marker (it points at the same number on the touch diagram);
## [DIAGRAM] is the drawing of the phone screen with the touch controls.
func _make_pages() -> Array:
	var pages := []
	pages.append({"title": "L'obiettivo",
		"intro": "Gli Inquinatori stanno riempiendo l'isola di rifiuti. In ogni livello il tuo compito è ripulirla.",
		"rows": [
			[ICON_BAG, "Raccogli i sacchi di rifiuti", "Passaci sopra per raccoglierli. In alto al centro vedi quanti te ne mancano."],
			[_enemy_icon(), "Sconfiggi gli Inquinatori", "In alcuni livelli devi anche sconfiggere un certo numero di nemici: il contatore in alto te lo ricorda."],
			[ICON_STATION, "Vai al punto di raccolta", "Quando l'obiettivo è completo il punto di raccolta si apre e una freccia accanto all'eroe ti mostra la strada, anche attraverso i teletrasporti. Entraci per finire il livello."],
			[ICON_STAR, "Avanza nella storia", "Ogni livello completato sblocca il capitolo successivo."],
		]})
	# Phones and tablets get the touch controls only, computers the keys only.
	if TouchControls.enabled:
		pages.append({"title": "I comandi",
			"intro": "Si gioca con due pollici: il sinistro muove l'eroe, il destro combatte.",
			"rows": _touch_rows()})
	else:
		pages.append({"title": "I comandi",
			"intro": "Muovi l'eroe, attacca e usa la sua mossa speciale.",
			"rows": _keyboard_rows()})
	pages.append({"title": "Combattere",
		"intro": "Colpisci e allontanati: non farti mai circondare.",
		"rows": [
			[ICON_FIST, "Colpisci da vicino", "L'attacco si gira da solo verso il nemico più vicino e colpisce ad arco davanti all'eroe."],
			[ICON_BOLT, "Mossa speciale", "Ogni eroe ha una seconda mossa, spesso a distanza. Dopo averla usata deve ricaricarsi."],
			[ICON_SHIELD, "Respingi i colpi", "Un colpo da vicino rimanda indietro i proiettili nemici, come il fango e le scariche dei droni."],
			[ICON_HEART, "Cuori", "Ogni colpo subito costa un cuore; subito dopo lampeggi e per un attimo sei invulnerabile. Raccogli i cuori nel livello per curarti."],
			[ICON_BROKEN, "Se perdi tutti i cuori", "Il livello è perso, ma tieni metà delle monete raccolte. Riprova!"],
			[_enemy_icon(true), "Conosci il nemico", "Prima di ogni capitolo ti presentiamo i nuovi nemici. Li ritrovi nel Codex, con un consiglio per batterli."],
		]})
	pages.append({"title": "Gli oggetti",
		"intro": "Esplora ogni angolo: c'è molto da raccogliere.",
		"rows": [
			[ICON_COIN, "Monete verdi", "Servono ad aprire i forzieri del livello. Quelle che non spendi diventano monete del negozio a fine livello."],
			[ICON_CHEST, "Forzieri", "Toccali con abbastanza monete verdi. Ricompensa a caso: Cura, Eco Rush (20 secondi più veloce e più forte), Tesoro (+100 monete) o Scudo."],
			[ICON_CRATE, "Casse del riciclo", "Si aprono al tuo passaggio e liberano 5 monete verdi."],
			[ICON_FEATHER, "Piuma", "Per qualche secondo corri più veloce."],
			[ICON_BARREL, "Barili che perdono", "La pozza tossica ti rallenta e ti toglie cuori. Raccogli il barile per metterlo in sicurezza: la pozza si asciuga."],
			[ICON_BATTERY, "Batterie", "Compaiono solo quando giochi con ECO-9 e ricaricano la sua energia."],
		]})
	pages.append({"title": "Stelle e segreti",
		"intro": "Finire un livello è solo l'inizio.",
		"rows": [
			[ICON_STAR, "Tre stelle per livello", "Una per averlo finito, una per aver raccolto tutti gli oggetti e una per non aver subito danni."],
			[ICON_DOSSIER, "Dossier segreto", "In ogni capitolo è nascosto un dossier degli Inquinatori: trovalo per scoprire di più sulla storia."],
			[ICON_SWORD, "Missione secondaria", "Ogni capitolo ha anche una missione extra, come aprire tutti i forzieri o finire senza danni. Dà monete in più la prima volta."],
			[VaultChest.OPEN, "Caveau nascosto", "Rompi casse e vasi sospetti: possono nascondere un passaggio verso un portale. Dentro ti aspettano guardiani e una reliquia."],
		]})
	var heroes := []
	for pg in ShopMenu.CHARACTERS:
		var price := tr("Gratis") if pg.price <= 0 else tr("%d monete") % pg.price
		heroes.append([pg.icon, pg.title, HERO_MOVES.get(pg.title, pg.shop_description), price])
	pages.append({"title": "Gli eroi",
		"intro": "Labra è con te fin dall'inizio. Gli altri eroi si sbloccano nel negozio con le monete.",
		"rows": heroes})
	pages.append({"title": "Negozio e modalità",
		"intro": "Le monete che guadagni servono a diventare più forte.",
		"rows": [
			[ICON_COIN, "Negozio", "Sblocca eroi e Potenziamenti: cuore extra, scarpe veloci, colpo potente, magnete e scudo. Puoi accenderli e spegnerli quando vuoi."],
			[ICON_ARMOR, "Sfide", "Rendono i nemici più forti (corazzati, rapidi, colpi pesanti, senza cure), ma ti fanno guadagnare più monete."],
			[ICON_MAGNET, "Sfida del giorno", "Ogni giorno un livello con le stesse Sfide per tutti e i potenziamenti spenti. Completala per monete extra e scala la classifica."],
			[ICON_RUSH, "Rage mode", "Resisti a ondate infinite di nemici su una mappa già sbloccata. Ogni 10 round arriva un boss: battilo per scegliere un vantaggio permanente."],
			[ICON_LOCK, "Codex", "Traguardi, nemici incontrati, dossier, caveau e statistiche: tutto quello che hai scoperto."],
		]})
	pages.append({"title": "Consigli",
		"intro": "Sei pronto. Ecco qualche trucco per finire in bellezza.",
		"rows": [
			[ICON_STATION, "Usa la mappa", "Metti in pausa: la mappa mostra i rifiuti rimasti, i nemici, i forzieri e la strada per il punto di raccolta."],
			[ICON_SHIELD, "Tieni d'occhio gli Elite", "Sono più resistenti e più forti degli altri: tienili a distanza e colpiscili quando si fermano."],
			[ICON_BARREL, "Pulisci prima i barili", "Mettere in sicurezza i barili ti libera la strada e ti evita danni inutili."],
			[ICON_COIN, "Spendi bene le monete", "Le monete verdi spese nei forzieri non diventano monete del negozio: aprili quando ti serve una mano."],
			[ICON_STAR, "Rivedi questa guida", "La trovi sempre nel menu principale e nel menu di pausa."],
		]})
	return pages


func _keyboard_rows() -> Array:
	return [
		[null, "Tastiera e mouse", ""],
		[ICON_BOOT, tr("Muoviti: %s") % " ".join([_key("up"), _key("left"), _key("down"), _key("right")]),
				"Puoi cambiare i tasti in Opzioni."],
		[ICON_FIST, tr("Attacco: %s") % (_key("primary") + " / " + tr("tasto destro del mouse")),
				"L'attacco principale dell'eroe. Con quasi tutti gli eroi puoi tenerlo premuto per continuare a colpire."],
		[ICON_BOLT, tr("Mossa speciale: %s") % tr("tasto sinistro del mouse"),
				"Mira con il puntatore del mouse."],
		[ICON_LOCK, tr("Pausa: %s") % _key("pause"), "Nel menu di pausa trovi la mappa del livello."],
	]


## The numbers match the markers on TouchDiagram.
func _touch_rows() -> Array:
	return [
		[DIAGRAM],
		[1, "Joystick: in basso a sinistra", "Appoggia il pollice in un punto qualsiasi della parte bassa a sinistra dello schermo: il joystick compare sotto il dito. Trascina per muoverti, lascia per fermarti."],
		[2, "Attacco: il pulsante grande", "Il nome cambia in base all'eroe: ATTACCA, POZIONE, PUGNO... Con quasi tutti gli eroi puoi tenerlo premuto per continuare a colpire."],
		[3, "Mossa speciale: il pulsante piccolo", "Mira da sola verso il nemico più vicino. L'ombra scura che gira sul pulsante indica che si sta ricaricando."],
		[4, "Pausa: in alto a destra", "Nel menu di pausa trovi la mappa del livello e questa guida."],
		[ICON_BOOT, "Usa più dita insieme", "Puoi correre e attaccare nello stesso momento: tieni il pollice sinistro sul joystick mentre premi i pulsanti."],
		[ICON_HEART, "In alto: cuori e obiettivo", "In alto a sinistra ci sono i tuoi cuori, al centro i rifiuti e i nemici che ti mancano. Tieni i pollici in basso per non coprirli."],
	]


## Name of the first key bound to `action` (follows the player's rebinding).
func _key(action: String) -> String:
	if not InputMap.has_action(action):
		return "?"
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			var code: Key = e.keycode
			if code == KEY_NONE and e.physical_keycode != KEY_NONE:
				code = DisplayServer.keyboard_get_keycode_from_physical(e.physical_keycode)
			if code != KEY_NONE:
				return OS.get_keycode_string(code)
	return "?"


## First frame of a polluter's sprite sheet.
func _enemy_icon(elite := false) -> Texture2D:
	var icon := AtlasTexture.new()
	icon.atlas = load("res://EliteEnemy/Assets/Spirtes/BracconiereElite.png" if elite
			else "res://Default_Enemy/Assets/Sprites/Bracconiere.png")
	icon.region = Rect2(0, 0, 48, 48)
	return icon


# --- UI --------------------------------------------------------------------

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	_margin = MarginContainer.new()
	_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_margin)
	_fit_margins()
	get_viewport().size_changed.connect(_fit_margins)

	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.09, 0.07, 0.96)
	style.set_corner_radius_all(18)
	style.set_border_width_all(4)
	style.border_color = Color(0.55, 0.85, 0.4)
	style.content_margin_left = 34
	style.content_margin_right = 34
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	_panel.add_theme_stylebox_override("panel", style)
	_margin.add_child(_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_panel.add_child(col)

	# header, one line to leave room for the page: "Come si gioca · 2 / 8"
	# on the left, the page title in the middle, close on the right
	var header := HBoxContainer.new()
	col.add_child(header)
	_step = _label("", _fs(16), Color(0.65, 0.9, 0.5))
	_step.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_step.size_flags_stretch_ratio = 1.0
	_step.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_step.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(_step)
	_title = _label("", 34 if _mobile else 40, Color.WHITE)
	_title.add_theme_constant_override("outline_size", 10)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_title)
	var right := HBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_END
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(right)
	var close := _button("Chiudi", _fs(20))
	close.custom_minimum_size = Vector2(130, 52) if _mobile else Vector2(120, 44)
	close.pressed.connect(_close)
	right.add_child(close)

	_intro = _label("", _fs(19), GOLD)
	_intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_intro)

	# the page body, rebuilt by _show_page()
	_body = MarginContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.mouse_filter = Control.MOUSE_FILTER_PASS
	col.add_child(_body)

	# phones: a finger sliding across the page shows that the guide is
	# turned by swiping (kept until the player has swiped once)
	if _mobile and not _swiped():
		_hint = SwipeHint.new()
		_hint.text = tr("Scorri per cambiare pagina")
		_hint.font_size = _fs(20)
		col.add_child(_hint)

	# footer: previous · one dot per page · next
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	col.add_child(footer)
	_prev = _button("Indietro", _fs(22))
	_prev.custom_minimum_size = Vector2(180, 56) if _mobile else Vector2(170, 52)
	_prev.pressed.connect(func(): _go(-1))
	footer.add_child(_prev)
	_dots = HBoxContainer.new()
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	_dots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dots.add_theme_constant_override("separation", 6)
	footer.add_child(_dots)
	for i in _pages.size():
		var dot := Button.new()
		dot.focus_mode = Control.FOCUS_NONE
		dot.custom_minimum_size = Vector2(26, 26)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.tooltip_text = tr(_pages[i].title)
		dot.pressed.connect(func():
			SFXManager.play_sfx(preload("res://Audio/SFX/Eco/ui_tab.wav"))
			_show_page(i))
		_dots.add_child(dot)
	_next = _button("Avanti", _fs(22))
	_next.custom_minimum_size = Vector2(180, 56) if _mobile else Vector2(170, 52)
	_style_next(_next)
	_next.pressed.connect(func(): _go(1))
	footer.add_child(_next)

	_panel.modulate.a = 0.0
	create_tween().tween_property(_panel, "modulate:a", 1.0, 0.15)


## Roomy on big screens, tight on phones.
func _fit_margins() -> void:
	var s := get_viewport().get_visible_rect().size
	# phones: use more of the screen, but keep clear of the notch
	var side := clampf(s.x * (0.03 if _mobile else 0.08), 16.0, 160.0)
	var top := clampf(s.y * (0.03 if _mobile else 0.05), 10.0, 60.0)
	var safe: Vector4 = TouchControls._safe_margins(s)
	_margin.add_theme_constant_override("margin_left", int(side + safe.x))
	_margin.add_theme_constant_override("margin_right", int(side + safe.z))
	_margin.add_theme_constant_override("margin_top", int(top + safe.y))
	_margin.add_theme_constant_override("margin_bottom", int(top + safe.w))


func _show_page(i: int, from := 0) -> void:
	_page = clampi(i, 0, _pages.size() - 1)
	var page: Dictionary = _pages[_page]
	_step.text = tr("Come si gioca  ·  %d / %d") % [_page + 1, _pages.size()]
	_title.text = tr(page.title)
	_title.add_theme_font_override("font", TITLE_FONT)
	_intro.text = tr(page.intro)
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	var rows: Array = []
	var diagram := false
	for r in page.rows:
		if r[0] is String and r[0] == DIAGRAM:
			diagram = true
		elif r[0] == null and r[2] == "":
			rows.append(_section(r[1]))
		else:
			rows.append(_row(r[0], r[1], r[2], r[3] if r.size() > 3 else ""))
	# Landscape screens are wide and short: rows go in two columns, and the
	# touch diagram sits beside its numbered explanations instead of above.
	var wide := get_viewport().get_visible_rect().size.x >= 1000.0
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var list: Container
	if wide and not diagram and rows.size() > 3:
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 8)
		list = grid
	else:
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 8)
		list = vbox
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.mouse_filter = Control.MOUSE_FILTER_PASS
	for row in rows:
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_child(row)
	_scroll.add_child(list)
	if diagram:
		var split: BoxContainer = HBoxContainer.new() if wide else VBoxContainer.new()
		split.add_theme_constant_override("separation", 14)
		var drawing := TouchDiagram.new()
		drawing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		drawing.size_flags_vertical = Control.SIZE_EXPAND_FILL
		drawing.size_flags_stretch_ratio = 1.0
		_scroll.size_flags_stretch_ratio = 1.3
		split.add_child(drawing)
		split.add_child(_scroll)
		_body.add_child(split)
	else:
		_body.add_child(_scroll)
	_prev.disabled = _page == 0
	_next.text = tr("Ho capito!") if _page == _pages.size() - 1 else tr("Avanti")
	for d in _dots.get_child_count():
		var dot: Button = _dots.get_child(d)
		var on := d == _page
		for state in ["normal", "hover", "pressed"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = GREEN if on else Color(1, 1, 1, 0.25 if state == "normal" else 0.45)
			sb.set_corner_radius_all(13)
			dot.add_theme_stylebox_override(state, sb)
	# the new page slides in from the side it comes from
	_set_drag(from * 90.0)
	if from != 0:
		create_tween().tween_method(_set_drag, from * 90.0, 0.0, 0.18) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# first page: the "Avanti" button gently pulses so the way on is obvious
	if _next_pulse:
		_next_pulse.kill()
		_next.modulate = Color.WHITE
	if _page == 0:
		_next_pulse = create_tween().set_loops()
		_next_pulse.tween_property(_next, "modulate", Color(1.35, 1.35, 1.35), 0.6)
		_next_pulse.tween_property(_next, "modulate", Color.WHITE, 0.6)



func _go(step: int) -> void:
	if _page + step >= _pages.size():
		_close()
		return
	if _page + step < 0:
		return
	SFXManager.play_sfx(preload("res://Audio/SFX/Eco/ui_page.wav"))
	_show_page(_page + step, step)


## Pushes the page sideways by `x` (it fades as it goes), via the body's
## margins so the containers keep their layout.
func _set_drag(x: float) -> void:
	_drag = x
	_body.add_theme_constant_override("margin_left", roundi(x))
	_body.add_theme_constant_override("margin_right", roundi(-x))
	_body.modulate.a = clampf(1.0 - absf(x) / 400.0, 0.3, 1.0)


func _style_next(b: Button) -> void:
	for state in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.2, 0.45, 0.15) if state != "pressed" else Color(0.15, 0.35, 0.1)
		if state == "hover":
			sb.bg_color = Color(0.26, 0.55, 0.2)
		sb.set_border_width_all(3)
		sb.border_color = GREEN
		sb.set_corner_radius_all(12)
		b.add_theme_stylebox_override(state, sb)


## Swipe left / right to turn the page. Vertical drags stay with the list's
## scrolling, and a short drag is a tap on whatever is under the finger.
const SWIPE_MIN := 90.0

func _input(event: InputEvent) -> void:
	# the page follows the finger sideways, so it feels like a page to turn
	if event is InputEventScreenDrag and event.index == _swipe_index:
		var d: Vector2 = event.position - _swipe_from
		if absf(d.x) > 12.0 and absf(d.x) > absf(d.y) * 1.5:
			var step := -1 if d.x > 0.0 else 1
			var can := _page + step >= 0 and _page + step < _pages.size()
			_set_drag(d.x * (0.6 if can else 0.15))
		return
	if event is InputEventScreenTouch:
		if event.pressed and _swipe_index == -1:
			_swipe_index = event.index
			_swipe_from = event.position
		elif not event.pressed and event.index == _swipe_index:
			var d: Vector2 = event.position - _swipe_from
			_swipe_index = -1
			var step := -1 if d.x > 0.0 else 1
			# a swipe only turns pages: it never closes the guide
			if absf(d.x) >= SWIPE_MIN and absf(d.x) > absf(d.y) * 2.0 \
					and _page + step >= 0 and _page + step < _pages.size():
				_go(step)
				_learned_swipe()
			elif _drag != 0.0:
				create_tween().tween_method(_set_drag, _drag, 0.0, 0.15)
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		_close()
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("right"):
		_go(1)
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("left"):
		_go(-1)
	else:
		return
	get_viewport().set_input_as_handled()  # don't let the pause menu see it


## The player knows how to swipe now: the hint fades out for good.
func _learned_swipe() -> void:
	if _hint == null:
		return
	_save_flag("swiped")
	var h := _hint
	_hint = null
	var tw := create_tween()
	tw.tween_property(h, "modulate:a", 0.0, 0.3)
	tw.tween_callback(h.queue_free)


func _close() -> void:
	if is_queued_for_deletion():
		return
	SFXManager.play_sfx(preload("res://Audio/SFX/Eco/ui_back.wav"))
	closed.emit()
	queue_free()


## One line of a page: icon, title, explanation and an optional note on the right.
func _row(icon, title: String, text: String, right: String) -> Control:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.45)
	style.set_border_width_all(2)
	style.border_color = Color(GREEN, 0.45)
	style.set_corner_radius_all(12)
	style.content_margin_left = 16
	style.content_margin_right = 26
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(row)
	if icon is int:
		var badge := Badge.new()
		badge.number = icon
		badge.custom_minimum_size = Vector2(52, 52)
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(badge)
	var tex := TextureRect.new()
	tex.visible = icon is Texture2D
	tex.texture = icon if icon is Texture2D else null
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.custom_minimum_size = Vector2(52, 52)
	tex.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(tex)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var t := _label(tr(title), _fs(22), GREEN)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(t)
	if text != "":
		var d := _label(tr(text), _fs(18), Color.WHITE)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(d)
	if right != "":
		var r := _label(right, _fs(20), GOLD)
		r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(r)
	return panel


## A small heading between rows ("Tastiera e mouse").
func _section(text: String) -> Control:
	var l := _label(tr(text), _fs(22), CYAN)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## Font size, a bit bigger on phones.
func _fs(size: int) -> int:
	return roundi(size * 1.15) if _mobile else size


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	# the text is already translated with tr(): don't translate it twice
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, font_size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_size)
	return b


# --- Drawings ----------------------------------------------------------------

## A finger that slides across a strip, right to left, with arrows ahead of
## it and the words "Scorri per cambiare pagina": the guide is a book of
## pages you turn with your thumb.
class SwipeHint extends Control:
	const GOLD := Color(1.0, 0.83, 0.3)
	var text := ""
	var font_size := 22
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(0, font_size + 30)

	func _process(delta: float) -> void:
		_t = fmod(_t + delta, 1.8)
		queue_redraw()

	func _draw() -> void:
		var font := get_theme_font("font", "Label")
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var track := 150.0
		var total := track + 24.0 + tw
		var x0 := (size.x - total) * 0.5
		var cy := size.y * 0.5
		# the strip
		var pill := Rect2(x0 - 22, cy - size.y * 0.5 + 2, total + 44, size.y - 4)
		draw_style_box(_pill(), pill)
		# arrows pointing the way the finger goes (towards the next page)
		for i in 3:
			var ax := x0 + 18 + i * 22
			var a := 0.35 + 0.65 * clampf(sin((_t / 1.8) * TAU * 2.0 - i * 0.9) * 0.5 + 0.5, 0.0, 1.0)
			var c := Color(GOLD, a)
			draw_polyline(PackedVector2Array([Vector2(ax + 8, cy - 9), Vector2(ax, cy), Vector2(ax + 8, cy + 9)]), c, 4.0)
		# the finger: slides right -> left, then fades and starts again
		var p := clampf(_t / 1.3, 0.0, 1.0)
		var e := p * p * (3.0 - 2.0 * p)
		var fx := x0 + track - 4 - e * (track - 70)
		var alpha := 1.0 if _t < 1.3 else 1.0 - (_t - 1.3) / 0.5
		for k in 5:  # fading trail
			var tx := fx + (k + 1) * 9.0 * e
			draw_circle(Vector2(tx, cy), 9.0 - k * 1.4, Color(1, 1, 1, 0.18 * alpha * (1.0 - k * 0.18)))
		draw_circle(Vector2(fx, cy), 12.0, Color(1, 1, 1, 0.95 * alpha))
		draw_arc(Vector2(fx, cy), 12.0, 0, TAU, 24, Color(0, 0, 0, 0.6 * alpha), 2.0)
		# the words
		var tx0 := x0 + track + 24
		var base := cy + font.get_ascent(font_size) * 0.5 - font.get_descent(font_size) * 0.5
		draw_string_outline(font, Vector2(tx0, base), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, Color(0, 0, 0, 0.8))
		draw_string(font, Vector2(tx0, base), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, GOLD)

	func _pill() -> StyleBoxFlat:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1.0, 0.83, 0.3, 0.12)
		sb.set_border_width_all(2)
		sb.border_color = Color(1.0, 0.83, 0.3, 0.6)
		sb.set_corner_radius_all(int(size.y * 0.5))
		return sb


## Gold disc with a number: links a line of text to the same number on the
## touch diagram.
class Badge extends Control:
	var number := 1

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.4
		TouchDiagram.draw_badge(self, c, r, number)


## A phone screen during a level, with the touch controls where the game puts
## them (see TouchControls._layout): joystick zone in the lower left, the big
## attack button in the bottom-right corner with the special move next to it,
## pause in the top-right corner. It moves a little (the stick circles, the
## special button recharges) and each control has a numbered marker.
class TouchDiagram extends Control:
	const HEART := preload("res://Collectibles/Assets/Sprites/Heart.png")
	const BAG := preload("res://Collectibles/Assets/Sprites/toxic_waste.png")
	const GOLD := Color(1.0, 0.83, 0.3)
	## Screen proportions of a phone in landscape and the game's height in
	## canvas units, used to scale the real button sizes down.
	const ASPECT := 2.1
	const GAME_HEIGHT := 648.0

	var _t := 0.0
	var _hero: Texture2D
	var _enemy: AtlasTexture

	func _ready() -> void:
		custom_minimum_size = Vector2(0, 220)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hero = ShopMenu.CHARACTERS[0].icon
		_enemy = AtlasTexture.new()
		_enemy.atlas = load("res://Default_Enemy/Assets/Sprites/Bracconiere.png")
		_enemy.region = Rect2(0, 0, 48, 48)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var h := size.y - 8.0
		var w := minf(size.x - 8.0, h * ASPECT)
		h = w / ASPECT
		var phone := Rect2((size - Vector2(w, h)) * 0.5, Vector2(w, h))
		var bezel := StyleBoxFlat.new()
		bezel.bg_color = Color(0.08, 0.08, 0.1)
		bezel.set_corner_radius_all(int(h * 0.12))
		bezel.border_color = Color(0.35, 0.35, 0.4)
		bezel.set_border_width_all(2)
		draw_style_box(bezel, phone)
		var scr := phone.grow(-h * 0.06)
		scr.position.x += h * 0.04
		scr.size.x -= h * 0.08
		draw_rect(scr, Color(0.16, 0.33, 0.17))
		var k := scr.size.y / GAME_HEIGHT  # canvas units -> diagram pixels
		var o := scr.position

		# scenery: a few trees and a path, then the hero and a polluter
		draw_rect(Rect2(o + scr.size * Vector2(0.0, 0.55), scr.size * Vector2(1.0, 0.12)), Color(0.42, 0.32, 0.2))
		for p in [Vector2(0.08, 0.2), Vector2(0.3, 0.12), Vector2(0.62, 0.22), Vector2(0.88, 0.36), Vector2(0.5, 0.82), Vector2(0.2, 0.9)]:
			draw_circle(o + scr.size * p, scr.size.y * 0.07, Color(0.1, 0.24, 0.11))
		var hero_size := Vector2.ONE * scr.size.y * 0.22
		draw_texture_rect(_hero, Rect2(o + scr.size * Vector2(0.46, 0.5) - hero_size * 0.5, hero_size), false)
		draw_texture_rect(_enemy, Rect2(o + scr.size * Vector2(0.64, 0.46) - hero_size * 0.5, hero_size), false)

		# HUD: hearts top left, objective top centre
		for i in 3:
			var hs := Vector2(14, 13) * k * 2.4
			draw_texture_rect(HEART, Rect2(o + Vector2(10 + i * 38, 10) * k, hs), false)
		var font := get_theme_default_font()
		var fs := maxi(9, int(26 * k))
		var obj := "3 / 8"
		var ow := font.get_string_size(obj, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var bag := Vector2.ONE * fs * 1.3
		var ox := o.x + scr.size.x * 0.5 - (ow + bag.x + 4) * 0.5
		draw_texture_rect(BAG, Rect2(Vector2(ox, o.y + 6 * k), bag), false)
		draw_string(font, Vector2(ox + bag.x + 4, o.y + 6 * k + bag.y * 0.8), obj, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)

		# 1: joystick zone (left 45%, below the top 30%) and the stick
		var zone := Rect2(o + scr.size * Vector2(0.0, 0.3), scr.size * Vector2(0.45, 0.7))
		draw_rect(zone, Color(1, 1, 1, 0.07))
		_dashed_rect(zone.grow(-2), Color(1, 1, 1, 0.45))
		var stick_r := 80.0 * k
		var base := Vector2(zone.position.x + 28 * k + stick_r, zone.end.y - 28 * k - stick_r)
		var knob := base + Vector2(cos(_t * 2.0), sin(_t * 2.0) * 0.7) * stick_r * 0.5
		draw_circle(base, stick_r, Color(0, 0, 0, 0.2))
		draw_arc(base, stick_r, 0.0, TAU, 48, Color(1, 1, 1, 0.55), 2.0, true)
		draw_circle(knob, 34.0 * k, Color(1, 1, 1, 0.55))

		# 2 and 3: attack and special buttons, 4: pause
		var pr := 62.0 * k
		var sr := 46.0 * k
		var pc := Vector2(scr.end.x - 28 * k - pr, scr.end.y - 28 * k - pr)
		var sc := pc + Vector2(-(pr + sr + 18 * k), -sr * 0.9)
		_button(pc, pr, tr("ATTACCA"), 0.0)
		_button(sc, sr, tr("LATTINA"), 1.0 - fmod(_t / 2.5, 1.0))
		var pz := 26.0 * k
		var pp := Vector2(scr.end.x - 28 * k - pz, scr.position.y + 14 * k + pz)
		_button(pp, pz, "", 0.0)
		var bar := Vector2(pz * 0.22, pz * 0.9)
		draw_rect(Rect2(pp + Vector2(-pz * 0.14 - bar.x, -bar.y * 0.5), bar), Color(1, 1, 1, 0.8))
		draw_rect(Rect2(pp + Vector2(pz * 0.14, -bar.y * 0.5), bar), Color(1, 1, 1, 0.8))

		# numbered markers
		var br := maxf(11.0, 16.0 * k * 1.6)
		draw_badge(self, zone.position + Vector2(br + 6, br + 6), br, 1)
		draw_badge(self, pc + Vector2(0, -pr - br - 4), br, 2)
		draw_badge(self, sc + Vector2(0, -sr - br - 4), br, 3)
		draw_badge(self, pp + Vector2(-pz - br - 4, 0), br, 4)

	func _button(c: Vector2, r: float, label: String, cooldown: float) -> void:
		draw_circle(c, r, Color(0, 0, 0, 0.25))
		draw_circle(c, r, Color(1, 1, 1, 0.12))
		if cooldown > 0.02:
			var pts := PackedVector2Array([c])
			var steps := maxi(2, ceili(40 * cooldown))
			for i in steps + 1:
				var a := -PI / 2.0 + TAU * (1.0 - cooldown) + TAU * cooldown * float(i) / steps
				pts.append(c + Vector2(cos(a), sin(a)) * r)
			draw_colored_polygon(pts, Color(0, 0, 0, 0.55))
		draw_arc(c, r, 0.0, TAU, 48, Color(1, 1, 1, 0.6), 2.0, true)
		if label != "":
			var font := get_theme_default_font()
			var fs := maxi(9, int(r * 0.34))
			var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			while tw > r * 1.8 and fs > 7:  # long names (ΚΑΤΟΛΙΣΘΗΣΗ) must fit inside
				fs -= 1
				tw = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(font, c + Vector2(-tw * 0.5, fs * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.85))

	func _dashed_rect(r: Rect2, color: Color) -> void:
		var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
		for i in 4:
			draw_dashed_line(corners[i], corners[(i + 1) % 4], color, 2.0, 8.0)

	static func draw_badge(ci: CanvasItem, c: Vector2, r: float, n: int) -> void:
		ci.draw_circle(c, r + 2.0, Color(0, 0, 0, 0.7))
		ci.draw_circle(c, r, GOLD)
		var font: Font = ci.get_theme_default_font()
		var fs := int(r * 1.3)
		var text := str(n)
		var tw: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		ci.draw_string(font, c + Vector2(-tw * 0.5, fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.1, 0.08, 0.02))
