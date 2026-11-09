class_name RouteGuide
extends RefCounted
## Finds the way to a target in levels split into areas joined by teleports
## (Forest, Snow Path), and the walking path inside an area (City streets).
##
## Walkability comes from the level's tiles, not the navigation mesh (which
## only covers part of some levels): an 8 px cell is floor if some TileMapLayer
## has a tile there and no tile's collision polygon covers part of that cell.
## 8 px is fine enough that thin collisions (bridge railings, fences on a tile
## edge) block only their own strip. An AStarGrid2D over the cells gives
## paths; two points are connected if a path exists.
## Teleports (group "teleport", with a `destination_marker`) link the areas,
## and a breadth-first search over them gives the chain of teleports to take,
## so the HUD arrow points at the next teleport instead of through walls.

const CELL := 8
## How far (in cells) a point may be from floor and still count as on it
## (players stand on edge tiles, teleports sit in doorways).
const SNAP_RADIUS := 8

var _grid := AStarGrid2D.new()
var _built := false
var _teleports: Array = []  # [{entry: Vector2, dest: Vector2}]
var _static_cache := {}


func _init(level: Node2D) -> void:
	_build_grid(level)
	for tp in level.get_tree().get_nodes_in_group("teleport"):
		if not level.is_ancestor_of(tp):
			continue
		var marker = tp.get("destination_marker")
		if marker is Node2D:
			_teleports.append({"entry": tp.global_position, "dest": marker.global_position})


func _build_grid(level: Node2D) -> void:
	var floor_cells := {}  # Vector2i -> true (floor) / false (blocked)
	# Only collisions the player actually bumps into count as walls (Polluted
	# Lake's water-surface layer has polygons on collision layer 0, which
	# collides with nothing, and you walk right over it).
	var player := level.get_tree().get_first_node_in_group("player") as CollisionObject2D
	var player_mask: int = player.collision_mask if player and level.is_ancestor_of(player) else 0xFFFFFFFF
	for layer in level.find_children("*", "TileMapLayer", true, false):
		var tml := layer as TileMapLayer
		if not tml.visible or tml.tile_set == null:
			continue
		var phys_layers: Array[int] = []
		if tml.collision_enabled:
			for i in tml.tile_set.get_physics_layers_count():
				if tml.tile_set.get_physics_layer_collision_layer(i) & player_mask:
					phys_layers.append(i)
		# every tile covers several cells (16 px tiles: 2x2, AI DataCenter's
		# 32 px tiles: 4x4). Which of them its collision blocks is the same for
		# every copy of a tile, so it's worked out once per tile type.
		var half := Vector2(tml.tile_set.tile_size) * tml.global_scale / 2.0
		var span := Vector2i(maxi(1, roundi(half.x * 2.0 / CELL)), maxi(1, roundi(half.y * 2.0 / CELL)))
		var masks := {}
		for c in tml.get_used_cells():
			var key := Vector4i(tml.get_cell_source_id(c), tml.get_cell_atlas_coords(c).x,
					tml.get_cell_atlas_coords(c).y, tml.get_cell_alternative_tile(c))
			var mask: PackedByteArray = masks.get(key, PackedByteArray())
			if mask.is_empty():
				mask = _tile_mask(tml.get_cell_tile_data(c), phys_layers, half, span, tml.global_scale)
				masks[key] = mask
			var center := tml.to_global(tml.map_to_local(c))
			var g0 := _cell_of(center - half + Vector2(CELL, CELL) / 2.0)
			for sy in span.y:
				for sx in span.x:
					var g := g0 + Vector2i(sx, sy)
					if mask[sy * span.x + sx] == 1:
						floor_cells[g] = false
					elif not floor_cells.has(g):
						floor_cells[g] = true
	_block_static_bodies(level, player_mask, floor_cells)
	if floor_cells.is_empty():
		return
	var minc := Vector2i(1 << 30, 1 << 30)
	var maxc := -minc
	for c in floor_cells:
		minc = Vector2i(mini(minc.x, c.x), mini(minc.y, c.y))
		maxc = Vector2i(maxi(maxc.x, c.x), maxi(maxc.y, c.y))
	_grid.region = Rect2i(minc, maxc - minc + Vector2i.ONE)
	_grid.cell_size = Vector2(CELL, CELL)
	_grid.offset = Vector2(CELL, CELL) / 2.0  # point = cell centre
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.update()
	_grid.fill_solid_region(_grid.region, true)
	for c in floor_cells:
		if floor_cells[c]:
			_grid.set_point_solid(c, false)
	_keep_paths_off_walls(floor_cells)
	_built = true


