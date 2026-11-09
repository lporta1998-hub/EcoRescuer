class_name FX
extends AnimatedSprite2D
## Short pixel-art effects (hit sparks, the "purify" puff of a defeated
## polluter, pickup sparkles...). The sheets are drawn by
## Tools/art/effects.py: one horizontal strip per effect.
##
##   FX.spawn("hit", level, where)            # plays once, then frees itself
##   FX.at_node("purify", enemy, Vector2(0, -12))
##   var s := FX.spawn("stars", brute, p); s.life = 1.5   # looping, timed

## name: [sheet, frame size, frame count, fps, loops]
const SHEETS := {
	"hit": [preload("res://Misc/FX/hit.png"), 24, 5, 20.0, false],
	"hurt": [preload("res://Misc/FX/hurt.png"), 24, 5, 16.0, false],
	"purify": [preload("res://Misc/FX/purify.png"), 48, 9, 13.0, false],
	"sparkle": [preload("res://Misc/FX/sparkle.png"), 32, 6, 18.0, false],
	"heal": [preload("res://Misc/FX/heal.png"), 32, 8, 12.0, false],
	"blast": [preload("res://Misc/FX/blast.png"), 64, 9, 15.0, false],
	"splash": [preload("res://Misc/FX/splash.png"), 32, 6, 14.0, false],
	"dust": [preload("res://Misc/FX/dust.png"), 16, 5, 14.0, false],
	"stars": [preload("res://Misc/FX/stars.png"), 32, 6, 10.0, true],
}

static var _frames := {}

## Seconds before a looping effect removes itself (-1 = until freed).
var life := -1.0


static func frames_for(effect: String) -> SpriteFrames:
	if _frames.has(effect):
		return _frames[effect]
	var d: Array = SHEETS[effect]
	var sf := SpriteFrames.new()
	sf.set_animation_speed("default", d[3])
	sf.set_animation_loop("default", d[4])
	var size: int = d[1]
	for i in int(d[2]):
		var at := AtlasTexture.new()
		at.atlas = d[0]
		at.region = Rect2(i * size, 0, size, size)
		sf.add_frame("default", at)
	_frames[effect] = sf
	return sf


## Plays `effect` centred on `at` (global position) as a child of `parent`.
static func spawn(effect: String, parent: Node, at: Vector2, tint := Color.WHITE, size := 1.0, z := 20) -> FX:
	if not SHEETS.has(effect) or parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return null
	var fx := FX.new()
	fx.sprite_frames = frames_for(effect)
	fx.modulate = tint
	fx.scale = Vector2(size, size)
	fx.z_index = z
	parent.add_child(fx)
	fx.global_position = at
	fx.play("default")
	if not SHEETS[effect][4]:
		fx.animation_finished.connect(fx.queue_free)
	return fx


## Plays `effect` where `target` is (plus `offset`), in the target's parent,
## so it stays behind when the target moves or is freed.
static func at_node(effect: String, target: Node2D, offset := Vector2.ZERO, tint := Color.WHITE, size := 1.0, z := 20) -> FX:
	if target == null or not is_instance_valid(target) or not target.is_inside_tree():
		return null
	return spawn(effect, target.get_parent(), target.global_position + offset, tint, size, z)


func _process(delta: float) -> void:
	if life >= 0.0:
		life -= delta
		if life <= 0.0:
			queue_free()
