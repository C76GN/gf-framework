## GFNetworkBackend: 网络后端抽象基类。
##
## 后端负责具体传输协议，框架层只依赖该统一接口与信号。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 3.17.0
class_name GFNetworkBackend
extends RefCounted


# --- 信号 ---

## 连接成功后发出。
## [br]
## @api public
signal connected

## 断开连接后发出。
## [br]
## @api public
## [br]
## @param reason: 断开原因。
signal disconnected(reason: String)

## 远端节点连接后发出。
## [br]
## @api public
## [br]
## @param peer_id: 远端 peer 标识。
signal peer_connected(peer_id: int)

## 远端节点断开后发出。
## [br]
## @api public
## [br]
## @param peer_id: 远端 peer 标识。
signal peer_disconnected(peer_id: int)

## 收到原始消息 bytes 后发出。
## [br]
## @api public
## [br]
## @param peer_id: 远端 peer 标识。
## [br]
## @param bytes: 原始消息 bytes。
signal message_received(peer_id: int, bytes: PackedByteArray)


# --- 常量 ---

## Backend 补充一次传输指标允许的最大同步耗时，单位毫秒。
## [br]
## @api public
## [br]
## @since unreleased
const MAX_TRANSPORT_METRICS_ENRICHMENT_MSEC: int = 10


# --- 私有变量 ---

var _transport_bytes_sent: int = 0
var _transport_bytes_received: int = 0
var _transport_packets_sent: int = 0
var _transport_packets_received: int = 0
var _transport_connected: bool = false
var _transport_connected_at_msec: int = 0


# --- 公共方法 ---

## 启动主机。
## [br]
## @api public
## [br]
## @param _options: 后端自定义选项。
## [br]
## @return Godot 错误码。
## [br]
## @schema _options: Dictionary，后端自定义启动选项。
func host(_options: Dictionary = {}) -> Error:
	return ERR_UNAVAILABLE


## 连接远端。
## [br]
## @api public
## [br]
## @param _endpoint: 远端地址。
## [br]
## @param _options: 后端自定义选项。
## [br]
## @return Godot 错误码。
## [br]
## @schema _options: Dictionary，后端自定义连接选项。
func connect_to_endpoint(_endpoint: String, _options: Dictionary = {}) -> Error:
	return ERR_UNAVAILABLE


## 断开连接。
## [br]
## @api public
func disconnect_backend() -> void:
	pass


## 发送 bytes。
## [br]
## @api public
## [br]
## @param _peer_id: 目标 peer；后端可约定 -1 表示广播。
## [br]
## @param _bytes: 消息 bytes。
## [br]
## @param _options: 后端自定义发送选项。
## [br]
## @return Godot 错误码。
## [br]
## @schema _options: Dictionary，后端自定义发送选项。
func send_bytes(_peer_id: int, _bytes: PackedByteArray, _options: Dictionary = {}) -> Error:
	return ERR_UNAVAILABLE


## 后端轮询入口。需要轮询的后端可重写。
## [br]
## @api public
## [br]
## @param _delta: 帧间隔。
func poll(_delta: float) -> void:
	pass


## 检查 Backend 是否已建立连接。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 已收到连接终态且尚未断开时返回 true。
func is_backend_connected() -> bool:
	return _transport_connected


## 获取已建立外部连接的会话接管信息。
##
## 普通 Backend 返回空字典，由 `host()` / `connect_to_endpoint()` 建立 Session；
## 接管外部 Peer 的 Backend 可返回 mode、endpoint、local_peer_id 和 metadata。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 可选会话接管字段。
## [br]
## @schema return: Dictionary with optional mode, endpoint, local_peer_id, and metadata.
func get_session_bootstrap() -> Dictionary:
	return {}


## 获取后端调试快照。
## [br]
## @api public
## [br]
## @return 调试信息字典。
## [br]
## @schema return: Dictionary，包含 backend、available 以及后端自定义状态字段。
func get_debug_snapshot() -> Dictionary:
	return {
		"backend": get_script().resource_path if get_script() != null else "",
		"available": false,
		"transport_metrics": get_transport_metrics().to_dict(),
	}


