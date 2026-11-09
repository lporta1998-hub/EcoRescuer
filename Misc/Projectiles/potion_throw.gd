class_name PotionThrow
extends Node2D
## Mira's potion: flies in an arc to the target and splashes, hurting every
## enemy (and the boss) within SPLASH_RADIUS.

const ICON := preload("res://Misc/Projectiles/potion.png")
const SPLASH_RADIUS := 30.0
const FLIGHT := 0.42

var damage := 2
var thrower: Node
var _from: Vector2
var _to: Vector2
var _t := 0.0


static func throw(parent: Node, from: Vector2, to: Vector2, dmg: int, by: Node) -> void:
	var p := PotionThrow.new()
	p.damage = dmg
	p.thrower = by
	p._from = from
	p._to = to
	p.z_index = 20
	parent.add_child(p)
	p.global_position = from


func _process(delta: float) -> void:
	_t += delta / FLIGHT
	if _t >= 1.0:
		_splash()
		return
	global_position = _from.lerp(_to, _t) + Vector2(0, -42.0 * sin(_t * PI))
	rotation = _t * TAU * 1.5
	queue_redraw()


func _draw() -> void:
	draw_texture(ICON, -ICON.get_size() / 2.0)


func _splash() -> void:
	set_process(false)
	global_position = _to
	rotation = 0
	SFXManager.play_sfx(preload("res://Audio/SFX/Eco/splash.wav"), -6, 1.4)
	for node in get_tree().current_scene.find_children("*", "CharacterBody2D", true, false):
		if (node is Enemy or node is Boss) and not node.is_dead and node.global_position.distance_to(_to) <= SPLASH_RADIUS + 8.0:
			node.take_damage(damage, thrower if is_instance_valid(thrower) else null)
	var r := {"v": 0.0}
	var fx := Node2D.new()
	fx.draw.connect(func():
		fx.draw_circle(Vector2.ZERO, SPLASH_RADIUS * r.v, Color(0.75, 0.3, 0.95, 0.35 * (1.0 - r.v)))
		fx.draw_arc(Vector2.ZERO, SPLASH_RADIUS * r.v, 0, TAU, 28, Color(0.95, 0.7, 1.0, 1.0 - r.v), 2.0)
		for i in 6:
			var a := i * TAU / 6.0
			fx.draw_circle(Vector2(cos(a), sin(a)) * SPLASH_RADIUS * r.v * 0.8, 2.0, Color(0.9, 0.5, 1.0, 1.0 - r.v)))
	get_parent().add_child(fx)
	fx.global_position = _to
	fx.scale = Vector2(1.0, 0.7)
	var tw := fx.create_tween()
	tw.tween_method(func(v: float):
		r.v = v
		fx.queue_redraw(), 0.0, 1.0, 0.35)
	tw.tween_callback(fx.queue_free)
	queue_free()
