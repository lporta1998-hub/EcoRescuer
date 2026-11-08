class_name Elite extends Enemy

## Elites are tougher: double health (max_health in Elite.tscn), they don't
## flinch out of an attack when hit and barely get pushed back.
func _ready():
    can_be_interrupted = false
    knockback_force = 110.0
    stagger_time = 0.12
    super._ready()
