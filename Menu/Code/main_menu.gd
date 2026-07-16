extends CanvasLayer

var pg_menu_scene = preload("res://SelezionePg/Scenes/menu_selezione.tscn")
@onready var name_overlay: Control = $NameOverlay
@onready var name_line_edit: LineEdit = $NameOverlay/NamePanel/VBox/NameLineEdit
@onready var name_confirm_button: Button = $NameOverlay/NamePanel/VBox/ConfermaButton
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    $fade_transition.visible=true
    MusicManager.play_music(load("res://Audio/Music_Levels/Menu/Menu.mp3"))
    await $fade_transition.fade_in()
    _sync_name_prompt_with_state()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
    pass


func _on_quit_button_pressed() -> void:
    SFXManager.play_sfx(preload("res://Audio/SFX/MenuSFX/Unequip.wav"))
    get_tree().quit()


func _on_start_button_pressed() -> void:
    SFXManager.play_sfx(preload("res://Audio/SFX/MenuSFX/Confirm.wav"))
    _open_name_prompt()


func _on_options_button_pressed() -> void:
    SFXManager.play_sfx(preload("res://Audio/SFX/MenuSFX/Confirm.wav"))
    $PopupMenu.show()
   
    
func _on_leaderboard_button_pressed() -> void:
    SFXManager.play_sfx(preload("res://Audio/SFX/MenuSFX/Confirm.wav"))
    get_tree().change_scene_to_file("res://Menu/Scenes/leaderboard_page.tscn")


func _open_name_prompt() -> void:
    _sync_name_prompt_with_state()
    name_overlay.visible = true
    name_line_edit.grab_focus()
    name_line_edit.caret_column = name_line_edit.text.length()


func _sync_name_prompt_with_state() -> void:
    if Global.player_name != "":
        name_line_edit.text = Global.player_name
    _update_name_confirm_button()


func _update_name_confirm_button() -> void:
    name_confirm_button.disabled = name_line_edit.text.strip_edges().is_empty()


func _on_name_line_edit_text_changed(_new_text: String) -> void:
    _update_name_confirm_button()


func _on_name_line_edit_text_submitted(_new_text: String) -> void:
    _on_name_confirm_pressed()


func _on_name_confirm_pressed() -> void:
    var trimmed_name := name_line_edit.text.strip_edges()
    if trimmed_name.is_empty():
        _update_name_confirm_button()
        return

    Global.player_name = trimmed_name
    name_overlay.visible = false
    SFXManager.play_sfx(preload("res://Audio/SFX/MenuSFX/Confirm.wav"))
    await $fade_transition.fade_out()
    get_tree().change_scene_to_packed(pg_menu_scene)
