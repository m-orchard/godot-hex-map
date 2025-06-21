@tool
extends PanelContainer

# emitted when the user clicks on the rule description to select the rule
signal pressed
# emitted when the user confirms deleting the rule
signal pressed_edit

@export var color : Color :
    set(value):
        color = value
        if not is_node_ready():
            await ready
        %Color.color = value

@export var desc : String :
    set(value):
        desc = value
        if not is_node_ready():
            await ready
        %Desc.text = desc

@export var value : int

@export var selected := false :
    set(value):
        selected = value
        _update_stylebox()

@export var hovered := false :
    set(value):
        hovered = value
        _update_stylebox()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    mouse_entered.connect(func(): hovered = true)
    mouse_exited.connect(func(): hovered = false)
    %Color.color = color
    %Desc.text = desc
    %EditButton.mouse_entered.connect(func(): hovered = true)
    %EditButton.mouse_exited.connect(func(): hovered = false)
    %EditButton.pressed.connect(func(): pressed_edit.emit())

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton \
            and event.is_released() \
        and event.button_index == MOUSE_BUTTON_MASK_LEFT:
        selected = true
        pressed.emit()

func _update_stylebox() -> void:
    var stylebox = null
    if selected:
        stylebox = get_theme_stylebox("focus")
    elif hovered:
        stylebox = get_theme_stylebox("hovered")
   
    if stylebox:
        add_theme_stylebox_override("panel", stylebox)
    else:
        remove_theme_stylebox_override("panel")
