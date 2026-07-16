extends Panel

var icon = null:
    set(value):
            icon = value
            $TextureButton.texture_normal = value

signal pressed

func _ready() -> void:
    $Select.hide()


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
