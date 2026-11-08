extends Node2D

func _ready() -> void:
    # Chiama il setup del LevelManager
    LevelManager.setup_level(self)
    # load() instead of preload(): a missing music file must not stop the
    # level script from running (that left the level without its HUD,
    # recycling station and pause map).
    var music := "res://Audio/Music_Levels/BeachLevel/Beach.wav"
    MusicManager.play_music(load(music) if ResourceLoader.exists(music) else null)


func _exit_tree() -> void:
    # Quando cambi livello, riattiva il gioco
    get_tree().paused = false
