@tool

## GFEditorCommandRegistry: 编辑器动作注册表。
##
## 收集由 kernel、standard、扩展或项目工具主动贡献的编辑器动作，并提供按 ID
## 查询、排序、布局解析和调用入口。注册表只保存动作声明与来源信息，不扫描脚本、
## 不保存业务逻辑，也不规定命令面板或工具栏的具体 UI。
## [br]
## @api public
## [br]
## @category editor_api
## [br]
## @since 7.0.0
## [br]
## @layer kernel/editor
class_name GFEditorCommandRegistry
extends RefCounted


# --- 常量 ---

## 动作已新增注册。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATUS_REGISTERED: StringName = &"registered"

## 已存在动作被替换。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATUS_REPLACED: StringName = &"replaced"

## 动作 ID 已存在且未允许替换。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATUS_DUPLICATE: StringName = &"duplicate"

## 动作声明无效。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATUS_INVALID: StringName = &"invalid"

## 动作不存在。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATUS_MISSING: StringName = &"missing"

## 动作已调用。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATUS_INVOKED: StringName = &"invoked"

## 动作调用失败。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATUS_FAILED: StringName = &"failed"

## 编辑器动作声明脚本。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const GFEditorActionDefinitionBase = preload("res://addons/gf/kernel/editor/gf_editor_action_definition.gd")
const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")


# --- 公共变量 ---

## 注册表元数据。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @schema metadata: Dictionary for caller-defined registry metadata.
var metadata: Dictionary = {}


# --- 私有变量 ---

var _records: Dictionary = {}


# --- 公共方法 ---

## 清空所有动作记录。
## [br]
## @api public
## [br]
## @since 7.0.0
func clear() -> void:
	_records.clear()


## 注册单个动作。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param action: 要注册的动作声明。
## [br]
## @param options: 注册选项，支持 replace_existing、group、source_id、sort_order 和 metadata。
## [br]
## @schema options: Dictionary with replace_existing, group, source_id, sort_order, and metadata.
## [br]
## @return 注册结果。
## [br]
## @schema return: Dictionary containing ok, status, action_id, replaced, error_code, message, and metadata.
func register_action(action: GFEditorActionDefinitionBase, options: Dictionary = {}) -> Dictionary:
	if action == null:
		return _make_result(false, STATUS_INVALID, &"", false, ERR_INVALID_PARAMETER, "动作为空。", options)
	if action.action_id == &"":
		return _make_result(false, STATUS_INVALID, &"", false, ERR_INVALID_PARAMETER, "动作缺少 action_id。", options)

	var action_id: StringName = action.action_id
	var exists: bool = _records.has(action_id)
	var replace_existing: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "replace_existing", false)
	if exists and not replace_existing:
		return _make_result(false, STATUS_DUPLICATE, action_id, false, ERR_ALREADY_EXISTS, "动作 ID 已存在。", options)

	_records[action_id] = _make_record(action, options)
	return _make_result(true, STATUS_REPLACED if exists else STATUS_REGISTERED, action_id, exists, OK, "", options)


## 批量注册动作。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param actions: 动作声明数组。
## [br]
## @param options: 注册选项，会传给每个 register_action()。
## [br]
## @schema actions: Array of GFEditorActionDefinition.
## [br]
## @schema options: Dictionary register_action() options.
## [br]
## @return 批量注册摘要。
## [br]
## @schema return: Dictionary containing ok, action_count, registered_count, failed_count, and results.
func register_actions(actions: Array[GFEditorActionDefinitionBase], options: Dictionary = {}) -> Dictionary:
	var results: Array[Dictionary] = []
	var registered_count: int = 0
	var failed_count: int = 0
	for action: GFEditorActionDefinitionBase in actions:
		var result: Dictionary = register_action(action, options)
		results.append(result)
		if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(result, "ok", false):
			registered_count += 1
		else:
			failed_count += 1
	return {
		"ok": failed_count == 0,
		"action_count": actions.size(),
		"registered_count": registered_count,
		"failed_count": failed_count,
		"results": results,
	}


## 取消注册动作。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param action_id: 动作 ID。
## [br]
## @return 存在并移除时返回 true。
func unregister_action(action_id: StringName) -> bool:
	if not _records.has(action_id):
		return false
	var _erased: bool = _records.erase(action_id)
	return true


