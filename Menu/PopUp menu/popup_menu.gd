extends CanvasLayer

@onready var master_slider: HSlider = $TabContainer/Audio/VBoxContainer/HBoxContainer/HSlider
@onready var music_slider: HSlider = $TabContainer/Audio/VBoxContainer/HBoxContainer2/HSlider
@onready var sfx_slider: HSlider = $TabContainer/Audio/VBoxContainer/HBoxContainer3/HSlider
@onready var tab_container: TabContainer = $TabContainer

const MIN_DB = -60.0
const MAX_DB = 0.0


func _ready():
    _sync_sliders()
    SettingsManager.load_settings()
    master_slider.value_changed.connect(_on_master_volume_changed)
    music_slider.value_changed.connect(_on_music_volume_changed)
    sfx_slider.value_changed.connect(_on_sfx_volume_changed)
    visibility_changed.connect(_on_visibility_changed)
    
func _process(delta):
    if Input.is_action_just_pressed("ui_cancel"):
        SettingsManager.save_settings()
        toggle_visibility()
        
    
    if Input.is_key_pressed(KEY_ESCAPE):
        SettingsManager.save_settings()
        toggle_visibility()
        
func _sync_sliders():
    master_slider.value = _db_to_slider(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master")))
    music_slider.value = _db_to_slider(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")))
    sfx_slider.value = _db_to_slider(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")))
 
func _slider_to_db(value: float) -> float:
    if value <= 0.0:
        return MIN_DB
 
    var linear = value / 100.0
    var db = linear_to_db(linear)
    return clamp(db, MIN_DB, MAX_DB)
 
func _db_to_slider(db: float) -> float:
    if db <= MIN_DB:
        return 0.0
    var linear = db_to_linear(db)
    return clamp(linear * 100.0, 0.0, 100.0)
 
func _set_volume(bus_name: String, value: float):
    var db = _slider_to_db(value)
    var bus_index = AudioServer.get_bus_index(bus_name)
    AudioServer.set_bus_volume_db(bus_index, db)
    AudioServer.set_bus_mute(bus_index, db <= MIN_DB)
 
func _on_master_volume_changed(value: float):
    _set_volume("Master", value)
    SettingsManager.master_volume = value / 100.0
 
func _on_music_volume_changed(value: float):
    _set_volume("Music", value)
    SettingsManager.music_volume = value / 100.0
 
func _on_sfx_volume_changed(value: float):
    _set_volume("SFX", value)
    SettingsManager.sfx_volume = value / 100.0
    
func toggle_visibility():
    if visible:
        hide()
        SFXManager.play_sfx(preload("res://Audio/SFX/MenuSFX/Unequip.wav"))

func _on_visibility_changed():
    if visible:
        reset_to_first_tab()
        print("Menu mostrato - reset alla tab iniziale")
    else:
        SettingsManager.save_settings()
        print("Menu nascosto")



func reset_to_first_tab():
    if tab_container and tab_container is TabContainer:
        tab_container.current_tab = 0 
        print("Tab resettata a: ", tab_container.current_tab)



func _on_tab_clicked(tab: int) -> void:
    if tab != 3:
        SFXManager.play_sfx(preload("res://Audio/SFX/MenuSFX/Confirm.wav"))
    if tab == 3:
        toggle_visibility()
