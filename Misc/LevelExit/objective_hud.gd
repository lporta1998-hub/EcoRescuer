class_name ObjectiveHUD
extends CanvasLayer
## In-level HUD:
##  - top centre: objective tracker "Rifiuti 3/8 · Nemici 2/5", then
##    "Porta i rifiuti al punto di raccolta!", plus the coins of this run
##    (spent on eco chests)
##  - top right: active Shop buffs / Sfide with their level, the shield
##    charges left and the Eco Rush timer
##  - short messages ("toasts")
##  - once the objective is done: an arrow next to the player that follows the
##    walking route to the recycling station, through teleports (RouteGuide).
##    When the next teleport is on screen it gets a bouncing marker instead.

const BAG_ICON := preload("res://Collectibles/Assets/Sprites/toxic_waste.png")
const COIN_ICON := preload("res://Collectibles/Assets/Sprites/coin.png")
const STATION := preload("res://Misc/LevelExit/recycle_station.png")
const RUSH_ICON := preload("res://Menu/Shop/Icons/rush.png")
const GOLD := Color(1.0, 0.83, 0.3)
const GREEN := Color(0.65, 0.95, 0.3)
const TELEPORT_COLOR := Color(0.75, 0.5, 1.0)
const ROUTE_REFRESH := 0.25
## How far along the route the arrow looks (world px).
const LOOK_AHEAD := 90.0

var exit_node: Node2D
var route_guide: RouteGuide
var _met := false
var _label: Label
var _coins_label: Label
var _toast: Label
var _toast_tween: Tween
var _arrow: Control
var _buff_row: HBoxContainer
var _buff_badges := {}  # id -> Label
var _waypoint := {}
var _route := PackedVector2Array()
var _route_timer := 0.0
var _shown_coins := -1
var _quest_label: Label
var _quest_timer := 0.0
var _objective_icon: TextureRect


func _ready() -> void:
	layer = 1
	process_mode = Node.PROCESS_MODE_ALWAYS

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.offset_top = 10
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 0)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(lines)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	lines.add_child(row)
	_quest_label = _make_label(15)
	_quest_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quest_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	_quest_label.visible = false
	lines.add_child(_quest_label)
	_objective_icon = _make_icon(BAG_ICON)
	row.add_child(_objective_icon)
	_label = _make_label(20)
	row.add_child(_label)
	var sep := _make_label(20)
	sep.text = "·"
	row.add_child(sep)
	row.add_child(_make_icon(COIN_ICON))
	_coins_label = _make_label(20)
	_coins_label.add_theme_color_override("font_color", GOLD)
	row.add_child(_coins_label)

	_buff_row = HBoxContainer.new()
	_buff_row.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_buff_row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	# right edge, below the touch pause button and clear of the notch
	var margins: Vector4 = TouchControls._safe_margins(get_viewport().get_visible_rect().size)
	_buff_row.offset_right = -12.0 - margins.z
	_buff_row.offset_top = 10.0 + margins.y + (70.0 if TouchControls.enabled else 0.0)
	_buff_row.alignment = BoxContainer.ALIGNMENT_END
	_buff_row.add_theme_constant_override("separation", 4)
	_buff_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_buff_row)
	_fill_buff_row()

	_toast = _make_label(20)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_left = -400
	_toast.offset_right = 400
	_toast.offset_top = 68
	_toast.offset_bottom = 98
	_toast.modulate.a = 0.0
	add_child(_toast)

	_arrow = Control.new()
	_arrow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow.draw.connect(_draw_arrow)
	add_child(_arrow)

	var active := Progress.active_buffs()
	if not active.is_empty():
		var names := []
		for entry in active:
			names.append("%s Lv%d" % [Progress.BUFFS[entry[0]].title, entry[1]])
		toast.call_deferred("Attivi: " + ", ".join(names), Color(0.8, 0.95, 1.0))


func _process(delta: float) -> void:
	# Hide behind the pause / end menus.
	visible = not get_tree().paused
	if not visible:
		return
	if LevelManager.run_coins != _shown_coins:
		_shown_coins = LevelManager.run_coins
		_coins_label.text = str(_shown_coins)
	_update_buff_badges()
	_quest_timer -= delta
	if _quest_timer <= 0.0 and LevelManager.side_quests:
		_quest_timer = 0.5
		LevelManager.side_quests.on_time(LevelManager.elapsed_seconds())
		LevelManager._refresh_quest_hud()
	if _met:
		_route_timer -= delta
		if _route_timer <= 0.0:
			refresh_route()
		_arrow.queue_redraw()


