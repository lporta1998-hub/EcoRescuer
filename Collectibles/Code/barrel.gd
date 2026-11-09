## barrel.gd
## Leaking oil barrel: a hazard to clean up.
##
## The barrel sits in a toxic puddle. Standing in it slows the player down and
## costs a heart now and then (the first after FIRST_TICK seconds, then one
## every TICK seconds; i-frames and the Scudo still apply). Picking the barrel
## up (walking into it) secures it and the puddle dries up.
## Enemies are not affected.
extends Collectible
class_name OilBarrel

const PUDDLE_RADIUS := 38.0
const FIRST_TICK := 0.6
const TICK := 1.2
const SLOW := 0.6  # speed multiplier while in the puddle

var _puddle: Area2D
## The visible puddle: drawn in the level's floor layer (ToxicPuddle.floor_layer)
## so the ground tiles of the hand-made levels don't hide it.
var _decal: Node2D
var _victim: Node2D = null
var _tick := 0.0
var _t := 0.0


func _ready() -> void:
	add_to_group("barrel_hazard")
	points = 20
	bobbing = false
	super()
	_puddle = Area2D.new()
	_puddle.name = "Puddle"
	_puddle.collision_layer = 0
	_puddle.collision_mask = 1  # the player's physics layer
	_puddle.scale = Vector2(1.0, 0.6)  # flat, seen from above
	_puddle.position = Vector2(0, 6)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = PUDDLE_RADIUS
	shape.shape = circle
	_puddle.add_child(shape)
	_puddle.body_entered.connect(_on_puddle_entered)
	_puddle.body_exited.connect(_on_puddle_exited)
	add_child(_puddle)
	_decal = Node2D.new()
	_decal.name = "BarrelPuddle"
	_decal.scale = _puddle.scale
	_decal.draw.connect(_draw_puddle)
	var layer := ToxicPuddle.floor_layer(self)
	layer.add_child(_decal)
	if layer.z_index == 0 and z_index < 1:
		z_index = 1  # hand-made levels: the barrel itself above its puddle and the ground
	_decal.position = ToxicPuddle.floor_point(layer, _puddle.global_position)


func _exit_tree() -> void:
	if is_instance_valid(_decal):
		_decal.queue_free()


func magnet_enabled() -> bool:
	return false  # it has to be picked up on purpose


func _process(delta: float) -> void:
	super(delta)
	if _collected:
		return
	_t += delta
	if is_instance_valid(_decal):
		_decal.queue_redraw()
	if _victim == null:
		return
	if not is_instance_valid(_victim) or _victim.get("is_dead"):
		_victim = null
		return
	_tick -= delta
	if _tick <= 0.0:
		_tick = TICK
		if _victim.has_method("take_damage"):
			FloatText.spawn(_victim, "Tossico!", Color(0.6, 1.0, 0.3))
			_victim.take_damage(1, self)


func _on_puddle_entered(body: Node2D) -> void:
	if _collected or _victim != null or not body.is_in_group("player"):
		return
	_victim = body
	_tick = FIRST_TICK
	LevelManager.scale_player_speed(body, SLOW)


func _on_puddle_exited(body: Node2D) -> void:
	if body == _victim:
		_release_victim()


func _release_victim() -> void:
	if _victim and is_instance_valid(_victim):
		LevelManager.scale_player_speed(_victim, 1.0 / SLOW)
	_victim = null


func on_collect(_player: Node2D) -> void:
	SFXManager.play_sfx(preload("res://Audio/SFX/Eco/pickup.wav"), -8)
	_release_victim()
	if LevelManager.objective_hud and is_instance_valid(LevelManager.objective_hud):
		LevelManager.objective_hud.toast("Barile messo in sicurezza!", Color(0.6, 1.0, 0.45))
	# A copy of the puddle stays a moment after the barrel is gone, drying up.
	if not is_instance_valid(_decal):
		return
	var parent := _decal.get_parent()
	var dry := Node2D.new()
	dry.scale = _puddle.scale
	dry.draw.connect(func():
		dry.draw_circle(Vector2.ZERO, PUDDLE_RADIUS, Color(0.04, 0.05, 0.03, 0.55))
		dry.draw_arc(Vector2.ZERO, PUDDLE_RADIUS - 1.5, 0, TAU, 40, Color(0.45, 0.85, 0.15, 0.5), 2.5, true))
	parent.add_child.call_deferred(dry)
	dry.position = _decal.position
	dry.ready.connect(func():
		var tw := dry.create_tween()
		tw.tween_property(dry, "modulate:a", 0.0, 0.8)
		tw.parallel().tween_property(dry, "scale", dry.scale * 0.3, 0.8)
		tw.tween_callback(dry.queue_free), CONNECT_ONE_SHOT)


func _draw_puddle() -> void:
	var r := PUDDLE_RADIUS
	var wobble := sin(_t * 1.7) * 1.5
	_decal.draw_circle(Vector2.ZERO, r + wobble, Color(0.04, 0.05, 0.03, 0.55))
	_decal.draw_circle(Vector2(3, 2), r * 0.72, Color(0.08, 0.12, 0.04, 0.6))
	# toxic green rim
	var pulse := 0.45 + 0.25 * sin(_t * 3.0)
	_decal.draw_arc(Vector2.ZERO, r + wobble - 1.5, 0, TAU, 40, Color(0.45, 0.85, 0.15, pulse), 2.5, true)
	# oily rainbow sheen drifting around
	for i in 3:
		var a := _t * (0.4 + i * 0.15) + i * 2.1
		var p := Vector2(cos(a), sin(a)) * r * (0.35 + 0.15 * i)
		var hue := fmod(_t * 0.1 + i * 0.33, 1.0)
		_decal.draw_circle(p, 5.0 - i, Color.from_hsv(hue, 0.5, 1.0, 0.18))
	# bubbles
	for i in 4:
		var k := fmod(_t * 0.8 + i * 0.25, 1.0)
		var bp := Vector2(sin(i * 2.4) * r * 0.55, cos(i * 1.7) * r * 0.5)
		_decal.draw_arc(bp, 1.5 + k * 3.0, 0, TAU, 10, Color(0.6, 1.0, 0.3, 0.6 * (1.0 - k)), 1.0, true)
