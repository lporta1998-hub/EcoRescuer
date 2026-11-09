extends CanvasLayer
@onready var items_container = $ScrollContainer/VBoxContainer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    #visible=false
    pass
var level_data = {}

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
    pass

#func _input(event: InputEvent):
    ## Controlla se premi ESC
    #if event.is_action_pressed("go"):
        #show()
        #visible = true
    #
    ## 2. Metti in pausa l'albero
        #get_tree().paused = true

func _on_menu_principale_pressed() -> void:
    MusicManager.resume_music()
    get_tree().paused = false
    get_tree().change_scene_to_file("res://main_menu.tscn")
    SFXManager.play_sfx(preload("res://Audio/SFX/Eco/ui_back.wav"))
    


func _on_riprova_pressed() -> void:
    SFXManager.play_sfx(preload("res://Audio/SFX/Eco/ui_confirm.wav"))
    # Mostra il rettangolo nero
    $TransitionRect.color = Color.BLACK
    $TransitionRect.modulate.a = 0.0  # Inizia trasparente
    $TransitionRect.visible = true
    var tween = create_tween()
    tween.tween_property($TransitionRect, "modulate:a", 1.0, 0.3)
    MusicManager.resume_music()
    
    await get_tree().create_timer(0.5).timeout
    # Ricarica
    Global.load_game()
    get_tree().paused = false
    
   
func set_level_data(data: Dictionary) -> void:
    level_data = data
    display_grouped_items()
    _show_coins_earned()

## Under the "Game Over" title: the half share of coins the player keeps.
func _show_coins_earned() -> void:
    var coins_label: Label = get_node_or_null("CoinsLabel")
    if coins_label == null:
        coins_label = Label.new()
        coins_label.name = "CoinsLabel"
        coins_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
        coins_label.offset_left = -300.0
        coins_label.offset_right = 300.0
        coins_label.offset_top = 150.0
        coins_label.offset_bottom = 190.0
        coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        coins_label.add_theme_font_size_override("font_size", 26)
        coins_label.add_theme_color_override("font_color", Color(0.65, 0.95, 0.3))
        coins_label.add_theme_constant_override("outline_size", 6)
        coins_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
        add_child(coins_label)
    coins_label.text = "Hai salvato metà del bottino: +%d monete" % level_data.get("coins_earned", 0)

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
