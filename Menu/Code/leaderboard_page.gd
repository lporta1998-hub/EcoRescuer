extends CanvasLayer

func _ready() -> void:
    _connect_header_controls()
    _update_ui_and_load()


@onready var leaderboard: Node = $Leaderboard
@onready var map_name_label: Label = $Leaderboard/Board/HighScores/Header/MapName
@onready var left_arrow: Button = $Leaderboard/Board/HighScores/Header/LeftArrow
@onready var right_arrow: Button = $Leaderboard/Board/HighScores/Header/RightArrow

var map_leaderboards := [
    {"name": "Forest", "ld": "forest"},
    {"name": "City", "ld": "city"},
    {"name": "Polluted Lake", "ld": "polluted_lake"},
    {"name": "Snow Path", "ld": "snow_path"},
    {"name": "Ruins", "ld": "ruins"},
    {"name": "AI Data Center", "ld": "ai_data_center"},
]

var current_index := 0


func _connect_header_controls() -> void:
    if left_arrow and !left_arrow.pressed.is_connected(_on_left_arrow_pressed):
        left_arrow.pressed.connect(_on_left_arrow_pressed)
    if right_arrow and !right_arrow.pressed.is_connected(_on_right_arrow_pressed):
        right_arrow.pressed.connect(_on_right_arrow_pressed)


func _on_left_arrow_pressed() -> void:
    current_index = (current_index - 1 + map_leaderboards.size()) % map_leaderboards.size()
    SFXManager.play_sfx(preload("res://Audio/SFX/MenuSFX/Confirm.wav"))
    _update_ui_and_load()


func _on_right_arrow_pressed() -> void:
    current_index = (current_index + 1) % map_leaderboards.size()
    SFXManager.play_sfx(preload("res://Audio/SFX/MenuSFX/Confirm.wav"))
    _update_ui_and_load()


func _update_ui_and_load() -> void:
    if map_leaderboards.is_empty():
        return

    var entry: Dictionary = map_leaderboards[current_index]
    map_name_label.text = str(entry["name"])

    if leaderboard and leaderboard.has_method("load_leaderboard"):
        leaderboard.load_leaderboard(str(entry["ld"]))
