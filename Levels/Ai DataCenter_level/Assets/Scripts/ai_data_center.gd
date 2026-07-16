extends Node2D

func _ready() -> void:
    # Chiama il setup del LevelManager
    LevelManager.setup_level(self)
    MusicManager.play_music(load("res://Audio/Music_Levels/DataCenter/Alchemist's Oddities.wav"))
#AGGIUNGI MUSIC PER LIVELLO

func _exit_tree() -> void:
    # Quando cambi livello, riattiva il gioco
    get_tree().paused = false
