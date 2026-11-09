extends GridContainer

@export var pg_slot : PackedScene
    
@export var characters : Array[Pg]

var selected_character : Pg = null

func _ready() -> void:
    $"../../ConfermaButton".hide()
    load_characters() 
    
func load_characters():
    # Free character first, then cheapest to most expensive.
    # Same roster as the Shop (includes the new heroes).
    var sorted: Array = ShopMenu.CHARACTERS.duplicate()
    sorted.sort_custom(func(a: Pg, b: Pg): return a.price < b.price)
    for character in sorted:
        var slot = pg_slot.instantiate()
        
        slot.icon = character.icon
        slot.pressed.connect(_on_slot_pressed.bind(character))
        add_child(slot)
        slot.set_locked(not Progress.is_unlocked(character), character.price)

func _on_slot_pressed(character: Pg):
    if not Progress.is_unlocked(character):
        SFXManager.play_sfx(preload("res://Audio/SFX/Eco/ui_denied.wav"))
        selected_character = null
        $"../../ConfermaButton".hide()
        get_parent().get_parent().show_hint(
            "%s è bloccato: costa %d monete (ne hai %d). Sbloccalo nello Shop!" % [character.title, character.price, Progress.coins])
        return
    get_parent().get_parent().show_hint("")
    SFXManager.play_sfx(preload("res://Audio/SFX/Eco/ui_confirm.wav"))
    print("Personaggio selezionato: ", character.title)
    selected_character = character
    $"../../ConfermaButton".show()
    Global.selected_character = character
    Global.character_scene = character.scene
    
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
    pass
