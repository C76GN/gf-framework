@tool

## GFResourceTableEditor: 通用 Resource 表格编辑控件。
##
## 提供资源扫描、属性列提取、表格刷新与单元格提交，不绑定具体资源类型或业务数据。
## [br]
## @api public
## [br]
## @category editor_api
## [br]
## @since 3.17.0
## [br]
## @layer kernel/editor
class_name GFResourceTableEditor
extends VBoxContainer


# --- 信号 ---

## 表格选中资源时发出。
## [br]
## @api public
## [br]
## @param resource: 被选中的资源。
signal resource_selected(resource: Resource)

## 单元格值提交后发出。
## [br]
## @api public
## [br]
## @param resource: 被修改的资源。
## [br]
## @param property: 被修改的属性名。
## [br]
## @param old_value: 提交前的旧值。
## [br]
## @schema old_value: Variant value before commit.
## [br]
## @param new_value: 提交后的新值。
## [br]
## @schema new_value: Variant value after commit.
signal cell_value_committed(resource: Resource, property: StringName, old_value: Variant, new_value: Variant)

## 自动保存资源失败时发出。
## [br]
## @api public
## [br]
## @param resource: 保存失败的资源。
## [br]
## @param path: 资源路径。
## [br]
## @param error: Godot 错误码。
signal resource_save_failed(resource: Resource, path: String, error: Error)

## 资源列表顺序变化后发出。
## [br]
## @api public
## [br]
## @param resources: 当前资源列表副本。
## [br]
## @schema resources: Array[Resource]
signal resources_reordered(resources: Array)

## 插入资源后发出。
## [br]
## @api public
## [br]
## @param resource: 被插入的资源。
## [br]
## @param index: 插入索引。
signal resource_inserted(resource: Resource, index: int)

## 移除资源后发出。
## [br]
## @api public
## [br]
## @param resource: 被移除的资源。
## [br]
## @param index: 移除前索引。
signal resource_removed(resource: Resource, index: int)

## 搜索过滤条件变化后发出。
## [br]
## @api public
## [br]
## @param query: 当前搜索文本。
## [br]
## @param visible_count: 当前可见资源数量。
signal resource_filter_changed(query: String, visible_count: int)


# --- 常量 ---

## 默认最大扫描深度。
## [br]
## @api public
const DEFAULT_MAX_SCAN_DEPTH: int = 32

## 默认最大扫描资源路径数量。
## [br]
## @api public
const DEFAULT_MAX_RESOURCE_PATHS: int = 10000
const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")
const _OBJECT_PROPERTY_TOOLS = preload("res://addons/gf/kernel/core/gf_object_property_tools.gd")
const _SCRIPT_TYPE_INSPECTOR = preload("res://addons/gf/kernel/core/gf_script_type_inspector.gd")


# --- 公共变量 ---

## 提交单元格后是否自动保存已绑定路径的 Resource。
## [br]
## @api public
var auto_save_committed_resources: bool = false

## 当前搜索过滤文本。为空时显示全部资源。
## [br]
## @api public
var search_text: String = ""

## 当前排序属性；为空时不记录排序属性。
## [br]
## @api public
var sort_property: StringName = &""

## 当前排序方向。
## [br]
## @api public
var sort_ascending: bool = true


# --- 私有变量 ---

var _resources: Array[Resource] = []
var _columns: Array[Dictionary] = []
var _visible_row_indices: PackedInt32Array = PackedInt32Array()
var _tree: Tree = null


# --- Godot 生命周期方法 ---

func _ready() -> void:
	_ensure_tree()


# --- 公共方法 ---

