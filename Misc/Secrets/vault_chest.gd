class_name VaultChest
extends StaticBody2D
## The chest of a secret vault. Locked while any guard of the vault stands;
## then walking into it opens it and pays the level's secret reward the first
## time (SecretSpots.claim). The count of guards left floats above it.

const CLOSED := preload("res://Collectibles/Assets/Sprites/eco_chest.png")
const OPEN := preload("res://Collectibles/Assets/Sprites/eco_chest_open.png")

var vault: SecretVault
var _sprite: Sprite2D
var _label: Label
var _locked := true
var _opened := false
var _check := 0.0


func _ready() -> void:
	collision_layer = 1 | 2
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(20, 10)
	shape.shape = rect
	shape.position = Vector2(0, 2)
	add_child(shape)
	_sprite = Sprite2D.new()
	_sprite.texture = CLOSED
	_sprite.offset = Vector2(0, -6)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 8)
	_label.add_theme_constant_override("outline_size", 4)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.size = Vector2(120, 12)
	_label.position = Vector2(-60, -34)
	add_child(_label)
	# touching it: a slightly bigger area than the body
	var touch := Area2D.new()
	touch.collision_layer = 0
	touch.collision_mask = 1
	var ts := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 18.0
	ts.shape = circle
	touch.add_child(ts)
	add_child(touch)
	touch.body_entered.connect(_on_touch)


func _process(delta: float) -> void:
	if _opened or vault == null:
		return
	_check -= delta
	if _check > 0.0:
		return
	_check = 0.25
	var left := vault.guards_left()
	if left > 0:
		_label.text = "Guardiani: %d" % left
		_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.5))
	elif _locked:
		_locked = false
		_label.text = "Aperto!"
		_label.add_theme_color_override("font_color", SecretPortal.COLOR)
		FX.spawn("sparkle", get_parent(), global_position + Vector2(0, -8), SecretPortal.COLOR, 1.5)
		SFXManager.play_sfx(preload("res://Audio/SFX/Eco/charge.wav"), -6)
		if LevelManager.objective_hud:
			LevelManager.objective_hud.toast("Guardiani sconfitti! Il forziere del caveau è aperto.", SecretPortal.COLOR)


func _on_touch(body: Node) -> void:
	if _opened or not body.is_in_group("player"):
		return
	if _locked:
		if LevelManager.objective_hud:
			LevelManager.objective_hud.toast("Il forziere è sigillato: sconfiggi prima tutti i guardiani.", Color(1.0, 0.55, 0.5))
		return
	_opened = true
	_sprite.texture = OPEN
	_label.text = ""
	SFXManager.play_sfx(preload("res://Audio/SFX/Eco/ui_buy.wav"))
	FX.spawn("sparkle", get_parent(), global_position + Vector2(0, -10), Color(1.0, 0.85, 0.4), 1.8)
	var level: LevelData = Global.selected_level_data
	var secret: Dictionary = Story.chapter_of(level).get("secret", {})
	var lines: Array = SecretSpots.claim(level)
	StoryCard.open(get_tree().current_scene, {
		"kicker": "Caveau segreto",
		"title": secret.get("title", "Il forziere"),
		"text": secret.get("text", ""),
		"lines": lines,
		"button": "Continua", "color": SecretPortal.COLOR, "icon": CLOSED})
