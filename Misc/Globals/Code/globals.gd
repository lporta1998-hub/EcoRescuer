class_name Globals extends Node

var selected_character : Pg = null
var character_scene : PackedScene = null
var selected_level : PackedScene = null
var selected_level_data: LevelData = null
var player_name: String = ""
var pause_menu_scene : PackedScene = preload("res://Menu/PauseMenu/Scenes/pause_menu.tscn")
var current_pause_menu : CanvasLayer = null
var current_level_score: int = 0

signal score_updated(current_score: int)
signal high_score_updated(level_data: LevelData)

func _ready() -> void:
    var sw = get_tree().root.get_node_or_null("/root/SilentWolf")
    if sw:
        SilentWolf.configure({
            "api_key": "sgtRud9XUsaDGaXvgyRiq6hteVHdTSX23F5mdYgk",
            "game_id": "eco",
            "game_version": "1.0",
            "log_level": 1
        })
        SilentWolf.configure_scores_open_scene_on_close("res://main_menu.tscn")

func load_game():
    if character_scene and selected_level:
      
        var level_instance = selected_level.instantiate()
        
        var character_instance = character_scene.instantiate()
        var spawn_point = level_instance.find_child("PlayerSpawn", true, false)
        level_instance.add_child(character_instance)
        if spawn_point:
            
            character_instance.global_position = spawn_point.global_position
        else:
            level_instance.add_child(character_instance)
            character_instance.global_position = Vector2(400, 300)
        
        print("Personaggio spawnato")
        
     
        if get_tree().current_scene:
            get_tree().current_scene.queue_free()
       
        get_tree().root.add_child(level_instance)
        
        get_tree().current_scene = level_instance
        
        #add_pause_menu_to_current_level()
        
       
        
        get_tree().root.set_disable_input(false)
        
        
        print("Livello caricato e impostato come corrente")

func add_pause_menu_to_current_level():
   
    
    # Crea nuovo pause menu
    current_pause_menu = pause_menu_scene.instantiate()
    
    # Aggiungi al livello corrente
    if get_tree().current_scene:
        get_tree().current_scene.add_child(current_pause_menu)
        print("Pause menu aggiunto al livello: ", get_tree().current_scene.name)
    else:
        # Fallback: aggiungi alla radice
        get_tree().root.add_child(current_pause_menu)
        print("Pause menu aggiunto alla radice")

       
 

static func exp_decay(a,b,decay,delta):
  return b+(a-b)*exp(-decay*delta)


func add_score(amount: int) -> void:
    current_level_score += amount
    print("Punteggio corrente: +%d | Totale livello: %d" % [amount, current_level_score])
    score_updated.emit(current_level_score)

func complete_level() -> int:
    if not selected_level_data:
        print("ERRORE: Nessun livello selezionato!")
        return 0
    
    var old_high = selected_level_data.high_score
    var is_new_record = selected_level_data.update_high_score(current_level_score)
    
    if is_new_record:
        print("NUOVO RECORD! Livello %s: %d punti (vecchio: %d)" % [selected_level_data.level_name, current_level_score, old_high])
        # Salva la risorsa modificata
        save_level_data(selected_level_data)
        high_score_updated.emit(selected_level_data)
    else:
        print("Livello %s completato con %d punti (record: %d)" % [selected_level_data.level_name, current_level_score, old_high])
    
    
    return current_level_score

func reset_current_score() -> void:
    current_level_score = 0
    score_updated.emit(0)

func get_current_high_score() -> int:
    if selected_level_data:
        return selected_level_data.high_score
    return 0

# Salvataggio su file
func save_level_data(level_data: LevelData) -> void:
    # Salva solo questo livello modificato
    var error = ResourceSaver.save(level_data, level_data.resource_path)
    if error == OK:
        print("Dati livello salvati: ", level_data.resource_path)
    else:
        print("ERRORE nel salvare il livello: ", error)