func update_objective(bags: int, bags_needed: int, kills: int, kills_needed: int, met: bool) -> void:
	var was_met := _met
	_met = met
	if met:
		_label.text = "Porta i rifiuti al punto di raccolta!"
		_label.add_theme_color_override("font_color", GREEN)
		if not was_met:
			toast("Obiettivo completato! Raggiungi il punto di raccolta.", GREEN)
			refresh_route()
	else:
		var parts := ["Rifiuti %d/%d" % [mini(bags, bags_needed), bags_needed]]
		if kills_needed > 0:
			parts.append("Nemici %d/%d" % [mini(kills, kills_needed), kills_needed])
		_label.text = "  ·  ".join(parts)
		_label.add_theme_color_override("font_color", Color.WHITE)
	_arrow.queue_redraw()


## Second line under the objective: the side quests ("Dossier 0/1 · Barili 1/3").
func set_quests(text: String) -> void:
	_quest_label.text = text
	_quest_label.visible = text != ""


func toast(text: String, color: Color = GOLD) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", color)
	if _toast_tween:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.5)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.6)


## Recomputes where the player should go next (station or a teleport).
func refresh_route() -> void:
	_route_timer = ROUTE_REFRESH
	var player := _player()
	if player == null or exit_node == null or not is_instance_valid(exit_node):
		_waypoint = {}
		_route = PackedVector2Array()
		return
	var from := player.global_position
	if route_guide:
		_waypoint = route_guide.next_waypoint(from, exit_node.global_position)
		_route = route_guide.path(from, _waypoint.pos)
	else:
		_waypoint = {"pos": exit_node.global_position, "teleport": false}
		_route = PackedVector2Array([from, exit_node.global_position])


## The next point to walk to, for the pause map ({} if none).
func current_waypoint() -> Dictionary:
	return _waypoint


func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D


# --- Buff row --------------------------------------------------------------

func _add_buff_icon(id: String, tex: Texture2D, badge: String, enemy: bool) -> void:
	var box := Control.new()
	box.custom_minimum_size = Vector2(30, 30)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := Panel.new()
	var style := _panel_style()
	style.bg_color = Color(0.35, 0.05, 0.05, 0.6) if enemy else Color(0, 0, 0, 0.5)
	style.set_corner_radius_all(8)
	bg.add_theme_stylebox_override("panel", style)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(bg)
	var icon := TextureRect.new()
	icon.texture = tex
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 3
	icon.offset_top = 3
	icon.offset_right = -3
	icon.offset_bottom = -3
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)
	var label := _make_label(13)
	label.text = badge
	label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	label.offset_left = -14
	label.offset_top = -14
	label.offset_right = 2
	label.offset_bottom = 4
	box.add_child(label)
	_buff_row.add_child(box)
	_buff_badges[id] = label


func _fill_buff_row() -> void:
	for entry in Progress.active_buffs():
		_add_buff_icon(entry[0], load(Progress.BUFFS[entry[0]].icon), str(entry[1]),
				Progress.BUFFS[entry[0]].kind == "enemy")


## Rebuilds the buff icons (Rage mode changes them during the match).
func refresh_buffs() -> void:
	for child in _buff_row.get_children():
		_buff_row.remove_child(child)
		child.queue_free()
	_buff_badges.clear()
	_fill_buff_row()


## The icon in front of the objective line (Rage mode shows a fist).
func set_objective_icon(tex: Texture2D) -> void:
	_objective_icon.texture = tex


