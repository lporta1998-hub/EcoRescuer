extends CanvasLayer

@onready var items_container = $VBoxContainer/ScrollContainer/VBoxContainer
@onready var total_label = $VBoxContainer/VBoxContainer2/Label2
@onready var score_label = $VBoxContainer/VBoxContainer2/Label3
@onready var percentage_label = $VBoxContainer/VBoxContainer2/Label4
@onready var time_label = $VBoxContainer/VBoxContainer2/Label

var level_data = {}
## Seconds before the next chapter starts by itself.
const AUTO_ADVANCE_SECONDS := 8
var _next_button: Button
var _countdown := 0.0
var _advancing := false

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
        _show_coins_earned()
        _show_star_conditions()
        _show_quests()
    _show_stars()
    _setup_next_button()
    # Mostra gli oggetti raggruppati
    display_grouped_items()

const STAR_FULL := preload("res://Menu/Stars/star_full.png")
const STAR_EMPTY := preload("res://Menu/Stars/star_empty.png")
const STAR_TEXTS := ["Livello completato", "Tutti gli oggetti raccolti", "Nessun danno subito"]

## Three big stars under the title; earned ones pop in one after the other.
func _show_stars() -> void:
    var row: HBoxContainer = get_node_or_null("StarsRow")
    if row == null:
        row = HBoxContainer.new()
        row.name = "StarsRow"
        row.alignment = BoxContainer.ALIGNMENT_CENTER
        row.add_theme_constant_override("separation", 14)
        row.set_anchors_preset(Control.PRESET_CENTER_TOP)
        row.offset_left = -150.0
        row.offset_right = 150.0
        row.offset_top = 150.0
        row.offset_bottom = 206.0
        add_child(row)
        for i in 3:
            var star := TextureRect.new()
            star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
            star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
            star.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
            star.custom_minimum_size = Vector2(56, 56)
            star.pivot_offset = Vector2(28, 28)
            row.add_child(star)
    var earned: int = level_data.get("stars", 0)
    var tween := create_tween()
    tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)  # the game is paused here
    for i in 3:
        var star: TextureRect = row.get_child(i)
        star.texture = STAR_EMPTY
        star.scale = Vector2.ONE
        if i < earned:
            tween.tween_interval(0.25)
            tween.tween_callback(func(): star.texture = STAR_FULL)
            tween.tween_property(star, "scale", Vector2(1.35, 1.35), 0.1)
            tween.tween_property(star, "scale", Vector2.ONE, 0.12)

## One line per star condition under the stats, green when achieved.
func _show_star_conditions() -> void:
    var box := score_label.get_parent()
    var conds: Array = level_data.get("star_conditions", [false, false, false])
    for i in 3:
        var line_name := "StarCondition%d" % i
        var line: Label = box.get_node_or_null(line_name)
        if line == null:
            line = score_label.duplicate()
            line.name = line_name
            box.add_child(line)
        var ok: bool = conds[i] if i < conds.size() else false
        line.text = ("[x] " if ok else "[  ] ") + STAR_TEXTS[i]
        line.add_theme_color_override("font_color", Color(1.0, 0.83, 0.3) if ok else Color(0.7, 0.7, 0.7))
    var total_line: Label = box.get_node_or_null("StarTotal")
    if total_line == null:
        total_line = score_label.duplicate()
        total_line.name = "StarTotal"
        total_line.add_theme_color_override("font_color", Color(1.0, 0.83, 0.3))
        box.add_child(total_line)
    var total: int = level_data.get("stars_total", 0)
    total_line.text = ("Nuovo record! Stelle totali: %d" if level_data.get("new_star_record", false) else "Stelle totali: %d") % total

