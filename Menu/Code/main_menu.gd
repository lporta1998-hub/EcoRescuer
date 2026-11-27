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
    Daily.stop()  # back in the menu: any Daily challenge or Rage match is over
    Rage.stop()
    # left the training from its pause menu: don't push the player back in
    if Training.active:
        Training.resume_start = false
    Training.end()
    _add_player_button()
    _add_story_button()
    _add_codex_button()
    _add_tutorial_button()
    _add_language_picker()
    _add_daily_button()
    _add_rage_button()
    _layout_buttons()
    $fade_transition.visible=true
    MusicManager.play_track("menu")
    await $fade_transition.fade_in()
    _sync_name_prompt_with_state()
    # just finished the first training: carry on with Start (story, heroes)
    if Training.resume_start:
        Training.resume_start = false
        _go_to_game()


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
    SFXManager.play_sfx(preload("res://Audio/SFX/Eco/ui_back.wav"))
    MusicManager.quit()


func _on_start_button_pressed() -> void:
    SFXManager.play_sfx(preload("res://Audio/SFX/Eco/ui_confirm.wav"))
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
        SFXManager.play_sfx(preload("res://Audio/SFX/Eco/ui_confirm.wav"))
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
        SFXManager.play_sfx(preload("res://Audio/SFX/Eco/ui_confirm.wav"))
        Cutscene.play(get_tree(), Cutscene.INTRO, "res://main_menu.tscn"))
    add_child(b)
    move_child(b, $NameOverlay.get_index())


## "Codex" next to "Storia": achievements, enemies, dossiers, stats.
func _add_codex_button() -> void:
    var b := Button.new()
    b.flat = true
    b.text = "Codex"
    b.add_theme_font_size_override("font_size", 22)
    b.add_theme_constant_override("outline_size", 6)
    b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
    b.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    b.offset_left = -310.0
    b.offset_right = -180.0
    b.offset_top = -64.0
    b.offset_bottom = -24.0
    b.pressed.connect(func():
        SFXManager.play_sfx(preload("res://Audio/SFX/Eco/ui_confirm.wav"))
        CodexMenu.open_from(get_tree(), "res://main_menu.tscn"))
    add_child(b)
    move_child(b, $NameOverlay.get_index())


## "Come si gioca" next to "Codex": the step-by-step guide to the game.
func _add_tutorial_button() -> void:
    var b := Button.new()
    b.flat = true
    b.text = "Come si gioca"
    b.add_theme_font_size_override("font_size", 22)
    b.add_theme_constant_override("outline_size", 6)
    b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
    b.add_theme_color_override("font_color", Color(0.65, 0.95, 0.3))
    b.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    b.grow_horizontal = Control.GROW_DIRECTION_BEGIN
    b.offset_left = -330.0
    b.offset_right = -320.0
    b.offset_top = -64.0
    b.offset_bottom = -24.0
    b.pressed.connect(func():
        SFXManager.play_sfx(preload("res://Audio/SFX/Eco/ui_confirm.wav"))
        Training.start())  # learn by playing, in the practice level
    add_child(b)
    move_child(b, $NameOverlay.get_index())


## Language picker in the top-right corner: the flag of the current
## language. Tapping it opens the list: "Automatico" (follow the phone's
## language), then Italiano, English, Ελληνικά. Choosing one switches the
## language and reloads the menu.
const FLAG_SIZE := Vector2(60, 40)
const PICKER_GOLD := Color(1.0, 0.83, 0.3)

