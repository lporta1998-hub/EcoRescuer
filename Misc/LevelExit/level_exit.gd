class_name LevelExit
extends Area2D
## The recycling station that ends a level.
##
## Walk into it once the level's objective is done (enough trash bags and
## defeated enemies, see LevelData.required_bags / required_kills) to finish.
## Until then it's grey and tells the player what's missing.
##
## Place a LevelExit (res://Misc/LevelExit/level_exit.tscn) in a level scene to
## choose where it is. Levels without one get it automatically on the trash
## bag farthest from the player's start.

const STATION := preload("res://Misc/LevelExit/recycle_station.png")
const RADIUS := 26.0

var is_open := false
var _t := 0.0


func _ready() -> void:
	add_to_group("level_exit")
	collision_layer = 0
	collision_mask = 1  # the player's physics layer
	monitoring = true
	if get_node_or_null("CollisionShape2D") == null:
		var shape := CollisionShape2D.new()
		shape.name = "CollisionShape2D"
		var circle := CircleShape2D.new()
		circle.radius = RADIUS
		shape.shape = circle
		add_child(shape)
	body_entered.connect(_on_body_entered)


func set_open(open: bool) -> void:
	if open and not is_open:
		var t := create_tween()
		t.tween_property(self, "scale", Vector2(1.25, 1.25), 0.12)
		t.tween_property(self, "scale", Vector2.ONE, 0.18)
	var opened_now := open and not is_open
	is_open = open
	queue_redraw()
	# Already standing in the station when the goal is completed (e.g. the
	# last enemy dies next to it): finish without having to walk out and in.
	if opened_now:
		_finish_if_player_inside.call_deferred()


func _finish_if_player_inside() -> void:
	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			LevelManager.try_finish_level()
			return


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		LevelManager.try_finish_level()


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_t * 4.0)
	var ring := Color(0.45, 1.0, 0.4, 0.55 + 0.35 * pulse) if is_open else Color(0.7, 0.7, 0.72, 0.5)
	# ground pad
	draw_set_transform(Vector2(0, 6), 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, RADIUS, Color(0, 0, 0, 0.25))
	draw_arc(Vector2.ZERO, RADIUS - 2.0 + (pulse * 3.0 if is_open else 0.0), 0, TAU, 40, ring, 3.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if is_open:
		# light beam with rising sparkles
		draw_rect(Rect2(-9, -46, 18, 50), Color(0.55, 1.0, 0.45, 0.12 + 0.08 * pulse))
		for i in 5:
			var k := fmod(_t * 0.6 + i * 0.2, 1.0)
			draw_circle(Vector2(sin(i * 2.1 + _t) * 7.0, -k * 48.0), 1.3, Color(0.8, 1.0, 0.6, 1.0 - k))
	var tint := Color.WHITE if is_open else Color(0.55, 0.55, 0.6)
	draw_texture(STATION, Vector2(-12, -22), tint)
