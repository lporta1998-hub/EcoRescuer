extends ColorRect
## Falling snow, made cheap enough for phones.
##
## The snow shader computes `num_of_layers` snowflake layers for every pixel it
## covers. Drawn directly at the iPhone's native resolution (about 3 million
## pixels when the camera is inside the snow area) with 40 layers, it made the
## level lag. Now the shader runs in a small SubViewport at `resolution_scale`
## of the rectangle's size and the result is stretched over the rectangle:
## the flakes are soft dots, so it looks the same for a fraction of the cost.
## On phones the number of layers is also reduced, and nothing is rendered
## while the snow area is off-screen.

@export_range(0.1, 1.0) var resolution_scale := 0.5
@export var mobile_layers := 18

var _viewport: SubViewport


func _ready() -> void:
	var mat := material as ShaderMaterial
	if mat == null:
		return
	if OS.has_feature("mobile"):
		mat.set_shader_parameter("num_of_layers", mobile_layers)

	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.size = Vector2i((size * resolution_scale).ceil())
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	var snow := ColorRect.new()
	snow.material = mat
	snow.color = color
	snow.size = Vector2(_viewport.size)
	_viewport.add_child(snow)

	# This node now only shows the rendered snow.
	material = null
	color = Color(1, 1, 1, 0)
	var view := TextureRect.new()
	view.texture = _viewport.get_texture()
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_SCALE
	view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	# The viewport stores colour already multiplied by alpha: blend it as such,
	# otherwise the flakes come out as grey smudges.
	var blend := CanvasItemMaterial.new()
	blend.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	view.material = blend
	add_child(view)

	# Only render while the snow area is on screen.
	var notifier := VisibleOnScreenNotifier2D.new()
	notifier.rect = Rect2(Vector2.ZERO, size)
	notifier.screen_entered.connect(func(): _viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS)
	notifier.screen_exited.connect(func(): _viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED)
	add_child(notifier)
