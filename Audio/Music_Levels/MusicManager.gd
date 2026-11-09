extends Node
## Background music. The tracks are original, composed by
## Tools/audio/music.py: they loop seamlessly (loop point stored in the WAV).
## Each story chapter names its track ("music" in Misc/Story/story.gd);
## LevelManager.setup_level starts it, the main menu plays "menu" and the
## Baron switches to "boss" when his fight starts.

const TRACKS := {
	"menu": "res://Audio/Music_Levels/Eco/menu.wav",
	"forest": "res://Audio/Music_Levels/Eco/forest.wav",
	"snow": "res://Audio/Music_Levels/Eco/snow.wav",
	"city": "res://Audio/Music_Levels/Eco/city.wav",
	"lake": "res://Audio/Music_Levels/Eco/lake.wav",
	"ruins": "res://Audio/Music_Levels/Eco/ruins.wav",
	"factory": "res://Audio/Music_Levels/Eco/factory.wav",
	"harbor": "res://Audio/Music_Levels/Eco/harbor.wav",
	"datacenter": "res://Audio/Music_Levels/Eco/datacenter.wav",
	"fortress": "res://Audio/Music_Levels/Eco/fortress.wav",
	"boss": "res://Audio/Music_Levels/Eco/boss.wav",
}
const VICTORY := preload("res://Audio/Music_Levels/Eco/victory.wav")
const GAME_OVER := preload("res://Audio/Music_Levels/Eco/gameover.wav")

## Music sits under the sound effects.
const VOLUME_DB := -7.0
const SILENT_DB := -40.0
const FADE := 0.8

var current_track := ""
var _current: AudioStream
var _main: AudioStreamPlayer  # the one playing
var _old: AudioStreamPlayer  # the one fading out
var _jingle: AudioStreamPlayer
var _fades := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_main = _new_player()
	_old = _new_player()
	_jingle = _new_player()


func _new_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	if AudioServer.get_bus_index("Music") != -1:
		p.bus = "Music"
	add_child(p)
	return p


## Plays one of TRACKS by name (keeps going if it's already playing).
func play_track(track: String) -> void:
	if not TRACKS.has(track):
		push_warning("MusicManager: no track called %s" % track)
		return
	if track == current_track and _main.playing:
		return
	play_music(load(TRACKS[track]))
	current_track = track


## Crossfades to `stream` (looped).
func play_music(stream: AudioStream) -> void:
	if stream == null:
		return
	_jingle.stop()
	if stream == _current and _main.playing:
		return
	current_track = ""
	_current = stream
	_make_loop(stream)
	var was := _main
	_main = _old
	_old = was
	_fade(_old, SILENT_DB, FADE, true)
	_main.stream = stream
	_main.volume_db = SILENT_DB
	_main.play()
	_fade(_main, VOLUME_DB, FADE)


## Back to the level's music after the level-complete / game-over jingle.
func resume_music() -> void:
	_jingle.stop()
	if _current and not _main.playing:
		_main.volume_db = SILENT_DB
		_main.play()
		_fade(_main, VOLUME_DB, FADE)


func play_level_complete() -> void:
	_play_jingle(VICTORY)


func play_game_over() -> void:
	_play_jingle(GAME_OVER)


func _play_jingle(stream: AudioStream) -> void:
	_fade(_main, SILENT_DB, 0.25, true)
	_jingle.stream = stream
	_jingle.volume_db = VOLUME_DB + 2.0
	_jingle.play()


func _fade(p: AudioStreamPlayer, to_db: float, seconds: float, stop_after := false) -> void:
	if _fades.has(p) and _fades[p].is_valid():
		_fades[p].kill()
	var tw := create_tween()
	tw.tween_property(p, "volume_db", to_db, seconds)
	if stop_after:
		tw.tween_callback(p.stop)
	_fades[p] = tw


## The WAVs carry their loop point; this only covers a file imported without it.
func _make_loop(stream: AudioStream) -> void:
	if stream is AudioStreamWAV and stream.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
	elif "loop" in stream:
		stream.loop = true
