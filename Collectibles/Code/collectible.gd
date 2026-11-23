## collectible.gd
## Base class for all collectible objects in Green Guardians.
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
    if highlight_enabled():
        _add_highlight()

## Items that are big and obvious already (barrels) return false.
func highlight_enabled() -> bool:
    return true

const HIGHLIGHT_SHADER := preload("res://Misc/FX/pickup_highlight.gdshader")

## Makes the item easy to spot on any ground: outline, pulsing glow and a
## glint on the sprite (pickup_highlight.gdshader), and a soft light on the
## ground under it. The colour is the item's sparkle tint.
func _add_highlight() -> void:
    var spr := get_node_or_null("Sprite2D") as Sprite2D
    if spr == null or spr.texture == null:
        return
    var tint: Color = SPARKLE_TINTS.get(item_type, Color(1.0, 0.85, 0.3))
    var phase := float(absi(hash(Vector2i(global_position))) % 1000) / 100.0
    var mat := ShaderMaterial.new()
    mat.shader = HIGHLIGHT_SHADER
    mat.set_shader_parameter("glow_color", tint)
    mat.set_shader_parameter("phase", phase)
    mat.set_shader_parameter("px_scale", maxf(1.0, roundf(1.0 / absf(spr.scale.x))))
    spr.material = mat
    # soft light on the ground
    var grad := Gradient.new()
    grad.set_color(0, Color(tint, 0.55))
    grad.set_color(1, Color(tint, 0.0))
    var tex := GradientTexture2D.new()
    tex.gradient = grad
    tex.fill = GradientTexture2D.FILL_RADIAL
    tex.fill_from = Vector2(0.5, 0.5)
    tex.fill_to = Vector2(1.0, 0.5)
    tex.width = 48
    tex.height = 48
    var glow := Sprite2D.new()
    glow.name = "GroundGlow"
    glow.texture = tex
    var add := CanvasItemMaterial.new()
    add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
    glow.material = add
    var h := spr.texture.get_height() * absf(spr.scale.y)
    glow.position = spr.position + Vector2(0, h * 0.45)
    glow.scale = Vector2(0.7, 0.32)
    add_child(glow)
    move_child(glow, 0)
    var tw := glow.create_tween().set_loops()
    tw.tween_property(glow, "scale", Vector2(0.9, 0.42), 0.9).set_trans(Tween.TRANS_SINE)
    tw.tween_property(glow, "scale", Vector2(0.7, 0.32), 0.9).set_trans(Tween.TRANS_SINE)

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
