class_name Enemy extends Character

@onready var sprite = $AnimatedSprite2D
@onready var navigation = $NavigationAgent2D
@onready var detection_area = $DetectionArea
@onready var attack_area = $AttackRange

@export var attack_damage = 1
@export var attack_cooldown = 1.5
@export var attack_range = 12

var player = null
var chasing = false
var attacking = false
var can_attack = true

var direction = Vector2.ZERO
var cardinal_direction: Vector2 = Vector2.DOWN
var attack_direction: Vector2 = Vector2.DOWN
var attack_combo: int = 1
var player_in_attack_area = false

# NEW: Frame-based damage timing
var damage_frame: int = 3  
var damage_dealt: bool = false

func _ready():
    detection_area.body_entered.connect(_on_body_entered)
    detection_area.body_exited.connect(_on_body_exited)
    attack_area.body_entered.connect(_on_attack_area_body_entered)
    attack_area.body_exited.connect(_on_attack_area_body_exited)
    navigation.target_position = global_position
    
    # NEW: Connect frame signal
    sprite.frame_changed.connect(_on_frame_changed)

func _on_body_entered(body):
    if body.name == "Player":  
        player = body
        chasing = true

func _on_body_exited(body):
    if body == player:
        player = null
        chasing = false

func _on_attack_area_body_entered(body):
    if body.name == "Player":
        player_in_attack_area = true

func _on_attack_area_body_exited(body):
    if body.name == "Player":
        player_in_attack_area = false
        
func _physics_process(delta):
    if is_dead:
        return
        
    direction = Vector2.ZERO
    
    if chasing and player and not attacking:
        navigation.target_position = player.global_position
        
        var to_player = (player.global_position - global_position).normalized()
        if abs(to_player.x) > abs(to_player.y):
            attack_direction = Vector2.LEFT if to_player.x < 0 else Vector2.RIGHT
        else:
            attack_direction = Vector2.UP if to_player.y < 0 else Vector2.DOWN
    
    if not attacking and not navigation.is_navigation_finished():
        var next_point = navigation.get_next_path_position()
        direction = (next_point - global_position).normalized()
    
    _update_direction()
    input_direction = direction
    handle_footsteps(delta)
    super(delta)
    _update_animation()
    move_and_slide()
    
    if player and player_in_attack_area and can_attack and not attacking and not is_dead:
        _start_attack_cooldown()
        _attack()

func _start_attack_cooldown():
    can_attack = false
    get_tree().create_timer(attack_cooldown).timeout.connect(
        func(): can_attack = true, 
        CONNECT_ONE_SHOT)

# NEW: Frame change handler
func _on_frame_changed():
    if not attacking or is_dead:
        return
    
    if sprite.frame == damage_frame and not damage_dealt:
        _deal_damage()

# NEW: Separate damage function
func _deal_damage():
    if not player:
        return
    
    if player_in_attack_area or _is_player_in_attack_range():
        if player.has_method("take_damage"):
            player.take_damage(attack_damage, self)
            damage_dealt = true

func _attack():
    attacking = true
    damage_dealt = false  
    
    # RANDOM OPTION: Pick 1 or 2 
    #attack_combo = randi() % 2 + 1
    # SEQUENTIAL 
    attack_combo = 2 if attack_combo == 1 else 1
    
    var dir_name = ""
    match attack_direction:
        Vector2.UP:    dir_name = "up"
        Vector2.DOWN:  dir_name = "down"
        Vector2.LEFT:  dir_name = "left"
        Vector2.RIGHT: dir_name = "right"
    
    var anim_name = "Attack_%s_%d" % [dir_name, attack_combo]
    sprite.play(anim_name)

func _is_player_in_attack_range():
    if not player:
        return false
    return global_position.distance_to(player.global_position) <= attack_range

func _update_direction():
    if direction == Vector2.ZERO:
        return
    
    var new_dir := Vector2.RIGHT 
    if abs(direction.x) > abs(direction.y):
        if direction.x < 0:
            new_dir = Vector2.LEFT
        else:
            new_dir = Vector2.RIGHT
    else:
        if direction.y < 0:
            new_dir = Vector2.UP
        else:
            new_dir = Vector2.DOWN

    if new_dir == cardinal_direction:
        return
    
    cardinal_direction = new_dir
    attack_direction = new_dir

func _update_animation():
    if attacking:
        return
    
    var state = "Idle"
    if direction != Vector2.ZERO:
        state = "Walk"
    
    var anim_name = state + "_"
    
    match cardinal_direction:
        Vector2.UP:    anim_name += "up"
        Vector2.DOWN:  anim_name += "down"
        Vector2.LEFT:  anim_name += "left"
        Vector2.RIGHT: anim_name += "right"
    
    sprite.play(anim_name)

func _on_animated_sprite_2d_animation_finished() -> void:
    if sprite.animation.begins_with("Attack_"):
        attacking = false
        damage_dealt = false  
