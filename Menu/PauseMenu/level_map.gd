class_name LevelMap
extends Control
## Miniature of the current level for the pause menu.
##
## A SubViewport shares the game's World2D and looks at the whole level with
## its own zoomed-out camera, so the map is the real level as it is right now
## (collected items are gone, enemies are where they stopped). On top of it we
## draw markers for the player, the trash bags still to collect, enemies,
## teleports, eco chests, leaking barrels and, once the objective is done, the
## route to the recycling station (through teleports, see RouteGuide).

const TRASH_ICON := preload("res://Collectibles/Assets/Sprites/toxic_waste.png")
const STATION_ICON := preload("res://Misc/LevelExit/recycle_station.png")
const LEGEND_HEIGHT := 46.0
const PLAYER_COLOR := Color(0.55, 1.0, 0.45)
const ENEMY_COLOR := Color(1.0, 0.3, 0.25)
const TRASH_COLOR := Color(0.75, 1.0, 0.3)
const TELEPORT_COLOR := Color(0.75, 0.5, 1.0)
const CHEST_COLOR := Color(1.0, 0.8, 0.3)

var _viewport: SubViewport
var _camera: Camera2D
var _level: Node
var _bounds := Rect2()
var _scale := 1.0
var _map_rect := Rect2()
var _route: Array = []  # walking segments (PackedVector2Array) to the station


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport.world_2d = get_viewport().world_2d
	add_child(_viewport)
	_camera = Camera2D.new()
	_viewport.add_child(_camera)


## Starts showing `level`. Call when the pause menu opens.
func open(level: Node) -> void:
	_level = level
	_bounds = _level_bounds(level)
	if _bounds.size.x < 1.0 or _bounds.size.y < 1.0:
		return
	var area := Vector2(size.x, size.y - LEGEND_HEIGHT)
	_scale = minf(area.x / _bounds.size.x, area.y / _bounds.size.y)
	var map_size := (_bounds.size * _scale).floor()
	_map_rect = Rect2(((area - map_size) / 2.0).floor(), map_size)
	_viewport.size = Vector2i(map_size)
	_camera.position = _bounds.get_center()
	_camera.zoom = Vector2(_scale, _scale)
	_camera.enabled = true
	_camera.make_current()
	_camera.force_update_scroll()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_route = []
	var exit := LevelManager.level_exit
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if LevelManager.objective_met() and LevelManager.route_guide and player \
			and exit and is_instance_valid(exit):
		_route = LevelManager.route_guide.route_segments(player.global_position, exit.global_position)
	set_process(true)
	queue_redraw()


## Stops rendering (call when the pause menu closes).
func close() -> void:
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	set_process(false)
	_level = null


func _process(_delta: float) -> void:
	queue_redraw()  # the player marker pulses


## World-space rectangle covering every tile of the level.
func _level_bounds(level: Node) -> Rect2:
	var bounds := Rect2()
	var first := true
	for layer in level.find_children("*", "TileMapLayer", true, false):
		if not layer.visible or layer.tile_set == null:
			continue
		var used: Rect2i = layer.get_used_rect()
		if used.size == Vector2i.ZERO:
			continue
		var ts := Vector2(layer.tile_set.tile_size)
		var a: Vector2 = layer.to_global(Vector2(used.position) * ts)
		var b: Vector2 = layer.to_global(Vector2(used.end) * ts)
		var r := Rect2(a, Vector2.ZERO).expand(b)
		bounds = r if first else bounds.merge(r)
		first = false
	return bounds


func _to_map(world: Vector2) -> Vector2:
	return _map_rect.position + (world - _bounds.position) * _scale


