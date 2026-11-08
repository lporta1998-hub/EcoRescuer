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

var _scroll_at_press := 0

func _ready() -> void:
    
    $Select.hide()
    # On touch screens the level list scrolls by dragging a finger over it.
    # Nodes that STOP the mouse would swallow that drag before it reaches the
    # ScrollContainer, so let the input pass up the tree instead.
    _let_input_pass(self)
    $TextureButton.button_down.connect(_on_texture_button_down)

func _let_input_pass(node: Node) -> void:
    if node is Control and node.mouse_filter == Control.MOUSE_FILTER_STOP:
        node.mouse_filter = Control.MOUSE_FILTER_PASS
    for child in node.get_children():
        _let_input_pass(child)

func _scroll_container() -> ScrollContainer:
    var node := get_parent()
    while node:
        if node is ScrollContainer:
            return node
        node = node.get_parent()
    return null

func _on_texture_button_down() -> void:
    var sc := _scroll_container()
    _scroll_at_press = sc.scroll_vertical if sc else 0
    
var locked := false

func setup(level: LevelData):
    level_data = level
    icon = level.preview_image
    level_name = level.level_name
    description = level.description
    # Long descriptions (AI Data Center) used to spill out of the card and
    # past the lock veil: cap them so every card has the same height.
    var desc: Label = $TextureButton/MarginContainer/VBoxContainer2/Description
    desc.max_lines_visible = 4
    desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    _show_stars(Progress.get_stars(level))
    locked = not Progress.is_level_unlocked(level)
    if locked:
        _show_lock(level.stars_required)
    elif Progress.is_new_unlock(level):
        _show_new_badge()
        Progress.mark_level_seen(level)

## Row of 3 small stars (best result) under the level name.
func _show_stars(count: int) -> void:
    var row := HBoxContainer.new()
    row.name = "Stars"
    row.mouse_filter = Control.MOUSE_FILTER_PASS
    row.add_theme_constant_override("separation", 2)
    for i in 3:
        var star := TextureRect.new()
        star.texture = preload("res://Menu/Stars/star_full.png") if i < count else preload("res://Menu/Stars/star_empty.png")
        star.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        star.custom_minimum_size = Vector2(20, 20)
        star.mouse_filter = Control.MOUSE_FILTER_PASS
        row.add_child(star)
    var names_box = $TextureButton/MarginContainer/VBoxContainer2
    names_box.add_child(row)
    names_box.move_child(row, 1)  # right under the level name

## Dark veil with a padlock and "N stars needed".
func _show_lock(stars_needed: int) -> void:
    var veil := ColorRect.new()
    veil.name = "LockVeil"
    veil.color = Color(0, 0, 0, 0.8)
    veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(veil)  # PanelContainer stretches it over the whole card
    var center := CenterContainer.new()
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    veil.add_child(center)
    center.set_anchors_preset(Control.PRESET_FULL_RECT)
    var row := HBoxContainer.new()
    row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_theme_constant_override("separation", 8)
    center.add_child(row)
    for tex in [preload("res://Menu/Shop/lock.png"), preload("res://Menu/Stars/star_full.png")]:
        var icon_rect := TextureRect.new()
        icon_rect.texture = tex
        icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        icon_rect.custom_minimum_size = Vector2(32, 32)
        icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
        row.add_child(icon_rect)
    var label := Label.new()
    label.text = "%d" % stars_needed
    label.add_theme_font_size_override("font_size", 28)
    label.add_theme_constant_override("outline_size", 6)
    label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
    row.add_child(label)

func _show_new_badge() -> void:
    var badge := Label.new()
    badge.text = "NUOVO!"
    badge.add_theme_font_size_override("font_size", 18)
    badge.add_theme_color_override("font_color", Color(1.0, 0.83, 0.3))
    badge.add_theme_constant_override("outline_size", 6)
    badge.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
    badge.size_flags_horizontal = Control.SIZE_SHRINK_END
    badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
    badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(badge)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
    pass


func _on_texture_button_pressed() -> void:
    # The finger moved the list: that was a scroll, not a tap on this level.
    var sc := _scroll_container()
    if sc and absi(sc.scroll_vertical - _scroll_at_press) > 8:
        return
    for slot in get_parent().get_children():
            slot.deselect()
    $Select.show()
    pressed.emit()

func deselect():
    $Select.hide()
    


      
        
        
    
    
    
    
   