## 获取当前传输指标快照。
##
## 基类统一统计成功发送和已派发接收的 bytes/packet 数。具体后端可通过
## `_enrich_transport_metrics` 补充 RTT、丢包率或队列等可选指标。该入口是
## 同步、无副作用且有硬输出上限的模板方法；Backend 不应重写本方法，也不得
## 在补充钩子中执行网络、磁盘或不可中断的业务 I/O。补充钩子超过协作预算时，
## 本次调用只返回基础指标。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 当前指标快照；未知指标不会出现在快照中。
func get_transport_metrics() -> GFNetworkTransportMetrics:
	var now_msec: int = Time.get_ticks_msec()
	var metrics: GFNetworkTransportMetrics = GFNetworkTransportMetrics.new()
	metrics.sample_time_msec = now_msec
	var _bytes_sent_set: bool = metrics.set_metric(
		GFNetworkTransportMetrics.BYTES_SENT,
		float(_transport_bytes_sent)
	)
	var _bytes_received_set: bool = metrics.set_metric(
		GFNetworkTransportMetrics.BYTES_RECEIVED,
		float(_transport_bytes_received)
	)
	var _packets_sent_set: bool = metrics.set_metric(
		GFNetworkTransportMetrics.PACKETS_SENT,
		float(_transport_packets_sent)
	)
	var _packets_received_set: bool = metrics.set_metric(
		GFNetworkTransportMetrics.PACKETS_RECEIVED,
		float(_transport_packets_received)
	)
	if _transport_connected:
		var _connection_age_set: bool = metrics.set_metric(
			GFNetworkTransportMetrics.CONNECTION_AGE_MSEC,
			float(maxi(now_msec - _transport_connected_at_msec, 0))
		)
	var base_metrics: GFNetworkTransportMetrics = metrics.duplicate_metrics()
	var enrichment_budget: GFExecutionBudget = GFExecutionBudget.new({
		"max_steps": GFNetworkTransportMetrics.ABSOLUTE_MAX_METRIC_COUNT,
		"max_elapsed_msec": MAX_TRANSPORT_METRICS_ENRICHMENT_MSEC,
	})
	_enrich_transport_metrics(metrics, enrichment_budget)
	if not enrichment_budget.check():
		return base_metrics
	if (
		metrics.sample_time_msec != base_metrics.sample_time_msec
		or metrics.sample_window_msec != base_metrics.sample_window_msec
	):
		return base_metrics
	var base_metric_ids: PackedStringArray = base_metrics.get_metric_ids()
	for base_metric_id_text: String in base_metric_ids:
		var base_metric_id: StringName = StringName(base_metric_id_text)
		if (
			not metrics.has_metric(base_metric_id)
			or metrics.get_metric(base_metric_id) != base_metrics.get_metric(
				base_metric_id
			)
		):
			return base_metrics
	var added_metric_count: int = 0
	for current_metric_id_text: String in metrics.get_metric_ids():
		var current_metric_id: StringName = StringName(current_metric_id_text)
		if not base_metrics.has_metric(current_metric_id):
			added_metric_count += 1
	if added_metric_count > enrichment_budget.get_steps():
		return base_metrics
	return metrics


# --- 可重写钩子 / 虚方法 ---

## 向基础指标快照写入后端特有指标。
##
## 实现必须保持同步、无副作用、有限时间和有限工作量，只读取已经在内存中的
## 传输状态；不得发起网络、磁盘、锁等待或项目业务调用。每次尝试写入一个可选
## 指标前必须消耗一步预算，并在预算或 `set_metric()` 拒绝时立即停止。预算只能
## 协作式终止循环，不能中断阻塞调用，因此不可中断 I/O 从契约上禁止进入此钩子。
## [br]
## @api protected
## [br]
## @since 10.0.0
## [br]
## @param _metrics: 可追加已知指标的有界快照。
## [br]
## @param _budget: 必须在每次可选指标写入前消费的协作式执行预算。
func _enrich_transport_metrics(
	_metrics: GFNetworkTransportMetrics,
	_budget: GFExecutionBudget
) -> void:
	pass


## 记录一次成功发送。
## [br]
## @api protected
## [br]
## @since 10.0.0
## [br]
## @param byte_count: 已交给传输层的字节数。
func _record_transport_packet_sent(byte_count: int) -> void:
	_transport_bytes_sent += maxi(byte_count, 0)
	_transport_packets_sent += 1


## 重置当前连接的累计传输指标。
## [br]
## @api protected
## [br]
## @since 10.0.0
func _reset_transport_metrics() -> void:
	_transport_bytes_sent = 0
	_transport_bytes_received = 0
	_transport_packets_sent = 0
	_transport_packets_received = 0


# --- 私有/辅助方法 ---

func _emit_connected() -> void:
	if not _transport_connected:
		_reset_transport_metrics()
		_transport_connected = true
		_transport_connected_at_msec = Time.get_ticks_msec()
	connected.emit()


func _emit_disconnected(reason: String) -> void:
	_transport_connected = false
	_transport_connected_at_msec = 0
	disconnected.emit(reason)


func _emit_peer_connected(peer_id: int) -> void:
	peer_connected.emit(peer_id)


func _emit_peer_disconnected(peer_id: int) -> void:
	peer_disconnected.emit(peer_id)


func _emit_message_received(peer_id: int, bytes: PackedByteArray) -> void:
	_transport_bytes_received += bytes.size()
	_transport_packets_received += 1
	message_received.emit(peer_id, bytes)
