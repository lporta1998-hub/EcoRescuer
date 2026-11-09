extends "res://Boss/fortress_level.gd"
## Chapter 10, the epilogue: "La fuga del Barone". After the fortress the
## Barone ran to the docks with what's left of his MECCA-RIFIUTI and waits for
## a ship. Same flow as the fortress (objective -> arena gate -> boss), at
## night, against a damaged suit that throws barrels from the start.

const NIGHT := Color(0.58, 0.62, 0.86)


func _init() -> void:
	intro_lines = [
		["Ancora voi?! La nave arriva tra pochi minuti...", 2.6],
		["Il mio MECCA-RIFIUTI è ammaccato, ma basta per voi!", 2.8],
	]
	boss_overrides = {"boss_health": 32.0, "start_phase": 2, "walk_speed": 62.0}
	defeat_text = "Il Barone è a terra! Niente nave per lui stanotte."


func build() -> void:
	super()
	var night := CanvasModulate.new()
	night.name = "Night"
	night.color = NIGHT
	add_child(night)
