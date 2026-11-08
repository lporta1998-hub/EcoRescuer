# Sistema Raccoglibili – EcoRescuer

Questa cartella contiene il sistema completo di **oggetti raccoglibili a tema ambientale** per EcoRescuer.

---

## Struttura

```
Collectibles/
├── Assets/Sprites/
│   ├── eco_token.png        ← Moneta verde (16×16 px)
│   ├── green_leaf.png       ← Foglia (16×16 px)
│   ├── trash_bag.png        ← Sacchetto immondizia (20×20 px)
│   └── recycling_crate.png  ← Cassa riciclaggio (24×24 px)
├── Code/
│   ├── collectible.gd       ← Classe base (estende Area2D)
│   ├── eco_token.gd         ← Moneta ecologica (+10 punti)
│   ├── green_leaf.gd        ← Foglia verde (+25 punti)
│   ├── trash_bag.gd         ← Sacchetto spazzatura (+15 punti)
│   └── recycling_crate.gd   ← Cassa con 5 EcoToken dentro
└── Scenes/
    ├── eco_token.tscn
    ├── green_leaf.tscn
    ├── trash_bag.tscn
    └── recycling_crate.tscn
```

---

## Oggetti

| Oggetto | Punti | Descrizione |
|---|---|---|
| **EcoToken** 🟢 | +10 | Moneta verde collezionabile, il raccoglibile base |
| **GreenLeaf** 🍃 | +25 | Foglia: simbolo di natura salvata |
| **TrashBag** 🗑️ | +15 | Sacchetto spazzatura: pulizia dell'ambiente |
| **RecyclingCrate** ♻️ | — | Cassa che esplode in 5 EcoToken raccoglibili |

---

## Ruolo nel gioco

| Oggetto | Cosa fa |
|---|---|
| **Sacchetti** (TrashBag) | Obiettivo del livello: raccoglili e portali al punto di raccolta (LevelExit). |
| **Monete verdi** (EcoToken) | Contano nel contatore in alto (`LevelManager.run_coins`) e servono ad aprire i **forzieri**. Quelle non spese diventano monete del negozio a fine livello. |
| **Barili** (Barile, `barrel.gd`) | Perdono una pozza tossica: dentro la pozza vai più piano e perdi un cuore ogni 1.2 s. Raccogli il barile per metterlo in sicurezza e asciugare la pozza. Il Magnete non li attira. |
| **Forzieri** (EcoChest, `eco_chest.gd`) | Costano `cost` monete raccolte nel livello. Danno una ricompensa a caso: Cura (+1 cuore e salute piena), Eco Rush (20 s più veloce e +1 danno), Tesoro (+100 monete negozio), Scudo extra. Imposta `cost` nell'Inspector e spostali dove vuoi nel livello. |
| **Cuori** | Curano 1 cuore (la sfida "Senza cure" ne fa sparire una parte). |

---

## Come usare

### Aggiungere raccoglibili a un livello esistente
1. Apri il livello in Godot (es. `Ruins_level/Scenes/ruins.tscn`)
2. Trascina una delle scene da `Collectibles/Scenes/` nella scena del livello
3. Posiziona l'oggetto dove vuoi


### Integrazione punteggio
I raccoglibili chiamano `Global.add_score(points)` se il metodo esiste. Per attivare il punteggio, aggiungi in `globals.gd`:

```gdscript
var eco_score: int = 0

func add_score(amount: int) -> void:
    eco_score += amount
    print("Eco Score: ", eco_score)
```

---

## Comportamento tecnico

- Tutti i raccoglibili estendono la classe `Collectible` (extends `Area2D`)
- La collision mask è impostata al layer 1 (Player), compatibile con il progetto
- La `RecyclingCrate` spawna 5 `EcoToken` in cerchio al contatto col giocatore
- `queue_free()` viene chiamato automaticamente dopo la raccolta
