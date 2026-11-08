extends Character 

# Movement variables
@export var acceleration : float = 0.25  # Smooth movement (0-1)
@export var friction : float = 0.15       # Deceleration when no input

# Animation node reference
@onready var animated_sprite : AnimatedSprite2D = $AnimatedSprite2D

#game stats
@onready var heartsContainer = $CanvasLayer/HeartsContainer

## Buttons shown by the on-screen touch controls.
var touch_actions := {"primary": "ATTACCA", "secondary": "LATTINA"}

## LATTINA: a recycled can thrown like a boomerang (see CanBoomerang).
const CAN_COOLDOWN := 2.0
var _can_left := 0.0

#attack statesa
@onready var attack_cooldown: Timer = $AttackCooldown
var cooldown_length := .5
var can_attack := true

@onready var hurt_box: Area2D = $HurtBox
@onready var hurt_box_collider: CollisionPolygon2D = $HurtBox/HurtBoxCollider

# Direction vectors
var movement_direction : Vector2 = Vector2.ZERO
var last_direction : Vector2 = Vector2.DOWN  # Default facing direction

# Animation states
enum AnimationState { IDLE, WALK }
var current_state : AnimationState = AnimationState.IDLE


var attack_combo := 0
const MAX_COMBO := 2
var is_attacking := false


func _ready():
    add_to_group("player")
    # Ensure animation player is properly set up
    if animated_sprite == null:
        print("Error: AnimatedSprite2D node not found!")
        return
        
    heartsContainer.setMaxHP(3)
    heartsContainer.updateHP(self.health)
    self.hpChanged.connect(heartsContainer.updateHP)
    
    attack_cooldown.timeout.connect(_on_attack_cooldown_timeout)
    CombatCharacter.enable_deflect(hurt_box)
    animated_sprite.animation_finished.connect(_on_animation_finished)

func _physics_process(_delta):
    if is_dead:
        velocity = Vector2.ZERO
        return
    # Get input direction
    get_input_direction()
    handle_footsteps(_delta)    
    super(_delta)
    # Apply movement
    apply_movement()
    
    # Update animations
    update_animations()
    update_hurt_box_position()
    
    if Input.is_action_just_pressed("primary"):
        handle_attack()        
    _can_left = maxf(0.0, _can_left - _delta)
    if Input.is_action_just_pressed("secondary"):
        throw_can()

## Throws the can toward `target` (default: where the player aims).
## Returns false while cooling down.
func throw_can(target = null) -> bool:
    if is_dead or _can_left > 0.0:
        return false
    _can_left = CAN_COOLDOWN
    var from := global_position + Vector2(0, -14)
    var aim: Vector2 = target if target is Vector2 else TouchControls.get_aim_position(self)
    var dir := aim - from
    if dir.is_zero_approx():
        dir = last_direction
    CanBoomerang.throw(get_parent(), from, dir, self)
    SFXManager.play_sfx(preload("res://Audio/SFX/Attacks/Arrow.wav"), -6)
    return true

## 1 = just thrown, 0 = ready. Read by TouchControls for the button's sweep.
func secondary_cooldown_ratio() -> float:
    return clampf(_can_left / CAN_COOLDOWN, 0.0, 1.0)

func handle_attack():
  if is_dead:
      return
  # Respect the cooldown: before, every tap dealt damage even while cooling down.
  if not can_attack or is_attacking:
      return
  if can_attack and not is_attacking:
    print_debug("Attacking! Direction: %s, Position: %s" % [get_facing_direction(), global_position])
    
    is_attacking = true
    play_attack_animation()
    
  CombatCharacter.deflect_overlapping(hurt_box, self)
  for b in hurt_box.get_overlapping_bodies():
    if b == self:
        continue
        
    if b is Character:
        print_debug("  Hit: %s" % b.name)
        b.take_damage(1, self)
        
    can_attack = false
    attack_cooldown.start(cooldown_length)
    
    attack_combo += 1
    if attack_combo >= MAX_COMBO:
        attack_combo = 0

func _on_attack_cooldown_timeout() -> void:
    can_attack = true
    print_debug("Attack cooldown finished, can_attack = true")

func update_hurt_box_position():
    if is_dead:
        return
    # Position hurt box based on facing direction
    var facing = get_facing_direction()
    match facing:
        "right":
            hurt_box.position = Vector2(0, 0)
            hurt_box.rotation = 0
        "left":
            hurt_box.position = Vector2(0, 0)
            hurt_box.rotation = PI
        "up":
            hurt_box.position = Vector2(0, 0)
            hurt_box.rotation = -PI/2
        "down":
            hurt_box.position = Vector2(0, 0)
            hurt_box.rotation = PI/2
            
func get_input_direction():
    input_direction = Input.get_vector("left", "right", "up", "down")
    
    if input_direction.length() > 1.0:
        input_direction = input_direction.normalized()
    
    movement_direction = input_direction

func apply_movement():
    if movement_direction != Vector2.ZERO:
        velocity = velocity.lerp(movement_direction * speed, acceleration)
        last_direction = movement_direction
    else:
        velocity = velocity.lerp(Vector2.ZERO, friction)

func update_animations():

    # Prevent overwriting attack animations
    if is_attacking:
        return

    if movement_direction != Vector2.ZERO:
        current_state = AnimationState.WALK
    else:
        current_state = AnimationState.IDLE
    
    var animation_name = get_animation_name()
    
    if animated_sprite.animation != animation_name:
        animated_sprite.play(animation_name)

func get_animation_name() -> String:
    
    var direction = movement_direction if movement_direction != Vector2.ZERO else last_direction
    
    match current_state:
        AnimationState.IDLE:
            match get_direction_string(direction):
                "down":
                    return "idle_down"
                "left":
                    return "idle_left"
                "right":
                    return "idle_right"
                "up":
                    return "idle_up"
                _:
                    return "idle_down"
        
        AnimationState.WALK:
            match get_direction_string(direction):
                "down":
                    return "walk_down"
                "left":
                    return "walk_left"
                "right":
                    return "walk_right"
                "up":
                    return "walk_up"
                _:
                    return "walk_down"
    
    return "idle_down"

func get_direction_string(direction: Vector2) -> String:
    if abs(direction.x) > abs(direction.y):
        if direction.x > 0:
            return "right"
        else:
            return "left"
    elif abs(direction.y) > 0:
        if direction.y > 0:
            return "down"
        else:
            return "up"
    else:
        return get_direction_string(last_direction)


func play_attack_animation():

    var dir = get_facing_direction()
    var anim_name := ""

    if attack_combo == 0:
        anim_name = "attack_" + dir
    else:
        anim_name = "attack_" + dir + "_2"

    if animated_sprite.sprite_frames.has_animation(anim_name):
        animated_sprite.play(anim_name)
# -----------------------------------------------

# Reset attack state when animation ends
func _on_animation_finished():
    if "attack" in animated_sprite.animation:
        is_attacking = false

#Function to set speed dynamically
func set_speed(new_speed: float):
    speed = max(0.0, new_speed)

# Function to check if character is moving
func is_moving() -> bool:
    return movement_direction != Vector2.ZERO

#Get current facing direction
func get_facing_direction() -> String:
    return get_direction_string(last_direction)
