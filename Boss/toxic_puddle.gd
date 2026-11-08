class_name ToxicPuddle
extends Area2D
## Poison puddle left by the boss's toxic barrels: standing in it costs a
## heart every TICK seconds (i-frames and the Scudo still apply). It dries up
## after LIFE seconds.

const RADIUS := 26.0
const LIFE := 6.0
const TICK := 1.0

var _t := 0.0
var _tick := 0.4
var _victim: Node2D


static func spawn(parent: Node, at: Vector2) -> ToxicPuddle:
	var p := ToxicPuddle.new()
	parent.add_child(p)
	p.global_position = at
	return p


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	z_index = -1
	scale = Vector2(1.0, 0.6)
	var shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = RADIUS
	shape.shape = c
	add_child(shape)
	body_entered.connect(func(b):
		if b.is_in_group("player"):
			_victim = b
			_tick = 0.4)
	body_exited.connect(func(b):
		if b == _victim:
			_victim = null)
	SFXManager.play_sfx(preload("res://Audio/SFX/Objects/Collection.wav"), -12)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _victim and is_instance_valid(_victim):
		_tick -= delta
		if _tick <= 0.0:
			_tick = TICK
			_victim.take_damage(1, self)
	if _t > LIFE:
		modulate.a = maxf(0.0, 1.0 - (_t - LIFE) * 2.5)
		if _t > LIFE + 0.4:
			queue_free()


func _draw() -> void:
	var grow := minf(1.0, _t * 5.0)
	draw_circle(Vector2.ZERO, RADIUS * grow, Color(0.25, 0.5, 0.1, 0.55))
	draw_arc(Vector2.ZERO, RADIUS * grow - 1.0, 0, TAU, 32, Color(0.6, 1.0, 0.25, 0.6 + 0.3 * sin(_t * 6.0)), 2.0)
	for i in 3:
		var k := fmod(_t * 0.9 + i * 0.33, 1.0)
		draw_arc(Vector2(sin(i * 2.0) * 10.0, cos(i * 1.4) * 8.0), 2.0 + k * 3.0, 0, TAU, 10, Color(0.7, 1.0, 0.3, 1.0 - k), 1.0)
