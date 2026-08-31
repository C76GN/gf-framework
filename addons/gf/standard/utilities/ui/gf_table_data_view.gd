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

## 可见行集合成功提交后发出。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param view_revision: 单调递增的已提交投影 revision。
## [br]
## @param visible_count: 当前可见行数量。
signal view_changed(view_revision: int, visible_count: int)

## 候选投影未提交时发出。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param result: 保留 prior projection 的类型化失败结果。
signal view_rebuild_failed(result: GFTableViewRebuildResult)

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


# --- 常量 ---

## 单个表格允许注册的命名行谓词上限。
## [br]
## @api public
## [br]
## @since 11.0.0
const MAX_ROW_PREDICATE_COUNT: int = 64


# --- 私有变量 ---

var _row_id_column: StringName = &"id"
var _case_sensitive_filter: bool = false
var _selection_model: GFTableSelectionModel = GFTableSelectionModel.new()
var _rows: Array = []
var _columns: Array[GFTableColumnDefinition] = []
var _columns_by_id: Dictionary = {}
var _visible_row_indices: Array[int] = []
var _filter_query: String = ""
var _sort_column_id: StringName = &""
var _sort_ascending: bool = true
var _row_predicates: Array[GFTableRowPredicateRegistration] = []
var _row_predicates_by_id: Dictionary = {}
var _view_revision: int = 0
var _last_view_rebuild_result: GFTableViewRebuildResult = null
var _view_rebuild_in_progress: bool = false
var _reentrant_rebuild_attempted: bool = false
var _state_publication_in_progress: bool = false


# --- 公共方法 ---

## 事务式设置稳定行 ID 字段键。
## [br]
## 新字段键会先参与完整候选投影；失败时保留旧字段键、投影、选择模型与 revision。
## 成功时按同一源行迁移稳定选择和范围锚点。空字段键表示使用源行索引。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param column_id: 新的稳定行 ID 字段键；为空时使用源行索引。
## [br]
## @return 类型化投影重建结果。
func set_row_id_column(column_id: StringName) -> GFTableViewRebuildResult:
	var reentrant_failure: GFTableViewRebuildResult = _reject_reentrant_rebuild_request()
	if reentrant_failure != null:
		return reentrant_failure
	if _row_id_column == column_id:
		return _publish_rebuild_success(false, 0, 0)
	var build_report: Dictionary = _try_build_projection(
		_rows,
		_columns,
		_columns_by_id,
		_filter_query,
		_sort_column_id,
		_sort_ascending,
		_row_predicates,
		column_id,
		_case_sensitive_filter,
		true,
		_row_id_column
	)
	if not GFVariantData.get_option_bool(build_report, "ok"):
		return _publish_rebuild_failure(_get_build_failure(build_report))
	var selected_ids_before: Array = _selection_model.get_selected_ids()
	var anchor_before: Variant = _selection_model.anchor_row_id
	var row_id_transitions: Array = GFVariantData.get_option_array(
		build_report,
		"row_id_transitions"
	)
	var mapped_selected_ids: Array = _map_selected_row_ids(
		selected_ids_before,
		row_id_transitions
	)
	var mapped_anchor: Variant = _map_row_id(anchor_before, row_id_transitions)
	_state_publication_in_progress = true
	_row_id_column = column_id
	var result: GFTableViewRebuildResult = _commit_projection_state(build_report)
	var _selection_result: bool = _selection_model.replace_selection_with_anchor(
		mapped_selected_ids,
		mapped_anchor
	)
	view_changed.emit(_view_revision, _visible_row_indices.size())
	_state_publication_in_progress = false
	return result


## 获取稳定行 ID 字段键。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 当前稳定行 ID 字段键；为空时使用源行索引。
func get_row_id_column() -> StringName:
	return _row_id_column


## 事务式设置文本过滤是否区分大小写。
## [br]
## 新设置会先参与完整候选投影；失败时保留旧设置、投影、选择模型与 revision。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param case_sensitive: 为 true 时区分大小写。
## [br]
## @return 类型化投影重建结果。
func set_filter_case_sensitive(case_sensitive: bool) -> GFTableViewRebuildResult:
	var reentrant_failure: GFTableViewRebuildResult = _reject_reentrant_rebuild_request()
	if reentrant_failure != null:
		return reentrant_failure
	if _case_sensitive_filter == case_sensitive:
		return _publish_rebuild_success(false, 0, 0)
	var build_report: Dictionary = _try_build_projection(
		_rows,
		_columns,
		_columns_by_id,
		_filter_query,
		_sort_column_id,
		_sort_ascending,
		_row_predicates,
		_row_id_column,
		case_sensitive
	)
	if not GFVariantData.get_option_bool(build_report, "ok"):
		return _publish_rebuild_failure(_get_build_failure(build_report))
	_state_publication_in_progress = true
	_case_sensitive_filter = case_sensitive
	var result: GFTableViewRebuildResult = _commit_projection_state(build_report)
	view_changed.emit(_view_revision, _visible_row_indices.size())
	_state_publication_in_progress = false
	return result


## 查询文本过滤是否区分大小写。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 区分大小写时返回 true。
func is_filter_case_sensitive() -> bool:
	return _case_sensitive_filter


## 事务式替换该视图使用的选择模型。
## [br]
## 新模型只会在完整候选投影成功后成为权威选择模型，并在提交态中按当前行 ID 修剪。
## 失败时不会修改旧模型、新模型、投影或 revision。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param model: 非空选择模型。
## [br]
## @return 类型化投影重建结果。
func set_selection_model(model: GFTableSelectionModel) -> GFTableViewRebuildResult:
	var reentrant_failure: GFTableViewRebuildResult = _reject_reentrant_rebuild_request()
	if reentrant_failure != null:
		return reentrant_failure
	if model == null:
		return _publish_rebuild_failure(_make_rebuild_failure(
			&"invalid_selection_model",
			"Table selection model cannot be null."
		))
	if is_same(_selection_model, model):
		return _publish_rebuild_success(false, 0, 0)
	var build_report: Dictionary = _try_build_projection(
		_rows,
		_columns,
		_columns_by_id,
		_filter_query,
		_sort_column_id,
		_sort_ascending,
		_row_predicates,
		_row_id_column,
		_case_sensitive_filter
	)
	if not GFVariantData.get_option_bool(build_report, "ok"):
		return _publish_rebuild_failure(_get_build_failure(build_report))
	_state_publication_in_progress = true
	_selection_model = model
	var result: GFTableViewRebuildResult = _commit_projection_state(build_report)
	var _prune_result: bool = _selection_model.prune_to_row_ids(get_row_ids())
	view_changed.emit(_view_revision, _visible_row_indices.size())
	_state_publication_in_progress = false
	return result


## 获取该视图使用的选择模型。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 当前非空选择模型。
func get_selection_model() -> GFTableSelectionModel:
	return _selection_model