func _draw() -> void:
	if _level == null or not is_instance_valid(_level):
		return
	# frame + level picture
	draw_rect(_map_rect.grow(3), Color(0, 0, 0, 0.55))
	# slightly brighter than the game, so dark cave levels still read on the map
	draw_texture_rect(_viewport.get_texture(), _map_rect, false, Color(1.45, 1.45, 1.45))
	draw_rect(_map_rect.grow(2), Color(1, 1, 1, 0.8), false, 2.0)

	var t := Time.get_ticks_msec() / 1000.0

	# leaking barrels: dark puddles
	for barrel in get_tree().get_nodes_in_group("barrel_hazard"):
		if _level.is_ancestor_of(barrel):
			var p := _to_map(barrel.global_position)
			draw_circle(p, 5.0, Color(0.05, 0.05, 0.08, 0.9))
			draw_circle(p, 3.0, Color(0.45, 0.7, 0.2, 0.9))

	# teleports: ring at the entrance, faint line to where it leads
	if LevelManager.route_guide:
		for tp in LevelManager.route_guide.teleports():
			var a := _to_map(tp.entry)
			var b := _to_map(tp.dest)
			draw_dashed_line(a, b, Color(TELEPORT_COLOR, 0.35), 1.0, 4.0)
			draw_circle(a, 5.5, Color(0, 0, 0, 0.8))
			draw_arc(a, 4.5, 0, TAU, 16, TELEPORT_COLOR, 2.0, true)
			draw_circle(b, 2.0, Color(TELEPORT_COLOR, 0.7))

	# route to the station (objective done)
	for seg in _route:
		if seg.size() < 2:
			continue
		var pts := PackedVector2Array()
		for q in seg:
			pts.append(_to_map(q))
		for i in range(1, pts.size()):
			draw_line(pts[i - 1], pts[i], Color(0, 0, 0, 0.55), 5.0)
		for i in range(1, pts.size()):
			draw_line(pts[i - 1], pts[i], Color(PLAYER_COLOR, 0.95), 2.5)

	# eco chests
	var chests_open := 0
	var chests_total := 0
	for chest in get_tree().get_nodes_in_group("eco_chest"):
		if not _level.is_ancestor_of(chest):
			continue
		chests_total += 1
		if chest.opened:
			chests_open += 1
		var p := _to_map(chest.global_position)
		draw_rect(Rect2(p - Vector2(5, 4), Vector2(10, 8)), Color(0, 0, 0, 0.85))
		draw_rect(Rect2(p - Vector2(4, 3), Vector2(8, 6)), Color(0.5, 0.5, 0.5) if chest.opened else CHEST_COLOR)

	var trash_left := 0
	var trash_total := 0
	for bag in get_tree().get_nodes_in_group("trashbag"):
		if not (bag is TrashBag) or not _level.is_ancestor_of(bag):
			continue
		trash_total += 1
		if bag._collected:
			continue
		trash_left += 1
		var p := _to_map(bag.global_position) + Vector2(0, sin(t * 3.0 + bag.global_position.x) * 1.5)
		draw_texture_rect(TRASH_ICON, Rect2(p - Vector2(7, 7), Vector2(14, 14)), false)

	var enemies := 0
	for node in _level.find_children("*", "CharacterBody2D", true, false):
		if node is Enemy and not node.is_dead:
			enemies += 1
			var p := _to_map(node.global_position)
			draw_circle(p, 4.0, Color(0, 0, 0, 0.8))
			draw_circle(p, 2.8, ENEMY_COLOR)

	for exit in get_tree().get_nodes_in_group("level_exit"):
		if not _level.is_ancestor_of(exit):
			continue
		var p := _to_map(exit.global_position)
		if exit.is_open:
			draw_arc(p, 11.0 + 2.0 * sin(t * 4.0), 0, TAU, 24, PLAYER_COLOR, 2.0, true)
		draw_texture_rect(STATION_ICON, Rect2(p - Vector2(8, 10), Vector2(16, 19)), false,
				Color.WHITE if exit.is_open else Color(0.6, 0.6, 0.65))

	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player and _level.is_ancestor_of(player):
		var p := _to_map(player.global_position)
		var pulse := 6.0 + 3.0 * (0.5 + 0.5 * sin(t * 5.0))
		draw_arc(p, pulse, 0, TAU, 24, Color(1, 1, 1, 0.9), 1.5, true)
		draw_circle(p, 5.0, Color(0, 0, 0, 0.85))
		draw_circle(p, 3.6, PLAYER_COLOR)

	_draw_legend(trash_left, trash_total, enemies, chests_open, chests_total)


func _draw_legend(trash_left: int, trash_total: int, enemies: int, chests_open: int, chests_total: int) -> void:
	var font := get_theme_default_font()
	var fs := 15
	var row1 := [[PLAYER_COLOR, "Tu"], [Color(0.3, 0.75, 0.35), "Punto di raccolta"]]
	if LevelManager.route_guide and not LevelManager.route_guide.teleports().is_empty():
		row1.append([TELEPORT_COLOR, "Teletrasporto"])
	var row2 := [[TRASH_COLOR, "Rifiuti %d/%d" % [trash_left, trash_total]], [ENEMY_COLOR, "Nemici: %d" % enemies]]
	if chests_total > 0:
		row2.append([CHEST_COLOR, "Forzieri %d/%d" % [chests_open, chests_total]])
	var rows := [row1, row2]
	var y := size.y - LEGEND_HEIGHT + 18.0
	for row in rows:
		var total_w := 0.0
		for e in row:
			total_w += 16.0 + font.get_string_size(e[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 18.0
		var x := (size.x - total_w + 18.0) / 2.0
		for e in row:
			draw_circle(Vector2(x + 5, y - 5), 5.0, Color(0, 0, 0, 0.85))
			draw_circle(Vector2(x + 5, y - 5), 3.6, e[0])
			x += 16.0
			draw_string_outline(font, Vector2(x, y), e[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.85))
			draw_string(font, Vector2(x, y), e[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
			x += font.get_string_size(e[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 18.0
		y += 20.0
