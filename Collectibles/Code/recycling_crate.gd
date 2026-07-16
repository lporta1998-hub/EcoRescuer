## recycling_crate.gd
## Environmental crate filled with EcoTokens.
## When the player walks into it the crate "opens" and spawns several tokens.
extends Area2D

@export var token_count: int = 5
@export var spawn_radius: float = 40.0

const EcoToken = preload("res://Collectibles/Scenes/eco_token.tscn")

var _opened: bool = false

func _ready() -> void:
    body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
    if _opened:
        return
    if body is CharacterBody2D:
        _opened = true
        _spawn_tokens()
        # Animate crate: flash green then hide
        modulate = Color(0.4, 1.0, 0.4, 1.0)
        await get_tree().create_timer(0.3).timeout
        queue_free()

func _spawn_tokens() -> void:
    var parent = get_parent()
    for i in range(token_count):
        var token: Node2D = EcoToken.instantiate()
        parent.add_child(token)
        var angle = (TAU / token_count) * i
        token.global_position = global_position + Vector2(cos(angle), sin(angle)) * spawn_radius
        print("[RecyclingCrate] Spawned EcoToken %d/%d" % [i+1, token_count])
