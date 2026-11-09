extends CanvasLayer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    $start_button.hide()

    $fade_transition.visible=true
    await $fade_transition.fade_in()
     

    if Global.selected_level:
        $start_button.show()
   

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
    pass


func _on_back_button_pressed() -> void:
    SFXManager.play_sfx(preload("res://Audio/SFX/Eco/ui_back.wav"))
    await $fade_transition.fade_out()
    Global.selected_level = null
    Global.selected_level_data = null
    get_tree().change_scene_to_file("res://SelezionePg/Scenes/menu_selezione.tscn")
    
    

func _on_start_button_pressed() -> void:
    SFXManager.play_sfx(preload("res://Audio/SFX/Eco/ui_confirm.wav"))
    await $fade_transition.fade_out()
    if Global.selected_character and Global.selected_level:
        print("Avvio livello con:")
        print("- Personaggio: ", Global.selected_character.title)
        print("- Livello: ", Global.selected_level)
        # Carica il gioco
        Global.load_game()
    else:
        print("Seleziona prima personaggio e livello!")
        

        
        