## 基于资源属性列表构建可编辑列声明。
## [br]
## @api public
## [br]
## @param resource: 示例资源。
## [br]
## @param include_read_only: 是否包含只读属性。
## [br]
## @return 列声明列表。
## [br]
## @schema return: Array of Dictionary column records with name, type, hint, hint_string, usage, and read_only.
static func build_export_columns(resource: Resource, include_read_only: bool = false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if resource == null:
		return result

	for property_info: Dictionary in _OBJECT_PROPERTY_TOOLS.get_property_infos(resource):
		var usage: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(property_info, "usage", 0)
		var has_storage: bool = (usage & PROPERTY_USAGE_STORAGE) != 0
		var has_editor: bool = (usage & PROPERTY_USAGE_EDITOR) != 0
		var read_only: bool = (usage & PROPERTY_USAGE_READ_ONLY) != 0
		if not has_storage or not has_editor:
			continue
		if read_only and not include_read_only:
			continue

		result.append({
			"name": _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(property_info, "name", &""),
			"type": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(property_info, "type", TYPE_NIL),
			"hint": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(property_info, "hint", PROPERTY_HINT_NONE),
			"hint_string": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(property_info, "hint_string", ""),
			"usage": usage,
			"read_only": read_only,
		})
	return result


## 递归扫描资源路径。
## [br]
## @api public
## [br]
## @param root_path: 扫描根路径。
## [br]
## @param extensions: 文件扩展名白名单，不包含点号。
## [br]
## @param options: 可选参数，支持 `max_scan_depth` 与 `max_resource_paths`。
## [br]
## @schema options: Dictionary with optional max_scan_depth and max_resource_paths.
## [br]
## @return 资源路径列表。
static func scan_resource_paths(
	root_path: String = "res://",
	extensions: PackedStringArray = PackedStringArray(["tres", "res"]),
	options: Dictionary = {}
) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var max_scan_depth: int = maxi(_GF_VARIANT_ACCESS_SCRIPT.get_option_int(options, "max_scan_depth", DEFAULT_MAX_SCAN_DEPTH), 0)
	var max_resource_paths: int = maxi(_GF_VARIANT_ACCESS_SCRIPT.get_option_int(options, "max_resource_paths", DEFAULT_MAX_RESOURCE_PATHS), 0)
	var scan_state: Dictionary = _make_scan_state()
	_scan_resource_paths_recursive(
		root_path,
		_normalize_extensions(extensions),
		result,
		0,
		max_scan_depth,
		max_resource_paths,
		scan_state
	)
	result.sort()
	return result


## 从路径列表加载资源。
## [br]
## @api public
## [br]
## @param paths: 资源路径列表。
## [br]
## @param script_filter: 可选脚本过滤；只返回附加该脚本或其子类脚本的资源。
## [br]
## @return 资源列表。
static func load_resources_from_paths(paths: PackedStringArray, script_filter: Script = null) -> Array[Resource]:
	var result: Array[Resource] = []
	for path: String in paths:
		var resource: Resource = ResourceLoader.load(path)
		if resource == null:
			continue
		if script_filter != null and not _resource_matches_script_filter(resource, script_filter):
			continue
		result.append(resource)
	return result


## 加载资源与列声明。
## [br]
## @api public
## [br]
## @param resources: Resource 列表。
## [br]
## @param columns: 可选列声明；为空时从第一条资源推导。
## [br]
## @schema columns: Array of Dictionary column records.
func load_resources(resources: Array[Resource], columns: Array[Dictionary] = []) -> void:
	_resources = resources.duplicate()
	_columns = columns.duplicate(true)
	if _columns.is_empty() and not _resources.is_empty():
		_columns = build_export_columns(_resources[0])
	refresh()


## 获取当前资源列表拷贝。
## [br]
## @api public
## [br]
## @return 资源列表。
func get_resources() -> Array[Resource]:
	return _resources.duplicate()


## 获取当前列声明拷贝。
## [br]
## @api public
## [br]
## @return 列声明列表。
## [br]
## @schema return: Array of Dictionary column records.
func get_columns() -> Array[Dictionary]:
	return _columns.duplicate(true)


## 设置搜索过滤文本。
## [br]
## @api public
## [br]
## @param query: 搜索文本，会匹配资源标签、路径和当前列值。
func set_search_text(query: String) -> void:
	if search_text == query:
		return
	search_text = query
	refresh()
	resource_filter_changed.emit(search_text, _visible_row_indices.size())


## 获取当前可见资源行的原始索引。
## [br]
## @api public
## [br]
## @return 可见行索引列表。
func get_visible_row_indices() -> PackedInt32Array:
	return PackedInt32Array(_visible_row_indices)


## 获取当前可见资源数量。
## [br]
## @api public
## [br]
## @return 可见资源数量。
func get_visible_resource_count() -> int:
	return _visible_row_indices.size()


## 查找资源在当前列表中的索引。
## [br]
## @api public
## [br]
## @param resource: 目标资源。
## [br]
## @return 资源索引；不存在时返回 -1。
func find_resource_index(resource: Resource) -> int:
	return _resources.find(resource)


## 按属性或资源标签排序。
## [br]
## @api public
## [br]
## @param property: 属性名；为空时按资源标签排序。
## [br]
## @param ascending: 是否升序。
func sort_by_property(property: StringName = &"", ascending: bool = true) -> void:
	sort_property = property
	sort_ascending = ascending
	_resources.sort_custom(func(left: Resource, right: Resource) -> bool:
		var compare_result: int = _compare_resources_for_sort(left, right, property)
		if compare_result == 0:
			return false
		return compare_result < 0 if ascending else compare_result > 0
	)
	refresh()
	resources_reordered.emit(get_resources())


## 移动资源位置。
## [br]
## @api public
## [br]
## @param from_index: 原始索引。
## [br]
## @param to_index: 目标索引。
## [br]
## @return 移动成功返回 true。
func move_resource(from_index: int, to_index: int) -> bool:
	if from_index < 0 or from_index >= _resources.size():
		return false
	if _resources.is_empty():
		return false
	var target_index: int = clampi(to_index, 0, _resources.size() - 1)
	if from_index == target_index:
		return true

	var resource: Resource = _resources[from_index]
	_resources.remove_at(from_index)
	var _insert_result_359: Variant = _resources.insert(target_index, resource)
	refresh()
	resources_reordered.emit(get_resources())
	return true


## 插入资源。
## [br]
## @api public
## [br]
## @param resource: 要插入的资源。
## [br]
## @param index: 插入索引；越界或负数时追加到末尾。
## [br]
## @return 插入成功返回 true。
func insert_resource(resource: Resource, index: int = -1) -> bool:
	if resource == null:
		return false
	var target_index: int = index
	if target_index < 0 or target_index > _resources.size():
		target_index = _resources.size()
	var _insert_result_380: Variant = _resources.insert(target_index, resource)
	if _columns.is_empty():
		_columns = build_export_columns(resource)
	refresh()
	resource_inserted.emit(resource, target_index)
	return true


## 移除资源。
## [br]
## @api public
## [br]
## @param row_index: 资源行索引。
## [br]
## @return 被移除的资源；无效索引返回 null。
func remove_resource(row_index: int) -> Resource:
	if row_index < 0 or row_index >= _resources.size():
		return null
	var resource: Resource = _resources[row_index]
	_resources.remove_at(row_index)
	refresh()
	resource_removed.emit(resource, row_index)
	return resource


## 复制资源并插入到列表。
## [br]
## @api public
## [br]
## @param row_index: 资源行索引。
## [br]
## @param deep: 是否深拷贝子资源。
## [br]
## @param insert_after: 为 true 时插入到当前资源之后，否则插入到当前位置。
## [br]
## @return 复制出的资源；无效索引返回 null。
func duplicate_resource(row_index: int, deep: bool = false, insert_after: bool = true) -> Resource:
	if row_index < 0 or row_index >= _resources.size():
		return null
	var source: Resource = _resources[row_index]
	if source == null:
		return null
	var duplicated_resource: Resource = source.duplicate(deep)
	if duplicated_resource == null:
		return null
	var target_index: int = row_index + 1 if insert_after else row_index
	var _insert_result_426: Variant = _resources.insert(target_index, duplicated_resource)
	refresh()
	resource_inserted.emit(duplicated_resource, target_index)
	return duplicated_resource


## 提交单元格值。
## [br]
## @api public
## [br]
## @param row_index: 资源行索引。
## [br]
## @param property: 属性名。
## [br]
## @param new_value: 新值。
## [br]
## @schema new_value: Variant value assigned to the resource property.
## [br]
## @return 提交成功返回 true。
func commit_cell_value(row_index: int, property: StringName, new_value: Variant) -> bool:
	var report: Dictionary = _commit_resource_cell_value_internal(row_index, property, new_value, false)
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(report, "ok"):
		return false

	var resource: Resource = _get_report_resource(report)
	cell_value_committed.emit(
		resource,
		property,
		_GF_VARIANT_ACCESS_SCRIPT.get_option_value(report, "old_value"),
		_GF_VARIANT_ACCESS_SCRIPT.get_option_value(report, "new_value")
	)
	_save_resource_if_requested(resource)
	refresh()
	return true


## 提交当前可见行的单元格值。
## [br]
## @api public
## [br]
## @param visible_row_index: 过滤后的可见行索引。
## [br]
## @param property: 属性名。
## [br]
## @param new_value: 新值。
## [br]
## @schema new_value: Variant value assigned to the resource property.
## [br]
## @return 提交成功返回 true。
func commit_visible_cell_value(visible_row_index: int, property: StringName, new_value: Variant) -> bool:
	if visible_row_index < 0 or visible_row_index >= _visible_row_indices.size():
		return false
	return commit_cell_value(_visible_row_indices[visible_row_index], property, new_value)


## 批量提交资源行单元格值。
## [br]
## 该方法会先处理所有变更，再统一刷新表格；启用自动保存时同一 Resource 只保存一次。
## 它不是事务，部分失败不会回滚已成功的变更。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param changes: 单元格变更数组；每项包含 row_index、property 与 new_value。
## [br]
## @return 批量提交报告。
## [br]
## @schema changes: Array[Dictionary]，每项包含 row_index: int、property: StringName/String、new_value: Variant。
## [br]
## @schema return: Dictionary，包含 ok、requested_count、applied_count、unchanged_count、failed_count、committed 和 errors。
func commit_cell_values(changes: Array[Dictionary]) -> Dictionary:
	return _commit_resource_cell_value_changes(changes, false)


## 批量提交可见资源行单元格值。
## [br]
## 可见行索引会在任何写入发生前解析为资源行索引，避免搜索过滤刷新导致同一批变更漂移。
## 启用自动保存时同一 Resource 只保存一次；该方法不是事务，部分失败不会回滚已成功的变更。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param changes: 单元格变更数组；每项包含 visible_row_index、property 与 new_value。
## [br]
## @return 批量提交报告。
## [br]
## @schema changes: Array[Dictionary]，每项包含 visible_row_index: int、property: StringName/String、new_value: Variant。
## [br]
## @schema return: Dictionary，包含 ok、requested_count、applied_count、unchanged_count、failed_count、committed 和 errors。
func commit_visible_cell_values(changes: Array[Dictionary]) -> Dictionary:
	return _commit_resource_cell_value_changes(changes, true)


## 刷新表格显示。
## [br]
## @api public
func refresh() -> void:
	_ensure_tree()
	_rebuild_visible_row_indices()
	_tree.clear()
	_tree.columns = _columns.size() + 1
	_tree.set_column_title(0, "Resource")
	for column_index: int in range(_columns.size()):
		var column: Dictionary = _columns[column_index]
		_tree.set_column_title(column_index + 1, _GF_VARIANT_ACCESS_SCRIPT.get_option_string(column, "name", ""))

	var root: TreeItem = _tree.create_item()
	for row_index: int in _visible_row_indices:
		var resource: Resource = _resources[row_index]
		if resource == null:
			continue
		var item: TreeItem = _tree.create_item(root)
		item.set_metadata(0, row_index)
		item.set_text(0, _resource_label(resource, row_index))
		for column_index: int in range(_columns.size()):
			var column: Dictionary = _columns[column_index]
			var property: StringName = _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(column, "name", &"")
			var value: Variant = _OBJECT_PROPERTY_TOOLS.read_property(resource, NodePath(String(property)))
			item.set_text(column_index + 1, _format_cell_value(value))


# --- 私有/辅助方法 ---

func _ensure_tree() -> void:
	if _tree != null:
		return

	_tree = Tree.new()
	_tree.hide_root = true
	_tree.column_titles_visible = true
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var _connect_result_523: Variant = _tree.item_selected.connect(_on_tree_item_selected)
	add_child(_tree)


func _commit_resource_cell_value_changes(changes: Array[Dictionary], use_visible_rows: bool) -> Dictionary:
	var committed: Array[Dictionary] = []
	var changed_reports: Array[Dictionary] = []
	var errors: Array[Dictionary] = []

	for change_index: int in range(changes.size()):
		var change: Dictionary = changes[change_index]
		var property: StringName = _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(change, "property", &"")
		var row_index: int = -1
		var visible_row_index: int = -1
		if use_visible_rows:
			visible_row_index = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(change, "visible_row_index", -1)
			if visible_row_index < 0 or visible_row_index >= _visible_row_indices.size():
				errors.append(_make_resource_commit_error(
					change_index,
					&"invalid_visible_row_index",
					-1,
					property,
					{ "visible_row_index": visible_row_index }
				))
				continue
			row_index = _visible_row_indices[visible_row_index]
		else:
			row_index = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(change, "row_index", -1)

		if not _has_option_key(change, &"new_value"):
			var missing_value_context: Dictionary = {}
			if use_visible_rows:
				missing_value_context["visible_row_index"] = visible_row_index
			errors.append(_make_resource_commit_error(
				change_index,
				&"missing_new_value",
				row_index,
				property,
				missing_value_context
			))
			continue

		var new_value: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(change, "new_value")
		var report: Dictionary = _commit_resource_cell_value_internal(row_index, property, new_value, true)
		report["index"] = change_index
		if use_visible_rows:
			report["visible_row_index"] = visible_row_index

		if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(report, "ok"):
			committed.append(report)
			if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(report, "changed"):
				changed_reports.append(report)
		else:
			var reason: StringName = _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(report, "reason", &"commit_failed")
			var failure_context: Dictionary = {
				"message": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(report, "message", String(reason)),
			}
			if use_visible_rows:
				failure_context["visible_row_index"] = visible_row_index
			errors.append(_make_resource_commit_error(
				change_index,
				reason,
				row_index,
				property,
				failure_context
			))

	if not changed_reports.is_empty():
		for report: Dictionary in changed_reports:
			_emit_resource_cell_value_committed(report)
		_save_changed_resources_if_requested(changed_reports)
		refresh()

	return _make_resource_commit_batch_result(changes.size(), committed, errors)


func _commit_resource_cell_value_internal(
	row_index: int,
	property: StringName,
	new_value: Variant,
	skip_unchanged: bool
) -> Dictionary:
	if row_index < 0 or row_index >= _resources.size():
		return _make_resource_cell_commit_failure(row_index, property, &"invalid_row_index")
	if property == &"":
		return _make_resource_cell_commit_failure(row_index, property, &"missing_property")

	var resource: Resource = _resources[row_index]
	if resource == null:
		return _make_resource_cell_commit_failure(row_index, property, &"missing_resource")
	if not _OBJECT_PROPERTY_TOOLS.has_property(resource, property):
		return _make_resource_cell_commit_failure(row_index, property, &"unknown_property")

	var old_value: Variant = _OBJECT_PROPERTY_TOOLS.read_property(resource, NodePath(String(property)))
	if skip_unchanged and old_value == new_value:
		return _make_resource_cell_commit_success(row_index, resource, property, old_value, new_value, false)

	var result: Dictionary = _OBJECT_PROPERTY_TOOLS.write_property(resource, NodePath(String(property)), new_value, {
		"check_type": false,
	})
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(result, "ok"):
		return _make_resource_cell_commit_failure(row_index, property, &"write_failed")

	var value_changed: bool = _GF_VARIANT_ACCESS_SCRIPT.to_bool(old_value != new_value)
	return _make_resource_cell_commit_success(row_index, resource, property, old_value, new_value, value_changed)


func _emit_resource_cell_value_committed(report: Dictionary) -> void:
	cell_value_committed.emit(
		_get_report_resource(report),
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(report, "property", &""),
		_GF_VARIANT_ACCESS_SCRIPT.get_option_value(report, "old_value"),
		_GF_VARIANT_ACCESS_SCRIPT.get_option_value(report, "new_value")
	)


func _save_changed_resources_if_requested(changed_reports: Array[Dictionary]) -> void:
	if not auto_save_committed_resources:
		return

	var saved_instance_ids: Dictionary = {}
	for report: Dictionary in changed_reports:
		var resource: Resource = _get_report_resource(report)
		if resource == null:
			continue
		var instance_id: int = resource.get_instance_id()
		if saved_instance_ids.has(instance_id):
			continue
		saved_instance_ids[instance_id] = true
		_save_resource_if_requested(resource)


func _make_resource_commit_batch_result(
	requested_count: int,
	committed: Array[Dictionary],
	errors: Array[Dictionary]
) -> Dictionary:
	var applied_count: int = 0
	for report: Dictionary in committed:
		if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(report, "changed"):
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


func _make_resource_cell_commit_success(
	row_index: int,
	resource: Resource,
	property: StringName,
	old_value: Variant,
	new_value: Variant,
	changed: bool
) -> Dictionary:
	return {
		"ok": true,
		"changed": changed,
		"row_index": row_index,
		"resource": resource,
		"property": property,
		"old_value": old_value,
		"new_value": new_value,
	}


func _make_resource_cell_commit_failure(row_index: int, property: StringName, reason: StringName) -> Dictionary:
	return {
		"ok": false,
		"row_index": row_index,
		"property": property,
		"reason": reason,
		"message": String(reason),
	}


func _make_resource_commit_error(
	change_index: int,
	reason: StringName,
	row_index: int,
	property: StringName,
	extra_fields: Dictionary = {}
) -> Dictionary:
	var error: Dictionary = {
		"index": change_index,
		"reason": reason,
		"message": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(extra_fields, "message", String(reason)),
		"row_index": row_index,
		"property": property,
	}
	if _has_option_key(extra_fields, &"visible_row_index"):
		error["visible_row_index"] = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(extra_fields, "visible_row_index", -1)
	return error


func _get_report_resource(report: Dictionary) -> Resource:
	var resource_value: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(report, "resource")
	if resource_value is Resource:
		var resource: Resource = resource_value
		return resource
	return null


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
	_visible_row_indices = PackedInt32Array()
	for row_index: int in range(_resources.size()):
		var resource: Resource = _resources[row_index]
		if resource == null:
			continue
		if _resource_matches_search(resource, row_index, search_text):
			var _append_result_534: Variant = _visible_row_indices.append(row_index)


static func _scan_resource_paths_recursive(
	root_path: String,
	extensions: PackedStringArray,
	result: PackedStringArray,
	depth: int,
	max_scan_depth: int,
	max_resource_paths: int,
	scan_state: Dictionary
) -> void:
	if not _can_collect_more_resource_paths(result, max_resource_paths):
		_warn_resource_path_limit(max_resource_paths, scan_state)
		return

	var dir: DirAccess = DirAccess.open(root_path)
	if dir == null:
		return

	var _list_dir_begin_result_554: Variant = dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while not file_name.is_empty():
		if not _can_collect_more_resource_paths(result, max_resource_paths):
			_warn_resource_path_limit(max_resource_paths, scan_state)
			break

		var path: String = "%s/%s" % [root_path.trim_suffix("/"), file_name]
		if dir.current_is_dir():
			if not file_name.begins_with("."):
				if _can_scan_deeper(path, depth, max_scan_depth, scan_state):
					_scan_resource_paths_recursive(
						path,
						extensions,
						result,
						depth + 1,
						max_scan_depth,
						max_resource_paths,
						scan_state
					)
		else:
			var extension: String = file_name.get_extension().to_lower()
			if extensions.has(extension):
				var _append_result_577: Variant = result.append(path)
		file_name = dir.get_next()
	dir.list_dir_end()


static func _can_scan_deeper(path: String, current_depth: int, max_scan_depth: int, scan_state: Dictionary) -> bool:
	if max_scan_depth <= 0 or current_depth < max_scan_depth:
		return true
	_warn_scan_depth_limit(path, max_scan_depth, scan_state)
	return false


static func _can_collect_more_resource_paths(result: PackedStringArray, max_resource_paths: int) -> bool:
	return max_resource_paths <= 0 or result.size() < max_resource_paths


static func _make_scan_state() -> Dictionary:
	return {
		"count_warning_emitted": false,
		"depth_warning_emitted": false,
	}


static func _get_resource_script_or_null(resource: Resource) -> Script:
	if resource == null:
		return null
	var raw_script: Variant = resource.get_script()
	if raw_script is Script:
		return raw_script
	return null


static func _warn_resource_path_limit(max_resource_paths: int, scan_state: Dictionary) -> void:
	if max_resource_paths <= 0 or _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(scan_state, "count_warning_emitted"):
		return
	scan_state["count_warning_emitted"] = true
	push_warning("[GFResourceTableEditor] scan_resource_paths 已达到 max_resource_paths=%d，后续资源已跳过。" % max_resource_paths)


static func _warn_scan_depth_limit(path: String, max_scan_depth: int, scan_state: Dictionary) -> void:
	if max_scan_depth <= 0 or _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(scan_state, "depth_warning_emitted"):
		return
	scan_state["depth_warning_emitted"] = true
	push_warning("[GFResourceTableEditor] scan_resource_paths 已达到 max_scan_depth=%d，已跳过更深目录：%s。" % [max_scan_depth, path])


static func _normalize_extensions(extensions: PackedStringArray) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for extension: String in extensions:
		var _append_result_626: Variant = result.append(extension.trim_prefix(".").to_lower())
	return result


static func _resource_matches_script_filter(resource: Resource, script_filter: Script) -> bool:
	return _SCRIPT_TYPE_INSPECTOR.script_extends_or_equals(_get_resource_script_or_null(resource), script_filter)


func _resource_matches_search(resource: Resource, row_index: int, query: String) -> bool:
	var normalized_query: String = query.strip_edges().to_lower()
	if normalized_query.is_empty():
		return true

	var label: String = _resource_label(resource, row_index).to_lower()
	if label.contains(normalized_query):
		return true
	if resource.get_class().to_lower().contains(normalized_query):
		return true

	var script: Script = _get_resource_script_or_null(resource)
	if script != null and script.resource_path.to_lower().contains(normalized_query):
		return true

	for column: Dictionary in _columns:
		var property: StringName = _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(column, "name", &"")
		if property == &"" or not _OBJECT_PROPERTY_TOOLS.has_property(resource, property):
			continue
		var value: Variant = _OBJECT_PROPERTY_TOOLS.read_property(resource, NodePath(String(property)))
		if _format_cell_value(value).to_lower().contains(normalized_query):
			return true
	return false


func _compare_resources_for_sort(left: Resource, right: Resource, property: StringName) -> int:
	if left == right:
		return 0
	if left == null:
		return 1
	if right == null:
		return -1

	if property == &"":
		return _compare_variant_values(_resource_label(left, _resources.find(left)), _resource_label(right, _resources.find(right)))

	var left_value: Variant = _OBJECT_PROPERTY_TOOLS.read_property(left, NodePath(String(property)))
	var right_value: Variant = _OBJECT_PROPERTY_TOOLS.read_property(right, NodePath(String(property)))
	return _compare_variant_values(left_value, right_value)


func _compare_variant_values(left: Variant, right: Variant) -> int:
	if left == right:
		return 0
	if left == null:
		return 1
	if right == null:
		return -1

	var left_type: int = typeof(left)
	var right_type: int = typeof(right)
	if _is_numeric_type(left_type) and _is_numeric_type(right_type):
		return _compare_float_values(
			_GF_VARIANT_ACCESS_SCRIPT.to_float(left),
			_GF_VARIANT_ACCESS_SCRIPT.to_float(right)
		)
	if left_type == TYPE_BOOL and right_type == TYPE_BOOL:
		return _compare_float_values(
			1.0 if _GF_VARIANT_ACCESS_SCRIPT.to_bool(left) else 0.0,
			1.0 if _GF_VARIANT_ACCESS_SCRIPT.to_bool(right) else 0.0
		)

	var left_text: String = str(left)
	var right_text: String = str(right)
	return left_text.naturalnocasecmp_to(right_text)


func _compare_float_values(left: float, right: float) -> int:
	if left < right:
		return -1
	if left > right:
		return 1
	return 0


func _is_numeric_type(type_id: int) -> bool:
	return type_id == TYPE_INT or type_id == TYPE_FLOAT


func _save_resource_if_requested(resource: Resource) -> void:
	if not auto_save_committed_resources:
		return

	var path: String = resource.resource_path
	if path.is_empty():
		return

	var error: Error = ResourceSaver.save(resource, path)
	if error != OK:
		resource_save_failed.emit(resource, path, error)


func _resource_label(resource: Resource, row_index: int) -> String:
	if not resource.resource_path.is_empty():
		return resource.resource_path
	return "Resource %d" % row_index


func _format_cell_value(value: Variant) -> String:
	if value is Dictionary or value is Array:
		return JSON.stringify(value)
	return str(value)


# --- 信号处理函数 ---

func _on_tree_item_selected() -> void:
	if _tree == null:
		return

	var item: TreeItem = _tree.get_selected()
	if item == null:
		return

	var raw_row_index: Variant = item.get_metadata(0)
	var row_index: int = raw_row_index if raw_row_index is int else -1
	if row_index >= 0 and row_index < _resources.size():
		resource_selected.emit(_resources[row_index])
