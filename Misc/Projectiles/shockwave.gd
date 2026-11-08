class_name Shockwave
extends Node2D
## Boarman's FRANA: he slams the ground and a shockwave runs RANGE pixels
## forward along the ground. Ground enemies it passes take DAMAGE and are
## knocked back; anything in group "flying" is above it and is skipped.
## Where the wave ends, rock chunks burst out of the ground: everything
## within ROCK_RADIUS, flying enemies INCLUDED, takes ROCK_DAMAGE (enemies
## already hit by the wave are not hit twice).

const RANGE := 150.0
const TRAVEL_TIME := 0.4
const WIDTH := 22.0
const DAMAGE := 2
const KNOCKBACK := 320.0
const ROCK_RADIUS := 30.0
const ROCK_DAMAGE := 2
const DUST := Color(0.62, 0.5, 0.36)
const ROCK := Color(0.45, 0.38, 0.32)

var caster: Node
var dir := Vector2.RIGHT
## Who was hit, for tests and so nobody is hit twice.
var wave_hits: Array[Node2D] = []
var rock_hits: Array[Node2D] = []
var _from: Vector2
var _t := 0.0
var _cracks: Array[Vector2] = []


static func slam(parent: Node, from: Vector2, direction: Vector2, by: Node) -> Shockwave:
	var s := Shockwave.new()
	s.dir = direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
	s.caster = by
	s._from = from
	s.z_index = 2  # on the ground, under the characters' heads
	parent.add_child(s)
	s.global_position = from
	return s


func _physics_process(delta: float) -> void:
	_t = minf(1.0, _t + delta / TRAVEL_TIME)
	var front := _from + dir * RANGE * _t
	global_position = front
	if _cracks.is_empty() or _cracks[-1].distance_to(front) > 12.0:
		_cracks.append(front)
	for n in HeroShot.targets(get_tree(), false):
		if n in wave_hits:
			continue
		# distance from the enemy's feet to the path walked so far
		var p := Geometry2D.get_closest_point_to_segment(n.global_position, _from, front)
		if p.distance_to(n.global_position) <= WIDTH * 0.5 + HeroShot.reach(n):
			wave_hits.append(n)
			HeroShot.hit(n, DAMAGE, caster)
			_knock(n)
	queue_redraw()
	if _t >= 1.0:
		set_physics_process(false)
		_rock_burst(front)


func _knock(n: Node2D) -> void:
	if n is Boss or not is_instance_valid(n) or n.get("is_dead") == true:
		return
	if n is CharacterBody2D:
		var away := dir
		if is_instance_valid(caster) and caster is Node2D:
			away = (n.global_position - caster.global_position).normalized()
		n.velocity = away * KNOCKBACK


func _rock_burst(at: Vector2) -> void:
	for n in HeroShot.targets(get_tree(), true):
		if n in wave_hits:
			continue
		# flying enemies hover above the ground: measure to their shadow too
		if n.global_position.distance_to(at) <= ROCK_RADIUS + HeroShot.reach(n):
			rock_hits.append(n)
			HeroShot.hit(n, ROCK_DAMAGE, caster)
	SFXManager.play_sfx(preload("res://Audio/SFX/Dmg/Damage.wav"), -8)
	_rock_fx(at)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)


func _rock_fx(at: Vector2) -> void:
	var fx := Node2D.new()
	fx.z_index = 18
	var r := {"v": 0.0}
	var chunks: Array = []
	for i in 7:
		var a := i * TAU / 7.0 + randf_range(-0.3, 0.3)
		chunks.append({"a": a, "d": randf_range(0.6, 1.0), "s": randf_range(3.0, 5.5), "spin": randf_range(-6, 6)})
	fx.draw.connect(func():
		var v: float = r.v
		fx.draw_circle(Vector2.ZERO, ROCK_RADIUS * (0.4 + 0.6 * v), Color(DUST, 0.35 * (1.0 - v)))
		for c in chunks:
			var ca: float = c.a
			var cd: float = c.d
			var flat := Vector2(cos(ca), sin(ca) * 0.55) * ROCK_RADIUS * cd * v
			var lift := Vector2(0, -34.0 * sin(v * PI) * cd)
			var pos: Vector2 = flat + lift
			var s: float = c.s
			var pts := PackedVector2Array()
			for k in 5:
				var ang: float = k * TAU / 5.0 + v * c.spin
				pts.append(pos + Vector2(cos(ang), sin(ang)) * s * (0.8 + 0.25 * (k % 2)))
			fx.draw_colored_polygon(pts, Color(ROCK, 1.0 - v * 0.6))
			fx.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.15, 0.12, 0.1, 1.0 - v * 0.6), 1.0))
	get_parent().add_child(fx)
	fx.global_position = at
	var tw := fx.create_tween()
	tw.tween_method(func(v: float):
		r.v = v
		fx.queue_redraw(), 0.0, 1.0, 0.45)
	tw.tween_callback(fx.queue_free)


func _draw() -> void:
	# cracks along the path walked so far (local coords: the node is at the front)
	for i in _cracks.size():
		var c := _cracks[i] - global_position
		var side := dir.orthogonal() * (5.0 if i % 2 == 0 else -5.0)
		draw_line(c - side, c + side * 0.4, Color(0.2, 0.15, 0.1, 0.8), 2.0)
	if _t < 1.0:
		# the wave front: a flat dust arc facing forward
		var a := dir.angle()
		draw_arc(Vector2.ZERO, WIDTH * 0.7, a - 1.2, a + 1.2, 12, Color(DUST, 0.9), 4.0)
		draw_arc(Vector2.ZERO - dir * 6.0, WIDTH * 0.6, a - 1.1, a + 1.1, 10, Color(DUST, 0.5), 3.0)
