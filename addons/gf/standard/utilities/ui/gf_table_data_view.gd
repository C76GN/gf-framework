## GFTableDataView: 通用表格数据视图模型。
##
## 维护行数据、列定义、可见行索引、排序、过滤和单元格提交，
## 供运行时 UI、编辑器 Dock、资源表或配置表工具自行选择渲染方式。
## 它不创建 Control，不规定键鼠交互、主题样式或业务字段含义。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 5.2.0
class_name GFTableDataView
extends RefCounted


# --- 信号 ---

## 行数据集合变化后发出。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param row_count: 当前行数量。
signal rows_changed(row_count: int)

## 可见行集合变化后发出。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param visible_count: 当前可见行数量。
signal view_changed(visible_count: int)

## 过滤文本变化后发出。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param query: 当前过滤文本。
## [br]
## @param visible_count: 当前可见行数量。
signal filter_changed(query: String, visible_count: int)

## 排序设置变化后发出。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param column_id: 当前排序列 ID；为空表示未排序。
## [br]
## @param ascending: 是否升序。
signal sort_changed(column_id: StringName, ascending: bool)

## 单元格成功提交后发出。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param row_index: 源行索引。
## [br]
## @param row_id: 稳定行 ID。
## [br]
## @param column_id: 列 ID。
## [br]
## @param old_value: 旧值。
## [br]
## @param new_value: 新值。
## [br]
## @schema row_id: Variant，提交前的稳定行 ID。
## [br]
## @schema old_value: Variant，提交前的列值。
## [br]
## @schema new_value: Variant，提交后的列值。
signal cell_value_committed(
	row_index: int,
	row_id: Variant,
	column_id: StringName,
	old_value: Variant,
	new_value: Variant
)


# --- 公共变量 ---

## 用作稳定行 ID 的字段键。为空时使用源行索引。
## [br]
## @api public
## [br]
## @since 5.2.0
var row_id_column: StringName = &"id"

## 过滤时是否区分大小写。
## [br]
## @api public
## [br]
## @since 5.2.0
var case_sensitive_filter: bool = false

## 该视图使用的选择模型。
## [br]
## @api public
## [br]
## @since 5.2.0
var selection_model: GFTableSelectionModel = GFTableSelectionModel.new()


# --- 私有变量 ---

var _rows: Array = []
var _columns: Array[GFTableColumnDefinition] = []
var _columns_by_id: Dictionary = {}
var _visible_row_indices: Array[int] = []
var _filter_query: String = ""
var _sort_column_id: StringName = &""
var _sort_ascending: bool = true


# --- 公共方法 ---

## 设置列定义列表。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param column_definitions: 列定义列表；null 项会被忽略。
## [br]
## @schema column_definitions: Array，包含 GFTableColumnDefinition。
func set_columns(column_definitions: Array[GFTableColumnDefinition]) -> void:
	_columns.clear()
	_columns_by_id.clear()
	for column: GFTableColumnDefinition in column_definitions:
		if column == null or column.column_id == &"":
			continue
		_columns.append(column)
		_columns_by_id[column.column_id] = column
	if _sort_column_id != &"" and get_column(_sort_column_id) == null:
		_sort_column_id = &""
	refresh_view()


## 追加列定义。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param column: 列定义。
## [br]
## @return 追加成功返回 true。
func add_column(column: GFTableColumnDefinition) -> bool:
	if column == null or column.column_id == &"":
		return false
	if _columns_by_id.has(column.column_id):
		return false
	_columns.append(column)
	_columns_by_id[column.column_id] = column
	refresh_view()
	return true


## 获取列定义列表副本。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @return 列定义列表。
## [br]
## @schema return: Array，包含 GFTableColumnDefinition。
func get_columns() -> Array[GFTableColumnDefinition]:
	return _columns.duplicate()


## 获取指定列定义。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param column_id: 列 ID。
## [br]
## @return 列定义；不存在时返回 null。
func get_column(column_id: StringName) -> GFTableColumnDefinition:
	var column_value: Variant = GFVariantData.get_option_value(_columns_by_id, column_id)
	if column_value is GFTableColumnDefinition:
		var column: GFTableColumnDefinition = column_value
		return column
	return null


