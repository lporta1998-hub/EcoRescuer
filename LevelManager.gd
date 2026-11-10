extends Node

var trash_bags_total: int = 0
var trash_bags_collected: int = 0
var items_collected = []
var items_counter = {}
var start_time: int
var time_bonus: int
var total_items: int = 0
var collected_items: int = 0
var current_level: Node2D
var end_level_menu: CanvasLayer
var game_over_menu: CanvasLayer
var pause_menu: CanvasLayer
var fade_layer: CanvasLayer = null
## Coins paid out for the run that just ended (shown by the end menus).
var coins_earned: int = 0
## Star conditions for the current run: finished, all items, no damage.
var took_damage := false
var star_conditions: Array[bool] = [false, false, false]
var stars_earned := 0
var new_star_record := false
var _player_hp := 0.0
## Hits the "Scudo" buff can still block in this run.
var shield_charges := 0
## "Eco Rush" from a chest: faster and stronger until this time (msec).
const ECO_RUSH_SECONDS := 20.0
const ECO_RUSH_SPEED := 1.3
var _eco_rush_until := 0
## Green coins (EcoToken) picked up in this run, spendable on eco chests.
var run_coins := 0
## Points of the coins spent on chests (not paid out as Shop coins).
var spent_coin_points := 0
## Shop coins won from chests ("Tesoro") in this run.
var chest_bonus_coins := 0
## Objective: collect `bags_needed` trash bags and defeat `kills_needed`
## enemies, then walk into the recycling station (LevelExit) to finish.
var total_enemies := 0
var enemies_killed := 0
var bags_needed := 0
var kills_needed := 0
var level_exit: LevelExit
var objective_hud: ObjectiveHUD
var route_guide: RouteGuide
## Side quests of this level (dossier + one gameplay quest), see Story.
var side_quests: SideQuests
var _finished := false
## Achievements unlocked at the end of this run (shown by the end menus).
var new_achievements: Array = []
## Coins of the Daily challenge reward paid at the end of this run.
var daily_reward := 0
## The Rage mode match (null outside Rage mode) and its game over summary.
var rage_run: RageRun
var rage_summary := {}
func _ready() -> void:
    
    add_to_group("level_manager") 
    call_deferred("create_fade_layer")

    
## Safety net against getting wedged in a map (narrow gaps between collision
## shapes, mostly in the hand-made levels): if the player has been pushing a
## direction for a while without moving and can't move any way at all, put
## them on the nearest open spot.
const UNSTICK_AFTER := 0.6
var _stuck_time := 0.0
var _stuck_from := Vector2.INF

func _physics_process(delta: float) -> void:
    if not is_instance_valid(current_level) or get_tree().paused or route_guide == null:
        return
    var p := _player_in(current_level)
    if p == null or p.is_dead:
        _stuck_time = 0.0
        return
    var pushing := Input.get_vector("left", "right", "up", "down").length() > 0.3
    if not pushing or _stuck_from == Vector2.INF or p.global_position.distance_to(_stuck_from) > 2.0:
        _stuck_time = 0.0
        _stuck_from = p.global_position
        return
    _stuck_time += delta
    if _stuck_time < UNSTICK_AFTER:
        return
    _stuck_time = 0.0
    if _boxed_in(p.global_transform, p):
        # nearest spot around where the body fits and can move again
        var xf := p.global_transform
        for r in [8.0, 12.0, 16.0, 24.0, 32.0, 40.0, 56.0]:
            for k in 16:
                xf.origin = p.global_position + Vector2.RIGHT.rotated(k * TAU / 16.0) * r
                if route_guide.is_open(xf.origin) and not p.test_move(xf, Vector2.ZERO) and not _boxed_in(xf, p):
                    p.global_position = xf.origin
                    p.velocity = Vector2.ZERO
                    print_debug("unstuck the player to ", xf.origin)
                    return

func _player_in(level: Node) -> CharacterBody2D:
    for node in get_tree().get_nodes_in_group("player"):
        if node is CharacterBody2D and level.is_ancestor_of(node):
            return node
    return null

## True if, placed at `xf`, a 4 px step in every one of 8 directions would hit something.
func _boxed_in(xf: Transform2D, p: CharacterBody2D) -> bool:
    for k in 8:
        if not p.test_move(xf, Vector2.RIGHT.rotated(k * PI / 4.0) * 4.0):
            return false
    return true