## Bodies are wider than a path line: an enemy walking the cells right next
## to a wall scrapes it and stalls. Cells near walls cost more, so paths keep
## a margin where there's room but can still squeeze through narrow spots.
func _keep_paths_off_walls(floor_cells: Dictionary) -> void:
	const NEAR := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var ring := []
	for c in floor_cells:
		if not floor_cells[c]:
			continue
		for d in NEAR:
			if not floor_cells.get(c + d, false):
				ring.append(c)
				break
	for c in ring:
		_grid.set_point_weight_scale(c, 4.0)
	for c in ring:
		for d in NEAR:
			var n: Vector2i = c + d
			if floor_cells.get(n, false) and _grid.get_point_weight_scale(n) < 2.0:
				_grid.set_point_weight_scale(n, 2.0)


## Props that are their own physics bodies (the truck on the Polluted Lake
## beach, destructible rocks...) block the cells under their shapes too.
static func _block_static_bodies(level: Node, player_mask: int, floor_cells: Dictionary) -> void:
	for body in level.find_children("*", "StaticBody2D", true, false):
		if not (body.collision_layer & player_mask):
			continue
		for shape_node in body.get_children():
			var poly := PackedVector2Array()
			if shape_node is CollisionShape2D and shape_node.shape and not shape_node.disabled:
				var r: Rect2 = shape_node.shape.get_rect()
				var xf: Transform2D = shape_node.global_transform
				poly = PackedVector2Array([xf * r.position, xf * Vector2(r.end.x, r.position.y), xf * r.end, xf * Vector2(r.position.x, r.end.y)])
			elif shape_node is CollisionPolygon2D and not shape_node.disabled:
				poly = shape_node.global_transform * shape_node.polygon
			if poly.size() < 3:
				continue
			var box := Rect2(poly[0], Vector2.ZERO)
			for q in poly:
				box = box.expand(q)
			var a := _cell_of(box.position)
			var b := _cell_of(box.end)
			for cy in range(a.y, b.y + 1):
				for cx in range(a.x, b.x + 1):
					var c := Vector2i(cx, cy)
					if floor_cells.has(c) and Geometry2D.is_point_in_polygon(Vector2(c * CELL) + Vector2(CELL, CELL) / 2.0, poly):
						floor_cells[c] = false


## Nearest point to `world` with open floor all around it (`clearance` cells
## each way), e.g. for the recycling station so it never sits in a wall.
func open_spot(world: Vector2, clearance := 3, search := 16) -> Vector2:
	if not _built:
		return world
	var c := _cell_of(world)
	for r in range(0, search + 1):
		var best := Vector2i.ZERO
		var best_d := INF
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var q := c + Vector2i(dx, dy)
				var ok := true
				for oy in range(-clearance, clearance + 1):
					for ox in range(-clearance, clearance + 1):
						var w := q + Vector2i(ox, oy)
						if not _grid.is_in_boundsv(w) or _grid.is_point_solid(w):
							ok = false
							break
					if not ok:
						break
				if ok and Vector2(dx, dy).length_squared() < best_d:
					best_d = Vector2(dx, dy).length_squared()
					best = q
		if best_d < INF:
			return Vector2(best * CELL) + Vector2(CELL, CELL) / 2.0
	return world


## Which cells of one tile its collision blocks: 1 = blocked, row by row.
static func _tile_mask(td: TileData, phys_layers: Array[int], half: Vector2, span: Vector2i, scale: Vector2) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(span.x * span.y)
	var polys := []
	if td:
		for i in phys_layers:
			for k in td.get_collision_polygons_count(i):
				polys.append(td.get_collision_polygon_points(i, k))
	if polys.is_empty():
		mask.fill(0)  # no collision: every cell is floor
		return mask
	for sy in span.y:
		for sx in span.x:
			# cell centre relative to the tile centre, in the tile's own pixels
			var local := (Vector2(sx, sy) * CELL + Vector2(CELL, CELL) / 2.0 - half) / scale
			mask[sy * span.x + sx] = 1 if _hits(polys, local, 2.5 / scale.x) else 0
	return mask


## True if a collision polygon covers part of the cell around `local`
## (sampled on a 3x3 grid, so thin wall strips still count).
static func _hits(polys: Array, local: Vector2, step: float) -> bool:
	for oy in [-step, 0.0, step]:
		for ox in [-step, 0.0, step]:
			var q := local + Vector2(ox, oy)
			for poly in polys:
				if Geometry2D.is_point_in_polygon(q, poly):
					return true
	return false


static func _cell_of(world: Vector2) -> Vector2i:
	return Vector2i((world / CELL).floor())


## True once the walkability grid is built (false for a level without tiles).
func is_ready() -> bool:
	return _built


## True if `world` is on open floor, where the player can stand. Enemies use
## it to stay inside the map: in some levels (City, part of Snow Path) the
## walls are on a collision layer enemies don't collide with.
func is_open(world: Vector2) -> bool:
	if not _built:
		return true
	var c := _cell_of(world)
	return _grid.is_in_boundsv(c) and not _grid.is_point_solid(c)