## "Monete: +N (totale M)" line under the score, added in code so the
## scene layout stays untouched.
func _show_coins_earned() -> void:
    var coins_label: Label = score_label.get_parent().get_node_or_null("CoinsLabel")
    if coins_label == null:
        coins_label = score_label.duplicate()
        coins_label.name = "CoinsLabel"
        coins_label.add_theme_color_override("font_color", Color(0.65, 0.95, 0.3))
        score_label.get_parent().add_child(coins_label)
    coins_label.text = "Monete: +%d (totale %d)" % [
        level_data.get("coins_earned", 0), level_data.get("coins_total", 0)]
    var bonus: float = level_data.get("coin_bonus", 0.0)
    if bonus > 0.001:
        coins_label.text += "  bonus sfide +%d%%" % roundi(bonus * 100.0)
    var chest: int = level_data.get("chest_coins", 0)
    if chest > 0:
        coins_label.text += "  forzieri +%d" % chest

## Side quests of the level: "[x] Dossier segreto  +100".
func _show_quests() -> void:
    var box := score_label.get_parent()
    var quests: Array = level_data.get("quests", [])
    for i in quests.size():
        var line_name := "Quest%d" % i
        var line: Label = box.get_node_or_null(line_name)
        if line == null:
            line = score_label.duplicate()
            line.name = line_name
            box.add_child(line)
        var q: Array = quests[i]
        line.text = ("[x] " if q[1] else "[  ] ") + q[0]
        line.add_theme_color_override("font_color", Color(1.0, 0.75, 0.35) if q[1] else Color(0.7, 0.7, 0.7))
    var bonus: int = level_data.get("quest_coins", 0)
    if bonus > 0:
        var coins_label: Label = box.get_node_or_null("CoinsLabel")
        if coins_label:
            coins_label.text += "  missioni +%d" % bonus

## "Avanti" starts the next chapter, by itself after a short countdown. After
## the final boss it plays the ending instead.
func _setup_next_button() -> void:
    if _next_button == null:
        var row: HBoxContainer = get_node_or_null("ButtonsRow")
        if row == null:
            return
        _next_button = $ButtonsRow/Livelli.duplicate()
        for c in _next_button.get_signal_connection_list("pressed"):
            _next_button.disconnect("pressed", c.callable)
        _next_button.name = "Avanti"
        _next_button.pressed.connect(_advance)
        row.add_child(_next_button)
        row.offset_left = -390.0  # room for three buttons
        row.offset_right = 390.0
        for b in row.get_children():
            b.custom_minimum_size.x = 240.0
        $ButtonsRow/MenuPrincipale.pressed.connect(func(): _countdown = -1.0)
        $ButtonsRow/Livelli.pressed.connect(func(): _countdown = -1.0)
    var ld: LevelData = Global.selected_level_data
    var has_next := Story.next_level(ld) != null or Story.is_final(ld)
    _next_button.visible = has_next
    _countdown = AUTO_ADVANCE_SECONDS if has_next else -1.0
    _advancing = false
    _update_next_label()

func _update_next_label() -> void:
    if _next_button == null:
        return
    var word := "Finale" if Story.is_final(Global.selected_level_data) else "Avanti"
    _next_button.text = ("%s (%d)" % [word, ceili(_countdown)]) if _countdown > 0.0 else word

func _process(delta: float) -> void:
    if not visible or _countdown <= 0.0 or _advancing:
        return
    _countdown -= delta
    _update_next_label()
    if _countdown <= 0.0:
        _advance()

func _advance() -> void:
    if _advancing:
        return
    _advancing = true
    SFXManager.play_sfx(preload("res://Audio/SFX/MenuSFX/Confirm.wav"))
    MusicManager.resume_music()
    get_tree().paused = false
    var ld: LevelData = Global.selected_level_data
    if Story.is_final(ld):
        Cutscene.play(get_tree(), Cutscene.ending_panels(), "res://main_menu.tscn")
        return
    var next: LevelData = Story.next_level(ld)
    if next == null:
        get_tree().change_scene_to_file("res://Menu/Scenes/level_menu.tscn")
        return
    Global.selected_level_data = next
    Global.selected_level = next.level_scene
    Global.load_game()

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
    
