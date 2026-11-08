class_name SeedShot
extends Node2D
## Silvano's seed: flies straight and hurts the first enemy it touches.

const ICON := preload("res://Misc/Projectiles/seed.png")
const SPEED := 280.0
const LIFE := 0.7
const DAMAGE := 1

var dir := Vector2.RIGHT
var shooter: Node
var _life := LIFE


static func fire(parent: Node, from: Vector2, direction: Vector2, by: Node) -> void:
	var s := SeedShot.new()
	s.dir = direction.normalized()
	s.shooter = by
	s.z_index = 15
	parent.add_child(s)
	s.global_position = from


func _process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	global_position += dir * SPEED * delta
	rotation += delta * 12.0
	for node in get_tree().current_scene.find_children("*", "CharacterBody2D", true, false):
		if (node is Enemy or node is Boss) and not node.is_dead:
			var reach := 30.0 if node is Boss else 12.0
			if node.global_position.distance_to(global_position + Vector2(0, 8)) < reach:
				node.take_damage(DAMAGE, shooter if is_instance_valid(shooter) else null)
				queue_free()
				return
	queue_redraw()


func _draw() -> void:
	draw_texture(ICON, -ICON.get_size() / 2.0)
