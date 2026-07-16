extends Node2D

@onready var ray = $RayCast2D
@onready var reload_timer = $RayCast2D/ReloadTimer
@export var bullet_scene : PackedScene

func _process(delta):

    if ray.is_colliding():

        var collider = ray.get_collider()

        if collider.is_in_group("player") and collider.health > 0:

            if reload_timer.is_stopped():
                shoot()
func shoot():

    var bullet = bullet_scene.instantiate()
    SFXManager.play_sfx(preload("res://Audio/SFX/Attacks/Arrow.wav"))
    get_tree().current_scene.add_child(bullet)

    bullet.global_position = global_position
    bullet.direction = ray.target_position.normalized()
    bullet.shooter = self

    reload_timer.start()
