@tool
@static_unload
extends SubViewportContainer

# emitted when a cell in the painter is clicked; drag indicates that an active
# drag action is causing the click action
signal cell_clicked(cell_id: HexMapCellId, mouse_button: int, drag: bool)
# emitted when the user uses shortcuts to request a change in the layer being
# edited
signal layer_changed(layer: int)

@export var active_layer := 0 :
    set(value):
        if value == active_layer:
            return
        active_layer = clampi(value, -2, 2)
        _on_active_layer_changed()
@export var tile_mesh : Mesh :
    set(value):
        tile_mesh = value
        %TileMeshInstance3D.mesh = tile_mesh
@export var tile_mesh_transform : Transform3D :
    set(value):
        tile_mesh_transform = value
        %TileMeshInstance3D.transform = value

var cell_instances := {}

class HexCell:
    extends Node3D
    const Math_SQRT3_2 = 0.8660254037844386
   
    # state for a given cell
    # This is an array of `state: String`, followed by `type: Integer`.  The
    # type is only required when `state` is set to "type" or "not_type".
    #
    # @see _on_state_changed for supported state values
    @export var state : Array :
        set(value):
            state = value
            _on_state_changed()

    # toggle whether the cell grid is displayed for this cell
    @export var show_grid := true :
        set(value):
            show_grid = value
            if is_node_ready():
                floor_mesh_instance.visible = value

    # toggle when the cell is being hovered; changes the cell grid color
    @export var hovered := false :
        set(value):
            hovered = value
            if not is_node_ready():
                return
            if hovered:
                floor_mesh_instance \
                    .material_override = grid_mat_hover
            else:
                floor_mesh_instance.material_override = null

    # track the child node we add that shows the floor grid for this cell
    var floor_mesh_instance: MeshInstance3D

    # track the child node that displays the state of this cell
    var state_node: Node3D

    # meshes we use for displaying the various states of a cell
    static var tile_mesh: Mesh = preload("../models/autotiled_rule_tile.obj")
    static var tile_not_mesh: Mesh = preload("../models/autotiled_rule_tile_not.obj")
    static var tile_any_mesh: Mesh = preload("../models/autotiled_rule_tile_any.obj")
    # hot-reload doesn't work properly for static variables.
    # see https://github.com/godotengine/godot/issues/105667
    #
    # rename any one of these to trigger a real reload
    static var grid_mesh: Mesh
    static var grid_mat: StandardMaterial3D
    static var grid_mat_hover: StandardMaterial3D

    static func _static_init() -> void:
        # Grid material 
        var mat := StandardMaterial3D.new()
        mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        mat.disable_fog = true
        mat.disable_receive_shadows = true
        mat.albedo_color = Color.GOLD
        grid_mat = mat

        # hovered
        mat = StandardMaterial3D.new()
        mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        mat.disable_fog = true
        mat.disable_receive_shadows = true
        mat.albedo_color = Color.WHITE
        mat.no_depth_test = true
        grid_mat_hover = mat

        # grid mesh
        var st = SurfaceTool.new()
        st.begin(Mesh.PRIMITIVE_LINE_STRIP)
        st.set_material(grid_mat)
        st.add_vertex(Vector3(0.0, 0, -1.0))
        st.add_vertex(Vector3(-Math_SQRT3_2, 0, -0.5))
        st.add_vertex(Vector3(-Math_SQRT3_2, 0, 0.5))
        st.add_vertex(Vector3(0.0, 0, 1.0))
        st.add_vertex(Vector3(Math_SQRT3_2, 0, 0.5))
        st.add_vertex(Vector3(Math_SQRT3_2, 0, -0.5))
        st.add_vertex(Vector3(0.0, 0, -1.0))
        grid_mesh = st.commit()

    func _ready() -> void:
        floor_mesh_instance = MeshInstance3D.new()
        floor_mesh_instance.mesh = grid_mesh
        floor_mesh_instance.visible = show_grid
        add_child(floor_mesh_instance)

    # update the meshes for this node based on state
    func _on_state_changed():
        if state_node != null:
            remove_child(state_node)
            state_node.queue_free()
            state_node = null
        match state[0]:
            "disabled":
                pass
            "empty":
                state_node = MeshInstance3D.new()
                state_node.mesh = tile_not_mesh
                add_child(state_node)
                pass
            "not_empty":
                state_node = MeshInstance3D.new()
                state_node.mesh = tile_any_mesh
                add_child(state_node)
                pass
            "type":
                var mat := StandardMaterial3D.new()
                mat.albedo_color = state[1]
                state_node = MeshInstance3D.new()
                state_node.mesh = tile_mesh
                state_node.material_override = mat
                add_child(state_node)
            "not_type":
                var mat := StandardMaterial3D.new()
                mat.albedo_color = state[1]
                state_node = MeshInstance3D.new()
                state_node.mesh = tile_mesh
                state_node.material_override = mat
                var decor = MeshInstance3D.new()
                decor.mesh = tile_not_mesh
                state_node.add_child(decor)
                add_child(state_node)

                pass
            _:
                push_error("unsupported cell state ", state)

# camera controls
var y_rot := deg_to_rad(15)
var x_rot := deg_to_rad(45)
var distance := 15.0
var edit_plane := Plane(Vector3.UP)
var cursor_cell := HexMapCellId.new()

# hex map settings
var hex_space := HexMapSpace.new()

