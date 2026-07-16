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
