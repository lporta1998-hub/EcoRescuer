extends Node2D

func _ready() -> void:
    # Chiama il setup del LevelManager
    LevelManager.setup_level(self)
    # the music comes from the chapter (MusicManager / story.gd)


func _exit_tree() -> void:
    # Quando cambi livello, riattiva il gioco
    get_tree().paused = false
