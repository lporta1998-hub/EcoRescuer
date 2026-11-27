class_name TrainingCoach
extends CanvasLayer
## The coach of the practice level (see Training): one exercise at a time,
## each finished by doing it, never by reading.
##
##  1. walk to the glowing circle         (points at the joystick zone)
##  2. pick up the trash bag              (points at the bag)
##  3. defeat an Inquinatore              (points at the big attack button)
##  4. use the special move               (points at the small button)
##  5. take the trash to the station      (points at the station)
##
## A panel at the top says what to do; on phones a pulsing ring and a finger
## show which control to use. The hero can't lose here: when only one heart
## is left, the hearts refill.

const TITLE_FONT := preload("res://Misc/UI/Fonts/pixel_title_font.tres")
const GREEN := Color(0.65, 0.95, 0.3)
const GOLD := Color(1.0, 0.83, 0.3)
const ENEMY_SCENE := "res://Default_Enemy/Enemy.tscn"
## Where the first exercise sends the hero (map tile).
const MOVE_TILE := Vector2i(18, 14)

enum { MOVE, BAG, ATTACK, SPECIAL, STATION }

## Title, text on phones, text with keyboard and mouse.
const STEPS := [
	["Muoviti", "Appoggia il pollice in basso a sinistra e trascinalo: raggiungi il cerchio luminoso.",
			"Usa W A S D o le frecce: raggiungi il cerchio luminoso."],
	["Raccogli i rifiuti", "Passa sopra il sacco di rifiuti per raccoglierlo. In alto vedi quanti te ne mancano.",
			"Passa sopra il sacco di rifiuti per raccoglierlo. In alto vedi quanti te ne mancano."],
	["Attacca!", "Arriva un Inquinatore! Premi il pulsante grande in basso a destra per colpirlo.",
			"Arriva un Inquinatore! Colpiscilo con il tasto destro del mouse."],
	["Mossa speciale", "Ora premi il pulsante piccolo: la mossa speciale mira da sola al nemico più vicino.",
			"Ora usa la mossa speciale con il tasto sinistro del mouse: mira con il puntatore."],
	["Al punto di raccolta", "Hai i rifiuti: portali al punto di raccolta. Segui la freccia accanto all'eroe.",
			"Hai i rifiuti: portali al punto di raccolta. Segui la freccia accanto all'eroe."],
]

var level: Node2D
var _step := -1
var _busy := false
var _done := false
var _player: Character
var _enemy: Node2D
var _target: Node2D          ## the world spot of this exercise (circle, bag, station)
var _marker: GroundMarker
var _guide: GuideArrow
var _pointer: Pointer
var _panel: PanelContainer
var _count: Label
var _title: Label
var _text: Label
var _told_safe := false


func _ready() -> void:
	layer = 25  # above the HUD and the touch controls, under pause menu and guide
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_pointer = Pointer.new()
	_pointer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_pointer)
	_marker = GroundMarker.new()
	level.add_child(_marker)
	_guide = GuideArrow.new()
	level.add_child(_guide)
	# the station arrow of the HUD comes back for the last exercise
	if LevelManager.objective_hud:
		LevelManager.objective_hud.exit_node = null
	await get_tree().process_frame
	_player = get_tree().get_first_node_in_group("player") as Character
	_next_step()


func _process(_delta: float) -> void:
	if _done or _player == null or not is_instance_valid(_player):
		return
	_keep_alive()
	if not is_instance_valid(_target):
		_target = null  # the bag was picked up, the enemy is gone
	_marker.target = _target
	_guide.player = _player
	_guide.target = _target
	_pointer.control = _touch_control()
	if _busy:
		return
	match _step:
		MOVE:
			if _player.global_position.distance_to(_target.global_position) < 26.0:
				_complete()
		BAG:
			if LevelManager.trash_bags_collected >= 1:
				_complete()
		ATTACK:
			if _enemy == null or not is_instance_valid(_enemy) or _enemy.is_dead:
				_complete()
		SPECIAL:
			if _player.has_method("secondary_cooldown_ratio") and _player.secondary_cooldown_ratio() > 0.0:
				_complete()


## The recycling station was reached (via LevelManager.try_finish_level).
func exit_reached() -> void:
	if _done:
		return
	if _step < STATION:
		if LevelManager.objective_hud:
			LevelManager.objective_hud.toast(tr("Prima finisci gli esercizi dell'allenamento!"), GOLD)
		return
	_finish()


# --- Exercises ---------------------------------------------------------------

