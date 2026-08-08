## GFVirtualListSyncResult: 虚拟列表同步的不可变诊断结果。
##
## 只保存范围、计数、版本和稳定错误信息，不保存项目条目数据或原始稳定 ID。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since unreleased
class_name GFVirtualListSyncResult
extends RefCounted


# --- 常量 ---

## 目标范围已完整同步。
## [br]
## @api public
## [br]
## @since unreleased
const STATUS_SYNCED: StringName = &"synced"

## 当前 materialization 已满足目标且没有结构变化。
## [br]
## @api public
## [br]
## @since unreleased
const STATUS_UNCHANGED: StringName = &"unchanged"

## 当前轮冻结快照在完成提交前或项目绑定副作用期间失效；Binder 已保留后续同步请求。
## [br]
## 该状态不表示同步成功。若漂移发生在绑定副作用前，Binder 保留最近一次可信
## materialization；若已调用 bind/unbind、测量、布局或焦点副作用，则对称解绑并清空
## 不可信 materialization。调用方应以结果中的当前索引为准并等待下一轮结果。
## [br]
## @api public
## [br]
## @since unreleased
const STATUS_DEFERRED: StringName = &"deferred"

## 目标范围超过显式节点预算，已优先物化真实视口范围。
## [br]
## @api public
## [br]
## @since unreleased
const STATUS_TRUNCATED: StringName = &"truncated"

## Binder 当前没有有效绑定。
## [br]
## @api public
## [br]
## @since unreleased
const STATUS_UNBOUND: StringName = &"unbound"

## Binder 已进入不可复用的终态。
## [br]
## @api public
## [br]
## @since unreleased
const STATUS_DISPOSED: StringName = &"disposed"

## identity callback 返回了不可稳定编码的值。
## [br]
## @api public
## [br]
## @since unreleased
const STATUS_INVALID_IDENTITY: StringName = &"invalid_identity"

## 当前请求范围包含重复稳定 identity。
## [br]
## @api public
## [br]
## @since unreleased
const STATUS_DUPLICATE_IDENTITY: StringName = &"duplicate_identity"

## item factory 没有返回可接管的 parentless Control。
## [br]
## @api public
## [br]
## @since unreleased
const STATUS_FACTORY_FAILED: StringName = &"factory_failed"

## 项目 bind callback 拒绝了一个条目。
## [br]
## @api public
## [br]
## @since unreleased
const STATUS_BIND_FAILED: StringName = &"bind_failed"

# JSON number 可以无损表达的最大整数。
# 所有写入诊断摘要的 revision、count 与 error_index 都必须位于对应语义范围内。
const _MAX_JSON_SAFE_INTEGER: int = 9_007_199_254_740_991
const _MAX_ERROR_LENGTH: int = 512


# --- 私有变量 ---

var _configured: bool = false
var _status: StringName = STATUS_UNBOUND
var _layout_revision: int = 0
var _data_revision: int = 0
var _viewport_range: Vector2i = Vector2i.ZERO
var _requested_range: Vector2i = Vector2i.ZERO
var _materialized_indices: PackedInt32Array = PackedInt32Array()
var _pooled_count: int = 0
var _created_count: int = 0
var _reused_count: int = 0
var _released_count: int = 0
var _measured_count: int = 0
var _anchor_adjustment: float = 0.0
var _truncated: bool = false
var _error_index: int = -1
var _error: String = ""


# --- 公共方法 ---

## 检查同步是否提交了内部一致的目标状态。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 完整、无变化或按显式预算截断完成时返回 true。
func is_successful() -> bool:
	return _status in [STATUS_SYNCED, STATUS_UNCHANGED, STATUS_TRUNCATED]


## 获取稳定同步状态。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return `STATUS_*` 常量之一。
func get_status() -> StringName:
	return _status


## 获取本轮计算范围前冻结的布局版本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return `GFVirtualListModel` revision。
func get_layout_revision() -> int:
	return _layout_revision


## 获取本轮开始时冻结的 Binder 数据失效版本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 从 0 开始的 data revision。
func get_data_revision() -> int:
	return _data_revision


## 获取未加入 overscan 的真实视口范围。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return Vector2i(start, end)，end 不包含。
func get_viewport_range() -> Vector2i:
	return _viewport_range


