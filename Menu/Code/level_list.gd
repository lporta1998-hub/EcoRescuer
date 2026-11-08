extends GridContainer

@export var level_slot : PackedScene
@export var levels : Array[LevelData]  # Array di scene dei livelli
@onready var best_score_label = $"../../../ContenitoreRecord/Label"
@onready var best_score_container = $"../../../ContenitoreRecord"
@onready var start_button = $"../../../start_button"
var selected_level : LevelData = null
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    if start_button:
        start_button.hide()
        
    load_levels()
    _show_total_stars()
    if Global:
        # Crea un segnale in Global se non esiste
        if not Global.has_signal("high_score_updated"):
            Global.high_score_updated.connect(_on_high_score_updated)
    if best_score_container:
        best_score_container.hide()

func load_levels():
    # The campaign order comes from Story (new levels appear automatically).
    var campaign := Story.campaign_levels()
    if not campaign.is_empty():
        levels = campaign
    # Pulisci eventuali slot esistenti
    for child in get_children():
        child.queue_free()
    
    for level in levels:
        Global.apply_saved_high_score(level)
        var slot = level_slot.instantiate()
        slot.setup(level)  # Usa il nuovo metodo setup
        slot.pressed.connect(_on_level_slot_pressed.bind(level))
        
        add_child(slot)

func update_best_score_display(level: LevelData):
    if not best_score_label:
        return
    
    best_score_label.add_theme_font_size_override("font_size", 30)
    if level.high_score > 0:
        best_score_label.text = "Record:\n%d" % level.high_score
        best_score_label.show()
    else:
        best_score_label.text = "Miglior p: --"
        best_score_container.hide()  # O .hide() se vuoi nasconderlo


## "★ 5 / 15" in the top-right corner of the level menu.
func _show_total_stars() -> void:
    var box := HBoxContainer.new()
    box.alignment = BoxContainer.ALIGNMENT_END
    box.add_theme_constant_override("separation", 8)
    box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    box.offset_left = -260.0
    box.offset_right = -48.0
    box.offset_top = 40.0
    box.offset_bottom = 90.0
    var star := TextureRect.new()
    star.texture = preload("res://Menu/Stars/star_full.png")
    star.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    star.custom_minimum_size = Vector2(40, 40)
    var label := Label.new()
    label.text = "%d / %d" % [Progress.total_stars(), levels.size() * Progress.MAX_STARS_PER_LEVEL]
    label.add_theme_font_size_override("font_size", 32)
    label.add_theme_constant_override("outline_size", 6)
    label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
    box.add_child(star)
    box.add_child(label)
    owner.add_child.call_deferred(box)

func _on_level_slot_pressed(level: LevelData):
    if not Progress.is_level_unlocked(level):
        SFXManager.play_sfx(preload("res://Audio/SFX/MenuSFX/Unequip.wav"))
        selected_level = null
        Global.selected_level = null
        Global.selected_level_data = null
        $"../../../start_button".hide()
        if best_score_container and best_score_label:
            best_score_container.show()
            best_score_label.text = "Bloccato!\nServono %d stelle\n(ne hai %d)" % [level.stars_required, Progress.total_stars()]
            best_score_label.add_theme_font_size_override("font_size", 22)
            best_score_label.show()
        return
    SFXManager.play_sfx(preload("res://Audio/SFX/MenuSFX/Confirm.wav"))
    print("Livello selezionato")
    print(level.level_name)
    print(level.description)
    selected_level = level
    Global.selected_level_data = level
    Global.selected_level = level.level_scene    
    if best_score_container:
        best_score_container.show()
        update_best_score_display(level)
    $"../../../start_button".show()
    
func _on_high_score_updated(level_data: LevelData):
    # Trova lo slot corrispondente e aggiorna
    for slot in get_children():
        if slot.level_data == level_data:
            slot.update_high_score_display()
            break
    