func set_hex_space(value: HexMapSpace) -> void:
    hex_space = value

# @param state [Array] see HexCell.state for content description
func set_cell(cell_id: HexMapCellId, state: Array) -> void:
    var cell = cell_instances.get_or_add(cell_id.as_int(), HexCell.new())
    cell.state = state

    # grab the cell scale
    cell.scale = hex_space.get_cell_scale()

    # put the cell node at the bottom of the hex-space node
    cell.position = hex_space.get_cell_center(cell_id)
    cell.position.y -= cell.scale.y/2

    # toggle the grid if it's on the active layer
    cell.show_grid = cell_id.y == active_layer

    if cell.get_parent() == null:
        %CellMeshes.add_child(cell)

func reset() -> void:
    tile_mesh = null
    tile_mesh_transform = Transform3D()
    active_layer = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    mouse_entered.connect(func(): grab_focus())
    _orbit_camera(Vector2())
    _on_active_layer_changed()

func _gui_input(event: InputEvent) -> void:
    var cell_changed = false
    # update cursor cell
    if event is InputEventMouse:
        cell_changed = _update_cursor_cell(event.position)

    # camera controls
    if event is InputEventMouseMotion \
            and event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
        _orbit_camera(event.relative)
    elif event is InputEventMouseButton \
            and event.button_index == MOUSE_BUTTON_WHEEL_UP \
            and event.is_pressed():
        var zoom_factor = 1 + (1.08 - 1) * event.factor
        _scale_camera_distance(1.0/zoom_factor)
    elif event is InputEventMouseButton \
            and event.button_index == MOUSE_BUTTON_WHEEL_DOWN \
            and event.is_pressed():
        var zoom_factor = 1 + (1.08 - 1) * event.factor
        _scale_camera_distance(zoom_factor)

    # painting/erasing
    if event is InputEventMouseButton and event.is_pressed():
        cell_clicked.emit(cursor_cell, event.button_index, false)
    elif event is InputEventMouseMotion:
        if event.button_mask == MOUSE_BUTTON_MASK_LEFT:
            cell_clicked.emit(cursor_cell, MOUSE_BUTTON_MASK_LEFT, true)
        elif event.button_mask == MOUSE_BUTTON_MASK_RIGHT:
            cell_clicked.emit(cursor_cell, MOUSE_BUTTON_MASK_RIGHT, true)

    # layer changes
    if event is InputEventKey && event.is_pressed():
        var editor_settings = EditorInterface.get_editor_settings()
        if editor_settings \
                .get_setting("hex_map/previous_floor") \
                .matches_event(event):
            active_layer -= 1
            accept_event()
        if editor_settings \
                .get_setting("hex_map/next_floor") \
                .matches_event(event):
            active_layer += 1
            accept_event()

func _orbit_camera(relative: Vector2) -> void:
    # adapted from Node3DEditorViewport::_nav_orbit()

    var editor_settings = EditorInterface.get_editor_settings()
    var degrees_per_pixel = editor_settings.get_setting("editors/3d/navigation_feel/orbit_sensitivity");
    var radians_per_pixel = deg_to_rad(degrees_per_pixel);
    var invert_y_axis = editor_settings.get_setting("editors/3d/navigation/invert_y_axis")
    var invert_x_axis = editor_settings.get_setting("editors/3d/navigation/invert_x_axis")

    if invert_y_axis:
        x_rot -= relative.y * radians_per_pixel
    else:
        x_rot += relative.y * radians_per_pixel
    x_rot = clamp(x_rot, -1.57, 1.57)

    if invert_x_axis:
        y_rot -= relative.x * radians_per_pixel
    else:
        y_rot += relative.x * radians_per_pixel

    _update_camera_transform()

func _scale_camera_distance(scale: float) -> void:
    # XXX set distance limits based off HexSpace cell size
    distance = clamp(distance * scale, 2, 4000)
    _update_camera_transform()

func _update_camera_transform():
    # from Node3DEditorViewport::_update_camera
    var camera_transform := Transform3D()
    camera_transform = camera_transform.rotated(Vector3(1, 0, 0), -x_rot)
    camera_transform = camera_transform.rotated(Vector3.UP, -y_rot)
    camera_transform = camera_transform \
        .translated_local(Vector3(0, 0, distance))
    %Camera3D.transform = camera_transform

    var half_fov = deg_to_rad(35)/2
    var height = 2 * distance * tan(half_fov)
    %Camera3D.size = height

func _update_cursor_cell(pos: Vector2) -> Variant:
    var origin = %Camera3D.project_ray_origin(pos)
    var normal = %Camera3D.project_ray_normal(pos)
    var intersect = edit_plane.intersects_ray(origin, normal)
    if not intersect:
        return false
    var cell_id = hex_space.get_cell_id(intersect)
    if cell_id.equals(cursor_cell):
        return false
    cursor_cell = cell_id

    # update hovered state on cells
    var active_key = cursor_cell.as_int()
    for key in cell_instances:
        cell_instances[key].hovered = (key == active_key)

    # hide/show the Tile mesh if the cursor_cell is the origin
    %TileMeshInstance3D.visible = not cursor_cell.equals(HexMapCellId.new())

    return true

func _on_active_layer_changed() -> void:
    for key in cell_instances:
        var cell_id = HexMapCellId.from_int(key)
        cell_instances[key].show_grid = cell_id.y == active_layer
    edit_plane.d = active_layer
    layer_changed.emit(active_layer)
