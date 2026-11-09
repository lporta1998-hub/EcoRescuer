class_name MapFixes
extends RefCounted
## Invisible blockers that fill narrow pockets and notches where a hero could
## get wedged (found by pushing hero-sized bodies into every wall-side spot of
## each map, see Tools/README). Each rectangle is solid for heroes and enemies.

const RECTS := {
	"res://Levels/City_level/Assets/Scenes/city.tscn": [
		Rect2(2303, 737, 10, 17), Rect2(2303, 791, 10, 16), Rect2(2303, 935, 10, 16), Rect2(2479, 983, 10, 10),
		Rect2(999, 1224, 10, 10), Rect2(2823, 1163, 10, 10), Rect2(999, 1291, 10, 10), Rect2(1503, 1357, 10, 10),
		Rect2(1839, 1416, 10, 10), Rect2(2063, 1471, 10, 10), Rect2(799, 1479, 10, 16), Rect2(799, 1527, 10, 16),
		Rect2(799, 1591, 10, 16), Rect2(1951, 1666, 10, 10), Rect2(2702, 1663, 10, 10), Rect2(2063, 1775, 10, 10),
		Rect2(783, 2039, 10, 16), Rect2(943, 2168, 10, 10), Rect2(2063, 2962, 10, 10), Rect2(2623, 3511, 10, 10),
		Rect2(2900, 398, 10, 10), Rect2(2332, 775, 10, 10), Rect2(1348, 974, 10, 10), Rect2(2770, 1039, 10, 10),
		Rect2(826, 1511, 10, 10), Rect2(1309, 1972, 10, 10), Rect2(1309, 2163, 10, 10), Rect2(2340, 2589, 10, 10),
		Rect2(1803, 2759, 10, 10), Rect2(2559, 2809, 10, 10), Rect2(772, 2973, 10, 10), Rect2(1252, 3262, 10, 10),
		Rect2(2791, 809, 10, 10), Rect2(2786, 783, 10, 10),
	],
	"res://Levels/Forest_level/Assets/Scenes/forest.tscn": [
		Rect2(1541, 574, 11, 10), Rect2(1032, 958, 10, 10),
	],
	"res://Levels/SnowPathLevel/Assets/Scenes/snow_path.tscn": [
		Rect2(-545, -209, 2518, 62),
	],
	"res://Levels/Ai DataCenter_level/Assets/Scenes/Ai DataCenter.tscn": [
		Rect2(-704, 1887, 45, 194), Rect2(2111, 1887, 40, 194), Rect2(1206, -190, 10, 10), Rect2(1202, -155, 10, 10),
		Rect2(93, 571, 12, 14), Rect2(82, 613, 10, 10), Rect2(-704, 1767, 23, 138), Rect2(2111, 1767, 40, 138),
	],
}


static func apply(level: Node) -> void:
	var rects: Array = RECTS.get(level.scene_file_path, [])
	if rects.is_empty() or OS.has_environment("ECO_NO_MAPFIX"):  # (the env var is for comparing in tests)
		return
	var body := StaticBody2D.new()
	body.name = "MapFixes"
	body.collision_layer = 1 | 2 | 16 | 256  # what heroes and enemies bump into
	body.collision_mask = 0
	for r: Rect2 in rects:
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = r.size
		cs.shape = shape
		cs.position = r.get_center()
		body.add_child(cs)
	level.add_child(body)
	body.owner = level
