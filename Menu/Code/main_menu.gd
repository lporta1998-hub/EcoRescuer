extends CanvasLayer

var pg_menu_scene = preload("res://SelezionePg/Scenes/menu_selezione.tscn")
@onready var name_overlay: Control = $NameOverlay
@onready var name_line_edit: LineEdit = $NameOverlay/NamePanel/VBox/NameLineEdit
@onready var name_confirm_button: Button = $NameOverlay/NamePanel/VBox/ConfermaButton
@onready var name_panel: Control = $NameOverlay/NamePanel
## True when the name box was opened from "cambia nome" (stay in the menu).
var _renaming := false
var _player_button: Button
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    # iOS apps don't quit themselves (Apple guidelines): no Quit button on phones.
    if OS.has_feature("mobile"):
        $VBoxContainer/QuitButton.hide()
    _add_player_button()
    _add_story_button()
    $fade_transition.visible=true
    MusicManager.play_music(load("res://Audio/Music_Levels/Menu/Menu.mp3"))
    await $fade_transition.fade_in()
    _sync_name_prompt_with_state()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
    if name_overlay.visible:
        _keep_name_panel_above_keyboard(delta)


## On phones the on-screen keyboard covers the lower half of the screen in
## landscape, hiding the name box. While the keyboard is open, slide the box
## to the top of the screen; slide it back to the centre when it closes.
func _keep_name_panel_above_keyboard(delta: float) -> void:
    var screen_h := get_viewport().get_visible_rect().size.y
    var target_y := (screen_h - name_panel.size.y) / 2.0
    if DisplayServer.virtual_keyboard_get_height() > 0:
        target_y = 16.0
    name_panel.position.y = lerpf(name_panel.position.y, target_y, minf(1.0, delta * 14.0))


func _on_quit_button_pressed() -> void:
    SFXManager.play_sfx(preload("res://Audio/SFX/MenuSFX/Unequip.wav"))
    get_tree().quit()


func _on_start_button_pressed() -> void:
    SFXManager.play_sfx(preload("res://Audio/SFX/MenuSFX/Confirm.wav"))
    # The name is asked only the first time; after that Start goes straight in.
    if Global.player_name.strip_edges() != "":
        await $fade_transition.fade_out()
        _go_to_game()
        return
    _renaming = false
    _open_name_prompt()


## Small "Giocatore: <name> · cambia" button in the bottom-left corner.
func _add_player_button() -> void:
    _player_button = Button.new()
    _player_button.flat = true
    _player_button.add_theme_font_size_override("font_size", 22)
    _player_button.add_theme_constant_override("outline_size", 6)
    _player_button.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
    _player_button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
    _player_button.offset_left = 40.0
    _player_button.offset_top = -64.0
    _player_button.offset_bottom = -24.0
    _player_button.pressed.connect(func():
        SFXManager.play_sfx(preload("res://Audio/SFX/MenuSFX/Confirm.wav"))
        _renaming = true
        _open_name_prompt())
    add_child(_player_button)
    move_child(_player_button, $NameOverlay.get_index())  # keep it under the name box
    _update_player_button()


## "Storia" in the bottom-right corner: replays the intro.
func _add_story_button() -> void:
    var b := Button.new()
    b.flat = true
    b.text = "Storia"
    b.add_theme_font_size_override("font_size", 22)
    b.add_theme_constant_override("outline_size", 6)
    b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
    b.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    b.offset_left = -170.0
    b.offset_right = -40.0
    b.offset_top = -64.0
    b.offset_bottom = -24.0
    b.pressed.connect(func():
        SFXManager.play_sfx(preload("res://Audio/SFX/MenuSFX/Confirm.wav"))
        Cutscene.play(get_tree(), Cutscene.INTRO, "res://main_menu.tscn"))
    add_child(b)
    move_child(b, $NameOverlay.get_index())


func _update_player_button() -> void:
    _player_button.visible = Global.player_name != ""
    _player_button.text = "Giocatore: %s  ·  cambia" % Global.player_name


func _on_shop_button_pressed() -> void:
    SFXManager.play_sfx(preload("res://Audio/SFX/MenuSFX/Confirm.wav"))
    ShopMenu.open_from(get_tree(), "res://main_menu.tscn")


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

    Progress.set_player_name(trimmed_name)
    name_overlay.visible = false
    _update_player_button()
    if _renaming:
        _renaming = false
        return
    SFXManager.play_sfx(preload("res://Audio/SFX/MenuSFX/Confirm.wav"))
    await $fade_transition.fade_out()
    _go_to_game()


## Character select, with the story intro first the very first time.
func _go_to_game() -> void:
    if not Progress.intro_seen:
        Progress.mark_intro_seen()
        Cutscene.play(get_tree(), Cutscene.INTRO, "res://SelezionePg/Scenes/menu_selezione.tscn")
        return
    get_tree().change_scene_to_packed(pg_menu_scene)
