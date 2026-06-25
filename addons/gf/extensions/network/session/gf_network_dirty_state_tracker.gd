## GFNetworkDirtyStateTracker: 通用网络状态 dirty 字段追踪器。
##
## 维护字段基线、优先级和近似比较规则，帮助项目或扩展决定哪些状态需要同步。
## 它不扫描节点、不规定 authority，也不发送消息。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 6.0.0
class_name GFNetworkDirtyStateTracker
extends RefCounted


# --- 枚举 ---

## 字段同步优先级。
## [br]
## @api public
## [br]
## @since 6.0.0
enum Priority {
	## 高频、强实时字段。
	REALTIME,
	## 高优先级字段。
	HIGH,
	## 普通字段。
	NORMAL,
	## 低频字段。
	LOW,
	## 只适合出生或初始状态同步的字段。
	SPAWN_ONLY,
	## 只保留在本地的字段。
	LOCAL_ONLY,
}


# --- 公共变量 ---

## 浮点和向量近似比较阈值。
## [br]
## @api public
## [br]
## @since 6.0.0
var epsilon: float = 0.001

## 默认字段优先级。
## [br]
## @api public
## [br]
## @since 6.0.0
var default_priority: Priority = Priority.NORMAL


# --- 私有变量 ---

var _baseline: Dictionary = {}
var _priorities: Dictionary = {}


# --- 公共方法 ---

## 设置字段优先级。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param field_id: 字段标识。
## [br]
## @param priority: 优先级。
func set_field_priority(field_id: StringName, priority: Priority) -> void:
	if field_id == &"":
		return
	_priorities[field_id] = priority


## 获取字段优先级。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param field_id: 字段标识。
## [br]
## @return 字段优先级。
func get_field_priority(field_id: StringName) -> Priority:
	return GFVariantData.get_option_int(_priorities, field_id, default_priority) as Priority


## 设置基线状态。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param state: 字段状态。
## [br]
## @schema state: Dictionary mapping field ids to values.
func set_baseline(state: Dictionary) -> void:
	_baseline = GFVariantData.duplicate_variant(state)


## 使用当前状态更新全部或指定字段基线。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param state: 字段状态。
## [br]
## @param field_ids: 指定字段；为空时更新全部字段。
## [br]
## @return 更新字段数量。
## [br]
## @schema state: Dictionary mapping field ids to values.
func update_baseline(state: Dictionary, field_ids: PackedStringArray = PackedStringArray()) -> int:
	var updated_count: int = 0
	if field_ids.is_empty():
		for key: Variant in state.keys():
			_baseline[key] = GFVariantData.duplicate_variant(state[key])
			updated_count += 1
		return updated_count

	for field_id_text: String in field_ids:
		var field_key: Variant = _resolve_state_key(state, StringName(field_id_text))
		if field_key == null:
			continue
		_baseline[field_key] = GFVariantData.duplicate_variant(state[field_key])
		updated_count += 1
	return updated_count


## 获取 dirty 字段报告。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param state: 当前字段状态。
## [br]
## @param options: 可选参数，支持 include_spawn_only、include_local_only、priorities。
## [br]
## @return dirty 字段报告。
## [br]
## @schema state: Dictionary mapping field ids to values.
## [br]
## @schema options: Dictionary with optional `include_spawn_only: bool`, `include_local_only: bool`, and `priorities: Array`.
## [br]
## @schema return: Dictionary with dirty_count, dirty_fields, by_priority, and values.
func get_dirty_report(state: Dictionary, options: Dictionary = {}) -> Dictionary:
	var include_spawn_only: bool = GFVariantData.get_option_bool(options, "include_spawn_only", false)
	var include_local_only: bool = GFVariantData.get_option_bool(options, "include_local_only", false)
	var allowed_priorities: Dictionary = _make_allowed_priority_lookup(GFVariantData.get_option_value(options, "priorities", []))
	var dirty_fields: PackedStringArray = PackedStringArray()
	var values: Dictionary = {}
	var by_priority: Dictionary = {}

	for key: Variant in state.keys():
		var field_id: StringName = GFVariantData.to_string_name(key)
		if field_id == &"":
			continue
		var priority: Priority = get_field_priority(field_id)
		if priority == Priority.SPAWN_ONLY and not include_spawn_only:
			continue
		if priority == Priority.LOCAL_ONLY and not include_local_only:
			continue
		if not allowed_priorities.is_empty() and not allowed_priorities.has(int(priority)):
			continue
		if _values_equal(GFVariantData.get_option_value(_baseline, key, null), state[key]):
			continue

		var field_text: String = String(field_id)
		var _field_appended: bool = dirty_fields.append(field_text)
		values[field_id] = GFVariantData.duplicate_variant(state[key])
		var priority_name: String = _priority_name(priority)
		if not by_priority.has(priority_name):
			by_priority[priority_name] = PackedStringArray()
		var priority_fields: PackedStringArray = GFVariantData.get_option_packed_string_array(by_priority, priority_name)
		var _priority_field_appended: bool = priority_fields.append(field_text)
		by_priority[priority_name] = priority_fields

	dirty_fields.sort()
	for priority_key: String in by_priority.keys():
		var priority_fields: PackedStringArray = GFVariantData.get_option_packed_string_array(by_priority, priority_key)
		priority_fields.sort()
		by_priority[priority_key] = priority_fields

	return {
		"dirty_count": dirty_fields.size(),
		"dirty_fields": dirty_fields,
		"by_priority": by_priority,
		"values": values,
	}


