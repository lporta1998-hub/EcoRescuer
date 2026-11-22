extends Node
## Game language (autoloaded as "Lang", first so every other script already
## sees the right locale).
##
## The game is written in Italian: the Italian text IS the translation key.
## The other languages come from Localization/<code>.po (en, es, pt, el)
## (gettext files: edit them with any PO editor, e.g. Poedit). Labels and
## Buttons translate their text by themselves; text built in code goes
## through tr() (or Lang.t() in static functions).
##
## By default the game follows the phone's language (Italian, English,
## Spanish, Portuguese or Greek; any other language gets English). Picking a language in the main
## menu's flag list overrides it; picking "Automatico" goes back to the
## phone's language. The choice is saved in user://language.cfg.

signal changed

const SAVE_PATH := "user://language.cfg"
const LANGUAGES := ["it", "en", "es", "pt", "el"]
## Shown in the language list, each in its own language.
const NAMES := {"it": "Italiano", "en": "English", "es": "Español", "pt": "Português", "el": "Ελληνικά"}

var current := "it"
## True while the game follows the phone's language.
var automatic := true


func _enter_tree() -> void:
	var saved := ""
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		saved = String(cfg.get_value("general", "language", ""))
	automatic = not saved in LANGUAGES
	apply(device_language() if automatic else saved, false)


## The phone's language if the game has it, otherwise English.
func device_language() -> String:
	var lang := OS.get_locale_language()
	return lang if lang in LANGUAGES else "en"


## Switches the language. With `save`, it becomes the player's choice
## (no longer automatic) and is remembered.
func apply(code: String, save := true) -> void:
	if not code in LANGUAGES:
		code = "en"
	current = code
	TranslationServer.set_locale(code)
	if save:
		automatic = false
		_save(code)
	changed.emit()


## Back to following the phone's language.
func use_device_language() -> void:
	automatic = true
	_save("auto")
	apply(device_language(), false)


func _save(value: String) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("general", "language", value)
	cfg.save(SAVE_PATH)


## tr() for static functions and other places without an Object at hand.
func t(text: String) -> String:
	return String(TranslationServer.translate(text))
