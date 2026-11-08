extends CombatCharacter
## ECO-9, a pollution robot that went rogue to help humans. No hearts: an
## energy bar that drains as time passes; enemy hits drain it further.
## Batteries (they appear in the levels only when ECO-9 is playing) recharge
## it. In exchange: huge strength and speed.

const MAX_ENERGY := 100.0
const DRAIN_PER_SECOND := 0.8
const HIT_COST := 15.0
const BATTERY_CHARGE := 45.0
const HEART_CHARGE := 12.0
const SPEED_FACTOR := 1.6

var last_direction = Vector2.RIGHT
var touch_actions := {"primary": "COLPO"}
var _bar: Control
var _low_warned := false


func _ready() -> void:
	max_health = MAX_ENERGY
	health = MAX_ENERGY
	super()
	add_to_group("player")
	speed *= SPEED_FACTOR
	base_speed *= SPEED_FACTOR
	original_speed *= SPEED_FACTOR
	$CanvasLayer/HeartsContainer.visible = false
	_make_bar()


## LevelManager places batteries in the level when the hero needs them.
func uses_batteries() -> bool:
	return true


func _process(delta: float) -> void:
	super(delta)
	if is_dead or get_tree().paused:
		return
	# energy drains with time (no hpChanged: that's only for real hits)
	health = maxf(0.0, health - DRAIN_PER_SECOND * delta)
	if health < 25.0 and not _low_warned:
		_low_warned = true
		if LevelManager.objective_hud:
			LevelManager.objective_hud.toast("Energia bassa! Cerca una batteria.", Color(1.0, 0.6, 0.3))
	elif health > 35.0:
		_low_warned = false
	_bar.queue_redraw()


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


## A hit costs energy: HIT_COST for every heart it would have taken.
func take_damage(dmg: int, attacker) -> void:
	super(int(dmg * HIT_COST), attacker)


func heal(amount: int) -> void:
	recharge(amount * HEART_CHARGE)


func recharge(amount: float) -> void:
	health = minf(max_health, health + amount)
	FloatText.spawn(self, "+%d" % int(amount), Color(0.4, 1.0, 0.6), Vector2(0, -44))


func _make_bar() -> void:
	_bar = Control.new()
	_bar.position = Vector2(14, 10)
	_bar.size = Vector2(200, 30)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.draw.connect(_draw_bar)
	$CanvasLayer.add_child(_bar)


func _draw_bar() -> void:
	var r := clampf(health / max_health, 0.0, 1.0)
	var col := Color(0.3, 0.95, 0.5) if r > 0.5 else (Color(1.0, 0.8, 0.25) if r > 0.25 else Color(1.0, 0.3, 0.25))
	_bar.draw_rect(Rect2(0, 0, 196, 26), Color(0.05, 0.06, 0.08, 0.85))
	_bar.draw_rect(Rect2(196, 7, 6, 12), Color(0.05, 0.06, 0.08, 0.85))
	_bar.draw_rect(Rect2(3, 3, 190 * r, 20), col)
	for i in range(1, 5):
		_bar.draw_line(Vector2(3 + 38 * i, 3), Vector2(3 + 38 * i, 23), Color(0, 0, 0, 0.35), 2.0)
	var font := ThemeDB.fallback_font
	_bar.draw_string_outline(font, Vector2(8, 19), "ENERGIA %d%%" % int(r * 100), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color(0, 0, 0, 0.8))
	_bar.draw_string(font, Vector2(8, 19), "ENERGIA %d%%" % int(r * 100), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