func _next_step() -> void:
	_step += 1
	var s: Array = STEPS[_step]
	_count.text = tr("Allenamento  ·  %d / %d") % [_step + 1, STEPS.size()]
	_title.text = tr(s[0])
	_text.text = tr(s[1] if TouchControls.enabled else s[2])
	_text.add_theme_color_override("font_color", Color.WHITE)
	_target = null
	# the objective tracker only for the exercises about the objective
	if LevelManager.objective_hud:
		LevelManager.objective_hud.set_objective_visible(_step in [BAG, STATION])
	match _step:
		MOVE:
			var spot := Node2D.new()
			spot.position = Vector2(MOVE_TILE) * BuiltLevel.TILE + Vector2.ONE * BuiltLevel.TILE * 0.5
			level.add_child(spot)
			_target = spot
		BAG:
			var bags := level.find_children("*", "TrashBag", true, false)
			if not bags.is_empty():
				_target = bags[0]
		ATTACK:
			_enemy = _spawn_enemy()
			_target = _enemy
		SPECIAL:
			_enemy = _spawn_enemy()
			_target = _enemy
		STATION:
			_target = LevelManager.level_exit
			if LevelManager.objective_hud:
				LevelManager.objective_hud.exit_node = LevelManager.level_exit
	_pop(_panel)


func _complete() -> void:
	_busy = true
	SFXManager.play_sfx(preload("res://Audio/SFX/Eco/ui_confirm.wav"))
	_text.text = tr("Bravo!")
	_text.add_theme_color_override("font_color", GREEN)
	# the HUD's own "objective done, go to the station" message would get
	# ahead of the coach: the station is the last exercise
	if _step == BAG and LevelManager.objective_hud:
		LevelManager.objective_hud.toast(tr("Bravo!"), GREEN)
	_target = null
	await get_tree().create_timer(1.0, true).timeout
	_busy = false
	if not _done:
		_next_step()


## A weak polluter a little ahead of the hero, on open ground.
func _spawn_enemy() -> Node2D:
	var e: Node2D = load(ENEMY_SCENE).instantiate()
	e.set("max_health", 2.0)
	var where := _player.global_position + Vector2(150, -10)
	if LevelManager.route_guide and LevelManager.route_guide.is_ready():
		where = LevelManager.route_guide.open_spot(where)
	e.global_position = where
	level.add_child(e)
	return e


## The hero can't lose in the training: the hearts refill at the last one.
func _keep_alive() -> void:
	if _player.health <= 1 and not _player.is_dead:
		_player.heal(int(_player.max_health))
		if not _told_safe and LevelManager.objective_hud:
			_told_safe = true
			LevelManager.objective_hud.toast(tr("Qui non puoi perdere: prova pure!"), GREEN)


## The on-screen control this exercise is about (phones only).
func _touch_control() -> Control:
	if not TouchControls.enabled or _busy:
		return null
	match _step:
		MOVE: return TouchControls._joystick
		ATTACK: return TouchControls._primary
		SPECIAL: return TouchControls._secondary
	return null


func _finish() -> void:
	_done = true
	_target = null
	_pointer.control = null
	_marker.target = null
	_guide.target = null
	_panel.hide()
	get_tree().paused = true
	MusicManager.play_level_complete()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _panel_style())
	card.custom_minimum_size = Vector2(560, 0)
	center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	card.add_child(col)
	var title := _label(tr("Allenamento completato!"), 34, GREEN)
	title.add_theme_font_override("font", TITLE_FONT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var text := _label(tr("Sei pronto per ripulire l'isola. Nel menu di pausa trovi la mappa del livello e la guida completa."), 21, Color.WHITE)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(text)
	var play := Button.new()
	play.text = tr("Gioca!")
	play.focus_mode = Control.FOCUS_NONE
	play.custom_minimum_size = Vector2(220, 60)
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play.add_theme_font_size_override("font_size", 26)
	_green_button(play)
	play.pressed.connect(func():
		SFXManager.play_sfx(preload("res://Audio/SFX/Eco/ui_confirm.wav"))
		Training.finish(get_tree(), true))
	col.add_child(play)
	_pop(card)


# --- UI ----------------------------------------------------------------------

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _panel_style())
	_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_panel.offset_left = -340
	_panel.offset_right = 340
	_panel.offset_top = 104  # under the objective tracker and its messages
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(row)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	_count = _label("", 16, GREEN)
	col.add_child(_count)
	_title = _label("", 28, GOLD)
	_title.add_theme_font_override("font", TITLE_FONT)
	col.add_child(_title)
	_text = _label("", 20, Color.WHITE)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_text)
	var skip := Button.new()
	skip.text = tr("Salta")
	skip.focus_mode = Control.FOCUS_NONE
	skip.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	skip.custom_minimum_size = Vector2(96, 44)
	skip.add_theme_font_size_override("font_size", 18)
	skip.pressed.connect(func():
		SFXManager.play_sfx(preload("res://Audio/SFX/Eco/ui_back.wav"))
		Training.finish(get_tree(), true))
	row.add_child(skip)


