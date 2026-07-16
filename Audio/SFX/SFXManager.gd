extends Node

const MAX_PLAYERS = 8

var players: Array[AudioStreamPlayer] = []

func _ready():
    for i in MAX_PLAYERS:
        var p = AudioStreamPlayer.new()
        p.autoplay = false
        p.bus = "SFX"
        p.process_mode = Node.PROCESS_MODE_ALWAYS
        add_child(p)
        players.append(p)
    
    process_mode = Node.PROCESS_MODE_ALWAYS

func play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch: float = 1.0):
    var player = _get_free_player()
    if player == null:
        return
    player.stream = stream
    player.volume_db = volume_db
    player.pitch_scale = pitch
    player.play()

func play_sfx_random_pitch(stream: AudioStream, pitch_min: float = 0.9, pitch_max: float = 1.1):
    play_sfx(stream, 0.0, randf_range(pitch_min, pitch_max))

func stop_all():
    for p in players:
        p.stop()

func _get_free_player() -> AudioStreamPlayer:
    for p in players:
        if not p.playing:
            return p
    # Se tutti occupati, interrompe il più vecchio (primo della lista)
    players[0].stop()
    return players[0]
