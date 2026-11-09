class_name ToxicPuddle
extends Area2D
## Poison puddle left by the boss's toxic barrels: standing in it costs a
## heart every TICK seconds (i-frames and the Scudo still apply). It dries up
## after LIFE seconds.

const RADIUS := 26.0
const LIFE := 6.0
const TICK := 1.0

var radius := RADIUS
var life := LIFE
var _t := 0.0
var _tick := 0.4
var _victim: Node2D


static func spawn(parent: Node, at: Vector2, r: float = RADIUS, l: float = LIFE) -> ToxicPuddle:
	var p := ToxicPuddle.new()
	p.radius = r
	p.life = l
	var layer := floor_layer(parent)
	layer.add_child(p)
	p.position = floor_point(layer, at)
	return p


## The node that puddles and other floor marks go in: above the ground tiles,
## under everything standing on them. The hand-made levels (Forest, Snow Path,
## City) draw their floor tile layers at z 0, in tree order, so a mark at
## z -1 was hidden under the ground there; the built levels y-sort everything
## and keep the ground at z -10.
static func floor_layer(near: Node) -> Node2D:
	# the level root: the child of the scene root above `near` (enemies and
	# items can sit in containers like "Enemies", "Collectibles" or a plain Node)
	var level: Node = near
	var top: Node = near.get_tree().root if near and near.is_inside_tree() else null
	while level and level.get_parent() and level.get_parent() != top:
		level = level.get_parent()
	if level == null or not (level is Node2D):
		return near as Node2D
	if level.has_meta("floor_decals") and is_instance_valid(level.get_meta("floor_decals")):
		return level.get_meta("floor_decals")
	var layer := Node2D.new()
	layer.name = "FloorDecals"
	level.set_meta("floor_decals", layer)
	layer.set_meta("level", level)
	var at := -1
	if level.y_sort_enabled:
		layer.z_index = -1
	else:
		layer.z_index = 0
		# right after the last floor tile layer (z 0 or below)
		for c in level.get_children():
			if c is TileMapLayer and c.z_index <= 0 and c.z_as_relative:
				at = c.get_index()
	if level.is_node_ready():
		level.add_child(layer)
		if at >= 0:
			level.move_child(layer, at + 1)
	else:  # the level is still setting up its children (barrels call this from _ready)
		level.add_child.call_deferred(layer)
		if at >= 0:
			level.move_child.call_deferred(layer, at + 1)
	return layer


## `world` (a global position) in the floor layer's coordinates. Works while
## the layer is still waiting to be added (some level roots aren't at 0,0).
static func floor_point(layer: Node2D, world: Vector2) -> Vector2:
	var level = layer.get_meta("level") if layer.has_meta("level") else null
	if level is Node2D and level.is_inside_tree():
		return level.to_local(world)
	return world


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	scale = Vector2(1.0, 0.6)
	var shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = radius
	shape.shape = c
	add_child(shape)
	body_entered.connect(func(b):
		if b.is_in_group("player"):
			_victim = b
			_tick = 0.4)
	body_exited.connect(func(b):
		if b == _victim:
			_victim = null)
	SFXManager.play_sfx(preload("res://Audio/SFX/Eco/splash.wav"), -8)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _victim and is_instance_valid(_victim):
		_tick -= delta
		if _tick <= 0.0:
			_tick = TICK
			_victim.take_damage(1, self)
	if _t > life:
		modulate.a = maxf(0.0, 1.0 - (_t - life) * 2.5)
		if _t > life + 0.4:
			queue_free()


func _draw() -> void:
	var grow := minf(1.0, _t * 5.0)
	draw_circle(Vector2.ZERO, radius * grow, Color(0.25, 0.5, 0.1, 0.55))
	draw_arc(Vector2.ZERO, radius * grow - 1.0, 0, TAU, 32, Color(0.6, 1.0, 0.25, 0.6 + 0.3 * sin(_t * 6.0)), 2.0)
	for i in 3:
		var k := fmod(_t * 0.9 + i * 0.33, 1.0)
		draw_arc(Vector2(sin(i * 2.0) * 10.0, cos(i * 1.4) * 8.0), 2.0 + k * 3.0, 0, TAU, 10, Color(0.7, 1.0, 0.3, 1.0 - k), 1.0)