func _panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.04, 0.09, 0.07, 0.92)
	s.set_border_width_all(3)
	s.border_color = Color(0.55, 0.85, 0.4)
	s.set_corner_radius_all(14)
	s.content_margin_left = 24
	s.content_margin_right = 16
	s.content_margin_top = 12
	s.content_margin_bottom = 14
	return s


func _green_button(b: Button) -> void:
	for state in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.2, 0.45, 0.15) if state == "normal" else Color(0.26, 0.55, 0.2)
		sb.set_border_width_all(3)
		sb.border_color = GREEN
		sb.set_corner_radius_all(12)
		sb.content_margin_left = 20
		sb.content_margin_right = 20
		b.add_theme_stylebox_override(state, sb)


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED  # already tr()-ed
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A small bounce when a panel shows up or changes.
func _pop(c: Control) -> void:
	c.pivot_offset = c.size * 0.5
	c.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(c, "modulate:a", 1.0, 0.2)


# --- Drawings ----------------------------------------------------------------

## Pulsing ring and a finger on the touch control of the exercise. For the
## joystick the finger drags across the zone, for buttons it taps.
class Pointer extends Control:
	const GOLD := Color(1.0, 0.83, 0.3)
	var control: Control
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		if control == null or not is_instance_valid(control) or not control.is_visible_in_tree():
			return
		var rect := control.get_global_rect()
		var pulse := 0.5 + 0.5 * sin(_t * 5.0)
		if control is VirtualJoystick:
			var joy := control as VirtualJoystick
			var c := rect.position + joy.rest_position
			draw_arc(c, joy.radius + 8.0 + pulse * 8.0, 0, TAU, 48, Color(GOLD, 0.9), 4.0)
			# a finger drags from the centre to the right and back
			var p := fmod(_t, 1.6) / 1.6
			var off := Vector2(sin(p * TAU) * joy.radius * 0.7, 0)
			_finger(c + off, 1.0)
			return
		var c2 := rect.get_center()
		var r := minf(rect.size.x, rect.size.y) * 0.5
		draw_arc(c2, r + 8.0 + pulse * 10.0, 0, TAU, 48, Color(GOLD, 0.95), 5.0)
		# a finger taps on it
		var tap := absf(sin(_t * 3.0))
		_finger(c2 + Vector2(10, 14) + Vector2(14, 18) * tap, 1.0 - tap * 0.3)

	func _finger(at: Vector2, alpha: float) -> void:
		draw_circle(at, 15.0, Color(1, 1, 1, 0.9 * alpha))
		draw_arc(at, 15.0, 0, TAU, 24, Color(0, 0, 0, 0.6 * alpha), 2.5)


## A glowing circle on the ground under the target, with a bouncing arrow.
class GroundMarker extends Node2D:
	const GOLD := Color(1.0, 0.83, 0.3)
	var target: Node2D
	var _t := 0.0
	var _arrow: Node2D

	func _ready() -> void:
		z_index = -6
		z_as_relative = false
		_arrow = Node2D.new()
		_arrow.z_index = 30
		_arrow.z_as_relative = false
		_arrow.draw.connect(_draw_arrow)
		add_child(_arrow)

	func _process(delta: float) -> void:
		_t += delta
		visible = target != null and is_instance_valid(target)
		if visible:
			global_position = target.global_position
		queue_redraw()
		_arrow.queue_redraw()

	func _draw() -> void:
		var pulse := 0.5 + 0.5 * sin(_t * 4.0)
		draw_circle(Vector2(0, 4), 13.0 + pulse * 3.0, Color(GOLD, 0.25))
		draw_arc(Vector2(0, 4), 13.0 + pulse * 3.0, 0, TAU, 32, Color(GOLD, 0.9), 2.0)

	func _draw_arrow() -> void:
		var y := -34.0 - absf(sin(_t * 4.0)) * 8.0
		var pts := PackedVector2Array([Vector2(-7, y - 8), Vector2(7, y - 8), Vector2(0, y)])
		_arrow.draw_colored_polygon(pts, GOLD)
		_arrow.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), Color(0, 0, 0, 0.7), 1.5)


## When the target is off to the side, an arrow next to the hero points at it.
class GuideArrow extends Node2D:
	const GOLD := Color(1.0, 0.83, 0.3)
	var player: Node2D
	var target: Node2D

	func _ready() -> void:
		z_index = 30
		z_as_relative = false

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if player == null or target == null or not is_instance_valid(player) or not is_instance_valid(target):
			return
		var d := target.global_position - player.global_position
		if d.length() < 110.0:
			return
		var dir := d.normalized()
		var tip := player.global_position + dir * 34.0
		var side := dir.orthogonal() * 6.0
		var pts := PackedVector2Array([tip + dir * 8.0, tip - dir * 4.0 + side, tip - dir * 4.0 - side])
		draw_colored_polygon(pts, GOLD)
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), Color(0, 0, 0, 0.7), 1.2)
