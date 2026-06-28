## GFNetworkUtility: 可插拔网络后端运行时。
##
## 负责把通用 GFNetworkMessage 编码后交给后端发送，并将后端收到的 bytes 解码为消息信号。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFNetworkUtility
extends GFUtility


# --- 信号 ---

## 收到消息后发出。
## [br]
## @api public
## [br]
## @param peer_id: 发送方 peer 标识。
## [br]
## @param message: 解码后的网络消息。
signal message_received(peer_id: int, message: GFNetworkMessage)

## 消息校验失败后发出。
## [br]
## @api public
## [br]
## @param peer_id: 关联 peer 标识。
## [br]
## @param reason: 拒绝原因。
## [br]
## @param details: 校验或解码详情。
## [br]
## @schema details: Dictionary，包含 ok、errors 或 error/data 等诊断字段。
signal message_rejected(peer_id: int, reason: String, details: Dictionary)

## 后端连接成功后发出。
## [br]
## @api public
signal connected

## 后端断开后发出。
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


# --- 公共变量 ---

## 当前网络后端。
## [br]
## @api public
var backend: GFNetworkBackend

## 消息编码器。
## [br]
## @api public
var serializer: GFNetworkSerializer = GFNetworkSerializer.new()

## 消息校验器。
## [br]
## @api public
var validator: GFNetworkMessageValidator = GFNetworkMessageValidator.new()

## 当前会话状态。
## [br]
## @api public
var session: GFNetworkSession = GFNetworkSession.new()

## 客户端连接超时时间，单位毫秒。小于等于 0 表示不主动超时。
## [br]
## @api public
## [br]
## @since 6.0.0
var connect_timeout_msec: int = 15000


# --- 私有变量 ---

var _channels: Dictionary = {}
var _connect_timeout_active: bool = false
var _connect_timeout_elapsed_msec: int = 0


# --- GF 生命周期方法 ---

## 注册网络诊断快照贡献。
## [br]
## @api public
func ready() -> void:
	_register_diagnostics_contribution()


## 推进运行时逻辑。
## [br]
## @api public
## [br]
## @param delta: 本帧时间增量（秒）。
func tick(delta: float) -> void:
	if backend != null:
		backend.poll(delta)
	_update_connect_timeout(delta)


## 释放后端、通道和诊断贡献。
## [br]
## @api public
func dispose() -> void:
	_unregister_diagnostics_contribution()
	_replace_backend(null, "disposed")
	clear_channels()
	if session != null:
		session.close("disposed")


# --- 公共方法 ---

## 设置网络后端。
## [br]
## @api public
## [br]
## @param next_backend: 新后端。
func set_backend(next_backend: GFNetworkBackend) -> void:
	var close_reason: String = "backend_replaced" if next_backend != null else "backend_cleared"
	_replace_backend(next_backend, close_reason)


## 注册网络通道。
## [br]
## @api public
## [br]
## @param channel: 通道资源。
func register_channel(channel: GFNetworkChannel) -> void:
	if channel == null or channel.channel_id == &"":
		return
	_channels[channel.channel_id] = channel


## 注销网络通道。
## [br]
## @api public
## [br]
## @param channel_id: 通道标识。
func unregister_channel(channel_id: StringName) -> void:
	var erased: bool = _channels.erase(channel_id)
	if erased:
		return


## 获取网络通道。
## [br]
## @api public
## [br]
## @param channel_id: 通道标识。
## [br]
## @return 通道资源。
func get_channel(channel_id: StringName) -> GFNetworkChannel:
	return _get_network_channel_value(GFVariantData.get_option_value(_channels, channel_id))


## 获取已注册通道标识。
## [br]
## @api public
## [br]
## @return 排序后的通道标识。
func get_channel_ids() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for channel_id: StringName in _channels.keys():
		var _channel_id_appended: bool = result.append(String(channel_id))
	result.sort()
	return result


## 清空网络通道。
## [br]
## @api public
func clear_channels() -> void:
	_channels.clear()


