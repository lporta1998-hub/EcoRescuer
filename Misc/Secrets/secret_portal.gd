class_name SecretPortal
extends Area2D
## A portal of the secret vault. The entrance stands in the level's secret
## area (hidden behind crates or vases, in shadow until they break); the exit
## stands in the vault. Walking in fades out, moves the player and keeps the
## camera inside the room it arrives in.

const COLOR := Color(0.55, 0.95, 1.0)
const ICON := preload("res://Menu/Stars/star_full.png")
const RADIUS := 13.0

## The vault this portal leads into (entrance) or out of (exit).
var vault: SecretVault
## Where the exit portal sends you back to (global: the entrance portal, you
## land beside it), set by SecretSpots, and
## the entrance it comes back next to (ignores you for a moment, so you don't
## bounce straight back in).
var back_to := Vector2.ZERO
var entrance: SecretPortal
var _busy := false
var _time := 0.0


## Hidden and inert until its seals break (SecretSpots.seal_portal).
func close() -> void:
	visible = false
	set_deferred("monitoring", false)


## Opens with a flash where the seals were.
func open_up() -> void:
	visible = true
	monitoring = true
	scale = Vector2.ZERO
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE * 1.3, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE, 0.2)
	FX.spawn("sparkle", get_parent(), global_position, COLOR, 1.8)
	SFXManager.play_sfx(preload("res://Audio/SFX/Eco/teleport.wav"), -4)
	if LevelManager.objective_hud:
		LevelManager.objective_hud.toast("Un portale si è aperto!", COLOR)


func is_entrance() -> bool:
	return name != "VaultExit"


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1  # Player
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS - 3.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	z_index = -1  # on the floor, under the characters


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.55))  # lying on the floor
	draw_circle(Vector2.ZERO, RADIUS + 2.0, Color(0.05, 0.15, 0.2, 0.75))
	for i in 3:
		var r := RADIUS - i * 3.5
		var a := _time * (2.2 - i * 0.6) * (1 if i % 2 == 0 else -1)
		draw_arc(Vector2.ZERO, r, a, a + PI * 1.4, 18, Color(COLOR, 0.95 - i * 0.2), 2.0)
	draw_circle(Vector2.ZERO, 3.0 + sin(_time * 4.0), Color(0.9, 1.0, 1.0, 0.9))


## An open spot right next to `p` (the entrance portal), on whichever side
## has floor, so you come back out where you went in.
func _beside(p: Vector2) -> Vector2:
	var rg := LevelManager.route_guide
	if rg == null or not rg.is_ready():
		return p + Vector2(0, 28)
	for d in [Vector2(0, 26), Vector2(0, -26), Vector2(26, 0), Vector2(-26, 0), Vector2(20, 20), Vector2(-20, 20)]:
		if rg.is_open(p + d) and rg.is_open(p + d * 0.5):
			return p + d
	return rg.open_spot(p + Vector2(0, 28), 2)


## Ignores the player for `seconds`.
func rest(seconds: float) -> void:
	_busy = true
	await get_tree().create_timer(seconds).timeout
	_busy = false


func _on_body_entered(body: Node) -> void:
	if _busy or not visible or not body.is_in_group("player") or vault == null:
		return
	_busy = true
	SFXManager.play_sfx(preload("res://Audio/SFX/Eco/teleport.wav"))
	body.set_physics_process(false)
	var going_in := is_entrance()
	var done := func():
		body.velocity = Vector2.ZERO
		var cam := body.get_node_or_null("Camera2D") as Camera2D
		if going_in:
			body.global_position = vault.entry_global() + Vector2(0, -20)
			if cam:
				cam.set_meta("vault_saved_limits", [cam.limit_left, cam.limit_top, cam.limit_right, cam.limit_bottom])
				var r := vault.world_rect().grow(48.0)
				cam.limit_left = int(r.position.x)
				cam.limit_top = int(r.position.y)
				cam.limit_right = int(r.end.x)
				cam.limit_bottom = int(r.end.y)
		else:
			var to := _beside(back_to)
			body.global_position = to
			if cam and cam.has_meta("vault_saved_limits"):
				var l: Array = cam.get_meta("vault_saved_limits")
				cam.limit_left = l[0]
				cam.limit_top = l[1]
				cam.limit_right = l[2]
				cam.limit_bottom = l[3]
				cam.remove_meta("vault_saved_limits")
			if entrance:
				entrance.rest(1.5)
		if cam:
			cam.reset_smoothing()
		LevelManager.on_player_teleported()
	if LevelManager.fade_layer:
		await LevelManager.fade_layer.fade_out_then(done)
	else:
		done.call()
	if is_instance_valid(body):
		body.set_physics_process(true)
	if going_in and LevelManager.objective_hud:
		var left := vault.guards_left()
		LevelManager.objective_hud.toast(
				"Caveau segreto! Sconfiggi i %d guardiani per aprire il forziere." % left if left > 0
				else "Caveau segreto!", COLOR)
	await get_tree().create_timer(0.8).timeout
	_busy = false
