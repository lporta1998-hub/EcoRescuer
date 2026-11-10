class_name RageRun
extends Node
## One Rage match (see Rage): rounds of enemies until the player dies.
## LevelManager adds it to the level instead of the normal objective and
## forwards kills to on_kill(); show_game_over_menu() calls finish().
##
## A round spawns round_size() enemies, one every spawn_interval() seconds
## and never more than max_alive() at once, around the player out of sight.
## When they're all down there's a short break. Every Rage.BOSS_EVERY rounds
## the round is a boss: a huge buffed enemy or, every third boss, the
## Barone's MECCA-RIFIUTI; beating it lets the player pick a permanent perk.

const BASIC := "res://Default_Enemy/Enemy.tscn"
const ELITE := "res://EliteEnemy/Scenes/Elite.tscn"
const BOSS_SCENE := "res://Boss/Boss.tscn"
# --- Difficulty: the numbers to tweak --------------------------------------
const BREAK := 6.0
const FIRST_BREAK := 3.0
const SPAWN_MIN_DIST := 230.0
const SPAWN_MAX_DIST := 440.0
const PICKUP_FIRST := 5.0
const PICKUP_EVERY := 13.0
const MAX_PICKUPS := 3
## Hearts healed at the end of every round (Rigenerazione adds more).
const ROUND_HEAL := 1
const REALERT_EVERY := 1.5
const MINION_EVERY := 9.0
## ECO-9's batteries: one every BATTERY_EVERY seconds (sooner when low).
const BATTERY_EVERY := 12.0
const MAX_BATTERIES := 2
const RED := Color(1.0, 0.45, 0.4)
const GOLD := Color(1.0, 0.83, 0.3)
const GREEN := Color(0.65, 0.95, 0.3)

## Buffed enemies that can be a boss (the Bomber would blow itself up).
const BOSS_TYPES := {"brute": "Bruto furioso", "sprayer": "Spruzzatore gigante",
		"drone": "Drone madre", "elite": "Capobanda"}

var level: Node2D
## Current round (1 = first).
var wave := 0
var kills := 0
var bosses := 0
## "break" between rounds, "fight", "boss", "choice" (picking a perk), "over".
var state := "break"
var _timer := FIRST_BREAK
var _to_spawn := 0
var _round_total := 0
var _alive: Array = []
var _boss: Node2D
var _boss_name := ""
var _spawn_timer := 0.0
var _minion_timer := 0.0
var _pickup_timer := PICKUP_FIRST
var _alert_timer := 0.0
var _battery_timer := 4.0
var _rng := RandomNumberGenerator.new()
var _bar: CanvasLayer
var _bar_fill: ColorRect


func _init(level_node: Node2D) -> void:
	level = level_node
	name = "RageRun"


func _ready() -> void:
	_rng.randomize()
	if LevelManager.objective_hud:
		LevelManager.objective_hud.set_objective_icon(preload("res://Menu/Shop/Icons/fist.png"))
	update_hud()
	_toast("RAGE MODE! Sopravvivi più round che puoi.", RED)


# --- Loop -------------------------------------------------------------------

func _process(delta: float) -> void:
	if state in ["over", "choice"]:
		return
	var p := _player()
	if p == null or p.is_dead:
		return
	_alert_timer -= delta
	if _alert_timer <= 0.0:
		_alert_timer = REALERT_EVERY
		for e in _alive:
			if is_instance_valid(e) and e.has_method("alert"):
				e.alert(p)
	if p.has_method("uses_batteries"):
		_battery_timer -= delta
		if _battery_timer <= 0.0:
			var low: bool = p.health < p.max_health * 0.35
			_battery_timer = BATTERY_EVERY * (0.5 if low else 1.0)
			_spawn_battery(p)
	_pickup_timer -= delta
	if _pickup_timer <= 0.0:
		_pickup_timer = PICKUP_EVERY * (1.0 - 0.2 * Rage.perk("luck")) * _rng.randf_range(0.8, 1.2)
		_spawn_pickup(p)
	match state:
		"break":
			_timer -= delta
			if _timer <= 0.0:
				_start_round()
		"fight":
			_clean_alive()
			if _to_spawn > 0:
				_spawn_timer -= delta
				if _spawn_timer <= 0.0 and _alive.size() < max_alive():
					_spawn_timer = spawn_interval()
					_spawn_enemy(_pick_type(), p)
					_to_spawn -= 1
					update_hud()
			elif _alive.is_empty():
				_end_round()
		"boss":
			_clean_alive()
			_minion_timer -= delta
			if _minion_timer <= 0.0:
				_minion_timer = MINION_EVERY
				if _alive.size() < 4:
					_spawn_enemy("basic", p)


