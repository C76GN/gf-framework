## GFWebSocketNetworkBackend: 基于 Godot WebSocketPeer 的网络后端。
##
## 只实现 GFNetworkBackend 的 bytes 传输边界，适合浏览器、原生客户端或工具链
## 之间复用同一套 GFNetworkMessage 序列化流程。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 3.17.0
class_name GFWebSocketNetworkBackend
extends GFNetworkBackend


# --- 枚举 ---

## WebSocket 后端运行模式。
## [br]
## @api public
enum Mode {
	## 未连接。
	DISCONNECTED,
	## 作为服务器监听 TCP 并接受 WebSocket 握手。
	SERVER,
	## 作为客户端连接远端 WebSocket 地址。
	CLIENT,
}


# --- 常量 ---

## 广播 peer 标识。
## [br]
## @api public
const BROADCAST_PEER_ID: int = -1

## 客户端视角下远端服务器的 peer 标识。
## [br]
## @api public
const SERVER_PEER_ID: int = 1


# --- 公共变量 ---

## 每次 poll 最多接受的 TCP 连接数量。小于等于 0 表示不限制。
## [br]
## @api public
var max_accepts_per_poll: int = 16

## 每个 peer 每次 poll 最多派发的入站包数量。小于等于 0 表示不限制。
## [br]
## @api public
var max_packets_per_peer_per_poll: int = 64


# --- 私有变量 ---

var _mode: Mode = Mode.DISCONNECTED
var _server: TCPServer = null
var _client: WebSocketPeer = null
var _endpoint: String = ""
var _peers: Dictionary[int, WebSocketPeer] = {}
var _open_peer_ids: Dictionary[int, bool] = {}
var _server_peer_options: Dictionary = {}
var _next_peer_id: int = SERVER_PEER_ID
var _client_was_open: bool = false


# --- 公共方法 ---

## 启动 WebSocket 主机。
## 支持 options: port, bind_address, supported_protocols。
## [br]
## @api public
## [br]
## @param options: 操作选项字典。
## [br]
## @return Godot 错误码。
## [br]
## @schema options: Dictionary，支持 port、bind_address、address、supported_protocols、inbound_buffer_size、outbound_buffer_size、max_queued_packets、no_delay。
func host(options: Dictionary = {}) -> Error:
	var port: int = GFVariantData.get_option_int(options, "port")
	if port <= 0:
		return ERR_INVALID_PARAMETER

	_close_all(false)
	_server = TCPServer.new()
	var bind_address: String = GFVariantData.get_option_string(options, "bind_address", GFVariantData.get_option_string(options, "address", "*"))
	var error: Error = _server.listen(port, bind_address)
	if error != OK:
		_server = null
		return error

	_mode = Mode.SERVER
	_endpoint = "%s:%d" % [bind_address, port]
	_server_peer_options = options.duplicate(true)
	_next_peer_id = SERVER_PEER_ID
	_emit_connected()
	return OK


## 连接 WebSocket 远端。
## endpoint 应为 ws:// 或 wss:// URL。
## [br]
## @api public
## [br]
## @param endpoint: WebSocket 地址。
## [br]
## @param options: 操作选项字典，支持 tls_options、supported_protocols。
## [br]
## @return Godot 错误码。
## [br]
## @schema options: Dictionary，支持 tls_options、supported_protocols、inbound_buffer_size、outbound_buffer_size、max_queued_packets、no_delay。
func connect_to_endpoint(endpoint: String, options: Dictionary = {}) -> Error:
	if endpoint.strip_edges().is_empty():
		return ERR_INVALID_PARAMETER

	_close_all(false)
	_client = WebSocketPeer.new()
	_apply_peer_options(_client, options)
	var tls_options: TLSOptions = _get_tls_options_value(GFVariantData.get_option_value(options, "tls_options"))
	var error: Error = _client.connect_to_url(endpoint, tls_options)
	if error != OK:
		_client = null
		return error

	_mode = Mode.CLIENT
	_endpoint = endpoint
	_client_was_open = false
	return OK


## 断开 WebSocket 连接。
## [br]
## @api public
func disconnect_backend() -> void:
	_close_all(true)


