## trash_bag.gd
## Collectible trash bag. Collecting it means cleaning the environment.
## Awards bonus points and could restore HP in the future.
extends Collectible
class_name TrashBag

func _ready() -> void:
    add_to_group("trashbag")
    points = 15
    bobbing = true
    bob_speed = 1.2
    bob_amplitude = 3.0
    
    super()
    


func on_collect(player: Node2D) -> void:
    SFXManager.play_sfx(preload("res://Audio/SFX/Objects/Collection.wav"),-10)
    print("[TrashBag] Rifiuto raccolto! Ambiente più pulito! +%d punti eco" % points)
    if Global.has_method("add_score"):
        Global.add_score(points)