## Enemies in a round: 5, 6, 7... up to 30.
func round_size() -> int:
	return mini(4 + wave, 30)


## Seconds between two spawns: 2.9 at round 1, never under 1.2.
func spawn_interval() -> float:
	return maxf(1.2, 3.0 - 0.1 * wave)


## Enemies on the map at once: 3 at round 1, +1 every 2 rounds, at most 10.
func max_alive() -> int:
	return mini(3 + wave / 2, 10)


## Enemy health and speed multipliers for the current round.
func hp_scale() -> float:
	return 1.0 + 0.04 * (wave - 1)


func speed_scale() -> float:
	return 1.0 + minf(0.2, 0.01 * (wave - 1))


## Which enemy comes next: the tougher kinds join later and stay rarer.
func _pick_type() -> String:
	var weights := {"basic": 8}
	if wave >= 3:
		weights.sprayer = 2
	if wave >= 5:
		weights.bomber = 2
	if wave >= 6:
		weights.elite = 1 + wave / 15
	if wave >= 7:
		weights.brute = 1
	if wave >= 9:
		weights.drone = 2
	return _weighted(weights)


func _start_round() -> void:
	wave += 1
	if wave % Rage.BOSS_EVERY == 0:
		_start_boss()
		return
	state = "fight"
	_to_spawn = round_size()
	_round_total = _to_spawn
	_spawn_timer = 0.5
	_toast("Round %d" % wave, GOLD)
	update_hud()


func _end_round() -> void:
	state = "break"
	_timer = BREAK
	Progress.record_stat_max("rage_best_round", wave)
	# "round" pickups end here
	for id in Rage.PICKUPS:
		if Rage.PICKUPS[id].lasts == "round" and int(Rage.run_levels.get(id, 0)) > 0:
			_set_run_level(id, 0)
	# between rounds: an ability to grab before the next one (and a battery for ECO-9)
	var hero := _player()
	if hero:
		_spawn_pickup(hero, true)
		if hero.has_method("uses_batteries"):
			_spawn_battery(hero)
	var msg := "Round %d superato!" % wave
	# every round cleared gives back a heart; Rigenerazione one more
	# (every 3 / 2 / 1 rounds at level 1 / 2 / 3)
	var p := _player()
	var heal := ROUND_HEAL
	var regen := Rage.perk("regen")
	if regen > 0 and wave % (4 - regen) == 0:
		heal += 1
	if p and p.health < p.max_health:
		p.heal(heal)
		msg += "  +%d %s" % [heal, "cuore" if heal == 1 else "cuori"]
	_toast(msg, GREEN)
	update_hud()


func on_kill(enemy: Node) -> void:
	kills += 1
	if state == "boss" and enemy != null and enemy == _boss:
		_boss_defeated.call_deferred()
	update_hud()


func update_hud() -> void:
	var hud := LevelManager.objective_hud
	if hud == null or not is_instance_valid(hud):
		return
	var text := ""
	match state:
		"boss", "choice":
			text = "Round %d  ·  BOSS: %s" % [wave, _boss_name]
		"fight":
			var left := _to_spawn + _alive.size()
			text = "Round %d  ·  Nemici %d/%d" % [wave, _round_total - left, _round_total]
		_:
			text = "Round %d tra poco..." % (wave + 1) if wave > 0 else "Preparati..."
	hud._label.text = "%s  ·  Uccisioni %d" % [text, kills]
	hud._label.add_theme_color_override("font_color", RED if state == "boss" else Color.WHITE)


# --- Spawning ---------------------------------------------------------------

func _spawn_enemy(type: String, p: Node2D) -> Node2D:
	var path: String = BASIC if type == "basic" else (ELITE if type == "elite" else Story.ENEMIES[type].scene)
	var e: Node2D = load(path).instantiate()
	var at := _spawn_point(p)
	e.position = at
	level.add_child(e)
	e.global_position = at
	_scale_enemy(e, hp_scale(), speed_scale())
	FX.at_node("dust", e, Vector2(0, 6), Color(1.0, 0.8, 0.8), 1.5)
	if e.has_method("alert"):
		e.alert(p)
	_alive.append(e)
	return e


