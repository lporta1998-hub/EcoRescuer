extends CanvasLayer
## On-screen controls for phones and tablets (autoloaded as "TouchControls").
##
## - Left half of the screen: floating joystick (feeds left/right/up/down).
## - Bottom right: "primary" button, plus "secondary" for characters that use it.
## - Top right: pause button (sends the "pause" action).
##
## The controls only appear on touch devices, during gameplay (a node in the
## "player" group exists) and while the game is not paused.
##
## To try them on a computer, turn on Project Settings > Input Devices >
## Pointing > Emulate Touch From Mouse, or run the game with the user
## argument "--touch".
##
## A character can customise its buttons by declaring, for example:
##     var touch_actions := {"primary": "ATTACCA", "secondary": "TIRA"}
## Only the actions listed get a button.
## If the character also has `secondary_cooldown_ratio() -> float` (1 = just
## used, 0 = ready), the secondary button shows the cooldown as a dark sweep.

const DEFAULT_TOUCH_ACTIONS := {"primary": "ATTACCA"}
const EDGE_PADDING := 28.0

## How far (in world pixels) auto-aim looks for an enemy.
@export var aim_assist_range := 420.0

## True when the game is running with touch controls.
var enabled := false

var _player: Node2D = null
var _targets: Array[Character] = []
var _target_refresh := 0.0

var _root: Control
var _joystick: VirtualJoystick
var _primary: TouchActionButton
var _secondary: TouchActionButton
var _pause: TouchActionButton


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	enabled = _detect_touch_mode()
	_build()
	_root.visible = false
	if not enabled:
		set_process(false)
		return
	_strip_mouse_bindings()
	get_viewport().size_changed.connect(_layout)
	_layout()


func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != _player:
		_player = player
		_configure_for_player()

	var should_show: bool = _player != null and not get_tree().paused and not _player.get("is_dead")
	if should_show != _root.visible:
		_root.visible = should_show
		if not should_show:
			release_all()

	if should_show:
		_update_cooldowns()
		_target_refresh -= delta
		if _target_refresh <= 0.0:
			_target_refresh = 0.25
			_refresh_targets()


func _notification(what: int) -> void:
	# Phone call, home button, notification centre...: drop every held input
	# so the character doesn't keep walking when the app comes back.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_node_ready():
			release_all()


## Releases the joystick and every button.
func release_all() -> void:
	_joystick.reset()
	_primary.reset()
	_secondary.reset()
	_pause.reset()


## Where a weapon/projectile fired by `from` should point.
## With a mouse: the cursor. On touch: the nearest enemy in range, otherwise
## straight ahead in the direction the player is facing.
func get_aim_position(from: Node2D) -> Vector2:
	if not enabled:
		return from.get_global_mouse_position()
	var origin := from.global_position
	var target := _nearest_target(origin)
	if target:
		return target.global_position
	return origin + _facing_direction() * 100.0


# --- Setup ---------------------------------------------------------------

func _detect_touch_mode() -> bool:
	if OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios"):
		return true
	if "--touch" in OS.get_cmdline_user_args():
		return true
	return ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse", false)


## Touches are also turned into mouse clicks (so menus work), which would
## make every tap on the screen fire the mouse-bound attacks. With touch
## controls those actions come from the on-screen buttons instead.
func _strip_mouse_bindings() -> void:
	for action in [&"primary", &"secondary"]:
		if not InputMap.has_action(action):
			continue
		for ev in InputMap.action_get_events(action):
			if ev is InputEventMouseButton:
				InputMap.action_erase_event(action, ev)


func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	_joystick = VirtualJoystick.new()
	_joystick.name = "Joystick"
	_root.add_child(_joystick)

	_secondary = TouchActionButton.new()
	_secondary.name = "Secondary"
	_secondary.action = &"secondary"
	_secondary.radius = 46.0
	_secondary.font_size = 16
	_root.add_child(_secondary)

	_primary = TouchActionButton.new()
	_primary.name = "Primary"
	_primary.action = &"primary"
	_primary.radius = 62.0
	_root.add_child(_primary)

	_pause = TouchActionButton.new()
	_pause.name = "Pause"
	_pause.action = &"pause"
	_pause.radius = 26.0
	_pause.hit_scale = 1.6
	_pause.send_as_event = true
	_pause.icon = TouchActionButton.Icon.PAUSE
	_root.add_child(_pause)

	_configure_for_player()