func create_fade_layer() -> void:
    
    var fade_scene = preload("res://Menu/Scenes/fade_transition.tscn") 
    fade_layer = fade_scene.instantiate()
    # Fades must finish even while the game is paused (level briefing card).
    fade_layer.process_mode = Node.PROCESS_MODE_ALWAYS
    get_tree().root.add_child(fade_layer)
    
func setup_level(level_node: Node2D) -> void:
    # Questa funzione viene chiamata dal livello quando è pronto
    if fade_layer:
        print("provo fade in")
        fade_layer.fade_in()
    current_level = level_node
    
    # Ottieni i riferimenti ai menu dal livello corrente
    end_level_menu = current_level.get_node_or_null("CompleteMenu")
    game_over_menu = current_level.get_node_or_null("GameOverMenu")
    pause_menu = current_level.get_node_or_null("PauseMenu")
    
    # Resetta i dati per il nuovo livello
    trash_bags_total = 0
    trash_bags_collected = 0
    items_collected.clear()
    items_counter.clear()
    start_time = Time.get_ticks_msec()
    coins_earned = 0
    new_achievements = []
    daily_reward = 0
    rage_run = null
    rage_summary = {}
    if Rage.active:
        Rage.reset_run()  # before the buffs are applied below
    took_damage = false
    stars_earned = 0
    new_star_record = false
    star_conditions = [false, false, false]
    _eco_rush_until = 0
    run_coins = 0
    spent_coin_points = 0
    chest_bonus_coins = 0
    # background music of this chapter (Tools/audio/music.py)
    var chapter: Dictionary = Story.chapter_of(Global.selected_level_data) if Global.selected_level_data else {}
    MusicManager.play_track(chapter.get("music", "forest"))
    MapFixes.apply(level_node)  # before the route grid is built, so it sees them
    if Rage.active or Daily.active:
        _remove_secret(level_node)  # secrets are for the campaign
    else:
        SecretSpots.apply(level_node)
    _disable_tile_navigation(level_node)
    _track_player_damage(level_node)
    if Rage.active:
        _clear_for_rage(level_node)
    else:
        _mix_enemies(level_node)
    _apply_buffs(level_node)
    total_items = 0
    collected_items = 0
    # Configura il livello
    count_trash_bags()
    connect_collectible_signals()
    if Rage.active:
        _setup_rage(level_node)
    else:
        _setup_objective(level_node)
    
    # Nascondi i menu
    if end_level_menu:
        end_level_menu.hide()
    if game_over_menu:
        game_over_menu.hide()
    if pause_menu:
        pause_menu.hide()

func count_trash_bags() -> void:
    
    if not current_level:
        return
        
    var all_trashbags = current_level.find_children("*", "TrashBag")
    trash_bags_total = all_trashbags.size()
    print("Trovati ", trash_bags_total, " sacchi della spazzatura nel livello")

func connect_collectible_signals() -> void:
    if not current_level:
        return
    
    # Cerchiamo TUTTI i collectible
    var all_collectibles = current_level.find_children("*", "Collectible")
    
    # FILTRIAMO: escludiamo i cuori (HeartCollectible)
    var filtered_collectibles = []
    for collectible in all_collectibles:
        # Escludi HeartCollectible
        if collectible is HeartCollectible or collectible is SpeedBoost:
            print("Escluso cuore dal conteggio")
            continue
        
        filtered_collectibles.append(collectible)
    print("Trovati ", all_collectibles.size(), " collectible totali nel livello")
    print("Di cui ", filtered_collectibles.size(), " conteggiabili per il completamento")
    
    total_items = filtered_collectibles.size()
    
    # Connetti i segnali solo per quelli filtrati
    for collectible in filtered_collectibles:
        if collectible is Collectible:
            if not collectible.collected.is_connected(_on_collectible_collected):
                collectible.collected.connect(_on_collectible_collected)

