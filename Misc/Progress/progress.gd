extends Node
## Player progress that survives between sessions (autoloaded as "Progress"):
## the coin wallet, which characters have been bought, and the best star
## rating of every level (stars unlock the next levels).
##
## Coins come from the collectibles picked up in a level (their `points`):
## all of them when the level is completed, half on game over.
## Characters are bought in the Shop; a character whose Pg.price is 0 is free.

signal coins_changed(total: int)
signal character_unlocked(character_id: String)
signal stars_changed(total: int)

const MAX_STARS_PER_LEVEL := 3

## Shop buffs. Each one can be bought up to MAX_BUFF_LEVEL times: every
## purchase raises its level and makes it stronger. Bought buffs can be
## switched on/off in the Shop.
## "player" buffs make the game easier; "enemy" ones (Sfide) make it harder and
## raise the coins earned by `reward` per level (0.10 = +10% per level).
## `per_level` is the size of one level of the effect (see effect_text()).
const MAX_BUFF_LEVEL := 5
const BUFFS := {
	"extra_heart": {"kind": "player", "title": "Cuore extra", "per_level": 1,
		"prices": [300, 450, 650, 900, 1200], "icon": "res://Menu/Shop/Icons/heart.png"},
	"swift": {"kind": "player", "title": "Scarpe veloci", "per_level": 0.12,
		"prices": [250, 375, 550, 800, 1100], "icon": "res://Menu/Shop/Icons/boot.png"},
	"power": {"kind": "player", "title": "Colpo potente", "per_level": 0.15,
		"prices": [500, 650, 850, 1100, 1400], "icon": "res://Menu/Shop/Icons/sword.png"},
	"magnet": {"kind": "player", "title": "Magnete", "per_level": 50.0,
		"prices": [350, 500, 700, 950, 1250], "icon": "res://Menu/Shop/Icons/magnet.png"},
	"shield": {"kind": "player", "title": "Scudo", "per_level": 1,
		"prices": [400, 550, 750, 1000, 1300], "icon": "res://Menu/Shop/Icons/shield.png"},
	"armored": {"kind": "enemy", "title": "Nemici corazzati", "per_level": 0.20, "reward": 0.10,
		"prices": [100, 150, 200, 250, 300], "icon": "res://Menu/Shop/Icons/armor.png"},
	"rapid": {"kind": "enemy", "title": "Nemici rapidi", "per_level": 0.08, "reward": 0.08,
		"prices": [100, 150, 200, 250, 300], "icon": "res://Menu/Shop/Icons/bolt.png"},
	"heavy": {"kind": "enemy", "title": "Colpi pesanti", "per_level": 0.20, "reward": 0.10,
		"prices": [100, 150, 200, 250, 300], "icon": "res://Menu/Shop/Icons/fist.png"},
	"no_heal": {"kind": "enemy", "title": "Senza cure", "per_level": 0.20, "reward": 0.06,
		"prices": [100, 150, 200, 250, 300], "icon": "res://Menu/Shop/Icons/broken_heart.png"},
}
## Magnet range at level 0 (+ per_level for every level).
const MAGNET_BASE_RADIUS := 80.0

const SAVE_PATH := "user://progress.cfg"
## Share of the collected coins kept when the player dies.
const GAME_OVER_SHARE := 0.5

var coins := 0
## Name typed on the first Start; also used for the online leaderboard.
var player_name := ""
var _unlocked: Array[String] = []
var _stars := {}                 # level id -> best stars (0..3)
var _seen_levels: Array[String] = []  # unlocked levels the player has already seen in the menu
var _buff_levels := {}            # buff id -> bought level (0..MAX_BUFF_LEVEL)
var _active_buffs: Array[String] = []
## True once the story intro has been shown (it plays after the first Start).
var intro_seen := false
## Side quests done: level id -> {"dossier": bool, "quest": bool}.
var _quests := {}


func _ready() -> void:
	load_progress()


## Stable id of a character, taken from its resource file name ("Ranger").
func character_id(character: Pg) -> String:
	return character.resource_path.get_file().get_basename()


func is_unlocked(character: Pg) -> bool:
	if character == null:
		return false
	return character.price <= 0 or _unlocked.has(character_id(character))


func can_afford(price: int) -> bool:
	return coins >= price


## Spends the character's price and unlocks it. Returns false if the player
## can't afford it (nothing changes in that case).
func buy_character(character: Pg) -> bool:
	if is_unlocked(character):
		return true
	if not can_afford(character.price):
		return false
	coins -= character.price
	_unlocked.append(character_id(character))
	save_progress()
	coins_changed.emit(coins)
	character_unlocked.emit(character_id(character))
	return true