## 发送 bytes。
## [br]
## @api public
## [br]
## @param peer_id: 目标 peer；服务器模式下 -1 表示广播，客户端模式下可传 1 或 -1。
## [br]
## @param bytes: 要发送的字节数据。
## [br]
## @param _options: 操作选项字典。
## [br]
## @return Godot 错误码。
## [br]
## @schema _options: Dictionary，保留给后端自定义发送选项。
func send_bytes(peer_id: int, bytes: PackedByteArray, _options: Dictionary = {}) -> Error:
	if bytes.is_empty():
		return ERR_INVALID_DATA
	if _mode == Mode.CLIENT:
		if _client == null or _client.get_ready_state() != WebSocketPeer.STATE_OPEN:
			return ERR_UNAVAILABLE
		if peer_id != BROADCAST_PEER_ID and peer_id != SERVER_PEER_ID:
			return ERR_DOES_NOT_EXIST
		return _client.send(bytes, WebSocketPeer.WRITE_MODE_BINARY)
	if _mode == Mode.SERVER:
		return _send_server_bytes(peer_id, bytes)
	return ERR_UNCONFIGURED


## 轮询 WebSocket 连接、握手和收包。
## [br]
## @api public
## [br]
## @param _delta: 本帧时间增量（秒），默认实现不直接使用。
func poll(_delta: float) -> void:
	if _mode == Mode.SERVER:
		_poll_server_accepts()
		_poll_server_peers()
	elif _mode == Mode.CLIENT:
		_poll_client()


## 获取后端调试快照。
## [br]
## @api public
## [br]
## @return 调试信息字典。
## [br]
## @schema return: Dictionary，包含 backend、available、mode、mode_name、endpoint、peer_count、open_peer_count、client_state、max_accepts_per_poll、max_packets_per_peer_per_poll。
func get_debug_snapshot() -> Dictionary:
	return GFNetworkDebugTools.sanitize_debug_dictionary({
		"backend": "GFWebSocketNetworkBackend",
		"available": _mode != Mode.DISCONNECTED,
		"mode": _mode,
		"mode_name": _get_mode_name(_mode),
		"endpoint": _endpoint,
		"peer_count": _peers.size(),
		"open_peer_count": _open_peer_ids.size(),
		"client_state": _client.get_ready_state() if _client != null else WebSocketPeer.STATE_CLOSED,
		"max_accepts_per_poll": max_accepts_per_poll,
		"max_packets_per_peer_per_poll": max_packets_per_peer_per_poll,
	})


# --- 私有/辅助方法 ---

func _poll_server_accepts() -> void:
	if _server == null:
		return

	var accepted_count: int = 0
	while _server.is_connection_available():
		if max_accepts_per_poll > 0 and accepted_count >= max_accepts_per_poll:
			break

		var stream: StreamPeerTCP = _server.take_connection()
		var peer: WebSocketPeer = WebSocketPeer.new()
		_apply_peer_options(peer, _server_peer_options)
		var error: Error = peer.accept_stream(stream)
		if error == OK:
			var peer_id: int = _next_peer_id
			_next_peer_id += 1
			_peers[peer_id] = peer
			accepted_count += 1


func _poll_server_peers() -> void:
	for peer_id_variant: Variant in _peers.keys():
		var peer_id: int = GFVariantData.to_int(peer_id_variant)
		var peer: WebSocketPeer = _get_peer_value(GFVariantData.get_option_value(_peers, peer_id))
		if peer == null:
			continue

		peer.poll()
		var state: int = peer.get_ready_state()
		if state == WebSocketPeer.STATE_OPEN:
			_mark_peer_open(peer_id)
			_emit_peer_packets(peer_id, peer)
		elif state == WebSocketPeer.STATE_CLOSED:
			_close_server_peer(peer_id, "closed")


func _poll_client() -> void:
	if _client == null:
		return

	_client.poll()
	var state: int = _client.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not _client_was_open:
			_client_was_open = true
			_emit_connected()
			_emit_peer_connected(SERVER_PEER_ID)
		_emit_peer_packets(SERVER_PEER_ID, _client)
	elif state == WebSocketPeer.STATE_CLOSED:
		var was_open: bool = _client_was_open
		_client = null
		_client_was_open = false
		_mode = Mode.DISCONNECTED
		_endpoint = ""
		if was_open:
			_emit_peer_disconnected(SERVER_PEER_ID)
		_emit_disconnected("closed")


func _emit_peer_packets(peer_id: int, peer: WebSocketPeer) -> void:
	var processed_packets: int = 0
	while (
		peer.get_available_packet_count() > 0
		and (max_packets_per_peer_per_poll <= 0 or processed_packets < max_packets_per_peer_per_poll)
	):
		_emit_message_received(peer_id, peer.get_packet())
		processed_packets += 1


