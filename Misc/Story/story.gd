extends Node
## The campaign: level order, the story told before each level, and each
## level's side quests (autoloaded as "Story").
##
## The story: the island was green until the Inquinatori gang started dumping
## waste everywhere, covered by corrupt politicians. Behind them is NEXUS, an
## AI built to maximise profit that decided pollution is the cheapest way.
## The EcoRescuer team cleans each area and follows the trail to the fortress
## of the Barone dei Rifiuti, who guards NEXUS's core.
##
## Every level has two side quests:
##  - "dossier": a secret Inquinatori file hidden somewhere in the level
##    (placed automatically on a far, reachable spot unless the level has a
##    Dossier node). Collecting all of them unlocks the true ending.
##  - one gameplay quest (see QUEST_TYPES).

const DOSSIER_REWARD := 100
const QUEST_REWARD := 150

## Quest types: "barrels" secure every leaking barrel, "chests" open every eco
## chest, "elites" defeat every Elite, "coins" pick up every coin, "time"
## finish within `target` seconds, "nodamage" finish without being hit.
const QUEST_TYPES := ["barrels", "chests", "elites", "coins", "time", "nodamage"]

## The new enemy types. In each chapter, `enemies` says how many of the
## level's basic Inquinatori are swapped for each type (LevelManager does it
## when the level starts); the first level a type appears in mentions it in
## the briefing.
const ENEMIES := {
	"sprayer": {"scene": "res://Enemies/Sprayer/sprayer.tscn", "name": "Spruzzatore",
			"tip": "lancia fanghi tossici da lontano: avvicinati mentre prende la mira."},
	"bomber": {"scene": "res://Enemies/Bomber/bomber.tscn", "name": "Kamikaze",
			"tip": "corre verso di te con un barile che esplode: colpiscilo prima o allontanati quando lampeggia."},
	"brute": {"scene": "res://Enemies/Brute/brute.tscn", "name": "Bruto",
			"tip": "carica in linea retta: schivalo e fallo sbattere contro un muro, resterà stordito."},
	"drone": {"scene": "res://Enemies/Drone/drone.tscn", "name": "Drone NEXUS",
			"tip": "vola sopra muri e acqua e spara laser: colpiscilo da lontano o respingi i suoi colpi."},
}

