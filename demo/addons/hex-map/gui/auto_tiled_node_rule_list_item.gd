@tool
extends PanelContainer

# emitted when the user clicks on the rule description to select the rule
signal pressed
# emitted when the user confirms deleting the rule
signal pressed_delete
# emitted when the user toggles the enabled state
signal enabled_toggled(value: bool)

@export var preview := Texture2D.new() :
    set(value):
        if not is_node_ready():
            await ready
        preview = value
        %TilePreview.texture = value

@export var tile_name := "" :
    set(value):
        %TilePreview.tooltip_text = value

@export var selected := false :
    set(value):
        selected = value
        _update_rule_panel_stylebox()

@export var hovered := false :
    set(value):
        hovered = value
        _update_rule_panel_stylebox()

var rule : HexMapTileRule 

func set_rule(value: HexMapTileRule) -> void:
    rule = value

    if not is_node_ready():
        await ready

    %RuleId.text = str("(", rule.id, ")")
    %EnabledToggle.button_pressed = rule.enabled

func get_rule() -> HexMapTileRule:
    return rule

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    %RulePanel.mouse_entered.connect(func(): hovered = true)
    %RulePanel.mouse_exited.connect(func(): hovered = false)
    %DeleteButton.pressed.connect(_on_delete_pressed)
    %DeleteConfirmButton.pressed.connect(_on_delete_confirmed)
    %EnabledToggle.toggled.connect(_on_enabled_toggle_toggled)

func _gui_input(event: InputEvent) -> void:
    # only select when we left-click within the %RulePanel; we don't want to
    # select the rule when the drag handle is clicked.
    if event is InputEventMouseButton \
            and event.is_pressed() \
            and event.button_index == MOUSE_BUTTON_MASK_LEFT \
            and %RulePanel.get_rect().has_point(event.position):
        selected = true
        pressed.emit()

func _get_drag_data(at_position: Vector2) -> Variant:
    if not %DragHandle.get_rect().has_point(at_position):
        return
    add_theme_stylebox_override("panel", get_theme_stylebox("drag"))
    return self

func _update_rule_panel_stylebox() -> void:
    var stylebox = null
    if selected:
        stylebox = get_theme_stylebox("focus")
    elif hovered:
        stylebox = get_theme_stylebox("hovered")
   
    if stylebox:
        %RulePanel.add_theme_stylebox_override("panel", stylebox)
    else:
        %RulePanel.remove_theme_stylebox_override("panel")

func _on_delete_pressed() -> void:
    var rect = %DeleteButton.get_global_rect()
    var pos = rect.position + rect.size
    %DeletePopup.position = pos
    %DeletePopup.show()

func _on_delete_confirmed() -> void:
    %DeletePopup.hide()
    pressed_delete.emit()

func _on_enabled_toggle_toggled(toggled: bool) -> void:
    if rule.enabled == toggled:
        return
    enabled_toggled.emit(toggled)
