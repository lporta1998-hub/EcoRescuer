class_name Boss
extends Character
## MECCA-RIFIUTI, the Barone dei Rifiuti's armored battle suit: the final boss.
## Asleep until activate(). Three phases by health:
##   1  walks at you and CHARGES (red wind-up, then a fast dash)
##   2  also THROWS toxic barrels that leave poison puddles
##   3  also SUMMONS Inquinatori and charges more often
## Touching it hurts. When it dies the level calls on_boss_defeated().

signal defeated
signal health_changed(current: float, maximum: float)

const SHEET := preload("res://Boss/mecca_rifiuti.png")
const MINION := preload("res://Default_Enemy/Enemy.tscn")
const FRAME := 128

@export var boss_health := 40.0
@export var walk_speed := 55.0
@export var charge_speed := 340.0

var active := false
var _state := "sleep"
var _timer := 0.0
var _charge_dir := Vector2.ZERO
var _next_attack := 2.5
var _contact_cd := 0.0
var _minions: Array = []
var _summon_countdown := 0
var _player: Node2D


func _ready() -> void:
	$AnimatedSprite2D.sprite_frames = _frames()
	$AnimatedSprite2D.play("empty")  # the Barone isn't on board yet
	max_health = boss_health
	health = boss_health
	speed = walk_speed
	super()
	add_to_group("boss")


func _frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var anims := {"idle": [[0, 0], [1, 0], [2, 0], [3, 0]], "walk": [[0, 1], [1, 1], [2, 1], [3, 1]],
		"windup": [[0, 2], [1, 2]], "charge": [[2, 2], [3, 2]], "throw": [[0, 3], [1, 3], [2, 3], [3, 3]],
		"hurt": [[0, 4]], "broken": [[1, 4], [2, 4], [3, 4]],
		"empty": [[0, 5], [1, 5]], "boot": [[2, 5], [3, 5], [0, 0]]}
	for a in anims:
		sf.add_animation(a)
		sf.set_animation_speed(a, {"idle": 4.0, "walk": 6.0, "windup": 8.0, "charge": 12.0, "throw": 8.0, "hurt": 1.0, "broken": 3.0, "empty": 1.5, "boot": 3.0}[a])
		sf.set_animation_loop(a, a in ["idle", "walk", "windup", "charge"])
		for c in anims[a]:
			var at := AtlasTexture.new()
			at.atlas = SHEET
			at.region = Rect2(c[0] * FRAME, c[1] * FRAME, FRAME, FRAME)
			sf.add_frame(a, at)
	return sf


func activate() -> void:
	active = true
	MusicManager.play_track("boss")
	_state = "chase"
	_next_attack = 2.0
	health_changed.emit(health, max_health)


func phase() -> int:
	var r := health / max_health
	return 1 if r > 0.66 else (2 if r > 0.33 else 3)


func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		return
	_player = get_tree().get_first_node_in_group("player") as Node2D
	if not active or _player == null:
		input_direction = Vector2.ZERO
		super(delta)
		return
	_contact_cd -= delta
	_timer -= delta
	var to_player := _player.global_position - global_position
	match _state:
		"chase":
			speed = walk_speed * (1.0 + 0.25 * (phase() - 1))
			input_direction = to_player.normalized() if to_player.length() > 30.0 else Vector2.ZERO
			$AnimatedSprite2D.play("walk" if input_direction != Vector2.ZERO else "idle")
			$AnimatedSprite2D.flip_h = to_player.x < 0
			_next_attack -= delta
			if _next_attack <= 0.0:
				_pick_attack()
		"windup":
			input_direction = Vector2.ZERO
			if _timer <= 0.0:
				_state = "charge"
				_timer = 0.9
				_charge_dir = (_player.global_position - global_position).normalized()
				$AnimatedSprite2D.play("charge")
		"charge":
			speed = charge_speed
			input_direction = _charge_dir
			velocity = _charge_dir * charge_speed
			if _timer <= 0.0 or get_slide_collision_count() > 0:
				_end_attack()
		"throw":
			input_direction = Vector2.ZERO
			if _timer <= 0.0:
				_end_attack()
	super(delta)
	_check_contact()