## Campaign order. `level` is the LevelData resource; the rest is story.
const CHAPTERS := [
	{
		"level": "res://Resources/Levels/Forest.tres",
		"music": "forest",
		"enemies": {"sprayer": 2},
		"title": "Il primo segnale",
		"text": "Nella foresta dell'isola sono comparsi sacchi di rifiuti tossici, scaricati di notte. Le tracce portano agli Inquinatori. Ripulisci il bosco e scopri chi li manda.",
		"dossier": "Ordine di scarico n. 1: \"Bosco nord, tre carichi a settimana. Pagamento garantito.\" Firmato: N.",
		"quest": {"type": "barrels", "text": "Metti in sicurezza tutti i barili che perdono"},
	},
	{
		"level": "res://Resources/Levels/SnowPath.tres",
		"music": "snow",
		"enemies": {"sprayer": 2, "bomber": 2},
		"title": "Cristalli spenti",
		"text": "Sul sentiero innevato i cristalli che illuminavano le grotte si stanno spegnendo sotto le scorie. Gli Inquinatori usano le grotte come deposito.",
		"dossier": "Rapporto interno: \"Le grotte sono perfette, nessuno controlla. N. approva l'espansione.\"",
		"quest": {"type": "chests", "text": "Apri tutti i forzieri nelle grotte"},
	},
	{
		"level": "res://Resources/Levels/City.tres",
		"music": "city",
		"enemies": {"sprayer": 3, "bomber": 2, "brute": 1},
		"title": "La città comprata",
		"text": "In città nessuno ferma gli Inquinatori: politici e funzionari sono stati pagati. Riprendi le strade e trova le prove della corruzione.",
		"dossier": "Lista pagamenti: assessori, ispettori, un giudice. In fondo: \"Calcolato da NEXUS: corrompere costa meno che smaltire.\"",
		"quest": {"type": "elites", "text": "Sconfiggi i capisquadra (Elite) degli Inquinatori"},
	},
	{
		"level": "res://Resources/Levels/BeachLevel.tres",
		"music": "lake",
		"enemies": {"sprayer": 2, "bomber": 2, "brute": 1},
		"title": "Il lago dimenticato",
		"text": "Il grande lago è diventato una discarica a cielo aperto. Il furgone degli Inquinatori fa ancora la spola dal complesso sulla riva.",
		"dossier": "Messaggio di NEXUS: \"Profitto massimo raggiunto. Ridurre i costi: aumentare gli scarichi del 40%.\"",
		"quest": {"type": "coins", "text": "Raccogli tutte le monete del lago"},
	},
	{
		"level": "res://Resources/Levels/Ruins.tres",
		"music": "ruins",
		"enemies": {"sprayer": 2, "bomber": 2, "brute": 2},
		"title": "Le rovine antiche",
		"text": "Tra le rovine di un'antica città dell'isola gli Inquinatori hanno nascosto dei server di NEXUS. Le pietre ricordano un tempo in cui l'isola era pulita.",
		"dossier": "Mappa dei server: \"Nodo rovine, nodo fabbrica, nodo porto. Il nucleo è nella fortezza del Barone.\"",
		"quest": {"type": "time", "target": 240, "text": "Completa il livello in meno di 4 minuti"},
	},
	{
		"level": "res://Resources/Levels/Factory.tres",
		"music": "factory",
		"enemies": {"sprayer": 2, "bomber": 2, "brute": 1, "drone": 2},
		"title": "La fabbrica tossica",
		"text": "Ecco da dove arrivano i veleni: una fabbrica che non produce nulla, solo scorie. Fermala prima che le vasche traboccino.",
		"dossier": "Registro della fabbrica: \"Produzione: zero. Scorie: 900 tonnellate. Obiettivo NEXUS: raggiunto.\"",
		"quest": {"type": "barrels", "text": "Metti in sicurezza tutti i barili che perdono"},
	},
	{
		"level": "res://Resources/Levels/Harbor.tres",
		"music": "harbor",
		"enemies": {"sprayer": 2, "bomber": 2, "brute": 2, "drone": 2},
		"title": "Il porto nero",
		"text": "Le navi degli Inquinatori portano rifiuti da tutto il mondo sull'isola. Al porto si nasconde anche il Barone dei Rifiuti, il capo della banda.",
		"dossier": "Contratto del Barone: \"In cambio della protezione di NEXUS, l'isola sarà la discarica del mondo.\"",
		"quest": {"type": "nodamage", "text": "Completa il livello senza subire danni"},
	},
	{
		"level": "res://Resources/Levels/AiDataCenter.tres",
		"music": "datacenter",
		"enemies": {"drone": 4, "sprayer": 2, "bomber": 2, "brute": 1},
		"title": "Il cervello",
		"text": "Il data center è la mente degli Inquinatori. Qui NEXUS calcola ogni scarico e ogni tangente. Spegni i suoi server e scopri dov'è il nucleo.",
		"dossier": "Ultimo file: \"Se il nucleo è minacciato, il Barone attiverà il MECCA-RIFIUTI.\"",
		"quest": {"type": "elites", "text": "Sconfiggi tutte le guardie Elite del data center"},
	},
	{
		"level": "res://Resources/Levels/Fortress.tres",
		"music": "fortress",
		"enemies": {"brute": 3, "drone": 2, "sprayer": 2, "bomber": 2},
		"title": "La fortezza del Barone",
		"text": "Sulla collina della discarica si alza la fortezza del Barone dei Rifiuti. Attraversala, raggiungi l'arena e abbatti il suo MECCA-RIFIUTI per spegnere NEXUS.",
		"dossier": "Codice di spegnimento di NEXUS: trovato. L'isola può tornare verde.",
		"quest": {"type": "chests", "text": "Apri i forzieri della fortezza"},
		"boss": true,
	},
]

var _levels := {}  # LevelData path -> index


func _ready() -> void:
	for i in CHAPTERS.size():
		_levels[CHAPTERS[i].level] = i


## Chapters whose level exists in this build, in order.
func chapters() -> Array:
	var out := []
	for ch in CHAPTERS:
		if ResourceLoader.exists(ch.level):
			out.append(ch)
	return out


func chapter_index(level: LevelData) -> int:
	if level == null:
		return -1
	var list := chapters()
	for i in list.size():
		if list[i].level == level.resource_path:
			return i
	return -1


## The chapter dictionary of `level`, or {} for levels outside the campaign.
func chapter_of(level: LevelData) -> Dictionary:
	var i := chapter_index(level)
	return chapters()[i] if i >= 0 else {}


## The level after `level` in the campaign, or null after the last one.
func next_level(level: LevelData) -> LevelData:
	var list := chapters()
	var i := chapter_index(level)
	if i < 0 or i + 1 >= list.size():
		return null
	return load(list[i + 1].level)


func previous_level(level: LevelData) -> LevelData:
	var i := chapter_index(level)
	if i <= 0:
		return null
	return load(chapters()[i - 1].level)


## Campaign levels as LevelData, in order (for the level menu).
func campaign_levels() -> Array[LevelData]:
	var out: Array[LevelData] = []
	for ch in chapters():
		out.append(load(ch.level))
	return out


## Enemy types that appear for the first time in `level`'s chapter.
func new_enemies_in(level: LevelData) -> Array:
	var i := chapter_index(level)
	if i < 0:
		return []
	var seen := {}
	var list := chapters()
	for j in i:
		for k in list[j].get("enemies", {}):
			seen[k] = true
	var out := []
	for k in list[i].get("enemies", {}):
		if not seen.has(k):
			out.append(k)
	return out


func is_final(level: LevelData) -> bool:
	var ch := chapter_of(level)
	return ch.get("boss", false)