func _on_collectible_collected(collectible: Collectible) -> void:  
    
    var item_data = collectible.get_collectible_data()
    items_collected.append(item_data)
    collected_items += 1
    var item_type = item_data.get("type", "unknown")
    if items_counter.has(item_type):
        items_counter[item_type]["count"] += 1
    else:
        items_counter[item_type] = {
            "count": 1,
            "name": item_data.get("name", "Oggetto"),
            "icon": item_data.get("icon", null),
            "points": item_data.get("points", 0)
        }
    if collectible.has_method("is_eco_coin"):
        run_coins += 1
        Progress.add_stat("coins")
        _quest_event("coin")
    if collectible is OilBarrel:
        Progress.add_stat("barrels")
        _quest_event("barrel")
    if collectible is TrashBag:
        trash_bags_collected += 1
        Progress.add_stat("bags")
        print("Sacco raccolto! ", trash_bags_collected, "/", trash_bags_total)
    else:
        print("Oggetto di tipo '", item_type, "' raccolto (non influisce sul completamento)")
    

    update_menu_data()
    
    # The level no longer ends on the last bag: the player can keep exploring
    # and finishes by walking into the recycling station.
    _update_objective()

func update_menu_data() -> void:
    var time_elapsed = (Time.get_ticks_msec() - start_time) / 1000 if start_time else 0
    var completion_percentage = 0.0
    if total_items > 0:
        completion_percentage = (float(collected_items) / total_items) * 100
    var current_data = {
        "total_bags": trash_bags_total,
        "collected_bags": trash_bags_collected,
        "total_items": total_items,                 
        "collected_items": collected_items, 
        "items": items_collected,
        "items_counter": items_counter,
        "score": Global.current_level_score,
        "completion_seconds": time_elapsed,
        "completion_time": Time.get_time_string_from_system(),
        "completion_percentage": completion_percentage,
        "coins_earned": coins_earned,
        "coins_total": Progress.coins,
        "coin_bonus": Progress.coin_multiplier() - 1.0,
        "chest_coins": chest_bonus_coins,
        "quests": side_quests.results if side_quests else [],
        "quest_coins": side_quests.bonus_coins if side_quests else 0,
        "stars": stars_earned,
        "star_conditions": star_conditions,
        "new_star_record": new_star_record,
        "stars_total": Progress.total_stars(),
        "achievements": new_achievements,
        "daily": Daily.active,
        "daily_reward": daily_reward,
        "rage": rage_summary
    }
    
    
    if end_level_menu and end_level_menu.has_method("set_level_data"):
        end_level_menu.set_level_data(current_data)
    
    if game_over_menu and game_over_menu.has_method("set_level_data"):
        game_over_menu.set_level_data(current_data)
    
    if pause_menu and pause_menu.has_method("set_level_data"):
        pause_menu.set_level_data(current_data)

func show_end_level_menu() -> void:
    _finished = true
    var bonus = time_score()
    if bonus > 0:
        Global.add_score(bonus)
        print("Bonus tempo aggiunto: +", bonus)
        
    # the Daily challenge keeps the level's own record and stars untouched
    var final_score = Global.current_level_score if Daily.active else Global.complete_level()
    print("Livello completato! Punteggio finale: ", final_score)
    if side_quests:
        side_quests.on_level_finished(elapsed_seconds())
    _pay_out_coins(true)
    _award_stars()
    if Daily.active:
        daily_reward = Daily.on_completed()
    _record_run_stats(true)
    if Global.selected_level_data and SilentWolf:
        var player_name := Global.player_name
        if player_name.strip_edges().is_empty():
            player_name = SilentWolf.Auth.get_anon_user_id()
        var ld_name := Daily.board_id() if Daily.active else _get_ld_name_for_level(Global.selected_level_data)
        SilentWolf.Scores.save_score(player_name, final_score, ld_name)
    
    update_menu_data()
    Global.reset_current_score()
    MusicManager.play_level_complete()
    get_tree().paused = true
    
    if pause_menu:
        pause_menu.set_process_input(false)
        pause_menu.hide()
    
    if end_level_menu:
        end_level_menu.show()


func _get_ld_name_for_level(level_data: LevelData) -> String:
    return Story.leaderboard_id(level_data)

## Watches the player's health so the "no damage" star can be judged.
## Looks inside the new level only: the previous level's player may still be
## in the tree for a frame while it's being freed.
func _track_player_damage(level_node: Node) -> void:
    for node in level_node.find_children("*", "CharacterBody2D", true, false):
        if node.is_in_group("player") and node.has_signal("hpChanged"):
            _player_hp = float(node.health)
            node.hpChanged.connect(_on_player_hp_changed)
            return

func _on_player_hp_changed(new_hp) -> void:
    if float(new_hp) < _player_hp:
        took_damage = true
        if side_quests:
            side_quests.on_damage()
            _refresh_quest_hud()
    _player_hp = float(new_hp)

