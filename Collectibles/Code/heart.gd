## green_leaf.gd
## Collectible leaf. Represents rescuing a piece of nature.
## Awards more points than a single coin.
extends Collectible
class_name HeartCollectible

func _ready():
    # Configurazione specifica per i cuori
    item_name = "Cuore"
    item_type = "health"
    points = 0
    
    # IMPORTANTE: Non aggiungere il cuore a nessun gruppo di conteggio
    # Se è stato aggiunto al gruppo "trashbag", rimuovilo
    if is_in_group("trashbag"):
        remove_from_group("trashbag")
        
    super._ready()

func on_collect(_player: Node2D) -> void:
    SFXManager.play_sfx(preload("res://Audio/SFX/Objects/Heal.wav"))
    # Logica di recupero vita (the "Senza cure" Sfida removes hearts at level start)
    if _player.has_method("heal"):
        _player.heal(health_restore)
    
    # NON chiamare super.on_collect() perché quello aggiungerebbe punti
    
    # Opzionale: mostra un messaggio di recupero vita
    print("Cuore raccolto! +", health_restore, " vita")

# Sovrascrivi il metodo get_collectible_data per non fornire dati
func get_collectible_data() -> Dictionary:
    return {
        "name": "Cuore",
        "type": "health",
        "points": 0,
        "is_heart": true  # Flag per identificarlo
    }
