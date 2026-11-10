# CombatCharacter.gd
class_name CombatCharacter extends Character

# Variabili per l'attacco melee
@export var attack_cooldown_duration: float = 0.5
@export var attack_damage: int = 1
@export var invincibility_duration: float = 1.0
@export var attack_sound: AudioStream = preload("res://Audio/SFX/Attacks/Basic_Attack.wav")

@onready var attack_cooldown: Timer = $AttackCooldown
@onready var hurt_box: Area2D = $HurtBox
@onready var hurt_box_collider: CollisionPolygon2D = $HurtBox/HurtBoxCollider
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var can_attack := true
var is_attacking := false
var attack_direction := Vector2.RIGHT
var original_speed := 0.0
var is_invincible: bool = false

# Variabili per le animazioni di attacco
var _has_attack_animation := false
var _has_attack_up_animation := false
var _has_attack_down_animation := false

# Cooldown of the hero's secondary move (ranged move of the melee heroes).
var _secondary_left := 0.0
var _secondary_total := 1.0

## Deflect: the melee HurtBox must overlap enemy projectiles. EnemyShot
## (sludge blobs, drone bolts) is an Area2D on layer 3 "Enemy" (value 4, like
## enemy bodies), which every hero HurtBox already masks; enable_deflect also
## adds layer 7 "Enemy Attack" so projectiles put there work too. A projectile
## needs monitorable = true, group "deflectable" and a deflect(by) method.
const ENEMY_LAYER := 3
const ENEMY_ATTACK_LAYER := 7

func _ready():
    super()
    original_speed = speed
    enable_deflect(hurt_box)
    # Breakable objects (vases, crates, barricades) are StaticBody2D on layer
    # 1: some heroes' hurt boxes only saw layer 3 (enemies) and couldn't break
    # them. perform_melee_attack skips the hero itself.
    if hurt_box:
        hurt_box.set_collision_mask_value(1, true)
    
    # Controlla animazioni di attacco disponibili
    if sprite and sprite.sprite_frames:
        _has_attack_animation = sprite.sprite_frames.has_animation("attack")
        _has_attack_up_animation = sprite.sprite_frames.has_animation("attack_up")
        _has_attack_down_animation = sprite.sprite_frames.has_animation("attack_down")
    
    # Connetti il segnale animation_finished per gestire la fine dell'attacco
    if sprite:
        sprite.animation_finished.connect(_on_animation_finished)
        
func _process(delta):
    super(delta)
    _secondary_left = maxf(0.0, _secondary_left - delta)
    if not is_attacking:
        if active_boost > 0:
            speed = base_speed + active_boost
        else:
            speed = original_speed
        
func _on_animation_finished():
    if is_attacking:
        # Se l'animazione che è finita è un'animazione di attacco
        var current_anim = sprite.animation
        if current_anim in ["attack", "attack_up", "attack_down"]:
            end_attack()

func handle_attack_input():
  
    if can_attack and not is_attacking:
        perform_melee_attack()

func perform_melee_attack():
    # Ferma il movimento durante l'attacco
    speed = 0
    input_direction = Vector2.ZERO
    
    # Applica danno ai nemici nell'area
    deflect_overlapping(hurt_box, self)
    var bodies = hurt_box.get_overlapping_bodies()
    for b in bodies:
        if b == self:
            continue
        if b is Character or b.has_method("take_damage"):
            b.take_damage(attack_damage, self)
    
    # Gestione cooldown
    can_attack = false
    attack_cooldown.start(attack_cooldown_duration)
    
    # Riproduci suono - CORREZIONE QUI
    play_attack_sound()
    
    # Avvia animazione
    is_attacking = true
    start_attack_animation()

func play_attack_sound():

    if attack_sound:
        # Metodo 1: Se SFXManager è un autoload (nome del file = nome del singleton)
        if has_node("/root/SFXManager"):
            SFXManager.play_sfx(attack_sound)
        # Metodo 2: Se è un nodo normale nella scena
        elif has_node("SFXManager"):
            $SFXManager.play_sfx(attack_sound)

