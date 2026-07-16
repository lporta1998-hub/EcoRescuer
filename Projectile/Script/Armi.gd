extends Resource
class_name Armi


@export var title : String
@export var texture : Texture2D
 
@export var damage : float
@export var cooldown : float
@export var speed : float
@export var range : float 
@export var projectile_node : PackedScene = preload("res://Projectile/Scenes/projectile.tscn")
 
func activate(_source, _target, _scene_tree):
    pass
