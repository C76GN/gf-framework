## GFNetworkTransportMetrics: 网络传输指标快照。
##
## 指标只在显式写入后才视为已知，避免用 0 混淆“真实为零”与“后端不支持”。
## 内置指标覆盖流量、包数、连接时长、队列、延迟、抖动和丢包率；Adapter
## 也可以写入命名稳定的自定义非负指标。总指标数、自定义指标数和 ID 长度
## 均受绝对上限约束，任何超限的新指标都失败关闭。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 10.0.0
class_name GFNetworkTransportMetrics
extends RefCounted


# --- 常量 ---

## 单个指标快照允许的绝对最大指标数量。
## [br]
## @api public
## [br]
## @since unreleased
const ABSOLUTE_MAX_METRIC_COUNT: int = 64

## 单个指标快照允许的绝对最大自定义指标数量。
## [br]
## @api public
## [br]
## @since unreleased
const ABSOLUTE_MAX_CUSTOM_METRIC_COUNT: int = 48

## 指标 ID 允许的绝对最大字符数。
## [br]
## @api public
## [br]
## @since unreleased
const ABSOLUTE_MAX_METRIC_ID_LENGTH: int = 64

## 已发送字节数。
## [br]
## @api public
## [br]
## @since 10.0.0
const BYTES_SENT: StringName = &"bytes_sent"

## 已接收字节数。
## [br]
## @api public
## [br]
## @since 10.0.0
const BYTES_RECEIVED: StringName = &"bytes_received"

## 已发送包数。
## [br]
## @api public
## [br]
## @since 10.0.0
const PACKETS_SENT: StringName = &"packets_sent"

## 已接收包数。
## [br]
## @api public
## [br]
## @since 10.0.0
const PACKETS_RECEIVED: StringName = &"packets_received"

## 当前连接时长，单位毫秒。
## [br]
## @api public
## [br]
## @since 10.0.0
const CONNECTION_AGE_MSEC: StringName = &"connection_age_msec"

## 往返延迟，单位毫秒。
## [br]
## @api public
## [br]
## @since 10.0.0
const ROUND_TRIP_TIME_MSEC: StringName = &"round_trip_time_msec"

## 延迟抖动，单位毫秒。
## [br]
## @api public
## [br]
## @since 10.0.0
const JITTER_MSEC: StringName = &"jitter_msec"

## 丢包率，取值范围为 0 到 1。
## [br]
## @api public
## [br]
## @since 10.0.0
const PACKET_LOSS_RATIO: StringName = &"packet_loss_ratio"

## 发送队列包数。
## [br]
## @api public
## [br]
## @since 10.0.0
const SEND_QUEUE_PACKETS: StringName = &"send_queue_packets"

## 接收队列包数。
## [br]
## @api public
## [br]
## @since 10.0.0
const RECEIVE_QUEUE_PACKETS: StringName = &"receive_queue_packets"


# --- 公共变量 ---

## 采样单调时间戳，单位毫秒。
## [br]
## @api public
## [br]
## @since 10.0.0
var sample_time_msec: int = 0

## 统计窗口长度，单位毫秒；0 表示累计值或未知窗口。
## [br]
## @api public
## [br]
## @since 10.0.0
var sample_window_msec: int = 0


# --- 私有变量 ---

var _metrics: Dictionary[StringName, float] = {}


# --- 公共方法 ---

## 写入一个已知指标。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param metric_id: 非空稳定指标 ID。
## [br]
## @param value: 有限非负值；packet_loss_ratio 额外限制在 0 到 1。
## [br]
## @return 指标合法、未突破容量并已写入时返回 true；达到容量后仍可更新既有指标。
func set_metric(metric_id: StringName, value: float) -> bool:
	var normalized_id: StringName = _normalize_metric_id(metric_id)
	if normalized_id == &"" or not is_finite(value) or value < 0.0:
		return false
	if normalized_id == PACKET_LOSS_RATIO and value > 1.0:
		return false
	if not _metrics.has(normalized_id):
		if _metrics.size() >= ABSOLUTE_MAX_METRIC_COUNT:
			return false
		if (
			not _is_builtin_metric_id(normalized_id)
			and _get_custom_metric_count() >= ABSOLUTE_MAX_CUSTOM_METRIC_COUNT
		):
			return false
	_metrics[normalized_id] = value
	return true


## 移除一个指标，使其恢复为未知。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param metric_id: 指标 ID。
## [br]
## @return 指标原本存在时返回 true。
func clear_metric(metric_id: StringName) -> bool:
	return _metrics.erase(_normalize_metric_id(metric_id))


## 检查指标是否已知。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param metric_id: 指标 ID。
## [br]
## @return 指标存在时返回 true。
func has_metric(metric_id: StringName) -> bool:
	return _metrics.has(_normalize_metric_id(metric_id))


