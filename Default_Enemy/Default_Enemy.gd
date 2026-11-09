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

## Smarter behaviour: they see you from farther, call their friends, follow
## you for a while after losing sight, patrol around their post when you're
## near, and flash before they strike.
const SIGHT_RADIUS := 140.0
const ALERT_RADIUS := 160.0
const MEMORY := 4.0
const PATROL_RADIUS := 90.0
## Only enemies this close to the player patrol; the rest keep resting
## (no physics at all), which keeps phones smooth.
const PATROL_WAKE := 450.0
const WINDUP := 0.3
const LUNGE := 110.0
var _home := Vector2.INF
var _in_sight := false
var _memory := 0.0
var _awake := false
var _wake_check := 0.0
var _patrol_wait := 0.0
var _patrolling := false
var _windup := 0.0
var _last_ok := Vector2.INF

func _ready():
    add_to_group("enemies")
    _home = global_position
    _wake_check = randf() * 0.5
    _patrol_wait = randf_range(0.5, 2.0)
    var sight := detection_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
    if sight and sight.shape is CircleShape2D:
        sight.shape = sight.shape.duplicate()  # the shape resource is shared by every enemy
        sight.shape.radius = SIGHT_RADIUS
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
        _in_sight = true
        var was_chasing: bool = chasing
        alert(body)
        if not was_chasing:
            # "!" and the friends nearby join the chase
            FloatText.spawn(self, "!", Color(1.0, 0.85, 0.3), Vector2(0, -38))
            SFXManager.play_sfx(preload("res://Audio/SFX/Eco/alert.wav"), -10)
            for e in get_tree().get_nodes_in_group("enemies"):
                if e != self and is_instance_valid(e) and e.has_method("alert") \
                        and e.global_position.distance_to(global_position) < ALERT_RADIUS:
                    e.alert(body)

func _on_body_exited(body):
    if body == player:
        _in_sight = false  # keep following for MEMORY seconds

## Starts (or refreshes) the chase: called when it sees the player or when a
## friend nearby spotted them.
func alert(target: Node2D) -> void:
    if is_dead or target == null:
        return
    player = target
    chasing = true
    _memory = MEMORY
    _patrolling = false

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
        _keep_on_floor()
        return
        
    direction = Vector2.ZERO

    # lost sight: follow the trail for a while, then go back to patrolling
    if chasing and not _in_sight:
        _memory -= delta
        if _memory <= 0.0 or player == null or not is_instance_valid(player):
            chasing = false
            player = null
            _path = PackedVector2Array()
            _path_index = 0

    # winding up a strike: stand still, then lunge and swing
    if _windup > 0.0:
        _windup -= delta
        input_direction = Vector2.ZERO
        if _windup <= 0.0 and player and is_instance_valid(player) and not is_dead:
            velocity += global_position.direction_to(player.global_position) * LUNGE
            _start_attack_cooldown()
            _attack()
        super(delta)
        _keep_on_floor()
        return

    if not chasing and not attacking:
        _update_patrol(delta)

    # Idle and not moving: nothing to simulate this frame. Skipping
    # move_and_slide() for the many enemies standing around saves a lot of
    # physics time on phones. Detection still works (area signals).
    if not chasing and not attacking and _path_finished() and not _patrolling \
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
    input_direction = direction * (0.5 if _patrolling and not chasing else 1.0)
    handle_footsteps(delta)
    super(delta)
    _keep_on_floor()
    _update_animation()
    # (Character._physics_process already calls move_and_slide(); calling it
    # again here used to move enemies twice per frame.)
    
    if player and player_in_attack_area and can_attack and not attacking and not is_dead:
        # telegraph: a red flash, a short pause, then the lunge (see above)
        _windup = WINDUP
        can_attack = false
        modulate = Color(2.0, 0.55, 0.5)
        create_tween().tween_property(self, "modulate", Color.WHITE, WINDUP)

## Never leave the walkable map: if a move (or a knockback) ends off the
## floor grid, step back to the last good spot. Returns false when blocked.
## (In City the walls are on collision layer 1, which enemies don't collide
## with, so physics alone doesn't stop them.)
func _keep_on_floor() -> bool:
    var rg: RouteGuide = LevelManager.route_guide
    if rg == null or not rg.is_ready():
        return true
    if rg.is_open(global_position):
        _last_ok = global_position
        return true
    if _last_ok == Vector2.INF:
        _last_ok = rg.open_spot(global_position, 0)
    global_position = _last_ok
    velocity = Vector2.ZERO
    return false

## Wanders between open spots around its post while the player is nearby.
func _update_patrol(delta: float) -> void:
    _wake_check -= delta
    if _wake_check <= 0.0:
        _wake_check = 0.5
        var p := get_tree().get_first_node_in_group("player") as Node2D
        _awake = p != null and p.global_position.distance_to(global_position) < PATROL_WAKE
    if not _awake:
        _patrolling = false
        return
    if not _path_finished():
        _patrolling = true
        return
    _patrolling = false
    _patrol_wait -= delta
    if _patrol_wait > 0.0:
        return
    _patrol_wait = randf_range(1.0, 2.0)
    var rg: RouteGuide = LevelManager.route_guide
    if rg == null or not rg.is_ready():
        return
    var a := randf() * TAU
    var goal := rg.open_spot(_home + Vector2(cos(a), sin(a)) * randf_range(30.0, PATROL_RADIUS))
    if rg.reachable(global_position, goal):
        _set_path_to(goal)
        _patrolling = true

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
    if can_be_interrupted and (attacking or _windup > 0.0):
        attacking = false
        damage_dealt = false
        if _windup > 0.0:
            _windup = 0.0
            can_attack = true
    _flash(Color(2.5, 2.5, 2.5))
    Global.hitstop()

## Getting hit (even from far away, by an arrow or a potion) starts the chase.
func take_damage(dmg: int, attacker):
    super(dmg, attacker)
    if is_dead:
        return
    var p: Node2D = attacker if is_instance_valid(attacker) and attacker is Node2D and attacker.is_in_group("player") \
            else get_tree().get_first_node_in_group("player") as Node2D
    if p:
        alert(p)

func handle_death():
    if _health_bar:
        _health_bar.visible = false
    LevelManager.on_enemy_killed(self)
    # the smog clears into leaves: one polluter less
    FX.at_node("purify", self, Vector2(0, -12))
    SFXManager.play_sfx(preload("res://Audio/SFX/Eco/purify.wav"), -5, randf_range(0.95, 1.05))
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
