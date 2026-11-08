extends CombatCharacter

var last_direction = Vector2.RIGHT
@export var current_weapon: Armi
@onready var shoot_cooldown: Timer = $ShootCooldown
var can_shoot = true 
@onready var heartsContainer = $CanvasLayer/HeartsContainer

# Variabili per gestire le animazioni di sparo
var is_shooting := false
var _has_shoot_animation := false
var _has_shoot_up_animation := false
var _has_shoot_down_animation := false
var _shoot_animation_length := 0.0
var _shoot_timer := 0.0
var shoot_direction := Vector2.RIGHT

# Buttons shown by the on-screen touch controls.
var touch_actions := {"primary": "ATTACCA", "secondary": "TIRA"}

func _ready():
    super()
    add_to_group("player")
    heartsContainer.setMaxHP(3)
    heartsContainer.updateHP(self.health)
    self.hpChanged.connect(heartsContainer.updateHP)
    
    # Controlla animazioni di sparo
    if sprite and sprite.sprite_frames:
        _has_shoot_animation = sprite.sprite_frames.has_animation("shoot")
        _has_shoot_up_animation = sprite.sprite_frames.has_animation("shoot_up")
        _has_shoot_down_animation = sprite.sprite_frames.has_animation("shoot_down")
        
        if _has_shoot_animation:
            var anim_frames = sprite.sprite_frames.get_frame_count("shoot")
            var anim_speed = sprite.sprite_frames.get_animation_speed("shoot")
            _shoot_animation_length = anim_frames / anim_speed
        else:
            _shoot_animation_length = 0.3

func _process(delta):
    super(delta)
    
    # Aggiorna timer sparo
    if is_shooting:
        _shoot_timer -= delta
        if _shoot_timer <= 0:
            is_shooting = false
            if not is_attacking:
                if active_boost > 0:
            # Mantieni la velocità con boost
                    speed = base_speed + active_boost
                else:
                    speed = original_speed
    
    # Input sparo - SOLO se current_weapon è valido
    if Input.is_action_just_pressed("secondary") and can_shoot and current_weapon != null:
        SFXManager.play_sfx(preload("res://Audio/SFX/Attacks/Arrow.wav"))
        handle_shoot_input()

func _physics_process(delta):
    # Salva input per movimento
    var raw_input = Input.get_vector("left","right","up","down")
    
    # Gestisci movimento durante attacchi
    if is_attacking or is_shooting:
        input_direction = Vector2.ZERO
    else:
        input_direction = raw_input
    
    super(delta)
    handle_footsteps(delta)
    
    # Gestisci attacco melee - questo FUNZIONA anche senza arma
    if Input.is_action_pressed("primary") and not is_attacking and not is_shooting:
        handle_attack_input()
    
    # Aggiorna direzione attacco (solo se non stiamo attaccando)
    if raw_input != Vector2.ZERO and not is_attacking:
        update_attack_direction(raw_input)
    
    # Gestisci animazioni
    if is_shooting:
        handle_shoot_animation()
    elif is_attacking:
        # L'animazione è già gestita da CombatCharacter
        pass
    else:
        handle_animations()

func handle_shoot_input():
    if current_weapon == null:
        print_debug("Nessuna arma equipaggiata!")
        return
    
    # Mouse cursor on desktop, auto-aim on touch screens.
    var aim_pos = TouchControls.get_aim_position(self)
    var direction = (aim_pos - global_position).normalized()
    
    shoot_direction = direction
    speed = 0
    input_direction = Vector2.ZERO
    is_shooting = true
    is_attacking = false
    _shoot_timer = _shoot_animation_length
    
    update_facing_direction(direction)
    
    # Ritardo per sincronizzare con animazione
    var shoot_delay = _shoot_animation_length * 0.5
    await get_tree().create_timer(shoot_delay).timeout
    
    # Controlla di nuovo se l'arma esiste ancora (potrebbe essere stata rimossa)
    if current_weapon != null:
        current_weapon.activate_with_direction(self, direction, get_tree())
        can_shoot = false
        shoot_cooldown.start(current_weapon.cooldown)
    else:
        # Se l'arma non c'è più, termina l'animazione
        is_shooting = false
        speed = original_speed

func handle_shoot_animation():
    var has_any_shoot_anim = _has_shoot_animation or _has_shoot_up_animation or _has_shoot_down_animation
    
    if not has_any_shoot_anim:
        is_shooting = false
        speed = original_speed
        handle_animations()
        return
    
    if abs(shoot_direction.x) > abs(shoot_direction.y):
        if _has_shoot_animation:
            sprite.play("shoot")
            sprite.flip_h = shoot_direction.x < 0
        elif _has_shoot_up_animation and shoot_direction.y < 0:
            sprite.play("shoot_up")
        elif _has_shoot_down_animation and shoot_direction.y > 0:
            sprite.play("shoot_down")
    else:
        if shoot_direction.y < 0 and _has_shoot_up_animation:
            sprite.play("shoot_up")
        elif shoot_direction.y > 0 and _has_shoot_down_animation:
            sprite.play("shoot_down")
        elif _has_shoot_animation:
            sprite.play("shoot")

func update_facing_direction(direction: Vector2):
    if abs(direction.x) > abs(direction.y):
        last_direction = Vector2.LEFT if direction.x < 0 else Vector2.RIGHT
    else:
        last_direction = Vector2.UP if direction.y < 0 else Vector2.DOWN
    
    look_direction = direction

func _on_shoot_cooldown_timeout() -> void:
    can_shoot = true

func heal(amount: int) -> void:
    health = min(health + amount, max_health)
    hpChanged.emit(health)
