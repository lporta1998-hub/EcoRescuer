class_name SideQuests
extends RefCounted
## The two side quests of the current level (see Story): the secret dossier
## and one gameplay quest. LevelManager forwards events here; the HUD shows
## `summary()`. Rewards are paid only the first time a quest is completed.

var level: LevelData
var chapter: Dictionary
var kind := ""          # gameplay quest type (Story.QUEST_TYPES)
var text := ""
var target := 0
var progress := 0
var quest_done := false
var quest_failed := false
var dossier_found := false
var bonus_coins := 0    # rewards earned in this run
var results: Array = [] # [[label, done, reward], ...] for the end menu


func _init(level_data: LevelData, level_node: Node) -> void:
	level = level_data
	chapter = Story.chapter_of(level_data)
	var q: Dictionary = chapter.get("quest", {})
	kind = q.get("type", "")
	text = q.get("text", "")
	target = int(q.get("target", 0))
	match kind:
		"barrels":
			target = level_node.find_children("*", "OilBarrel", true, false).size()
		"chests":
			target = level_node.find_children("*", "EcoChest", true, false).size()
		"elites":
			target = 0
			for e in level_node.find_children("*", "CharacterBody2D", true, false):
				if e is Elite:
					target += 1
		"coins":
			target = 0
			for c in level_node.find_children("*", "Collectible", true, false):
				if c.has_method("is_eco_coin"):
					target += 1
	# A level without what the quest needs gets "no damage" instead.
	if kind in ["barrels", "chests", "elites", "coins"] and target <= 0:
		kind = "nodamage"
		text = "Completa il livello senza subire danni"


func is_active() -> bool:
	return not chapter.is_empty()


## Short HUD line: "Dossier 0/1 · Barili 1/3".
func summary(elapsed_seconds: float) -> String:
	if not is_active():
		return ""
	var parts := ["Dossier %d/1" % (1 if dossier_found else 0)]
	match kind:
		"barrels":
			parts.append("Barili %d/%d" % [progress, target])
		"chests":
			parts.append("Forzieri %d/%d" % [progress, target])
		"elites":
			parts.append("Elite %d/%d" % [progress, target])
		"coins":
			parts.append("Monete %d/%d" % [progress, target])
		"time":
			var left := maxi(0, target - int(elapsed_seconds))
			parts.append("Tempo %d:%02d" % [left / 60, left % 60] if not quest_failed else "Tempo scaduto")
		"nodamage":
			parts.append("Senza danni" + (": fallita" if quest_failed else ""))
	if quest_done:
		parts[1] += " OK"
	return "  ·  ".join(parts)


## Something happened in the level: "barrel", "chest", "elite", "coin".
## Returns a message when the quest has just been completed.
func on_event(event: String) -> String:
	if quest_done or quest_failed:
		return ""
	var counts := {"barrels": "barrel", "chests": "chest", "elites": "elite", "coins": "coin"}
	if counts.get(kind, "") != event:
		return ""
	progress += 1
	if progress >= target:
		return _complete_quest()
	return ""


func on_damage() -> void:
	if kind == "nodamage" and not quest_done:
		quest_failed = true


func on_time(elapsed_seconds: float) -> void:
	if kind == "time" and not quest_done and elapsed_seconds > target:
		quest_failed = true


func on_dossier() -> String:
	if dossier_found:
		return ""
	dossier_found = true
	var first := Progress.record_quest(level, "dossier")
	if first:
		bonus_coins += Story.DOSSIER_REWARD
	return "Dossier segreto trovato!" + (" +%d monete" % Story.DOSSIER_REWARD if first else "")


## End of the level: quests checked at the finish line.
func on_level_finished(elapsed_seconds: float) -> void:
	if not quest_done and not quest_failed and kind in ["time", "nodamage"]:
		if kind == "time" and elapsed_seconds > target:
			quest_failed = true
		else:
			_complete_quest()
	results = [["Dossier segreto", dossier_found, Story.DOSSIER_REWARD], [text, quest_done, Story.QUEST_REWARD]]


func _complete_quest() -> String:
	quest_done = true
	var first := Progress.record_quest(level, "quest")
	if first:
		bonus_coins += Story.QUEST_REWARD
	return "Missione completata!" + (" +%d monete" % Story.QUEST_REWARD if first else "")
