extends BuiltLevel
## The final level: explore the dump and the fortress, complete the objective
## (trash bags + Inquinatori) to open the arena gate (G cells), then walk to
## the recycling station inside the arena: the gate slams shut and the
## Barone dei Rifiuti's MECCA-RIFIUTI wakes up. Beating it ends the game.

const BOSS_SCENE := preload("res://Boss/Boss.tscn")
const BARON_SCENE := preload("res://Boss/Baron/Baron.tscn")

var boss: Boss
var boss_defeated := false
var fight_started := false
var _gates_open := false
var _bar: CanvasLayer
var _bar_fill: ColorRect
var _bar_ghost: ColorRect
## What the Barone says before boarding, the boss's exported values to change
## and the toast when it's beaten (the Escape level sets its own).
var intro_lines: Array = [
	["Benvenuti nella mia fortezza, piccoli ambientalisti!", 2.4],
	["Io compro tutto: politici, isole... e questa armatura da un miliardo.", 2.8],
]
var boss_overrides := {}
var defeat_text := "Il MECCA-RIFIUTI è distrutto! NEXUS si spegne..."


func build() -> void:
	super()
	close_gates()
	if boss_spawn != Vector2.INF:
		boss = BOSS_SCENE.instantiate()
		for key in boss_overrides:
			boss.set(key, boss_overrides[key])
		boss.position = boss_spawn
		add_child(boss)
		boss.owner = self
		boss.defeated.connect(_on_boss_defeated)
		boss.health_changed.connect(_on_boss_health)


func _process(_delta: float) -> void:
	if not _gates_open and not fight_started and LevelManager.current_level == self and LevelManager.objective_met():
		_open_gates()


func _open_gates() -> void:
	_gates_open = true
	open_gates()
	for c in gates:
		if LevelManager.route_guide:
			LevelManager.route_guide.set_area_walkable(Rect2(Vector2(c * TILE), Vector2(TILE, TILE)), true)
	if LevelManager.objective_hud:
		LevelManager.objective_hud.toast("Il cancello dell'arena è aperto! Entra e affronta il Barone.", Color(1.0, 0.6, 0.4))
		LevelManager.objective_hud.refresh_route()


## Called by LevelManager when the player reaches the station in the arena.
func start_boss_fight() -> void:
	if fight_started:
		return
	fight_started = true
	close_gates()
	for c in gates:
		if LevelManager.route_guide:
			LevelManager.route_guide.set_area_walkable(Rect2(Vector2(c * TILE), Vector2(TILE, TILE)), false)
	if LevelManager.level_exit:
		LevelManager.level_exit.visible = false
		LevelManager.level_exit.set_deferred("monitoring", false)
	if LevelManager.objective_hud:
		LevelManager.objective_hud.exit_node = null
		LevelManager.objective_hud._label.text = "Sconfiggi il MECCA-RIFIUTI!"
		LevelManager.objective_hud._label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4))
		LevelManager.objective_hud.toast("IL BARONE DEI RIFIUTI ATTACCA!", Color(1.0, 0.45, 0.35))
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		player.set_physics_process(false)
		player.velocity = Vector2.ZERO
	await _boarding_cutscene(player)
	if is_instance_valid(player):
		player.set_physics_process(true)
	_make_bar()
	if boss:
		boss.activate()


