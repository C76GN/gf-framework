## GFUndoableCommand: 可撤销命令的抽象基类。
##
## 继承自 GFCommand，在标准命令的基础上新增撤销能力。
## 子类须在 execute() 执行前通过 set_snapshot() 保存当前状态快照，
## 并在 undo() 中借助 get_snapshot() 取回快照以还原数据，
## 从而支持编辑器操作、运行时流程回放和项目自定义撤销功能。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 3.17.0
class_name GFUndoableCommand
extends GFCommand


# --- 常量 ---

const _MAX_SNAPSHOT_DEPTH: int = 128
const _MAX_SNAPSHOT_ITEMS: int = 100_000
const _SNAPSHOT_ITEM_OVERHEAD_BYTES: int = 64

## 单个命令快照允许的最大保守内存成本估算，单位字节。
##
## [br]
## 估算覆盖容器节点、String/StringName/NodePath 和全部 PackedArray 载荷，
## 防止少量超大 Variant 绕过节点预算。
## [br]
## @api public
## [br]
## @since unreleased
const MAX_SNAPSHOT_BYTES: int = 16 * 1024 * 1024


# --- 公共变量 ---

## 可选命令标签，供项目历史面板、日志或调试工具显示。默认为空，框架不生成用户可见文案。
## [br]
## @api public
var action_name: String = ""


# --- 私有变量 ---

# 执行前保存的状态快照，用于 undo() 时还原。
var _snapshot: Variant = null


# --- 公共方法 ---

## 执行命令逻辑。子类必须重写此方法，并建议在此处先调用 set_snapshot()。
## [br]
## @api public
## [br]
## @return 同步命令返回 null；异步命令可返回 Signal 供外部 await。
## [br]
## @schema return: Variant, null or Signal.
func execute() -> Variant:
	return null


## 撤销命令。子类必须重写此方法，使用 get_snapshot() 还原状态。
## [br]
## @api public
## [br]
## @return 同步命令返回 null；异步命令可返回 Signal 供外部 await。
## [br]
## @schema return: Variant, null or Signal.
func undo() -> Variant:
	return null


## 判断 execute() 返回后是否应该写入命令历史。
## [br]
## @api public
## [br]
## @param _execute_result: execute() 的最终返回值。
## [br]
## @return 返回 false 时，GFCommandHistoryUtility 不会记录该命令。
## [br]
## @schema _execute_result: Variant returned by execute().
func should_record(_execute_result: Variant) -> bool:
	return true


## 判断一次 undo() 的终态结果是否成功。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## 该 hook 运行在非重入历史操作内，不得执行、记录、清空、调整容量或恢复历史。
## [br]
## @param _undo_result: 同步返回值，或异步完成 Signal 的规范化 payload；异步最多捕获 16 个参数。
## [br]
## @return 返回 false 时，GFCommandHistoryUtility 会保留原撤销栈位置并报告失败。
## [br]
## @schema _undo_result: Direct undo() result, null for a no-argument completion Signal, one emitted value, or an Array containing the first 2 to 16 emitted values.
func is_undo_successful(_undo_result: Variant) -> bool:
	return true


## 判断一次重做 execute() 的终态结果是否成功。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## 该 hook 运行在非重入历史操作内，不得执行、记录、清空、调整容量或恢复历史。
## [br]
## @param _execute_result: 同步返回值，或异步完成 Signal 的规范化 payload；异步最多捕获 16 个参数。
## [br]
## @return 返回 false 时，GFCommandHistoryUtility 会保留原重做栈位置并报告失败。
## [br]
## @schema _execute_result: Direct execute() result, null for a no-argument completion Signal, one emitted value, or an Array containing the first 2 to 16 emitted values.
func is_redo_successful(_execute_result: Variant) -> bool:
	return true


## 保存执行前的状态快照。应在 execute() 内部、修改数据之前调用。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param data: 任意可序列化的快照数据（如字典、数值、数组）。
## [br]
## 快照只接受不含 Object、Callable、Signal 或 RID 的纯 Variant 值；复杂运行时对象应先投影为数据。
## 深度、项目数或 [constant MAX_SNAPSHOT_BYTES] 成本预算校验失败时保留原快照，
## 不产生半更新状态。
## [br]
## @return 快照通过校验并保存时返回 true。
## [br]
## @schema data: Pure Variant snapshot value without Object, Callable, Signal, or RID references, bounded to 128 levels, 100000 visited values, and MAX_SNAPSHOT_BYTES estimated bytes.
func set_snapshot(data: Variant) -> bool:
	var validation_state: Dictionary = {
		"bytes": 0,
		"items": 0,
	}
	if not _is_snapshot_value_supported(data, 0, validation_state):
		push_error("[GFUndoableCommand] 快照必须是有界的纯 Variant 数据，不能包含运行时引用或递归结构。")
		return false
	_snapshot = GFVariantData.duplicate_variant(data, true, false)
	return true