func _update_buff_badges() -> void:
	# a shield from a chest without the Scudo buff still gets its icon
	if LevelManager.shield_charges > 0 and not _buff_badges.has("shield"):
		_add_buff_icon("shield", load(Progress.BUFFS.shield.icon), "", false)
	if _buff_badges.has("shield"):
		var charges := LevelManager.shield_charges
		_buff_badges.shield.text = str(charges)
		_buff_badges.shield.get_parent().modulate.a = 1.0 if charges > 0 else 0.35
	var rush := LevelManager.eco_rush_active()
	if rush and not _buff_badges.has("rush"):
		_add_buff_icon("rush", RUSH_ICON, "", false)
		_buff_row.move_child(_buff_badges.rush.get_parent(), 0)
	if _buff_badges.has("rush"):
		var box: Control = _buff_badges.rush.get_parent()
		box.visible = rush
		_buff_badges.rush.text = str(ceili(LevelManager.eco_rush_seconds_left())) if rush else ""


# --- Arrow -----------------------------------------------------------------

func _draw_arrow() -> void:
	if not _met or _waypoint.is_empty():
		return
	var player := _player()
	if player == null:
		return
	var screen := _arrow.get_viewport_rect().size
	var to_screen := _arrow.get_viewport().get_canvas_transform()
	var target_screen: Vector2 = to_screen * (_waypoint.pos as Vector2)
	var t := Time.get_ticks_msec() / 1000.0

	# Target on screen: mark the teleport to use (the station has its own beam).
	if Rect2(Vector2(30, 70), screen - Vector2(60, 100)).has_point(target_screen):
		if _waypoint.teleport:
			var bob := sin(t * 5.0) * 4.0
			var tip := target_screen + Vector2(0, -26 + bob)
			_arrow.draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-10, -14), tip + Vector2(10, -14)]), TELEPORT_COLOR)
			_arrow.draw_arc(target_screen, 18.0 + 3.0 * sin(t * 4.0), 0, TAU, 32, TELEPORT_COLOR, 2.5, true)
			_draw_text(tip + Vector2(0, -20), "Teletrasporto", TELEPORT_COLOR)
		return

	# Off screen: an arrow orbiting the player, along the walking route.
	var player_world := player.global_position
	var ahead := _point_ahead(player_world)
	var player_screen: Vector2 = to_screen * player_world
	var dir: Vector2 = (to_screen * ahead - player_screen).normalized()
	if dir == Vector2.ZERO:
		return
	var pulse := 1.0 + 0.12 * sin(t * 6.5)
	var p := player_screen + dir * 64.0
	var side := dir.orthogonal()
	var tip := p + dir * 24.0 * pulse
	var color := TELEPORT_COLOR if _waypoint.teleport else GREEN
	_arrow.draw_colored_polygon(PackedVector2Array([tip, p - side * 15.0, p + side * 15.0]), Color(0, 0, 0, 0.65))
	_arrow.draw_colored_polygon(PackedVector2Array([tip - dir * 4.0, p - side * 11.0 + dir * 2.0, p + side * 11.0 + dir * 2.0]), color)
	# small icon of what's at the end of the arrow
	var icon_pos := p - dir * 18.0
	if _waypoint.teleport:
		_arrow.draw_circle(icon_pos, 9.0, Color(0, 0, 0, 0.6))
		_arrow.draw_arc(icon_pos, 7.0, 0, TAU, 20, TELEPORT_COLOR, 2.5, true)
	else:
		_arrow.draw_circle(icon_pos, 11.0, Color(0, 0, 0, 0.5))
		_arrow.draw_texture_rect(STATION, Rect2(icon_pos - Vector2(8, 9), Vector2(16, 18)), false)


## The point LOOK_AHEAD px along the route from the player (or the end).
func _point_ahead(from: Vector2) -> Vector2:
	if _route.size() < 2:
		return _waypoint.pos
	var travelled := 0.0
	var prev := from
	for i in range(1, _route.size()):
		var q := _route[i]
		var seg := prev.distance_to(q)
		if travelled + seg >= LOOK_AHEAD:
			return prev.move_toward(q, LOOK_AHEAD - travelled)
		travelled += seg
		prev = q
	return _route[_route.size() - 1]


func _draw_text(center: Vector2, text: String, color: Color) -> void:
	var font := _arrow.get_theme_default_font()
	var fs := 15
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := center - Vector2(w / 2.0, 0)
	_arrow.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.85))
	_arrow.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)


# --- Helpers ---------------------------------------------------------------

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.5)
	style.set_corner_radius_all(12)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


func _make_icon(tex: Texture2D) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = tex
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _make_label(size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
