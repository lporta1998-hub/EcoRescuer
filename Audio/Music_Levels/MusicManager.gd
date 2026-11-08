extends Node
## PLACEHOLDER: the original MusicManager.gd was missing from this copy of the
## project. This minimal version only exists so the game can run. Replace it
## with the real file (same path) when you restore Audio/Music_Levels.

var _player: AudioStreamPlayer
var _current: AudioStream


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	if AudioServer.get_bus_index("Music") != -1:
		_player.bus = "Music"
	add_child(_player)


func play_music(stream: AudioStream) -> void:
	if stream == null:
		push_warning("MusicManager placeholder: music file missing, skipping.")
		return
	if stream == _current and _player.playing:
		return
	_current = stream
	_player.stream = stream
	_player.play()


func resume_music() -> void:
	if _current and not _player.playing:
		_player.play()


func play_level_complete() -> void:
	_player.stop()


func play_game_over() -> void:
	_player.stop()
