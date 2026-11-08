extends Panel

var icon = null:
    set(value):
            icon = value
            $TextureButton.texture_normal = value

signal pressed

var locked := false

func _ready() -> void:
    $Select.hide()

## Locked characters are dimmed with a padlock and their Shop price.
func set_locked(is_locked: bool, price: int) -> void:
    locked = is_locked
    $TextureButton.modulate = Color(0.35, 0.35, 0.4) if is_locked else Color.WHITE
    var overlay := get_node_or_null("LockOverlay")
    if not is_locked:
        if overlay:
            overlay.queue_free()
        return
    if overlay:
        return
    overlay = Control.new()
    overlay.name = "LockOverlay"
    overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(overlay)
    var lock := TextureRect.new()
    lock.texture = preload("res://Menu/Shop/lock.png")
    lock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    lock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    lock.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
    lock.position = Vector2(30, 16)
    lock.size = Vector2(40, 40)
    overlay.add_child(lock)
    var price_row := HBoxContainer.new()
    price_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    price_row.alignment = BoxContainer.ALIGNMENT_CENTER
    price_row.position = Vector2(0, 62)
    price_row.size = Vector2(100, 28)
    price_row.add_theme_constant_override("separation", 4)
    var coin := TextureRect.new()
    coin.texture = preload("res://Collectibles/Assets/Sprites/coin.png")
    coin.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    coin.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
    coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var label := Label.new()
    label.text = str(price)
    label.add_theme_font_size_override("font_size", 20)
    label.add_theme_constant_override("outline_size", 5)
    label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
    price_row.add_child(coin)
    price_row.add_child(label)
    overlay.add_child(price_row)


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
