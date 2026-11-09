extends CombatCharacter

var last_direction = Vector2.RIGHT
## Buttons shown by the on-screen touch controls.
var touch_actions := {"primary": "ATTACCA", "secondary": "ZAP"}
## ZAP: a bolt from his home-made zapper that chains (see ZapBolt).
const ZAP_COOLDOWN := 2.2
@onready var heartsContainer = $CanvasLayer/HeartsContainer

func _ready():
    super()
    add_to_group("player")

    heartsContainer.setMaxHP(3)
    heartsContainer.updateHP(self.health)
    self.hpChanged.connect(heartsContainer.updateHP)

func _process(delta):
    super(delta)
    
    

func _physics_process(delta):
    var raw_input = Input.get_vector("left","right","up","down")
    
    if is_attacking:
        input_direction = Vector2.ZERO
    else:
        input_direction = raw_input
    handle_footsteps(delta)
    super(delta)
    
    if Input.is_action_pressed("primary") and not is_attacking:
        handle_attack_input()
    if Input.is_action_just_pressed("secondary"):
        zap()
    
    if raw_input != Vector2.ZERO and not is_attacking:
        update_attack_direction(raw_input)
    
    if not is_attacking:
        handle_animations()

## Fires the zapper toward `target` (default: where the player aims).
## Returns false while cooling down.
func zap(target = null) -> bool:
    if not secondary_ready():
        return false
    start_secondary_cooldown(ZAP_COOLDOWN)
    var from := global_position + Vector2(0, -14)
    var dir: Vector2 = (target - from).normalized() if target is Vector2 else aim_direction(from)
    ZapBolt.fire(get_parent(), from, dir, self)
    SFXManager.play_sfx(preload("res://Audio/SFX/Attacks/Arrow.wav"), -4)
    return true

func update_facing_direction(direction: Vector2):
    if abs(direction.x) > abs(direction.y):
        last_direction = Vector2.LEFT if direction.x < 0 else Vector2.RIGHT
    else:
        last_direction = Vector2.UP if direction.y < 0 else Vector2.DOWN
    
    look_direction = direction

func heal(amount: int) -> void:
    health = min(health + amount, max_health)
    hpChanged.emit(health)
    _heal_fx()
