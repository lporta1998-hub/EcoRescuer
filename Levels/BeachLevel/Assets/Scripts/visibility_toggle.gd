extends Area2D

@onready var roof: TileMapLayer = $".."
var hide_roof := false
var roof_visibility = 1.0

func _on_body_entered(body: Node2D) -> void:
  if body.name.to_lower() == "player":
    hide_roof = true

func _on_body_exited(body: Node2D) -> void:
  if body.name.to_lower() == "player":
    hide_roof = false

func _process(delta: float) -> void:
  roof_visibility -= delta * 5 if hide_roof else -delta * 5
  roof_visibility = clampf(roof_visibility, 0.25,1)
  roof.self_modulate.a = roof_visibility