## 获取加入 overscan、应用预算前的请求范围。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return Vector2i(start, end)，end 不包含。
func get_requested_range() -> Vector2i:
	return _requested_range


## 获取实际物化索引副本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 升序物化索引。
func get_materialized_indices() -> PackedInt32Array:
	return _materialized_indices.duplicate()


## 获取实际物化数量。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 当前活动 Control 数量。
func get_materialized_count() -> int:
	return _materialized_indices.size()


## 获取当前池内可复用 Control 数量。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return parentless 池节点数量。
func get_pooled_count() -> int:
	return _pooled_count


## 获取本轮新建 Control 数量。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return factory 成功创建数量。
func get_created_count() -> int:
	return _created_count


## 获取本轮从旧 active 或 pool 复用数量。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 复用数量。
func get_reused_count() -> int:
	return _reused_count


## 获取本轮离开旧绑定的数量。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 已执行 unbind 的旧绑定数量。
func get_released_count() -> int:
	return _released_count


## 获取本轮成功测量的行数量。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 测量数量。
func get_measured_count() -> int:
	return _measured_count


## 获取本轮一次性应用的滚动锚点修正。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 主轴滚动调整量。
func get_anchor_adjustment() -> float:
	return _anchor_adjustment


## 检查是否因 materialization 上限截断。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 目标范围未完整物化时返回 true。
func was_truncated() -> bool:
	return _truncated


## 获取首个失败条目索引。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 没有索引错误时为 -1。
func get_error_index() -> int:
	return _error_index


## 获取有界稳定错误说明。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 成功时为空。
func get_error() -> String:
	return _error


## 创建结果的隔离副本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 新结果对象。
func duplicate_result() -> GFVirtualListSyncResult:
	var result: GFVirtualListSyncResult = GFVirtualListSyncResult.new()
	var _configured_result: bool = result.configure_for_framework(to_dict())
	return result


## 转换为不含项目数据的诊断字典。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return JSON-safe 同步摘要；状态使用 String，范围与索引只使用 JSON 原生容器和整数。
## [br]
## @schema return: Dictionary with String status; viewport_range and requested_range Dictionaries containing start and end_exclusive ints; materialized_indices Array[int]; revisions and counts in 0..9007199254740991; finite anchor_adjustment; truncated; error_index in -1..9007199254740991; and error.
func to_dict() -> Dictionary:
	var materialized_indices: Array[int] = []
	for item_index: int in _materialized_indices:
		materialized_indices.append(item_index)
	return {
		"status": String(_status),
		"layout_revision": _layout_revision,
		"data_revision": _data_revision,
		"viewport_range": _range_to_json_dictionary(_viewport_range),
		"requested_range": _range_to_json_dictionary(_requested_range),
		"materialized_indices": materialized_indices,
		"pooled_count": _pooled_count,
		"created_count": _created_count,
		"reused_count": _reused_count,
		"released_count": _released_count,
		"measured_count": _measured_count,
		"anchor_adjustment": _anchor_adjustment,
		"truncated": _truncated,
		"error_index": _error_index,
		"error": _error,
	}


# --- 框架内部方法 ---

