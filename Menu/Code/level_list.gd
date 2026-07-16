extends GridContainer

@export var level_slot : PackedScene
@export var levels : Array[LevelData]  # Array di scene dei livelli
@onready var best_score_label = $"../../../ContenitoreRecord/Label"
@onready var best_score_container = $"../../../ContenitoreRecord"
@onready var start_button = $"../../../start_button"
var selected_level : LevelData = null
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    if start_button:
        start_button.hide()
        
    load_levels()
    if Global:
        # Crea un segnale in Global se non esiste
        if not Global.has_signal("high_score_updated"):
            Global.high_score_updated.connect(_on_high_score_updated)
    if best_score_container:
        best_score_container.hide()

func load_levels():
    # Pulisci eventuali slot esistenti
    for child in get_children():
        child.queue_free()
    
    for level in levels:
        var slot = level_slot.instantiate()
        slot.setup(level)  # Usa il nuovo metodo setup
        slot.pressed.connect(_on_level_slot_pressed.bind(level))
        
        add_child(slot)

func update_best_score_display(level: LevelData):
    if not best_score_label:
        return
    
    if level.high_score > 0:
        best_score_label.text = "Record:\n🏆 %d" % level.high_score
        best_score_label.show()
    else:
        best_score_label.text = "Miglior p: --"
        best_score_container.hide()  # O .hide() se vuoi nasconderlo


func _on_level_slot_pressed(level: LevelData):
    SFXManager.play_sfx(preload("res://Audio/SFX/MenuSFX/Confirm.wav"))
    print("Livello selezionato")
    print(level.level_name)
    print(level.description)
    selected_level = level
    Global.selected_level_data = level
    Global.selected_level = level.level_scene    
    if best_score_container:
        best_score_container.show()
        update_best_score_display(level)
    $"../../../start_button".show()
    
func _on_high_score_updated(level_data: LevelData):
    # Trova lo slot corrispondente e aggiorna
    for slot in get_children():
        if slot.level_data == level_data:
            slot.update_high_score_display()
            break
    
