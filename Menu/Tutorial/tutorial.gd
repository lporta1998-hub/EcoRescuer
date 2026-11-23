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
const TITLE_FONT := preload("res://Menu/Font/Bleeding_Cowboys.ttf")

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
var _pages: Array = []
var _margin: MarginContainer
var _panel: PanelContainer
var _title: Label
var _step: Label
var _intro: Label
var _list: VBoxContainer
var _scroll: ScrollContainer
var _dots: HBoxContainer
var _prev: Button
var _next: Button


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
	var cfg := ConfigFile.new()
	cfg.set_value("general", "seen", true)
	cfg.save(SAVE_PATH)


func _ready() -> void:
	layer = 40  # above the pause menu, story cards and touch controls
	process_mode = Node.PROCESS_MODE_ALWAYS
	_mark_seen()
	_pages = _make_pages()
	_build()
	_show_page(0)


# --- Content ---------------------------------------------------------------

## Every page: {title, intro, rows: [[icon, title, text, (right)]]}.
## A row with a null icon and empty text is a section header.
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
	pages.append({"title": "I comandi",
		"intro": "Muovi l'eroe, attacca e usa la sua mossa speciale.",
		"rows": _touch_rows() + _keyboard_rows() if TouchControls.enabled else _keyboard_rows() + _touch_rows()})
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
				"L'attacco principale dell'eroe. Tienilo premuto per continuare a colpire."],
		[ICON_BOLT, tr("Mossa speciale: %s") % tr("tasto sinistro del mouse"),
				"Mira con il puntatore del mouse."],
		[ICON_LOCK, tr("Pausa: %s") % _key("pause"), "Nel menu di pausa trovi la mappa del livello."],
	]


func _touch_rows() -> Array:
	return [
		[null, "Touch screen", ""],
		[ICON_BOOT, "Muoviti: joystick", "Appoggia il dito in un punto qualsiasi della metà sinistra dello schermo e trascina."],
		[ICON_FIST, "Attacco: pulsante grande in basso a destra", "Il nome cambia in base all'eroe: ATTACCA, POZIONE, PUGNO..."],
		[ICON_BOLT, "Mossa speciale: secondo pulsante", "Mira da sola verso il nemico più vicino. L'ombra scura sul pulsante indica la ricarica."],
		[ICON_LOCK, "Pausa: pulsante in alto a destra", "Nel menu di pausa trovi la mappa del livello."],
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
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 14
	style.content_margin_bottom = 16
	_panel.add_theme_stylebox_override("panel", style)
	_margin.add_child(_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_panel.add_child(col)

	# header: "Come si gioca · 2 / 8" on the left, close on the right
	var header := HBoxContainer.new()
	col.add_child(header)
	_step = _label("", 18, Color(0.65, 0.9, 0.5))
	_step.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_step.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_step)
	var close := _button("Chiudi", 20)
	close.custom_minimum_size = Vector2(120, 44)
	close.pressed.connect(_close)
	header.add_child(close)

	_title = _label("", 42, Color.WHITE)
	_title.add_theme_constant_override("outline_size", 10)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_title)

	_intro = _label("", 20, GOLD)
	_intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_intro)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	_list.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.add_child(_list)

	# footer: previous · one dot per page · next
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	col.add_child(footer)
	_prev = _button("Indietro", 22)
	_prev.custom_minimum_size = Vector2(170, 52)
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
	_next = _button("Avanti", 22)
	_next.custom_minimum_size = Vector2(170, 52)
	_next.pressed.connect(func(): _go(1))
	footer.add_child(_next)

	_panel.modulate.a = 0.0
	create_tween().tween_property(_panel, "modulate:a", 1.0, 0.15)


## Roomy on big screens, tight on phones.
func _fit_margins() -> void:
	var s := get_viewport().get_visible_rect().size
	var side := int(clampf(s.x * 0.08, 16.0, 160.0))
	var top := int(clampf(s.y * 0.05, 10.0, 60.0))
	_margin.add_theme_constant_override("margin_left", side)
	_margin.add_theme_constant_override("margin_right", side)
	_margin.add_theme_constant_override("margin_top", top)
	_margin.add_theme_constant_override("margin_bottom", top)


func _show_page(i: int) -> void:
	_page = clampi(i, 0, _pages.size() - 1)
	var page: Dictionary = _pages[_page]
	_step.text = tr("Come si gioca  ·  %d / %d") % [_page + 1, _pages.size()]
	_title.text = tr(page.title)
	# the western-style title font only draws Latin letters (its Greek ones
	# are blank): Greek titles use the normal font
	if _is_latin(_title.text):
		_title.add_theme_font_override("font", TITLE_FONT)
	else:
		_title.remove_theme_font_override("font")
	_intro.text = tr(page.intro)
	for child in _list.get_children():
		child.queue_free()
	for r in page.rows:
		if r[0] == null and r[2] == "":
			_list.add_child(_section(r[1]))
		else:
			_list.add_child(_row(r[0], r[1], r[2], r[3] if r.size() > 3 else ""))
	_scroll.scroll_vertical = 0
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


static func _is_latin(text: String) -> bool:
	for i in text.length():
		if text.unicode_at(i) >= 0x0250:  # past Latin Extended-B
			return false
	return true


func _go(step: int) -> void:
	if _page + step >= _pages.size():
		_close()
		return
	if _page + step < 0:
		return
	SFXManager.play_sfx(preload("res://Audio/SFX/Eco/ui_page.wav"))
	_show_page(_page + step)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		_close()
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("right"):
		_go(1)
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("left"):
		_go(-1)
	else:
		return
	get_viewport().set_input_as_handled()  # don't let the pause menu see it


func _close() -> void:
	if is_queued_for_deletion():
		return
	SFXManager.play_sfx(preload("res://Audio/SFX/Eco/ui_back.wav"))
	closed.emit()
	queue_free()


## One line of a page: icon, title, explanation and an optional note on the right.
func _row(icon: Texture2D, title: String, text: String, right: String) -> Control:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.45)
	style.set_border_width_all(2)
	style.border_color = Color(GREEN, 0.45)
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
	var tex := TextureRect.new()
	tex.texture = icon
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
	var t := _label(tr(title), 22, GREEN)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(t)
	if text != "":
		var d := _label(tr(text), 17, Color(0.92, 0.92, 0.92))
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(d)
	if right != "":
		var r := _label(right, 20, GOLD)
		r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(r)
	return panel


## A small heading between rows ("Tastiera e mouse", "Touch screen").
func _section(text: String) -> Control:
	var l := _label(tr(text), 22, CYAN)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


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