func start_attack_animation():
   
    if not _has_attack_animation and not _has_attack_up_animation and not _has_attack_down_animation:
        end_attack()
        return
    
    # Determina quale animazione usare
    if abs(attack_direction.x) > abs(attack_direction.y):
        # Attacco orizzontale
        if _has_attack_animation:
            sprite.play("attack")
            sprite.flip_h = attack_direction.x < 0
        else:
            # Fallback se non c'è animazione orizzontale
            end_attack()
    else:
        # Attacco verticale
        if attack_direction.y < 0 and _has_attack_up_animation:
            sprite.play("attack_up")
        elif attack_direction.y > 0 and _has_attack_down_animation:
            sprite.play("attack_down")
        elif _has_attack_animation:
            # Fallback all'animazione orizzontale
            sprite.play("attack")
            sprite.flip_h = attack_direction.x < 0
        else:
            end_attack()

func end_attack():
  
    is_attacking = false
    speed = original_speed

func update_attack_direction(direction: Vector2):
   
    if direction != Vector2.ZERO:
        attack_direction = direction.normalized()
        update_hurt_box_rotation()

func update_hurt_box_rotation():

    if hurt_box and is_instance_valid(hurt_box):
        if abs(attack_direction.x) > abs(attack_direction.y):
            hurt_box.rotation = PI if attack_direction.x < 0 else 0
        else:
            hurt_box.rotation = -PI/2 if attack_direction.y < 0 else PI/2

func take_damage(dmg: int, attacker):
    # Ignore hits while blinking after the previous one.
    if is_invincible or is_dead:
        return
    super(dmg, attacker)
    
    if not is_dead and health > 0:
        start_invincibility()

func start_invincibility() -> void:
    is_invincible = true
    
    var timer = 0.0
    while timer < invincibility_duration:
        if not is_instance_valid(sprite) or is_dead:
            sprite.visible = true
            is_invincible = false
            return
        
        sprite.visible = not sprite.visible
        await get_tree().create_timer(0.1).timeout
        timer += 0.1
    
    if is_instance_valid(sprite):
        sprite.visible = true
    is_invincible = false

func _on_attack_cooldown_timeout() -> void:
    can_attack = true


# --- Secondary move cooldown -------------------------------------------------

func secondary_ready() -> bool:
    return _secondary_left <= 0.0 and not is_dead

func start_secondary_cooldown(seconds: float) -> void:
    _secondary_total = maxf(seconds, 0.01)
    _secondary_left = seconds

## 1 = just used, 0 = ready. Read by TouchControls for the button's sweep.
func secondary_cooldown_ratio() -> float:
    return clampf(_secondary_left / _secondary_total, 0.0, 1.0)

## Direction from `from` to where the player is aiming (touch auto-aim or mouse).
func aim_direction(from: Vector2) -> Vector2:
    var dir := TouchControls.get_aim_position(self) - from
    return attack_direction if dir.is_zero_approx() else dir.normalized()


# --- Deflect -----------------------------------------------------------------

## Lets the melee hurt box see enemy projectiles (layers 3 and 7).
static func enable_deflect(box: Area2D) -> void:
    if box:
        box.monitoring = true
        box.set_collision_mask_value(ENEMY_LAYER, true)
        box.set_collision_mask_value(ENEMY_ATTACK_LAYER, true)

## A melee swing bats back every deflectable enemy projectile it touches.
## Returns how many were deflected.
static func deflect_overlapping(box: Area2D, by: Node) -> int:
    var count := 0
    if box == null:
        return count
    for a in box.get_overlapping_areas():
        if a.is_in_group("deflectable") and a.has_method("deflect"):
            a.deflect(by)
            count += 1
    return count
