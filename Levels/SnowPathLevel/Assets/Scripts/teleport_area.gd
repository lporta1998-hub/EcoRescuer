extends Area2D

@export var destination_marker : Marker2D

var can_teleport = true

func _ready() -> void:
    add_to_group("teleport")  # used by RouteGuide (arrow + pause map)

func _on_body_entered(body: Node2D) -> void:
    if body.is_in_group("player") and can_teleport:
        SFXManager.play_sfx(preload("res://Audio/SFX/Eco/teleport.wav"))
        $fade_transition.show()
        can_teleport = false
        
        # Disabilita il player durante la transizione
        body.set_process(false)
        body.set_physics_process(false)
        
        # Usa la funzione fade_out_then per fare:
        # 1. Fade out
        # 2. Teletrasporto (nel callback)
        # 3. Fade in (automatico dopo il callback)
        await $fade_transition.fade_out_then(func():
            body.velocity = Vector2.ZERO
            body.global_position = destination_marker.global_position
            LevelManager.on_player_teleported()
        )
        
        # Riabilita il player
        body.set_process(true)
        body.set_physics_process(true)
        
        # Cooldown
        await get_tree().create_timer(0.5).timeout
        can_teleport = true
