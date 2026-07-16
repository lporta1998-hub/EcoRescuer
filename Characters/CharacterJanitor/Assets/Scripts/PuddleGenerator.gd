extends Node2D

const Puddle_scene = preload("uid://b82nnumtdaekw")

var puddles = []
var current_puddle: Line2D = null

func start_puddle():
  var new_puddle := Puddle_scene.instantiate()
  get_tree().root.add_child(new_puddle)
  new_puddle.add_point(global_position)
  current_puddle = new_puddle
  puddles.append(current_puddle)

func continue_puddle():
  if current_puddle.points[-1].distance_to(global_position) > 20.0:
    current_puddle.add_point(global_position)


#func _process(delta: float) -> void:
  #if Input.is_action_just_pressed("primary"):
    #start_puddle()
#
  #if Input.is_action_pressed("primary"):
    #continue_puddle()
