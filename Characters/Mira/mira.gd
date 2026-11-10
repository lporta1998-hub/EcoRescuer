extends CombatCharacter
## Mira, the scientist: throws potions that splash for DOUBLE the basic
## attack damage, but she only has 2 hearts. Up close she swings her lab
## staff (secondary): a quick melee hit that also breaks vases and crates and
## bats back enemy shots.

const HEARTS := 2

var last_direction = Vector2.RIGHT
@onready var heartsContainer = $CanvasLayer/HeartsContainer
## Buttons shown by the on-screen touch controls.
var touch_actions := {"primary": "POZIONE", "secondary": "BASTONE"}
const STAFF_COOLDOWN := 0.55
const STAFF_REACH := 48.0


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
	if Input.is_action_just_pressed("secondary"):
		staff_swing()
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


## BASTONE: a melee swing toward where the player aims. Returns false while
## cooling down.
func staff_swing() -> bool:
	if not secondary_ready():
		return false
	start_secondary_cooldown(STAFF_COOLDOWN)
	# Mouse: swing where it points. Touch: auto-aim only at a close enemy,
	# otherwise swing where she's facing (a vase in front, not a far enemy).
	var aim := TouchControls.get_aim_position(self)
	if not TouchControls.enabled or aim.distance_to(global_position) <= STAFF_REACH:
		update_attack_direction(aim - global_position)
	await get_tree().physics_frame  # let the hurt box turn before checking it
	deflect_overlapping(hurt_box, self)
	for b in hurt_box.get_overlapping_bodies():
		if b != self and b.has_method("take_damage"):
			b.take_damage(attack_damage, self)
	play_attack_sound()
	FX.spawn("hit", get_parent(), global_position + Vector2(0, -8) + attack_direction * 16.0)
	return true


func heal(amount: int) -> void:
	health = min(health + amount, max_health)
	hpChanged.emit(health)
	_heal_fx()
