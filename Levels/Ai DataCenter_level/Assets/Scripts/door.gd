extends Area2D

var bodies_inside := 0

func _ready():
    $AnimatedSprite2D.play("closed")

func _on_body_entered(body):
    if body is CharacterBody2D:
        bodies_inside += 1
        $AnimatedSprite2D.play("open")
        $DoorOpen.play()

func _on_body_exited(body):
    if body is CharacterBody2D:
        bodies_inside -= 1
        if bodies_inside <= 0:
            $AnimatedSprite2D.play("closed")
            $DoorClose.play()