## 设置源行数据。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param row_values: 行数据列表。
## [br]
## @param duplicate_rows: 是否复制 Dictionary / Array 行数据。
## [br]
## @schema row_values: Array，调用方保存的行数据。
func set_rows(row_values: Array, duplicate_rows: bool = false) -> void:
	_rows.clear()
	for row_data: Variant in row_values:
		if duplicate_rows:
			_rows.append(GFVariantData.duplicate_variant(row_data, true, false))
		else:
			_rows.append(row_data)
	refresh_view()
	if selection_model != null:
		var _prune_result: bool = selection_model.prune_to_row_ids(get_row_ids())
	rows_changed.emit(_rows.size())


## 追加源行数据。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param row_data: 行数据。
## [br]
## @return 新行索引。
## [br]
## @schema row_data: Variant，调用方保存的行数据。
func append_row(row_data: Variant) -> int:
	var row_index: int = _rows.size()
	_rows.append(row_data)
	refresh_view()
	rows_changed.emit(_rows.size())
	return row_index


## 移除源行。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param row_index: 源行索引。
## [br]
## @param should_prune_selection: 是否移除已不存在行 ID 的选择。
## [br]
## @return 移除成功返回 true。
func remove_row(row_index: int, should_prune_selection: bool = true) -> bool:
	if not _is_valid_row_index(row_index):
		return false
	_rows.remove_at(row_index)
	refresh_view()
	if should_prune_selection and selection_model != null:
		var _prune_result: bool = selection_model.prune_to_row_ids(get_row_ids())
	rows_changed.emit(_rows.size())
	return true


## 清空所有行数据。
## [br]
## @api public
## [br]
## @since 5.2.0
func clear_rows() -> void:
	if _rows.is_empty():
		return
	_rows.clear()
	refresh_view()
	if selection_model != null:
		selection_model.clear_selection()
	rows_changed.emit(0)


## 获取源行数量。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @return 源行数量。
func get_row_count() -> int:
	return _rows.size()


## 获取可见行数量。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @return 可见行数量。
func get_visible_row_count() -> int:
	return _visible_row_indices.size()


## 获取源行数据。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param row_index: 源行索引。
## [br]
## @return 行数据；索引无效时返回 null。
## [br]
## @schema return: Variant，调用方保存的行数据。
func get_row(row_index: int) -> Variant:
	if not _is_valid_row_index(row_index):
		return null
	return _rows[row_index]


## 获取可见行数据。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param visible_row_index: 可见行索引。
## [br]
## @return 行数据；索引无效时返回 null。
## [br]
## @schema return: Variant，调用方保存的行数据。
func get_visible_row(visible_row_index: int) -> Variant:
	var row_index: int = get_source_row_index(visible_row_index)
	if row_index < 0:
		return null
	return _rows[row_index]


## 获取可见行对应的源行索引。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param visible_row_index: 可见行索引。
## [br]
## @return 源行索引；无效时返回 -1。
func get_source_row_index(visible_row_index: int) -> int:
	if visible_row_index < 0 or visible_row_index >= _visible_row_indices.size():
		return -1
	return _visible_row_indices[visible_row_index]


## 获取可见行源索引副本。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @return 可见行源索引。
func get_visible_row_indices() -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	var _resize_result: int = result.resize(_visible_row_indices.size())
	for index: int in range(_visible_row_indices.size()):
		result[index] = _visible_row_indices[index]
	return result


## 获取源行稳定 ID。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param row_index: 源行索引。
## [br]
## @return 稳定行 ID；没有字段值时回退为源行索引。
## [br]
## @schema return: Variant，稳定行 ID。
func get_row_id(row_index: int) -> Variant:
	if not _is_valid_row_index(row_index):
		return null
	if row_id_column == &"":
		return row_index
	var row_id: Variant = _read_row_property(_rows[row_index], row_id_column)
	if row_id == null:
		return row_index
	return row_id


