class_name Training
extends RefCounted
## The interactive tutorial ("Allenamento"): a short practice level where a
## coach teaches one thing at a time by having the player do it (move, pick
## up a trash bag, attack, use the special move, reach the recycling station).
##
## Brand-new players play it the first time they press Start; "Come si gioca"
## in the main menu plays it again. While it runs, LevelManager hands the
## recycling station and the hero's death over to the level (see
## LevelManager.try_finish_level / show_game_over_menu).

const SAVE_PATH := "user://training.cfg"
const LEVEL := "res://Levels/Training/training.tscn"
const HERO := "res://Resources/Characters/Labra.tres"

## True while the practice level is being played.
static var active := false
## After the first training, the main menu goes on with what Start does
## (story intro, then the hero choice) instead of waiting for another tap.
static var resume_start := false


## True once the player has finished the training at least once.
static func done() -> bool:
	var cfg := ConfigFile.new()
	return cfg.load(SAVE_PATH) == OK and bool(cfg.get_value("general", "done", false))


static func start(first_time := false) -> void:
	active = true
	resume_start = first_time
	Daily.stop()
	Rage.stop()
	var hero: Pg = load(HERO)
	Global.selected_character = hero
	Global.character_scene = hero.scene
	Global.selected_level_data = null
	Global.selected_level = load(LEVEL)
	Global.load_game()


## Back to the main menu (the training was completed or left from the pause menu).
static func finish(tree: SceneTree, completed: bool) -> void:
	active = false
	if completed:
		var cfg := ConfigFile.new()
		cfg.load(SAVE_PATH)
		cfg.set_value("general", "done", true)
		cfg.save(SAVE_PATH)
	else:
		resume_start = false
	Global.selected_level = null
	tree.paused = false
	tree.change_scene_to_file("res://main_menu.tscn")