func _scale_enemy(e: Node, hp: float, spd: float) -> void:
	e.max_health = ceilf(e.max_health * hp)
	e.health = e.max_health
	e.hpChanged.emit(e.health)  # refresh its health bar
	e.speed *= spd


## An open spot out of sight but reachable from the player.
func _spawn_point(p: Node2D) -> Vector2:
	var rg := LevelManager.route_guide
	var from := p.global_position
	if rg == null or not rg.is_ready():
		return from + Vector2.RIGHT.rotated(_rng.randf() * TAU) * SPAWN_MIN_DIST
	for min_d in [SPAWN_MIN_DIST, SPAWN_MIN_DIST * 0.6, 90.0]:
		for i in 24:
			var q := from + Vector2.RIGHT.rotated(_rng.randf() * TAU) * _rng.randf_range(min_d, SPAWN_MAX_DIST)
			if rg.is_open(q) and rg.reachable(from, q):
				return rg.open_spot(q, 2)
	return rg.open_spot(from + Vector2.RIGHT.rotated(_rng.randf() * TAU) * 120.0, 2)


func _clean_alive() -> void:
	var still := []
	for e in _alive:
		if is_instance_valid(e) and not e.is_dead:
			still.append(e)
	if still.size() != _alive.size():
		_alive = still
		update_hud()


# --- Bosses -----------------------------------------------------------------

func _start_boss() -> void:
	state = "boss"
	_minion_timer = MINION_EVERY
	var tier := wave / Rage.BOSS_EVERY
	var p := _player()
	if tier % 3 == 0:
		var b: Boss = load(BOSS_SCENE).instantiate()
		b.boss_health = 24.0 + 10.0 * tier
		b.start_phase = clampi(tier - 1, 1, 3)
		var at := _spawn_point(p)
		level.add_child(b)
		b.global_position = at  # world position (hand-made levels aren't at the origin)
		b.defeated.connect(_boss_defeated)
		b.health_changed.connect(func(c: float, m: float): _set_bar(c / m))
		b.get_node("AnimatedSprite2D").play("boot")
		_boss = b
		_boss_name = "MECCA-RIFIUTI del Barone"
		_toast("ROUND %d: IL BARONE È TORNATO!" % wave, RED)
		_make_bar()
		await get_tree().create_timer(1.2, false).timeout
		if is_instance_valid(b) and state == "boss":
			b.activate()
	else:
		var type: String = BOSS_TYPES.keys()[_rng.randi_range(0, BOSS_TYPES.size() - 1)]
		var e := _spawn_enemy(type, p)
		_scale_enemy(e, 6.0 + 3.0 * tier, 1.1)
		e.scale *= 1.5
		e.modulate = Color(1.35, 0.75, 0.75)
		e.hpChanged.connect(func(hp: float): _set_bar(hp / e.max_health))
		_boss = e
		_boss_name = BOSS_TYPES[type]
		_toast("ROUND %d: BOSS! %s" % [wave, _boss_name], RED)
		MusicManager.play_track("boss")
		_make_bar()
	update_hud()


func _boss_defeated() -> void:
	if state != "boss":
		return
	bosses += 1
	Progress.add_stat("rage_bosses")
	if _bar:
		_bar.queue_free()
		_bar = null
	# the boss's helpers go with it
	for e in _alive:
		if is_instance_valid(e) and not e.is_dead and e != _boss:
			FX.at_node("purify", e, Vector2(0, -12))
			e.queue_free()
	_alive.clear()
	_toast("Boss sconfitto!", GREEN)
	state = "choice"
	update_hud()
	await get_tree().create_timer(1.5, false).timeout
	_show_perk_choice()


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
	var title := _label(18, Color(1.0, 0.75, 0.6))
	title.text = "BOSS · " + _boss_name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(540, 22)
	root.add_child(title)
	var back := ColorRect.new()
	back.color = Color(0.08, 0.04, 0.06, 0.85)
	back.position = Vector2(8, 26)
	back.size = Vector2(524, 16)
	root.add_child(back)
	_bar_fill = ColorRect.new()
	_bar_fill.color = Color(0.85, 0.2, 0.2)
	_bar_fill.position = Vector2(10, 28)
	_bar_fill.size = Vector2(520, 12)
	root.add_child(_bar_fill)