## 设置列定义列表。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param column_definitions: 列定义列表；null 项会被忽略。
## [br]
## @schema column_definitions: Array，包含 GFTableColumnDefinition。
## [br]
## @return 类型化投影重建结果；失败时保留原列与 prior projection。
func set_columns(
	column_definitions: Array[GFTableColumnDefinition]
) -> GFTableViewRebuildResult:
	var reentrant_failure: GFTableViewRebuildResult = _reject_reentrant_rebuild_request()
	if reentrant_failure != null:
		return reentrant_failure
	var next_columns: Array[GFTableColumnDefinition] = []
	var next_columns_by_id: Dictionary = {}
	for column: GFTableColumnDefinition in column_definitions:
		if column == null or column.column_id == &"":
			continue
		next_columns.append(column)
		next_columns_by_id[column.column_id] = column
	var next_sort_column_id: StringName = _sort_column_id
	if next_sort_column_id != &"" and not next_columns_by_id.has(next_sort_column_id):
		next_sort_column_id = &""
	var build_report: Dictionary = _try_build_projection(
		_rows,
		next_columns,
		next_columns_by_id,
		_filter_query,
		next_sort_column_id,
		_sort_ascending,
		_row_predicates,
		_row_id_column,
		_case_sensitive_filter
	)
	if not GFVariantData.get_option_bool(build_report, "ok"):
		return _publish_rebuild_failure(_get_build_failure(build_report))
	_state_publication_in_progress = true
	_columns = next_columns
	_columns_by_id = next_columns_by_id
	_sort_column_id = next_sort_column_id
	var result: GFTableViewRebuildResult = _commit_projection_state(build_report)
	view_changed.emit(_view_revision, _visible_row_indices.size())
	_state_publication_in_progress = false
	return result


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
	if _reject_reentrant_rebuild_request() != null:
		return false
	if column == null or column.column_id == &"":
		return false
	if _columns_by_id.has(column.column_id):
		return false
	var next_columns: Array[GFTableColumnDefinition] = _columns.duplicate()
	next_columns.append(column)
	var result: GFTableViewRebuildResult = set_columns(next_columns)
	return result.is_successful()


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
## [br]
## @return 类型化投影重建结果；失败时保留原 source、projection 与 selection。
func set_rows(
	row_values: Array,
	duplicate_rows: bool = false
) -> GFTableViewRebuildResult:
	var reentrant_failure: GFTableViewRebuildResult = _reject_reentrant_rebuild_request()
	if reentrant_failure != null:
		return reentrant_failure
	var next_rows: Array = []
	for row_data: Variant in row_values:
		if duplicate_rows:
			next_rows.append(GFVariantData.duplicate_variant(row_data, true, false))
		else:
			next_rows.append(row_data)
	var build_report: Dictionary = _try_build_projection(
		next_rows,
		_columns,
		_columns_by_id,
		_filter_query,
		_sort_column_id,
		_sort_ascending,
		_row_predicates,
		_row_id_column,
		_case_sensitive_filter
	)
	if not GFVariantData.get_option_bool(build_report, "ok"):
		return _publish_rebuild_failure(_get_build_failure(build_report))
	_state_publication_in_progress = true
	_rows = next_rows
	var result: GFTableViewRebuildResult = _commit_projection_state(build_report)
	var _prune_result: bool = _selection_model.prune_to_row_ids(get_row_ids())
	view_changed.emit(_view_revision, _visible_row_indices.size())
	rows_changed.emit(_rows.size())
	_state_publication_in_progress = false
	return result


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
	if _reject_reentrant_rebuild_request() != null:
		return -1
	var row_index: int = _rows.size()
	var next_rows: Array = _rows.duplicate()
	next_rows.append(row_data)
	var build_report: Dictionary = _try_build_projection(
		next_rows,
		_columns,
		_columns_by_id,
		_filter_query,
		_sort_column_id,
		_sort_ascending,
		_row_predicates,
		_row_id_column,
		_case_sensitive_filter
	)
	if not GFVariantData.get_option_bool(build_report, "ok"):
		var _failure_result: GFTableViewRebuildResult = _publish_rebuild_failure(
			_get_build_failure(build_report)
		)
		return -1
	_state_publication_in_progress = true
	_rows = next_rows
	var _rebuild_result: GFTableViewRebuildResult = _commit_projection_state(build_report)
	view_changed.emit(_view_revision, _visible_row_indices.size())
	rows_changed.emit(_rows.size())
	_state_publication_in_progress = false
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
	if _reject_reentrant_rebuild_request() != null:
		return false
	if not _is_valid_row_index(row_index):
		return false
	var next_rows: Array = _rows.duplicate()
	next_rows.remove_at(row_index)
	var build_report: Dictionary = _try_build_projection(
		next_rows,
		_columns,
		_columns_by_id,
		_filter_query,
		_sort_column_id,
		_sort_ascending,
		_row_predicates,
		_row_id_column,
		_case_sensitive_filter
	)
	if not GFVariantData.get_option_bool(build_report, "ok"):
		var _failure_result: GFTableViewRebuildResult = _publish_rebuild_failure(
			_get_build_failure(build_report)
		)
		return false
	_state_publication_in_progress = true
	_rows = next_rows
	var _rebuild_result: GFTableViewRebuildResult = _commit_projection_state(build_report)
	if should_prune_selection:
		var _prune_result: bool = _selection_model.prune_to_row_ids(get_row_ids())
	view_changed.emit(_view_revision, _visible_row_indices.size())
	rows_changed.emit(_rows.size())
	_state_publication_in_progress = false
	return true


## 清空所有行数据。
## [br]
## @api public
## [br]
## @since 5.2.0
func clear_rows() -> void:
	if _reject_reentrant_rebuild_request() != null:
		return
	if _rows.is_empty():
		return
	var next_rows: Array = []
	var build_report: Dictionary = _try_build_projection(
		next_rows,
		_columns,
		_columns_by_id,
		_filter_query,
		_sort_column_id,
		_sort_ascending,
		_row_predicates,
		_row_id_column,
		_case_sensitive_filter
	)
	if not GFVariantData.get_option_bool(build_report, "ok"):
		var _failure_result: GFTableViewRebuildResult = _publish_rebuild_failure(
			_get_build_failure(build_report)
		)
		return
	_state_publication_in_progress = true
	_rows = next_rows
	var _rebuild_result: GFTableViewRebuildResult = _commit_projection_state(build_report)
	_selection_model.clear_selection()
	view_changed.emit(_view_revision, _visible_row_indices.size())
	rows_changed.emit(0)
	_state_publication_in_progress = false


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
	if _row_id_column == &"":
		return row_index
	var row_id: Variant = _read_row_property(_rows[row_index], _row_id_column)
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
## [br]
## @return 类型化投影重建结果；失败时保留旧 query 与 prior projection。
func set_filter_query(query: String) -> GFTableViewRebuildResult:
	var reentrant_failure: GFTableViewRebuildResult = _reject_reentrant_rebuild_request()
	if reentrant_failure != null:
		return reentrant_failure
	if _filter_query == query:
		return _publish_rebuild_success(false, 0, 0)
	var build_report: Dictionary = _try_build_projection(
		_rows,
		_columns,
		_columns_by_id,
		query,
		_sort_column_id,
		_sort_ascending,
		_row_predicates,
		_row_id_column,
		_case_sensitive_filter
	)
	if not GFVariantData.get_option_bool(build_report, "ok"):
		return _publish_rebuild_failure(_get_build_failure(build_report))
	_state_publication_in_progress = true
	_filter_query = query
	var result: GFTableViewRebuildResult = _commit_projection_state(build_report)
	view_changed.emit(_view_revision, _visible_row_indices.size())
	filter_changed.emit(_filter_query, _visible_row_indices.size())
	_state_publication_in_progress = false
	return result


## 获取当前过滤文本。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @return 过滤文本。
func get_filter_query() -> String:
	return _filter_query


