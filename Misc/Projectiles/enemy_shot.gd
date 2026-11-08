class_name EnemyShot
extends Area2D
## Enemy projectiles: the Spruzzatore's sludge blob (lobbed in an arc, leaves
## a toxic puddle where it lands) and the drone's laser bolt (straight line).
##
## Deflect: they sit on collision layer 3 (value 4, like enemy bodies) so the
## heroes' HurtBox (mask 5) overlaps them; a melee swing calls deflect(),
## which sends the shot back at whoever fired it, now hurting enemies.

enum Kind { SLUDGE, BOLT }

var kind := Kind.BOLT
var shooter: Node2D
var from := Vector2.ZERO
var target := Vector2.ZERO
var deflected := false
var _vel := Vector2.ZERO
var _t := 0.0
var _flight := 0.8
var _life := 1.8


static func lob_sludge(parent: Node, at: Vector2, to: Vector2, by: Node2D) -> EnemyShot:
	var s := EnemyShot.new()
	s.kind = Kind.SLUDGE
	s.shooter = by
	s.from = at
	s.target = to
	s._flight = clampf(at.distance_to(to) / 170.0, 0.45, 1.0)
	parent.add_child(s)
	s.global_position = at
	return s


static func fire_bolt(parent: Node, at: Vector2, dir: Vector2, by: Node2D) -> EnemyShot:
	var s := EnemyShot.new()
	s.kind = Kind.BOLT
	s.shooter = by
	s._vel = dir.normalized() * 160.0
	s.rotation = dir.angle()
	parent.add_child(s)
	s.global_position = at
	return s


func _ready() -> void:
	add_to_group("deflectable")
	collision_layer = 4
	collision_mask = 0
	monitoring = false
	monitorable = true
	z_index = 20
	var shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 7.0
	shape.shape = c
	add_child(shape)


## Called by a hero's melee swing: back to sender, now an ally.
func deflect(by: Node) -> void:
	if deflected:
		return
	deflected = true
	SFXManager.play_sfx(preload("res://Audio/SFX/MenuSFX/Unequip.wav"), -6)
	var back: Vector2 = shooter.global_position if is_instance_valid(shooter) else global_position - _vel
	shooter = by as Node2D
	if kind == Kind.BOLT:
		_vel = (back - global_position).normalized() * 220.0
		rotation = _vel.angle()
		_life = 1.5
	else:
		from = global_position
		target = back
		_t = 0.0
		_flight = clampf(from.distance_to(target) / 200.0, 0.35, 0.8)


func _process(delta: float) -> void:
	_t += delta
	if kind == Kind.BOLT:
		_life -= delta
		global_position += _vel * delta
		if _life <= 0.0:
			queue_free()
			return
		_check_hit(10.0, 1)
	else:
		var k := minf(1.0, _t / _flight)
		global_position = from.lerp(target, k) + Vector2(0, -42.0 * sin(k * PI))
		if k >= 1.0:
			_land()
			return
	queue_redraw()


func _check_hit(reach: float, dmg: int) -> void:
	if deflected:
		for e in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(e) and not e.is_dead and e.global_position.distance_to(global_position) < reach + 4.0:
				e.take_damage(dmg, shooter if is_instance_valid(shooter) else null)
				queue_free()
				return
	else:
		var p := get_tree().get_first_node_in_group("player") as Node2D
		if p and p.global_position.distance_to(global_position + Vector2(0, 4)) < reach:
			p.take_damage(LevelManager.enemy_hit_damage(dmg), shooter if is_instance_valid(shooter) else self)
			queue_free()


func _land() -> void:
	if deflected:
		# splashes the polluters instead
		for e in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(e) and not e.is_dead and e.global_position.distance_to(global_position) < 22.0:
				e.take_damage(1, shooter if is_instance_valid(shooter) else null)
	else:
		ToxicPuddle.spawn(get_parent(), global_position, 18.0, 4.0)
	queue_free()


func _draw() -> void:
	if kind == Kind.BOLT:
		var c := Color(1.0, 0.25, 0.2) if not deflected else Color(0.4, 1.0, 0.5)
		draw_line(Vector2(-7, 0), Vector2(5, 0), Color(c, 0.35), 5.0)
		draw_line(Vector2(-6, 0), Vector2(5, 0), c, 2.0)
		draw_circle(Vector2(5, 0), 1.6, Color(1, 1, 0.9))
	else:
		var k := minf(1.0, _t / _flight)
		# shadow on the ground, under the blob
		var ground := from.lerp(target, k) - global_position
		draw_set_transform(ground, 0, Vector2(1, 0.5))
		draw_circle(Vector2.ZERO, 4.0, Color(0, 0, 0, 0.3))
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		var col := Color(0.45, 0.9, 0.25) if not deflected else Color(0.9, 0.95, 0.4)
		draw_circle(Vector2.ZERO, 4.5, Color(col, 0.35))
		draw_circle(Vector2.ZERO, 3.0, col)
		draw_circle(Vector2(-1, -1), 1.0, Color(0.9, 1, 0.8))
