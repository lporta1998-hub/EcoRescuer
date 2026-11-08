class_name TouchActionButton
extends Control
## Round on-screen button that holds an input action while touched.
##
## Supports multitouch: it only reacts to the finger that started on it, so
## you can move with the joystick and press buttons at the same time.

enum Icon { NONE, PAUSE }

@export var action: StringName = &"primary"
@export var label := "":
	set(value):
		label = value
		queue_redraw()
@export var radius := 60.0:
	set(value):
		radius = value
		custom_minimum_size = Vector2.ONE * radius * 2.0
		size = custom_minimum_size
		queue_redraw()
## Makes the touch area a bit bigger than the drawn circle.
@export var hit_scale := 1.25
## Send the action as an InputEvent instead of only setting its state.
## Needed for scripts that listen in _input()/_unhandled_input(), like the
## pause menu.
@export var send_as_event := false
@export var icon := Icon.NONE
@export var font_size := 18

var _touch_index := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	radius = radius


func is_held() -> bool:
	return _touch_index != -1


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			if _touch_index == -1 and _hits(event.position):
				_touch_index = event.index
				_set_pressed(true)
				get_viewport().set_input_as_handled()
		elif event.index == _touch_index:
			reset()
			get_viewport().set_input_as_handled()


## Releases the button (used when the controls get hidden mid-press).
func reset() -> void:
	if _touch_index == -1:
		return
	_touch_index = -1
	_set_pressed(false)


func _hits(global_point: Vector2) -> bool:
	var center := global_position + size * 0.5
	return global_point.distance_to(center) <= radius * hit_scale


func _set_pressed(pressed: bool) -> void:
	if send_as_event:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		ev.strength = 1.0 if pressed else 0.0
		Input.parse_input_event(ev)
	elif pressed:
		Input.action_press(action)
	else:
		Input.action_release(action)
	queue_redraw()


func _draw() -> void:
	var held := is_held()
	var center := size * 0.5
	draw_circle(center, radius, Color(0, 0, 0, 0.35 if held else 0.2))
	draw_circle(center, radius, Color(1, 1, 1, 0.35 if held else 0.12))
	draw_arc(center, radius, 0.0, TAU, 64, Color(1, 1, 1, 0.85 if held else 0.5), 3.0, true)

	var fg := Color(1, 1, 1, 0.95 if held else 0.75)
	match icon:
		Icon.PAUSE:
			var bar := Vector2(radius * 0.22, radius * 0.9)
			var gap := radius * 0.14
			draw_rect(Rect2(center + Vector2(-gap - bar.x, -bar.y * 0.5), bar), fg)
			draw_rect(Rect2(center + Vector2(gap, -bar.y * 0.5), bar), fg)
		_:
			if label.is_empty():
				return
			var font := get_theme_default_font()
			var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
			var baseline := center.y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
			draw_string_outline(font, Vector2(center.x - text_size.x * 0.5, baseline), label,
					HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0, 0, 0, 0.6))
			draw_string(font, Vector2(center.x - text_size.x * 0.5, baseline), label,
					HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, fg)
