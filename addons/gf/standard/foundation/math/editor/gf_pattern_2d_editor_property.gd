@tool

# GFPattern2DEditorProperty: 在 Inspector 中用网格编辑 GFPattern2D.cells。
extends EditorProperty


# --- 私有变量 ---

var _root: MarginContainer
var _grid: GridContainer
var _current_cells: Array[Vector2i] = []
var _is_updating: bool = false
var _is_dragging: bool = false
var _drag_value: bool = false


# --- Godot 生命周期方法 ---

func _init() -> void:
	_root = MarginContainer.new()
	add_child(_root)
	_grid = GridContainer.new()
	_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_root.add_child(_grid)


# --- Godot 回调方法 ---

func _update_property() -> void:
	var edited_object: Object = get_edited_object()
	if not (edited_object is GFPattern2D):
		return

	var pattern: GFPattern2D = edited_object
	if pattern == null:
		return

	_is_updating = true
	_rebuild_grid(pattern)
	_is_updating = false


# --- 私有/辅助方法 ---

func _rebuild_grid(pattern: GFPattern2D) -> void:
	for child: Node in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()

	var dimensions: Vector2i = pattern.pattern_dimensions
	_grid.columns = maxi(dimensions.x, 1)
	var cells: Array[Vector2i] = pattern.cells
	_current_cells = []
	_current_cells.append_array(pattern.get_cells())
	for y: int in range(dimensions.y):
		for x: int in range(dimensions.x):
			_grid.add_child(_create_cell_button(Vector2i(x, y), cells))


func _create_cell_button(cell: Vector2i, cells: Array) -> CheckBox:
	var checkbox: CheckBox = CheckBox.new()
	checkbox.focus_mode = Control.FOCUS_NONE
	checkbox.tooltip_text = "%d,%d" % [cell.x, cell.y]
	checkbox.button_pressed = cells.has(cell)
	checkbox.custom_minimum_size = Vector2(22.0, 22.0)
	checkbox.mouse_filter = Control.MOUSE_FILTER_STOP as Control.MouseFilter
	var _connect_result_67: Variant = checkbox.gui_input.connect(_on_cell_gui_input.bind(checkbox, cell))
	var _connect_result_68: Variant = checkbox.mouse_entered.connect(_on_cell_mouse_entered.bind(checkbox, cell))
	var _connect_result_69: Variant = checkbox.toggled.connect(_on_cell_toggled.bind(cell))
	return checkbox


func _make_next_cells(cell: Vector2i, enabled: bool) -> Array[Vector2i]:
	var edited_object: Object = get_edited_object()
	var next_cells: Array[Vector2i] = []
	if not (edited_object is GFPattern2D):
		return next_cells

	next_cells.append_array(_current_cells)
	if enabled:
		if not next_cells.has(cell):
			next_cells.append(cell)
	else:
		next_cells.erase(cell)
	next_cells.sort_custom(func(left: Vector2i, right: Vector2i) -> bool:
		if left.y == right.y:
			return left.x < right.x
		return left.y < right.y
	)
	return next_cells


func _apply_cell_change(cell: Vector2i, enabled: bool) -> void:
	if _is_updating:
		return

	var next_cells: Array[Vector2i] = _make_next_cells(cell, enabled)
	if next_cells == _current_cells:
		return

	_current_cells = next_cells
	emit_changed("cells", next_cells)


func _set_checkbox_pressed(checkbox: CheckBox, enabled: bool) -> void:
	if checkbox.button_pressed == enabled:
		return
	_is_updating = true
	checkbox.button_pressed = enabled
	_is_updating = false


# --- 信号处理函数 ---

func _on_cell_toggled(enabled: bool, cell: Vector2i) -> void:
	if _is_updating:
		return
	_apply_cell_change(cell, enabled)


func _on_cell_gui_input(event: InputEvent, checkbox: CheckBox, cell: Vector2i) -> void:
	if not (event is InputEventMouseButton):
		return

	var mouse_event: InputEventMouseButton = event
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	if mouse_event.pressed:
		_is_dragging = true
		_drag_value = false if mouse_event.ctrl_pressed else not checkbox.button_pressed
		_set_checkbox_pressed(checkbox, _drag_value)
		_apply_cell_change(cell, _drag_value)
		checkbox.accept_event()
	else:
		_is_dragging = false
		checkbox.accept_event()


func _on_cell_mouse_entered(checkbox: CheckBox, cell: Vector2i) -> void:
	if not _is_dragging:
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_is_dragging = false
		return
	_set_checkbox_pressed(checkbox, _drag_value)
	_apply_cell_change(cell, _drag_value)
