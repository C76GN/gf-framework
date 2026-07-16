## GFENetNetworkBackend: 基于 Godot ENetMultiplayerPeer 的网络后端。
##
## 该后端只实现 GFNetworkBackend 的 bytes 传输边界，不定义房间、同步、
## RPC 或任何项目消息语义。需要更复杂协议时可以继续继承 GFNetworkBackend。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 3.17.0
class_name GFENetNetworkBackend
extends GFNetworkBackend


# --- 常量 ---

## 广播 peer 标识。
## [br]
## @api public
const BROADCAST_PEER_ID: int = -1


# --- 公共变量 ---

## 每次 poll 最多派发的入站包数量。小于等于 0 表示不限制。
## [br]
## @api public
var max_packets_per_poll: int = 64


# --- 私有变量 ---

var _peer: ENetMultiplayerPeer
var _last_status: int = MultiplayerPeer.CONNECTION_DISCONNECTED
var _endpoint: String = ""
var _is_server: bool = false
var _connected_peer_ids: Dictionary = {}


# --- 公共方法 ---

## 启动 ENet 主机。
## 支持 options: port, max_clients, max_channels, in_bandwidth, out_bandwidth。
## [br]
## @api public
## [br]
## @param options: 操作选项字典。
## [br]
## @return Godot 错误码。
## [br]
## @schema options: Dictionary，支持 port、max_clients、max_channels、in_bandwidth、out_bandwidth。
func host(options: Dictionary = {}) -> Error:
	var port: int = GFVariantData.get_option_int(options, "port")
	if port <= 0:
		return ERR_INVALID_PARAMETER

	_close_peer(false)
	_peer = ENetMultiplayerPeer.new()
	var error: Error = _peer.create_server(
		port,
		GFVariantData.get_option_int(options, "max_clients", 32),
		GFVariantData.get_option_int(options, "max_channels"),
		GFVariantData.get_option_int(options, "in_bandwidth"),
		GFVariantData.get_option_int(options, "out_bandwidth")
	)
	if error != OK:
		_peer = null
		return error

	_endpoint = "0.0.0.0:%d" % port
	_is_server = true
	_connect_peer_signals()
	_last_status = _peer.get_connection_status()
	if _last_status == MultiplayerPeer.CONNECTION_CONNECTED:
		_emit_connected()
	return OK


## 连接 ENet 远端。
## endpoint 可传 "host:port"，或通过 options.port 传端口。
## [br]
## @api public
## [br]
## @param endpoint: 网络连接端点。
## [br]
## @param options: 操作选项字典。
## [br]
## @return Godot 错误码。
## [br]
## @schema options: Dictionary，支持 port、max_channels、in_bandwidth、out_bandwidth。
func connect_to_endpoint(endpoint: String, options: Dictionary = {}) -> Error:
	var parsed: Dictionary = _parse_endpoint(endpoint, options)
	var address: String = GFVariantData.get_option_string(parsed, "address")
	var port: int = GFVariantData.get_option_int(parsed, "port")
	if address.is_empty() or port <= 0:
		return ERR_INVALID_PARAMETER

	_close_peer(false)
	_peer = ENetMultiplayerPeer.new()
	var error: Error = _peer.create_client(
		address,
		port,
		GFVariantData.get_option_int(options, "max_channels"),
		GFVariantData.get_option_int(options, "in_bandwidth"),
		GFVariantData.get_option_int(options, "out_bandwidth")
	)
	if error != OK:
		_peer = null
		return error

	_endpoint = "%s:%d" % [address, port]
	_is_server = false
	_connect_peer_signals()
	_last_status = _peer.get_connection_status()
	return OK


## 断开 ENet 连接。
## [br]
## @api public
func disconnect_backend() -> void:
	_close_peer(true)


## 发送 bytes。
## options 支持 reliable, transfer_mode, channel。
## [br]
## @api public
## [br]
## @param peer_id: 目标网络 peer 标识。
## [br]
## @param bytes: 要发送的字节数据。
## [br]
## @param options: 操作选项字典。
## [br]
## @return Godot 错误码。
## [br]
## @schema options: Dictionary，支持 reliable、transfer_mode、channel。
func send_bytes(peer_id: int, bytes: PackedByteArray, options: Dictionary = {}) -> Error:
	if _peer == null:
		return ERR_UNCONFIGURED
	if bytes.is_empty():
		return ERR_INVALID_DATA

	_peer.set_target_peer(_map_target_peer(peer_id))
	_peer.transfer_channel = GFVariantData.get_option_int(options, "channel")
	_peer.transfer_mode = _get_transfer_mode(options)
	var error: Error = _peer.put_packet(bytes)
	_peer.set_target_peer(MultiplayerPeer.TARGET_PEER_BROADCAST)
	return error


## 轮询 ENet 事件和收包。
## [br]
## @api public
## [br]
## @param _delta: 本帧时间增量（秒），默认实现不直接使用。
func poll(_delta: float) -> void:
	if _peer == null:
		return

	_peer.poll()
	_update_connection_status()
	var processed_packets: int = 0
	while (
		_peer != null
		and _peer.get_available_packet_count() > 0
		and (max_packets_per_poll <= 0 or processed_packets < max_packets_per_poll)
	):
		var peer_id: int = _peer.get_packet_peer()
		var bytes: PackedByteArray = _peer.get_packet()
		_emit_message_received(peer_id, bytes)
		processed_packets += 1