## 检查字段是否 dirty。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param state: 当前字段状态。
## [br]
## @param field_id: 字段标识。
## [br]
## @return 字段值变化时返回 true。
## [br]
## @schema state: Dictionary mapping field ids to values.
func is_field_dirty(state: Dictionary, field_id: StringName) -> bool:
	var key: Variant = _resolve_state_key(state, field_id)
	if key == null:
		return false
	return not _values_equal(GFVariantData.get_option_value(_baseline, key, null), state[key])


## 清空基线和优先级。
## [br]
## @api public
## [br]
## @since 6.0.0
func clear() -> void:
	_baseline.clear()
	_priorities.clear()


## 获取调试快照。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @return 调试快照。
## [br]
## @schema return: Dictionary with baseline_count, priority_count, epsilon, and default_priority.
func get_debug_snapshot() -> Dictionary:
	return {
		"baseline_count": _baseline.size(),
		"priority_count": _priorities.size(),
		"epsilon": epsilon,
		"default_priority": int(default_priority),
		"default_priority_name": _priority_name(default_priority),
	}


# --- 私有/辅助方法 ---

func _make_allowed_priority_lookup(values: Variant) -> Dictionary:
	var result: Dictionary = {}
	if values is Array:
		var array: Array = values
		for item: Variant in array:
			result[GFVariantData.to_int(item, -1)] = true
	elif values is PackedInt32Array:
		var packed_ints: PackedInt32Array = values
		for item: int in packed_ints:
			result[item] = true
	elif values is PackedStringArray:
		var packed_strings: PackedStringArray = values
		for item: String in packed_strings:
			result[_priority_from_name(item)] = true
	return result


func _resolve_state_key(state: Dictionary, field_id: StringName) -> Variant:
	if state.has(field_id):
		return field_id
	var field_text: String = String(field_id)
	if state.has(field_text):
		return field_text
	return null


func _values_equal(left: Variant, right: Variant) -> bool:
	if left == null and right == null:
		return true
	if typeof(left) != typeof(right):
		return false
	if left is float and right is float:
		var left_float: float = left
		var right_float: float = right
		return absf(left_float - right_float) <= epsilon
	if left is Vector2:
		var left_v2: Vector2 = left
		var right_v2: Vector2 = right
		return left_v2.distance_to(right_v2) <= epsilon
	if left is Vector3:
		var left_v3: Vector3 = left
		var right_v3: Vector3 = right
		return left_v3.distance_to(right_v3) <= epsilon
	if left is Color:
		var left_color: Color = left
		var right_color: Color = right
		return (
			absf(left_color.r - right_color.r) <= epsilon
			and absf(left_color.g - right_color.g) <= epsilon
			and absf(left_color.b - right_color.b) <= epsilon
			and absf(left_color.a - right_color.a) <= epsilon
		)
	return left == right


func _priority_name(priority: Priority) -> String:
	match priority:
		Priority.REALTIME:
			return "realtime"
		Priority.HIGH:
			return "high"
		Priority.LOW:
			return "low"
		Priority.SPAWN_ONLY:
			return "spawn_only"
		Priority.LOCAL_ONLY:
			return "local_only"
		_:
			return "normal"


func _priority_from_name(priority_name: String) -> int:
	match priority_name.to_lower():
		"realtime":
			return Priority.REALTIME
		"high":
			return Priority.HIGH
		"low":
			return Priority.LOW
		"spawn_only":
			return Priority.SPAWN_ONLY
		"local_only":
			return Priority.LOCAL_ONLY
		_:
			return Priority.NORMAL
