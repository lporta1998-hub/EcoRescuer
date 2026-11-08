class_name FloatText
extends Node2D
## A short word that pops up over something in the level and floats away
## ("CRIT!", "+1 cuore", ...).

var _text := ""
var _color := Color.WHITE


## Shows `text` above `target` (a Node2D in the level).
static func spawn(target: Node2D, text: String, color: Color = Color.WHITE, offset := Vector2(0, -30)) -> void:
	if not is_instance_valid(target) or not target.is_inside_tree():
		return
	var ft := FloatText.new()
	ft._text = text
	ft._color = color
	ft.z_index = 100
	target.get_parent().add_child(ft)
	ft.global_position = target.global_position + offset


func _ready() -> void:
	var t := create_tween().set_parallel()
	t.tween_property(self, "position:y", position.y - 22.0, 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(self, "modulate:a", 0.0, 0.35).set_delay(0.45)
	scale = Vector2(0.6, 0.6)
	t.tween_property(self, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK)
	t.chain().tween_callback(queue_free)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var fs := 13
	var w := font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := Vector2(-w / 2.0, 0)
	draw_string_outline(font, pos, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.9))
	draw_string(font, pos, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, _color)
