extends CanvasLayer

@export var fade_duration: float = 0.5
@export var fade_color: Color = Color.BLACK

@onready var color_rect = $ColorRect

func _ready():
    layer = 128
    color_rect.color = fade_color
    color_rect.color.a = 0
    color_rect.visible = false

func fade_in():
    color_rect.visible = true
    color_rect.color.a = 1.0
    
    var tween = create_tween()
    tween.tween_property(color_rect, "color:a", 0.0, fade_duration)
    await tween.finished
    color_rect.visible = false

func fade_out():
    color_rect.visible = true
    color_rect.color.a = 0.0
    
    var tween = create_tween()
    tween.tween_property(color_rect, "color:a", 1.0, fade_duration)
    await tween.finished
    
func fade_out_then(callback: Callable):
    fade_out()
    await get_tree().create_timer(fade_duration).timeout
    callback.call()
    fade_in()


func transition_to(scene_path: String):
    fade_out()
    get_tree().change_scene_to_file(scene_path)
    fade_in()
