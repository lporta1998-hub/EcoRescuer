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

## Seconds a player stays invincible (blinking) after being hit. Characters
## that extend CombatCharacter use their own invincibility_duration instead.
const PLAYER_IFRAMES := 0.8
var _iframes := 0.0
var _blink := 0.0



func _ready() -> void:
  var sprite = $AnimatedSprite2D
  if sprite and sprite.sprite_frames:
    _has_vertical_idles = sprite.sprite_frames.has_animation("idle_top")


func _process(delta: float) -> void:
  _update_iframes(delta)
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
  if is_dead or is_invincible_now():
    return
  var from_player: bool = is_instance_valid(attacker) and attacker is Node and attacker.is_in_group("player")
  if is_in_group("player"):
    # "Scudo" buff: the first hit of the level is blocked.
    if LevelManager.consume_shield():
      _flash(Color(0.45, 0.8, 1.6))
      SFXManager.play_sfx(preload("res://Audio/SFX/Eco/shield.wav"))
      _iframes = 0.6
      return
  elif from_player:
    # "Colpo potente" buff / Eco Rush: bonus damage and critical hits
    var hit: Array = LevelManager.player_hit_damage(dmg)
    dmg = hit[0]
    if hit[1]:
      FloatText.spawn(self, "CRIT!", Color(1.0, 0.85, 0.2))
  health -= dmg
  hpChanged.emit(health)
  _hit_fx()
  var hit_from := global_position + Vector2.LEFT
  if is_instance_valid(attacker) and attacker is Node2D:
    hit_from = attacker.global_position
  _on_hurt(hit_from.direction_to(global_position))
  print_debug("%s took %s damage" % [name, dmg])


## Green impact star on a polluter, toxic splat on the hero.
func _hit_fx() -> void:
  if is_in_group("player"):
    FX.at_node("hurt", self, Vector2(randf_range(-3, 3), -10))
    SFXManager.play_sfx(preload("res://Audio/SFX/Eco/hurt.wav"), -2)
  else:
    SFXManager.play_sfx(preload("res://Audio/SFX/Eco/hit.wav"), -3, randf_range(0.9, 1.12))
    var fx := FX.at_node("hit", self, Vector2(randf_range(-4, 4), randf_range(-14, -6)))
    if fx:
      fx.flip_h = randf() < 0.5


func is_invincible_now() -> bool:
  return _iframes > 0.0 or get("is_invincible") == true


## Reaction to a hit, `away` points from the attacker to this character.
## Enemies override it (knockback + stagger); players get feedback + i-frames.
func _on_hurt(away: Vector2) -> void:
  soft_collision_vector += away * 400.0
  _flash(Color(1.0, 0.35, 0.35) if is_in_group("player") else Color(2.5, 2.5, 2.5))
  if is_in_group("player"):
    Input.vibrate_handheld(60)
    _shake_camera()
    if not has_method("start_invincibility"):
      _iframes = PLAYER_IFRAMES


func _flash(color: Color) -> void:
  modulate = color
  var t := create_tween()
  t.tween_property(self, "modulate", Color.WHITE, 0.15)


func _shake_camera() -> void:
  var cam := get_node_or_null("Camera2D") as Camera2D
  if cam == null:
    return
  var t := create_tween()
  for i in 4:
    t.tween_property(cam, "offset", Vector2(randf_range(-3, 3), randf_range(-3, 3)), 0.03)
  t.tween_property(cam, "offset", Vector2.ZERO, 0.03)


func _update_iframes(delta: float) -> void:
  if _iframes <= 0.0:
    return
  _iframes -= delta
  _blink -= delta
  var spr := get_node_or_null("AnimatedSprite2D") as CanvasItem
  if spr == null:
    return
  if _iframes <= 0.0 or is_dead:
    spr.visible = true
  elif _blink <= 0.0:
    _blink = 0.1
    spr.visible = not spr.visible

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
    # Never above this character's max (it can be raised by the Cuore extra buff)
    health = min(health + amount, max_health)
    # Emetti il segnale per aggiornare i cuori
    hpChanged.emit(health)
    print("Salute recuperata! Ora: ", health)
    _heal_fx()


## Leaves and pluses rising around the hero (they follow the hero), with a
## soft chime. The heroes that override heal() call this too.
func _heal_fx() -> void:
    if is_in_group("player"):
        SFXManager.play_sfx(preload("res://Audio/SFX/Eco/heal.wav"), -4)
        FX.spawn("heal", self, global_position + Vector2(0, -6), Color.WHITE, 1.0, 5)
    
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