## 获取由 set_snapshot() 保存的状态快照。在 undo() 中调用以还原数据。
## [br]
## @api public
## [br]
## @return 之前保存的快照数据，不存在则返回 null。
## [br]
## @schema return: Variant snapshot value or null.
func get_snapshot() -> Variant:
	return GFVariantData.duplicate_variant(_snapshot, true, false)


# --- 私有/辅助方法 ---

func _is_snapshot_value_supported(value: Variant, depth: int, state: Dictionary) -> bool:
	if depth > _MAX_SNAPSHOT_DEPTH:
		return false
	var item_count: int = GFVariantData.get_option_int(state, "items") + 1
	state["items"] = item_count
	if item_count > _MAX_SNAPSHOT_ITEMS:
		return false
	if not _consume_snapshot_bytes(state, _SNAPSHOT_ITEM_OVERHEAD_BYTES):
		return false

	match typeof(value):
		TYPE_OBJECT, TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID:
			return false
		TYPE_STRING, TYPE_STRING_NAME, TYPE_NODE_PATH:
			return _consume_snapshot_text(state, str(value))
		TYPE_PACKED_BYTE_ARRAY:
			var packed_bytes: PackedByteArray = value
			return _consume_snapshot_units(state, packed_bytes.size(), 1)
		TYPE_PACKED_INT32_ARRAY:
			var packed_int32: PackedInt32Array = value
			return _consume_snapshot_units(state, packed_int32.size(), 4)
		TYPE_PACKED_INT64_ARRAY:
			var packed_int64: PackedInt64Array = value
			return _consume_snapshot_units(state, packed_int64.size(), 8)
		TYPE_PACKED_FLOAT32_ARRAY:
			var packed_float32: PackedFloat32Array = value
			return _consume_snapshot_units(state, packed_float32.size(), 4)
		TYPE_PACKED_FLOAT64_ARRAY:
			var packed_float64: PackedFloat64Array = value
			return _consume_snapshot_units(state, packed_float64.size(), 8)
		TYPE_PACKED_STRING_ARRAY:
			var packed_strings: PackedStringArray = value
			if not _consume_snapshot_units(
				state,
				packed_strings.size(),
				_SNAPSHOT_ITEM_OVERHEAD_BYTES
			):
				return false
			for text: String in packed_strings:
				if not _consume_snapshot_text(state, text):
					return false
		TYPE_PACKED_VECTOR2_ARRAY:
			var packed_vector2: PackedVector2Array = value
			return _consume_snapshot_units(state, packed_vector2.size(), 8)
		TYPE_PACKED_VECTOR3_ARRAY:
			var packed_vector3: PackedVector3Array = value
			return _consume_snapshot_units(state, packed_vector3.size(), 12)
		TYPE_PACKED_VECTOR4_ARRAY:
			var packed_vector4: PackedVector4Array = value
			return _consume_snapshot_units(state, packed_vector4.size(), 16)
		TYPE_PACKED_COLOR_ARRAY:
			var packed_colors: PackedColorArray = value
			return _consume_snapshot_units(state, packed_colors.size(), 16)
		TYPE_ARRAY:
			var array_values: Array = value
			for entry: Variant in array_values:
				if not _is_snapshot_value_supported(entry, depth + 1, state):
					return false
		TYPE_DICTIONARY:
			var dictionary_values: Dictionary = value
			for key: Variant in dictionary_values.keys():
				if not _is_snapshot_value_supported(key, depth + 1, state):
					return false
				if not _is_snapshot_value_supported(dictionary_values[key], depth + 1, state):
					return false
	return true


func _consume_snapshot_text(state: Dictionary, value: String) -> bool:
	return _consume_snapshot_units(state, value.length(), 4)


func _consume_snapshot_units(
	state: Dictionary,
	unit_count: int,
	bytes_per_unit: int
) -> bool:
	if unit_count < 0 or bytes_per_unit <= 0:
		return false
	var consumed_bytes: int = GFVariantData.get_option_int(state, "bytes")
	var remaining_bytes: int = MAX_SNAPSHOT_BYTES - consumed_bytes
	var maximum_units: int = floori(float(remaining_bytes) / float(bytes_per_unit))
	if remaining_bytes < 0 or unit_count > maximum_units:
		return false
	state["bytes"] = consumed_bytes + unit_count * bytes_per_unit
	return true


func _consume_snapshot_bytes(state: Dictionary, byte_count: int) -> bool:
	return _consume_snapshot_units(state, byte_count, 1)
