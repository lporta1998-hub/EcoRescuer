extends TileMapLayer
@export var object1: Node2D
@export var object2: Node2D
@export var pareteIllusoria : StaticBody2D
var objects_broken = 0

func _ready():
    if object1 and object1.has_signal("broken"):
        object1.broken.connect(_on_object_broken)
    if object2 and object2.has_signal("broken"):
        object2.broken.connect(_on_object_broken)
    
    # Nascondi inizialmente se vuoi
    # hide_layer()

func _on_object_broken():
    objects_broken += 1
    if objects_broken >= 2:
        hide_layer()
        pareteIllusoria.queue_free()

func hide_layer():
    # Metodo 1: Nascondi completamente
    hide()  # Nasconde tutto il layer
    
    # Metodo 2: Solo disabilita collisioni
    # set_collision_enabled(false)
    
    # Metodo 3: Modifica la visibilità
    # modulate = Color(1, 1, 1, 0.5)  # Mezza trasparenza
    # visible = false  # Invisibile
    
    print("Percorso sbloccato!")
