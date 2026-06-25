## GFTableSelectionModel: 稳定行 ID 驱动的表格选择模型。
##
## 只维护选中行 ID、锚点和选择模式，不关心行如何渲染、排序或过滤。
## 表格视图排序、过滤或重建可见行时，只要 row_id 稳定，选择状态就能保留。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 5.2.0
class_name GFTableSelectionModel
extends RefCounted


# --- 信号 ---

## 选择集合变化后发出。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param selected_ids: 当前选中行 ID 副本。
## [br]
## @schema selected_ids: Array，当前选中行 ID。
signal selection_changed(selected_ids: Array)


# --- 枚举 ---

## 选择模式。
## [br]
## @api public
## [br]
## @since 5.2.0
enum SelectionMode {
	## 不允许选择。
	NONE,
	## 只允许单选。
	SINGLE,
	## 允许多选。
	MULTIPLE,
}


# --- 公共变量 ---

## 当前选择模式。
## [br]
## @api public
## [br]
## @since 5.2.0
var selection_mode: SelectionMode:
	get:
		return _selection_mode
	set(value):
		_set_selection_mode(value)

## 当前范围选择锚点。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @schema anchor_row_id: Variant，最近一次显式选择的行 ID。
var anchor_row_id: Variant = null


# --- 私有变量 ---

var _selection_mode: SelectionMode = SelectionMode.MULTIPLE
var _selected_lookup: Dictionary = {}
var _selected_ids: Array = []


# --- 公共方法 ---

## 清空选择。
## [br]
## @api public
## [br]
## @since 5.2.0
func clear_selection() -> void:
	if _selected_ids.is_empty() and anchor_row_id == null:
		return
	_clear_selection_internal()
	selection_changed.emit(get_selected_ids())


## 设置单个行 ID 的选择状态。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param row_id: 稳定行 ID。
## [br]
## @param selected: 是否选中。
## [br]
## @return 状态发生变化时返回 true。
## [br]
## @schema row_id: Variant，调用方提供的稳定行 ID。
func set_selected(row_id: Variant, selected: bool) -> bool:
	if not _is_valid_row_id(row_id):
		return false
	if selected:
		return _select_row_id(row_id, true)
	return _deselect_row_id(row_id, true)


## 切换单个行 ID 的选择状态。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param row_id: 稳定行 ID。
## [br]
## @return 状态发生变化时返回 true。
## [br]
## @schema row_id: Variant，调用方提供的稳定行 ID。
func toggle_selected(row_id: Variant) -> bool:
	if is_selected(row_id):
		return set_selected(row_id, false)
	return set_selected(row_id, true)


## 用单个行 ID 替换当前选择。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param row_id: 稳定行 ID。
## [br]
## @return 状态发生变化时返回 true。
## [br]
## @schema row_id: Variant，调用方提供的稳定行 ID。
func select_single(row_id: Variant) -> bool:
	if _selection_mode == SelectionMode.NONE:
		return false
	if not _is_valid_row_id(row_id):
		return false

	var changed: bool = false
	if _selected_ids.size() != 1 or _selected_ids[0] != row_id:
		_clear_selection_internal()
		_select_row_id_internal(row_id)
		changed = true
	anchor_row_id = row_id
	if changed:
		selection_changed.emit(get_selected_ids())
	return changed


## 用一组行 ID 替换当前选择。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param row_ids: 稳定行 ID 列表。
## [br]
## @return 状态发生变化时返回 true。
## [br]
## @schema row_ids: Array，调用方提供的稳定行 ID。
func replace_selection(row_ids: Array) -> bool:
	var previous_ids: Array = get_selected_ids()
	_clear_selection_internal()
	if selection_mode != SelectionMode.NONE:
		for row_id: Variant in row_ids:
			if not _is_valid_row_id(row_id):
				continue
			_select_row_id_internal(row_id)
			anchor_row_id = row_id
			if selection_mode == SelectionMode.SINGLE:
				break

	if _arrays_equal(previous_ids, _selected_ids):
		return false
	selection_changed.emit(get_selected_ids())
	return true


## 在有序行 ID 列表中选择范围。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param ordered_row_ids: 当前可见顺序或项目指定顺序中的行 ID。
## [br]
## @param from_row_id: 范围起点。
## [br]
## @param to_row_id: 范围终点。
## [br]
## @param additive: 为 true 时保留现有选择并叠加范围。
## [br]
## @return 状态发生变化时返回 true。
## [br]
## @schema ordered_row_ids: Array，当前顺序中的稳定行 ID。
## [br]
## @schema from_row_id: Variant，范围起点行 ID。
## [br]
## @schema to_row_id: Variant，范围终点行 ID。
func select_range(
	ordered_row_ids: Array,
	from_row_id: Variant,
	to_row_id: Variant,
	additive: bool = false
) -> bool:
	if selection_mode == SelectionMode.NONE:
		return false
	if selection_mode == SelectionMode.SINGLE:
		return select_single(to_row_id)

	var from_index: int = ordered_row_ids.find(from_row_id)
	var to_index: int = ordered_row_ids.find(to_row_id)
	if from_index < 0 or to_index < 0:
		return false

	var previous_ids: Array = get_selected_ids()
	if not additive:
		_clear_selection_internal()

	var start_index: int = mini(from_index, to_index)
	var end_index: int = maxi(from_index, to_index)
	for index: int in range(start_index, end_index + 1):
		_select_row_id_internal(ordered_row_ids[index])
	anchor_row_id = from_row_id

	if _arrays_equal(previous_ids, _selected_ids):
		return false
	selection_changed.emit(get_selected_ids())
	return true


