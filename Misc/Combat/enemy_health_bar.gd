class_name EnemyHealthBar
extends Node2D
## Small health bar drawn above an enemy's head.
## Hidden while the enemy is at full health; after a hit the lost part first
## shows in white and then shrinks away, so you can see how much a blow did.

@export var bar_size := Vector2(22, 4)

var max_value := 3.0
var value := 3.0
var _ghost := 3.0  # trailing "damage" part


func _ready() -> void:
	z_index = 20
	visible = false


func set_health(current: float, maximum: float) -> void:
	max_value = maxf(maximum, 0.001)
	value = clampf(current, 0.0, max_value)
	visible = value < max_value and value > 0.0
	queue_redraw()


func _process(delta: float) -> void:
	if _ghost > value:
		_ghost = move_toward(_ghost, value, delta * max_value * 1.5)
		queue_redraw()
	elif _ghost < value:
		_ghost = value


func _draw() -> void:
	var origin := Vector2(-bar_size.x / 2.0, 0)
	draw_rect(Rect2(origin - Vector2.ONE, bar_size + Vector2(2, 2)), Color(0.1, 0.08, 0.12))
	draw_rect(Rect2(origin, bar_size), Color(0.28, 0.1, 0.12))
	var ghost_w := bar_size.x * (_ghost / max_value)
	draw_rect(Rect2(origin, Vector2(ghost_w, bar_size.y)), Color(1, 1, 1, 0.9))
	var w := bar_size.x * (value / max_value)
	var ratio := value / max_value
	var fill := Color(0.36, 0.8, 0.3) if ratio > 0.5 else (Color(0.95, 0.75, 0.2) if ratio > 0.25 else Color(0.9, 0.25, 0.2))
	draw_rect(Rect2(origin, Vector2(w, bar_size.y)), fill)
	draw_rect(Rect2(origin, Vector2(w, 1)), fill.lightened(0.35))
