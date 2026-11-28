extends BuiltLevel
## The practice level of the interactive tutorial (see Training): a forest
## trail from the start to the recycling station, with the coach on top.

var coach: TrainingCoach


func _ready() -> void:
	super._ready()
	coach = TrainingCoach.new()
	coach.level = self
	add_child(coach)


## LevelManager calls this instead of ending the level when the hero walks
## into the recycling station.
func training_exit_reached() -> void:
	if coach:
		coach.exit_reached()