func _add_language_picker() -> void:
    var button := Button.new()
    button.focus_mode = Control.FOCUS_NONE
    button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
    button.tooltip_text = Lang.NAMES[Lang.current]
    button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    button.offset_left = -120.0
    button.offset_right = -30.0
    button.offset_top = 20.0
    button.offset_bottom = 20.0 + FLAG_SIZE.y + 10.0
    _style_picker_button(button, Color(0, 0, 0, 0.35), Color(1, 1, 1, 0.6))
    var flag := LanguageFlag.new()
    flag.code = Lang.current
    flag.position = Vector2(5, 5)
    flag.size = FLAG_SIZE
    button.add_child(flag)
    var caret := Control.new()
    caret.mouse_filter = Control.MOUSE_FILTER_IGNORE
    caret.position = Vector2(FLAG_SIZE.x + 11.0, 5.0)
    caret.size = Vector2(14, FLAG_SIZE.y)
    caret.draw.connect(func():
        var c := caret.size / 2.0
        caret.draw_colored_polygon(PackedVector2Array([c + Vector2(-6, -3), c + Vector2(6, -3), c + Vector2(0, 4)]), Color.WHITE))
    button.add_child(caret)
    button.pressed.connect(func():
        SFXManager.play_sfx(preload("res://Audio/SFX/Eco/ui_confirm.wav"))
        _open_language_list(button.offset_bottom + 8.0))
    add_child(button)
    move_child(button, $NameOverlay.get_index())


func _open_language_list(top: float) -> void:
    var layer := Control.new()
    layer.set_anchors_preset(Control.PRESET_FULL_RECT)
    layer.mouse_filter = Control.MOUSE_FILTER_STOP
    layer.gui_input.connect(func(e: InputEvent):  # tap outside the list closes it
        if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed:
            layer.queue_free())
    add_child(layer)
    move_child(layer, $NameOverlay.get_index())
    var panel := PanelContainer.new()
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.02, 0.1, 0.12, 0.95)
    style.set_border_width_all(3)
    style.border_color = Color(0.55, 0.9, 1.0)
    style.set_corner_radius_all(12)
    style.set_content_margin_all(8)
    panel.add_theme_stylebox_override("panel", style)
    panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
    panel.offset_left = -30.0
    panel.offset_right = -30.0
    panel.offset_top = top
    layer.add_child(panel)
    var list := VBoxContainer.new()
    list.add_theme_constant_override("separation", 4)
    panel.add_child(list)
    list.add_child(_language_row(layer, Lang.device_language(), tr("Automatico"), Lang.automatic,
            func(): Lang.use_device_language()))
    for code in Lang.LANGUAGES:
        list.add_child(_language_row(layer, code, Lang.NAMES[code], not Lang.automatic and code == Lang.current,
                func(): Lang.apply(code)))


## One line of the language list: flag + name; the chosen one is gold.
func _language_row(layer: Control, code: String, text: String, selected: bool, choose: Callable) -> Button:
    var b := Button.new()
    b.focus_mode = Control.FOCUS_NONE
    b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
    b.custom_minimum_size = Vector2(260, 54)
    _style_picker_button(b, Color(1, 1, 1, 0.1) if selected else Color(0, 0, 0, 0),
            PICKER_GOLD if selected else Color(0, 0, 0, 0))
    var row := HBoxContainer.new()
    row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.set_anchors_preset(Control.PRESET_FULL_RECT)
    row.offset_left = 12.0
    row.offset_right = -12.0
    row.add_theme_constant_override("separation", 14)
    b.add_child(row)
    var flag := LanguageFlag.new()
    flag.code = code
    flag.custom_minimum_size = Vector2(42, 28)
    flag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    row.add_child(flag)
    var label := Label.new()
    label.text = text
    label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
    label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    label.add_theme_font_size_override("font_size", 24)
    label.add_theme_color_override("font_color", PICKER_GOLD if selected else Color.WHITE)
    row.add_child(label)
    b.pressed.connect(func():
        if selected:
            layer.queue_free()
            return
        SFXManager.play_sfx(preload("res://Audio/SFX/Eco/ui_confirm.wav"))
        choose.call()
        get_tree().reload_current_scene())
    return b


