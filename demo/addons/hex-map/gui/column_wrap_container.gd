@tool
extends Container

func _notification(what: int) -> void:
    match what:
        NOTIFICATION_RESIZED:
            # when the container is resized, our minimum size may have changed
            update_minimum_size()
        NOTIFICATION_SORT_CHILDREN:
            var wrap = _calc_wrap()

            var pos = Vector2()
            var count = 0
            var col = 0
            for child in get_children():
                if not child.visible:
                    continue
                fit_child_in_rect(child, Rect2(pos, wrap.child_size))
                if count < wrap.count - 1:
                    pos.y += wrap.child_size.y
                    count += 1
                else:
                    col += 1
                    count = 0
                    pos = Vector2(wrap.child_size.x * col, 0)
            
func _get_minimum_size() -> Vector2:
    var wrap = _calc_wrap()
    return Vector2(wrap.min_size.x, wrap.min_size.y * wrap.count)

func _calc_wrap():
    # find the largest minimum width/height of all of our children
    var min_width := 0
    var min_height := 0
    var child_count := 0
    for child in get_children():
        if not child.visible:
            continue
        child_count += 1
        var size = child.get_combined_minimum_size()
        if size.y > min_height:
            min_height = size.y
        if size.x > min_width:
            min_width = size.x
    var min_size = Vector2(min_width, min_height)

    # get the visible area in the ScrollContainer ancestor
    var node = self
    while node and not node is ScrollContainer:
        node = node.get_parent()
    var win_size : Vector2 = node.size if node else size

    # calculate some important boundaries
    var visible_rows = max(1, floor(win_size.y / min_size.y))
    var visible_cols = max(1, floor(win_size.x / min_size.x))

    # calculate the number of elements to draw in a column before wrapping to
    # the next column
    var wrap
    if child_count < visible_rows * visible_cols:
        wrap = visible_rows
    else:
        wrap = floor((child_count + visible_cols - 1)/visible_cols)

    # calculate the child size based on the parent area size
    var child_size = min_size
    child_size.x = win_size.x / visible_cols

    return {
        "min_size": min_size,
        "child_size": child_size,
        "count": wrap,
    }