## 事务式替换全部命名行谓词。
##
## 注册会先完整校验并按 order 升序、predicate_id 字典序排序，再构建一个候选投影。
## GFTableDataView 保存 predicate_id、order、enabled 与 predicate 引用的框架自有
## metadata 快照；调用方后续修改注册对象不会改变已提交 registry。
## 任一失败都会保留当前 registry、projection、revision 与 selection。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param registrations: 谓词注册定义；提交时复制 metadata。
## [br]
## @schema registrations: Array of GFTableRowPredicateRegistration values.
## [br]
## @return 类型化投影重建结果。
func set_row_predicates(
	registrations: Array[GFTableRowPredicateRegistration]
) -> GFTableViewRebuildResult:
	var reentrant_failure: GFTableViewRebuildResult = _reject_reentrant_rebuild_request()
	if reentrant_failure != null:
		return reentrant_failure
	if registrations.size() > MAX_ROW_PREDICATE_COUNT:
		return _publish_rebuild_failure(_make_rebuild_failure(
			&"predicate_limit_exceeded",
			"Table row predicate registration count exceeds the bounded limit."
		))
	var next_predicates: Array[GFTableRowPredicateRegistration] = (
		_snapshot_row_predicate_registrations(registrations)
	)
	var validation_failure: GFTableViewRebuildResult = _validate_row_predicate_registrations(
		next_predicates
	)
	if validation_failure != null:
		return _publish_rebuild_failure(validation_failure)
	next_predicates.sort_custom(_compare_row_predicate_registrations)
	if _row_predicate_registrations_equal(_row_predicates, next_predicates):
		return _publish_rebuild_success(false, 0, 0)
	var build_report: Dictionary = _try_build_projection(
		_rows,
		_columns,
		_columns_by_id,
		_filter_query,
		_sort_column_id,
		_sort_ascending,
		next_predicates,
		_row_id_column,
		_case_sensitive_filter
	)
	if not GFVariantData.get_option_bool(build_report, "ok"):
		return _publish_rebuild_failure(_get_build_failure(build_report))
	_state_publication_in_progress = true
	_row_predicates = next_predicates
	_row_predicates_by_id = _make_row_predicate_lookup(next_predicates)
	var result: GFTableViewRebuildResult = _commit_projection_state(build_report)
	view_changed.emit(_view_revision, _visible_row_indices.size())
	_state_publication_in_progress = false
	return result


## 事务式注册一个命名行谓词。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param registration: 谓词注册定义；提交时复制 metadata。
## [br]
## @return 类型化投影重建结果。
func register_row_predicate(
	registration: GFTableRowPredicateRegistration
) -> GFTableViewRebuildResult:
	var reentrant_failure: GFTableViewRebuildResult = _reject_reentrant_rebuild_request()
	if reentrant_failure != null:
		return reentrant_failure
	if registration == null:
		return _publish_rebuild_failure(_make_rebuild_failure(
			&"invalid_predicate_registration",
			"Table row predicate registration cannot be null."
		))
	if _row_predicates.size() >= MAX_ROW_PREDICATE_COUNT:
		return _publish_rebuild_failure(_make_rebuild_failure(
			&"predicate_limit_exceeded",
			"Table row predicate registration count exceeds the bounded limit."
		))
	var next_predicates: Array[GFTableRowPredicateRegistration] = _row_predicates.duplicate()
	next_predicates.append(registration)
	return set_row_predicates(next_predicates)


## 事务式移除一个命名行谓词。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param predicate_id: 要移除的稳定谓词 ID。
## [br]
## @return 类型化投影重建结果。
func unregister_row_predicate(predicate_id: StringName) -> GFTableViewRebuildResult:
	var reentrant_failure: GFTableViewRebuildResult = _reject_reentrant_rebuild_request()
	if reentrant_failure != null:
		return reentrant_failure
	if not _row_predicates_by_id.has(predicate_id):
		return _publish_rebuild_failure(_make_rebuild_failure(
			&"unknown_predicate_id",
			"Table row predicate id is not registered.",
			predicate_id
		))
	var next_predicates: Array[GFTableRowPredicateRegistration] = []
	for registration: GFTableRowPredicateRegistration in _row_predicates:
		if registration.get_predicate_id() != predicate_id:
			next_predicates.append(registration)
	return set_row_predicates(next_predicates)


## 事务式设置命名行谓词的启用状态。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param predicate_id: 稳定谓词 ID。
## [br]
## @param enabled: 是否参与候选投影。
## [br]
## @return 类型化投影重建结果。
func set_row_predicate_enabled(
	predicate_id: StringName,
	enabled: bool
) -> GFTableViewRebuildResult:
	var reentrant_failure: GFTableViewRebuildResult = _reject_reentrant_rebuild_request()
	if reentrant_failure != null:
		return reentrant_failure
	var current: GFTableRowPredicateRegistration = get_row_predicate(predicate_id)
	if current == null:
		return _publish_rebuild_failure(_make_rebuild_failure(
			&"unknown_predicate_id",
			"Table row predicate id is not registered.",
			predicate_id
		))
	if current.is_enabled() == enabled:
		return _publish_rebuild_success(false, 0, 0)
	return _replace_row_predicate_registration(GFTableRowPredicateRegistration.create(
		predicate_id,
		current.get_predicate(),
		current.get_order(),
		enabled
	))


## 事务式设置命名行谓词的执行顺序。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param predicate_id: 稳定谓词 ID。
## [br]
## @param order: 新顺序；数值越小越早执行。
## [br]
## @return 类型化投影重建结果。
func set_row_predicate_order(
	predicate_id: StringName,
	order: int
) -> GFTableViewRebuildResult:
	var reentrant_failure: GFTableViewRebuildResult = _reject_reentrant_rebuild_request()
	if reentrant_failure != null:
		return reentrant_failure
	var current: GFTableRowPredicateRegistration = get_row_predicate(predicate_id)
	if current == null:
		return _publish_rebuild_failure(_make_rebuild_failure(
			&"unknown_predicate_id",
			"Table row predicate id is not registered.",
			predicate_id
		))
	if current.get_order() == order:
		return _publish_rebuild_success(false, 0, 0)
	return _replace_row_predicate_registration(GFTableRowPredicateRegistration.create(
		predicate_id,
		current.get_predicate(),
		order,
		current.is_enabled()
	))


## 获取一个命名行谓词注册值。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param predicate_id: 稳定谓词 ID。
## [br]
## @return 独立 metadata 快照；predicate 协议实例保持同一引用，不存在时返回 null。
func get_row_predicate(predicate_id: StringName) -> GFTableRowPredicateRegistration:
	var registration_value: Variant = GFVariantData.get_option_value(
		_row_predicates_by_id,
		predicate_id
	)
	if registration_value is GFTableRowPredicateRegistration:
		var registration: GFTableRowPredicateRegistration = registration_value
		return _snapshot_row_predicate_registration(registration)
	return null


## 获取按确定顺序排列的命名行谓词注册值。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 独立 metadata 快照数组；predicate 协议实例保持同一引用。
## [br]
## @schema return: Array of GFTableRowPredicateRegistration values.
func get_row_predicates() -> Array[GFTableRowPredicateRegistration]:
	return _snapshot_row_predicate_registrations(_row_predicates)


## 获取按确定顺序排列的命名行谓词 ID。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 稳定谓词 ID 数组。
func get_row_predicate_ids() -> Array[StringName]:
	var predicate_ids: Array[StringName] = []
	for registration: GFTableRowPredicateRegistration in _row_predicates:
		predicate_ids.append(registration.get_predicate_id())
	return predicate_ids


## 获取当前已提交投影 revision。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 单调递增 revision。
func get_view_revision() -> int:
	return _view_revision


