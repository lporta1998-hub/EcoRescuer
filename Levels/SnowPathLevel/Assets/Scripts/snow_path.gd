# Livello1.gd (attaccato al nodo principale del livello)
extends Node2D

func _ready() -> void:
    # Chiama il setup del LevelManager
    LevelManager.setup_level(self)
    MusicManager.play_music(load("res://Audio/Music_Levels/SnowPathLevel/Adventures.wav"))


func _exit_tree() -> void:
    # Quando cambi livello, riattiva il gioco
    get_tree().paused = false
