extends CombatCharacter
## Silvano, ancient god of nature: heavy punches (primary) and a spread of
## seeds (secondary). Weakness: pollution poisons him. Toxic barrels and
## puddles hurt him double, and he is slower than the other heroes.

const HEARTS := 4
const SPEED_FACTOR := 0.85
const SEED_COOLDOWN := 1.1

var last_direction = Vector2.RIGHT
@onready var heartsContainer = $CanvasLayer/HeartsContainer
var touch_actions := {"primary": "PUGNO", "secondary": "SEMI"}
var _seed_ready_at := 0.0


func _ready() -> void:
	max_health = HEARTS
	health = HEARTS
	super()
	add_to_group("player")
	speed *= SPEED_FACTOR
	base_speed *= SPEED_FACTOR
	original_speed *= SPEED_FACTOR
	heartsContainer.setMaxHP(HEARTS)
	heartsContainer.updateHP(health)
	hpChanged.connect(heartsContainer.updateHP)


func _physics_process(delta: float) -> void:
	var raw := Input.get_vector("left", "right", "up", "down")
	input_direction = Vector2.ZERO if is_attacking else raw
	super(delta)
	handle_footsteps(delta)
	if Input.is_action_pressed("primary") and not is_attacking:
		handle_attack_input()
	if Input.is_action_just_pressed("secondary"):
		shoot_seeds()
	if raw != Vector2.ZERO and not is_attacking:
		update_attack_direction(raw)
	if not is_attacking:
		handle_animations()


func shoot_seeds() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now < _seed_ready_at or is_dead:
		return
	_seed_ready_at = now + SEED_COOLDOWN
	var from := global_position + Vector2(0, -14)
	var dir := (TouchControls.get_aim_position(self) - from).normalized()
	if dir == Vector2.ZERO:
		dir = attack_direction
	for a in [-0.22, 0.0, 0.22]:
		SeedShot.fire(get_parent(), from, dir.rotated(a), self)
	SFXManager.play_sfx(preload("res://Audio/SFX/Attacks/Arrow.wav"), -6)


## Pollution is his weakness: toxic sources hurt double.
func take_damage(dmg: int, attacker) -> void:
	if attacker is OilBarrel or attacker is ToxicPuddle:
		dmg *= 2
		if not is_invincible_now() and not is_invincible:
			FloatText.spawn(self, "Veleno!", Color(0.6, 1.0, 0.3), Vector2(0, -40))
	super(dmg, attacker)


func heal(amount: int) -> void:
	health = min(health + amount, max_health)
	hpChanged.emit(health)
