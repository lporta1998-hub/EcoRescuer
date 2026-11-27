extends Node
## Keeps every screen's buttons, counters and text clear of the iPhone notch
## / Dynamic Island, the rounded corners and the home indicator.
##
## Each screen is a CanvasLayer (or a Control at the root of the tree) whose
## direct Control children are laid out against the screen edges. When one is
## added, its children are moved into the safe area: a child anchored to the
## left edge moves right by the left margin, one anchored to the right edge
## moves left, a full-screen child shrinks to the safe area and a centred one
## stays where it is. Full-screen backgrounds (dims, the animated map behind
## the menus) are left alone so they still reach the edges.
##
## The side margins are the same on both sides (the larger of the two), so
## turning the phone round (notch left <-> right) never needs a new layout.
##
## Skip a node with `set_meta("safe_area_skip", true)`. Screens that already
## place themselves in the safe area (touch controls, objective HUD, the
## guide) are skipped.

const SKIP_META := &"safe_area_skip"
const BASE_META := &"safe_area_base"
const SKIP_SCRIPTS := [
	"res://Misc/TouchControls/touch_controls.gd",
	"res://Misc/LevelExit/objective_hud.gd",
	"res://Menu/Tutorial/tutorial.gd",
]
const BACKGROUND_SCENES := ["res://Menu/Background/control.tscn"]

var _fitted: Array[WeakRef] = []


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	get_viewport().size_changed.connect(_refit_all)


## Safe-area margins in canvas units: x=left, y=top, z=right, w=bottom.
## Left and right are the same (see above).
func margins() -> Vector4:
	var m: Vector4 = TouchControls._safe_margins(get_viewport().get_visible_rect().size)
	var side := maxf(m.x, m.z)
	return Vector4(side, m.y, side, m.w)


func _on_node_added(node: Node) -> void:
	if node is CanvasLayer or (node is Control and node.get_parent() == get_tree().root):
		# deferred: the screen builds its children in _ready()
		_fit_screen.call_deferred(node)


func _fit_screen(screen: Node) -> void:
	if not is_instance_valid(screen) or not screen.is_inside_tree() or _skipped(screen):
		return
	if margins() == Vector4.ZERO:
		return
	_fit_children(screen)


func _fit_children(parent: Node) -> void:
	for child in parent.get_children():
		if not child is Control or _skipped(child) or _is_background(child):
			continue
		# a plain full-screen holder (an overlay with its own dim behind a
		# panel): fit what is inside, so the dim still covers the edges
		if _is_full(child) and child.get_class() == "Control":
			_fit_children(child)
		else:
			_fit(child)


func _skipped(node: Node) -> bool:
	if node.has_meta(SKIP_META):
		return true
	var script: Script = node.get_script()
	return script != null and script.resource_path in SKIP_SCRIPTS


## Full-screen art that should keep reaching the edges.
func _is_background(c: Control) -> bool:
	if c.scene_file_path in BACKGROUND_SCENES:
		return true
	return _is_full(c) and (c is ColorRect or c is TextureRect)


static func _is_full(c: Control) -> bool:
	return c.anchor_left == 0.0 and c.anchor_top == 0.0 \
			and c.anchor_right == 1.0 and c.anchor_bottom == 1.0


func _fit(c: Control) -> void:
	if not c.has_meta(BASE_META):
		c.set_meta(BASE_META, Vector4(c.offset_left, c.offset_top, c.offset_right, c.offset_bottom))
		_fitted.append(weakref(c))
	var base: Vector4 = c.get_meta(BASE_META)
	var m := margins()
	# maps the whole screen onto the safe rectangle, anchor by anchor
	c.offset_left = base.x + m.x * (1.0 - c.anchor_left) - m.z * c.anchor_left
	c.offset_right = base.z + m.x * (1.0 - c.anchor_right) - m.z * c.anchor_right
	c.offset_top = base.y + m.y * (1.0 - c.anchor_top) - m.w * c.anchor_top
	c.offset_bottom = base.w + m.y * (1.0 - c.anchor_bottom) - m.w * c.anchor_bottom


func _refit_all() -> void:
	var alive: Array[WeakRef] = []
	for ref in _fitted:
		var c = ref.get_ref()
		if c != null and is_instance_valid(c):
			_fit(c)
			alive.append(ref)
	_fitted = alive