## 检查动作是否已注册。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param action_id: 动作 ID。
## [br]
## @return 存在返回 true。
func has_action(action_id: StringName) -> bool:
	return _records.has(action_id)


## 获取动作声明。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param action_id: 动作 ID。
## [br]
## @return 动作声明；不存在时返回 null。
func get_action(action_id: StringName) -> GFEditorActionDefinitionBase:
	var record: Dictionary = get_action_record(action_id)
	if record.is_empty():
		return null
	var action_value: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(record, "action")
	if action_value is GFEditorActionDefinitionBase:
		var action: GFEditorActionDefinitionBase = action_value
		return action
	return null


## 获取动作注册记录副本。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param action_id: 动作 ID。
## [br]
## @return 动作记录；不存在时返回空字典。
## [br]
## @schema return: Dictionary containing action, action_id, group, source_id, sort_order, and metadata.
func get_action_record(action_id: StringName) -> Dictionary:
	if not _records.has(action_id):
		return {}
	var record_value: Variant = _records[action_id]
	if record_value is Dictionary:
		var record: Dictionary = record_value
		return record.duplicate(true)
	return {}


## 获取动作 ID 列表。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param filters: 可选过滤条件，支持 group 与 source_id。
## [br]
## @schema filters: Dictionary with optional group and source_id.
## [br]
## @return 按 group、sort_order、label 排序的动作 ID。
func get_action_ids(filters: Dictionary = {}) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for record: Dictionary in _get_sorted_records(filters):
		var _append_id: bool = result.append(String(_GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(record, "action_id")))
	return result


## 获取动作快照列表。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param context: 用于可用性或调用探针的调用上下文。
## [br]
## @param options: 可选参数，支持 group、source_id、include_availability 和 include_invocation。
## [br]
## @schema context: Dictionary passed to action availability and invocation checks.
## [br]
## @schema options: Dictionary with group, source_id, include_availability, and include_invocation.
## [br]
## @return 动作快照数组。
## [br]
## @schema return: Array[Dictionary] action snapshots sorted for UI display.
func get_action_snapshots(context: Dictionary = {}, options: Dictionary = {}) -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	for record: Dictionary in _get_sorted_records(options):
		snapshots.append(_make_action_snapshot(record, context, options))
	return snapshots


## 按保存的动作 ID 布局解析动作快照。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param action_ids: 已保存的动作 ID 顺序。
## [br]
## @param context: 用于可用性或调用探针的调用上下文。
## [br]
## @param options: 可选参数，支持 include_availability 和 include_invocation。
## [br]
## @schema context: Dictionary passed to action availability and invocation checks.
## [br]
## @schema options: Dictionary with optional include_availability and include_invocation.
## [br]
## @return 布局解析报告。
## [br]
## @schema return: Dictionary containing entries and missing_ids.
func resolve_layout(
	action_ids: PackedStringArray,
	context: Dictionary = {},
	options: Dictionary = {}
) -> Dictionary:
	var entries: Array[Dictionary] = []
	var missing_ids: PackedStringArray = PackedStringArray()
	for action_id_text: String in action_ids:
		var action_id: StringName = StringName(action_id_text)
		var record: Dictionary = get_action_record(action_id)
		if record.is_empty():
			var _append_missing: bool = missing_ids.append(action_id_text)
			continue
		entries.append(_make_action_snapshot(record, context, options))
	return {
		"entries": entries,
		"missing_ids": missing_ids,
	}


## 按 ID 调用动作。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param action_id: 动作 ID。
## [br]
## @param context: 动作上下文。
## [br]
## @param undo_manager: EditorUndoRedoManager 或兼容对象；为空时直接执行命令。
## [br]
## @schema context: Dictionary passed to action.invoke().
## [br]
## @return 调用结果。
## [br]
## @schema return: Dictionary containing ok, status, action_id, error_code, message, and metadata.
func invoke_action(
	action_id: StringName,
	context: Dictionary = {},
	undo_manager: Object = null
) -> Dictionary:
	var action: GFEditorActionDefinitionBase = get_action(action_id)
	if action == null:
		return _make_result(false, STATUS_MISSING, action_id, false, ERR_DOES_NOT_EXIST, "动作不存在。")

	var error: Error = action.invoke(context, undo_manager)
	if error != OK:
		return _make_result(false, STATUS_FAILED, action_id, false, error, error_string(error))
	return _make_result(true, STATUS_INVOKED, action_id, false, OK)


