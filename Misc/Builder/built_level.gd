class_name BuiltLevel
extends Node2D
## A level built from a text map and an original tileset (every campaign
## level). Edit the map file to change the level: every character is one
## 16 px cell.
##
## Terrain:  .  floor        ,  path / plaza     _  special overlay
##           #  wall         ~  water / pool     =  bridge / walkway
##           &  dense mass: forest, machinery, containers, junk (blocks, filled with big props)
##           o  decor A      O  decor B          (space = nothing)
## Props (sprites, y-sorted with the characters, they block at the base):
##           T  big prop     x  medium prop      X  small prop       b  boat (on water)
## Things (they stand on floor):
##           P  player start     S  recycling station    D  secret dossier
##           B  trash bag        E  enemy                L  Elite enemy
##           C  coin             H  heart                F  speed feather
##           W  litter (small trash to pick up)
##           R  leaking barrel   K  eco chest (cost from `chest_costs`, in map order)
##           Z  boss             G  arena gate (floor, closes when the boss fight starts)
## Secrets (see SecretSpots):
##           V  breakable crates (close a secret passage)      Y  portal to the secret vault
## After the rows, a line "---" starts the extras, one per line, in map pixels:
##           tp X Y DX DY      a passage at X,Y that takes the player to DX,DY
##           turret X Y DIR    a wall turret (DIR: left, right, up, down)

const TILE := 16
const SCENES := {
	"B": "res://Collectibles/Scenes/trash_bag.tscn",
	"C": "res://Collectibles/Scenes/eco_token.tscn",
	"H": "res://Collectibles/Scenes/heart.tscn",
	"F": "res://Collectibles/Scenes/feather.tscn",
	"R": "res://Collectibles/Scenes/barile.tscn",
	"K": "res://Collectibles/Scenes/eco_chest.tscn",
	"E": "res://Default_Enemy/Enemy.tscn",
	"L": "res://EliteEnemy/Scenes/Elite.tscn",
	"S": "res://Misc/LevelExit/level_exit.tscn",
	"W": "res://Collectibles/Scenes/trash.tscn",
}
const TELEPORT_SCENE := "res://Levels/SnowPathLevel/Assets/Scenes/teleport_area.tscn"
const TELEPORT_ART := "res://Misc/Builder/Tiles/passage.png"
const TURRETS := {
	"left": "res://Levels/Ai DataCenter_level/Assets/Turrets/turret/turret.tscn",
	"right": "res://Levels/Ai DataCenter_level/Assets/Turrets/turretRight/turret.tscn",
	"up": "res://Levels/Ai DataCenter_level/Assets/Turrets/turretUp/turret.tscn",
	"down": "res://Levels/Ai DataCenter_level/Assets/Turrets/turretDown/turret.tscn",
}
## Atlas index of each terrain character (see the tileset generator).
const FLOORS := [0, 0, 0, 0, 1, 1, 2, 3, 4, 5]
const BLOCKING := [6, 7, 8, 9, 13, 14]
const WALL_TOP := 6
const WALL_FRONT := 7
const UNDER_WATER := 8
const MASS_EDGE := 9
const MASS := 14
const GATE := 13
const PROP_DIR := "res://Misc/Builder/Props/%s/%s.png"
## Prop sprites per theme and map character ("&" = what fills the dense masses).
const PROPS := {
	"ruins": {"T": ["tree_0", "tree_1", "tree_2", "tree_3"], "x": ["pillar_0", "pillar_1", "statue_0", "rock_0", "rock_1"],
			"X": ["bush_0", "bush_1"], "&": ["tree_0", "tree_1", "tree_2", "tree_3"], "b": []},
	"factory": {"T": ["machine_0", "tank_0", "tank_1", "pipes_0"], "x": ["drums_0", "crates_0"], "X": ["crates_0"],
			"&": ["pipes_0", "tank_0", "tank_1", "chimney_0", "pipes_0", "crates_0", "drums_0", "machine_0"], "b": []},
	"harbor": {"T": ["container_0", "container_1", "container_2"], "x": ["crates_0", "drums_0"], "X": ["bollard_0"],
			"&": ["container_0", "container_1", "container_2"], "b": ["boat_0"]},
	"fortress": {"T": ["junk_0", "junk_1", "car_0"], "x": ["tires_0", "drums_0", "banner_0"], "X": ["tires_0"],
			"&": ["junk_0", "junk_1"], "b": []},
	"forest": {"T": ["tree_0", "tree_1", "tree_2", "tree_0", "tree_1", "tree_3"], "x": ["rock_0", "stump_0", "bush_0"],
			"X": ["bush_0", "bush_1"], "&": ["tree_0", "tree_1", "tree_2", "tree_3"], "b": []},
	"snow": {"T": ["pine_0", "pine_1", "pine_2"], "x": ["rock_0", "crystal_0", "crystal_1"], "X": ["crystal_0", "rock_0"],
			"&": ["pine_0", "pine_1", "pine_2"], "b": []},
	"city": {"T": ["street_tree_0", "street_tree_1", "lamp_0"], "x": ["bench_0", "dumpster_0", "dumpster_1", "car_0", "car_1"],
			"X": ["hydrant_0", "lamp_0"], "&": ["street_tree_0", "street_tree_1"], "b": []},
	"lake": {"T": ["palm_0", "palm_1", "umbrella_0", "umbrella_1"], "x": ["crates_0", "rock_0"], "X": ["bollard_0", "rock_0"],
			"&": ["palm_0", "palm_1"], "b": ["boat_0"]},
	"datacenter": {"T": ["server_0", "server_1"], "x": ["console_0", "drum_0", "crates_0"], "X": ["drum_0", "crates_0"],
			"&": ["server_0", "server_1"], "b": []},
}
## Fog tint per theme (the Forest's drifting fog).
const FOG := {"ruins": Color(1, 1, 1, 0.8), "factory": Color(0.75, 1.0, 0.6, 0.7),
		"harbor": Color(0.9, 0.95, 1.0, 0.75), "fortress": Color(0.8, 0.7, 0.9, 0.7),
		"forest": Color(1, 1, 1, 0.8), "snow": Color(0.9, 0.95, 1.0, 0.85), "city": Color(0.9, 0.85, 0.8, 0.45),
		"lake": Color(1, 1, 1, 0.5), "datacenter": Color(0.6, 0.9, 1.0, 0.35)}