func _style_picker_button(b: Button, bg: Color, border: Color) -> void:
    for state in ["normal", "hover", "pressed", "focus"]:
        var sb := StyleBoxFlat.new()
        sb.bg_color = bg if state == "normal" or state == "focus" else bg.lerp(Color(1, 1, 1, 0.25), 0.5)
        sb.set_border_width_all(3)
        sb.border_color = border
        sb.set_corner_radius_all(8)
        b.add_theme_stylebox_override(state, sb)


## "Sfida del giorno" under Start: shows today's level and Sfide, then plays.
func _add_daily_button() -> void:
    var start: Button = $VBoxContainer/StartButton
    var b: Button = start.duplicate()
    for c in b.get_signal_connection_list("pressed"):
        b.disconnect("pressed", c.callable)
    b.name = "DailyButton"
    b.text = "Sfida del giorno"
    b.pressed.connect(_open_daily_panel)
    $VBoxContainer.add_child(b)
    $VBoxContainer.move_child(b, start.get_index() + 1)


## "Rage mode" right under Start (above the Daily challenge).
func _add_rage_button() -> void:
    var start: Button = $VBoxContainer/StartButton
    var b: Button = start.duplicate()
    for c in b.get_signal_connection_list("pressed"):
        b.disconnect("pressed", c.callable)
    b.name = "RageButton"
    b.text = "Rage mode"
    b.add_theme_color_override("font_color", Color(1.0, 0.55, 0.5))
    b.pressed.connect(func():
        SFXManager.play_sfx(preload("res://Audio/SFX/Eco/ui_confirm.wav"))
        get_tree().change_scene_to_file("res://Menu/Rage/rage_menu.tscn"))
    $VBoxContainer.add_child(b)
    $VBoxContainer.move_child(b, start.get_index() + 1)


## The menu buttons as 2 centered rows of equal buttons (3 per row on
## phones, 4 + 3 on desktop where Quit is shown too). The buttons keep the
## style and connections they have in the scene; only their container changes.
const MENU_BUTTON_SIZE := Vector2(272, 74)
const MENU_FONT_SIZE := 26
const MENU_GAP := 14

func _layout_buttons() -> void:
    var box: VBoxContainer = $VBoxContainer
    var buttons: Array[Button] = []
    for c in box.get_children():
        if c is Button and c.visible:
            buttons.append(c)
    var rows := VBoxContainer.new()
    rows.name = "MenuRows"
    rows.add_theme_constant_override("separation", MENU_GAP)
    rows.set_anchors_preset(Control.PRESET_CENTER)
    rows.grow_horizontal = Control.GROW_DIRECTION_BOTH
    rows.grow_vertical = Control.GROW_DIRECTION_BOTH
    rows.offset_top = 70.0  # a bit below the middle, clear of the title
    rows.offset_bottom = 70.0
    add_child(rows)
    move_child(rows, box.get_index())
    var per_row := ceili(buttons.size() / 2.0)
    var row: HBoxContainer
    for i in buttons.size():
        if i % per_row == 0:
            row = HBoxContainer.new()
            row.alignment = BoxContainer.ALIGNMENT_CENTER
            row.add_theme_constant_override("separation", MENU_GAP)
            rows.add_child(row)
        var b := buttons[i]
        box.remove_child(b)
        row.add_child(b)
        b.custom_minimum_size = MENU_BUTTON_SIZE
        b.add_theme_font_size_override("font_size", MENU_FONT_SIZE)
    box.hide()


