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

## "Magnete" buff: pull speed (the radius grows with the buff level).
const MAGNET_SPEED := 260.0
var _magnet_radius := -1.0

func _process(delta: float) -> void:
    if _collected:
        return
    # "Magnete" buff: drift towards the player when close.
    if _magnet_radius < 0.0:
        var lvl := Progress.level_of("magnet")
        _magnet_radius = Progress.MAGNET_BASE_RADIUS + Progress.buff_value("magnet", lvl) if lvl > 0 else 0.0
    if _magnet_radius > 0.0 and magnet_enabled():
        var player := get_tree().get_first_node_in_group("player") as Node2D
        if player and global_position.distance_to(player.global_position) < _magnet_radius:
            global_position = global_position.move_toward(player.global_position, (MAGNET_SPEED + _magnet_radius) * delta)
            _start_y = position.y
            return
    if bobbing:
        _time += delta
        position.y = _start_y + sin(_time * bob_speed) * bob_amplitude

func _on_body_entered(body: Node2D) -> void:
    if _collected:
        return
    # Only the player picks things up (enemies are CharacterBody2D too).
    if body is CharacterBody2D and body.is_in_group("player"):
        _collected = true
        on_collect(body)
        emit_signal("collected", self)
        _play_collect_effect()
        queue_free()

## Items that shouldn't fly to the player (barrels) return false.
func magnet_enabled() -> bool:
    return true

## Override in subclasses to add custom pickup logic.
func on_collect(_player: Node2D) -> void:
    pass

## Sparkle color per item type.
const SPARKLE_TINTS := {
    "health": Color(1.0, 0.45, 0.5),
    "trash": Color(0.55, 1.0, 0.45),
    "trash_bag": Color(0.55, 1.0, 0.45),
    "barile": Color(0.75, 1.0, 0.3),
    "SpeedBoost": Color(0.6, 0.85, 1.0),
}

func _play_collect_effect() -> void:
    FX.at_node("sparkle", self, Vector2.ZERO, SPARKLE_TINTS.get(item_type, Color(1.0, 0.85, 0.3)))
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