## 获取可见行稳定 ID。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param visible_row_index: 可见行索引。
## [br]
## @return 稳定行 ID。
## [br]
## @schema return: Variant，稳定行 ID。
func get_visible_row_id(visible_row_index: int) -> Variant:
	var row_index: int = get_source_row_index(visible_row_index)
	if row_index < 0:
		return null
	return get_row_id(row_index)


## 获取全部源行 ID。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @return 行 ID 列表。
## [br]
## @schema return: Array，全部源行稳定 ID。
func get_row_ids() -> Array:
	var result: Array = []
	for row_index: int in range(_rows.size()):
		result.append(get_row_id(row_index))
	return result


## 获取当前可见顺序中的行 ID。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @return 可见行 ID 列表。
## [br]
## @schema return: Array，当前可见顺序中的稳定行 ID。
func get_visible_row_ids() -> Array:
	var result: Array = []
	for row_index: int in _visible_row_indices:
		result.append(get_row_id(row_index))
	return result


## 设置过滤文本。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param query: 过滤文本；空字符串显示全部行。
func set_filter_query(query: String) -> void:
	if _filter_query == query:
		return
	_filter_query = query
	refresh_view()
	filter_changed.emit(_filter_query, _visible_row_indices.size())


## 获取当前过滤文本。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @return 过滤文本。
func get_filter_query() -> String:
	return _filter_query


## 按列排序。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param column_id: 排序列 ID。
## [br]
## @param ascending: 是否升序。
## [br]
## @return 排序设置成功返回 true。
func sort_by_column(column_id: StringName, ascending: bool = true) -> bool:
	var column: GFTableColumnDefinition = get_column(column_id)
	if column == null or not column.sortable:
		return false
	_sort_column_id = column_id
	_sort_ascending = ascending
	refresh_view()
	sort_changed.emit(_sort_column_id, _sort_ascending)
	return true


## 清除排序。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @return 排序状态发生变化时返回 true。
func clear_sort() -> bool:
	if _sort_column_id == &"":
		return false
	_sort_column_id = &""
	refresh_view()
	sort_changed.emit(_sort_column_id, _sort_ascending)
	return true


## 获取当前排序列 ID。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @return 排序列 ID；为空表示未排序。
func get_sort_column_id() -> StringName:
	return _sort_column_id


## 当前排序是否升序。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @return 升序时返回 true。
func is_sort_ascending() -> bool:
	return _sort_ascending


## 重新构建可见行索引。
## [br]
## @api public
## [br]
## @since 5.2.0
func refresh_view() -> void:
	_rebuild_visible_row_indices()
	view_changed.emit(_visible_row_indices.size())


## 获取源行单元格值。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param row_index: 源行索引。
## [br]
## @param column_id: 列 ID。
## [br]
## @return 单元格值。
## [br]
## @schema return: Variant，单元格值。
func get_cell_value(row_index: int, column_id: StringName) -> Variant:
	if not _is_valid_row_index(row_index):
		return null
	var column: GFTableColumnDefinition = get_column(column_id)
	if column == null:
		return null
	return column.read_value(_rows[row_index])


## 提交源行单元格值。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param row_index: 源行索引。
## [br]
## @param column_id: 列 ID。
## [br]
## @param new_value: 新值。
## [br]
## @return 提交成功返回 true。
## [br]
## @schema new_value: Variant，要提交的新值。
func commit_cell_value(row_index: int, column_id: StringName, new_value: Variant) -> bool:
	var report: Dictionary = _commit_cell_value_internal(row_index, column_id, new_value)
	if not GFVariantData.get_option_bool(report, "ok"):
		return false

	if GFVariantData.get_option_bool(report, "changed"):
		refresh_view()
		_emit_cell_value_committed(report)
	return true


## 提交可见行单元格值。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param visible_row_index: 可见行索引。
## [br]
## @param column_id: 列 ID。
## [br]
## @param new_value: 新值。
## [br]
## @return 提交成功返回 true。
## [br]
## @schema new_value: Variant，要提交的新值。
func commit_visible_cell_value(
	visible_row_index: int,
	column_id: StringName,
	new_value: Variant
) -> bool:
	var row_index: int = get_source_row_index(visible_row_index)
	if row_index < 0:
		return false
	return commit_cell_value(row_index, column_id, new_value)


