class_name Achievements
extends RefCounted
## The achievement list. Each one is unlocked once, for good, the first time
## its `source` value reaches `target` (Progress.check_achievements, run at
## the end of every level), and pays `reward` Shop coins.
##
## Sources:
##   "stat:<key>"    a lifetime counter in Progress (kills, bags, ...)
##   "stars"         total stars
##   "dossiers"      secret dossiers found (main chapters)
##   "quests"        gameplay side quests completed (main chapters)
##   "heroes_won"    different characters that have finished a level
##   "heroes_owned"  characters unlocked
##   "epilogue"      1 once the epilogue chapter is completed

const LIST := [
	{"id": "first_clean", "title": "Prima pulizia", "text": "Completa il tuo primo livello",
		"source": "stat:runs_completed", "target": 1, "reward": 50},
	{"id": "kills_100", "title": "Spazzino", "text": "Sconfiggi 100 Inquinatori",
		"source": "stat:kills", "target": 100, "reward": 100},
	{"id": "kills_500", "title": "Incubo degli Inquinatori", "text": "Sconfiggi 500 Inquinatori",
		"source": "stat:kills", "target": 500, "reward": 300},
	{"id": "elites_20", "title": "Caccia ai capi", "text": "Sconfiggi 20 Elite",
		"source": "stat:elites", "target": 20, "reward": 150},
	{"id": "bags_100", "title": "Sacchi pieni", "text": "Raccogli 100 sacchi di rifiuti",
		"source": "stat:bags", "target": 100, "reward": 100},
	{"id": "barrels_25", "title": "Niente perdite", "text": "Metti in sicurezza 25 barili",
		"source": "stat:barrels", "target": 25, "reward": 100},
	{"id": "chests_15", "title": "Cacciatore di tesori", "text": "Apri 15 forzieri",
		"source": "stat:chests", "target": 15, "reward": 100},
	{"id": "flawless", "title": "Intoccabile", "text": "Completa un livello senza subire danni",
		"source": "stat:flawless", "target": 1, "reward": 100},
	{"id": "hard_win", "title": "Senza paura", "text": "Completa un livello con 3 Sfide attive",
		"source": "stat:hard_wins", "target": 1, "reward": 200},
	{"id": "stars_14", "title": "Stelle nascenti", "text": "Ottieni 14 stelle",
		"source": "stars", "target": 14, "reward": 100},
	{"id": "stars_all", "title": "Cielo pieno", "text": "Ottieni 3 stelle in tutti i livelli della campagna",
		"source": "stars", "target": -1, "reward": 500},
	{"id": "dossier_1", "title": "Prima prova", "text": "Trova un dossier segreto",
		"source": "dossiers", "target": 1, "reward": 50},
	{"id": "dossier_all", "title": "Prove schiaccianti", "text": "Trova tutti i dossier segreti",
		"source": "dossiers", "target": -1, "reward": 400},
	{"id": "quests_all", "title": "Missioni compiute", "text": "Completa tutte le missioni secondarie",
		"source": "quests", "target": -1, "reward": 300},
	{"id": "baron", "title": "Abbasso il Barone", "text": "Distruggi il MECCA-RIFIUTI",
		"source": "stat:boss_kills", "target": 1, "reward": 300},
	{"id": "epilogue", "title": "Fine della fuga", "text": "Completa il capitolo \"La fuga del Barone\"",
		"source": "epilogue", "target": 1, "reward": 300},
	{"id": "team_5", "title": "Squadra al completo", "text": "Completa un livello con 5 eroi diversi",
		"source": "heroes_won", "target": 5, "reward": 200},
	{"id": "all_heroes", "title": "Collezionista", "text": "Sblocca tutti gli eroi",
		"source": "heroes_owned", "target": -1, "reward": 200},
	{"id": "rage_10", "title": "Furia", "text": "Supera 10 round in Rage mode",
		"source": "stat:rage_best_round", "target": 10, "reward": 200},
	{"id": "rage_30", "title": "Inarrestabile", "text": "Supera 30 round in Rage mode",
		"source": "stat:rage_best_round", "target": 30, "reward": 500},
	{"id": "daily_1", "title": "Sfida accettata", "text": "Completa una Sfida del giorno",
		"source": "stat:daily_done", "target": 1, "reward": 50},
	{"id": "daily_7", "title": "Abitudine verde", "text": "Completa 7 Sfide del giorno",
		"source": "stat:daily_done", "target": 7, "reward": 300},
]


static func find(id: String) -> Dictionary:
	for a in LIST:
		if a.id == id:
			return a
	return {}


## Target of `a`; -1 in the list means "all of them" (worked out here).
static func target_of(a: Dictionary) -> int:
	if int(a.target) >= 0:
		return int(a.target)
	match a.source:
		"stars":
			return Story.main_chapters().size() * Progress.MAX_STARS_PER_LEVEL
		"dossiers", "quests":
			return Story.main_chapters().size()
		"heroes_owned":
			return ShopMenu.CHARACTERS.size()
	return 1


## Current value of `a`'s source.
static func value_of(a: Dictionary) -> int:
	var source: String = a.source
	if source.begins_with("stat:"):
		return Progress.stat(source.substr(5))
	match source:
		"stars":
			return Progress.campaign_stars()
		"dossiers":
			return Progress.dossiers_found()
		"quests":
			return Progress.quests_found()
		"heroes_won":
			return Progress.heroes_won()
		"heroes_owned":
			var n := 0
			for c in ShopMenu.CHARACTERS:
				if Progress.is_unlocked(c):
					n += 1
			return n
		"epilogue":
			for ch in Story.chapters():
				if ch.get("epilogue", false) and Progress.is_level_completed(load(ch.level)):
					return 1
			return 0
	return 0
