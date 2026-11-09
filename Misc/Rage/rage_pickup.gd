class_name RagePickup
extends Area2D
## A Shop ability lying on the ground during a Rage match. Walk over it to
## get it (RageRun.on_pickup applies it). It blinks and disappears after
## LIFETIME seconds.

signal picked(id: String)

const LIFETIME := 16.0
const BLINK_FROM := 4.0
const SIZE := 22.0

var id := ""
var _time := 0.0
var _icon: Sprite2D
var _taken := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1  # Player
	monitoring = true
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 12.0
	shape.shape = circle
	add_child(shape)
	# soft glow under the icon
	var glow := Sprite2D.new()
	glow.texture = preload("res://Misc/FX/sparkle.png")
	glow.hframes = 6
	glow.modulate = Color(0.6, 1.0, 0.8, 0.8)
	add_child(glow)
	_icon = Sprite2D.new()
	_icon.texture = load(Progress.BUFFS[id].icon)
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var tex_size := _icon.texture.get_size()
	_icon.scale = Vector2.ONE * (SIZE / maxf(tex_size.x, tex_size.y))
	add_child(_icon)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time += delta
	_icon.position.y = -4.0 + sin(_time * 4.0) * 3.0
	var left := LIFETIME - _time
	if left < BLINK_FROM:
		visible = fmod(left, 0.3) > 0.12
	if left <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if _taken or not body.is_in_group("player"):
		return
	_taken = true
	picked.emit(id)
	FX.spawn("sparkle", get_parent(), global_position, Color(0.7, 1.0, 0.8))
	queue_free()