## 批量提交源行单元格值。
## [br]
## 该方法会先处理所有变更，再在有实际写入时统一刷新视图并发送单元格提交信号；
## 它不是事务，部分失败不会回滚已成功的变更。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param changes: 单元格变更数组；每项包含 row_index、column_id 与 new_value。
## [br]
## @return 批量提交报告。
## [br]
## @schema changes: Array[Dictionary]，每项包含 row_index: int、column_id: StringName/String、new_value: Variant。
## [br]
## @schema return: Dictionary，包含 ok、requested_count、applied_count、unchanged_count、failed_count、committed 和 errors。
func commit_cell_values(changes: Array[Dictionary]) -> Dictionary:
	return _commit_cell_value_changes(changes, false)


## 批量提交可见行单元格值。
## [br]
## 可见行索引会在任何写入发生前解析为源行索引，避免排序或过滤重建导致同一批变更漂移。
## 该方法不是事务，部分失败不会回滚已成功的变更。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param changes: 单元格变更数组；每项包含 visible_row_index、column_id 与 new_value。
## [br]
## @return 批量提交报告。
## [br]
## @schema changes: Array[Dictionary]，每项包含 visible_row_index: int、column_id: StringName/String、new_value: Variant。
## [br]
## @schema return: Dictionary，包含 ok、requested_count、applied_count、unchanged_count、failed_count、committed 和 errors。
func commit_visible_cell_values(changes: Array[Dictionary]) -> Dictionary:
	return _commit_cell_value_changes(changes, true)


## 描述当前可见行。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param visible_row_index: 可见行索引。
## [br]
## @return 可见行摘要。
## [br]
## @schema return: Dictionary，包含 ok、row_index、visible_row_index、row_id、selected 和 values。
func describe_visible_row(visible_row_index: int) -> Dictionary:
	var row_index: int = get_source_row_index(visible_row_index)
	return _describe_row(row_index, visible_row_index, { "include_hidden_columns": true })


## 描述源行。
## [br]
## 返回结构面向调试、导出、编辑器表格或虚拟列表渲染，不附带具体 Control 或文件格式语义。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param row_index: 源行索引。
## [br]
## @param options: 描述选项。
## [br]
## @return 行摘要。
## [br]
## @schema options: Dictionary，可包含 include_values: bool、include_hidden_columns: bool、include_row_data: bool、copy_values: bool。
## [br]
## @schema return: Dictionary，包含 ok、row_index、visible_row_index、row_id、selected、values 和可选 row_data。
func describe_row(row_index: int, options: Dictionary = {}) -> Dictionary:
	var visible_row_index: int = _find_visible_row_index(row_index)
	return _describe_row(row_index, visible_row_index, options)


## 描述当前表格视图。
## [br]
## 默认只导出当前可见行和可见列；调用方可以通过 options 请求源行、隐藏列或原始行数据。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param options: 描述选项。
## [br]
## @return 视图摘要。
## [br]
## @schema options: Dictionary，可包含 visible_only: bool、include_values: bool、include_columns: bool、include_hidden_columns: bool、include_row_data: bool、copy_values: bool。
## [br]
## @schema return: Dictionary，包含 row_count、visible_count、column_count、filter_query、sort_column_id、sort_ascending、visible_only、columns 和 rows。
func describe_view(options: Dictionary = {}) -> Dictionary:
	var visible_only: bool = GFVariantData.get_option_bool(options, "visible_only", true)
	var include_columns: bool = GFVariantData.get_option_bool(options, "include_columns", true)
	var rows: Array[Dictionary] = []
	if visible_only:
		for visible_index: int in range(_visible_row_indices.size()):
			var row_index: int = _visible_row_indices[visible_index]
			rows.append(_describe_row(row_index, visible_index, options))
	else:
		var visible_row_indices_by_source: Dictionary = _make_visible_row_index_map()
		for row_index: int in range(_rows.size()):
			var visible_row_index: int = visible_row_indices_by_source.get(row_index, -1)
			rows.append(_describe_row(row_index, visible_row_index, options))
	return {
		"row_count": _rows.size(),
		"visible_count": _visible_row_indices.size(),
		"column_count": _columns.size(),
		"filter_query": _filter_query,
		"sort_column_id": _sort_column_id,
		"sort_ascending": _sort_ascending,
		"visible_only": visible_only,
		"columns": _describe_columns(options) if include_columns else [],
		"rows": rows,
	}