## 获取注册表调试快照。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param context: 可选动作上下文。
## [br]
## @param options: 可选参数，透传给 get_action_snapshots()。
## [br]
## @schema context: Dictionary passed to get_action_snapshots().
## [br]
## @schema options: Dictionary get_action_snapshots() options.
## [br]
## @return 调试快照。
## [br]
## @schema return: Dictionary containing action_count, action_ids, actions, and metadata.
func get_debug_snapshot(context: Dictionary = {}, options: Dictionary = {}) -> Dictionary:
	return {
		"action_count": _records.size(),
		"action_ids": get_action_ids(options),
		"actions": get_action_snapshots(context, options),
		"metadata": metadata.duplicate(true),
	}


# --- 私有/辅助方法 ---

func _make_record(action: GFEditorActionDefinitionBase, options: Dictionary) -> Dictionary:
	var group: StringName = _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(options, "group", action.group)
	var source_id: StringName = _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(options, "source_id", action.source_id)
	var sort_order: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(options, "sort_order", action.sort_order)
	return {
		"action": action,
		"action_id": action.action_id,
		"group": group,
		"source_id": source_id,
		"sort_order": sort_order,
		"metadata": _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(options, "metadata"),
	}


func _make_result(
	ok: bool,
	status: StringName,
	action_id: StringName,
	replaced: bool,
	error_code: Error,
	message: String = "",
	source_options: Dictionary = {}
) -> Dictionary:
	return {
		"ok": ok,
		"status": status,
		"action_id": String(action_id),
		"replaced": replaced,
		"error_code": error_code,
		"message": message,
		"metadata": _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(source_options, "metadata"),
	}


func _get_sorted_records(filters: Dictionary) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for record_value: Variant in _records.values():
		if not (record_value is Dictionary):
			continue
		var record: Dictionary = record_value
		if _record_matches_filters(record, filters):
			records.append(record.duplicate(true))
	records.sort_custom(Callable(self, "_sort_action_records_asc"))
	return records


func _record_matches_filters(record: Dictionary, filters: Dictionary) -> bool:
	var expected_group: StringName = _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(filters, "group")
	if expected_group != &"" and _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(record, "group") != expected_group:
		return false

	var expected_source_id: StringName = _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(filters, "source_id")
	if expected_source_id != &"" and _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(record, "source_id") != expected_source_id:
		return false
	return true


func _make_action_snapshot(record: Dictionary, context: Dictionary, options: Dictionary) -> Dictionary:
	var action: GFEditorActionDefinitionBase = _record_action(record)
	if action == null:
		return {
			"action_id": String(_GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(record, "action_id")),
			"valid": false,
		}

	var snapshot: Dictionary = action.get_debug_snapshot()
	snapshot["valid"] = true
	snapshot["group"] = String(_GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(record, "group", action.group))
	snapshot["source_id"] = String(_GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(record, "source_id", action.source_id))
	snapshot["sort_order"] = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(record, "sort_order", action.sort_order)
	snapshot["registry_metadata"] = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(record, "metadata")
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "include_availability", false):
		snapshot["available"] = action.is_available(context)
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "include_invocation", false):
		snapshot["invocation"] = action.get_invocation_report(context)
	return snapshot


func _record_action(record: Dictionary) -> GFEditorActionDefinitionBase:
	var action_value: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(record, "action")
	if action_value is GFEditorActionDefinitionBase:
		var action: GFEditorActionDefinitionBase = action_value
		return action
	return null


func _sort_action_records_asc(left_value: Variant, right_value: Variant) -> bool:
	var left: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(left_value)
	var right: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(right_value)
	var left_group: String = String(_GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(left, "group"))
	var right_group: String = String(_GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(right, "group"))
	if left_group != right_group:
		return left_group < right_group

	var left_order: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(left, "sort_order", 0)
	var right_order: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(right, "sort_order", 0)
	if left_order != right_order:
		return left_order < right_order

	var left_action: GFEditorActionDefinitionBase = _record_action(left)
	var right_action: GFEditorActionDefinitionBase = _record_action(right)
	var left_label: String = left_action.label if left_action != null else ""
	var right_label: String = right_action.label if right_action != null else ""
	if left_label != right_label:
		return left_label < right_label
	return String(_GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(left, "action_id")) < String(_GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(right, "action_id"))
