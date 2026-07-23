## GFNetworkTransportMetrics: 网络传输指标快照。
##
## 指标只在显式写入后才视为已知，避免用 0 混淆“真实为零”与“后端不支持”。
## 内置指标覆盖流量、包数、连接时长、队列、延迟、抖动和丢包率；Adapter
## 也可以写入命名稳定的自定义非负指标。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since unreleased
class_name GFNetworkTransportMetrics
extends RefCounted


# --- 常量 ---

## 已发送字节数。
## [br]
## @api public
## [br]
## @since unreleased
const BYTES_SENT: StringName = &"bytes_sent"

## 已接收字节数。
## [br]
## @api public
## [br]
## @since unreleased
const BYTES_RECEIVED: StringName = &"bytes_received"

## 已发送包数。
## [br]
## @api public
## [br]
## @since unreleased
const PACKETS_SENT: StringName = &"packets_sent"

## 已接收包数。
## [br]
## @api public
## [br]
## @since unreleased
const PACKETS_RECEIVED: StringName = &"packets_received"

## 当前连接时长，单位毫秒。
## [br]
## @api public
## [br]
## @since unreleased
const CONNECTION_AGE_MSEC: StringName = &"connection_age_msec"

## 往返延迟，单位毫秒。
## [br]
## @api public
## [br]
## @since unreleased
const ROUND_TRIP_TIME_MSEC: StringName = &"round_trip_time_msec"

## 延迟抖动，单位毫秒。
## [br]
## @api public
## [br]
## @since unreleased
const JITTER_MSEC: StringName = &"jitter_msec"

## 丢包率，取值范围为 0 到 1。
## [br]
## @api public
## [br]
## @since unreleased
const PACKET_LOSS_RATIO: StringName = &"packet_loss_ratio"

## 发送队列包数。
## [br]
## @api public
## [br]
## @since unreleased
const SEND_QUEUE_PACKETS: StringName = &"send_queue_packets"

## 接收队列包数。
## [br]
## @api public
## [br]
## @since unreleased
const RECEIVE_QUEUE_PACKETS: StringName = &"receive_queue_packets"


# --- 公共变量 ---

## 采样单调时间戳，单位毫秒。
## [br]
## @api public
## [br]
## @since unreleased
var sample_time_msec: int = 0

## 统计窗口长度，单位毫秒；0 表示累计值或未知窗口。
## [br]
## @api public
## [br]
## @since unreleased
var sample_window_msec: int = 0


# --- 私有变量 ---

var _metrics: Dictionary[StringName, float] = {}


# --- 公共方法 ---

## 写入一个已知指标。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param metric_id: 非空稳定指标 ID。
## [br]
## @param value: 有限非负值；packet_loss_ratio 额外限制在 0 到 1。
## [br]
## @return 指标合法并已写入时返回 true。
func set_metric(metric_id: StringName, value: float) -> bool:
	var normalized_id: StringName = _normalize_metric_id(metric_id)
	if normalized_id == &"" or not is_finite(value) or value < 0.0:
		return false
	if normalized_id == PACKET_LOSS_RATIO and value > 1.0:
		return false
	_metrics[normalized_id] = value
	return true


## 移除一个指标，使其恢复为未知。
## [br]
## @api public
## [br]
## @since unreleased
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
## @since unreleased
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
## @since unreleased
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
## @since unreleased
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
## @since unreleased
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
## @since unreleased
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
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param data: 指标快照字典。
## [br]
## @schema data: Dictionary with sample_time_msec, sample_window_msec, and metrics.
func apply_dict(data: Dictionary) -> void:
	sample_time_msec = maxi(GFVariantData.get_option_int(data, "sample_time_msec"), 0)
	sample_window_msec = maxi(GFVariantData.get_option_int(data, "sample_window_msec"), 0)
	_metrics.clear()
	var metric_values: Dictionary = GFVariantData.get_option_dictionary(data, "metrics")
	for key_value: Variant in metric_values.keys():
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
			StringName(GFVariantData.to_text(key_value)),
			numeric_value
		)


## 创建快照深拷贝。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 新指标快照。
func duplicate_metrics() -> GFNetworkTransportMetrics:
	return from_dict(to_dict())


## 从字典创建指标快照。
## [br]
## @api public
## [br]
## @since unreleased
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
	return StringName(String(metric_id).strip_edges())