const FOG_SCENE := "res://Levels/Forest_level/Assets/Scenes/parallax_background.tscn"

@export_file("*.txt") var map_path := ""
@export_enum("ruins", "factory", "harbor", "fortress", "forest", "snow", "city", "lake", "datacenter") var theme := "ruins"
@export var chest_costs: Array[int] = [3, 5]
@export_file var music_path := ""
## Map given in code instead of map_path (the secret vaults).
var map_text := ""
## A room inside another level (SecretVault): only tiles, props and things;
## no fog, menus, camera limits or level setup.
var sub_area := false

var map: PackedStringArray
var extras: PackedStringArray  ## lines after "---" (teleports, turrets)
var ground: TileMapLayer   ## floor + collision of water and masses
var walls: TileMapLayer    ## walls, bridges, decor, gates (drawn over water and paths)
var gates: Array[Vector2i] = []
var boss_spawn := Vector2.INF
var bounds := Rect2()
var _built := false


func _notification(what: int) -> void:
	# Build as soon as the scene is instantiated, before it enters the tree:
	# Global.load_game() looks for "PlayerSpawn" right after instantiating.
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		build()


func _ready() -> void:
	if not _built:
		build()
	if sub_area:
		return
	_fit_camera()
	LevelManager.setup_level(self)
	if music_path != "" and ResourceLoader.exists(music_path):
		MusicManager.play_music(load(music_path))


func _exit_tree() -> void:
	get_tree().paused = false