## 获取后端调试快照。
## [br]
## @api public
## [br]
## @return 调试信息字典。
## [br]
## @schema return: Dictionary，包含 backend、available、endpoint、is_server、connection_status、connection_status_name、available_packet_count、max_packets_per_poll。
func get_debug_snapshot() -> Dictionary:
	var status: int = MultiplayerPeer.CONNECTION_DISCONNECTED if _peer == null else _peer.get_connection_status()
	return GFNetworkDebugTools.sanitize_debug_dictionary({
		"backend": "GFENetNetworkBackend",
		"available": _peer != null,
		"endpoint": _endpoint,
		"is_server": _is_server,
		"connection_status": status,
		"connection_status_name": _get_status_name(status),
		"available_packet_count": 0 if _peer == null else _peer.get_available_packet_count(),
		"max_packets_per_poll": max_packets_per_poll,
	})


# --- 私有/辅助方法 ---

func _connect_peer_signals() -> void:
	if _peer == null:
		return
	if not _peer.peer_connected.is_connected(_on_peer_connected):
		var _peer_connected_error: int = _peer.peer_connected.connect(_on_peer_connected)
	if not _peer.peer_disconnected.is_connected(_on_peer_disconnected):
		var _peer_disconnected_error: int = _peer.peer_disconnected.connect(_on_peer_disconnected)


func _disconnect_peer_signals() -> void:
	if _peer == null:
		return
	if _peer.peer_connected.is_connected(_on_peer_connected):
		_peer.peer_connected.disconnect(_on_peer_connected)
	if _peer.peer_disconnected.is_connected(_on_peer_disconnected):
		_peer.peer_disconnected.disconnect(_on_peer_disconnected)


func _close_peer(should_emit_signal: bool) -> void:
	if _peer == null:
		_emit_tracked_peer_disconnections()
		return

	_disconnect_peer_signals()
	_peer.close()
	_peer = null
	_emit_tracked_peer_disconnections()
	_last_status = MultiplayerPeer.CONNECTION_DISCONNECTED
	_endpoint = ""
	_is_server = false
	if should_emit_signal:
		_emit_disconnected("closed")


func _parse_endpoint(endpoint: String, options: Dictionary) -> Dictionary:
	var address: String = endpoint.strip_edges()
	var port: int = GFVariantData.get_option_int(options, "port")
	if address.begins_with("["):
		var bracket_index: int = address.find("]")
		if bracket_index > 0:
			var parsed_host: String = address.substr(1, bracket_index - 1)
			if bracket_index < address.length() - 2 and address.substr(bracket_index + 1, 1) == ":":
				port = int(address.substr(bracket_index + 2))
			address = parsed_host
	elif port <= 0:
		var separator_index: int = address.rfind(":")
		if (
			separator_index > 0
			and separator_index < address.length() - 1
			and address.find(":") == separator_index
		):
			port = int(address.substr(separator_index + 1))
			address = address.substr(0, separator_index)
	return {
		"address": address,
		"port": port,
	}


func _map_target_peer(peer_id: int) -> int:
	if peer_id == BROADCAST_PEER_ID:
		return MultiplayerPeer.TARGET_PEER_BROADCAST
	return peer_id


func _get_transfer_mode(options: Dictionary) -> MultiplayerPeer.TransferMode:
	if options.has("transfer_mode"):
		return _to_transfer_mode(GFVariantData.to_int(options["transfer_mode"]))
	if GFVariantData.get_option_bool(options, "reliable", true):
		return MultiplayerPeer.TRANSFER_MODE_RELIABLE
	return MultiplayerPeer.TRANSFER_MODE_UNRELIABLE


func _to_transfer_mode(value: int) -> MultiplayerPeer.TransferMode:
	match value:
		MultiplayerPeer.TRANSFER_MODE_UNRELIABLE:
			return MultiplayerPeer.TRANSFER_MODE_UNRELIABLE
		MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED:
			return MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED
		_:
			return MultiplayerPeer.TRANSFER_MODE_RELIABLE


func _update_connection_status() -> void:
	if _peer == null:
		return

	var status: int = _peer.get_connection_status()
	if status == _last_status:
		return

	_last_status = status
	match status:
		MultiplayerPeer.CONNECTION_CONNECTED:
			_emit_connected()
		MultiplayerPeer.CONNECTION_DISCONNECTED:
			_close_peer(false)
			_emit_disconnected("connection_status_disconnected")


func _get_status_name(status: int) -> String:
	match status:
		MultiplayerPeer.CONNECTION_DISCONNECTED:
			return "disconnected"
		MultiplayerPeer.CONNECTION_CONNECTING:
			return "connecting"
		MultiplayerPeer.CONNECTION_CONNECTED:
			return "connected"
		_:
			return "unknown"


func _on_peer_connected(peer_id: int) -> void:
	_connected_peer_ids[peer_id] = true
	_emit_peer_connected(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	var _erased_peer: bool = _connected_peer_ids.erase(peer_id)
	_emit_peer_disconnected(peer_id)


func _emit_tracked_peer_disconnections() -> void:
	var peer_ids: Array[int] = []
	for peer_id_value: Variant in _connected_peer_ids.keys():
		peer_ids.append(GFVariantData.to_int(peer_id_value))
	peer_ids.sort()
	_connected_peer_ids.clear()
	for peer_id: int in peer_ids:
		_emit_peer_disconnected(peer_id)
