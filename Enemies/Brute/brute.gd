class_name Brute
extends NewEnemy
## Bruto: big, slow, armored. When it has a straight line to you it steams
## up (0.7 s), then charges. A hit costs 2 hearts; if it crashes into a wall
## it's stunned for 1.5 s and takes double damage. Up close it slams the
## ground.

const CHARGE_SPEED := 260.0
const CHARGE_TIME := 0.9
const WIND := 0.7
const STUN := 1.5
const SLAM_WIND := 0.4

var _state := "chase"
var _t := 0.0
var _charge_dir := Vector2.ZERO
var _charge_cd := 1.5
var _slam_cd := 0.0
var _hit_player := false


func _ready() -> void:
	knockback_force = 0.0
	stagger_time = 0.05
	can_be_interrupted = false
	super._ready()


func take_damage(dmg: int, attacker):
	if _state == "stunned":
		dmg *= 2
	super(dmg, attacker)


func _think(delta: float) -> void:
	var to: Vector2 = player.global_position - global_position
	var dist := to.length()
	_charge_cd -= delta
	_slam_cd -= delta
	match _state:
		"chase":
			_face(to)
			if dist < 26.0 and _slam_cd <= 0.0:
				_state = "slam"
				_t = SLAM_WIND
				_flash_wind(SLAM_WIND)
				input_direction = Vector2.ZERO
				return
			if _charge_cd <= 0.0 and dist > 50.0 and dist < 170.0 and _clear_line(player.global_position):
				_state = "wind"
				_t = WIND
				_charge_dir = to.normalized()
				_flash_wind(WIND)
				SFXManager.play_sfx(preload("res://Audio/SFX/MenuSFX/Unequip.wav"), -6)
				input_direction = Vector2.ZERO
				return
			var d := _path_dir(player.global_position, delta)
			input_direction = d
			_play("walk" if d != Vector2.ZERO else "idle")
		"wind":
			_t -= delta
			input_direction = Vector2.ZERO
			_charge_dir = _charge_dir.lerp(to.normalized(), 0.08).normalized()  # aims while steaming
			_face(_charge_dir)
			_play("wind")
			if _t <= 0.0:
				_state = "charge"
				_t = CHARGE_TIME
				_hit_player = false
		"charge":
			_t -= delta
			_face(_charge_dir)
			_play("attack")
			input_direction = _charge_dir * (CHARGE_SPEED / maxf(speed, 1.0))
			velocity = _charge_dir * CHARGE_SPEED
			if not _hit_player and dist < 22.0:
				_hit_player = true
				player.take_damage(LevelManager.enemy_hit_damage(2), self)
				player.soft_collision_vector += _charge_dir * 450.0
				_end_charge()
				return
			if blocked_by_map:  # a wall on a layer it doesn't collide with (City)
				_stun()
				return
			if get_slide_collision_count() > 0:
				for i in get_slide_collision_count():
					var col := get_slide_collision(i).get_collider()
					if col and not (col is Node and (col.is_in_group("player") or col.is_in_group("enemies"))):
						_stun()
						return
			if _t <= 0.0:
				_end_charge()
		"stunned":
			_t -= delta
			input_direction = Vector2.ZERO
			velocity = Vector2.ZERO
			_play("idle")
			if _t <= 0.0:
				_state = "chase"
				sprite.modulate = Color.WHITE
		"slam":
			_t -= delta
			input_direction = Vector2.ZERO
			_play("wind")
			if _t <= 0.0:
				_play("attack")
				if global_position.distance_to(player.global_position) < 34.0:
					player.take_damage(LevelManager.enemy_hit_damage(1), self)
				if player.has_method("_shake_camera"):
					player._shake_camera()
				_slam_cd = 1.6
				_state = "chase"


func _flash_wind(seconds: float) -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(1.9, 1.2, 0.6), seconds * 0.5)
	tw.tween_property(self, "modulate", Color(2.2, 1.0, 0.5), seconds * 0.5)
	tw.tween_property(self, "modulate", Color.WHITE, 0.15)


func _end_charge() -> void:
	_state = "chase"
	_charge_cd = 2.2
	velocity = Vector2.ZERO
	input_direction = Vector2.ZERO


func _stun() -> void:
	_state = "stunned"
	_t = STUN
	_charge_cd = 2.5
	velocity = Vector2.ZERO
	input_direction = Vector2.ZERO
	FloatText.spawn(self, "★ ★ ★", Color(1.0, 0.9, 0.4), Vector2(0, -52))
	sprite.modulate = Color(0.8, 0.8, 1.2)
	SFXManager.play_sfx(preload("res://Audio/SFX/Dmg/Damage.wav"), -4)
	var p := get_tree().get_first_node_in_group("player")
	if p and p.has_method("_shake_camera"):
		p._shake_camera()