func add_coins(amount: int) -> void:
	if amount <= 0:
		return
	coins += amount
	save_progress()
	coins_changed.emit(coins)


## Coins earned for a finished run: everything collected on completion,
## half of it on game over, then the bonus of the active Sfide.
func coins_for_run(collected_points: int, completed: bool) -> int:
	var base := float(collected_points) if completed else collected_points * GAME_OVER_SHARE
	return int(floor(base * coin_multiplier()))


# --- Buffs ---------------------------------------------------------------

func buff_ids(kind: String) -> Array[String]:
	var ids: Array[String] = []
	for id in BUFFS:
		if BUFFS[id].kind == kind:
			ids.append(id)
	return ids


func owns_buff(id: String) -> bool:
	return buff_level(id) > 0


## Level bought in the Shop (0 = not bought), whether switched on or not.
func buff_level(id: String) -> int:
	return int(_buff_levels.get(id, 0))


## Level the game should use: the bought level if the buff is switched on,
## otherwise 0. This is what gameplay code checks.
func level_of(id: String) -> int:
	return buff_level(id) if _active_buffs.has(id) else 0


## True if the buff is owned and switched on.
func is_active(id: String) -> bool:
	return level_of(id) > 0


func is_max_level(id: String) -> bool:
	return buff_level(id) >= MAX_BUFF_LEVEL


## Price of the next level, or -1 when the buff is already at max level.
func next_price(id: String) -> int:
	var lvl := buff_level(id)
	if lvl >= MAX_BUFF_LEVEL:
		return -1
	return int(BUFFS[id].prices[lvl])


## The size of the effect at `level`, as numbers the game uses.
func buff_value(id: String, level: int) -> float:
	return float(BUFFS[id].per_level) * level


## Human-readable effect of `id` at `level` (for the Shop).
func effect_text(id: String, level: int) -> String:
	var pct := func(v: float) -> String: return "%d%%" % roundi(v * 100.0)
	match id:
		"extra_heart":
			return "+1 cuore massimo" if level == 1 else "+%d cuori massimi" % level
		"swift":
			return "+%s velocità" % pct.call(buff_value(id, level))
		"power":
			if level <= 1:
				return "+1 danno a ogni colpo"
			return "+1 danno, %s di colpo critico (x2)" % pct.call(buff_value(id, level - 1))
		"magnet":
			return "attira gli oggetti entro %d px" % roundi(MAGNET_BASE_RADIUS + buff_value(id, level))
		"shield":
			return "blocca il primo colpo di ogni partita" if level == 1 \
					else "blocca i primi %d colpi di ogni partita" % level
		"armored":
			return "nemici con +%s di vita" % pct.call(buff_value(id, level))
		"rapid":
			return "nemici +%s veloci" % pct.call(buff_value(id, level))
		"heavy":
			if level >= MAX_BUFF_LEVEL:
				return "ogni colpo nemico toglie 2 cuori"
			return "%s dei colpi nemici toglie 2 cuori" % pct.call(buff_value(id, level))
		"no_heal":
			if level >= MAX_BUFF_LEVEL:
				return "nessun cuore a terra"
			return "sparisce il %s dei cuori a terra" % pct.call(buff_value(id, level))
	return ""


## Coin bonus of a Sfida at `level` (0.3 = +30%).
func reward_at(id: String, level: int) -> float:
	return float(BUFFS[id].get("reward", 0.0)) * level


## Buys the next level of a buff and switches it on.
## Returns false if it's already maxed or the player can't afford it.
func buy_buff(id: String) -> bool:
	var price := next_price(id)
	if price < 0 or not can_afford(price):
		return false
	coins -= price
	_buff_levels[id] = buff_level(id) + 1
	if not _active_buffs.has(id):
		_active_buffs.append(id)
	save_progress()
	coins_changed.emit(coins)
	return true


func set_buff_active(id: String, on: bool) -> void:
	if not owns_buff(id):
		return
	if on and not _active_buffs.has(id):
		_active_buffs.append(id)
	elif not on:
		_active_buffs.erase(id)
	save_progress()


## Active buffs as [[id, level], ...] in Shop order (for the in-game HUD).
func active_buffs() -> Array:
	var out := []
	for id in BUFFS:
		if level_of(id) > 0:
			out.append([id, level_of(id)])
	return out


## 1.0 + the reward of every active enemy buff (Sfida), times its level.
func coin_multiplier() -> float:
	var m := 1.0
	for id in BUFFS:
		m += reward_at(id, level_of(id))
	return m


