class_name ZapBolt
extends Node2D
## Nerd's ZAP: an electric bolt from his home-made zapper. It flies RANGE
## pixels; the first enemy it touches takes DAMAGE and the spark jumps to the
## nearest other enemy within CHAIN_RADIUS (one jump, DAMAGE again).

const RANGE := 170.0
const SPEED := 560.0
const DAMAGE := 1
const CHAIN_RADIUS := 80.0
const CORE := Color(0.85, 1.0, 1.0)
const GLOW := Color(0.35, 0.85, 1.0, 0.55)

var shooter: Node
var dir := Vector2.RIGHT
## Set after a hit: [first_target, chained_target_or_null]
var hit_chain: Array = []
var _travelled := 0.0


static func fire(parent: Node, from: Vector2, direction: Vector2, by: Node) -> ZapBolt:
	var z := ZapBolt.new()
	z.dir = direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
	z.shooter = by
	z.z_index = 15
	parent.add_child(z)
	z.global_position = from
	z.rotation = z.dir.angle()
	return z


func _physics_process(delta: float) -> void:
	var step := SPEED * delta
	_travelled += step
	global_position += dir * step
	var targets := HeroShot.targets(get_tree())
	for n in targets:
		if HeroShot.is_touching(n, global_position, 3.0):
			_strike(n, targets)
			return
	if _travelled >= RANGE:
		queue_free()
	queue_redraw()


func _strike(first: Node2D, targets: Array[Node2D]) -> void:
	set_physics_process(false)
	var second: Node2D = null
	var best := CHAIN_RADIUS
	for n in targets:
		if n == first:
			continue
		var d := n.global_position.distance_to(first.global_position)
		if d <= best:
			best = d
			second = n
	hit_chain = [first, second]
	var from := first.global_position
	HeroShot.hit(first, DAMAGE, shooter)
	if second:
		_spark(from + Vector2(0, -8), second.global_position + Vector2(0, -8))
		HeroShot.hit(second, DAMAGE, shooter)
	_burst(from + Vector2(0, -8))
	queue_free()


## Jagged lightning between two points that fades out.
func _spark(a: Vector2, b: Vector2) -> void:
	var fx := Node2D.new()
	fx.z_index = 16
	var pts := PackedVector2Array([Vector2.ZERO])
	var seg := 6
	var normal := (b - a).orthogonal().normalized()
	for i in range(1, seg):
		pts.append((b - a) * float(i) / seg + normal * randf_range(-7.0, 7.0))
	pts.append(b - a)
	fx.draw.connect(func():
		fx.draw_polyline(pts, GLOW, 5.0)
		fx.draw_polyline(pts, CORE, 2.0))
	get_parent().add_child(fx)
	fx.global_position = a
	var tw := fx.create_tween()
	tw.tween_property(fx, "modulate:a", 0.0, 0.25)
	tw.tween_callback(fx.queue_free)


func _burst(at: Vector2) -> void:
	var fx := Node2D.new()
	fx.z_index = 16
	var r := {"v": 0.0}
	fx.draw.connect(func():
		for i in 6:
			var a := i * TAU / 6.0 + 0.3
			fx.draw_line(Vector2(cos(a), sin(a)) * 4.0, Vector2(cos(a), sin(a)) * (6.0 + 10.0 * r.v), Color(CORE, 1.0 - r.v), 2.0))
	get_parent().add_child(fx)
	fx.global_position = at
	var tw := fx.create_tween()
	tw.tween_method(func(v: float):
		r.v = v
		fx.queue_redraw(), 0.0, 1.0, 0.2)
	tw.tween_callback(fx.queue_free)


func _draw() -> void:
	# a short zig-zag spark pointing along +x (the node is rotated to `dir`)
	var pts := PackedVector2Array([Vector2(-10, 0), Vector2(-5, -3), Vector2(-1, 3), Vector2(4, -3), Vector2(9, 0)])
	draw_polyline(pts, GLOW, 6.0)
	draw_polyline(pts, CORE, 2.0)
	draw_circle(Vector2(9, 0), 2.5, CORE)
