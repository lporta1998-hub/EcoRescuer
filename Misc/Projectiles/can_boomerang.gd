class_name CanBoomerang
extends Node2D
## Labra's LATTINA: a recycled can thrown like a boomerang. It flies out
## RANGE pixels, then comes back to Labra. Every enemy can be hit once on the
## way out and once on the way back (DAMAGE each time). Drawn in code.

const RANGE := 140.0
const OUT_TIME := 0.38
const RETURN_SPEED := 330.0
const DAMAGE := 1
const MAX_LIFE := 2.5

var thrower: Node2D
var returning := false
var _from: Vector2
var _dir := Vector2.RIGHT
var _t := 0.0
var _life := 0.0
var _hit_out := {}
var _hit_back := {}


static func throw(parent: Node, from: Vector2, direction: Vector2, by: Node2D) -> CanBoomerang:
	var c := CanBoomerang.new()
	c.thrower = by
	c._from = from
	c._dir = direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
	c.z_index = 15
	parent.add_child(c)
	c.global_position = from
	return c


func _physics_process(delta: float) -> void:
	_life += delta
	rotation += delta * 22.0
	if not returning:
		_t = minf(1.0, _t + delta / OUT_TIME)
		# ease out: fast at the start, it "hangs" at the far end
		global_position = _from + _dir * RANGE * (1.0 - pow(1.0 - _t, 2.0))
		if _t >= 1.0:
			returning = true
	else:
		if not is_instance_valid(thrower) or thrower.get("is_dead") == true or _life > MAX_LIFE:
			queue_free()
			return
		var home := thrower.global_position + Vector2(0, -14)
		var to_home := home - global_position
		if to_home.length() <= RETURN_SPEED * delta + 6.0:
			queue_free()
			return
		global_position += to_home.normalized() * RETURN_SPEED * delta
	_check_hits()
	queue_redraw()


func _check_hits() -> void:
	var hits := _hit_back if returning else _hit_out
	for n in HeroShot.targets(get_tree()):
		if hits.has(n) or not HeroShot.is_touching(n, global_position, 2.0):
			continue
		hits[n] = true
		HeroShot.hit(n, DAMAGE, thrower)


func _draw() -> void:
	# a small crushed can seen from the side: grey body, green recycle band
	var body := Rect2(-5, -7, 10, 14)
	draw_rect(body.grow(1), Color(0.1, 0.12, 0.12))
	draw_rect(body, Color(0.78, 0.82, 0.85))
	draw_rect(Rect2(-5, -2, 10, 4), Color(0.25, 0.75, 0.35))
	draw_rect(Rect2(-5, -7, 10, 2), Color(0.55, 0.58, 0.62))
	draw_rect(Rect2(-3, -6, 2, 10), Color(1, 1, 1, 0.5))