# --- Stars & level unlocks ---------------------------------------------

## Stable id of a level, taken from its resource file name ("Forest").
func level_id(level: LevelData) -> String:
	return level.resource_path.get_file().get_basename()


func get_stars(level: LevelData) -> int:
	return int(_stars.get(level_id(level), 0))


func total_stars() -> int:
	var total := 0
	for v in _stars.values():
		total += int(v)
	return total


## Keeps the best result. Returns true if this run beat the previous best.
func record_stars(level: LevelData, stars: int) -> bool:
	stars = clampi(stars, 0, MAX_STARS_PER_LEVEL)
	if stars <= get_stars(level):
		return false
	_stars[level_id(level)] = stars
	save_progress()
	stars_changed.emit(total_stars())
	return true


## Campaign unlocking: a level opens when the previous one has been completed
## (any star). The old star thresholds still unlock it too.
func is_level_unlocked(level: LevelData) -> bool:
	var prev: LevelData = Story.previous_level(level)
	if prev == null:
		return Story.chapter_index(level) == 0 or total_stars() >= level.stars_required
	return get_stars(prev) > 0 or total_stars() >= level.stars_required


func is_level_completed(level: LevelData) -> bool:
	return get_stars(level) > 0


# --- Side quests -------------------------------------------------------------

func quest_done(level: LevelData, kind: String) -> bool:
	return bool(_quests.get(level_id(level), {}).get(kind, false))


## Records a finished side quest. Returns true the first time (pay the reward).
func record_quest(level: LevelData, kind: String) -> bool:
	if quest_done(level, kind):
		return false
	var id := level_id(level)
	var q: Dictionary = _quests.get(id, {})
	q[kind] = true
	_quests[id] = q
	save_progress()
	return true


func dossiers_found() -> int:
	var n := 0
	for id in _quests:
		if _quests[id].get("dossier", false):
			n += 1
	return n


func mark_intro_seen() -> void:
	intro_seen = true
	save_progress()


## True the first time an unlocked level (one that needed stars) is shown.
func is_new_unlock(level: LevelData) -> bool:
	return level.stars_required > 0 and is_level_unlocked(level) \
			and not _seen_levels.has(level_id(level))


func mark_level_seen(level: LevelData) -> void:
	if not _seen_levels.has(level_id(level)):
		_seen_levels.append(level_id(level))
		save_progress()


func set_player_name(new_name: String) -> void:
	player_name = new_name
	Global.player_name = new_name
	save_progress()


func save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("player", "name", player_name)
	cfg.set_value("wallet", "coins", coins)
	cfg.set_value("characters", "unlocked", _unlocked)
	cfg.set_value("levels", "stars", _stars)
	cfg.set_value("levels", "seen", _seen_levels)
	cfg.set_value("buffs", "levels", _buff_levels)
	cfg.set_value("buffs", "active", _active_buffs)
	cfg.set_value("story", "intro_seen", intro_seen)
	cfg.set_value("story", "quests", _quests)
	var err := cfg.save(SAVE_PATH)
	if err != OK:
		push_warning("Progress: could not save (%d)" % err)


func load_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return  # first launch
	coins = int(cfg.get_value("wallet", "coins", 0))
	player_name = str(cfg.get_value("player", "name", ""))
	if player_name != "":
		Global.player_name = player_name
	_unlocked.clear()
	for id in cfg.get_value("characters", "unlocked", []):
		_unlocked.append(str(id))
	_stars = cfg.get_value("levels", "stars", {})
	_seen_levels.clear()
	for id in cfg.get_value("levels", "seen", []):
		_seen_levels.append(str(id))
	intro_seen = bool(cfg.get_value("story", "intro_seen", false))
	var q = cfg.get_value("story", "quests", {})
	_quests = q if q is Dictionary else {}
	_buff_levels.clear()
	_active_buffs.clear()
	var levels = cfg.get_value("buffs", "levels", {})
	if levels is Dictionary:
		for id in levels:
			if BUFFS.has(str(id)):
				_buff_levels[str(id)] = clampi(int(levels[id]), 0, MAX_BUFF_LEVEL)
	# Saves from before buff levels: every owned buff becomes level 1.
	for id in cfg.get_value("buffs", "owned", []):
		if BUFFS.has(str(id)) and buff_level(str(id)) == 0:
			_buff_levels[str(id)] = 1
	for id in cfg.get_value("buffs", "active", []):
		if owns_buff(str(id)):
			_active_buffs.append(str(id))
