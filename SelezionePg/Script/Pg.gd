extends Resource
class_name Pg

@export var title : String
@export var icon : Texture2D
@export var scene : PackedScene

@export var animation_name : String
## Coins needed to unlock this character in the Shop (0 = free from the start).
@export var price : int = 0
## Short line shown on the Shop card.
@export_multiline var shop_description : String
