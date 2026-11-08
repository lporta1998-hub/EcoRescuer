class_name Drone
extends NewEnemy
## Drone NEXUS: flies over walls and water (collision mask 0), circles you at
## about 90 px and fires a laser bolt every 1.8 s, then swoops in close for a
## moment (that's when melee heroes can hit it). Fragile: 2 HP.
## It's in the group "flying": ground attacks (the Boarman's shockwave) pass
## under it.

const ORBIT := 90.0
const SWOOP := 36.0
const RELOAD := 1.8
const AIM := 0.4

var _angle := 0.0
var _spin := 1.0
var _reload := 1.0
var _aim := 0.0
var _swoop := 0.0
var _bob := 0.0


func _ready() -> void:
	add_to_group("flying")
	collision_mask = 0
	z_index = 3  # above the treetops (the level y-sorts everything on the ground), under the fog
	knockback_force = 160.0
	super._ready()
	_angle = randf() * TAU


func _think(delta: float) -> void:
	var to: Vector2 = player.global_position - global_position
	_bob += delta
	sprite.position.y = (8 - (feet_y - frame_size / 2.0)) - 14.0 + sin(_bob * 4.0) * 2.0
	_face(to)
	if _aim > 0.0:
		_aim -= delta
		input_direction = input_direction * 0.85
		_play("wind")
		if _aim <= 0.0:
			var from := global_position + Vector2(0, sprite.position.y + 4)
			EnemyShot.fire_bolt(get_parent(), from, _where_player_will_be(0.25) - from, self)
			SFXManager.play_sfx(preload("res://Audio/SFX/Attacks/Arrow.wav"), -8)
			_swoop = 0.9
		return
	_reload -= delta
	if _reload <= 0.0 and to.length() < 200.0:
		_reload = RELOAD
		_aim = AIM
		if randf() < 0.35:
			_spin = -_spin
		return
	_swoop -= delta
	var radius := SWOOP if _swoop > 0.0 else ORBIT
	_angle += _spin * delta * 1.3
	var goal: Vector2 = player.global_position + Vector2(cos(_angle), sin(_angle) * 0.75) * radius
	var d := goal - global_position
	input_direction = d.normalized() * clampf(d.length() / 30.0, 0.0, 1.0)
	_play("idle")


func _idle(delta: float) -> void:
	_bob += delta
	sprite.position.y = (8 - (feet_y - frame_size / 2.0)) - 14.0 + sin(_bob * 3.0) * 2.0
	# hovers around its post
	var goal := _home + Vector2(sin(_bob * 0.7) * 24.0, cos(_bob * 0.5) * 12.0)
	var d := goal - global_position
	input_direction = d.normalized() * clampf(d.length() / 40.0, 0.0, 0.5)
	_play("idle")
	_update_patrol(delta)  # only to know if the player is near
	_sleeping = not _awake


func _draw() -> void:
	if is_dead:
		return
	# shadow on the ground, under the hovering drone
	draw_set_transform(Vector2(0, 8), 0, Vector2(1, 0.45))
	draw_circle(Vector2.ZERO, 7.0, Color(0, 0, 0, 0.28))


func _process(delta: float) -> void:
	super(delta)
	queue_redraw()
