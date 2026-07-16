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
func _ready() -> void:
    
    add_to_group("level_manager") 
    call_deferred("create_fade_layer")

    
func create_fade_layer() -> void:
    
    var fade_scene = preload("res://Menu/Scenes/fade_transition.tscn") 
    fade_layer = fade_scene.instantiate()
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
    total_items = 0
    collected_items = 0
    # Configura il livello
    count_trash_bags()
    connect_collectible_signals()
    
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
    if collectible is TrashBag:
        trash_bags_collected += 1
        print("Sacco raccolto! ", trash_bags_collected, "/", trash_bags_total)
    else:
        print("Oggetto di tipo '", item_type, "' raccolto (non influisce sul completamento)")
    

    update_menu_data()
    
    if trash_bags_collected >= trash_bags_total and trash_bags_total > 0:
        show_end_level_menu()

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
        "completion_percentage": completion_percentage
    }
    
    
    if end_level_menu and end_level_menu.has_method("set_level_data"):
        end_level_menu.set_level_data(current_data)
    
    if game_over_menu and game_over_menu.has_method("set_level_data"):
        game_over_menu.set_level_data(current_data)
    
    if pause_menu and pause_menu.has_method("set_level_data"):
        pause_menu.set_level_data(current_data)

func show_end_level_menu() -> void:
    var bonus = time_score()
    if bonus > 0:
        Global.add_score(bonus)
        print("Bonus tempo aggiunto: +", bonus)
        
    var final_score = Global.complete_level()
    print("Livello completato! Punteggio finale: ", final_score)
    if Global.selected_level_data and SilentWolf:
        var player_name := Global.player_name
        if player_name.strip_edges().is_empty():
            player_name = SilentWolf.Auth.get_anon_user_id()
        var ld_name := _get_ld_name_for_level(Global.selected_level_data)
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
    var normalized := level_data.level_name.strip_edges().to_lower()
    normalized = normalized.replace(" ", "_")

    var result := ""
    for i in normalized.length():
        var ch := normalized[i]
        var is_lower := ch >= "a" and ch <= "z"
        var is_digit := ch >= "0" and ch <= "9"
        if is_lower or is_digit or ch == "_":
            result += ch

    if result.is_empty():
        return "main"
    return result

func show_game_over_menu() -> void:
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
    

    
