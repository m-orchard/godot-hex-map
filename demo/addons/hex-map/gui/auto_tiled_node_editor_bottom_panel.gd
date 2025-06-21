@tool
extends VBoxContainer

@export var node: HexMapAutoTiled :
    set(value) :
        if value == node:
            return

        if node != null:
            node.mesh_library_changed.disconnect(_on_node_mesh_library_changed)
            node.rules_changed.disconnect(_on_node_rules_changed)

        node = value
        int_node = node.get_parent()
        node.mesh_library_changed.connect(_on_node_mesh_library_changed)
        node.mesh_origin_changed.connect(_on_node_mesh_origin_changed)
        node.rules_changed.connect(_on_node_rules_changed)
        _on_node_mesh_library_changed()
        _on_node_mesh_origin_changed()
        _on_node_rules_changed()

@export var editor_plugin: EditorPlugin

# local copy of the AutoTiledNode's parent IntNode
var int_node: HexMapInt

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    %NewRuleButton.pressed.connect(_on_new_rule_pressed)

    %RulesList.rule_selected.connect(_on_rule_selected)
    %RulesList.order_changed.connect(_on_rules_order_changed)
    %RulesList.delete_rule.connect(_on_rules_list_delete)
    %RulesList.rule_changed.connect(_on_rules_list_rule_changed)

    %RuleEditor.save_pressed.connect(_on_rule_editor_save)
    %RuleEditor.cancel_pressed.connect(_on_rule_editor_cancel)
    %HSplitContainer.split_offset *= EditorInterface.get_editor_scale()

func edit_rule(rule: HexMapTileRule) -> void:
    %RulesList.selected_id = rule.id
    %Directions.visible = false
    %RuleEditor.clear()

    %RuleEditor.set_hex_space(int_node.get_space())
    %RuleEditor.cell_scale = int_node.get_space().cell_scale
    %RuleEditor.cell_types = int_node.cell_types
    %RuleEditor.mesh_library = node.mesh_library
    if rule.id == HexMapTileRule.ID_NOT_SET:
        %RuleEditor.mode = "Add"
    else:
        %RuleEditor.mode = "Update"
    %RuleEditor.set_rule(rule)
    %RuleEditor.visible = true
    %RuleEditor.focus_painter()

func _on_new_rule_pressed():
    edit_rule(HexMapTileRule.new())

func _on_rule_selected(rule: HexMapTileRule) -> void:
    edit_rule(rule)

func _on_rules_order_changed(value: Array) -> void:
    var orig = node.get_rules_order()
    var undo_redo := editor_plugin.get_undo_redo()
    undo_redo.create_action("HexMapAutoTiled: change rule order")
    undo_redo.add_do_method(node, "set_rules_order", value)
    undo_redo.add_undo_method(node, "set_rules_order", orig)
    undo_redo.commit_action()

func _on_rule_editor_save(rule: HexMapTileRule):
    var undo_redo := editor_plugin.get_undo_redo()

    if %RuleEditor.mode == "Update":
        var orig = node.get_rule(rule.id)
        if orig == null:
            push_error("unable to find original values for rule ", rule.id)
            return
        undo_redo.create_action(str("HexMapAutoTiled: update rule ", rule.id))
        undo_redo.add_do_method(node, "update_rule", rule)
        undo_redo.add_undo_method(node, "update_rule", orig)
        undo_redo.commit_action()
        %RuleEditor.show_message("[b]Saved rule " + str(rule.id) + "[/b]")
    else:
        # we're gonna do an add/delete to generate an unused rule id
        var id = node.add_rule(rule)
        node.delete_rule(id)

        # now set that in the rule so that the undo/redo works properly
        rule.id = id
        undo_redo.create_action(str("HexMapAutoTiled: add rule ", id))
        undo_redo.add_do_method(node, "add_rule", rule)
        undo_redo.add_undo_method(node, "delete_rule", id)
        undo_redo.commit_action()

        %RulesList.selected_id = id
        # reopen the editor so it switches to edit mode
        edit_rule(rule)
        %RuleEditor.show_message("[b]Added rule " + str(id) + "[/b]")

func _on_rule_editor_cancel():
    %RuleEditor.clear()
    %RulesList.selected_id = -1
    %RuleEditor.visible = false
    %Directions.visible = true
    pass

func _on_node_mesh_library_changed():
    %RuleEditor.mesh_library = node.mesh_library
    %RulesList.mesh_library = node.mesh_library

func _on_node_mesh_origin_changed():
    %RuleEditor.mesh_origin = node.get_mesh_origin_vec()

func _on_node_rules_changed():
    %RulesList.rules = node.get_rules()
    %RulesList.order = node.get_rules_order()
    var id = %RulesList.selected_id
    if id == -1:
        return
    
    var rule = node.get_rule(id)
    if rule == null:
        _on_rule_editor_cancel()
    else:
        edit_rule(rule)

func _on_rules_list_delete(id: int):
    # close out the editor if we're deleting the rule being edited
    if %RulesList.selected_id == id:
        _on_rule_editor_cancel()

    var rule = node.get_rule(id)
    var order = node.get_rules_order()
    if rule == null:
        push_error("unable to find original values for rule ", id)
        return
    var undo_redo := editor_plugin.get_undo_redo()
    undo_redo.create_action(str("HexMapAutoTiled: remove rule ", id))
    undo_redo.add_do_method(node, "delete_rule", id)
    undo_redo.add_undo_method(node, "add_rule", rule)
    undo_redo.add_undo_method(node, "set_rules_order", order)
    undo_redo.commit_action()

func _on_rules_list_rule_changed(rule: HexMapTileRule):
    var undo_redo := editor_plugin.get_undo_redo()
    var orig = node.get_rule(rule.id)
    if orig == null:
        push_error("unable to find original values for rule ", rule.id)
        return
    var change = "enable" if rule.enabled else "disable"
    undo_redo.create_action(str("HexMapAutoTiled: ", change, " rule ", rule.id))
    undo_redo.add_do_method(node, "update_rule", rule)
    undo_redo.add_undo_method(node, "update_rule", orig)
    undo_redo.commit_action()
