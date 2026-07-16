## collectible.gd
## Base class for all collectible objects in EcoRescuer.
## Subclasses override `on_collect()` to define pickup behaviour.
class_name Collectible extends Area2D

signal collected(collectible: Collectible)

## Points awarded when this collectible is picked up.
@export var health_restore: int = 1
@export var points: int = 10
@onready var sprite = $Sprite2D 
@export var item_name: String = "Oggetto"
@export var item_type: String = "generic"
## If true the collectible bobs up and down.
@export var bobbing: bool = true
@export var bob_speed: float = 2.0
@export var bob_amplitude: float = 4.0

var _start_y: float = 0.0
var _time: float = 0.0
var _collected: bool = false

func _ready() -> void:
    _start_y = position.y
    body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
    if _collected:
        return
    if bobbing:
        _time += delta
        position.y = _start_y + sin(_time * bob_speed) * bob_amplitude

func _on_body_entered(body: Node2D) -> void:
    if _collected:
        return
    # Accept any CharacterBody2D as the player
    if body is CharacterBody2D:
        _collected = true
        on_collect(body)
        emit_signal("collected", self)
        _play_collect_effect()
        queue_free()

## Override in subclasses to add custom pickup logic.
func on_collect(_player: Node2D) -> void:
    pass

func _play_collect_effect() -> void:
    # Simple scale-up tween before queue_free (visual feedback)
    var tween := create_tween()
    tween.tween_property(self, "scale", Vector2(1.6, 1.6), 0.12)
    tween.tween_property(self, "scale", Vector2(0.0, 0.0), 0.08)
    
func get_collectible_data() -> Dictionary:
    var icon_texture = null
    if sprite and sprite.texture:
        icon_texture = sprite.texture
    return {
        "name": item_name,  
        "type": item_type,
        "points": points,
        "icon": icon_texture,
        
    }
