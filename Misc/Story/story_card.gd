class_name StoryCard
extends CanvasLayer
## A card over the paused game: the level briefing before it starts ("Capitolo
## 3 · La città comprata", story, objective, side quests) or a dossier that was
## just found. Tap anywhere or the button to close; the game resumes.

signal closed

var _card: Dictionary
var _can_close_at := 0


## card: {kicker, title, text, lines: [String], button}
static func open(parent: Node, card: Dictionary) -> StoryCard:
	var c := StoryCard.new()
	c._card = card
	parent.add_child(c)
	return c


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_can_close_at = Time.get_ticks_msec() + 400

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_input)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.09, 0.07, 0.95)
	style.set_corner_radius_all(16)
	style.set_border_width_all(4)
	style.border_color = _card.get("color", Color(0.55, 0.85, 0.4))
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 20
	style.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(640, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	if _card.has("icon"):
		var icon := TextureRect.new()
		icon.texture = _card.icon
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(0, 54)
		col.add_child(icon)
	if _card.get("kicker", "") != "":
		col.add_child(_label(_card.kicker, 16, Color(0.65, 0.9, 0.5)))
	col.add_child(_label(_card.get("title", ""), 34, Color.WHITE))
	var body := _label(_card.get("text", ""), 19, Color(0.86, 0.9, 0.86))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(580, 0)
	col.add_child(body)
	for line in _card.get("lines", []):
		var l := _label(line, 18, Color(1.0, 0.85, 0.4))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(580, 0)
		col.add_child(l)
	var button := Button.new()
	button.text = _card.get("button", "Via!")
	button.add_theme_font_size_override("font_size", 24)
	button.custom_minimum_size = Vector2(200, 52)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(_close)
	col.add_child(button)

	panel.scale = Vector2(0.9, 0.9)
	panel.pivot_offset = Vector2(320, 160)
	panel.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)
	tw.tween_property(panel, "modulate:a", 1.0, 0.15)


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _on_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		_close()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_close()


func _close() -> void:
	if Time.get_ticks_msec() < _can_close_at or is_queued_for_deletion():
		return
	SFXManager.play_sfx(preload("res://Audio/SFX/Eco/ui_page.wav"))
	get_tree().paused = false
	closed.emit()
	queue_free()