func _pick_attack() -> void:
	var p := phase()
	var roll := randf()
	# Phase 3: summon right away, then every third attack (if minions are down).
	if p >= 3:
		_summon_countdown -= 1
	if p >= 3 and _summon_countdown <= 0 and _alive_minions() < 3:
		_summon_countdown = 3
		_summon()
	elif p >= 2 and roll < 0.65:
		_throw()
	else:
		_state = "windup"
		_timer = 0.7 if p < 3 else 0.45
		$AnimatedSprite2D.play("windup")
		SFXManager.play_sfx(preload("res://Audio/SFX/Eco/charge.wav"), -6)


func _end_attack() -> void:
	_state = "chase"
	_next_attack = [0, 2.6, 2.1, 1.6][phase()]
	speed = walk_speed


func _throw() -> void:
	_state = "throw"
	_timer = 1.0
	$AnimatedSprite2D.play("throw")
	var n := 2 if phase() == 2 else 3
	for i in n:
		var target := _player.global_position + Vector2(randf_range(-50, 50), randf_range(-40, 40))
		# toxic plasma from the arm cannon
		_lob_barrel(global_position + Vector2(28 * (-1 if $AnimatedSprite2D.flip_h else 1), -80), target, 0.75 + i * 0.15)


func _lob_barrel(from: Vector2, to: Vector2, flight: float) -> void:
	var b := Node2D.new()
	b.z_index = 20
	b.draw.connect(func():
		b.draw_circle(Vector2.ZERO, 9.0, Color(0.35, 1.0, 0.45, 0.25))
		b.draw_circle(Vector2.ZERO, 5.5, Color(0.35, 1.0, 0.45, 0.85))
		b.draw_circle(Vector2(-1, -1), 2.5, Color(0.9, 1.0, 0.9)))
	get_parent().add_child(b)
	b.global_position = from
	var tw := b.create_tween()
	tw.tween_method(func(t: float):
		b.global_position = from.lerp(to, t) + Vector2(0, -60.0 * sin(t * PI))
		b.rotation = t * TAU, 0.0, 1.0, flight)
	tw.tween_callback(func():
		ToxicPuddle.spawn(get_parent(), to)
		FX.spawn("splash", get_parent(), to + Vector2(0, -8), Color.WHITE, 1.6, 0)
		b.queue_free())


func _summon() -> void:
	_state = "throw"
	_timer = 0.8
	FloatText.spawn(self, "RINFORZI!", Color(1.0, 0.5, 0.4), Vector2(0, -80))
	for i in 3:
		var m: Node2D = MINION.instantiate()
		get_parent().add_child(m)
		m.global_position = global_position + Vector2(cos(i * 2.1), sin(i * 2.1)) * 50.0
		_minions.append(m)


func _alive_minions() -> int:
	var n := 0
	for m in _minions:
		if is_instance_valid(m) and not m.is_dead:
			n += 1
	return n


func _check_contact() -> void:
	if _contact_cd > 0.0 or _player == null:
		return
	if global_position.distance_to(_player.global_position) < 46.0:
		_contact_cd = 0.6
		_player.take_damage(1, self)


func take_damage(dmg: int, attacker) -> void:
	if not active or is_dead:
		return
	super(dmg, attacker)
	health_changed.emit(health, max_health)


## Bosses don't get knocked back: just flash.
func _on_hurt(_away: Vector2) -> void:
	_flash(Color(2.2, 2.2, 2.2))


func handle_death() -> void:
	is_dead = true
	active = false
	velocity = Vector2.ZERO
	$CollisionShape2D.set_deferred("disabled", true)
	health_changed.emit(0.0, max_health)
	$AnimatedSprite2D.play("broken")
	for i in 8:
		FloatText.spawn(self, "BOOM", Color(1.0, 0.6 + randf() * 0.3, 0.2), Vector2(randf_range(-40, 40), randf_range(-70, -10)))
		SFXManager.play_sfx(preload("res://Audio/SFX/Dmg/Balloon Pop 1.wav"), -8)
		await get_tree().create_timer(0.22).timeout
	for m in _minions:
		if is_instance_valid(m) and not m.is_dead:
			m.health = 0
	defeated.emit()
