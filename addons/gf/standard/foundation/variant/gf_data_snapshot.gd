## GFDataSnapshot: 隔离纯数据后发布的只读快照。
##
## 捕获期间源数据必须稳定。共享子容器按值展开，循环、对象和对象类型容器被拒绝。
## 读取返回独立副本，后台任务可保留快照直到物理执行结束。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since unreleased
class_name GFDataSnapshot
extends RefCounted


# --- 常量 ---

## 内核拥有纯数据复制与预算规则。
## [br]
## @api private
const _CAPTURE_SCRIPT = preload("res://addons/gf/kernel/core/gf_data_value_capture.gd")


# --- 私有变量 ---

## 本快照独占的数据树，只交给框架内部只读执行器。
## [br]
## @api private
var _value: Variant = null

## 成功捕获时的固定计量。
## [br]
## @api private
var _statistics: Dictionary = {}

## 捕获时的数值限制，供导出使用。
## [br]
## @api private
var _limits: Dictionary = {}

## 构造完成标记。
## [br]
## @api private
var _ready: bool = false


# --- 公共方法 ---

## 完整捕获成功后发布快照，失败保留结构化诊断。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param value: 调用期间保持稳定的纯数据。
## [br]
## @schema value: Built-in Variant values and typed containers without objects, executable values, RID or cycles.
## [br]
## @param limits: 有限数据预算。
## [br]
## @schema limits: Dictionary with positive max_items (1000000), max_depth (64, at most 256), max_string_length (1048576), max_payload_bytes (67108864), max_elapsed_msec (30000), and optional cancel_token: GFCancellationToken. Payload counts logical scalar widths, UTF-8 strings and packed storage; nodes have a separate item budget.
## [br]
## @return 快照或捕获失败的计量。
## [br]
## @schema return: Dictionary with ok, snapshot: GFDataSnapshot or null, error_kind, error_path, limit_kind, limit, observed, counts_complete, items, packed_items, payload_bytes and maximum_depth. Failed counts describe only processed input.
static func capture(value: Variant, limits: Dictionary = {}) -> Dictionary:
	var report: Dictionary = _CAPTURE_SCRIPT.capture(value, limits)
	var snapshot: GFDataSnapshot = null
	if report["ok"]:
		snapshot = GFDataSnapshot.new()
		snapshot._value = report["value"]
		for key: Variant in limits:
			if limits[key] is int:
				snapshot._limits[key] = limits[key]
		snapshot._ready = true
	var _removed_value: bool = report.erase("value")
	if snapshot != null:
		snapshot._statistics = report.duplicate()
	report["snapshot"] = snapshot
	return report


## 返回快照是否已完成捕获。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 可以用于读取及任务提交时为 true。
func is_ready() -> bool:
	return _ready


## 返回成功捕获的计量副本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 仅包含标量的捕获计量。
## [br]
## @schema return: Dictionary containing capture counters and status, without a mutable payload.
func get_statistics() -> Dictionary:
	return _statistics.duplicate()


## 显式导出可修改的工作树；各次导出彼此隔离。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param limits: 覆盖原捕获数值预算，可额外提供取消令牌。
## [br]
## @schema limits: Dictionary with the same limits as capture.
## [br]
## @return 可变副本与结构化计量。
## [br]
## @schema return: Dictionary with capture fields and value: Variant; on failure value is null.
func copy_value(limits: Dictionary = {}) -> Dictionary:
	if not _ready:
		return {
			"ok": false,
			"value": null,
			"error_kind": "snapshot_unavailable",
			"error_path": "$",
			"limit_kind": "",
			"limit": 0,
			"observed": 0,
			"counts_complete": false,
			"items": 0,
			"packed_items": 0,
			"payload_bytes": 0,
			"maximum_depth": 0,
		}
	var effective_limits: Dictionary = _limits.duplicate()
	effective_limits.merge(limits, true)
	return _CAPTURE_SCRIPT.capture(_value, effective_limits)


## 读取指定字典键或数组索引路径，结果与快照隔离。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param path: 根路径为空；数组项使用非负 int，字典项使用存在的键。
## [br]
## @schema path: Array of Dictionary keys or nonnegative Array indices.
## [br]
## @return 指定值的副本，路径不存在或快照无效时返回 null。
## [br]
## @schema return: Detached Variant value or null.
func get_value(path: Array = []) -> Variant:
	if not _ready:
		return null
	var selected: Variant = _value
	for key: Variant in path:
		if selected is Dictionary:
			var dictionary: Dictionary = selected
			if not dictionary.has(key):
				return null
			selected = dictionary[key]
		elif selected is Array and key is int:
			var array: Array = selected
			var index: int = key
			if index < 0 or index >= array.size():
				return null
			selected = array[index]
		else:
			return null
	var report: Dictionary = _CAPTURE_SCRIPT.capture(selected, _limits)
	return report["value"]


# --- 框架内部方法 ---

## 向只读框架编码器借出内部树。调用方不得修改、发布或保留可变子容器。
## [br]
## @api framework_internal
## [br]
## @return 快照独占的根值。
## [br]
## @schema return: Read-only borrowed Variant valid while the snapshot is retained.
func get_value_for_framework() -> Variant:
	return _value