## 移除不存在于 row_ids 中的选择。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param row_ids: 仍然有效的行 ID 列表。
## [br]
## @return 状态发生变化时返回 true。
## [br]
## @schema row_ids: Array，有效稳定行 ID。
func prune_to_row_ids(row_ids: Array) -> bool:
	var allowed_lookup: Dictionary = {}
	for row_id: Variant in row_ids:
		if _is_valid_row_id(row_id):
			allowed_lookup[row_id] = true

	var previous_ids: Array = get_selected_ids()
	var next_ids: Array = []
	_selected_lookup.clear()
	for selected_id: Variant in previous_ids:
		if not allowed_lookup.has(selected_id):
			continue
		next_ids.append(selected_id)
		_selected_lookup[selected_id] = true
	_selected_ids = next_ids
	if not _selected_lookup.has(anchor_row_id):
		anchor_row_id = null

	if _arrays_equal(previous_ids, _selected_ids):
		return false
	selection_changed.emit(get_selected_ids())
	return true


## 判断行 ID 是否已选中。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param row_id: 稳定行 ID。
## [br]
## @return 已选中返回 true。
## [br]
## @schema row_id: Variant，调用方提供的稳定行 ID。
func is_selected(row_id: Variant) -> bool:
	return _selected_lookup.has(row_id)


## 获取选中行 ID 列表副本。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @return 选中行 ID 列表。
## [br]
## @schema return: Array，当前选中行 ID。
func get_selected_ids() -> Array:
	return _selected_ids.duplicate()


## 获取选中数量。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @return 选中行数量。
func get_selected_count() -> int:
	return _selected_ids.size()


## 判断当前是否没有选择。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @return 没有选择时返回 true。
func is_empty() -> bool:
	return _selected_ids.is_empty()


## 获取调试快照。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @return 选择模型状态字典。
## [br]
## @schema return: Dictionary，包含 selection_mode、selected_count、selected_ids 和 anchor_row_id。
func get_debug_snapshot() -> Dictionary:
	return {
		"selection_mode": selection_mode,
		"selected_count": _selected_ids.size(),
		"selected_ids": get_selected_ids(),
		"anchor_row_id": anchor_row_id,
	}


# --- 私有/辅助方法 ---

func _set_selection_mode(value: SelectionMode) -> void:
	if _selection_mode == value:
		return
	_selection_mode = value
	if _selection_mode == SelectionMode.NONE:
		clear_selection()
		return
	if _selection_mode == SelectionMode.SINGLE and _selected_ids.size() > 1:
		var first_selected_id: Variant = _selected_ids[0]
		_clear_selection_internal()
		_select_row_id_internal(first_selected_id)
		selection_changed.emit(get_selected_ids())


func _select_row_id(row_id: Variant, emit_changed: bool) -> bool:
	if _selection_mode == SelectionMode.NONE:
		return false
	if _selection_mode == SelectionMode.SINGLE:
		return select_single(row_id)
	if _selected_lookup.has(row_id):
		anchor_row_id = row_id
		return false

	_select_row_id_internal(row_id)
	anchor_row_id = row_id
	if emit_changed:
		selection_changed.emit(get_selected_ids())
	return true


func _deselect_row_id(row_id: Variant, emit_changed: bool) -> bool:
	if not _selected_lookup.has(row_id):
		return false
	var _lookup_erased: bool = _selected_lookup.erase(row_id)
	var selected_index: int = _selected_ids.find(row_id)
	if selected_index >= 0:
		_selected_ids.remove_at(selected_index)
	if anchor_row_id == row_id:
		anchor_row_id = null
	if emit_changed:
		selection_changed.emit(get_selected_ids())
	return true


func _select_row_id_internal(row_id: Variant) -> void:
	if not _is_valid_row_id(row_id) or _selected_lookup.has(row_id):
		return
	_selected_lookup[row_id] = true
	_selected_ids.append(row_id)


func _clear_selection_internal() -> void:
	_selected_lookup.clear()
	_selected_ids.clear()
	anchor_row_id = null


func _is_valid_row_id(row_id: Variant) -> bool:
	return row_id != null


func _arrays_equal(left_values: Array, right_values: Array) -> bool:
	if left_values.size() != right_values.size():
		return false
	for index: int in range(left_values.size()):
		if left_values[index] != right_values[index]:
			return false
	return true