# --- Objective & exit ------------------------------------------------------

## Swaps some of the level's basic Inquinatori (never Elites) for the new
## enemy types listed in the chapter's `enemies` (see Story.ENEMIES). Seeded
## by the level, so the same enemies change every time you play it.
func _mix_enemies(level_node: Node) -> void:
    var mix: Dictionary = Story.chapter_of(Global.selected_level_data).get("enemies", {})
    if mix.is_empty():
        return
    var basics: Array = []
    for node in level_node.find_children("*", "CharacterBody2D", true, false):
        if node is Enemy and not node is Elite and not node is NewEnemy:
            basics.append(node)
    var rng := RandomNumberGenerator.new()
    rng.seed = hash(level_node.scene_file_path)
    for i in range(basics.size() - 1, 0, -1):  # shuffle
        var j := rng.randi_range(0, i)
        var t = basics[i]
        basics[i] = basics[j]
        basics[j] = t
    var k := 0
    for type in mix:
        var scene: PackedScene = load(Story.ENEMIES[type].scene)
        for n in int(mix[type]):
            if k >= basics.size():
                return
            var old: Node2D = basics[k]
            k += 1
            var e: Node2D = scene.instantiate()
            e.position = old.position
            var parent := old.get_parent()
            parent.add_child(e)
            parent.move_child(e, old.get_index())
            e.owner = old.owner if old.owner else level_node
            parent.remove_child(old)
            old.queue_free()

func _setup_objective(level_node: Node) -> void:
    _finished = false
    enemies_killed = 0
    total_enemies = 0
    for node in level_node.find_children("*", "CharacterBody2D", true, false):
        if node is Enemy:
            total_enemies += 1
    var ld: LevelData = Global.selected_level_data
    var req_bags: int = ld.required_bags if ld else -1
    var req_kills: int = ld.required_kills if ld else 0
    bags_needed = trash_bags_total if req_bags < 0 else mini(req_bags, trash_bags_total)
    kills_needed = mini(req_kills, total_enemies)

    objective_hud = ObjectiveHUD.new()
    level_node.add_child(objective_hud)
    route_guide = RouteGuide.new(level_node)
    objective_hud.route_guide = route_guide
    _update_objective()
    level_exit = null
    for node in level_node.find_children("*", "Area2D", true, false):
        if node is LevelExit:
            level_exit = node
    if level_exit == null:
        level_exit = _place_exit(level_node)
    _check_chest_costs(level_node)
    objective_hud.exit_node = level_exit
    _update_objective()
    # no side quests in the Daily challenge: it's only about the score
    side_quests = SideQuests.new(Global.selected_level_data, level_node) \
            if Global.selected_level_data and not Daily.active else null
    _place_batteries(level_node)
    if Daily.active:
        _show_daily_briefing.call_deferred()
    elif side_quests and side_quests.is_active():
        _place_dossier(level_node)
        _refresh_quest_hud()
        _show_briefing.call_deferred()

# --- Rage mode -----------------------------------------------------------------

## Rage mode plays on the map without its story: no trash bags, station,
## dossier or placed enemies (RageRun spawns its own).
func _clear_for_rage(level_node: Node) -> void:
    var drop := []
    for node in level_node.find_children("*", "", true, false):
        if node is TrashBag or node is LevelExit or node is Dossier or node is Enemy or node is Boss:
            drop.append(node)
    for node in drop:
        if is_instance_valid(node) and node.get_parent():
            node.get_parent().remove_child(node)
            node.queue_free()

## Rage mode and the Daily challenge: no portal to the secret vault (the
## crates of the built levels stay, as scenery).
func _remove_secret(level_node: Node) -> void:
    for node in level_node.find_children("*", "SecretPortal", true, false):
        node.get_parent().remove_child(node)
        node.queue_free()

func _setup_rage(level_node: Node) -> void:
    total_enemies = 0
    bags_needed = 0
    kills_needed = 0
    side_quests = null
    level_exit = null
    objective_hud = ObjectiveHUD.new()
    level_node.add_child(objective_hud)
    route_guide = RouteGuide.new(level_node)
    objective_hud.route_guide = route_guide
    objective_hud.exit_node = null
    rage_run = RageRun.new(level_node)
    level_node.add_child(rage_run)

