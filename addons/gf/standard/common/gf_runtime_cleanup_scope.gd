## GFRuntimeCleanupScope: 通用运行时清理回调作用域。
##
## 用于让上层系统按 scope 注册清理回调，并在重启、切换场景或释放运行态时
## 按优先级执行。该类型只管理清理回调的所有权与顺序，不认识具体业务系统。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 8.0.0
class_name GFRuntimeCleanupScope
extends RefCounted


# --- 私有变量 ---

var _records_by_scope: Dictionary = {}
var _next_order: int = 0


# --- 公共方法 ---

## 注册清理回调。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param scope_id: 清理作用域 ID。
## [br]
## @param cleanup_id: 清理项 ID，同一 scope 内唯一。
## [br]
## @param callback: 无参数清理回调。
## [br]
## @param priority: 执行优先级，数值越大越先执行。
## [br]
## @param metadata: 调用方自定义元数据。
## [br]
## @return 注册成功返回 true。
## [br]
## @schema metadata: Dictionary project-defined cleanup metadata copied into diagnostics.
func register_cleanup(
	scope_id: StringName,
	cleanup_id: StringName,
	callback: Callable,
	priority: int = 0,
	metadata: Dictionary = {}
) -> bool:
	if scope_id == &"" or cleanup_id == &"" or not callback.is_valid():
		return false

	var _unregistered_existing: bool = unregister_cleanup(scope_id, cleanup_id)
	_next_order += 1
	var records: Array[Dictionary] = _get_scope_records(scope_id)
	records.append({
		"scope_id": scope_id,
		"cleanup_id": cleanup_id,
		"callback": callback,
		"priority": priority,
		"order": _next_order,
		"metadata": metadata.duplicate(true),
	})
	_records_by_scope[scope_id] = records
	return true


## 注销清理回调。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param scope_id: 清理作用域 ID。
## [br]
## @param cleanup_id: 清理项 ID。
## [br]
## @return 成功移除返回 true。
func unregister_cleanup(scope_id: StringName, cleanup_id: StringName) -> bool:
	if scope_id == &"" or cleanup_id == &"":
		return false

	var records: Array[Dictionary] = _get_scope_records(scope_id)
	for index: int in range(records.size() - 1, -1, -1):
		if GFVariantData.get_option_string_name(records[index], "cleanup_id") != cleanup_id:
			continue
		records.remove_at(index)
		_set_scope_records(scope_id, records)
		return true
	return false


## 执行指定 scope 的清理回调。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param scope_id: 清理作用域 ID。
## [br]
## @return 清理执行报告。
## [br]
## @schema return: Dictionary with ok, scope_id, executed_count, skipped_count, cleanup_ids, and issues.
func run_scope(scope_id: StringName) -> Dictionary:
	var records: Array[Dictionary] = _get_scope_records(scope_id)
	records.sort_custom(_sort_records)
	var executed_ids: PackedStringArray = PackedStringArray()
	var issues: Array[Dictionary] = []
	var skipped_count: int = 0

	for record: Dictionary in records:
		var cleanup_id: StringName = GFVariantData.get_option_string_name(record, "cleanup_id")
		var callback: Callable = _get_record_callback(record)
		if not callback.is_valid():
			skipped_count += 1
			issues.append({
				"kind": &"invalid_cleanup_callback",
				"cleanup_id": cleanup_id,
				"metadata": GFVariantData.get_option_dictionary(record, "metadata"),
			})
			continue
		var _callback_result: Variant = callback.call()
		var _cleanup_id_appended: bool = executed_ids.append(String(cleanup_id))

	return {
		"ok": issues.is_empty(),
		"scope_id": scope_id,
		"executed_count": executed_ids.size(),
		"skipped_count": skipped_count,
		"cleanup_ids": executed_ids,
		"issues": issues,
	}


## 清空指定 scope 的所有清理回调。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param scope_id: 清理作用域 ID。
func clear_scope(scope_id: StringName) -> void:
	var _erased_scope: bool = _records_by_scope.erase(scope_id)


## 清空全部清理作用域。
## [br]
## @api public
## [br]
## @since 8.0.0
func clear_all() -> void:
	_records_by_scope.clear()
	_next_order = 0


## 检查清理回调是否已注册。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param scope_id: 清理作用域 ID。
## [br]
## @param cleanup_id: 清理项 ID。
## [br]
## @return 存在返回 true。
func has_cleanup(scope_id: StringName, cleanup_id: StringName) -> bool:
	for record: Dictionary in _get_scope_records(scope_id):
		if GFVariantData.get_option_string_name(record, "cleanup_id") == cleanup_id:
			return true
	return false


## 获取指定 scope 的清理项 ID。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param scope_id: 清理作用域 ID。
## [br]
## @return 排序后的清理项 ID。
func get_cleanup_ids(scope_id: StringName) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for record: Dictionary in _get_scope_records(scope_id):
		var cleanup_id: StringName = GFVariantData.get_option_string_name(record, "cleanup_id")
		if cleanup_id == &"":
			continue
		var _appended_cleanup_id: bool = result.append(String(cleanup_id))
	result.sort()
	return result


## 获取调试快照。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 作用域调试快照。
## [br]
## @schema return: Dictionary with scope_count, cleanup_count, and scopes.
func get_debug_snapshot() -> Dictionary:
	var scopes: Dictionary = {}
	var cleanup_count: int = 0
	for scope_key: Variant in _records_by_scope.keys():
		var scope_id: StringName = GFVariantData.to_string_name(scope_key)
		var cleanup_ids: PackedStringArray = get_cleanup_ids(scope_id)
		cleanup_count += cleanup_ids.size()
		scopes[String(scope_id)] = cleanup_ids
	return {
		"scope_count": scopes.size(),
		"cleanup_count": cleanup_count,
		"scopes": scopes,
	}


# --- 私有/辅助方法 ---

func _get_scope_records(scope_id: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var records_value: Variant = _records_by_scope.get(scope_id)
	if not records_value is Array:
		return result

	var records: Array = records_value
	for record_value: Variant in records:
		if record_value is Dictionary:
			var record: Dictionary = record_value
			result.append(record.duplicate(true))
	return result


func _set_scope_records(scope_id: StringName, records: Array[Dictionary]) -> void:
	if records.is_empty():
		var _erased_scope: bool = _records_by_scope.erase(scope_id)
		return
	_records_by_scope[scope_id] = records


func _get_record_callback(record: Dictionary) -> Callable:
	var value: Variant = GFVariantData.get_option_value(record, "callback")
	if value is Callable:
		var callback: Callable = value
		return callback
	return Callable()


static func _sort_records(left: Dictionary, right: Dictionary) -> bool:
	var left_priority: int = GFVariantData.get_option_int(left, "priority")
	var right_priority: int = GFVariantData.get_option_int(right, "priority")
	if left_priority != right_priority:
		return left_priority > right_priority
	return GFVariantData.get_option_int(left, "order") < GFVariantData.get_option_int(right, "order")
