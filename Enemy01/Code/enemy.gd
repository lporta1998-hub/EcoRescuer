extends Character

@export var target: CharacterBody2D

func _process(delta: float) -> void:  
  if not target:
    return
  var desired = global_position.direction_to(target.global_position) * speed
  var setpoint = (desired - velocity).limit_length(speed)
  velocity += setpoint * delta
  #velocity = velocity.limit_length(speed)
  handle_footsteps(delta)
  
  var last_col := get_last_slide_collision()
  if last_col:
    velocity += last_col.get_normal() * velocity.length()/2.0
  pass
  
  
func on_soft_collision(body: Node2D) -> void:
  #soft_collision_vector = (Vector2.from_angle(randf_range(-PI, PI)) * 100)
  pass



#speed = 200.0
#
#@onready var puddle_map := %PuddleMap
#
#
#func _process(delta: float) -> void:
  #if target:
    ##velocity = Globals.exp_decay(velocity, global_position.direction_to(target.global_position) * speed, 8, delta)
    #var desired = global_position.direction_to(target.global_position) * speed
    #var setpoint = desired - velocity
    #velocity += setpoint * delta
  #velocity = velocity.limit_length(speed)
  #
  ##var cell_below = puddle_map.get_cell_at(global_position)
  ##if cell_below:
    ##velocity = global_position.direction_to(target.global_position) * -speed
#
#func _physics_process(delta: float) -> void:
  #var last_col := get_last_slide_collision()
  #if last_col:
    #velocity -= -last_col.get_normal() * speed
  #move_and_slide()