func _configure_for_player() -> void:
	var actions = DEFAULT_TOUCH_ACTIONS
	if _player:
		var custom = _player.get("touch_actions")
		if custom is Dictionary:
			actions = custom
	_primary.visible = actions.has("primary")
	_primary.label = actions.get("primary", "")
	_secondary.visible = actions.has("secondary")
	_secondary.label = actions.get("secondary", "")


func _update_cooldowns() -> void:
	if _secondary.visible and _player.has_method("secondary_cooldown_ratio"):
		_secondary.cooldown = _player.secondary_cooldown_ratio()
	else:
		_secondary.cooldown = 0.0


func _layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	var m := _safe_margins(vp)

	# Joystick zone: left 45% of the screen, below the hearts HUD.
	var top := vp.y * 0.3
	_joystick.position = Vector2(m.x, top)
	_joystick.size = Vector2(vp.x * 0.45 - m.x, vp.y - top - m.w)
	_joystick.rest_position = Vector2(
			EDGE_PADDING + _joystick.radius,
			_joystick.size.y - EDGE_PADDING - _joystick.radius)

	var primary_center := Vector2(
			vp.x - m.z - EDGE_PADDING - _primary.radius,
			vp.y - m.w - EDGE_PADDING - _primary.radius)
	_primary.position = primary_center - _primary.size * 0.5

	var secondary_center := primary_center + Vector2(
			-(_primary.radius + _secondary.radius + 18.0),
			-_secondary.radius * 0.9)
	_secondary.position = secondary_center - _secondary.size * 0.5

	_pause.position = Vector2(
			vp.x - m.z - EDGE_PADDING - _pause.size.x,
			m.y + EDGE_PADDING * 0.5)


## Notch / home-indicator margins in canvas units: x=left, y=top, z=right, w=bottom.
func _safe_margins(vp: Vector2) -> Vector4:
	if not OS.has_feature("mobile"):
		return Vector4.ZERO
	var win := Vector2(DisplayServer.window_get_size())
	if win.x <= 0.0 or vp.x <= 0.0:
		return Vector4.ZERO
	var safe := Rect2(DisplayServer.get_display_safe_area())
	# With stretch mode "canvas_items" the game is scaled to fit and may be
	# letterboxed; convert window pixels to canvas units.
	var s := minf(win.x / vp.x, win.y / vp.y)
	var offset := (win - vp * s) * 0.5
	return Vector4(
			maxf(0.0, safe.position.x - offset.x) / s,
			maxf(0.0, safe.position.y - offset.y) / s,
			maxf(0.0, (win.x - safe.end.x) - offset.x) / s,
			maxf(0.0, (win.y - safe.end.y) - offset.y) / s)


# --- Auto-aim ------------------------------------------------------------

func _refresh_targets() -> void:
	_targets.clear()
	var scene := get_tree().current_scene
	if scene == null:
		return
	for node in scene.find_children("*", "CharacterBody2D", true, false):
		if node is Character and not node.is_in_group("player"):
			_targets.append(node as Character)


func _nearest_target(origin: Vector2) -> Character:
	var best: Character = null
	var best_dist := aim_assist_range * aim_assist_range
	for target in _targets:
		if not is_instance_valid(target) or target.is_dead:
			continue
		var d := origin.distance_squared_to(target.global_position)
		if d < best_dist:
			best_dist = d
			best = target
	return best


func _facing_direction() -> Vector2:
	if _player:
		var dir = _player.get("look_direction")
		if dir is Vector2 and not dir.is_zero_approx():
			return dir.normalized()
	return Vector2.RIGHT
