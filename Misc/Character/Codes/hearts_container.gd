class_name HP
extends HBoxContainer

var HPGui : PackedScene = preload("res://Misc/Character/Scenes/heart.tscn")

func _ready():
    pass

func setMaxHP(max: int):
    for i in range(max):
        var hp = HPGui.instantiate()
        add_child(hp)

func updateHP(currentHP: float):
    var hearts = get_children()
    var full := clampi(int(currentHP), 0, hearts.size())
    for i in range(full):
        hearts[i].update(true)
    for i in range(full, hearts.size()):
        hearts[i].update(false)
