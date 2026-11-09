extends Node
## Sfida del giorno (autoloaded as "Daily"): every day (UTC) everyone gets the
## same level with the same Sfide switched on, and their own online board.
##
## While a daily run is `active`:
##  - Progress.level_of() uses today's Sfide and switches the player's Shop
##    buffs off, so the scores on the board are comparable;
##  - stars, level records and side quests are not touched (LevelManager);
##  - finishing it the first time each day pays REWARD coins.
## Going back to the main menu or the level menu ends daily mode.

const REWARD := 200
## How many Sfide are switched on, and their level range.
const MIN_SFIDE := 2
const MAX_SFIDE := 3
const MAX_SFIDA_LEVEL := 3

var active := false

var _date := ""
var _today := {}


## Today's date in UTC, "YYYY-MM-DD".
func date() -> String:
	return Time.get_date_string_from_system(true)


## Online board of today's challenge.
func board_id() -> String:
	return "daily_" + date().replace("-", "")


## {"date", "level": LevelData, "sfide": {buff id: level}}, the same for every
## player on the same day.
func today() -> Dictionary:
	var d := date()
	if d == _date and not _today.is_empty():
		return _today
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("eco-daily-" + d)
	# any main-campaign level except the boss fight
	var pool := []
	for ch in Story.main_chapters():
		if not ch.get("boss", false):
			pool.append(ch.level)
	var level: LevelData = load(pool[rng.randi_range(0, pool.size() - 1)])
	var ids: Array = Progress.buff_ids("enemy")
	var sfide := {}
	var count := rng.randi_range(MIN_SFIDE, mini(MAX_SFIDE, ids.size()))
	while sfide.size() < count:
		var id: String = ids[rng.randi_range(0, ids.size() - 1)]
		if not sfide.has(id):
			sfide[id] = rng.randi_range(1, MAX_SFIDA_LEVEL)
	_date = d
	_today = {"date": d, "level": level, "sfide": sfide}
	return _today


## Level of buff `id` during a daily run.
func buff_level(id: String) -> int:
	if Progress.BUFFS[id].kind != "enemy":
		return 0
	return int(today().sfide.get(id, 0))


## "Nemici corazzati 2 · Senza cure 1"
func sfide_text() -> String:
	var parts := []
	for id in Progress.BUFFS:
		var lvl: int = today().sfide.get(id, 0)
		if lvl > 0:
			parts.append("%s %d" % [Progress.BUFFS[id].title, lvl])
	return "  ·  ".join(parts)


func done_today() -> bool:
	return Progress.daily_last_done == date()


## Picks today's level and goes to character select; the level starts from
## there (menu_selezione.gd).
func start(tree: SceneTree) -> void:
	var t := today()
	active = true
	Global.selected_level_data = t.level
	Global.selected_level = t.level.level_scene
	tree.change_scene_to_file("res://SelezionePg/Scenes/menu_selezione.tscn")


func stop() -> void:
	if not active:
		return
	active = false
	Global.selected_level = null
	Global.selected_level_data = null


## Called by LevelManager when a daily run is completed. Returns the coins of
## the daily reward (0 if it was already paid today).
func on_completed() -> int:
	Progress.add_stat("daily_played")
	if done_today():
		return 0
	Progress.daily_last_done = date()
	Progress.add_stat("daily_done")
	Progress.add_coins(REWARD)
	return REWARD