## 启动主机。
## [br]
## @api public
## [br]
## @param options: 后端选项。
## [br]
## @return Godot 错误码。
## [br]
## @schema options: Dictionary，传给 session.start_host() 和 backend.host() 的后端选项。
func host(options: Dictionary = {}) -> Error:
	if backend == null:
		return ERR_UNCONFIGURED

	_end_connect_timeout()
	if session != null:
		session.start_host(options)
	var error: Error = backend.host(options)
	if error != OK and session != null:
		session.close("host_failed")
	elif session != null and not session.has_connection:
		session.mark_connected()
	return error


## 连接远端。
## [br]
## @api public
## [br]
## @param endpoint: 远端地址。
## [br]
## @param options: 后端选项。
## [br]
## @return Godot 错误码。
## [br]
## @schema options: Dictionary，传给 session.start_client() 和 backend.connect_to_endpoint() 的后端选项。
func connect_to_endpoint(endpoint: String, options: Dictionary = {}) -> Error:
	if backend == null:
		return ERR_UNCONFIGURED

	if session != null:
		session.start_client(endpoint, options)
	_begin_connect_timeout()
	var error: Error = backend.connect_to_endpoint(endpoint, options)
	if error != OK and session != null:
		_end_connect_timeout()
		session.close("connect_failed")
	return error


## 断开连接。
## [br]
## @api public
func disconnect_network() -> void:
	_end_connect_timeout()
	if backend != null:
		backend.disconnect_backend()
	elif session != null:
		session.close("closed")


## 发送消息。
## [br]
## @api public
## [br]
## @param peer_id: 目标 peer；后端可约定 -1 表示广播。
## [br]
## @param message: 消息载体。
## [br]
## @param options: 后端发送选项。
## [br]
## @return Godot 错误码。
## [br]
## @schema options: Dictionary，传给 backend.send_bytes() 的发送选项。
func send_message(peer_id: int, message: GFNetworkMessage, options: Dictionary = {}) -> Error:
	return _send_message_internal(peer_id, message, options, null)


## 通过指定通道发送消息。
## [br]
## @api public
## [br]
## @param peer_id: 目标 peer；后端可约定 -1 表示广播。
## [br]
## @param message: 消息载体。
## [br]
## @param channel_id: 通道标识。
## [br]
## @param options: 后端发送选项覆盖。
## [br]
## @return Godot 错误码。
## [br]
## @schema options: Dictionary，覆盖 GFNetworkChannel.build_send_options() 的发送选项。
func send_message_on_channel(
	peer_id: int,
	message: GFNetworkMessage,
	channel_id: StringName,
	options: Dictionary = {}
) -> Error:
	var channel: GFNetworkChannel = get_channel(channel_id)
	if channel == null:
		return ERR_DOES_NOT_EXIST
	var channel_message: GFNetworkMessage = _copy_message_for_channel(message, channel_id)
	return _send_message_internal(peer_id, channel_message, channel.build_send_options(options), channel)


## 获取网络工具调试快照。
## [br]
## @api public
## [br]
## @return 调试信息字典。
## [br]
## @schema return: Dictionary，包含 backend_configured、serializer_configured、validator_configured、backend、session、channels、validator。
func get_debug_snapshot() -> Dictionary:
	var snapshot: Dictionary = {
		"backend_configured": backend != null,
		"serializer_configured": serializer != null,
		"validator_configured": validator != null,
		"backend": {},
		"session": session.get_debug_snapshot() if session != null else {},
		"channels": _describe_channels(),
		"validator": validator.get_debug_snapshot() if validator != null else {},
	}
	if backend != null:
		snapshot["backend"] = backend.get_debug_snapshot()
	return GFNetworkDebugTools.sanitize_debug_dictionary(snapshot)


# --- 私有/辅助方法 ---

