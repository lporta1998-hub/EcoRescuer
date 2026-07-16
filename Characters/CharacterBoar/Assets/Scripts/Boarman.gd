extends CombatCharacter

var last_direction = Vector2.RIGHT
@onready var heartsContainer = $CanvasLayer/HeartsContainer


func _ready():
    super()
    add_to_group("player")
    heartsContainer.setMaxHP(4)
    heartsContainer.updateHP(self.health)
    self.hpChanged.connect(heartsContainer.updateHP)
    

func _process(delta):
    super(delta)
    
        

func _physics_process(delta):
    # Salva input per movimento
    var raw_input = Input.get_vector("left","right","up","down")
    
    # Gestisci movimento durante attacchi
    if is_attacking:
        input_direction = Vector2.ZERO
    else:
        input_direction = raw_input
    
    super(delta)
    handle_footsteps(delta)
    
    # Gestisci attacco melee - questo FUNZIONA anche senza arma
    if Input.is_action_pressed("primary") and not is_attacking:
        handle_attack_input()
    
    # Aggiorna direzione attacco (solo se non stiamo attaccando)
    if raw_input != Vector2.ZERO and not is_attacking:
        update_attack_direction(raw_input)
    
    # Gestisci animazioni
    if not is_attacking:
      handle_animations()



func update_facing_direction(direction: Vector2):
    if abs(direction.x) > abs(direction.y):
        last_direction = Vector2.LEFT if direction.x < 0 else Vector2.RIGHT
    else:
        last_direction = Vector2.UP if direction.y < 0 else Vector2.DOWN
    
    look_direction = direction


func heal(amount: int) -> void:
    health = min(health + amount, 4)
    hpChanged.emit(health)
