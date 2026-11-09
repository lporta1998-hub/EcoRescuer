## eco_token.gd
## Green coin. Coins picked up in a level are counted by LevelManager.run_coins
## and can be spent on eco chests (eco_chest.gd); the ones not spent become
## Shop coins at the end of the level.
extends Collectible

func _ready() -> void:
    points = 10
    super()

func on_collect(player: Node2D) -> void:
    SFXManager.play_sfx(preload("res://Audio/SFX/Eco/pickup.wav"), -8)
    print("[EcoToken] Raccolta! +%d punti eco" % points)
    # Hook into a global score if the project adds one in the future.
    if Global.has_method("add_score"):
        Global.add_score(points)


## Marks this collectible as a spendable coin for LevelManager.
func is_eco_coin() -> bool:
    return true
