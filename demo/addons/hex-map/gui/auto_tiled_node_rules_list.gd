@tool
extends PanelContainer 

@export var rules := {} :
    set(value):
        rules = value
        _queue_rebuild_list()
@export var order := [] :
    set(value):
        order = value
        _queue_rebuild_list()
@export var mesh_library := MeshLibrary.new() :
    set(value):
        if value != mesh_library:
            mesh_library = value
            _queue_rebuild_list()
@export var selected_id := -1 :
    set(value):
        selected_id = value
        for child in %Rules.get_children():
            child.selected = child.get_rule().id == selected_id

# emitted when user clicks on an existing rule in the list
signal rule_selected(rule: HexMapTileRule)
# emitted when the user changes the order of the rules in the list
signal order_changed(order: Array)
# emitted when user requests a rule be deleted
signal delete_rule(id: int)
# emitted when the user changes a rule from the list; only enable/disable at
# the moment
signal rule_changed(rule: HexMapTileRule)

const rule_item: PackedScene = preload("auto_tiled_node_rule_list_item.tscn")

# only rebuild the rules list once per frame at most
var _redraw_queued := false
func _queue_rebuild_list() -> void:
    if _redraw_queued == false:
        _redraw_queued = true
        call_deferred("_redraw_rules")


func _notification(what: int) -> void:
    if what == NOTIFICATION_DRAG_END:
        # if the drag wasn't successful (rule dropped someplace outside of the
        # list), we need to rebuild the rules list because we shuffled it
        # while dragging.
        if not is_drag_successful():
            _queue_rebuild_list()

func _redraw_rules() -> void:
    _redraw_queued = false
    for child in %Rules.get_children():
        %Rules.remove_child(child)
        child.queue_free()

    for id in order:
        var rule = rules[id]
        var control = rule_item.instantiate()

        # set the control state
        control.set_rule(rule)
        control.preview = mesh_library.get_item_preview(rule.tile)
        control.selected = rule.id == selected_id

        # forward some drag & drop to this class
        control.set_drag_forwarding(Callable(), _can_drop_in_child.bind(control), _drop_data)

        # hook up the signals
        control.pressed.connect(_on_rule_selected.bind(rule))
        control.pressed_delete.connect(func(): delete_rule.emit(rule.id))
        control.enabled_toggled.connect(_on_rule_enabled_toggled.bind(rule))
        control.tile_name = mesh_library.get_item_name(rule.tile)

        %Rules.add_child(control)

func _can_drop_in_child(at_position: Vector2, data: Variant, child: Control) -> bool:
    return _can_drop_data(child.get_rect().position + at_position, data)

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
    if data.get_parent() != %Rules:
        return false

    for child in %Rules.get_children():
        var child_rect := child.get_rect() as Rect2
        var pos = child_rect.position.y + child_rect.size.y
        if pos >= at_position.y:
            if data != child:
                %Rules.move_child(data, child.get_index())
            break

    return true

func _drop_data(at_position: Vector2, data: Variant) -> void:
    var order := []
    for child in %Rules.get_children():
        order.push_back(child.get_rule().id)

    # in _get_drag_data(), we override the panel stylebox to highlight this item
    # so we clear it here when dropped
    data.remove_theme_stylebox_override("panel")
    order_changed.emit(order)

func _on_rule_selected(rule: HexMapTileRule) -> void:
    rule_selected.emit(rule)

func _on_rule_enabled_toggled(value: bool, rule: HexMapTileRule) -> void:
    if value == rule.enabled:
        return
    rule.enabled = value
    rule_changed.emit(rule)