## True if open floor is within `radius` cells of `world` (flying enemies may
## cross walls and water, but not leave the playable area).
func near_open(world: Vector2, radius := 4) -> bool:
	if not _built:
		return true
	var c := _cell_of(world)
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var q := c + Vector2i(dx, dy)
			if _grid.is_in_boundsv(q) and not _grid.is_point_solid(q):
				return true
	return false


## Opens or closes the cells under a world rectangle (the boss arena gate).
func set_area_walkable(rect: Rect2, walkable: bool) -> void:
	if not _built:
		return
	var a := _cell_of(rect.position)
	var b := _cell_of(rect.end - Vector2(0.01, 0.01))
	for y in range(a.y, b.y + 1):
		for x in range(a.x, b.x + 1):
			var c := Vector2i(x, y)
			if _grid.is_in_boundsv(c):
				_grid.set_point_solid(c, not walkable)
	_static_cache.clear()


func teleports() -> Array:
	return _teleports


## Nearest floor cell to a world point (or the point's own cell).
func _snap(world: Vector2) -> Vector2i:
	var c := _cell_of(world)
	if not _built or (_grid.is_in_boundsv(c) and not _grid.is_point_solid(c)):
		return c
	for r in range(1, SNAP_RADIUS + 1):
		var best := Vector2i(1 << 30, 0)
		var best_d := INF
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var q := c + Vector2i(dx, dy)
				if _grid.is_in_boundsv(q) and not _grid.is_point_solid(q):
					var d := Vector2(dx, dy).length_squared()
					if d < best_d:
						best_d = d
						best = q
		if best_d < INF:
			return best
	return c


func _cell_path(from: Vector2, to: Vector2) -> Array[Vector2i]:
	var a := _snap(from)
	var b := _snap(to)
	if not _grid.is_in_boundsv(a) or not _grid.is_in_boundsv(b) \
			or _grid.is_point_solid(a) or _grid.is_point_solid(b):
		return []
	return _grid.get_id_path(a, b)


## Walking path in world coordinates ([from, to] if the grid isn't ready,
## [] if `to` can't be walked to).
func path(from: Vector2, to: Vector2) -> PackedVector2Array:
	if not _built:
		return PackedVector2Array([from, to])
	var out := PackedVector2Array()
	var cells := _cell_path(from, to)
	if cells.is_empty():
		return out
	out.append(from)
	for i in range(1, cells.size() - 1):
		out.append(Vector2(cells[i] * CELL) + Vector2(CELL, CELL) / 2.0)
	out.append(to)
	return out


func reachable(from: Vector2, to: Vector2) -> bool:
	return not _built or not _cell_path(from, to).is_empty()


## Same as reachable() but cached: for fixed points (teleports, targets).
func _reachable_cached(from: Vector2, to: Vector2) -> bool:
	var key := [_snap(from), _snap(to)]
	if not _static_cache.has(key):
		_static_cache[key] = reachable(from, to)
	return _static_cache[key]


## Teleports to take, in order, to get from `from` to `to`.
## [] if `to` can be walked to directly; null if there's no known way.
func teleport_chain(from: Vector2, to: Vector2):
	if reachable(from, to):
		return []
	# Breadth-first search: each state is "standing at the exit of a teleport".
	var queue := []
	var seen := {}
	for i in _teleports.size():
		if reachable(from, _teleports[i].entry):
			queue.append([i])
			seen[i] = true
	while not queue.is_empty():
		var chain: Array = queue.pop_front()
		var here: Vector2 = _teleports[chain[-1]].dest
		if _reachable_cached(here, to):
			var out := []
			for i in chain:
				out.append(_teleports[i])
			return out
		for i in _teleports.size():
			if not seen.has(i) and _reachable_cached(here, _teleports[i].entry):
				seen[i] = true
				queue.append(chain + [i])
	return null


## Where to walk next: {pos, teleport: bool}. Falls back to `to` itself.
func next_waypoint(from: Vector2, to: Vector2) -> Dictionary:
	var chain = teleport_chain(from, to)
	if chain is Array and not chain.is_empty():
		return {"pos": chain[0].entry, "teleport": true}
	return {"pos": to, "teleport": false}


## Walking segments of the whole route (one per area), for the map.
func route_segments(from: Vector2, to: Vector2) -> Array:
	var chain = teleport_chain(from, to)
	if chain == null:
		return []
	var segments := []
	var here := from
	for tp in chain:
		segments.append(path(here, tp.entry))
		here = tp.dest
	segments.append(path(here, to))
	return segments


## How far `to` is from `from` along the route: teleports used dominate,
## then walking distance. INF if unreachable.
func route_cost(from: Vector2, to: Vector2) -> float:
	var chain = teleport_chain(from, to)
	if chain == null:
		return INF
	var total := 0.0
	for seg in route_segments(from, to):
		for i in range(1, seg.size()):
			total += seg[i - 1].distance_to(seg[i])
	return chain.size() * 100000.0 + total
