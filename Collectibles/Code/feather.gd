extends Collectible
class_name SpeedBoost
@export var boost:int
@export var boost_duration: float = 5.0


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    points = 0
    bobbing = true
    bob_speed = 1.2
    bob_amplitude = 3.0
    
    super()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
    pass
    
func on_collect(_player: Node2D) -> void:
    SFXManager.play_sfx(preload("res://Audio/SFX/Objects/Collection.wav"),-10)
    if _player.has_method("speedBoost"):
        _player.speedBoost(boost,boost_duration)
        
    
            
    