func _send_message_internal(
	peer_id: int,
	message: GFNetworkMessage,
	options: Dictionary,
	channel: GFNetworkChannel
) -> Error:
	if backend == null:
		return ERR_UNCONFIGURED
	if serializer == null:
		return ERR_UNCONFIGURED
	if validator != null:
		var message_report: Dictionary = validator.validate_message(message)
		if not GFVariantData.get_option_bool(message_report, "ok", false):
			message_rejected.emit(peer_id, "invalid_message", message_report)
			return ERR_INVALID_DATA

	var bytes: PackedByteArray = serializer.serialize_message(message)
	if bytes.is_empty():
		return ERR_INVALID_DATA
	if validator != null:
		var bytes_report: Dictionary = validator.validate_bytes(bytes, channel)
		if not GFVariantData.get_option_bool(bytes_report, "ok", false):
			message_rejected.emit(peer_id, "invalid_packet", bytes_report)
			return ERR_INVALID_DATA
	return backend.send_bytes(peer_id, bytes, options)


func _connect_backend_signals(target_backend: GFNetworkBackend) -> void:
	var _connect_result_341: Variant = target_backend.connected.connect(_on_backend_connected)
	var _connect_result_342: Variant = target_backend.disconnected.connect(_on_backend_disconnected)
	var _connect_result_343: Variant = target_backend.peer_connected.connect(_on_backend_peer_connected)
	var _connect_result_344: Variant = target_backend.peer_disconnected.connect(_on_backend_peer_disconnected)
	var _connect_result_345: Variant = target_backend.message_received.connect(_on_backend_message_received)


func _disconnect_backend_signals(target_backend: GFNetworkBackend) -> void:
	if target_backend.connected.is_connected(_on_backend_connected):
		target_backend.connected.disconnect(_on_backend_connected)
	if target_backend.disconnected.is_connected(_on_backend_disconnected):
		target_backend.disconnected.disconnect(_on_backend_disconnected)
	if target_backend.peer_connected.is_connected(_on_backend_peer_connected):
		target_backend.peer_connected.disconnect(_on_backend_peer_connected)
	if target_backend.peer_disconnected.is_connected(_on_backend_peer_disconnected):
		target_backend.peer_disconnected.disconnect(_on_backend_peer_disconnected)
	if target_backend.message_received.is_connected(_on_backend_message_received):
		target_backend.message_received.disconnect(_on_backend_message_received)


func _replace_backend(next_backend: GFNetworkBackend, close_reason: String) -> void:
	if backend == next_backend:
		return

	_end_connect_timeout()
	var previous_backend: GFNetworkBackend = backend
	if previous_backend != null:
		_disconnect_backend_signals(previous_backend)
		previous_backend.disconnect_backend()
		if session != null:
			session.close(close_reason)

	backend = next_backend
	if backend != null:
		_connect_backend_signals(backend)


func _on_backend_connected() -> void:
	_end_connect_timeout()
	if session != null:
		if not session.has_connection:
			session.mark_connected()
	connected.emit()


func _on_backend_disconnected(reason: String) -> void:
	_end_connect_timeout()
	if session != null:
		session.close(reason)
	disconnected.emit(reason)


func _on_backend_peer_connected(peer_id: int) -> void:
	peer_connected.emit(peer_id)


func _on_backend_peer_disconnected(peer_id: int) -> void:
	peer_disconnected.emit(peer_id)


func _on_backend_message_received(peer_id: int, bytes: PackedByteArray) -> void:
	if serializer == null:
		return
	if validator != null:
		var bytes_report: Dictionary = validator.validate_bytes(bytes)
		if not GFVariantData.get_option_bool(bytes_report, "ok", false):
			message_rejected.emit(peer_id, "invalid_packet", bytes_report)
			return

	var message_result: Dictionary = serializer.deserialize_message_result(bytes)
	if not GFVariantData.get_option_bool(message_result, "ok", false):
		message_rejected.emit(peer_id, "decode_failed", message_result)
		return
	var message: GFNetworkMessage = _get_network_message_value(GFVariantData.get_option_value(message_result, "data"))
	if message == null:
		message_rejected.emit(peer_id, "decode_failed", {
			"ok": false,
			"data": null,
			"error": "message_is_null",
		})
		return
	message.sender_id = peer_id
	if validator != null:
		for channel: GFNetworkChannel in _resolve_inbound_channels(message):
			var channel_bytes_report: Dictionary = validator.validate_bytes(bytes, channel)
			if not GFVariantData.get_option_bool(channel_bytes_report, "ok", false):
				message_rejected.emit(peer_id, "invalid_packet", channel_bytes_report)
				return
		var message_report: Dictionary = validator.validate_message(message)
		if not GFVariantData.get_option_bool(message_report, "ok", false):
			message_rejected.emit(peer_id, "invalid_message", message_report)
			return
	message_received.emit(peer_id, message)