func _send_server_bytes(peer_id: int, bytes: PackedByteArray) -> Error:
	if peer_id == BROADCAST_PEER_ID:
		var first_error: Error = OK
		for id_variant: Variant in _peers.keys():
			var send_error: Error = _send_to_server_peer(GFVariantData.to_int(id_variant), bytes)
			if first_error == OK and send_error != OK:
				first_error = send_error
		return first_error
	return _send_to_server_peer(peer_id, bytes)


func _send_to_server_peer(peer_id: int, bytes: PackedByteArray) -> Error:
	var peer: WebSocketPeer = _get_peer_value(GFVariantData.get_option_value(_peers, peer_id))
	if peer == null:
		return ERR_DOES_NOT_EXIST
	if peer.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return ERR_UNAVAILABLE
	return peer.send(bytes, WebSocketPeer.WRITE_MODE_BINARY)


func _mark_peer_open(peer_id: int) -> void:
	if _open_peer_ids.has(peer_id):
		return

	_open_peer_ids[peer_id] = true
	_emit_peer_connected(peer_id)


func _close_server_peer(peer_id: int, _reason: String) -> void:
	var peer: WebSocketPeer = _get_peer_value(GFVariantData.get_option_value(_peers, peer_id))
	if peer != null and peer.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		peer.close()

	var _erased_peer: bool = _peers.erase(peer_id)
	var was_open: bool = _open_peer_ids.erase(peer_id)
	if was_open:
		_emit_peer_disconnected(peer_id)


func _close_all(should_emit_signal: bool) -> void:
	if _client != null:
		if _client.get_ready_state() != WebSocketPeer.STATE_CLOSED:
			_client.close()
		if _client_was_open:
			_emit_peer_disconnected(SERVER_PEER_ID)
		_client = null
	_client_was_open = false

	for peer_id_variant: Variant in _peers.keys():
		var peer_id: int = GFVariantData.to_int(peer_id_variant)
		var peer: WebSocketPeer = _get_peer_value(GFVariantData.get_option_value(_peers, peer_id))
		if peer != null and peer.get_ready_state() != WebSocketPeer.STATE_CLOSED:
			peer.close()
		if _open_peer_ids.has(peer_id):
			_emit_peer_disconnected(peer_id)
	_peers.clear()
	_open_peer_ids.clear()

	if _server != null:
		_server.stop()
	_server = null

	var was_active: bool = _mode != Mode.DISCONNECTED
	_mode = Mode.DISCONNECTED
	_endpoint = ""
	_server_peer_options.clear()
	if should_emit_signal and was_active:
		_emit_disconnected("closed")


func _apply_peer_options(peer: WebSocketPeer, options: Dictionary) -> void:
	if peer == null:
		return
	if options.has("supported_protocols"):
		var protocols: PackedStringArray = PackedStringArray()
		var raw_protocols: Variant = options["supported_protocols"]
		if raw_protocols is PackedStringArray:
			protocols = _get_packed_string_array_value(raw_protocols)
		elif raw_protocols is Array:
			for protocol_variant: Variant in GFVariantData.as_array(raw_protocols):
				var _appended: bool = protocols.append(GFVariantData.to_text(protocol_variant))
		peer.set_supported_protocols(protocols)
	if options.has("inbound_buffer_size"):
		peer.set_inbound_buffer_size(GFVariantData.to_int(options["inbound_buffer_size"]))
	if options.has("outbound_buffer_size"):
		peer.set_outbound_buffer_size(GFVariantData.to_int(options["outbound_buffer_size"]))
	if options.has("max_queued_packets"):
		peer.set_max_queued_packets(GFVariantData.to_int(options["max_queued_packets"]))
	if options.has("no_delay"):
		peer.set_no_delay(GFVariantData.to_bool(options["no_delay"]))


func _get_peer_value(value: Variant) -> WebSocketPeer:
	if value is WebSocketPeer:
		var peer: WebSocketPeer = value
		return peer
	return null


func _get_tls_options_value(value: Variant) -> TLSOptions:
	if value is TLSOptions:
		var tls_options: TLSOptions = value
		return tls_options
	return null


func _get_packed_string_array_value(value: Variant) -> PackedStringArray:
	if value is PackedStringArray:
		var array: PackedStringArray = value
		return array
	return PackedStringArray()


func _get_mode_name(mode: Mode) -> String:
	match mode:
		Mode.SERVER:
			return "server"
		Mode.CLIENT:
			return "client"
		_:
			return "disconnected"
