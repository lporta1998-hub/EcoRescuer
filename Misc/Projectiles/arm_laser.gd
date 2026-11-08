class_name ArmLaser
extends Node2D
## ECO-9's LASER: a beam from the arm cannon that pierces everything along
## LENGTH pixels at once (DAMAGE each). The beam itself only lasts a moment.

const LENGTH := 160.0
const WIDTH := 10.0
const DAMAGE := 2
const SHOW_TIME := 0.18
const CORE := Color(0.85, 1.0, 0.9)
const GLOW := Color(0.25, 1.0, 0.55, 0.6)

var hits: Array[Node2D] = []
var _length := LENGTH


static func fire(parent: Node, from: Vector2, direction: Vector2, by: Node) -> ArmLaser:
	var l := ArmLaser.new()
	var dir := direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
	l.z_index = 15
	parent.add_child(l)
	l.global_position = from
	l.rotation = dir.angle()
	var to := from + dir * LENGTH
	for n in HeroShot.targets(parent.get_tree()):
		# the beam is at chest height; compare with the enemy's body, not its feet
		var body := n.global_position - HeroShot.HIT_OFFSET
		var p := Geometry2D.get_closest_point_to_segment(body, from, to)
		if p.distance_to(body) <= WIDTH * 0.5 + HeroShot.reach(n):
			l.hits.append(n)
	for n in l.hits:
		HeroShot.hit(n, DAMAGE, by)
	var tw := l.create_tween()
	tw.tween_property(l, "modulate:a", 0.0, SHOW_TIME).set_ease(Tween.EASE_IN)
	tw.tween_callback(l.queue_free)
	return l


func _draw() -> void:
	draw_line(Vector2.ZERO, Vector2(_length, 0), GLOW, WIDTH)
	draw_line(Vector2.ZERO, Vector2(_length, 0), CORE, WIDTH * 0.35)
	draw_circle(Vector2.ZERO, WIDTH * 0.7, GLOW)
	draw_circle(Vector2.ZERO, WIDTH * 0.35, CORE)
	draw_circle(Vector2(_length, 0), WIDTH * 0.45, GLOW)
