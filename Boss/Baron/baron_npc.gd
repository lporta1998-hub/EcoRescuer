extends CharacterBody2D
## The Barone dei Rifiuti on foot, for the boss-fight intro: walks, talks and
## climbs into the MECCA-RIFIUTI. Not playable, not an enemy.


func _ready() -> void:
	remove_from_group("player")
	var cam := get_node_or_null("Camera2D") as Camera2D
	if cam:
		cam.enabled = false
	var ui := get_node_or_null("CanvasLayer")
	if ui:
		ui.visible = false
	var hb := get_node_or_null("HurtBox") as Area2D
	if hb:
		hb.monitoring = false
	collision_layer = 0
	collision_mask = 0
	$AnimatedSprite2D.play("idle_down")


func face(dir: String) -> void:
	$AnimatedSprite2D.flip_h = false
	match dir:
		"up":
			$AnimatedSprite2D.play("idle_top")
		"down":
			$AnimatedSprite2D.play("idle_down")
		_:
			$AnimatedSprite2D.play("idle")
			$AnimatedSprite2D.flip_h = dir == "left"


func walk_to(target: Vector2, seconds: float) -> void:
	var d := target - global_position
	if absf(d.x) > absf(d.y):
		$AnimatedSprite2D.play("walk_right" if d.x > 0 else "walk_left")
	else:
		$AnimatedSprite2D.play("walk_down" if d.y > 0 else "walk_up")
	var tw := create_tween()
	tw.tween_property(self, "global_position", target, seconds)
	await tw.finished


## A line of dialogue in a bubble above his head.
func say(text: String, seconds := 2.4) -> void:
	var bubble := Label.new()
	bubble.text = text
	bubble.add_theme_font_size_override("font_size", 9)
	bubble.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	bubble.add_theme_constant_override("outline_size", 4)
	bubble.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.06))
	bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble.size = Vector2(150, 30)
	bubble.position = Vector2(-75, -64)
	bubble.z_index = 50
	add_child(bubble)
	await get_tree().create_timer(seconds).timeout
	bubble.queue_free()
