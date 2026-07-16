extends StaticBody2D

signal broken

var health : float = 3:
    set(value):
        health = value
        if health <= 0:
            $CollisionShape2D.set_deferred("disabled", true)
            broken.emit()
            queue_free()

@onready var sprite = $Sprite2D
@onready var hit_area = $Area2D

func _ready() -> void:
   
    add_to_group("breakable_objects")
    
    if sprite:
        sprite.modulate = Color.WHITE
    
    
    if hit_area and not hit_area.body_entered.is_connected(_on_area_2d_body_entered):
        hit_area.body_entered.connect(_on_area_2d_body_entered)

func take_damage(amount = 1, attacker = null):
    health -= amount
    play_hit_effect()
    print("Oggetto colpito! Salute rimasta: ", health)

func play_hit_effect():
    if not sprite:
        return
        
    var tween = create_tween()
    tween.tween_property(sprite, "modulate", Color(3, 3, 3), 0.08)
    tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)

# Danno da contatto quando il player TOCCA l'oggetto
func _on_area_2d_body_entered(body: Node2D) -> void:
    if body.is_in_group("player"):
        take_damage()
        print("Danno da contatto!")
