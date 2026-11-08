extends Panel

var level_menu_scene = preload("res://Menu/Scenes/level_menu.tscn")
# Called when the node enters the scene tree for the first time.
var _hint: Label

func _ready() -> void:
    $fade_transition.visible=true
    # A selection made in an earlier visit may point to a character that's
    # locked now (or from before the Shop existed): start clean.
    Global.selected_character = null
    Global.character_scene = null
    _add_shop_button()
    _hint = Label.new()
    _hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
    _hint.offset_left = -330.0
    _hint.offset_right = 330.0
    _hint.offset_top = -110.0
    _hint.offset_bottom = -40.0
    _hint.add_theme_font_size_override("font_size", 22)
    _hint.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
    _hint.add_theme_constant_override("outline_size", 6)
    _hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
    add_child(_hint)

## Same style as the Back button, in the top-right corner.
func _add_shop_button() -> void:
    var shop: Button = $back_button.duplicate(0)
    shop.name = "ShopButton"
    shop.text = "Shop"
    shop.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    shop.offset_left = -193.0
    shop.offset_right = -68.0
    shop.offset_top = 33.0
    shop.offset_bottom = 85.0
    shop.pressed.connect(func():
        SFXManager.play_sfx(preload("res://Audio/SFX/MenuSFX/Confirm.wav"))
        ShopMenu.open_from(get_tree(), "res://SelezionePg/Scenes/menu_selezione.tscn"))
    add_child(shop)

func show_hint(text: String) -> void:
    if _hint:
        _hint.text = text
    
    

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
