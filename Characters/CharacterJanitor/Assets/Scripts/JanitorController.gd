extends Character

@export var dry_speed := 400.0
@export_range(1.0, 25.0, .1) var dry_decay := 20.0
@export var wet_speed := 950.0
@export_range(1.0, 25.0, .1) var wet_decay := 4.0

@onready var puddle_map: TileMapLayer = %PuddleMap
@onready var water_meter: ProgressBar = $CanvasLayer/UI/WaterMeter
@onready var puddle_generator: Node2D = $PuddleGenerator
@onready var mop: Weapon = $Mop

var sliding := 0.0
var is_sliding := false

var max_water := 1.5
var water := max_water

func _ready() -> void:
  speed = dry_speed
  decay = dry_decay
  super()

func _process(delta: float) -> void:
  input_direction = Input.get_vector("left","right","up","down")
  
  handle_attack()
  handle_water_and_puddle_map(delta)
  handle_sliding(delta)
  
  speed = lerpf(dry_speed, wet_speed, sliding)
  decay = lerpf(dry_decay, wet_decay, sliding)
  
  super(delta)


func handle_attack():
  if Input.is_action_pressed("secondary"):
    mop.start_attack()
    

func handle_water_and_puddle_map(delta: float) -> void:
  var has_water := water > 0.0
  
  if Input.is_action_just_pressed("primary") and has_water:
    puddle_generator.start_puddle()
  
  if Input.is_action_pressed("primary") and has_water:
    puddle_map.set_puddlemap_cells(global_position)
    puddle_generator.continue_puddle()
    water -= delta
  
  if not Input.is_action_pressed("primary"):
    water += delta
  
  water = clampf(water, 0, max_water)

func handle_sliding(delta: float) -> void:
  if is_sliding:
    sliding += delta * 2.0
  else:
    sliding -= delta * 1.5
  sliding = clampf(sliding, 0, 1)
  
  var cell_below_player = puddle_map.get_cell_at(global_position)
  if cell_below_player:
    is_sliding = true
  else:
    is_sliding = false

func on_soft_collision(body: Node2D) -> void:
  soft_collision_vector = body.global_position.direction_to(global_position) * 1000.0
