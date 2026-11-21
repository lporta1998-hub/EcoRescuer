class_name MapFixes
extends RefCounted
## Invisible blockers that fill narrow pockets and notches where a hero could
## get wedged (found by pushing hero-sized bodies into every wall-side spot of
## each map, see Tools/README). Each rectangle is solid for heroes and enemies.

const RECTS := {}


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