## 移除已不存在源行中的选择。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param visible_only: 为 true 时只保留当前可见行选择。
## [br]
## @return 选择发生变化时返回 true。
func prune_selection(visible_only: bool = false) -> bool:
	if selection_model == null:
		return false
	var valid_ids: Array = get_visible_row_ids() if visible_only else get_row_ids()
	return selection_model.prune_to_row_ids(valid_ids)


## 获取调试快照。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @return 数据视图状态字典。
## [br]
## @schema return: Dictionary，包含 row_count、visible_count、column_count、filter_query、sort_column_id 和 sort_ascending。
func get_debug_snapshot() -> Dictionary:
	return {
		"row_count": _rows.size(),
		"visible_count": _visible_row_indices.size(),
		"column_count": _columns.size(),
		"filter_query": _filter_query,
		"sort_column_id": _sort_column_id,
		"sort_ascending": _sort_ascending,
	}


# --- 私有/辅助方法 ---

func _describe_row(row_index: int, visible_row_index: int, options: Dictionary) -> Dictionary:
	if not _is_valid_row_index(row_index):
		return {
			"ok": false,
			"row_index": row_index,
			"visible_row_index": visible_row_index,
		}

	var copy_values: bool = GFVariantData.get_option_bool(options, "copy_values", true)
	var include_values: bool = GFVariantData.get_option_bool(options, "include_values", true)
	var include_row_data: bool = GFVariantData.get_option_bool(options, "include_row_data", false)
	var row_data: Variant = _rows[row_index]
	var row_id: Variant = get_row_id(row_index)
	var result: Dictionary = {
		"ok": true,
		"row_index": row_index,
		"visible_row_index": visible_row_index,
		"row_id": _copy_snapshot_value(row_id, copy_values),
		"selected": selection_model != null and selection_model.is_selected(row_id),
	}
	if include_values:
		result["values"] = _describe_row_values(row_data, options)
	if include_row_data:
		result["row_data"] = _copy_snapshot_value(row_data, copy_values)
	return result


func _describe_row_values(row_data: Variant, options: Dictionary) -> Dictionary:
	var copy_values: bool = GFVariantData.get_option_bool(options, "copy_values", true)
	var include_hidden_columns: bool = GFVariantData.get_option_bool(options, "include_hidden_columns", false)
	var values: Dictionary = {}
	for column: GFTableColumnDefinition in _columns:
		if column == null:
			continue
		if not include_hidden_columns and not column.visible:
			continue
		values[column.column_id] = _copy_snapshot_value(column.read_value(row_data), copy_values)
	return values


func _describe_columns(options: Dictionary) -> Array[Dictionary]:
	var include_hidden_columns: bool = GFVariantData.get_option_bool(options, "include_hidden_columns", false)
	var result: Array[Dictionary] = []
	for column: GFTableColumnDefinition in _columns:
		if column == null:
			continue
		if not include_hidden_columns and not column.visible:
			continue
		result.append(column.describe())
	return result


func _copy_snapshot_value(value: Variant, copy_values: bool) -> Variant:
	if not copy_values:
		return value
	return GFVariantData.duplicate_variant(value, true, false)


func _find_visible_row_index(row_index: int) -> int:
	for visible_index: int in range(_visible_row_indices.size()):
		if _visible_row_indices[visible_index] == row_index:
			return visible_index
	return -1


func _make_visible_row_index_map() -> Dictionary:
	var result: Dictionary = {}
	for visible_index: int in range(_visible_row_indices.size()):
		result[_visible_row_indices[visible_index]] = visible_index
	return result


