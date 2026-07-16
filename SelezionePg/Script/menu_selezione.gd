extends Panel

var level_menu_scene = preload("res://Menu/Scenes/level_menu.tscn")
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    $fade_transition.visible=true
    
    

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
    pass


func _on_conferma_button_pressed() -> void:
    if Global.selected_character:
        SFXManager.play_sfx(preload("res://Audio/SFX/MenuSFX/Confirm.wav"))
        
        await $fade_transition.fade_out()
        get_tree().change_scene_to_packed(level_menu_scene)
    else:
        print("ERRORE: Nessun personaggio selezionato!")


func _on_back_button_pressed() -> void:
    SFXManager.play_sfx(preload("res://Audio/SFX/MenuSFX/Unequip.wav"))
    get_tree().change_scene_to_file("res://main_menu.tscn")