func build() -> void:
	if _built:
		return
	_built = true
	var text := map_text
	if text == "":
		var f := FileAccess.open(map_path, FileAccess.READ)
		if f == null:
			push_error("BuiltLevel: map not found: " + map_path)
			return
		text = f.get_as_text()
	var parts := text.replace("\r", "").split("\n---\n")
	map = parts[0].split("\n")
	extras = parts[1].split("\n", false) if parts.size() > 1 else PackedStringArray()
	# characters, props, enemies and items are all children of the level:
	# sort them by their feet so you walk behind trees and in front of them
	y_sort_enabled = true
	var tiles := _make_tileset()
	ground = _layer("Ground", tiles, -10)
	var water := _layer("Water", _overlay_tileset("water"), -9, false)
	var path := _layer("Path", _overlay_tileset("path"), -8, false)
	walls = _layer("Walls", tiles, -7)
	var caps := _layer("WallCaps", tiles, -7, false)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(map_path)
	var chest_i := 0
	var w := 0
	for y in map.size():
		var row := map[y]
		w = maxi(w, row.length())
		for x in row.length():
			var ch := row[x]
			var cell := Vector2i(x, y)
			var pos := Vector2(x * TILE + TILE / 2.0, y * TILE + TILE / 2.0)
			var idx := _terrain(ch, x, y, rng)
			if idx >= 0:
				ground.set_cell(cell, 0, Vector2i(idx % 8, idx / 8))
			var top := _top(ch, x, y)
			if top >= 0:
				walls.set_cell(cell, 0, Vector2i(top % 8, top / 8))
			if ch == "#" and _char(x, y - 1) not in ["#", " "]:
				caps.set_cell(cell + Vector2i.UP, 0, Vector2i(WALL_TOP, 0))  # wall height, walk-behind
			_add_props(ch, x, y)
			match ch:
				"P":
					var m := Marker2D.new()
					m.name = "PlayerSpawn"
					m.position = pos
					add_child(m)
				"D":
					var d := Dossier.new()
					d.name = "Dossier"
					d.position = pos
					add_child(d)
				"Z":
					boss_spawn = pos
				"G":
					gates.append(cell)
				"V":
					var crate := BreakableCrate.new()
					crate.position = pos
					add_child(crate)
				"Y":
					var portal := SecretPortal.new()
					portal.name = "SecretPortal"
					portal.position = pos
					add_child(portal)
				"K":
					var chest = load(SCENES.K).instantiate()
					chest.cost = chest_costs[mini(chest_i, chest_costs.size() - 1)] if not chest_costs.is_empty() else 4
					chest_i += 1
					chest.position = pos
					add_child(chest)
				_:
					if SCENES.has(ch):
						var n: Node2D = load(SCENES[ch]).instantiate()
						n.position = pos
						add_child(n)
	bounds = Rect2(0, 0, w * TILE, map.size() * TILE)
	_add_extras()
	_fill_overlay(water, w, _is_water)
	_fill_overlay(path, w, _is_path)
	if sub_area:
		_own_children()
		return
	if ResourceLoader.exists(FOG_SCENE):
		var fog: Node2D = load(FOG_SCENE).instantiate()
		fog.name = "Fog"
		fog.set_script(null)
		fog.repeat_times = 3
		fog.modulate = FOG.get(theme, Color.WHITE)
		add_child(fog)
	_own_children()
	for menu in [["CompleteMenu", "res://Menu/Complete menu/complete_menu.tscn"],
			["GameOverMenu", "res://Menu/GameOverMenu/game_over_menu.tscn"],
			["PauseMenu", "res://Menu/PauseMenu/Scenes/pause_menu.tscn"]]:
		var m: Node = load(menu[1]).instantiate()
		m.name = menu[0]
		add_child(m)
		m.owner = self


## Teleports between the areas of a map, and wall turrets.
func _add_extras() -> void:
	for line in extras:
		var a := line.split(" ", false)
		if a.size() >= 5 and a[0] == "tp":
			var dest := Marker2D.new()
			dest.position = Vector2(float(a[3]), float(a[4]))
			add_child(dest)
			var tp: Area2D = load(TELEPORT_SCENE).instantiate()
			tp.position = Vector2(float(a[1]), float(a[2]))
			tp.destination_marker = dest
			if ResourceLoader.exists(TELEPORT_ART):
				var art := Sprite2D.new()
				art.texture = load(TELEPORT_ART)
				art.z_index = -6
				art.z_as_relative = false
				tp.add_child(art)
			add_child(tp)
		elif a.size() >= 4 and a[0] == "turret" and TURRETS.has(a[3]):
			var t: Node2D = load(TURRETS[a[3]]).instantiate()
			t.position = Vector2(float(a[1]), float(a[2]))
			add_child(t)


## Nodes made in code have no owner, and find_children() (used by LevelManager
## to count trash bags and connect collectibles) only returns owned nodes.
func _own_children() -> void:
	for c in get_children():
		c.owner = self


func _char(x: int, y: int) -> String:
	if y < 0 or y >= map.size() or x < 0 or x >= map[y].length():
		return " "
	return map[y][x]


func _terrain(ch: String, x: int, y: int, rng: RandomNumberGenerator) -> int:
	match ch:
		" ":
			return -1
		"~", "b":
			return UNDER_WATER
		"&":
			var inner := true
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if _char(x + d.x, y + d.y) != "&":
					inner = false
			return MASS if inner else MASS_EDGE
	return FLOORS[rng.randi_range(0, FLOORS.size() - 1)]


## What goes on the Walls layer (over water and paths).
func _top(ch: String, x: int, y: int) -> int:
	match ch:
		"#":
			var solid := true  # deep inside a wall block: dark roof
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					if _char(x + dx, y + dy) not in ["#", " "]:
						solid = false
			if solid:
				return MASS
			return WALL_TOP if _char(x, y + 1) == "#" else WALL_FRONT
		"=":
			return 10
		"o":
			return 11
		"O":
			return 12
		"_":
			return 15
	return -1


func _layer(layer_name: String, tiles: TileSet, z: int, collide := true) -> TileMapLayer:
	var l := TileMapLayer.new()
	l.name = layer_name
	l.tile_set = tiles
	l.z_index = z
	l.collision_enabled = collide
	l.navigation_enabled = false
	add_child(l)
	return l


