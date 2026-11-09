extends CanvasLayer

var is_paused := false

@onready var items_container = $ScrollContainer/VBoxContainer
var level_data = {}
var is_audio_menu_open: bool = false
# Called when the node enters the scene tree for the first time.
var _level_map: LevelMap

func _ready() -> void:
    visible = false
    process_mode = Node.PROCESS_MODE_ALWAYS
    _add_level_map()
    visibility_changed.connect(_on_visibility_changed)


## "Mappa" panel in the middle of the pause screen.
func _add_level_map() -> void:
    var panel := PanelContainer.new()
    panel.name = "MapPanel"
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0, 0, 0, 0.45)
    style.set_border_width_all(4)
    style.border_color = Color(1, 1, 1, 0.8)
    style.set_corner_radius_all(16)
    style.content_margin_left = 12
    style.content_margin_right = 12
    style.content_margin_top = 8
    style.content_margin_bottom = 8
    panel.add_theme_stylebox_override("panel", style)
    panel.set_anchors_preset(Control.PRESET_CENTER)
    panel.offset_left = -205.0
    panel.offset_right = 205.0
    panel.offset_top = -175.0
    panel.offset_bottom = 175.0
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(panel)
    move_child(panel, $VBoxContainer.get_index())  # under the buttons and popups
    var box := VBoxContainer.new()
    box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_child(box)
    var title := Label.new()
    title.text = "Mappa"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 26)
    title.add_theme_constant_override("outline_size", 6)
    title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
    box.add_child(title)
    _level_map = LevelMap.new()
    _level_map.custom_minimum_size = Vector2(386, 290)
    box.add_child(_level_map)


func _on_visibility_changed() -> void:
    if visible:
        # wait one frame so the panel has its final size
        await get_tree().process_frame
        if visible:
            _level_map.open(get_tree().current_scene)
    else:
        _level_map.close()
    


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
    if !$PopupMenu.visible:
        is_audio_menu_open= false
    pass


func set_level_data(data: Dictionary) -> void:
    level_data = data
    display_grouped_items()

func display_grouped_items() -> void:
    if not items_container:
        return
    
    # Pulisci il container
    for child in items_container.get_children():
        child.queue_free()
    
    var counter = level_data.get("items_counter", {})
    
    if counter.size() == 0:
        var placeholder = Label.new()
        placeholder.text = "Nessun oggetto raccolto"
        items_container.add_child(placeholder)
        return
    
    for item_type in counter:
        var item_data = counter[item_type]
        create_item_display(item_data)

func create_item_display(item_data: Dictionary) -> void:
    # Crea un container orizzontale per l'oggetto
    var hbox = HBoxContainer.new()
    hbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    
    # Icona
    var icon = TextureRect.new()
    icon.custom_minimum_size = Vector2(48, 48)
    icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    
    if item_data.has("icon") and item_data["icon"]:
        icon.texture = item_data["icon"]
    
    hbox.add_child(icon)
    
    # Contatore
    var count_label = Label.new()
    count_label.text = "x" + str(item_data.get("count", 0))
    count_label.add_theme_font_size_override("font_size", 24)
    count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    hbox.add_child(count_label)
    
    # Nome
    var name_label = Label.new()
    name_label.text = item_data.get("name", "Oggetto")
    name_label.add_theme_font_size_override("font_size", 16)
    name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    hbox.add_child(name_label)
    
    # Aggiungi al container principale
    items_container.add_child(hbox)
func _input(event: InputEvent):
    if is_audio_menu_open:
        return
    if event.is_action_pressed("pause"):
        toggle_pause()
        get_viewport().set_input_as_handled()  # Blocca propagazione

func toggle_pause():
    if is_paused:
        _on_riprendi_pressed()
    else:
        pause_game()

func pause_game():
    
    
    # 1. Mostra il menu
    show()
    visible = true
    SFXManager.play_sfx(preload("res://Audio/SFX/Eco/ui_pause.wav"))
    
    # 2. Metti in pausa l'albero
    get_tree().paused = true
    
    # 3. Aggiorna stato
    is_paused = true

func _on_menu_principale_pressed() -> void:
    get_tree().paused = false
    SFXManager.play_sfx(preload("res://Audio/SFX/Eco/ui_back.wav"))
    get_tree().change_scene_to_file("res://main_menu.tscn")
    

func _on_riprendi_pressed() -> void:
    print("▶️ RIPRENDE GIOCO")
    SFXManager.play_sfx(preload("res://Audio/SFX/Eco/ui_unpause.wav"))
    $".".hide()
    get_tree().paused = false
    is_paused = false


func _on_opzioni_pressed() -> void:
    SFXManager.play_sfx(preload("res://Audio/SFX/Eco/ui_confirm.wav"))
    $PopupMenu.show()
    is_audio_menu_open = true
    
