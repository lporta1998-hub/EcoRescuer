@tool
extends Sprite2D

#@export_tool_button("Randomize", "Callable") var randomize_action = randomize_params
@export var seed = 1:
  # Update speed and reset the rotation.
  set(new_seed):
    seed(hash(global_position))
    randomize_params()
    seed = new_seed

func randomize_params():
  flip_h = randi_range(0,1) == 1
