extends CombatCharacter
## Mira, the scientist: throws potions that splash for DOUBLE the basic
## attack damage, but she only has 2 hearts.

const HEARTS := 2

var last_direction = Vector2.RIGHT
@onready var heartsContainer = $CanvasLayer/HeartsContainer
## Buttons shown by the on-screen touch controls.
var touch_actions := {"primary": "POZIONE"}


func _ready() -> void:
	max_health = HEARTS
	health = HEARTS
	super()
	add_to_group("player")
	heartsContainer.setMaxHP(HEARTS)
	heartsContainer.updateHP(health)
	hpChanged.connect(heartsContainer.updateHP)


func _physics_process(delta: float) -> void:
	var raw := Input.get_vector("left", "right", "up", "down")
	input_direction = Vector2.ZERO if is_attacking else raw
	handle_footsteps(delta)
	super(delta)
	if Input.is_action_pressed("primary") and not is_attacking:
		handle_attack_input()
	if raw != Vector2.ZERO and not is_attacking:
		update_attack_direction(raw)
	if not is_attacking:
		handle_animations()


## The attack is a throw: no melee hit, a potion flies at the target.
func perform_melee_attack() -> void:
	speed = 0
	input_direction = Vector2.ZERO
	can_attack = false
	attack_cooldown.start(attack_cooldown_duration)
	play_attack_sound()
	is_attacking = true
	start_attack_animation()
	var from := global_position + Vector2(0, -16)
	var target := TouchControls.get_aim_position(self)
	if target.distance_to(from) > 170.0:
		target = from + (target - from).normalized() * 170.0
	PotionThrow.throw(get_parent(), from, target, attack_damage * 2, self)


func heal(amount: int) -> void:
	health = min(health + amount, max_health)
	hpChanged.emit(health)