## Warns (in the Godot output) when the eco chests of a level cost more green
## coins than the level has, so not every chest could be opened.
func _check_chest_costs(level_node: Node) -> void:
    var coins := 0
    for c in level_node.find_children("*", "Collectible", true, false):
        if c.has_method("is_eco_coin"):
            coins += 1
    var cost := 0
    for chest in level_node.find_children("*", "EcoChest", true, false):
        cost += chest.cost
    if cost > coins:
        push_warning("%s: i forzieri costano %d monete ma il livello ne ha solo %d" % [level_node.name, cost, coins])

# --- Story: briefing, dossier, side quests -----------------------------------

func _show_briefing() -> void:
    if not is_instance_valid(current_level):
        return
    var ld: LevelData = Global.selected_level_data
    var ch: Dictionary = side_quests.chapter
    var lines := ["Obiettivo: raccogli %d sacchi di rifiuti%s, poi portali al punto di raccolta." % [
            bags_needed, (" e sconfiggi %d Inquinatori" % kills_needed) if kills_needed > 0 else ""],
            "Missioni secondarie: trova il dossier segreto  ·  %s." % side_quests.text]
    for type in Story.new_enemies_in(ld):
        lines.append("Nuovo nemico: %s — %s" % [Story.ENEMIES[type].name, Story.ENEMIES[type].tip])
    var card := StoryCard.open(current_level, {
        "kicker": ("Epilogo  ·  %s" % ld.level_name) if Story.is_epilogue(ld) else \
                "Capitolo %d di %d  ·  %s" % [Story.chapter_index(ld) + 1, Story.main_chapters().size(), ld.level_name],
        "title": ch.title, "text": ch.text, "lines": lines, "button": "Via!"})
    card.closed.connect(func(): start_time = Time.get_ticks_msec())  # the clock starts now

func _show_daily_briefing() -> void:
    if not is_instance_valid(current_level):
        return
    var ld: LevelData = Global.selected_level_data
    var lines := ["Obiettivo: raccogli %d sacchi di rifiuti%s, poi portali al punto di raccolta." % [
            bags_needed, (" e sconfiggi %d Inquinatori" % kills_needed) if kills_needed > 0 else ""],
            "Sfide attive: " + Daily.sfide_text(),
            "I potenziamenti del negozio sono spenti: vince il punteggio più alto."]
    if not Daily.done_today():
        lines.append("Completala per +%d monete (una volta al giorno)." % Daily.REWARD)
    var card := StoryCard.open(current_level, {
        "kicker": "Sfida del giorno  ·  " + Daily.date(),
        "title": ld.level_name, "text": "Stesso livello e stesse Sfide per tutti i giocatori, solo per oggi.",
        "lines": lines, "button": "Via!", "color": Color(0.55, 0.9, 1.0)})
    card.closed.connect(func(): start_time = Time.get_ticks_msec())

## A Dossier placed in the level scene, or one on the reachable item farthest
## from the start (away from the recycling station).
func _place_dossier(level_node: Node) -> void:
    for node in level_node.find_children("*", "Area2D", true, false):
        if node is Dossier:
            return
    var spawn := level_node.find_child("PlayerSpawn", true, false) as Node2D
    var start := spawn.global_position if spawn else Vector2.ZERO
    var best := -1.0
    var where := Vector2.INF
    for item in level_node.find_children("*", "Collectible", true, false):
        if item is TrashBag:
            continue
        var p: Vector2 = item.global_position
        if level_exit and p.distance_to(level_exit.global_position) < 250.0:
            continue
        var d: float = route_guide.route_cost(start, p) if route_guide.is_ready() else start.distance_to(p)
        if d != INF and d > best:
            best = d
            where = p
    if where == Vector2.INF:
        return
    var dossier := Dossier.new()
    dossier.name = "Dossier"
    level_node.add_child(dossier)
    dossier.global_position = route_guide.open_spot(where + Vector2(34, 0), 1) if route_guide.is_ready() else where + Vector2(34, 0)