func _set_bar(ratio: float) -> void:
	if _bar_fill and is_instance_valid(_bar_fill):
		_bar_fill.size.x = 520.0 * clampf(ratio, 0.0, 1.0)


# --- Perk choice ------------------------------------------------------------

func _show_perk_choice() -> void:
	var ids := Rage.perk_choices(3)
	if ids.is_empty():
		Progress.add_coins(300)
		_toast("Hai già tutti i potenziamenti al massimo: +300 monete!", GOLD)
		_after_choice()
		return
	get_tree().paused = true
	var ui := CanvasLayer.new()
	ui.layer = 20
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ui)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	ui.add_child(box)
	var title := _label(32, GOLD)
	title.text = "Boss sconfitto! Scegli un potenziamento"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := _label(18, Color(0.9, 0.9, 0.9))
	sub.text = "È permanente: vale per tutte le tue partite in Rage mode."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	box.add_child(row)
	for id in ids:
		row.add_child(_perk_card(id, func(): _choose_perk(id, ui)))


func _perk_card(id: String, on_pick: Callable) -> Button:
	var perk: Dictionary = Rage.PERKS[id]
	var lvl := int(Progress.rage_perks.get(id, 0))
	var b := Button.new()
	b.custom_minimum_size = Vector2(230, 230)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.12, 0.08, 0.95)
	style.set_border_width_all(4)
	style.border_color = GOLD
	style.set_corner_radius_all(16)
	b.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = Color(0.12, 0.25, 0.15, 0.95)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 12
	col.offset_right = -12
	col.offset_top = 14
	col.offset_bottom = -12
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(col)
	var icon := TextureRect.new()
	icon.texture = load(perk.icon)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(56, 56)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(icon)
	for line in [[perk.title, 22, Color.WHITE], [perk.text, 15, Color(0.85, 0.85, 0.85)],
			["Livello %d → %d" % [lvl, lvl + 1], 17, GOLD]]:
		var l := _label(line[1], line[2])
		l.text = line[0]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(l)
	b.pressed.connect(on_pick)
	return b


func _choose_perk(id: String, ui: Node) -> void:
	SFXManager.play_sfx(preload("res://Audio/SFX/Eco/ui_buy.wav"))
	var is_buff := Progress.BUFFS.has(id)
	var old := Rage.buff_level(id) if is_buff else 0
	Progress.add_rage_perk(id)
	if is_buff:
		_apply_change(id, old, Rage.buff_level(id))
	ui.queue_free()
	get_tree().paused = false
	if Rage.use_perks:
		_toast("%s livello %d!" % [Rage.PERKS[id].title, Progress.rage_perks[id]], GREEN)
	else:
		_toast("%s livello %d: attivo dalla prossima partita con i potenziamenti." % [Rage.PERKS[id].title, Progress.rage_perks[id]], GREEN)
	_after_choice()


func _after_choice() -> void:
	var chapter: Dictionary = Story.chapter_of(Global.selected_level_data)
	MusicManager.play_track(chapter.get("music", "forest"))
	_end_round()


# --- Pickups ----------------------------------------------------------------

## An ability on the ground near the player. `always`: even if MAX_PICKUPS
## are already lying around (the one between rounds).
func _spawn_pickup(p: Node2D, always := false) -> void:
	var count := 0
	for n in level.get_children():
		if n is RagePickup:
			count += 1
	if count >= MAX_PICKUPS and not always:
		return
	var weights := {}
	for id in Rage.PICKUPS:
		weights[id] = Rage.PICKUPS[id].weight
	if p.health <= 1:
		weights.extra_heart = 8
	var at := _near_player(p, 70.0, 200.0)
	var pk := RagePickup.new()
	pk.id = _weighted(weights)
	pk.picked.connect(on_pickup)
	level.add_child(pk)
	pk.global_position = at  # world position (hand-made levels aren't at the origin)