## 由 VirtualList Binder 一次性配置结果。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param data: 同步诊断字段。
## [br]
## @return 首次配置、状态有效且所有 revision/count/error_index 位于 JSON 安全整数范围时返回 true。
## [br]
## @schema data: Dictionary accepting String or StringName status; typed Vector2i or JSON range Dictionaries with start and end_exclusive; PackedInt32Array or JSON Array materialized_indices; layout_revision, data_revision and count fields in 0..9007199254740991; error_index in -1..9007199254740991; and the remaining scalar fields emitted by to_dict().
func configure_for_framework(data: Dictionary) -> bool:
	if _configured:
		return false
	var status: StringName = GFVariantData.get_option_string_name(data, "status", STATUS_UNBOUND)
	if not _is_known_status(status):
		return false
	if (
		not _has_bounded_json_integer(data, "layout_revision", 0, 0)
		or not _has_bounded_json_integer(data, "data_revision", 0, 0)
		or not _has_bounded_json_integer(data, "pooled_count", 0, 0)
		or not _has_bounded_json_integer(data, "created_count", 0, 0)
		or not _has_bounded_json_integer(data, "reused_count", 0, 0)
		or not _has_bounded_json_integer(data, "released_count", 0, 0)
		or not _has_bounded_json_integer(data, "measured_count", 0, 0)
		or not _has_bounded_json_integer(data, "error_index", -1, -1)
	):
		return false
	_configured = true
	_status = status
	_layout_revision = GFVariantData.get_option_int(data, "layout_revision")
	_data_revision = GFVariantData.get_option_int(data, "data_revision")
	_viewport_range = _get_vector_2i(data, "viewport_range")
	_requested_range = _get_vector_2i(data, "requested_range")
	_materialized_indices = _get_packed_int_32_array(data, "materialized_indices")
	_pooled_count = GFVariantData.get_option_int(data, "pooled_count")
	_created_count = GFVariantData.get_option_int(data, "created_count")
	_reused_count = GFVariantData.get_option_int(data, "reused_count")
	_released_count = GFVariantData.get_option_int(data, "released_count")
	_measured_count = GFVariantData.get_option_int(data, "measured_count")
	var anchor_adjustment: float = GFVariantData.get_option_float(data, "anchor_adjustment")
	_anchor_adjustment = anchor_adjustment if is_finite(anchor_adjustment) else 0.0
	_truncated = GFVariantData.get_option_bool(data, "truncated")
	_error_index = GFVariantData.get_option_int(data, "error_index", -1)
	_error = GFVariantData.get_option_string(data, "error").left(_MAX_ERROR_LENGTH)
	return true


# --- 私有/辅助方法 ---

func _is_known_status(status: StringName) -> bool:
	return status in [
		STATUS_SYNCED,
		STATUS_UNCHANGED,
		STATUS_DEFERRED,
		STATUS_TRUNCATED,
		STATUS_UNBOUND,
		STATUS_DISPOSED,
		STATUS_INVALID_IDENTITY,
		STATUS_DUPLICATE_IDENTITY,
		STATUS_FACTORY_FAILED,
		STATUS_BIND_FAILED,
	]


func _has_bounded_json_integer(
	data: Dictionary,
	key: String,
	default_value: int,
	minimum_value: int
) -> bool:
	var value: Variant = GFVariantData.get_option_value(data, key, default_value)
	if value is int:
		var integer_value: int = value
		return integer_value >= minimum_value and integer_value <= _MAX_JSON_SAFE_INTEGER
	if value is float:
		var json_number: float = value
		return (
			is_finite(json_number)
			and json_number == floor(json_number)
			and json_number >= float(minimum_value)
			and json_number <= float(_MAX_JSON_SAFE_INTEGER)
		)
	return false


func _get_vector_2i(data: Dictionary, key: String) -> Vector2i:
	var value: Variant = GFVariantData.get_option_value(data, key, Vector2i.ZERO)
	if value is Vector2i:
		var vector: Vector2i = value
		return vector
	if value is Dictionary:
		var range_data: Dictionary = value
		return Vector2i(
			GFVariantData.get_option_int(range_data, "start"),
			GFVariantData.get_option_int(range_data, "end_exclusive")
		)
	return Vector2i.ZERO


func _get_packed_int_32_array(data: Dictionary, key: String) -> PackedInt32Array:
	var value: Variant = GFVariantData.get_option_value(data, key, PackedInt32Array())
	if value is PackedInt32Array:
		var packed_values: PackedInt32Array = value
		return packed_values.duplicate()
	if value is Array:
		var result: PackedInt32Array = PackedInt32Array()
		var array_values: Array = value
		for item: Variant in array_values:
			if item is int:
				var item_index: int = item
				if item_index >= -2_147_483_648 and item_index <= 2_147_483_647:
					var _append_int_result: bool = result.append(item_index)
			elif item is float:
				var numeric_index: float = item
				if (
					is_finite(numeric_index)
					and numeric_index == floor(numeric_index)
					and numeric_index >= -2_147_483_648.0
					and numeric_index <= 2_147_483_647.0
				):
					var _append_float_result: bool = result.append(int(numeric_index))
		return result
	return PackedInt32Array()


func _range_to_json_dictionary(range_value: Vector2i) -> Dictionary:
	return {
		"start": range_value.x,
		"end_exclusive": range_value.y,
	}
