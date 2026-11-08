class_name Enemy extends Character

@onready var sprite = $AnimatedSprite2D
@onready var navigation = $NavigationAgent2D
@onready var detection_area = $DetectionArea
@onready var attack_area = $AttackRange

@export var attack_damage = 1
@export var attack_cooldown = 1.5
@export var attack_range = 12
## Hit reaction: how hard the enemy is pushed back, how long it's stunned,
## and whether a hit cancels an attack it was winding up.
@export var knockback_force := 220.0
@export var stagger_time := 0.3
@export var can_be_interrupted := true

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

var _stagger := 0.0
var _repath_timer := 0.0
## Seconds between path recalculations while chasing (was every frame).
const REPATH_INTERVAL := 0.25
## Recalculate only if the player moved at least this far since the last path.
const REPATH_MIN_MOVE := 10.0
## Paths come from LevelManager.route_guide (a grid A* over the level's tiles,
## computed in native code). The NavigationAgent2D's navigation mesh has one
## region per tile in these levels, so its queries were slow enough to make
## the game stutter on phones whenever a group of enemies chased the player.
var _path := PackedVector2Array()
var _path_index := 0
var _path_goal := Vector2.INF
var _health_bar: EnemyHealthBar
var _resting := false

func _ready():
    detection_area.body_entered.connect(_on_body_entered)
    detection_area.body_exited.connect(_on_body_exited)
    attack_area.body_entered.connect(_on_attack_area_body_entered)
    attack_area.body_exited.connect(_on_attack_area_body_exited)
    # Spread path calculations over different frames.
    _repath_timer = randf() * REPATH_INTERVAL
    
    # NEW: Connect frame signal
    sprite.frame_changed.connect(_on_frame_changed)

    _health_bar = EnemyHealthBar.new()
    _health_bar.position = Vector2(0, -34)
    add_child(_health_bar)
    _health_bar.set_health(health, max_health)
    hpChanged.connect(func(hp): _health_bar.set_health(hp, max_health))

func _on_body_entered(body):
    if body.is_in_group("player"):
        player = body
        chasing = true

func _on_body_exited(body):
    if body == player:
        player = null
        chasing = false

func _on_attack_area_body_entered(body):
    if body.is_in_group("player"):
        player_in_attack_area = true

func _on_attack_area_body_exited(body):
    if body.is_in_group("player"):
        player_in_attack_area = false
        
func _physics_process(delta):
    if is_dead:
        return
    
    # Stunned after a hit: just slide back with the knockback.
    if _stagger > 0.0:
        _stagger -= delta
        input_direction = Vector2.ZERO
        super(delta)
        return
        
    direction = Vector2.ZERO

    # Idle and not moving: nothing to simulate this frame. Skipping
    # move_and_slide() for the many enemies standing around saves a lot of
    # physics time on phones. Detection still works (area signals).
    if not chasing and not attacking and _path_finished() \
            and velocity.length_squared() < 1.0 and soft_collision_vector == Vector2.ZERO:
        if not _resting:
            _resting = true
            velocity = Vector2.ZERO
            input_direction = Vector2.ZERO
            _update_animation()
        return
    _resting = false

    if chasing and player and not attacking:
        _repath_timer -= delta
        if _repath_timer <= 0.0:
            _repath_timer = REPATH_INTERVAL
            if player.global_position.distance_to(_path_goal) >= REPATH_MIN_MOVE or _path_finished():
                _set_path_to(player.global_position)
        
        var to_player = (player.global_position - global_position).normalized()
        if abs(to_player.x) > abs(to_player.y):
            attack_direction = Vector2.LEFT if to_player.x < 0 else Vector2.RIGHT
        else:
            attack_direction = Vector2.UP if to_player.y < 0 else Vector2.DOWN
    
    if not attacking and not _path_finished():
        direction = (_next_path_point() - global_position).normalized()
    
    _update_direction()
    input_direction = direction
    handle_footsteps(delta)
    super(delta)
    _update_animation()
    # (Character._physics_process already calls move_and_slide(); calling it
    # again here used to move enemies twice per frame.)
    
    if player and player_in_attack_area and can_attack and not attacking and not is_dead:
        _start_attack_cooldown()
        _attack()

func _set_path_to(goal: Vector2) -> void:
    _path_goal = goal
    _path_index = 1
    var rg: RouteGuide = LevelManager.route_guide
    if rg and rg.is_ready():
        _path = rg.path(global_position, goal)
    else:
        _path = PackedVector2Array()
    if _path.size() < 2:
        _path = PackedVector2Array([global_position, goal])  # straight at it

func _path_finished() -> bool:
    return _path_index >= _path.size()

## Next point to walk to; skips the ones already reached.
func _next_path_point() -> Vector2:
    while _path_index < _path.size() - 1 and global_position.distance_to(_path[_path_index]) < 6.0:
        _path_index += 1
    var p := _path[_path_index]
    if _path_index == _path.size() - 1 and global_position.distance_to(p) < 6.0:
        _path_index = _path.size()  # arrived
    return p

## Knockback, short stun, white flash, a tiny hit-pause and an update of the
## health bar (via hpChanged).
func _on_hurt(away: Vector2) -> void:
    velocity = away * knockback_force
    _stagger = stagger_time
    if can_be_interrupted and attacking:
        attacking = false
        damage_dealt = false
    _flash(Color(2.5, 2.5, 2.5))
    Global.hitstop()

func handle_death():
    if _health_bar:
        _health_bar.visible = false
    LevelManager.on_enemy_killed(self)
    await super()

## Enemy footsteps used a non-positional player, so every walking enemy in the
## level was heard at full volume. Only play them while chasing (= close).
func handle_footsteps(delta):
    if chasing:
        super(delta)

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
            player.take_damage(LevelManager.enemy_hit_damage(attack_damage), self)
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
