extends GridContainer

@export var pg_slot : PackedScene
    
@export var characters : Array[Pg]

var selected_character : Pg = null

func _ready() -> void:
    $"../../ConfermaButton".hide()
    load_characters() 
    
func load_characters():
    for character in characters:
        var slot = pg_slot.instantiate()
        
        slot.icon = character.icon
        slot.pressed.connect(_on_slot_pressed.bind(character))
        add_child(slot)

func _on_slot_pressed(character: Pg):
    SFXManager.play_sfx(preload("res://Audio/SFX/MenuSFX/Confirm.wav"))
    print("Personaggio selezionato: ", character.title)
    selected_character = character
    $"../../ConfermaButton".show()
    Global.selected_character = character
    Global.character_scene = character.scene
    
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
    pass