func _describe_channels() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for channel: GFNetworkChannel in _channels.values():
		if channel != null:
			result.append(channel.describe())
	return result


func _resolve_inbound_channels(message: GFNetworkMessage) -> Array[GFNetworkChannel]:
	var result: Array[GFNetworkChannel] = []
	if message == null:
		return result
	_append_inbound_channel(result, message.message_type)
	if message.channel_id != message.message_type:
		_append_inbound_channel(result, message.channel_id)
	return result


func _append_inbound_channel(result: Array[GFNetworkChannel], channel_id: StringName) -> void:
	if channel_id == &"" or not _channels.has(channel_id):
		return
	var channel: GFNetworkChannel = _get_network_channel_value(_channels[channel_id])
	if channel == null or result.has(channel):
		return
	result.append(channel)


func _begin_connect_timeout() -> void:
	_connect_timeout_elapsed_msec = 0
	_connect_timeout_active = connect_timeout_msec > 0


func _end_connect_timeout() -> void:
	_connect_timeout_active = false
	_connect_timeout_elapsed_msec = 0


func _update_connect_timeout(delta: float) -> void:
	if not _connect_timeout_active or connect_timeout_msec <= 0:
		return
	if session == null or not session.is_active or session.mode != GFNetworkSession.Mode.CLIENT:
		_end_connect_timeout()
		return
	if session.has_connection:
		_end_connect_timeout()
		return

	_connect_timeout_elapsed_msec += maxi(roundi(delta * 1000.0), 0)
	if _connect_timeout_elapsed_msec < connect_timeout_msec:
		return

	_end_connect_timeout()
	if backend != null:
		_disconnect_backend_signals(backend)
		backend.disconnect_backend()
		_connect_backend_signals(backend)
	if session != null:
		session.close("connect_timeout")
	disconnected.emit("connect_timeout")


func _copy_message_for_channel(message: GFNetworkMessage, channel_id: StringName) -> GFNetworkMessage:
	if message == null:
		return null

	return GFNetworkMessage.new(
		message.message_type,
		message.payload,
		message.sequence,
		message.tick,
		message.sender_id,
		channel_id
	)


func _register_diagnostics_contribution() -> void:
	var diagnostics: GFDiagnosticsUtility = _get_diagnostics_utility_value(get_utility(GFDiagnosticsUtility))
	if diagnostics == null:
		return

	var _register_snapshot_section_provider_result_471: Variant = diagnostics.register_snapshot_section_provider(&"network", Callable(self, "get_debug_snapshot"))


func _unregister_diagnostics_contribution() -> void:
	var diagnostics: GFDiagnosticsUtility = _get_diagnostics_utility_value(get_utility(GFDiagnosticsUtility))
	if diagnostics == null:
		return

	diagnostics.unregister_snapshot_section_provider(&"network")


func _get_network_channel_value(value: Variant) -> GFNetworkChannel:
	if value is GFNetworkChannel:
		var channel: GFNetworkChannel = value
		return channel
	return null


func _get_network_message_value(value: Variant) -> GFNetworkMessage:
	if value is GFNetworkMessage:
		var message: GFNetworkMessage = value
		return message
	return null


func _get_diagnostics_utility_value(value: Variant) -> GFDiagnosticsUtility:
	if value is GFDiagnosticsUtility:
		var diagnostics: GFDiagnosticsUtility = value
		return diagnostics
	return null