## Water and path edges use a dual grid: one tile per grid corner, chosen by
## which of the 4 cells around it are water (or path), so shores and plaza
## borders are round instead of square.
func _fill_overlay(layer: TileMapLayer, w: int, test: Callable) -> void:
	layer.position = Vector2(-TILE / 2.0, -TILE / 2.0)
	for y in map.size() + 1:
		for x in w + 1:
			var idx := int(test.call(x - 1, y - 1)) + 2 * int(test.call(x, y - 1)) \
					+ 4 * int(test.call(x - 1, y)) + 8 * int(test.call(x, y))
			if idx > 0:
				layer.set_cell(Vector2i(x, y), 0, Vector2i(idx % 4, idx / 4))


func _is_water(x: int, y: int) -> bool:
	return _char(x, y) in ["~", "=", "b"]


func _is_path(x: int, y: int) -> bool:
	var c := _char(x, y)
	if c == "," or c == "_":
		return true
	if c in [".", "#", "~", "=", "&", " ", "b"]:
		return false
	# things and props standing on a plaza keep the plaza under them
	var n := 0
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if _char(x + d.x, y + d.y) in [",", "_"]:
			n += 1
	return n >= 2


func _add_props(ch: String, x: int, y: int) -> void:
	var set_: Dictionary = PROPS.get(theme, {})
	var key := ""
	var jitter := Vector2.ZERO
	if ch in ["T", "x", "X", "b"]:
		key = ch
	elif ch == "&":
		# keep the crates of a secret passage in sight: no canopy over them
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				if _char(x + dx, y + dy) == "V":
					return
		var edge := false
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if _char(x + d.x, y + d.y) != "&":
				edge = true
		if (y % 2 == 0 and (x + (y / 2) % 2 * 2) % 3 == 0) or (edge and (x + y) % 2 == 0):
			key = "&"
			jitter = Vector2(_hash(x, y, 1) % 7 - 3, _hash(x, y, 2) % 5 - 2)
	if key == "" or not set_.has(key) or set_[key].is_empty():
		return
	var names: Array = set_[key]
	var tex: Texture2D = load(PROP_DIR % [theme, names[_hash(x, y, 3) % names.size()]])
	if tex == null:
		return
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.offset = Vector2(-floorf(tex.get_width() / 2.0), -tex.get_height() + 3)
	s.position = Vector2(x * TILE + TILE / 2.0, y * TILE + 14) + jitter
	add_child(s)
	if key in ["T", "x", "X"]:
		# block only at the base, so you can walk behind the canopy / top
		var body := StaticBody2D.new()
		body.collision_layer = 2
		body.collision_mask = 0
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		var wide := 0.8 if theme == "harbor" and key == "T" else 0.45
		rect.size = Vector2(clampf(tex.get_width() * wide, 10.0, 40.0), 10.0)
		shape.shape = rect
		shape.position = Vector2(0, -4)
		body.add_child(shape)
		s.add_child(body)


func _hash(x: int, y: int, salt: int) -> int:
	return absi(hash(Vector3i(x, y, salt)))


func _overlay_tileset(kind: String) -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	var src := TileSetAtlasSource.new()
	src.texture = load("res://Misc/Builder/Tiles/%s_%s.png" % [theme, kind])
	src.texture_region_size = Vector2i(TILE, TILE)
	ts.add_source(src, 0)
	for i in range(1, 16):
		src.create_tile(Vector2i(i % 4, i / 4))
	return ts


func _make_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 2)  # walls: what players and enemies bump into
	ts.set_physics_layer_collision_mask(0, 0)
	var src := TileSetAtlasSource.new()
	src.texture = load("res://Misc/Builder/Tiles/%s.png" % theme)
	src.texture_region_size = Vector2i(TILE, TILE)
	ts.add_source(src, 0)
	var half := TILE / 2.0
	var square := PackedVector2Array([Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)])
	for i in 16:
		var c := Vector2i(i % 8, i / 8)
		src.create_tile(c)
		if i in BLOCKING:
			var td := src.get_tile_data(c, 0)
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 0, square)
	return ts


## Keep the camera inside the map.
func _fit_camera() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam:
		cam.limit_left = int(bounds.position.x)
		cam.limit_top = int(bounds.position.y)
		cam.limit_right = int(bounds.end.x)
		cam.limit_bottom = int(bounds.end.y)


## Boss arena: close the gate cells (iron bars that block).
func close_gates() -> void:
	for c in gates:
		walls.set_cell(c, 0, Vector2i(GATE % 8, GATE / 8))


func open_gates() -> void:
	for c in gates:
		walls.erase_cell(c)
