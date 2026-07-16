class_name Character extends CharacterBody2D


signal hpChanged

@export var speed :float = 150.0
var base_speed: float = 150.0
var active_boost: int = 0
@export_range(1.0, 25.0, .1) var decay := 16.0
@export var max_health := 3.0
@onready var health := max_health
@onready var footstep = $FootstepSound

var step_timer = 0.0
var step_interval = 0.35  # intervallo tra un passo e l'altro
var buffer_time = 0.1

var input_direction := Vector2.ZERO
var soft_collision_vector := Vector2.ZERO
var movement := Vector2.ZERO
#var knockback_vector := Vector2.ZERO
var look_direction := Vector2.RIGHT
var _last_direction := Vector2.RIGHT
var _has_vertical_idles := false 
var is_dead := false



func _ready() -> void:
  var sprite = $AnimatedSprite2D
  if sprite and sprite.sprite_frames:
    _has_vertical_idles = sprite.sprite_frames.has_animation("idle_top")


func _process(delta: float) -> void:
  if health <= 0 and not is_dead:
    handle_death()
    
  if is_dead:
    return
  velocity = Globals.exp_decay(velocity, input_direction * speed, decay, delta)
  
  #if not input_direction.is_zero_approx():
    #velocity = input_direction * speed
    #look_direction = input_direction
  #else:
    #velocity = Vector2.ZERO
  
  if not velocity.is_zero_approx():
    look_direction = velocity.normalized()

func _physics_process(delta: float) -> void:
  # Questo if blocca lo sliding del personaggio quando muore
  if is_dead:
    velocity = Vector2.ZERO
    soft_collision_vector = Vector2.ZERO
    return
    
  velocity += soft_collision_vector
  soft_collision_vector = Vector2.ZERO
  #velocity += knockback_vector 5
  #knockback_vector -= knockback_vector * delta
  #velocity = velocity.limit_length(2000)
  #update_animation(movement)
  #velocity = movement * speed
  move_and_slide()

func handle_footsteps(delta):
    if input_direction != Vector2.ZERO:
        step_timer -= delta
        if step_timer <= 0:
            # riproduci il passo
            footstep.pitch_scale = randf_range(0.9, 1.1)
            footstep.play()
            step_timer = step_interval
    else:
        # reset timer quando smetti
        step_timer = 0

func handle_animations():
  if is_dead:
    return

  if input_direction == Vector2.ZERO:
    _handle_idle_animation()
  else:
    _handle_movement_animation()
    _last_direction = input_direction

func _handle_idle_animation():
  if _has_vertical_idles and (_last_direction.x != 0 or _last_direction.y != 0):
    if abs(_last_direction.x) > abs(_last_direction.y):
      # Prevalenza orizzontale
      if _last_direction.x > 0:
        $AnimatedSprite2D.play("idle")
        $AnimatedSprite2D.flip_h = false
      else:
        $AnimatedSprite2D.play("idle")
        $AnimatedSprite2D.flip_h = true
    else:
      # Prevalenza verticale
      if _last_direction.y > 0:
        $AnimatedSprite2D.play("idle_down")
      else:
        $AnimatedSprite2D.play("idle_top")
  else:
    $AnimatedSprite2D.play("idle")

func _handle_movement_animation():
  if _has_vertical_idles and abs(input_direction.x) <= abs(input_direction.y):
    # Prevalenza verticale
    if input_direction.y > 0:
      $AnimatedSprite2D.play("walk_down")
    else:
      $AnimatedSprite2D.play("walk_up")
  else:
    # Prevalenza orizzontale
    $AnimatedSprite2D.play("walk_right")
    if input_direction.x > 0:
      $AnimatedSprite2D.flip_h = false
    else:
      $AnimatedSprite2D.flip_h = true

# Metodi helper per le classi figlie
func get_direction_as_string():
  if look_direction.x > 0:
    return "right"
  elif look_direction.x < 0:
    return "left"
  elif look_direction.y > 0:
    return "up"
  elif look_direction.y < 0:
    return "down"



#func on_hurt(attack_data: AttackData):
  #var knockback_direction = Vector2.from_angle(attack_data.attacker.global_rotation)
  #soft_collision_vector += (attack_data.knockback * knockback_direction) - velocity
  #soft_collision_vector += attack_data.attacker.velocity 
  #print_debug(knockback_vector)

#func _on_hitbox_body_entered(body):
    #var hp_control = get_node("HP")
    #if body is Enemy:
        #hp_control.set_hp(hp_control.hp - 1)
        #if hp_control == 1:
            #print("Gameover")

func take_damage(dmg: int, attacker):
  SFXManager.play_sfx(preload("res://Audio/SFX/Dmg/Damage.wav"))
  health -= dmg
  hpChanged.emit(health)
  soft_collision_vector += attacker.global_position.direction_to(global_position) * 400.0
  print_debug("%s took %s damage" % [name, dmg])

func handle_death():
  SFXManager.play_sfx(preload("res://Audio/SFX/Dmg/Balloon Pop 1.wav"), -15)
  is_dead = true
  speed = 0
  input_direction = Vector2.ZERO
  velocity = Vector2.ZERO
  # Tolgo le collisioni alla morte
  $CollisionShape2D.disabled = true
  var sprite: AnimatedSprite2D = $AnimatedSprite2D

  if sprite.sprite_frames.has_animation("death"):
    sprite.play("death")
    await sprite.animation_finished
  else:
    modulate = Color.RED
    await get_tree().create_timer(0.1).timeout

  if is_in_group("player"):
    var level_manager = get_tree().get_first_node_in_group("level_manager")
    if level_manager and level_manager.has_method("show_game_over_menu"):
        level_manager.show_game_over_menu()
    else:
            # Cerca il level manager nella scena
            level_manager = get_tree().get_first_node_in_group("level_manager")
            if level_manager and level_manager.has_method("show_game_over_menu"):
                level_manager.show_game_over_menu()
    
  else:
    
    await get_tree().create_timer(1.0).timeout
    queue_free()  # Il nemico semplicemente sparisce
    return 
    
    
  #await get_tree().create_timer(.5).timeout
  #queue_free()
func heal(amount: int) -> void:
    # Aumenta la salute ma non superare il massimo (3)
    health = min(health + amount, 3)
    # Emetti il segnale per aggiornare i cuori
    hpChanged.emit(health)
    print("Salute recuperata! Ora: ", health)
    
func speedBoost(amount: int, duration: float) -> void:
    # Applica il boost
    speed = base_speed + amount
    active_boost = amount
    
    print("Boost applicato! Nuova velocità: ", speed)
    
    var timer = get_tree().create_timer(duration)
    timer.timeout.connect(_on_boost_timer_timeout)

func _on_boost_timer_timeout():
    
    speed = base_speed
    active_boost = 0
    print("Boost finito! Velocità tornata a: ", speed)