func _open_daily_panel() -> void:
    SFXManager.play_sfx(preload("res://Audio/SFX/Eco/ui_confirm.wav"))
    if Global.player_name.strip_edges() == "":
        _renaming = true  # after the name, stay here and press it again
        _open_name_prompt()  # the board needs a name
        return
    var t := Daily.today()
    var layer := Control.new()
    layer.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(layer)
    move_child(layer, $NameOverlay.get_index())
    var dim := ColorRect.new()
    dim.color = Color(0, 0, 0, 0.6)
    dim.set_anchors_preset(Control.PRESET_FULL_RECT)
    layer.add_child(dim)
    var panel := PanelContainer.new()
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.02, 0.1, 0.12, 0.95)
    style.set_border_width_all(4)
    style.border_color = Color(0.55, 0.9, 1.0)
    style.set_corner_radius_all(16)
    style.set_content_margin_all(24)
    panel.add_theme_stylebox_override("panel", style)
    panel.set_anchors_preset(Control.PRESET_CENTER)
    panel.custom_minimum_size = Vector2(560, 0)
    panel.offset_left = -280.0
    panel.offset_right = 280.0
    panel.offset_top = -170.0
    panel.offset_bottom = 170.0
    layer.add_child(panel)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 10)
    panel.add_child(box)
    var lines := [
        [tr("Sfida del giorno") + "  ·  " + t.date, 30, Color(0.55, 0.9, 1.0)],
        [tr("Livello: %s") % tr(t.level.level_name), 24, Color.WHITE],
        [tr("Sfide: %s") % Daily.sfide_text(), 20, Color(1.0, 0.6, 0.55)],
        [tr("Potenziamenti spenti: stesse regole per tutti."), 18, Color(0.85, 0.85, 0.85)],
        [tr("Ricompensa di oggi già ottenuta: gioca per il punteggio!") if Daily.done_today()
                else tr("Completala per +%d monete.") % Daily.REWARD, 18, Color(1.0, 0.83, 0.3)],
    ]
    for l in lines:
        var label := Label.new()
        label.text = l[0]
        label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.add_theme_font_size_override("font_size", l[1])
        label.add_theme_color_override("font_color", l[2])
        label.add_theme_constant_override("outline_size", 6)
        label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
        box.add_child(label)
    var row := HBoxContainer.new()
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    row.add_theme_constant_override("separation", 20)
    box.add_child(row)
    var back := Button.new()
    back.text = "Indietro"
    back.add_theme_font_size_override("font_size", 24)
    back.custom_minimum_size = Vector2(180, 52)
    back.pressed.connect(func():
        SFXManager.play_sfx(preload("res://Audio/SFX/Eco/ui_back.wav"))
        layer.queue_free())
    row.add_child(back)
    var play := Button.new()
    play.text = "Gioca"
    play.add_theme_font_size_override("font_size", 24)
    play.custom_minimum_size = Vector2(180, 52)
    play.pressed.connect(func():
        SFXManager.play_sfx(preload("res://Audio/SFX/Eco/ui_confirm.wav"))
        Daily.start(get_tree()))
    row.add_child(play)


func _update_player_button() -> void:
    _player_button.visible = Global.player_name != ""
    _player_button.text = tr("Giocatore: %s  ·  cambia") % Global.player_name


func _on_shop_button_pressed() -> void:
    SFXManager.play_sfx(preload("res://Audio/SFX/Eco/ui_confirm.wav"))
    ShopMenu.open_from(get_tree(), "res://main_menu.tscn")


func _on_options_button_pressed() -> void:
    SFXManager.play_sfx(preload("res://Audio/SFX/Eco/ui_confirm.wav"))
    $PopupMenu.show()
   
    
func _on_leaderboard_button_pressed() -> void:
    SFXManager.play_sfx(preload("res://Audio/SFX/Eco/ui_confirm.wav"))
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
    SFXManager.play_sfx(preload("res://Audio/SFX/Eco/ui_confirm.wav"))
    await $fade_transition.fade_out()
    _go_to_game()


## Character select, with the story intro first the very first time.
func _go_to_game() -> void:
    # Brand-new players learn by playing: the practice level comes first.
    if not Training.done() and not Progress.intro_seen:
        Training.start(true)
        return
    if not Progress.intro_seen:
        Progress.mark_intro_seen()
        Cutscene.play(get_tree(), Cutscene.INTRO, "res://SelezionePg/Scenes/menu_selezione.tscn")
        return
    get_tree().change_scene_to_packed(pg_menu_scene)
