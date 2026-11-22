extends Node
## Game language (autoloaded as "Lang", first so every other script already
## sees the right locale).
##
## The game is written in Italian: the Italian text IS the translation key.
## English and Greek come from Localization/en.po and Localization/el.po
## (gettext files: edit them with any PO editor, e.g. Poedit). Labels and
## Buttons translate their text by themselves; text built in code goes
## through tr() (or Lang.t() in static functions).
##
## The first launch picks the device language (Italian, English or Greek;
## any other language gets English). The choice made in the main menu is
## saved in user://language.cfg.

signal changed

const SAVE_PATH := "user://language.cfg"
const LANGUAGES := ["it", "en", "el"]
## Shown on the language button, each in its own language.
const NAMES := {"it": "Italiano", "en": "English", "el": "Ελληνικά"}

var current := "it"


func _enter_tree() -> void:
	var saved := ""
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		saved = String(cfg.get_value("general", "language", ""))
	apply(saved if saved in LANGUAGES else _device_language(), false)


func _device_language() -> String:
	var lang := OS.get_locale_language()
	return lang if lang in LANGUAGES else "en"


## Switches the language (and remembers it when `save` is true).
func apply(code: String, save := true) -> void:
	if not code in LANGUAGES:
		code = "en"
	current = code
	TranslationServer.set_locale(code)
	if save:
		var cfg := ConfigFile.new()
		cfg.set_value("general", "language", code)
		cfg.save(SAVE_PATH)
	changed.emit()


## The language after the current one (for the menu's language button).
func next() -> String:
	return LANGUAGES[(LANGUAGES.find(current) + 1) % LANGUAGES.size()]


## tr() for static functions and other places without an Object at hand.
func t(text: String) -> String:
	return String(TranslationServer.translate(text))
