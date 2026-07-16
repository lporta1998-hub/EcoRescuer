extends Node

const SAVE_PATH = "user://settings.cfg"

var master_volume: float = 1.0 :
    set(value):
        master_volume = clamp(value, 0.0, 1.0)
        AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(master_volume))

var music_volume: float = 1.0 :
    set(value):
        music_volume = clamp(value, 0.0, 1.0)
        AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(music_volume))

var sfx_volume: float = 1.0 :
    set(value):
        sfx_volume = clamp(value, 0.0, 1.0)
        AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(sfx_volume))

func _ready():
    load_settings()

func save_settings():
    var cfg = ConfigFile.new()
    cfg.set_value("audio", "master_volume", master_volume)
    cfg.set_value("audio", "music_volume", music_volume)
    cfg.set_value("audio", "sfx_volume", sfx_volume)
    cfg.save(SAVE_PATH)

func load_settings():
    var cfg = ConfigFile.new()
    if cfg.load(SAVE_PATH) != OK:
        return  # Nessun file salvato, si usano i default
    master_volume = cfg.get_value("audio", "master_volume", 1.0)
    music_volume  = cfg.get_value("audio", "music_volume",  1.0)
    sfx_volume    = cfg.get_value("audio", "sfx_volume",    1.0)

func reset_to_defaults():
    master_volume = 1.0
    music_volume  = 1.0
    sfx_volume    = 1.0
    save_settings()
