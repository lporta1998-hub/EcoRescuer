class_name Dossier
extends Area2D
## Secret Inquinatori file: a side quest in every level. Walking into it shows
## what it reveals (Story chapter "dossier" text) and pays a reward once.
## Put a Dossier in a level scene to choose its spot; otherwise LevelManager
## places one automatically on a far, reachable spot.

const ICON := preload("res://Misc/Story/Art/dossier.png")

var _t := 0.0
var _taken := false


func _ready() -> void:
	add_to_group("dossier")
	collision_layer = 0
	collision_mask = 1
	if get_node_or_null("CollisionShape2D") == null:
		var shape := CollisionShape2D.new()
		shape.name = "CollisionShape2D"
		var circle := CircleShape2D.new()
		circle.radius = 12.0
		shape.shape = circle
		add_child(shape)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if _taken or not body.is_in_group("player"):
		return
	_taken = true
	SFXManager.play_sfx(preload("res://Audio/SFX/Eco/ui_page.wav"), -2)
	LevelManager.on_dossier_found()
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.6, 1.6), 0.12)
	tw.tween_property(self, "scale", Vector2.ZERO, 0.1)
	tw.tween_callback(queue_free)


func _draw() -> void:
	var bob := sin(_t * 2.5) * 2.0
	var glow := 0.35 + 0.2 * sin(_t * 4.0)
	draw_circle(Vector2(0, bob), 13.0, Color(1.0, 0.85, 0.3, glow * 0.5))
	draw_texture(ICON, Vector2(-ICON.get_width() / 2.0, -ICON.get_height() / 2.0 + bob))
