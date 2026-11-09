class_name Sprayer
extends NewEnemy
## Spruzzatore: keeps its distance and lobs toxic sludge that leaves a puddle.
## It has to stop and aim before each shot (0.5 s), and backs off if you get
## close, but it's slower than you.

const KEEP_MIN := 70.0
const KEEP_MAX := 130.0
const FLEE := 50.0
const RELOAD := 2.2
const AIM := 0.5

var _reload := 1.2
var _aim := 0.0
var _recoil := 0.0
var _strafe := 1.0
var _strafe_t := 0.0


func _think(delta: float) -> void:
	var to: Vector2 = player.global_position - global_position
	var dist := to.length()
	_face(to)
	if _aim > 0.0:
		_aim -= delta
		input_direction = Vector2.ZERO
		_play("wind")
		if _aim <= 0.0:
			EnemyShot.lob_sludge(get_parent(), global_position + Vector2(0, -6), _where_player_will_be(0.35), self)
			SFXManager.play_sfx(preload("res://Audio/SFX/Eco/lob.wav"), -6)
			_recoil = 0.3
		return
	if _recoil > 0.0:
		_recoil -= delta
		input_direction = Vector2.ZERO
		_play("attack")
		return
	_reload -= delta
	if _reload <= 0.0 and dist < 190.0 and dist > 34.0:
		_reload = RELOAD
		_aim = AIM
		modulate = Color(1.4, 1.8, 1.2)
		create_tween().tween_property(self, "modulate", Color.WHITE, AIM)
		return
	_strafe_t -= delta
	if _strafe_t <= 0.0:
		_strafe_t = randf_range(1.2, 2.4)
		_strafe = -_strafe
	var dir := Vector2.ZERO
	if dist < FLEE:
		dir = -to.normalized()
	elif dist > KEEP_MAX:
		dir = _path_dir(player.global_position, delta)
	elif dist < KEEP_MIN:
		dir = -to.normalized() * 0.7
	else:
		dir = to.orthogonal().normalized() * _strafe * 0.45
	input_direction = dir
	_play("walk" if dir.length_squared() > 0.01 else "idle")
