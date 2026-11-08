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

       
 

## Freezes the game for a split second when a blow lands, so hits feel solid.
## Lives here (an autoload) so the time scale is always restored, even if the
## enemy that triggered it is freed in the meantime.
func hitstop(duration: float = 0.05) -> void:
    Engine.time_scale = 0.05
    await get_tree().create_timer(duration, true, false, true).timeout
    Engine.time_scale = 1.0

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
# High scores live in user:// (the app's writable save folder). Writing them
# back into the .tres files under res:// only works in the editor: in an
# exported game (iOS, Android, desktop builds) res:// is read-only.
const HIGH_SCORES_PATH := "user://high_scores.cfg"

func _level_key(level_data: LevelData) -> String:
    return level_data.resource_path.get_file().get_basename()

## Replaces the high score stored in the level resource with the player's
## saved record (0 if they never finished the level).
func apply_saved_high_score(level_data: LevelData) -> void:
    if level_data == null:
        return
    var cfg := ConfigFile.new()
    cfg.load(HIGH_SCORES_PATH)
    level_data.high_score = cfg.get_value("high_scores", _level_key(level_data), 0)

func save_level_data(level_data: LevelData) -> void:
    var cfg := ConfigFile.new()
    cfg.load(HIGH_SCORES_PATH)  # missing file on first save is fine
    cfg.set_value("high_scores", _level_key(level_data), level_data.high_score)
    var error := cfg.save(HIGH_SCORES_PATH)
    if error == OK:
        print("Record salvato: ", _level_key(level_data), " = ", level_data.high_score)
    else:
        print("ERRORE nel salvare il record: ", error)