## 获取最近一次投影事务结果。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 最近结果的隔离副本；尚未执行时返回 revision 0 的成功 no-op。
func get_last_view_rebuild_result() -> GFTableViewRebuildResult:
	if _last_view_rebuild_result == null:
		_last_view_rebuild_result = _make_rebuild_success(false, 0, 0)
	return _last_view_rebuild_result.duplicate_result()


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
	if _reject_reentrant_rebuild_request() != null:
		return false
	var column: GFTableColumnDefinition = get_column(column_id)
	if column == null or not column.sortable:
		return false
	if _sort_column_id == column_id and _sort_ascending == ascending:
		var _noop_result: GFTableViewRebuildResult = _publish_rebuild_success(false, 0, 0)
		return true
	var build_report: Dictionary = _try_build_projection(
		_rows,
		_columns,
		_columns_by_id,
		_filter_query,
		column_id,
		ascending,
		_row_predicates,
		_row_id_column,
		_case_sensitive_filter
	)
	if not GFVariantData.get_option_bool(build_report, "ok"):
		var _failure_result: GFTableViewRebuildResult = _publish_rebuild_failure(
			_get_build_failure(build_report)
		)
		return false
	_state_publication_in_progress = true
	_sort_column_id = column_id
	_sort_ascending = ascending
	var _rebuild_result: GFTableViewRebuildResult = _commit_projection_state(build_report)
	view_changed.emit(_view_revision, _visible_row_indices.size())
	sort_changed.emit(_sort_column_id, _sort_ascending)
	_state_publication_in_progress = false
	return true


## 清除排序。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @return 排序状态发生变化时返回 true。
func clear_sort() -> bool:
	if _reject_reentrant_rebuild_request() != null:
		return false
	if _sort_column_id == &"":
		return false
	var build_report: Dictionary = _try_build_projection(
		_rows,
		_columns,
		_columns_by_id,
		_filter_query,
		&"",
		_sort_ascending,
		_row_predicates,
		_row_id_column,
		_case_sensitive_filter
	)
	if not GFVariantData.get_option_bool(build_report, "ok"):
		var _failure_result: GFTableViewRebuildResult = _publish_rebuild_failure(
			_get_build_failure(build_report)
		)
		return false
	_state_publication_in_progress = true
	_sort_column_id = &""
	var _rebuild_result: GFTableViewRebuildResult = _commit_projection_state(build_report)
	view_changed.emit(_view_revision, _visible_row_indices.size())
	sort_changed.emit(_sort_column_id, _sort_ascending)
	_state_publication_in_progress = false
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
## [br]
## @return 类型化投影重建结果；失败时保留 prior projection。
func refresh_view() -> GFTableViewRebuildResult:
	var reentrant_failure: GFTableViewRebuildResult = _reject_reentrant_rebuild_request()
	if reentrant_failure != null:
		return reentrant_failure
	var build_report: Dictionary = _try_build_projection(
		_rows,
		_columns,
		_columns_by_id,
		_filter_query,
		_sort_column_id,
		_sort_ascending,
		_row_predicates,
		_row_id_column,
		_case_sensitive_filter
	)
	if not GFVariantData.get_option_bool(build_report, "ok"):
		return _publish_rebuild_failure(_get_build_failure(build_report))
	_state_publication_in_progress = true
	var result: GFTableViewRebuildResult = _commit_projection_state(build_report)
	view_changed.emit(_view_revision, _visible_row_indices.size())
	_state_publication_in_progress = false
	return result


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


## 事务式提交源行单元格值。
## [br]
## 写入先发生在隔离候选行上，完整投影成功后才交换权威 source；自定义
## value_setter 与不可隔离的 Object / 脚本 Resource 会在调用任何 setter 前失败关闭。
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
	var batch_report: Dictionary = _commit_cell_value_changes([
		{
			"row_index": row_index,
			"column_id": column_id,
			"new_value": new_value,
		},
	], false)
	return GFVariantData.get_option_bool(batch_report, "ok")


## 事务式提交可见行单元格值。
## [br]
## 写入先发生在隔离候选行上，完整投影成功后才交换权威 source；自定义
## value_setter 与不可隔离的 Object / 脚本 Resource 会在调用任何 setter 前失败关闭。
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
	var batch_report: Dictionary = _commit_cell_value_changes([
		{
			"visible_row_index": visible_row_index,
			"column_id": column_id,
			"new_value": new_value,
		},
	], true)
	return GFVariantData.get_option_bool(batch_report, "ok")


## 批量提交源行单元格值。
## [br]
## 该方法先在隔离候选 rows 上完成全部写入与投影，成功后统一交换并发送信号。
## 任一输入、隔离、写入或投影失败都会回滚整批候选变更。
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
## 任一输入、隔离、写入或投影失败都会回滚整批候选变更。
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
## @schema return: Dictionary，包含 view_revision、row_count、visible_count、column_count、predicate_count、filter_query、sort_column_id、sort_ascending、visible_only、columns 和 rows。
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
		"view_revision": _view_revision,
		"row_count": _rows.size(),
		"visible_count": _visible_row_indices.size(),
		"column_count": _columns.size(),
		"predicate_count": _row_predicates.size(),
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
	var reentrant_failure: GFTableViewRebuildResult = _reject_reentrant_rebuild_request()
	if reentrant_failure != null:
		return false
	var valid_ids: Array = get_visible_row_ids() if visible_only else get_row_ids()
	_state_publication_in_progress = true
	var changed: bool = _selection_model.prune_to_row_ids(valid_ids)
	_state_publication_in_progress = false
	return changed