## Batteries exist only for heroes that run on them (ECO-9): spread over
## reachable spots near the level's items, far from each other.
func _place_batteries(level_node: Node) -> void:
    # the hero of THIS level (the previous level's one may not be freed yet)
    var player: Node = null
    for n in level_node.get_children():
        if n.is_in_group("player"):
            player = n
    if player == null or not player.has_method("uses_batteries"):
        return
    var spawn := level_node.find_child("PlayerSpawn", true, false) as Node2D
    var start := spawn.global_position if spawn else Vector2.ZERO
    var candidates := []
    for item in level_node.find_children("*", "Collectible", true, false):
        if not (item is TrashBag) and (not route_guide.is_ready() or route_guide.teleport_chain(start, item.global_position) != null):
            candidates.append(item.global_position)
    var count := clampi(total_enemies / 3, 5, 9)
    var chosen := [start]
    for i in count:
        var best := Vector2.INF
        var best_d := -1.0
        for c in candidates:
            var d := INF
            for q in chosen:
                d = minf(d, c.distance_to(q))
            if d > best_d:
                best_d = d
                best = c
        if best == Vector2.INF:
            break
        chosen.append(best)
        candidates.erase(best)
        var b := Battery.new()
        b.name = "Battery%d" % i
        level_node.add_child(b)
        b.global_position = route_guide.open_spot(best + Vector2(0, 26), 1) if route_guide.is_ready() else best + Vector2(0, 26)

func on_dossier_found() -> void:
    if side_quests == null:
        return
    var msg := side_quests.on_dossier()
    _refresh_quest_hud()
    StoryCard.open(current_level, {
        "kicker": "Dossier segreto degli Inquinatori", "title": "Trovato!",
        "text": side_quests.chapter.get("dossier", ""), "lines": [msg] if msg != "" else [],
        "button": "Continua", "color": Color(0.95, 0.75, 0.3), "icon": preload("res://Misc/Story/Art/dossier.png")})

func _quest_event(event: String) -> void:
    if side_quests == null:
        return
    var msg := side_quests.on_event(event)
    _refresh_quest_hud()
    if msg != "" and objective_hud and is_instance_valid(objective_hud):
        objective_hud.toast(msg, Color(1.0, 0.85, 0.35))

func elapsed_seconds() -> float:
    return (Time.get_ticks_msec() - start_time) / 1000.0

func _refresh_quest_hud() -> void:
    if objective_hud and is_instance_valid(objective_hud) and side_quests:
        objective_hud.set_quests(side_quests.summary(elapsed_seconds()))

## Re-aims the arrow right away after the player used a teleport.
func on_player_teleported() -> void:
    if objective_hud and is_instance_valid(objective_hud):
        objective_hud.refresh_route()

## Puts a recycling station on the trash bag farthest from the player's
## start along the route (teleports count as far).
func _place_exit(level_node: Node) -> LevelExit:
    var spawn := level_node.find_child("PlayerSpawn", true, false) as Node2D
    var start := spawn.global_position if spawn else Vector2.ZERO
    var where := start
    var best := -1.0
    for bag in level_node.find_children("*", "TrashBag", true, false):
        var d: float = route_guide.route_cost(start, bag.global_position) if route_guide.is_ready() \
                else start.distance_to(bag.global_position)
        if d == INF:
            continue
        if d > best:
            best = d
            where = bag.global_position
    var exit := LevelExit.new()
    exit.name = "LevelExit"
    level_node.add_child(exit)
    # next to the bag, not on top of it, on open floor (never half in a wall)
    exit.global_position = route_guide.open_spot(where + Vector2(0, 26)) if route_guide.is_ready() \
            else where + Vector2(0, 26)
    # draw it above the ground but under the player
    for node in level_node.get_children():
        if node.is_in_group("player"):
            level_node.move_child(exit, node.get_index())
            break
    return exit

func objective_met() -> bool:
    return trash_bags_collected >= bags_needed and enemies_killed >= kills_needed

func _update_objective() -> void:
    if rage_run:
        rage_run.update_hud()
        return
    var met := objective_met()
    if level_exit and is_instance_valid(level_exit):
        level_exit.set_open(met)
    if objective_hud and is_instance_valid(objective_hud):
        objective_hud.update_objective(trash_bags_collected, bags_needed, enemies_killed, kills_needed, met)

func on_enemy_killed(enemy: Node = null) -> void:
    enemies_killed += 1
    Progress.add_stat("kills")
    if rage_run:
        rage_run.on_kill(enemy)
    _update_objective()
    if enemy is Elite:
        Progress.add_stat("elites")
        _quest_event("elite")

func on_chest_opened() -> void:
    Progress.add_stat("chests")
    _quest_event("chest")