## 获取指标值。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param metric_id: 指标 ID。
## [br]
## @param default_value: 指标未知时的返回值。
## [br]
## @return 指标值或默认值。
func get_metric(metric_id: StringName, default_value: float = 0.0) -> float:
	return _metrics.get(_normalize_metric_id(metric_id), default_value)


## 获取排序后的已知指标 ID。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 已知指标 ID。
func get_metric_ids() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for metric_id: StringName in _metrics.keys():
		var _appended: bool = result.append(String(metric_id))
	result.sort()
	return result


## 合并另一个快照中的已知指标。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param other: 指标来源。
func merge_from(other: GFNetworkTransportMetrics) -> void:
	if other == null:
		return
	for metric_id_text: String in other.get_metric_ids():
		var metric_id: StringName = StringName(metric_id_text)
		var _set: bool = set_metric(metric_id, other.get_metric(metric_id))


## 转换为 JSON 安全字典。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 指标快照字典。
## [br]
## @schema return: Dictionary with sample_time_msec, sample_window_msec, and metrics.
func to_dict() -> Dictionary:
	var metric_values: Dictionary = {}
	for metric_id_text: String in get_metric_ids():
		var metric_id: StringName = StringName(metric_id_text)
		metric_values[metric_id_text] = get_metric(metric_id)
	return {
		"sample_time_msec": sample_time_msec,
		"sample_window_msec": sample_window_msec,
		"metrics": metric_values,
	}


## 从字典应用指标快照。
##
## 只读取输入 metrics 的前 `ABSOLUTE_MAX_METRIC_COUNT` 个条目，不复制或遍历
## 完整容器；无效、未知类型或超限条目失败关闭。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param data: 指标快照字典。
## [br]
## @schema data: Dictionary with sample_time_msec, sample_window_msec, and metrics.
func apply_dict(data: Dictionary) -> void:
	sample_time_msec = maxi(GFVariantData.get_option_int(data, "sample_time_msec"), 0)
	sample_window_msec = maxi(GFVariantData.get_option_int(data, "sample_window_msec"), 0)
	_metrics.clear()
	var metric_values_value: Variant = data.get("metrics", {})
	if not (metric_values_value is Dictionary):
		return
	var metric_values: Dictionary = metric_values_value
	var processed_entry_count: int = 0
	for key_value: Variant in metric_values:
		if processed_entry_count >= ABSOLUTE_MAX_METRIC_COUNT:
			break
		processed_entry_count += 1
		if not (key_value is String or key_value is StringName):
			continue
		var raw_metric_id: String = ""
		if key_value is String:
			var string_metric_id: String = key_value
			raw_metric_id = string_metric_id
		else:
			var string_name_metric_id: StringName = key_value
			raw_metric_id = String(string_name_metric_id)
		if raw_metric_id.length() > ABSOLUTE_MAX_METRIC_ID_LENGTH:
			continue
		var value: Variant = metric_values[key_value]
		if not (value is int or value is float):
			continue
		var numeric_value: float = 0.0
		if value is int:
			var int_value: int = value
			numeric_value = float(int_value)
		elif value is float:
			var float_value: float = value
			numeric_value = float_value
		var _set: bool = set_metric(
			StringName(raw_metric_id),
			numeric_value
		)


## 创建快照深拷贝。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 新指标快照。
func duplicate_metrics() -> GFNetworkTransportMetrics:
	return from_dict(to_dict())


## 从字典创建指标快照。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param data: 指标快照字典。
## [br]
## @schema data: Dictionary with sample_time_msec, sample_window_msec, and metrics.
## [br]
## @return 新指标快照。
static func from_dict(data: Dictionary) -> GFNetworkTransportMetrics:
	var metrics: GFNetworkTransportMetrics = GFNetworkTransportMetrics.new()
	metrics.apply_dict(data)
	return metrics


# --- 私有/辅助方法 ---

static func _normalize_metric_id(metric_id: StringName) -> StringName:
	var raw_text: String = String(metric_id)
	if raw_text.length() > ABSOLUTE_MAX_METRIC_ID_LENGTH:
		return &""
	var normalized_text: String = raw_text.strip_edges()
	if (
		normalized_text.is_empty()
		or normalized_text.length() > ABSOLUTE_MAX_METRIC_ID_LENGTH
	):
		return &""
	return StringName(normalized_text)


static func _is_builtin_metric_id(metric_id: StringName) -> bool:
	return metric_id in [
		BYTES_SENT,
		BYTES_RECEIVED,
		PACKETS_SENT,
		PACKETS_RECEIVED,
		CONNECTION_AGE_MSEC,
		ROUND_TRIP_TIME_MSEC,
		JITTER_MSEC,
		PACKET_LOSS_RATIO,
		SEND_QUEUE_PACKETS,
		RECEIVE_QUEUE_PACKETS,
	]


func _get_custom_metric_count() -> int:
	var custom_metric_count: int = 0
	for metric_id: StringName in _metrics:
		if not _is_builtin_metric_id(metric_id):
			custom_metric_count += 1
	return custom_metric_count
