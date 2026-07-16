extends Control

@onready var bg1 = $Panel
@onready var bg2 = $Panel2
@onready var timer = $Timer

var backgrounds = [
    preload("res://Menu/Background/Forestbg.png"),
    preload("res://Menu/Background/Immagine 2026-02-21 155216.png"),
    preload("res://Menu/Background/SnowPathBG.png"),
    preload("res://Menu/Background/Citybg.png")
]

var current_index = 0
var using_bg1 = true

func _ready():
    bg1.texture = backgrounds[0]
    bg2.modulate.a = 0
    timer.timeout.connect(_on_timer_timeout)
    timer.start()

func _on_timer_timeout():
    print("Cambio sfondo")
    
    current_index = (current_index + 1) % backgrounds.size()
    
    var next_bg = bg2 if using_bg1 else bg1
    var current_bg = bg1 if using_bg1 else bg2
    
    next_bg.texture = backgrounds[current_index]
    next_bg.modulate.a = 0
    
    var tween = create_tween()
    tween.parallel().tween_property(next_bg, "modulate:a", 1.0, 1.0)
    tween.parallel().tween_property(current_bg, "modulate:a", 0.0, 1.0)
    
    using_bg1 = !using_bg1
