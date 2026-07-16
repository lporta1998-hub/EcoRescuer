extends PanelContainer

@onready var title_label = $TextureButton/MarginContainer/VBoxContainer2/LevelName
@onready var description_label = $TextureButton/MarginContainer/VBoxContainer2/Description
@onready var preview = $TextureButton/MarginContainer/VBoxContainer/TextureRect

@export var max_width: float = 500.0
@export var max_height: float = 100.0

var icon = null:
    set(value):
            icon = value
            $TextureButton/MarginContainer/VBoxContainer/TextureRect.texture= value
            
var level_name : String = "":
    set(value):
        level_name = value
        if $TextureButton/MarginContainer/VBoxContainer2/LevelName:
            $TextureButton/MarginContainer/VBoxContainer2/LevelName.text = value
var description : String = "":
    set(value):
        description = value
        if $TextureButton/MarginContainer/VBoxContainer2/Description:
            $TextureButton/MarginContainer/VBoxContainer2/Description.text = value
            
var level_data: LevelData = null
signal pressed

func _ready() -> void:
    
    $Select.hide()
    
func setup(level: LevelData):
    level_data = level
    icon = level.preview_image
    level_name = level.level_name
    description = level.description

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
    pass


func _on_texture_button_pressed() -> void:
    for slot in get_parent().get_children():
            slot.deselect()
    $Select.show()
    pressed.emit()

func deselect():
    $Select.hide()
    


      
        
        
    
    
    
    
   
