class_name Bomber
extends NewEnemy
## Kamikaze: runs at you with a leaking barrel. Close up it stops, the fuse
## sparks and it blinks red for 0.9 s, then BOOM: 1 heart to you, damage to
## other polluters nearby, and a toxic puddle. Kill it before the fuse ends
## and the barrel just leaks.

const FUSE := 0.9
const BLAST := 36.0

var _fuse := 0.0
var _exploded := false


func _think(delta: float) -> void:
	var to: Vector2 = player.global_position - global_position
	if _fuse > 0.0:
		_fuse -= delta
		input_direction = Vector2.ZERO
		_play("wind")
		modulate = Color(2.2, 0.6, 0.5) if int(_fuse * 12.0) % 2 == 0 else Color.WHITE
		if _fuse <= 0.0:
			_explode()
		return
	_face(to)
	if to.length() < 28.0:
		_fuse = FUSE
		SFXManager.play_sfx(preload("res://Audio/SFX/Eco/fuse.wav"), -4)
		FloatText.spawn(self, "!!", Color(1.0, 0.4, 0.3), Vector2(0, -36))
		return
	var d := _path_dir(player.global_position, delta)
	input_direction = d
	_play("walk" if d != Vector2.ZERO else "idle")


func _explode() -> void:
	_exploded = true
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p and p.global_position.distance_to(global_position) < BLAST:
		p.take_damage(LevelManager.enemy_hit_damage(1), self)
	if p and p.has_method("_shake_camera"):
		p._shake_camera()
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != self and is_instance_valid(e) and not e.is_dead and e.global_position.distance_to(global_position) < BLAST:
			e.take_damage(2, self)
	ToxicPuddle.spawn(get_parent(), global_position, 24.0, 5.0)
	FX.at_node("blast", self, Vector2(0, -10), Color.WHITE, 1.15)
	FloatText.spawn(self, "BOOM", Color(1.0, 0.65, 0.2), Vector2(0, -30))
	SFXManager.play_sfx(preload("res://Audio/SFX/Eco/blast.wav"), -1)
	health = 0
	handle_death()


func handle_death():
	if is_dead:
		return
	if _exploded:
		# gone in the blast: count the kill and vanish
		is_dead = true
		if _health_bar:
			_health_bar.visible = false
		$CollisionShape2D.set_deferred("disabled", true)
		LevelManager.on_enemy_killed(self)
		queue_free()
		return
	if _fuse <= 0.0:
		ToxicPuddle.spawn(get_parent(), global_position, 14.0, 3.0)  # the barrel leaks
	_fuse = 0.0
	modulate = Color.WHITE
	await super()
