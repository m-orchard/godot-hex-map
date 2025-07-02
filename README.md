**Really nice Godot 4 GDExtension for creating 3D hexagonal maps**

This GDExtension is a complete redesign of the Godot GridMap module to support
hexagonal cells.  It provides a basic `HexMapTiled` node for manually placing
tiles in 3D space.
It also includes the `HexMapAutoTiled` node to dynamically place tiles
using user-defined rules.

**The API for this GDExtension is not yet frozen; there are no guarantees of
  backwards compatibility at this time**

The GDScript API differs from GridMap.  Documentation is very sparse at the
moment, but you can find examples of the API in the following locations:
* The demo project [camera script](demo/RayPickerCamera/ray_picker_camera.gd)
* [GUT test cases](demo/test/)
* Editor GUI GDScripts (HexMapAutoTileEditorPlugin bottom panel)[demo/addons/hex_map/gui/auto_tiled_node_editor_bottom_panel.gd]

<img width="1209" alt="Screenshot 2024-10-03 at 6 57 52 PM" src="https://github.com/user-attachments/assets/ddaff96a-e153-496e-912e-a19db70eff58">

## Quick Start

```sh
# clone the repo
git clone --recurse-submodules https://github.com/dmlary/godot-hex-map

# cd into it and build the editor plugin
cd godot-hex-map
scons target=editor

# open the demo project
godot -e ./demo/project.godot
```

## Features
* Rule-based tile placement with `HexMapAutoTiled` node
* Type-based `HexMapInt` node with no visualization beyond visual editor
    * paint cells with a single type
    * `HexMapAutoTiled` node matches its rules against these types
    * useful for setting up enty spawn points
* Hexagonal shaped cells in `HexMapTiled` (https://github.com/godotengine/godot/pull/85890)
* Supports `LightmapGI` for lightmap baking
* Supports NavigationMesh baking
    * Specific tiles in MeshLibrary can be excluded from baking (see demo)
* GDScript `HexMapCellId` cell id helper class for navigating hexagonal space
    * NOTE: due to GDScript limitations, all `HexMapCellId` values are
        **references**; use `duplicate()` to create a unique instance if needed
    * Spatial helpers: `neighbors(distance=1)`, `east()`, `up()`,
        `rotate(steps, center)`
    * Logical helpers: `equals()`
    * Arithmetic helpers: `add()`, `subtract()`, `inverse()`
    * Type helpers:
        * `as_int()`/`from_int()` to use as Dictionary keys, or AStar ids
        * `as_vec()`/`from_vec()` more readable type, used in various API calls
          , such as `get_cells()`, for performance reasons
* `cells_changed` signal that inculdes cell ids for modified cells (https://github.com/godotengine/godot/issues/11855)
    * Includes an Array of changed cells
    * Each cell takes up `HexMapNode.CELL_ARRAY_WIDTH` elements in the array
    * `HexMapNode.CELL_ARRAY_INDEX_VEC` is the offset of the `HexMapCellId` in
      `Vector3i` from the base of the cell entry in the Array
    * `HexMapNode.CELL_ARRAY_INDEX_VALUE` is the offset new value of the cell
      from the base of the cell entry in the array
    * `HexMapNode.CELL_ARRAY_INDEX_ORIENTATION` is the offset of the tile
      orientation for the cell
      from the base of the cell entry in the array
    * Example: [ Vector3i(0,0,0), 1, 0, Vector3i(1,0,1), 10, 2 ]
* Editor improvements
    * Variable selection axis (y-axis editing, camera rotation determines selection snapping)
    * Current tile hiding; allows painting tiles to show when smaller than existing tile
    * Removal of editor menu

## Important Changes
* Hot keys have changed (to be similar to Blender)
    * Can be viewed/changed in `Editor Settings -> General tab -> Hex Map`
        * Not in Shortcuts because [Godot does not support it](https://github.com/godotengine/godot-proposals/issues/2024)
    * Manipulate the Edit Plane
        * Edit Y-Plane: `X`
        * Rotate Edit Plane About Y-Axis Clockwise: `C`
        * Rotate Edit Plane About Y-Axis Counter-Clockwise: `Z`
        * Increment Edit Plane: `E`
        * Decrement Edit Plane: `Q`
    * Manipulate the Editor Cursor
        * Rotate Editor Cursor Clockwise: 'D'
        * Rotate Editor Cursor Counter-Clockwise: 'A'
        * Clear Editor Cursor Rotation: `S`
        * Flip Editor Cursor: `W`
    * Selection Management
        * Create a Selection: `Shift + Left Click + Drag`
        * Clear Selection: `Escape`
        * Clear Selected Cells: `Backspace`
        * Fill Selected Cells: `F`
        * Duplicate Selected Cells: `D`
        * Move Selected Cells: `G`
    * Camera Control
        * Center Cell Under Cursor at Origin: `V`
            * This is a workaround for not being able to move the editor camera
              as a GDExtension [issue](https://github.com/godotengine/godot-proposals/issues/12112)
            * It moves the HexMap node so that the cell under your cursor is at
              the origin, and recenters the camera at the origin
            * **Don't use this if you want to keep a custom translation on your
                HexMap node**
        * Clear any HexMap node translation: `V, V`
* Support for baked per-tile NavigationMesh removed