## Called by the recycling station when the player walks into it.
func try_finish_level() -> void:
    if _finished:
        return
    # Final level: the station inside the arena starts the boss fight; the
    # level ends when the boss is beaten (see Boss/fortress_level.gd).
    if current_level and current_level.has_method("start_boss_fight") and not current_level.boss_defeated \
            and objective_met():
        current_level.start_boss_fight()
        return
    if objective_met():
        _finished = true
        show_end_level_menu()
        return
    var missing := []
    if trash_bags_collected < bags_needed:
        missing.append("%d rifiuti" % (bags_needed - trash_bags_collected))
    if enemies_killed < kills_needed:
        missing.append("%d nemici da sconfiggere" % (kills_needed - enemies_killed))
    if objective_hud:
        objective_hud.toast("Ti mancano ancora: " + " e ".join(missing), Color(1.0, 0.6, 0.45))

## Nothing uses the navigation mesh any more (enemies and the station arrow
## path over RouteGuide's tile grid). The tile layers registered one
## navigation region per tile (12-19 thousand per level), which the navigation
## server kept in sync for nothing: switch it off.
func _disable_tile_navigation(level_node: Node) -> void:
    for layer in level_node.find_children("*", "TileMapLayer", true, false):
        layer.navigation_enabled = false

## Applies the buffs and Sfide switched on in the Shop (at their bought
## level) to this level's player and enemies.
func _apply_buffs(level_node: Node) -> void:
    shield_charges = Progress.level_of("shield") * int(Progress.BUFFS.shield.per_level)
    for node in level_node.find_children("*", "CharacterBody2D", true, false):
        if node.is_in_group("player"):
            _buff_player(node)
        elif node is Enemy:
            _buff_enemy(node)
    _remove_hearts(level_node)

func _buff_player(player: Character) -> void:
    var hearts_lvl := Progress.level_of("extra_heart")
    if hearts_lvl > 0:
        add_player_hearts(player, int(Progress.buff_value("extra_heart", hearts_lvl)))
    var swift_lvl := Progress.level_of("swift")
    if swift_lvl > 0:
        scale_player_speed(player, 1.0 + Progress.buff_value("swift", swift_lvl))

## Raises the player's max hearts by `extra` (and fills them).
func add_player_hearts(player: Node, extra: int) -> void:
    if extra <= 0 or not is_instance_valid(player):
        return
    player.max_health += extra
    player.health += extra
    _player_hp = float(player.health)
    var hearts = player.get("heartsContainer")
    if hearts:
        hearts.setMaxHP(extra)  # appends the extra hearts
        hearts.updateHP(player.health)

## Multiplies every speed variable the characters use (they reset `speed` from
## base_speed / original_speed in different places).
func scale_player_speed(player: Node, factor: float) -> void:
    if not is_instance_valid(player):
        return
    player.speed *= factor
    player.base_speed *= factor
    if "original_speed" in player:
        player.original_speed *= factor

func _buff_enemy(enemy: Enemy) -> void:
    var armored_lvl := Progress.level_of("armored")
    if armored_lvl > 0:
        enemy.max_health = ceilf(enemy.max_health * (1.0 + Progress.buff_value("armored", armored_lvl)))
        enemy.health = enemy.max_health
        enemy.hpChanged.emit(enemy.health)  # refresh its health bar
    var rapid_lvl := Progress.level_of("rapid")
    if rapid_lvl > 0:
        enemy.speed *= 1.0 + Progress.buff_value("rapid", rapid_lvl)

## Damage of an enemy hit on the player: "Colpi pesanti" makes some hits
## (all of them at max level) take 2 hearts.
func enemy_hit_damage(base: int) -> int:
    var lvl := Progress.level_of("heavy")
    if lvl > 0 and randf() < Progress.buff_value("heavy", lvl):
        return maxi(base, 2)
    return base

## Bonus damage of a player hit: "Colpo potente" (+1, then a growing chance of
## a x2 critical) and the Eco Rush from chests (+1). Returns [damage, is_crit].
func player_hit_damage(base: int) -> Array:
    var dmg := base
    var lvl := Progress.level_of("power")
    if lvl > 0:
        dmg += 1
    if eco_rush_active():
        dmg += 1
    var crit := lvl > 1 and randf() < Progress.buff_value("power", lvl - 1)
    if crit:
        dmg *= 2
    return [dmg, crit]

## "Senza cure": a share of the level's heart pickups disappears.
func _remove_hearts(level_node: Node) -> void:
    var lvl := Progress.level_of("no_heal")
    if lvl <= 0:
        return
    var hearts := level_node.find_children("*", "HeartCollectible", true, false)
    hearts.shuffle()
    var to_remove := ceili(hearts.size() * minf(1.0, Progress.buff_value("no_heal", lvl)))
    for i in to_remove:
        hearts[i].queue_free()

