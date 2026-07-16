extends Collectible


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    points = 15
    super()

func on_collect(player: Node2D) -> void:
    SFXManager.play_sfx(preload("res://Audio/SFX/Objects/Collection.wav"),-10)
    if Global.has_method("add_score"):
        Global.add_score(points)