func _commit_cell_value_changes(changes: Array[Dictionary], use_visible_rows: bool) -> Dictionary:
	var committed: Array[Dictionary] = []
	var changed_reports: Array[Dictionary] = []
	var errors: Array[Dictionary] = []

	for change_index: int in range(changes.size()):
		var change: Dictionary = changes[change_index]
		var column_id: StringName = GFVariantData.get_option_string_name(change, "column_id", &"")
		var row_index: int = -1
		var visible_row_index: int = -1
		if use_visible_rows:
			visible_row_index = GFVariantData.get_option_int(change, "visible_row_index", -1)
			if visible_row_index < 0 or visible_row_index >= _visible_row_indices.size():
				errors.append(_make_commit_error(
					change_index,
					&"invalid_visible_row_index",
					-1,
					column_id,
					{ "visible_row_index": visible_row_index }
				))
				continue
			row_index = _visible_row_indices[visible_row_index]
		else:
			row_index = GFVariantData.get_option_int(change, "row_index", -1)

		if not _has_option_key(change, &"new_value"):
			var missing_value_context: Dictionary = {}
			if use_visible_rows:
				missing_value_context["visible_row_index"] = visible_row_index
			errors.append(_make_commit_error(
				change_index,
				&"missing_new_value",
				row_index,
				column_id,
				missing_value_context
			))
			continue

		var new_value: Variant = GFVariantData.get_option_value(change, "new_value")
		var report: Dictionary = _commit_cell_value_internal(row_index, column_id, new_value)
		report["index"] = change_index
		if use_visible_rows:
			report["visible_row_index"] = visible_row_index

		if GFVariantData.get_option_bool(report, "ok"):
			committed.append(report)
			if GFVariantData.get_option_bool(report, "changed"):
				changed_reports.append(report)
		else:
			var reason: StringName = GFVariantData.get_option_string_name(report, "reason", &"commit_failed")
			var failure_context: Dictionary = {
				"message": GFVariantData.get_option_string(report, "message", String(reason)),
			}
			if use_visible_rows:
				failure_context["visible_row_index"] = visible_row_index
			errors.append(_make_commit_error(
				change_index,
				reason,
				row_index,
				column_id,
				failure_context
			))

	if not changed_reports.is_empty():
		refresh_view()
		for report: Dictionary in changed_reports:
			_emit_cell_value_committed(report)

	return _make_commit_batch_result(changes.size(), committed, errors)


func _commit_cell_value_internal(row_index: int, column_id: StringName, new_value: Variant) -> Dictionary:
	if not _is_valid_row_index(row_index):
		return _make_cell_commit_failure(row_index, column_id, &"invalid_row_index")
	var column: GFTableColumnDefinition = get_column(column_id)
	if column == null:
		return _make_cell_commit_failure(row_index, column_id, &"unknown_column")
	if not column.editable:
		return _make_cell_commit_failure(row_index, column_id, &"column_not_editable")

	var row_data: Variant = _rows[row_index]
	var previous_row_id: Variant = get_row_id(row_index)
	var old_value: Variant = column.read_value(row_data)
	if old_value == new_value:
		return _make_cell_commit_success(row_index, previous_row_id, previous_row_id, column_id, old_value, new_value, false)
	if not column.write_value(row_data, new_value):
		return _make_cell_commit_failure(row_index, column_id, &"write_failed")

	var next_row_id: Variant = get_row_id(row_index)
	_preserve_selection_after_row_id_change(previous_row_id, next_row_id)
	return _make_cell_commit_success(row_index, previous_row_id, next_row_id, column_id, old_value, new_value, true)


func _emit_cell_value_committed(report: Dictionary) -> void:
	cell_value_committed.emit(
		GFVariantData.get_option_int(report, "row_index", -1),
		GFVariantData.get_option_value(report, "row_id"),
		GFVariantData.get_option_string_name(report, "column_id", &""),
		GFVariantData.get_option_value(report, "old_value"),
		GFVariantData.get_option_value(report, "new_value")
	)


func _make_commit_batch_result(
	requested_count: int,
	committed: Array[Dictionary],
	errors: Array[Dictionary]
) -> Dictionary:
	var applied_count: int = 0
	for report: Dictionary in committed:
		if GFVariantData.get_option_bool(report, "changed"):
			applied_count += 1
	var unchanged_count: int = committed.size() - applied_count
	return {
		"ok": errors.is_empty(),
		"requested_count": requested_count,
		"applied_count": applied_count,
		"unchanged_count": unchanged_count,
		"failed_count": errors.size(),
		"committed": committed,
		"errors": errors,
	}


