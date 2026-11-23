class_name BreakableCrate
extends StaticBody2D
## A stack of crates that blocks a secret passage (SecretSpots places a row
## of them across a corridor). Any attack breaks it: melee swings, arrows,
## potions, lasers. Fills one 16 px cell and blocks heroes and enemies.

signal broken(crate: BreakableCrate)

const SIZE := 16.0
## Its own cracked crate (Tools/art/breakable_crate.py), so it does not look
## like the decorative crates of the factory, harbor, lake and data center.
const SPRITE := preload("res://Misc/Secrets/breakable_crate.png")
const HIGHLIGHT_SHADER := preload("res://Misc/FX/pickup_highlight.gdshader")

var health := 2.0


func _ready() -> void:
	add_to_group("breakable_objects")
	collision_layer = 1 | 2  # what heroes and enemies bump into; hero hurt boxes see layer 1
	collision_mask = 0
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var rect := RectangleShape2D.new()
	rect.size = Vector2(SIZE, SIZE)
	shape.shape = rect
	add_child(shape)
	var s := Sprite2D.new()
	s.name = "Sprite2D"
	s.texture = SPRITE
	s.offset = Vector2(0, -3)
	# a little variety so a row of them looks like a pile
	var h := absi(hash(Vector2i(global_position)))
	s.flip_h = h % 2 == 0
	s.modulate = Color(1, 1, 1).darkened(float(h % 4) * 0.04)
	# a slow warm shimmer: noticeable, but quieter than the pickups
	var mat := ShaderMaterial.new()
	mat.shader = HIGHLIGHT_SHADER
	mat.set_shader_parameter("glow_color", Color(1.0, 0.82, 0.45))
	mat.set_shader_parameter("glow_strength", 0.6)
	mat.set_shader_parameter("pulse_speed", 2.0)
	mat.set_shader_parameter("glint_period", 4.5)
	mat.set_shader_parameter("glint_strength", 0.4)
	mat.set_shader_parameter("phase", float(h % 1000) / 100.0)
	s.material = mat
	add_child(s)


func take_damage(amount = 1, _attacker = null) -> void:
	if health <= 0.0:
		return
	health -= float(amount)
	var s: Sprite2D = $Sprite2D
	var tw := create_tween()
	tw.tween_property(s, "modulate", Color(2.5, 2.5, 2.5), 0.06)
	tw.tween_property(s, "modulate", Color.WHITE, 0.12)
	if health > 0.0:
		return
	SFXManager.play_sfx(preload("res://Audio/SFX/Dmg/Balloon Pop 1.wav"), -10, 0.8)
	FX.spawn("dust", get_parent(), global_position, Color(0.9, 0.75, 0.55), 1.4)
	$CollisionShape2D.set_deferred("disabled", true)
	if LevelManager.route_guide:
		LevelManager.route_guide.set_area_walkable(Rect2(global_position - Vector2(SIZE, SIZE) / 2.0, Vector2(SIZE, SIZE)), true)
	broken.emit(self)
	queue_free()
