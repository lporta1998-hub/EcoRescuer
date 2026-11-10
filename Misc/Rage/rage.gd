extends Node
## Rage mode (autoloaded as "Rage"): survive endless rounds of Inquinatori on
## a map already unlocked in the campaign, with a hero you own.
##
##  - Every round spawns more and stronger enemies, a few seconds apart; the
##    round ends when they're all down. Every BOSS_EVERY rounds: a boss (a
##    huge buffed enemy or the Barone's MECCA-RIFIUTI).
##  - The Shop abilities show up as pickups during the match. They work ONLY
##    here: Progress.level_of() asks Rage while a match is on, so the Shop
##    buffs bought for the campaign are not used and these don't leak out.
##    "match" pickups last until game over, "round" ones until the round ends.
##  - Each boss beaten lets the player pick one of 3 PERKS: a permanent bonus
##    for every future Rage match (never the campaign). Perks can be switched
##    off before a match (Progress.rage_perks_off).
## The match itself runs in RageRun, added to the level by LevelManager.

const BOSS_EVERY := 10
const MAX_LEVEL := 5      ## max level of a buff in a match (perk + pickups)
const PERK_MAX := 3       ## max level of each permanent perk

## Pickups: Shop buffs (Progress.BUFFS ids) and how long they last.
const PICKUPS := {
	"extra_heart": {"lasts": "match", "weight": 3},
	"shield": {"lasts": "match", "weight": 2},
	"magnet": {"lasts": "match", "weight": 1},
	"swift": {"lasts": "round", "weight": 2},
	"power": {"lasts": "round", "weight": 2},
}

## Permanent perks. The first five raise the matching Shop buff's starting
## level in Rage; the others exist only here.
const PERKS := {
	"extra_heart": {"title": "Cuore extra", "text": "+1 cuore massimo a inizio partita",
			"icon": "res://Menu/Shop/Icons/heart.png"},
	"swift": {"title": "Scarpe veloci", "text": "Più veloce per tutta la partita",
			"icon": "res://Menu/Shop/Icons/boot.png"},
	"power": {"title": "Colpo potente", "text": "+1 danno e colpi critici",
			"icon": "res://Menu/Shop/Icons/sword.png"},
	"magnet": {"title": "Magnete", "text": "Attira monete e oggetti da più lontano",
			"icon": "res://Menu/Shop/Icons/magnet.png"},
	"shield": {"title": "Scudo", "text": "+1 colpo bloccato a inizio partita",
			"icon": "res://Menu/Shop/Icons/shield.png"},
	"regen": {"title": "Rigenerazione", "text": "Un cuore in più alla fine dei round (ogni 3/2/1 round)",
			"icon": "res://Menu/Shop/Icons/heart.png"},
	"luck": {"title": "Fortuna", "text": "I potenziamenti compaiono più spesso",
			"icon": "res://Menu/Shop/Icons/rush.png"},
	"loot": {"title": "Bottino", "text": "+25% monete alla fine della partita",
			"icon": "res://Collectibles/Assets/Sprites/coin.png"},
}

## Online board of Rage mode.
const BOARD := "rage_mode"

var active := false
## Perks switched on for this match (decided in the Rage menu).
var use_perks := true
## Levels picked up in this match: buff id -> level.
var run_levels := {}


## Maps playable in Rage: campaign levels already unlocked, except the boss
## levels (their arena and sleeping boss belong to the story).
func maps() -> Array[LevelData]:
	var out: Array[LevelData] = []
	for ch in Story.chapters():
		if ch.get("boss", false) or ch.get("epilogue", false):
			continue
		var level: LevelData = load(ch.level)
		if Progress.is_level_unlocked(level):
			out.append(level)
	return out


## Heroes the player owns.
func heroes() -> Array[Pg]:
	var out: Array[Pg] = []
	for pg in ShopMenu.CHARACTERS:
		if Progress.is_unlocked(pg):
			out.append(pg)
	return out


func start(tree: SceneTree, level: LevelData, hero: Pg, with_perks: bool) -> void:
	active = true
	use_perks = with_perks
	run_levels = {}
	Global.selected_character = hero
	Global.character_scene = hero.scene
	Global.selected_level_data = level
	Global.selected_level = level.level_scene
	Global.load_game()


func stop() -> void:
	if not active:
		return
	active = false
	run_levels = {}
	Global.selected_level = null
	Global.selected_level_data = null


## A new match on the same map ("Riprova" after game over).
func reset_run() -> void:
	run_levels = {}


# --- Levels ---------------------------------------------------------------

## Level of a permanent perk this match (0 if perks are off or it's disabled).
func perk(id: String) -> int:
	if not use_perks or Progress.rage_perks_off.has(id):
		return 0
	return int(Progress.rage_perks.get(id, 0))


## What Progress.level_of() returns during a Rage match: perk + pickups for
## the player's buffs, nothing for the Sfide (Rage has its own scaling).
func buff_level(id: String) -> int:
	if Progress.BUFFS[id].kind != "player":
		return 0
	return mini(MAX_LEVEL, perk(id) + int(run_levels.get(id, 0)))


## Perks that can still be raised, for the choice after a boss.
func perk_choices(count: int) -> Array:
	var ids := []
	for id in PERKS:
		if int(Progress.rage_perks.get(id, 0)) < PERK_MAX:
			ids.append(id)
	ids.shuffle()
	return ids.slice(0, count)
