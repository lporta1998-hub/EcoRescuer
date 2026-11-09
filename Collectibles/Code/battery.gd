class_name Battery
extends Area2D
## Battery for ECO-9: recharges its energy. Only placed in a level when the
## chosen hero uses batteries (LevelManager._place_batteries).

const ICON := preload("res://Collectibles/Assets/Sprites/battery.png")

var _t := 0.0


func _ready() -> void:
	add_to_group("battery")
	collision_layer = 0
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 11.0
	shape.shape = c
	add_child(shape)
	body_entered.connect(func(b):
		if b.has_method("recharge"):
			b.recharge(b.BATTERY_CHARGE if "BATTERY_CHARGE" in b else 40.0)
			SFXManager.play_sfx(preload("res://Audio/SFX/Eco/pickup.wav"), -6)
			FX.at_node("sparkle", self, Vector2.ZERO, Color(1.0, 0.95, 0.4))
			queue_free())


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var bob := sin(_t * 3.0) * 2.0
	draw_circle(Vector2(0, bob), 12.0, Color(0.4, 1.0, 0.5, 0.18 + 0.1 * sin(_t * 5.0)))
	draw_texture(ICON, Vector2(-ICON.get_width() / 2.0, -ICON.get_height() / 2.0 + bob))