func eco_rush_active() -> bool:
    return Time.get_ticks_msec() < _eco_rush_until

func eco_rush_seconds_left() -> float:
    return maxf(0.0, (_eco_rush_until - Time.get_ticks_msec()) / 1000.0)

## Chest reward: ECO_RUSH_SECONDS of extra speed and +1 damage.
func start_eco_rush(player: Node) -> void:
    var already := eco_rush_active()
    _eco_rush_until = Time.get_ticks_msec() + int(ECO_RUSH_SECONDS * 1000.0)
    if already:
        return  # just extends it
    scale_player_speed(player, ECO_RUSH_SPEED)
    while eco_rush_active():
        await get_tree().create_timer(0.25, false).timeout
        if not is_instance_valid(player):
            return
    scale_player_speed(player, 1.0 / ECO_RUSH_SPEED)

## Called by the player when hit: true if the shield absorbed the blow.
func consume_shield() -> bool:
    if shield_charges <= 0:
        return false
    shield_charges -= 1
    return true

## Stars: 1 for finishing, 1 for collecting every item, 1 for taking no damage.
func _award_stars() -> void:
    star_conditions = [true, total_items > 0 and collected_items >= total_items, not took_damage]
    stars_earned = star_conditions.count(true)
    if Global.selected_level_data and not Daily.active:
        new_star_record = Progress.record_stars(Global.selected_level_data, stars_earned)

## Turns the points of the collected items into Shop coins.
## Spends `amount` run coins on a chest. False if there aren't enough.
func spend_run_coins(amount: int) -> bool:
    if run_coins < amount:
        return false
    run_coins -= amount
    spent_coin_points += amount * ECO_COIN_POINTS
    return true

const ECO_COIN_POINTS := 10  # points of one green coin (eco_token.gd)

func _pay_out_coins(completed: bool) -> void:
    var points := maxi(0, collected_points() - spent_coin_points) + chest_bonus_coins
    coins_earned = Progress.coins_for_run(points, completed)
    if side_quests:
        coins_earned += side_quests.bonus_coins  # side-quest rewards, paid in full
    Progress.add_coins(coins_earned)

## End-of-run counters for achievements, then saves and checks them.
func _record_run_stats(completed: bool) -> void:
    if completed:
        Progress.add_stat("runs_completed")
        Progress.record_win(Global.selected_character)
        if not took_damage:
            Progress.add_stat("flawless")
        if Progress.active_buffs().filter(func(b): return Progress.BUFFS[b[0]].kind == "enemy").size() >= 3:
            Progress.add_stat("hard_wins")
    else:
        Progress.add_stat("deaths")
    new_achievements = Progress.finish_run()

func collected_points() -> int:
    var total := 0
    for item in items_collected:
        total += int(item.get("points", 0))
    return total

func show_game_over_menu() -> void:
    if rage_run:
        rage_summary = rage_run.finish(maxi(0, collected_points() - spent_coin_points))
        coins_earned = rage_summary.coins
    else:
        _pay_out_coins(false)
    _record_run_stats(false)
    Global.reset_current_score()
    update_menu_data()
    MusicManager.play_game_over()
    get_tree().paused = true
    
    if pause_menu:
        pause_menu.set_process_input(false)
        pause_menu.hide()
    
    if game_over_menu:
        game_over_menu.show()

func show_pause_menu() -> void:
    update_menu_data()
    get_tree().paused = true
    
    if pause_menu:
        pause_menu.show()
        
        
#funzione per calcolorare il punteggio in base al tempo
func time_score()->int:
    var time_elapsed = (Time.get_ticks_msec() - start_time) / 1000.0
    if not Global.selected_level_data:
        print("ERRORE: Nessun livello selezionato per calcolare bonus tempo")
        return 0
        
    var max_time_bonus = Global.selected_level_data.max_time_bonus
    var penalty_time = Global.selected_level_data.penalty_time
    
    if time_elapsed <= 0:
        
        return 0
    var bonus = max_time_bonus - (time_elapsed * penalty_time)
    bonus = max(0, int(bonus))
    
    print("Tempo impiegato: %.1f secondi, Bonus: %d" % [time_elapsed, bonus])
    return bonus
    

    