## 获取调试快照。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @return 数据视图状态字典。
## [br]
## @schema return: Dictionary，包含 view_revision、row_count、visible_count、column_count、predicate_count、enabled_predicate_count、filter_query、sort_column_id、sort_ascending、last_rebuild_ok 和 last_rebuild_error_code。
func get_debug_snapshot() -> Dictionary:
	var enabled_predicate_count: int = 0
	for registration: GFTableRowPredicateRegistration in _row_predicates:
		if registration.is_enabled():
			enabled_predicate_count += 1
	var last_result: GFTableViewRebuildResult = get_last_view_rebuild_result()
	return {
		"view_revision": _view_revision,
		"row_count": _rows.size(),
		"visible_count": _visible_row_indices.size(),
		"column_count": _columns.size(),
		"predicate_count": _row_predicates.size(),
		"enabled_predicate_count": enabled_predicate_count,
		"filter_query": _filter_query,
		"sort_column_id": _sort_column_id,
		"sort_ascending": _sort_ascending,
		"last_rebuild_ok": last_result.is_successful(),
		"last_rebuild_error_code": last_result.get_error_code(),
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
		"selected": _selection_model.is_selected(row_id),
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
	var reentrant_failure: GFTableViewRebuildResult = _reject_reentrant_rebuild_request()
	if reentrant_failure != null:
		return _make_commit_batch_result(changes.size(), [], [
			_make_commit_error(
				-1,
				reentrant_failure.get_error_code(),
				-1,
				&"",
				{ "message": reentrant_failure.get_error_message() }
			),
		])

	var resolved_changes: Array[Dictionary] = []
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

		if not _is_valid_row_index(row_index):
			errors.append(_make_commit_error(
				change_index,
				&"invalid_row_index",
				row_index,
				column_id
			))
			continue
		var column: GFTableColumnDefinition = get_column(column_id)
		if column == null:
			errors.append(_make_commit_error(
				change_index,
				&"unknown_column",
				row_index,
				column_id
			))
			continue
		if not column.editable:
			errors.append(_make_commit_error(
				change_index,
				&"column_not_editable",
				row_index,
				column_id
			))
			continue
		if column.value_setter.is_valid():
			errors.append(_make_commit_error(
				change_index,
				&"non_transactional_value_setter",
				row_index,
				column_id,
				{
					"message": (
						"Custom table value setters are not accepted by the "
						+ "transactional projection path."
					),
				}
			))
			continue
		var resolved_change: Dictionary = {
			"index": change_index,
			"row_index": row_index,
			"column_id": column_id,
			"column": column,
			"new_value": GFVariantData.get_option_value(change, "new_value"),
		}
		if use_visible_rows:
			resolved_change["visible_row_index"] = visible_row_index
		resolved_changes.append(resolved_change)

	if not errors.is_empty():
		return _make_commit_batch_result(changes.size(), [], errors)

	_view_rebuild_in_progress = true
	_reentrant_rebuild_attempted = false
	var next_rows: Array = _rows.duplicate()
	var copied_row_indices: Dictionary = {}
	var staged_reports: Array[Dictionary] = []
	var changed_reports: Array[Dictionary] = []
	var staging_failure: GFTableViewRebuildResult = null
	for resolved_change: Dictionary in resolved_changes:
		var row_index: int = GFVariantData.get_option_int(resolved_change, "row_index", -1)
		var column_id: StringName = GFVariantData.get_option_string_name(
			resolved_change,
			"column_id"
		)
		var column_value: Variant = GFVariantData.get_option_value(resolved_change, "column")
		if not column_value is GFTableColumnDefinition:
			staging_failure = _make_rebuild_failure(
				&"invalid_column",
				"Transactional cell staging received an invalid column definition."
			)
			break
		var column: GFTableColumnDefinition = column_value
		if not copied_row_indices.has(row_index):
			var copy_report: Dictionary = GFTableRowView.duplicate_isolated_variant_for_framework(
				_rows[row_index]
			)
			if _reentrant_rebuild_attempted:
				staging_failure = _make_rebuild_failure(
					&"reentrant_rebuild",
					"Table source isolation callback attempted a recursive mutation."
				)
				break
			if not GFVariantData.get_option_bool(copy_report, "ok"):
				staging_failure = _make_rebuild_failure(
					&"unisolatable_source_row",
					"Table cell transactions require an isolated candidate source row.",
					&"",
					row_index,
					null
				)
				break
			next_rows[row_index] = GFVariantData.get_option_value(copy_report, "value")
			copied_row_indices[row_index] = true
		var candidate_row: Variant = next_rows[row_index]
		var previous_row_id: Variant = _get_row_id_for_state(
			row_index,
			next_rows,
			_row_id_column
		)
		if _reentrant_rebuild_attempted:
			staging_failure = _make_rebuild_failure(
				&"reentrant_rebuild",
				"Table row identity callback attempted a recursive mutation."
			)
			break
		var old_value: Variant = column.read_value(candidate_row)
		if _reentrant_rebuild_attempted:
			staging_failure = _make_rebuild_failure(
				&"reentrant_rebuild",
				"Table column getter attempted a recursive mutation."
			)
			break
		var new_value_report: Dictionary = (
			GFTableRowView.duplicate_isolated_variant_for_framework(
				GFVariantData.get_option_value(resolved_change, "new_value")
			)
		)
		if _reentrant_rebuild_attempted:
			staging_failure = _make_rebuild_failure(
				&"reentrant_rebuild",
				"Table cell value isolation callback attempted a recursive mutation."
			)
			break
		if not GFVariantData.get_option_bool(new_value_report, "ok"):
			staging_failure = _make_rebuild_failure(
				&"unisolatable_cell_value",
				"Table cell transactions require an isolated candidate value.",
				&"",
				row_index,
				previous_row_id
			)
			break
		var new_value: Variant = GFVariantData.get_option_value(new_value_report, "value")
		var changed: bool = not GFVariantData.values_equal(old_value, new_value)
		if changed and not column.write_value(candidate_row, new_value):
			staging_failure = _make_rebuild_failure(
				&"write_failed",
				"Table column rejected the staged value."
			)
			break
		if _reentrant_rebuild_attempted:
			staging_failure = _make_rebuild_failure(
				&"reentrant_rebuild",
				"Table column setter attempted a recursive mutation."
			)
			break
		var committed_value: Variant = column.read_value(candidate_row)
		if _reentrant_rebuild_attempted:
			staging_failure = _make_rebuild_failure(
				&"reentrant_rebuild",
				"Table column getter attempted a recursive mutation."
			)
			break
		var old_value_report: Dictionary = (
			GFTableRowView.duplicate_isolated_variant_for_framework(old_value)
		)
		var committed_value_report: Dictionary = (
			GFTableRowView.duplicate_isolated_variant_for_framework(committed_value)
		)
		if _reentrant_rebuild_attempted:
			staging_failure = _make_rebuild_failure(
				&"reentrant_rebuild",
				"Table cell report isolation callback attempted a recursive mutation."
			)
			break
		if (
			not GFVariantData.get_option_bool(old_value_report, "ok")
			or not GFVariantData.get_option_bool(committed_value_report, "ok")
		):
			staging_failure = _make_rebuild_failure(
				&"unisolatable_cell_value",
				"Table cell transaction report values must be isolated.",
				&"",
				row_index,
				previous_row_id
			)
			break
		var next_row_id: Variant = _get_row_id_for_state(
			row_index,
			next_rows,
			_row_id_column
		)
		if _reentrant_rebuild_attempted:
			staging_failure = _make_rebuild_failure(
				&"reentrant_rebuild",
				"Table row identity callback attempted a recursive mutation."
			)
			break
		var staged_report: Dictionary = _make_cell_commit_success(
			row_index,
			previous_row_id,
			next_row_id,
			column_id,
			GFVariantData.get_option_value(old_value_report, "value"),
			GFVariantData.get_option_value(committed_value_report, "value"),
			changed
		)
		staged_report["index"] = GFVariantData.get_option_int(resolved_change, "index", -1)
		if use_visible_rows:
			staged_report["visible_row_index"] = GFVariantData.get_option_int(
				resolved_change,
				"visible_row_index",
				-1
			)
		staged_reports.append(staged_report)
		if changed:
			changed_reports.append(staged_report)

	var build_report: Dictionary = {}
	if staging_failure == null and not changed_reports.is_empty():
		build_report = _build_projection_under_guard(
			next_rows,
			_columns,
			_columns_by_id,
			_filter_query,
			_sort_column_id,
			_sort_ascending,
			_row_predicates,
			_row_id_column,
			_case_sensitive_filter
		)
		if not GFVariantData.get_option_bool(build_report, "ok"):
			staging_failure = _get_build_failure(build_report)
		else:
			var transition_report: Dictionary = _make_row_id_transitions_under_guard(
				_rows,
				next_rows,
				_row_id_column,
				_row_id_column
			)
			if GFVariantData.get_option_bool(transition_report, "ok"):
				build_report["row_id_transitions"] = GFVariantData.get_option_array(
					transition_report,
					"transitions"
				)
			else:
				staging_failure = _get_build_failure(transition_report)
	_view_rebuild_in_progress = false

	if staging_failure != null:
		var published_failure: GFTableViewRebuildResult = _publish_rebuild_failure(
			staging_failure
		)
		return _make_commit_batch_result(changes.size(), [], [
			_make_commit_error(
				-1,
				published_failure.get_error_code(),
				published_failure.get_failed_source_row_index(),
				&"",
				{ "message": published_failure.get_error_message() }
			),
		])

	if changed_reports.is_empty():
		var _noop_result: GFTableViewRebuildResult = _publish_rebuild_success(false, 0, 0)
		return _make_commit_batch_result(changes.size(), staged_reports, [])

	var selected_ids_before: Array = _selection_model.get_selected_ids()
	var anchor_before: Variant = _selection_model.anchor_row_id
	var row_id_transitions: Array = GFVariantData.get_option_array(
		build_report,
		"row_id_transitions"
	)
	var mapped_selected_ids: Array = _map_selected_row_ids(
		selected_ids_before,
		row_id_transitions
	)
	var mapped_anchor: Variant = _map_row_id(anchor_before, row_id_transitions)
	_state_publication_in_progress = true
	_rows = next_rows
	var _rebuild_result: GFTableViewRebuildResult = _commit_projection_state(build_report)
	var _replace_selection_result: bool = _selection_model.replace_selection_with_anchor(
		mapped_selected_ids,
		mapped_anchor
	)
	view_changed.emit(_view_revision, _visible_row_indices.size())
	for staged_report: Dictionary in changed_reports:
		_emit_cell_value_committed(staged_report)
	_state_publication_in_progress = false
	return _make_commit_batch_result(changes.size(), staged_reports, [])


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


func _map_selected_row_ids(selected_ids: Array, reports: Array[Dictionary]) -> Array:
	var mapped_ids: Array = []
	for selected_id: Variant in selected_ids:
		var mapped_id: Variant = _map_row_id(selected_id, reports)
		if not _variant_array_has(mapped_ids, mapped_id):
			mapped_ids.append(mapped_id)
	return mapped_ids


func _map_row_id(row_id: Variant, reports: Array[Dictionary]) -> Variant:
	for report: Dictionary in reports:
		var previous_row_id: Variant = GFVariantData.get_option_value(report, "row_id")
		if GFVariantData.values_equal(row_id, previous_row_id):
			return GFVariantData.get_option_value(report, "next_row_id")
	return row_id


func _variant_array_has(values: Array, expected: Variant) -> bool:
	for value: Variant in values:
		if GFVariantData.values_equal(value, expected):
			return true
	return false


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


func _reject_reentrant_rebuild_request() -> GFTableViewRebuildResult:
	if not _view_rebuild_in_progress and not _state_publication_in_progress:
		return null
	if _view_rebuild_in_progress:
		_reentrant_rebuild_attempted = true
	return _make_rebuild_failure(
		&"reentrant_rebuild",
		"Table view mutation cannot be entered recursively."
	)


func _try_build_projection(
	rows: Array,
	columns: Array[GFTableColumnDefinition],
	columns_by_id: Dictionary,
	filter_query: String,
	sort_column_id: StringName,
	sort_ascending: bool,
	registrations: Array[GFTableRowPredicateRegistration],
	row_id_column_key: StringName,
	filter_case_sensitive: bool,
	include_row_id_transitions: bool = false,
	previous_row_id_column_key: StringName = &""
) -> Dictionary:
	if _view_rebuild_in_progress or _state_publication_in_progress:
		_reentrant_rebuild_attempted = true
		return {
			"ok": false,
			"failure": _make_rebuild_failure(
				&"reentrant_rebuild",
				"Table view rebuild cannot be entered recursively."
			),
		}

	_view_rebuild_in_progress = true
	_reentrant_rebuild_attempted = false
	var build_report: Dictionary = _build_projection_under_guard(
		rows,
		columns,
		columns_by_id,
		filter_query,
		sort_column_id,
		sort_ascending,
		registrations,
		row_id_column_key,
		filter_case_sensitive
	)
	if GFVariantData.get_option_bool(build_report, "ok") and include_row_id_transitions:
		var transition_report: Dictionary = _make_row_id_transitions_under_guard(
			rows,
			rows,
			previous_row_id_column_key,
			row_id_column_key
		)
		if GFVariantData.get_option_bool(transition_report, "ok"):
			build_report["row_id_transitions"] = GFVariantData.get_option_array(
				transition_report,
				"transitions"
			)
		else:
			build_report = transition_report
	_view_rebuild_in_progress = false
	return build_report


func _build_projection_under_guard(
	rows: Array,
	columns: Array[GFTableColumnDefinition],
	columns_by_id: Dictionary,
	filter_query: String,
	sort_column_id: StringName,
	sort_ascending: bool,
	registrations: Array[GFTableRowPredicateRegistration],
	row_id_column_key: StringName,
	filter_case_sensitive: bool
) -> Dictionary:
	var candidate_indices: Array[int] = []
	var scanned_row_count: int = 0
	var predicate_evaluation_count: int = 0
	var failure: GFTableViewRebuildResult = null

	for row_index: int in range(rows.size()):
		scanned_row_count += 1
		var matches_filter: bool = _row_matches_filter_for_state(
			row_index,
			rows,
			columns,
			filter_query,
			filter_case_sensitive
		)
		if _reentrant_rebuild_attempted:
			failure = _make_rebuild_failure(
				&"reentrant_rebuild",
				"Table view callback attempted a recursive rebuild.",
				&"",
				row_index,
				null,
				scanned_row_count,
				predicate_evaluation_count
			)
			break
		if not matches_filter:
			continue

		var should_include_row: bool = true
		var canonical_row_view: GFTableRowView = null
		var canonical_row_id: Variant = null
		for registration: GFTableRowPredicateRegistration in registrations:
			if not registration.is_enabled():
				continue
			if canonical_row_view == null:
				var row_view_report: Dictionary = _make_predicate_row_view(
					row_index,
					rows,
					columns,
					row_id_column_key
				)
				if not GFVariantData.get_option_bool(row_view_report, "ok"):
					failure = _make_rebuild_failure(
						GFVariantData.get_option_string_name(
							row_view_report,
							"error_code",
							&"invalid_row_view_snapshot"
						),
						GFVariantData.get_option_string(
							row_view_report,
							"error_message",
							"Table row view snapshot is invalid."
						),
						registration.get_predicate_id(),
						row_index,
						GFVariantData.get_option_value(row_view_report, "row_id"),
						scanned_row_count,
						predicate_evaluation_count
					)
					break
				canonical_row_id = GFVariantData.get_option_value(row_view_report, "row_id")
				var row_view_value: Variant = GFVariantData.get_option_value(
					row_view_report,
					"row_view"
				)
				if row_view_value is GFTableRowView:
					canonical_row_view = row_view_value
				else:
					failure = _make_rebuild_failure(
						&"invalid_row_view_snapshot",
						"Table row view builder returned an invalid snapshot.",
						registration.get_predicate_id(),
						row_index,
						canonical_row_id,
						scanned_row_count,
						predicate_evaluation_count
					)
					break
			if failure != null:
				break
			var callback_row_view: GFTableRowView = GFTableRowView.snapshot_for_framework(
				canonical_row_view
			)
			if callback_row_view == null:
				failure = _make_rebuild_failure(
					&"invalid_row_view_snapshot",
					"Table row view callback snapshot could not be isolated.",
					registration.get_predicate_id(),
					row_index,
					canonical_row_id,
					scanned_row_count,
					predicate_evaluation_count
				)
				break
			var predicate: GFTableRowPredicate = registration.get_predicate()
			var predicate_result: GFTableRowPredicateResult = (
				GFTableRowPredicate.evaluate_for_framework(predicate, callback_row_view)
			)
			predicate_evaluation_count += 1
			if _reentrant_rebuild_attempted:
				failure = _make_rebuild_failure(
					&"reentrant_rebuild",
					"Table row predicate attempted a recursive rebuild.",
					registration.get_predicate_id(),
					row_index,
					canonical_row_id,
					scanned_row_count,
					predicate_evaluation_count
				)
				break
			if predicate_result == null:
				failure = _make_rebuild_failure(
					&"invalid_predicate_result",
					"Table row predicate returned a null result.",
					registration.get_predicate_id(),
					row_index,
					canonical_row_id,
					scanned_row_count,
					predicate_evaluation_count
				)
				break
			if not predicate_result.is_successful():
				failure = _make_rebuild_failure(
					predicate_result.get_error_code(),
					predicate_result.get_error_message(),
					registration.get_predicate_id(),
					row_index,
					canonical_row_id,
					scanned_row_count,
					predicate_evaluation_count
				)
				break
			if not predicate_result.should_include():
				should_include_row = false
				break
		if failure != null:
			break
		if should_include_row:
			candidate_indices.append(row_index)

	if failure == null and sort_column_id != &"":
		var comparator: Callable = Callable(self, &"_compare_projection_row_indices").bind(
			rows,
			columns_by_id,
			sort_column_id,
			sort_ascending
		)
		candidate_indices.sort_custom(comparator)
		if _reentrant_rebuild_attempted:
			failure = _make_rebuild_failure(
				&"reentrant_rebuild",
				"Table sort callback attempted a recursive rebuild.",
				&"",
				-1,
				null,
				scanned_row_count,
				predicate_evaluation_count
			)

	if failure != null:
		return { "ok": false, "failure": failure }
	return {
		"ok": true,
		"indices": candidate_indices,
		"scanned_row_count": scanned_row_count,
		"predicate_evaluation_count": predicate_evaluation_count,
	}


func _row_matches_filter_for_state(
	row_index: int,
	rows: Array,
	columns: Array[GFTableColumnDefinition],
	filter_query: String,
	filter_case_sensitive: bool
) -> bool:
	if filter_query.is_empty():
		return true
	var row_data: Variant = rows[row_index]
	for column: GFTableColumnDefinition in columns:
		if column == null or not column.visible or not column.filterable:
			continue
		var column_value: Variant = column.read_value(row_data)
		if _reentrant_rebuild_attempted:
			return false
		var value_text: String = column.format_value(column_value, row_data)
		if _reentrant_rebuild_attempted:
			return false
		var normalized_query: String = filter_query
		if not filter_case_sensitive:
			value_text = value_text.to_lower()
			normalized_query = normalized_query.to_lower()
		if value_text.find(normalized_query) >= 0:
			return true
	return false


func _make_predicate_row_view(
	row_index: int,
	rows: Array,
	columns: Array[GFTableColumnDefinition],
	row_id_column_key: StringName
) -> Dictionary:
	var row_data: Variant = rows[row_index]
	var row_id: Variant = _get_row_id_for_state(row_index, rows, row_id_column_key)
	if _reentrant_rebuild_attempted:
		return _make_row_view_failure(
			&"reentrant_rebuild",
			"Table row identity callback attempted a recursive mutation.",
			row_id
		)
	if not GFVariantKeyCodec.is_stable_key(row_id):
		return _make_row_view_failure(
			&"invalid_row_id",
			"Table row predicates require a stable row id accepted by GFVariantKeyCodec.",
			null
		)
	var values: Dictionary = {}
	for column: GFTableColumnDefinition in columns:
		if column == null or column.column_id == &"":
			continue
		var column_value: Variant = column.read_value(row_data)
		if _reentrant_rebuild_attempted:
			return _make_row_view_failure(
				&"reentrant_rebuild",
				"Table column getter attempted a recursive mutation.",
				row_id
			)
		values[column.column_id] = column_value
	var row_view: GFTableRowView = GFTableRowView.new()
	var configured: bool = row_view.configure_for_framework(
		row_index,
		row_id,
		values
	)
	if _reentrant_rebuild_attempted:
		return _make_row_view_failure(
			&"reentrant_rebuild",
			"Table row snapshot callback attempted a recursive mutation.",
			row_id
		)
	if not configured:
		return _make_row_view_failure(
			&"invalid_row_view_snapshot",
			"Table row view contains an unsafe, circular, or over-budget value.",
			row_id
		)
	return {
		"ok": true,
		"row_view": row_view,
		"row_id": row_id,
		"error_code": &"",
		"error_message": "",
	}


func _make_row_view_failure(
	error_code: StringName,
	error_message: String,
	row_id: Variant
) -> Dictionary:
	return {
		"ok": false,
		"row_view": null,
		"row_id": row_id,
		"error_code": error_code,
		"error_message": error_message,
	}


func _make_row_id_transitions_under_guard(
	previous_rows: Array,
	next_rows: Array,
	previous_row_id_column_key: StringName,
	next_row_id_column_key: StringName
) -> Dictionary:
	if previous_rows.size() != next_rows.size():
		return {
			"ok": false,
			"failure": _make_rebuild_failure(
				&"invalid_row_id_transition_state",
				"Table row identity transitions require equal source row counts."
			),
		}
	var transitions: Array[Dictionary] = []
	for row_index: int in range(previous_rows.size()):
		var previous_row_id: Variant = _get_row_id_for_state(
			row_index,
			previous_rows,
			previous_row_id_column_key
		)
		if _reentrant_rebuild_attempted:
			return {
				"ok": false,
				"failure": _make_rebuild_failure(
					&"reentrant_rebuild",
					"Table row identity callback attempted a recursive mutation.",
					&"",
					row_index,
					previous_row_id
				),
			}
		var next_row_id: Variant = _get_row_id_for_state(
			row_index,
			next_rows,
			next_row_id_column_key
		)
		if _reentrant_rebuild_attempted:
			return {
				"ok": false,
				"failure": _make_rebuild_failure(
					&"reentrant_rebuild",
					"Table row identity callback attempted a recursive mutation.",
					&"",
					row_index,
					previous_row_id
				),
			}
		transitions.append({
			"row_index": row_index,
			"row_id": previous_row_id,
			"next_row_id": next_row_id,
		})
	return { "ok": true, "transitions": transitions }


func _get_row_id_for_state(
	row_index: int,
	rows: Array,
	row_id_column_key: StringName
) -> Variant:
	if row_index < 0 or row_index >= rows.size():
		return null
	if row_id_column_key == &"":
		return row_index
	var row_id: Variant = _read_row_property(rows[row_index], row_id_column_key)
	return row_index if row_id == null else row_id


func _compare_projection_row_indices(
	left_index: int,
	right_index: int,
	rows: Array,
	columns_by_id: Dictionary,
	sort_column_id: StringName,
	sort_ascending: bool
) -> bool:
	var column_value: Variant = GFVariantData.get_option_value(columns_by_id, sort_column_id)
	if not column_value is GFTableColumnDefinition:
		return left_index < right_index
	var column: GFTableColumnDefinition = column_value
	var left_row: Variant = rows[left_index]
	var right_row: Variant = rows[right_index]
	var left_value: Variant = column.read_value(left_row)
	if _reentrant_rebuild_attempted:
		return left_index < right_index
	var right_value: Variant = column.read_value(right_row)
	if _reentrant_rebuild_attempted:
		return left_index < right_index
	var compare_result: int = column.compare_values(
		left_value,
		right_value,
		left_row,
		right_row
	)
	if _reentrant_rebuild_attempted:
		return left_index < right_index
	if compare_result == 0:
		return left_index < right_index
	return compare_result < 0 if sort_ascending else compare_result > 0


func _validate_row_predicate_registrations(
	registrations: Array[GFTableRowPredicateRegistration]
) -> GFTableViewRebuildResult:
	if registrations.size() > MAX_ROW_PREDICATE_COUNT:
		return _make_rebuild_failure(
			&"predicate_limit_exceeded",
			"Table row predicate registration count exceeds the bounded limit."
		)
	var predicate_ids: Dictionary = {}
	for registration: GFTableRowPredicateRegistration in registrations:
		if registration == null:
			return _make_rebuild_failure(
				&"invalid_predicate_registration",
				"Table row predicate registration cannot be null."
			)
		var validation_report: Dictionary = registration.validate_registration()
		if not GFVariantData.get_option_bool(validation_report, "ok"):
			var issues: Array = GFVariantData.get_option_array(validation_report, "issues")
			var issue: Dictionary = GFVariantData.as_dictionary(issues[0]) if not issues.is_empty() else {}
			return _make_rebuild_failure(
				GFVariantData.get_option_string_name(issue, "kind", &"invalid_predicate_registration"),
				GFVariantData.get_option_string(
					issue,
					"message",
					"Table row predicate registration is invalid."
				),
				registration.get_predicate_id()
			)
		var predicate_id: StringName = registration.get_predicate_id()
		if predicate_ids.has(predicate_id):
			return _make_rebuild_failure(
				&"duplicate_predicate_id",
				"Table row predicate ids must be unique.",
				predicate_id
			)
		predicate_ids[predicate_id] = true
	return null


func _compare_row_predicate_registrations(
	left: GFTableRowPredicateRegistration,
	right: GFTableRowPredicateRegistration
) -> bool:
	if left.get_order() != right.get_order():
		return left.get_order() < right.get_order()
	return String(left.get_predicate_id()) < String(right.get_predicate_id())


func _row_predicate_registrations_equal(
	left: Array[GFTableRowPredicateRegistration],
	right: Array[GFTableRowPredicateRegistration]
) -> bool:
	if left.size() != right.size():
		return false
	for index: int in range(left.size()):
		var left_registration: GFTableRowPredicateRegistration = left[index]
		var right_registration: GFTableRowPredicateRegistration = right[index]
		if left_registration.get_predicate_id() != right_registration.get_predicate_id():
			return false
		if left_registration.get_predicate() != right_registration.get_predicate():
			return false
		if left_registration.get_order() != right_registration.get_order():
			return false
		if left_registration.is_enabled() != right_registration.is_enabled():
			return false
	return true


func _snapshot_row_predicate_registrations(
	registrations: Array[GFTableRowPredicateRegistration]
) -> Array[GFTableRowPredicateRegistration]:
	var snapshots: Array[GFTableRowPredicateRegistration] = []
	for registration: GFTableRowPredicateRegistration in registrations:
		if registration == null:
			snapshots.append(null)
		else:
			snapshots.append(_snapshot_row_predicate_registration(registration))
	return snapshots


func _snapshot_row_predicate_registration(
	registration: GFTableRowPredicateRegistration
) -> GFTableRowPredicateRegistration:
	return GFTableRowPredicateRegistration.snapshot_for_framework(
		registration
	)


func _make_row_predicate_lookup(
	registrations: Array[GFTableRowPredicateRegistration]
) -> Dictionary:
	var lookup: Dictionary = {}
	for registration: GFTableRowPredicateRegistration in registrations:
		lookup[registration.get_predicate_id()] = registration
	return lookup


func _replace_row_predicate_registration(
	replacement: GFTableRowPredicateRegistration
) -> GFTableViewRebuildResult:
	var next_predicates: Array[GFTableRowPredicateRegistration] = []
	for registration: GFTableRowPredicateRegistration in _row_predicates:
		if registration.get_predicate_id() == replacement.get_predicate_id():
			next_predicates.append(replacement)
		else:
			next_predicates.append(registration)
	return set_row_predicates(next_predicates)


func _get_build_failure(build_report: Dictionary) -> GFTableViewRebuildResult:
	var failure_value: Variant = GFVariantData.get_option_value(build_report, "failure")
	if failure_value is GFTableViewRebuildResult:
		var failure: GFTableViewRebuildResult = failure_value
		return failure
	return _make_rebuild_failure(
		&"invalid_rebuild_report",
		"Table view candidate builder returned an invalid failure report."
	)


func _get_build_indices(build_report: Dictionary) -> Array[int]:
	var indices: Array[int] = []
	for index_value: Variant in GFVariantData.get_option_array(build_report, "indices"):
		if index_value is int:
			var row_index: int = index_value
			indices.append(row_index)
	return indices


func _commit_projection_state(build_report: Dictionary) -> GFTableViewRebuildResult:
	_visible_row_indices = _get_build_indices(build_report)
	_view_revision += 1
	var scanned_row_count: int = GFVariantData.get_option_int(
		build_report,
		"scanned_row_count"
	)
	var predicate_evaluation_count: int = GFVariantData.get_option_int(
		build_report,
		"predicate_evaluation_count"
	)
	var result: GFTableViewRebuildResult = _make_rebuild_success(
		true,
		scanned_row_count,
		predicate_evaluation_count
	)
	_last_view_rebuild_result = result.duplicate_result()
	return result


func _publish_rebuild_success(
	committed: bool,
	scanned_row_count: int,
	predicate_evaluation_count: int
) -> GFTableViewRebuildResult:
	if _view_rebuild_in_progress or _state_publication_in_progress:
		_reentrant_rebuild_attempted = true
		return _make_rebuild_failure(
			&"reentrant_rebuild",
			"Table view rebuild cannot be entered recursively."
		)
	var result: GFTableViewRebuildResult = _make_rebuild_success(
		committed,
		scanned_row_count,
		predicate_evaluation_count
	)
	_last_view_rebuild_result = result.duplicate_result()
	return result


func _publish_rebuild_failure(
	result: GFTableViewRebuildResult
) -> GFTableViewRebuildResult:
	if _view_rebuild_in_progress:
		_reentrant_rebuild_attempted = true
		return result
	if _state_publication_in_progress:
		return result
	_state_publication_in_progress = true
	_last_view_rebuild_result = result.duplicate_result()
	view_rebuild_failed.emit(result.duplicate_result())
	_state_publication_in_progress = false
	return result


func _make_rebuild_success(
	committed: bool,
	scanned_row_count: int,
	predicate_evaluation_count: int
) -> GFTableViewRebuildResult:
	var result: GFTableViewRebuildResult = GFTableViewRebuildResult.new()
	var _configured: bool = result.configure_success_for_framework(
		committed,
		_view_revision,
		_visible_row_indices.size(),
		scanned_row_count,
		predicate_evaluation_count
	)
	return result


func _make_rebuild_failure(
	error_code: StringName,
	error_message: String,
	failed_predicate_id: StringName = &"",
	failed_source_row_index: int = -1,
	failed_row_id: Variant = null,
	scanned_row_count: int = 0,
	predicate_evaluation_count: int = 0
) -> GFTableViewRebuildResult:
	var result: GFTableViewRebuildResult = GFTableViewRebuildResult.new()
	var _configured: bool = result.configure_failure_for_framework(
		error_code,
		error_message,
		_view_revision,
		_visible_row_indices.size(),
		scanned_row_count,
		predicate_evaluation_count,
		failed_predicate_id,
		failed_source_row_index,
		failed_row_id
	)
	return result


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


func _is_valid_row_index(row_index: int) -> bool:
	return row_index >= 0 and row_index < _rows.size()
