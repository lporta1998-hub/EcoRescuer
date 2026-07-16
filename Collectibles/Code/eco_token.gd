## eco_token.gd
## Collectable green coin. Awards `points` to a future score system.
## Each coin collected increments the global eco_score variable if it exists.
extends Collectible

func _ready() -> void:
    points = 10
    super()

func on_collect(player: Node2D) -> void:
    SFXManager.play_sfx(preload("res://Audio/SFX/Objects/Collection.wav"),-10)
    print("[EcoToken] Raccolta! +%d punti eco" % points)
    # Hook into a global score if the project adds one in the future.
    if Global.has_method("add_score"):
        Global.add_score(points)