## An open, reachable spot between `near` and `far` px from the player.
func _near_player(p: Node2D, near: float, far: float) -> Vector2:
	var rg := LevelManager.route_guide
	if rg and rg.is_ready():
		for i in 24:
			var q := p.global_position + Vector2.RIGHT.rotated(_rng.randf() * TAU) * _rng.randf_range(near, far)
			if rg.is_open(q) and rg.reachable(p.global_position, q):
				return rg.open_spot(q, 2)
		return rg.open_spot(p.global_position + Vector2(near, 0), 2)
	return p.global_position + Vector2(near, 0)


## ECO-9 runs on batteries: one near the player (at most MAX_BATTERIES around).
func _spawn_battery(p: Node2D) -> void:
	var count := 0
	for n in level.get_children():
		if n is Battery:
			count += 1
	if count >= MAX_BATTERIES:
		return
	var b := Battery.new()
	level.add_child(b)
	b.global_position = _near_player(p, 60.0, 180.0)


func on_pickup(id: String) -> void:
	SFXManager.play_sfx(preload("res://Audio/SFX/Eco/ui_buy.wav"))
	var title: String = Progress.BUFFS[id].title
	var p := _player()
	if Rage.buff_level(id) >= Rage.MAX_LEVEL:
		if p:
			p.heal(1)
		_toast("%s al massimo: +1 cura" % title, GREEN)
		return
	_set_run_level(id, int(Rage.run_levels.get(id, 0)) + 1)
	var lasts := "fino a fine partita" if Rage.PICKUPS[id].lasts == "match" else "fino a fine round"
	_toast("%s Lv%d (%s)" % [title, Rage.buff_level(id), lasts], Color(0.6, 0.95, 1.0))


func _set_run_level(id: String, lvl: int) -> void:
	var old := Rage.buff_level(id)
	Rage.run_levels[id] = lvl
	_apply_change(id, old, Rage.buff_level(id))


## Applies a change of level of a player buff in the middle of a match (the
## ones read only when the level starts).
func _apply_change(id: String, old: int, new: int) -> void:
	if old == new:
		return
	var p := _player()
	match id:
		"extra_heart":
			if p and new > old:
				LevelManager.add_player_hearts(p, int(Progress.buff_value(id, new) - Progress.buff_value(id, old)))
		"swift":
			if p:
				LevelManager.scale_player_speed(p, (1.0 + Progress.buff_value(id, new)) / (1.0 + Progress.buff_value(id, old)))
		"shield":
			if new > old:
				LevelManager.shield_charges += (new - old) * int(Progress.BUFFS.shield.per_level)
		"magnet":
			for c in level.find_children("*", "Collectible", true, false):
				c._magnet_radius = -1.0  # recomputed with the new level
	if LevelManager.objective_hud:
		LevelManager.objective_hud.refresh_buffs()


# --- End ----------------------------------------------------------------------

## Game over: records, coins and the online score. Returns a summary for the
## game over menu.
func finish(item_points: int) -> Dictionary:
	var cleared := wave if state == "break" else wave - 1
	state = "over"
	if _bar:
		_bar.queue_free()
		_bar = null
	var best_before := Progress.stat("rage_best_round")
	Progress.record_stat_max("rage_best_round", cleared)
	Progress.add_stat("rage_matches")
	var score := cleared * 100 + kills * 10 + bosses * 500
	var coins := int((kills * 3 + cleared * 15 + bosses * 100 + item_points) * (1.0 + 0.25 * Rage.perk("loot")))
	Progress.add_coins(coins)
	if SilentWolf:
		var player_name := Global.player_name
		if player_name.strip_edges().is_empty():
			player_name = SilentWolf.Auth.get_anon_user_id()
		SilentWolf.Scores.save_score(player_name, score, Rage.BOARD)
	return {"rounds": cleared, "kills": kills, "bosses": bosses, "score": score, "coins": coins,
			"best": Progress.stat("rage_best_round"), "record": cleared > best_before}


# --- Helpers --------------------------------------------------------------------

func _player() -> CharacterBody2D:
	return LevelManager._player_in(level)


func _toast(text: String, color: Color) -> void:
	if LevelManager.objective_hud and is_instance_valid(LevelManager.objective_hud):
		LevelManager.objective_hud.toast(text, color)


func _weighted(weights: Dictionary) -> String:
	var total := 0
	for k in weights:
		total += int(weights[k])
	var r := _rng.randi_range(1, total)
	for k in weights:
		r -= int(weights[k])
		if r <= 0:
			return k
	return weights.keys()[0]


func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