func _make_cell_commit_success(
	row_index: int,
	row_id: Variant,
	next_row_id: Variant,
	column_id: StringName,
	old_value: Variant,
	new_value: Variant,
	changed: bool
) -> Dictionary:
	return {
		"ok": true,
		"changed": changed,
		"row_index": row_index,
		"row_id": row_id,
		"next_row_id": next_row_id,
		"column_id": column_id,
		"old_value": old_value,
		"new_value": new_value,
	}


func _make_cell_commit_failure(row_index: int, column_id: StringName, reason: StringName) -> Dictionary:
	return {
		"ok": false,
		"row_index": row_index,
		"column_id": column_id,
		"reason": reason,
		"message": String(reason),
	}


func _make_commit_error(
	change_index: int,
	reason: StringName,
	row_index: int,
	column_id: StringName,
	extra_fields: Dictionary = {}
) -> Dictionary:
	var error: Dictionary = {
		"index": change_index,
		"reason": reason,
		"message": GFVariantData.get_option_string(extra_fields, "message", String(reason)),
		"row_index": row_index,
		"column_id": column_id,
	}
	if _has_option_key(extra_fields, &"visible_row_index"):
		error["visible_row_index"] = GFVariantData.get_option_int(extra_fields, "visible_row_index", -1)
	return error


func _has_option_key(options: Dictionary, key: Variant) -> bool:
	if options.has(key):
		return true
	if key is StringName:
		var key_name: StringName = key
		return options.has(String(key_name))
	if key is String:
		var key_text: String = key
		return options.has(StringName(key_text))
	return false


func _rebuild_visible_row_indices() -> void:
	_visible_row_indices.clear()
	for row_index: int in range(_rows.size()):
		if _row_matches_filter(row_index):
			_visible_row_indices.append(row_index)
	if _sort_column_id != &"":
		_visible_row_indices.sort_custom(_compare_visible_row_indices)


func _row_matches_filter(row_index: int) -> bool:
	if _filter_query.is_empty():
		return true
	var row_data: Variant = _rows[row_index]
	for column: GFTableColumnDefinition in _columns:
		if column == null or not column.visible:
			continue
		if column.matches_query(row_data, _filter_query, case_sensitive_filter):
			return true
	return false


func _compare_visible_row_indices(left_index: int, right_index: int) -> bool:
	var column: GFTableColumnDefinition = get_column(_sort_column_id)
	if column == null:
		return left_index < right_index

	var left_row: Variant = _rows[left_index]
	var right_row: Variant = _rows[right_index]
	var compare_result: int = column.compare_values(
		column.read_value(left_row),
		column.read_value(right_row),
		left_row,
		right_row
	)
	if compare_result == 0:
		return left_index < right_index
	return compare_result < 0 if _sort_ascending else compare_result > 0


func _read_row_property(row_data: Variant, property_key: StringName) -> Variant:
	if row_data is Dictionary:
		var dictionary: Dictionary = row_data
		return GFVariantData.get_option_value(dictionary, property_key)
	if row_data is Object:
		var object_ref: Object = row_data
		for property_info: Dictionary in object_ref.get_property_list():
			var raw_property_name: Variant = GFVariantData.get_option_value(property_info, "name")
			if raw_property_name is String or raw_property_name is StringName:
				var property_name: StringName = GFVariantData.to_string_name(raw_property_name)
				if property_name == property_key:
					return object_ref.get(property_key)
	return null


func _preserve_selection_after_row_id_change(previous_row_id: Variant, next_row_id: Variant) -> void:
	if selection_model == null or previous_row_id == next_row_id:
		return
	if not selection_model.is_selected(previous_row_id):
		return
	var _deselect_result: bool = selection_model.set_selected(previous_row_id, false)
	var _select_result: bool = selection_model.set_selected(next_row_id, true)


func _is_valid_row_index(row_index: int) -> bool:
	return row_index >= 0 and row_index < _rows.size()
