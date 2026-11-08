class_name NewEnemy
extends Enemy
## Shared parts of the new enemy types (Spruzzatore, Bruto, Drone, Kamikaze):
## animations built from one sprite sheet, facing, simple steering, the
## "lost sight" memory and patrolling of the basic enemy. Each type only
## writes _think(delta), called while it is chasing the player.
##
## Sheet layout (see Tools/art/enemies.py): rows down / up / side / death,
## columns idle x2, walk x4, windup, attack. `directional = false` (drone):
## row 0 = hover x4, windup x2, hit; row 1 = death.

@export var sheet: Texture2D
@export var frame_size := 40
@export var directional := true
## Where the feet are, in the frame (pixels from the top).
@export var feet_y := 37

var facing := "down"
var _last_anim := ""
var _sleeping := false


func _ready() -> void:
	sprite.sprite_frames = _build_frames()
	sprite.centered = true
	sprite.position = Vector2(0, 8 - (feet_y - frame_size / 2.0))
	super._ready()
	_health_bar.position = Vector2(0, sprite.position.y - frame_size / 2.0 + 2)
	_play("idle")


func _build_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var f := frame_size
	var anims := {}
	if directional:
		var rows := {"down": 0, "up": 1, "side": 2}
		for d in rows:
			var r: int = rows[d]
			anims["idle_" + d] = [[0, r], [1, r]]
			anims["walk_" + d] = [[2, r], [3, r], [4, r], [5, r]]
			anims["wind_" + d] = [[6, r]]
			anims["attack_" + d] = [[7, r]]
		anims["death"] = [[0, 3], [1, 3], [2, 3], [3, 3]]
	else:
		anims["idle_"] = [[0, 0], [1, 0], [2, 0], [3, 0]]
		anims["walk_"] = anims["idle_"]
		anims["wind_"] = [[4, 0], [5, 0]]
		anims["attack_"] = [[6, 0]]
		anims["death"] = [[0, 1], [1, 1], [2, 1], [3, 1]]
	for a in anims:
		sf.add_animation(a)
		sf.set_animation_speed(a, 6.0 if a.begins_with("walk") else (8.0 if directional or a != "idle_" else 10.0))
		sf.set_animation_loop(a, a != "death")
		for c in anims[a]:
			var at := AtlasTexture.new()
			at.atlas = sheet
			at.region = Rect2(c[0] * f, c[1] * f, f, f)
			sf.add_frame(a, at)
	if not directional:
		sf.set_animation_speed("death", 6.0)
	return sf


## Plays "<state>_<facing>" (the side row is flipped for left).
func _play(state: String) -> void:
	var a := state + "_" + (facing if directional else "")
	if a != _last_anim:
		_last_anim = a
		sprite.play(a)


func _face(v: Vector2) -> void:
	if v.length_squared() < 0.01 or not directional:
		if not directional and absf(v.x) > 0.1:
			sprite.flip_h = v.x < 0
		return
	if absf(v.x) > absf(v.y):
		facing = "side"
		sprite.flip_h = v.x < 0
	else:
		facing = "down" if v.y > 0 else "up"
		sprite.flip_h = false


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if _stagger > 0.0:
		_stagger -= delta
		input_direction = Vector2.ZERO
		_move()
		return
	_update_memory(delta)
	if chasing and player and is_instance_valid(player):
		_sleeping = false
		_think(delta)
	else:
		_idle(delta)
		if _sleeping:
			return
	_move()


## Overridden by each type.
func _think(_delta: float) -> void:
	pass


func _idle(delta: float) -> void:
	_update_patrol(delta)
	if _patrolling and not _path_finished():
		var d := (_next_path_point() - global_position).normalized()
		input_direction = d * 0.5
		_face(d)
		_play("walk")
		_sleeping = false
	else:
		input_direction = Vector2.ZERO
		_play("idle")
		# nobody around: no physics this frame (same trick as the basic enemy)
		_sleeping = not _awake and velocity.length_squared() < 1.0 and soft_collision_vector == Vector2.ZERO


## The basic enemy's "keep following for a while after losing sight".
func _update_memory(delta: float) -> void:
	if chasing and not _in_sight:
		_memory -= delta
		if _memory <= 0.0 or player == null or not is_instance_valid(player):
			chasing = false
			player = null
			_path = PackedVector2Array()
			_path_index = 0


func _move() -> void:
	velocity += soft_collision_vector
	soft_collision_vector = Vector2.ZERO
	move_and_slide()


## Direction along the grid path to `goal` (repaths every REPATH_INTERVAL).
func _path_dir(goal: Vector2, delta: float) -> Vector2:
	_repath_timer -= delta
	if _repath_timer <= 0.0 or _path_finished():
		_repath_timer = REPATH_INTERVAL
		_set_path_to(goal)
	if _path_finished():
		return Vector2.ZERO
	return (_next_path_point() - global_position).normalized()


## True if nothing solid (walls, water edges) is between here and `to`.
func _clear_line(to: Vector2) -> bool:
	var q := PhysicsRayQueryParameters2D.create(global_position, to, 2 | 16 | 256, [get_rid()])
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	return hit.is_empty() or (hit.collider is Node and hit.collider.is_in_group("player"))


func _where_player_will_be(lead: float) -> Vector2:
	return player.global_position + player.velocity * lead


## The basic enemy's melee code isn't used by the new types.
func _on_frame_changed():
	pass