## The Barone walks to his armored suit, which stands open and dark; he leaps
## into the chest, the plates close over him and the visor lights up.
func _boarding_cutscene(player: Node2D) -> void:
	if boss == null:
		return
	var suit := boss.get_node("AnimatedSprite2D") as AnimatedSprite2D
	# pan the camera up to the suit for the scene
	var cam := player.get_node_or_null("Camera2D") as Camera2D if player else null
	if cam:
		var pan := create_tween()
		pan.tween_property(cam, "offset", boss.global_position + Vector2(-30, -50) - player.global_position, 0.8) \
				.set_trans(Tween.TRANS_SINE)
		await pan.finished
	var baron: Node2D = BARON_SCENE.instantiate()
	add_child(baron)
	baron.global_position = boss.global_position + Vector2(-96, 34)
	baron.face("right")
	await get_tree().create_timer(0.4).timeout
	for line in intro_lines:
		await baron.say(line[0], line[1])
	await baron.walk_to(boss.global_position + Vector2(0, 14), 1.2)
	baron.face("up")
	await get_tree().create_timer(0.3).timeout
	# a green light from the open cockpit
	var light := create_tween()
	light.tween_property(suit, "modulate", Color(1.3, 1.6, 1.3), 0.25)
	light.tween_property(suit, "modulate", Color.WHITE, 0.35)
	await baron.say("Armatura, apriti!", 1.2)
	# leap up into the chest
	var cockpit := boss.global_position + Vector2(0, -78)
	var start := baron.global_position
	var tw := create_tween()
	tw.tween_method(func(v: float):
		baron.global_position = start.lerp(cockpit, v) + Vector2(0, -30.0 * sin(v * PI))
		baron.scale = Vector2.ONE * lerpf(1.0, 0.75, v), 0.0, 1.0, 0.6)
	tw.tween_property(baron, "modulate:a", 0.0, 0.2)
	await tw.finished
	baron.queue_free()
	# plates close, the reactor and the visor light up
	suit.play("boot")
	SFXManager.play_sfx(preload("res://Audio/SFX/Eco/charge.wav"), -2)
	await get_tree().create_timer(0.7).timeout
	var flash := create_tween()
	flash.tween_property(suit, "modulate", Color(2.2, 2.4, 2.2), 0.08)
	flash.tween_property(suit, "modulate", Color.WHITE, 0.4)
	_shake(player, 1.0)
	if LevelManager.objective_hud:
		LevelManager.objective_hud.toast("MECCA-RIFIUTI ATTIVATO!", Color(1.0, 0.4, 0.3))
	await get_tree().create_timer(0.9).timeout
	if cam:
		var back := create_tween()
		back.tween_property(cam, "offset", Vector2.ZERO, 0.6).set_trans(Tween.TRANS_SINE)
		await back.finished


func _shake(player: Node2D, seconds: float) -> void:
	var cam := player.get_node_or_null("Camera2D") as Camera2D if player else null
	if cam == null:
		return
	var base := cam.offset
	var tw := create_tween()
	for i in int(seconds / 0.05):
		tw.tween_property(cam, "offset", base + Vector2(randf_range(-4, 4), randf_range(-3, 3)), 0.05)
	tw.tween_property(cam, "offset", base, 0.05)


func _on_boss_health(current: float, maximum: float) -> void:
	if _bar_fill == null:
		return
	var w := 520.0 * clampf(current / maximum, 0.0, 1.0)
	_bar_fill.size.x = w
	var tw := create_tween()
	tw.tween_property(_bar_ghost, "size:x", w, 0.4).set_delay(0.15)


func _on_boss_defeated() -> void:
	boss_defeated = true
	Progress.add_stat("boss_kills")
	if _bar:
		_bar.queue_free()
	if LevelManager.objective_hud:
		LevelManager.objective_hud.toast(defeat_text, Color(0.6, 1.0, 0.5))
	await get_tree().create_timer(2.0).timeout
	LevelManager.show_end_level_menu()


func _make_bar() -> void:
	_bar = CanvasLayer.new()
	_bar.layer = 2
	add_child(_bar)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	root.offset_left = -270
	root.offset_right = 270
	root.offset_top = -78
	root.offset_bottom = -30
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(root)
	var title := Label.new()
	title.text = "BARONE DEI RIFIUTI · MECCA-RIFIUTI"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_constant_override("outline_size", 6)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	title.add_theme_color_override("font_color", Color(1.0, 0.75, 0.6))
	title.position = Vector2(0, 0)
	title.size = Vector2(540, 22)
	root.add_child(title)
	var back := ColorRect.new()
	back.color = Color(0.08, 0.04, 0.06, 0.85)
	back.position = Vector2(8, 26)
	back.size = Vector2(524, 16)
	root.add_child(back)
	_bar_ghost = ColorRect.new()
	_bar_ghost.color = Color(1, 1, 1, 0.8)
	_bar_ghost.position = Vector2(10, 28)
	_bar_ghost.size = Vector2(520, 12)
	root.add_child(_bar_ghost)
	_bar_fill = ColorRect.new()
	_bar_fill.color = Color(0.85, 0.2, 0.2)
	_bar_fill.position = Vector2(10, 28)
	_bar_fill.size = Vector2(520, 12)
	root.add_child(_bar_fill)
