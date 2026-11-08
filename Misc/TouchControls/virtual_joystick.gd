class_name VirtualJoystick
extends Control
## Floating on-screen joystick.
##
## Touch anywhere inside this control to place the stick under your finger,
## then drag. The stick feeds the "left/right/up/down" input actions with
## analog strength, so every controller that calls
## Input.get_vector("left", "right", "up", "down") works without changes.

@export var radius := 80.0
@export var knob_radius := 34.0
@export var action_left: StringName = &"left"
@export var action_right: StringName = &"right"
@export var action_up: StringName = &"up"
@export var action_down: StringName = &"down"

## Where the stick sits when nobody is touching it (local coordinates).
var rest_position := Vector2.ZERO:
	set(value):
		rest_position = value
		if _touch_index == -1:
			_base = value
			queue_redraw()

## Current stick value, length 0..1.
var output := Vector2.ZERO

var _touch_index := -1
var _base := Vector2.ZERO
var _knob_offset := Vector2.ZERO
var _pressed_actions := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			if _touch_index == -1 and get_global_rect().has_point(event.position):
				_touch_index = event.index
				_base = _clamp_base(event.position - global_position)
				_update_knob(event.position)
				get_viewport().set_input_as_handled()
		elif event.index == _touch_index:
			reset()
			get_viewport().set_input_as_handled()

	elif event is InputEventScreenDrag and event.index == _touch_index:
		_update_knob(event.position)
		get_viewport().set_input_as_handled()


## Lets go of the stick and releases every action it was holding.
func reset() -> void:
	_touch_index = -1
	_base = rest_position
	_knob_offset = Vector2.ZERO
	output = Vector2.ZERO
	_apply_output()
	queue_redraw()


func _update_knob(global_touch: Vector2) -> void:
	var offset := (global_touch - global_position) - _base
	# If the finger runs past the rim, drag the base along so the player
	# never has to lift the thumb to re-centre the stick.
	if offset.length() > radius:
		_base = _clamp_base(_base + offset - offset.limit_length(radius))
		offset = (global_touch - global_position) - _base
	_knob_offset = offset.limit_length(radius)
	output = _knob_offset / radius
	_apply_output()
	queue_redraw()


func _clamp_base(local_pos: Vector2) -> Vector2:
	var lo := Vector2(radius, radius)
	var hi := (size - lo).max(lo)
	return local_pos.clamp(lo, hi)


func _apply_output() -> void:
	_set_action(action_left, maxf(0.0, -output.x))
	_set_action(action_right, maxf(0.0, output.x))
	_set_action(action_up, maxf(0.0, -output.y))
	_set_action(action_down, maxf(0.0, output.y))


func _set_action(action: StringName, strength: float) -> void:
	if strength > 0.0:
		Input.action_press(action, strength)
		_pressed_actions[action] = true
	elif _pressed_actions.has(action):
		Input.action_release(action)
		_pressed_actions.erase(action)


func _draw() -> void:
	var active := _touch_index != -1
	var ring_alpha := 0.55 if active else 0.3
	draw_circle(_base, radius, Color(0, 0, 0, 0.2 if active else 0.12))
	draw_arc(_base, radius, 0.0, TAU, 64, Color(1, 1, 1, ring_alpha), 3.0, true)
	draw_circle(_base + _knob_offset, knob_radius, Color(1, 1, 1, 0.55 if active else 0.3))
	draw_arc(_base + _knob_offset, knob_radius, 0.0, TAU, 48, Color(1, 1, 1, 0.8 if active else 0.4), 2.0, true)
