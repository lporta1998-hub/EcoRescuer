extends Resource
class_name LevelData

@export var level_scene : PackedScene
@export var level_name : String
@export var preview_image : Texture2D
@export var description : String
#@export var difficulty : int = 1  # 1=facile, 2=medio, 3=difficile
#@export var required_score_to_unlock : int = 0
#
#@export var is_boss_level : bool = false

@export var high_score: int = 0
@export var max_time_bonus: int = 300
@export var penalty_time : int = 20
## Total stars (across all levels) needed to unlock this level. 0 = open.
@export var stars_required : int = 0
## Objective: trash bags to collect (-1 = all of them) and enemies to defeat
## before the recycling station opens and the level can be finished.
@export var required_bags : int = -1
@export var required_kills : int = 0
func update_high_score(new_score: int) -> bool:
    if new_score > high_score:
        high_score = new_score
        return true  # Nuovo record!
    return false  # Non è record
