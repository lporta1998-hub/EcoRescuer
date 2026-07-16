extends Area2D

@export var speed := 200
@export var damage := 1
@export var lifetime := .8  # seconds before bullet disappears

var direction := Vector2.ZERO
var shooter

func _ready():
    await get_tree().create_timer(lifetime).timeout
    queue_free()

func _process(delta):
    position += direction * speed * delta


func _on_body_entered(body):
    if body is Character and body != shooter:
        body.take_damage(damage, shooter)
        queue_free()


func _on_visible_on_screen_notifier_2d_screen_exited():
    queue_free()
