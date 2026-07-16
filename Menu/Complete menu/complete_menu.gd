extends CanvasLayer

@onready var items_container = $VBoxContainer/ScrollContainer/VBoxContainer
@onready var total_label = $VBoxContainer/VBoxContainer2/Label2
@onready var score_label = $VBoxContainer/VBoxContainer2/Label3
@onready var percentage_label = $VBoxContainer/VBoxContainer2/Label4
@onready var time_label = $VBoxContainer/VBoxContainer2/Label

var level_data = {}

func _ready() -> void:
    process_mode = PROCESS_MODE_ALWAYS
    

func set_level_data(data: Dictionary) -> void:
    level_data = data
    update_display()

func format_time(total_seconds: float) -> String:
    var minutes = floor(total_seconds / 60)
    var seconds = int(total_seconds) % 60
    
    if minutes > 0:
        return "%d minuti e %d secondi" % [minutes, seconds]
    else:
        return "%d secondi" % seconds

func update_display() -> void:
    # Aggiorna etichette principali
    if total_label:
        # Usa le chiavi CORRETTE
        total_label.text = "Oggetti: %d/%d" % [
            level_data.get("collected_items", 0),
            level_data.get("total_items", 0)  
            ]
    
    if percentage_label:
        # Mostra percentuale di completamento TOTALE (tutti gli oggetti)
        var percentage = level_data.get("completion_percentage", 0)
        percentage_label.text = "Completamento: %.1f%%" % percentage
    
    if time_label:
        var total_seconds = level_data.get("completion_seconds", 0)
        var time_string = format_time(total_seconds)
        time_label.text = "Tempo: %s" % time_string
    if score_label:
        var current_score = level_data.get("score", 0)
        score_label.text = "Punteggio: %d" % current_score
    # Mostra gli oggetti raggruppati
    display_grouped_items()

func display_grouped_items() -> void:
    if not items_container:
        return
    
    # Pulisci il container degli oggetti
    for child in items_container.get_children():
        child.queue_free()
    
    # Ottieni il contatore
    var counter = level_data.get("items_counter", {})
    
    # Crea un display per ogni tipo di oggetto
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

func _on_menu_principale_pressed() -> void:
    MusicManager.resume_music()
    get_tree().paused = false
    get_tree().change_scene_to_file("res://main_menu.tscn")
    SFXManager.play_sfx(preload("res://Audio/SFX/MenuSFX/Unequip.wav"))

func _on_livelli_pressed() -> void:
    MusicManager.resume_music()
    get_tree().paused = false
    Global.selected_level = null
    Global.selected_level_data = null
    get_tree().change_scene_to_file("res://Menu/Scenes/level_menu.tscn")
    SFXManager.play_sfx(preload("res://Audio/SFX/MenuSFX/Unequip.wav"))
    
