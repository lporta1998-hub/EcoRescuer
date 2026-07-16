extends Area2D

var direction : Vector2 = Vector2.RIGHT
var speed : float = 200
var damage : float = 1
var shooter: Character = null  # Nuova variabile
var lifetime: float = 2.0  # Verrà impostato dall'arma

var time_alive: float = 0.0

func _ready():
    # Ignora le collisioni con lo shooter per un po' di tempo
    if shooter:
        # Aggiungi un piccolo ritardo prima di poter collidere con lo shooter
        await get_tree().create_timer(0.1).timeout
        
func _physics_process(delta):
    position += direction * speed * delta
    time_alive += delta
    if time_alive >= lifetime:
        queue_free()
    if direction != Vector2.ZERO:
        
        var angle = direction.angle()
        $Sprite2D.rotation = angle
 
 
func _on_body_entered(body):
       if is_instance_valid(body) and body.has_method("take_damage") and body != shooter:
        body.take_damage(damage, shooter)
        queue_free()
 
 
func _on_screen_exited():
    queue_free()
