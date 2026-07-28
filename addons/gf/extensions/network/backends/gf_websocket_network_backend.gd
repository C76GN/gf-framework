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

## WebSocket 主机默认允许的远端 peer 数量。
## [br]
## 握手中和已打开的 peer 都会占用容量。
## [br]
## @api public
## [br]
## @since unreleased
const DEFAULT_MAX_CLIENTS: int = 32

## WebSocket 主机允许的远端 peer 绝对上限。
## [br]
## @api public
## [br]
## @since unreleased
const ABSOLUTE_MAX_CLIENTS: int = 65_535

## WebSocket 握手默认超时时间（毫秒）。
## [br]
## @api public
## [br]
## @since unreleased
const DEFAULT_HANDSHAKE_TIMEOUT_MSEC: int = 5_000

## WebSocket 握手超时时间绝对上限（毫秒）。
## [br]
## @api public
## [br]
## @since unreleased
const ABSOLUTE_MAX_HANDSHAKE_TIMEOUT_MSEC: int = 300_000

## 单次 poll 默认 accept 尝试预算。
## [br]
## @api public
## [br]
## @since unreleased
const DEFAULT_MAX_ACCEPTS_PER_POLL: int = 16

## 单次 poll accept 尝试预算绝对上限。
## [br]
## @api public
## [br]
## @since unreleased
const ABSOLUTE_MAX_ACCEPTS_PER_POLL: int = 4096

## 单个 peer 单次 poll 默认入站包预算。
## [br]
## @api public
## [br]
## @since unreleased
const DEFAULT_MAX_PACKETS_PER_PEER_PER_POLL: int = 64

## 单个 peer 单次 poll 入站包预算绝对上限。
## [br]
## @api public
## [br]
## @since unreleased
const ABSOLUTE_MAX_PACKETS_PER_PEER_PER_POLL: int = 4096

## 单次 poll 默认全局入站包预算。
## [br]
## @api public
## [br]
## @since unreleased
const DEFAULT_MAX_PACKETS_PER_POLL: int = 512

## 单次 poll 全局入站包预算绝对上限。
## [br]
## @api public
## [br]
## @since unreleased
const ABSOLUTE_MAX_PACKETS_PER_POLL: int = 16_384

## 单次 poll 默认服务 peer 数量。
## [br]
## @api public
## [br]
## @since unreleased
const DEFAULT_MAX_SERVICE_PEERS_PER_POLL: int = 64

## 单次 poll 服务 peer 数量绝对上限。
## [br]
## @api public
## [br]
## @since unreleased
const ABSOLUTE_MAX_SERVICE_PEERS_PER_POLL: int = 4096

## 单个 WebSocket peer 默认入站缓冲区字节数。
## [br]
## @api public
## [br]
## @since unreleased
const DEFAULT_INBOUND_BUFFER_SIZE: int = 65_536

## 单个 WebSocket peer 入站缓冲区字节数绝对上限。
## [br]
## @api public
## [br]
## @since unreleased
const ABSOLUTE_MAX_INBOUND_BUFFER_SIZE: int = 4 * 1024 * 1024

## 单个 WebSocket peer 默认出站缓冲区字节数。
## [br]
## @api public
## [br]
## @since unreleased
const DEFAULT_OUTBOUND_BUFFER_SIZE: int = 65_536

## 单个 WebSocket peer 出站缓冲区字节数绝对上限。
## [br]
## @api public
## [br]
## @since unreleased
const ABSOLUTE_MAX_OUTBOUND_BUFFER_SIZE: int = 4 * 1024 * 1024

## 单个 WebSocket peer 默认排队包数量。
## [br]
## @api public
## [br]
## @since unreleased
const DEFAULT_MAX_QUEUED_PACKETS: int = 1024

## 单个 WebSocket peer 排队包数量绝对上限。
## [br]
## @api public
## [br]
## @since unreleased
const ABSOLUTE_MAX_QUEUED_PACKETS: int = 4096

## 单个 peer 允许声明的 WebSocket 子协议数量绝对上限。
## [br]
## @api public
## [br]
## @since unreleased
const ABSOLUTE_MAX_SUPPORTED_PROTOCOL_COUNT: int = 32

## 单个 WebSocket 子协议 UTF-8 字节数绝对上限。
## [br]
## @api public
## [br]
## @since unreleased
const ABSOLUTE_MAX_SUPPORTED_PROTOCOL_BYTES: int = 256

## 单个 peer 全部 WebSocket 子协议 UTF-8 总字节数绝对上限。
## [br]
## @api public
## [br]
## @since unreleased
const ABSOLUTE_MAX_SUPPORTED_PROTOCOL_TOTAL_BYTES: int = 4096


# --- 公共变量 ---

## 每次 poll 最多尝试接受的 TCP 连接数量。
##
## 赋值会钳制到 1..ABSOLUTE_MAX_ACCEPTS_PER_POLL，不能关闭工作预算。
## [br]
## @api public
## [br]
## @since 3.17.0
var max_accepts_per_poll: int:
	get:
		return _max_accepts_per_poll
	set(value):
		_max_accepts_per_poll = clampi(
			value,
			1,
			ABSOLUTE_MAX_ACCEPTS_PER_POLL
		)

## 每个 peer 每次 poll 最多派发的入站包数量。
##
## 赋值会钳制到 1..ABSOLUTE_MAX_PACKETS_PER_PEER_PER_POLL，不能关闭工作预算。
## [br]
## @api public
## [br]
## @since 3.17.0
var max_packets_per_peer_per_poll: int:
	get:
		return _max_packets_per_peer_per_poll
	set(value):
		_max_packets_per_peer_per_poll = clampi(
			value,
			1,
			ABSOLUTE_MAX_PACKETS_PER_PEER_PER_POLL
		)

## 单次 poll 最多派发的全局入站包数量。
##
## 赋值会钳制到 1..ABSOLUTE_MAX_PACKETS_PER_POLL，不能关闭全局工作预算。
## [br]
## @api public
## [br]
## @since unreleased
var max_packets_per_poll: int:
	get:
		return _max_packets_per_poll
	set(value):
		_max_packets_per_poll = clampi(
			value,
			1,
			ABSOLUTE_MAX_PACKETS_PER_POLL
		)

## 单次 poll 最多服务的服务器 peer 数量。
##
## 赋值会钳制到 1..ABSOLUTE_MAX_SERVICE_PEERS_PER_POLL，轮转游标保证尾部 peer
## 会在后续 poll 获得服务机会。
## [br]
## @api public
## [br]
## @since unreleased
var max_service_peers_per_poll: int:
	get:
		return _max_service_peers_per_poll
	set(value):
		_max_service_peers_per_poll = clampi(
			value,
			1,
			ABSOLUTE_MAX_SERVICE_PEERS_PER_POLL
		)

## 服务器 peer 从 accept 成功到完成 WebSocket 握手的最长时间（毫秒）。
##
## 赋值会钳制到 1..ABSOLUTE_MAX_HANDSHAKE_TIMEOUT_MSEC，避免慢握手永久占用
## 主机容量。每个 poll 仍只在服务 peer 预算内检查超时。
## [br]
## @api public
## [br]
## @since unreleased
var handshake_timeout_msec: int:
	get:
		return _handshake_timeout_msec
	set(value):
		_handshake_timeout_msec = clampi(
			value,
			1,
			ABSOLUTE_MAX_HANDSHAKE_TIMEOUT_MSEC
		)


# --- 私有变量 ---

var _mode: Mode = Mode.DISCONNECTED
var _session_generation: int = 0
var _server: TCPServer = null
var _client: WebSocketPeer = null
var _endpoint: String = ""
var _peers: Dictionary[int, WebSocketPeer] = {}
var _open_peer_ids: Dictionary[int, bool] = {}
var _server_peer_options: Dictionary = {}
var _peer_accepted_at_msec: Dictionary[int, int] = {}
var _next_peer_id: int = SERVER_PEER_ID + 1
var _client_was_open: bool = false
var _server_capacity: int = 0
var _accepted_connection_count: int = 0
var _capacity_rejection_count: int = 0
var _accept_failure_count: int = 0
var _handshake_failure_count: int = 0
var _handshake_timeout_count: int = 0
var _accept_attempt_count: int = 0
var _last_poll_accept_attempt_count: int = 0
var _max_accepts_per_poll: int = DEFAULT_MAX_ACCEPTS_PER_POLL
var _max_packets_per_peer_per_poll: int = DEFAULT_MAX_PACKETS_PER_PEER_PER_POLL
var _max_packets_per_poll: int = DEFAULT_MAX_PACKETS_PER_POLL
var _max_service_peers_per_poll: int = DEFAULT_MAX_SERVICE_PEERS_PER_POLL
var _handshake_timeout_msec: int = DEFAULT_HANDSHAKE_TIMEOUT_MSEC
var _service_peer_ids: Array[int] = []
var _service_peer_cursor: int = 0
var _peer_option_rejection_count: int = 0
var _packet_budget_exhaustion_count: int = 0
var _peer_packet_budget_exhaustion_count: int = 0
var _service_peer_budget_exhaustion_count: int = 0
var _last_poll_packet_count: int = 0
var _last_poll_service_peer_count: int = 0
var _last_poll_packet_budget_exhausted: bool = false
var _last_poll_service_peer_budget_exhausted: bool = false
var _poll_in_progress: bool = false


# --- 公共方法 ---

## 启动 WebSocket 主机。
## 支持 options: port, bind_address, supported_protocols。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param options: 操作选项字典。
## [br]
## @return Godot 错误码。
## [br]
## @schema options: Dictionary，支持 port、bind_address、address、max_clients、max_peers、handshake_timeout_msec、supported_protocols、inbound_buffer_size、outbound_buffer_size、max_queued_packets、no_delay。port、容量、握手超时和三项 peer 队列参数只接受对应公开上限内的精确正 int；supported_protocols 只接受有界且无重复的合法 WebSocket token，no_delay 必须为 bool；max_clients 优先于 max_peers。
func host(options: Dictionary = {}) -> Error:
	var port_value: Variant = _get_option_value(options, &"port")
	if not port_value is int:
		return ERR_INVALID_PARAMETER
	var port: int = port_value
	if port <= 0 or port > 65_535:
		return ERR_INVALID_PARAMETER
	var server_capacity_value: Variant = DEFAULT_MAX_CLIENTS
	if _has_option(options, &"max_clients"):
		server_capacity_value = _get_option_value(options, &"max_clients")
	elif _has_option(options, &"max_peers"):
		server_capacity_value = _get_option_value(options, &"max_peers")
	if not server_capacity_value is int:
		return ERR_INVALID_PARAMETER
	var server_capacity: int = server_capacity_value
	if server_capacity <= 0 or server_capacity > ABSOLUTE_MAX_CLIENTS:
		return ERR_INVALID_PARAMETER
	if not _is_exact_positive_bounded_option(
		options,
		&"handshake_timeout_msec",
		ABSOLUTE_MAX_HANDSHAKE_TIMEOUT_MSEC
	):
		return ERR_INVALID_PARAMETER
	var server_handshake_timeout_msec: int = _get_exact_option_int(
		options,
		&"handshake_timeout_msec",
		_handshake_timeout_msec
	)
	if not _validate_peer_options(options):
		_peer_option_rejection_count += 1
		return ERR_INVALID_PARAMETER
	var normalized_peer_options: Dictionary = _normalize_peer_options(options)

	_close_all(false)
	_server = _create_tcp_server()
	if _server == null:
		return ERR_CANT_CREATE
	var bind_address: String = GFVariantData.get_option_string(options, "bind_address", GFVariantData.get_option_string(options, "address", "*"))
	var error: Error = _server.listen(port, bind_address)
	if error != OK:
		_server = null
		return error

	_mode = Mode.SERVER
	_endpoint = "%s:%d" % [bind_address, port]
	_server_peer_options = normalized_peer_options
	_server_capacity = server_capacity
	_handshake_timeout_msec = server_handshake_timeout_msec
	_next_peer_id = SERVER_PEER_ID + 1
	_reset_transport_metrics()
	var session_generation: int = _session_generation
	var server_identity: TCPServer = _server
	_emit_connected()
	if not _is_server_session_current(
		session_generation,
		server_identity
	):
		return OK
	return OK


## 连接 WebSocket 远端。
## endpoint 应为 ws:// 或 wss:// URL。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param endpoint: WebSocket 地址。
## [br]
## @param options: 操作选项字典，支持 tls_options、supported_protocols。
## [br]
## @return Godot 错误码。
## [br]
## @schema options: Dictionary，支持 tls_options、supported_protocols、inbound_buffer_size、outbound_buffer_size、max_queued_packets、no_delay。三项 peer 队列参数只接受对应公开上限内的精确正 int；supported_protocols 只接受有界且无重复的合法 WebSocket token，no_delay 必须为 bool。
func connect_to_endpoint(endpoint: String, options: Dictionary = {}) -> Error:
	var normalized_endpoint: String = endpoint.strip_edges()
	if not _is_valid_websocket_endpoint(normalized_endpoint):
		return ERR_INVALID_PARAMETER
	if not _validate_peer_options(options):
		_peer_option_rejection_count += 1
		return ERR_INVALID_PARAMETER
	var normalized_peer_options: Dictionary = _normalize_peer_options(options)

	_close_all(false)
	_client = _create_websocket_peer()
	if _client == null:
		return ERR_CANT_CREATE
	var apply_options_error: Error = _apply_peer_options(_client, normalized_peer_options)
	if apply_options_error != OK:
		_client = null
		return apply_options_error
	var tls_options: TLSOptions = _get_tls_options_value(GFVariantData.get_option_value(options, "tls_options"))
	var error: Error = _client.connect_to_url(normalized_endpoint, tls_options)
	if error != OK:
		_client = null
		return error

	_mode = Mode.CLIENT
	_endpoint = normalized_endpoint
	_client_was_open = false
	_reset_transport_metrics()
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
## @since 3.17.0
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
		var client_error: Error = _client.send(bytes, WebSocketPeer.WRITE_MODE_BINARY)
		if client_error == OK:
			_record_transport_packet_sent(bytes.size())
		return client_error
	if _mode == Mode.SERVER:
		return _send_server_bytes(peer_id, bytes)
	return ERR_UNCONFIGURED


## 轮询 WebSocket 连接、握手和收包。
##
## 每轮会冻结工作预算，并绑定当前会话 generation 与 WebSocket 对象身份；
## 同步信号回调若执行 disconnect、rehost 或 reconnect，旧轮询会立即停止，
## 不再消费旧包、派发旧信号或覆盖新会话统计。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param _delta: 本帧时间增量（秒），默认实现不直接使用。
func poll(_delta: float) -> void:
	if _poll_in_progress:
		return
	_poll_in_progress = true
	_poll_once()
	_poll_in_progress = false


## 获取后端调试快照。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return 调试信息字典。
## [br]
## @schema return: Dictionary，包含 backend、available、mode、mode_name、endpoint、session_generation、peer_count、open_peer_count、handshaking_peer_count、client_state、server_capacity、容量与连接统计、handshake_timeout_msec、handshake_timeout_count、peer_option_rejection_count、max_accepts_per_poll、max_packets_per_peer_per_poll、max_packets_per_poll、max_service_peers_per_poll、当轮工作用量及各预算耗尽计数。
func get_debug_snapshot() -> Dictionary:
	var server_capacity_used: int = _peers.size()
	return GFNetworkDebugTools.sanitize_debug_dictionary({
		"backend": "GFWebSocketNetworkBackend",
		"available": _mode != Mode.DISCONNECTED,
		"mode": _mode,
		"mode_name": _get_mode_name(_mode),
		"endpoint": _endpoint,
		"session_generation": _session_generation,
		"peer_count": server_capacity_used,
		"open_peer_count": _open_peer_ids.size(),
		"handshaking_peer_count": maxi(0, server_capacity_used - _open_peer_ids.size()),
		"client_state": _client.get_ready_state() if _client != null else WebSocketPeer.STATE_CLOSED,
		"server_capacity": _server_capacity,
		"server_capacity_used": server_capacity_used,
		"server_capacity_remaining": maxi(0, _server_capacity - server_capacity_used),
		"accepted_connection_count": _accepted_connection_count,
		"capacity_rejection_count": _capacity_rejection_count,
		"accept_failure_count": _accept_failure_count,
		"handshake_failure_count": _handshake_failure_count,
		"handshake_timeout_msec": _handshake_timeout_msec,
		"handshake_timeout_count": _handshake_timeout_count,
		"accept_attempt_count": _accept_attempt_count,
		"last_poll_accept_attempt_count": _last_poll_accept_attempt_count,
		"peer_option_rejection_count": _peer_option_rejection_count,
		"max_accepts_per_poll": max_accepts_per_poll,
		"max_packets_per_peer_per_poll": max_packets_per_peer_per_poll,
		"max_packets_per_poll": max_packets_per_poll,
		"max_service_peers_per_poll": max_service_peers_per_poll,
		"last_poll_packet_count": _last_poll_packet_count,
		"last_poll_service_peer_count": _last_poll_service_peer_count,
		"last_poll_packet_budget_exhausted": _last_poll_packet_budget_exhausted,
		"last_poll_service_peer_budget_exhausted": _last_poll_service_peer_budget_exhausted,
		"packet_budget_exhaustion_count": _packet_budget_exhaustion_count,
		"peer_packet_budget_exhaustion_count": _peer_packet_budget_exhaustion_count,
		"service_peer_budget_exhaustion_count": _service_peer_budget_exhaustion_count,
	})


# --- 私有/辅助方法 ---

func _poll_once() -> void:
	_reset_last_poll_work_snapshot()
	var poll_generation: int = _session_generation
	var poll_accept_limit: int = _max_accepts_per_poll
	var poll_packet_per_peer_limit: int = _max_packets_per_peer_per_poll
	var poll_packet_limit: int = _max_packets_per_poll
	var poll_service_peer_limit: int = _max_service_peers_per_poll
	if _mode == Mode.SERVER:
		var poll_server: TCPServer = _server
		_poll_server_peers(
			poll_service_peer_limit,
			poll_packet_per_peer_limit,
			poll_packet_limit,
			poll_generation
		)
		if _is_server_session_current(poll_generation, poll_server):
			_poll_server_accepts(
				poll_accept_limit,
				poll_generation,
				poll_server
			)
	elif _mode == Mode.CLIENT:
		_poll_client(
			poll_packet_per_peer_limit,
			poll_packet_limit,
			poll_generation,
			_client
		)


func _is_valid_websocket_endpoint(endpoint: String) -> bool:
	if not endpoint.begins_with("ws://") and not endpoint.begins_with("wss://"):
		return false
	for index: int in range(endpoint.length()):
		if endpoint.unicode_at(index) < 32:
			return false
	var authority_start: int = endpoint.find("://") + 3
	var authority_end: int = endpoint.length()
	for separator: String in ["/", "?", "#"]:
		var separator_index: int = endpoint.find(separator, authority_start)
		if separator_index >= 0:
			authority_end = mini(authority_end, separator_index)
	return authority_end > authority_start


func _poll_server_accepts(
	accept_limit: int,
	expected_generation: int,
	expected_server: TCPServer
) -> void:
	if not _is_server_session_current(
		expected_generation,
		expected_server
	):
		return

	while (
		_is_server_session_current(expected_generation, expected_server)
		and _is_server_connection_available()
	):
		if _last_poll_accept_attempt_count >= accept_limit:
			break

		_last_poll_accept_attempt_count += 1
		_accept_attempt_count += 1
		var stream: StreamPeerTCP = _take_server_connection()
		if not _is_server_session_current(
			expected_generation,
			expected_server
		):
			if stream != null:
				_reject_server_stream(stream)
			return
		if stream == null:
			_accept_failure_count += 1
			continue
		if _peers.size() >= _server_capacity:
			_capacity_rejection_count += 1
			_reject_server_stream(stream)
			continue

		var peer: WebSocketPeer = _create_websocket_peer()
		if peer == null:
			_accept_failure_count += 1
			_reject_server_stream(stream)
			continue
		var apply_options_error: Error = _apply_peer_options(peer, _server_peer_options)
		if apply_options_error != OK:
			_accept_failure_count += 1
			_reject_server_stream(stream)
			continue
		var error: Error = _accept_server_stream(peer, stream)
		if not _is_server_session_current(
			expected_generation,
			expected_server
		):
			if peer.get_ready_state() != WebSocketPeer.STATE_CLOSED:
				peer.close()
			return
		if error != OK:
			_accept_failure_count += 1
			_reject_server_stream(stream)
			continue

		var peer_id: int = _next_peer_id
		_next_peer_id += 1
		_peers[peer_id] = peer
		_peer_accepted_at_msec[peer_id] = _get_ticks_msec()
		_service_peer_ids.append(peer_id)
		_accepted_connection_count += 1


func _poll_server_peers(
	service_peer_limit: int,
	packet_per_peer_limit: int,
	packet_limit: int,
	expected_generation: int
) -> void:
	if not _is_server_generation_current(expected_generation):
		return
	var initial_peer_count: int = _service_peer_ids.size()
	if initial_peer_count <= 0:
		_service_peer_cursor = 0
		return

	var service_limit: int = mini(initial_peer_count, service_peer_limit)
	if initial_peer_count > service_limit:
		_last_poll_service_peer_budget_exhausted = true
		_service_peer_budget_exhaustion_count += 1

	var serviced_peer_ids: Dictionary[int, bool] = {}
	var scan_count: int = 0
	while (
		_is_server_generation_current(expected_generation)
		and _last_poll_service_peer_count < service_limit
		and scan_count < initial_peer_count
		and not _service_peer_ids.is_empty()
	):
		if _service_peer_cursor >= _service_peer_ids.size():
			_service_peer_cursor = 0
		var peer_index: int = _service_peer_cursor
		var peer_id: int = _service_peer_ids[peer_index]
		scan_count += 1
		if serviced_peer_ids.has(peer_id):
			_advance_service_peer_cursor(peer_index, peer_id)
			continue

		var peer: WebSocketPeer = _get_peer_value(GFVariantData.get_option_value(_peers, peer_id))
		if peer == null:
			_remove_service_peer_id(peer_id)
			continue
		serviced_peer_ids[peer_id] = true
		_last_poll_service_peer_count += 1

		var global_packet_remaining: int = maxi(
			0,
			packet_limit - _last_poll_packet_count
		)
		var peer_packet_limit: int = mini(
			packet_per_peer_limit,
			global_packet_remaining
		)
		var packet_count_before_service: int = _last_poll_packet_count
		var service_result: int = _service_server_peer(
			peer_id,
			peer,
			peer_packet_limit
		)
		if (
			service_result < 0
			or not _is_server_generation_current(expected_generation)
		):
			return
		var processed_packets: int = clampi(
			service_result,
			0,
			peer_packet_limit
		)
		_last_poll_packet_count = (
			packet_count_before_service + processed_packets
		)
		var has_pending_packets: bool = _server_peer_has_available_packets(peer_id, peer)
		if (
			has_pending_packets
			and peer_packet_limit == packet_per_peer_limit
			and processed_packets >= peer_packet_limit
		):
			_peer_packet_budget_exhaustion_count += 1
		if (
			_last_poll_packet_count >= packet_limit
			and (
				has_pending_packets
				or _last_poll_service_peer_count < service_limit
			)
		):
			_last_poll_packet_budget_exhausted = true
		_advance_service_peer_cursor(peer_index, peer_id)
		if _last_poll_packet_budget_exhausted:
			break

	if _last_poll_packet_budget_exhausted:
		_packet_budget_exhaustion_count += 1


func _poll_client(
	packet_per_peer_limit: int,
	packet_limit: int,
	expected_generation: int,
	expected_client: WebSocketPeer
) -> void:
	if not _is_client_session_current(
		expected_generation,
		expected_client
	):
		return

	_poll_client_peer(expected_client)
	if not _is_client_session_current(
		expected_generation,
		expected_client
	):
		return
	_last_poll_service_peer_count = 1
	var state: int = _get_client_ready_state(expected_client)
	if state == WebSocketPeer.STATE_OPEN:
		if not _client_was_open:
			_client_was_open = true
			_emit_connected()
			if not _is_client_session_current(
				expected_generation,
				expected_client
			):
				return
			_emit_peer_connected(SERVER_PEER_ID)
			if not _is_client_session_current(
				expected_generation,
				expected_client
			):
				return
		var client_packet_limit: int = mini(
			packet_per_peer_limit,
			packet_limit
		)
		var packet_count_before_service: int = _last_poll_packet_count
		var processed_packets: int = _emit_peer_packets(
			SERVER_PEER_ID,
			expected_client,
			client_packet_limit,
			expected_generation,
			Mode.CLIENT
		)
		if (
			processed_packets < 0
			or not _is_client_session_current(
				expected_generation,
				expected_client
			)
			):
			return
		_last_poll_packet_count = (
			packet_count_before_service + processed_packets
		)
		var has_pending_packets: bool = (
			_get_peer_available_packet_count(
				SERVER_PEER_ID,
				expected_client
			)
			> 0
		)
		if (
			has_pending_packets
			and client_packet_limit == packet_per_peer_limit
			and _last_poll_packet_count >= client_packet_limit
		):
			_peer_packet_budget_exhaustion_count += 1
		if has_pending_packets and _last_poll_packet_count >= packet_limit:
			_last_poll_packet_budget_exhausted = true
			_packet_budget_exhaustion_count += 1
	elif state == WebSocketPeer.STATE_CLOSED:
		var was_open: bool = _client_was_open
		_client = null
		_client_was_open = false
		_mode = Mode.DISCONNECTED
		_endpoint = ""
		var closed_generation: int = _advance_session_generation()
		if was_open:
			_emit_peer_disconnected(SERVER_PEER_ID)
			if not _is_disconnected_session_current(closed_generation):
				return
		_emit_disconnected("closed")


func _emit_peer_packets(
	peer_id: int,
	peer: WebSocketPeer,
	packet_limit: int,
	expected_generation: int,
	expected_mode: Mode
) -> int:
	var processed_packets: int = 0
	while (
		_packet_source_is_current(
			expected_mode,
			expected_generation,
			peer_id,
			peer
		)
		and _get_peer_available_packet_count(peer_id, peer) > 0
		and processed_packets < packet_limit
	):
		var packet_bytes: PackedByteArray = _get_peer_packet(peer_id, peer)
		if not _packet_source_is_current(
			expected_mode,
			expected_generation,
			peer_id,
			peer
		):
			return -1
		processed_packets += 1
		_last_poll_packet_count += 1
		_emit_message_received(peer_id, packet_bytes)
		if not _packet_source_is_current(
			expected_mode,
			expected_generation,
			peer_id,
			peer
		):
			return -1
	return processed_packets


func _service_server_peer(
	peer_id: int,
	peer: WebSocketPeer,
	packet_limit: int
) -> int:
	var expected_generation: int = _session_generation
	if not _is_server_peer_current(
		expected_generation,
		peer_id,
		peer
	):
		return -1
	peer.poll()
	if not _is_server_peer_current(
		expected_generation,
		peer_id,
		peer
	):
		return -1
	var state: int = _get_server_peer_ready_state(peer_id, peer)
	if state == WebSocketPeer.STATE_OPEN:
		if not _mark_peer_open(
			peer_id,
			peer,
			expected_generation
		):
			return -1
		return _emit_peer_packets(
			peer_id,
			peer,
			packet_limit,
			expected_generation,
			Mode.SERVER
		)
	if state == WebSocketPeer.STATE_CLOSED:
		_close_server_peer(peer_id, peer, "closed")
	elif (
		state == WebSocketPeer.STATE_CONNECTING
		and _server_peer_handshake_timed_out(peer_id)
	):
		_close_server_peer(peer_id, peer, "handshake_timeout")
	return 0


func _server_peer_has_available_packets(
	peer_id: int,
	peer: WebSocketPeer
) -> bool:
	return (
		_peers.has(peer_id)
		and _get_peer_value(
			GFVariantData.get_option_value(_peers, peer_id)
		)
		== peer
		and peer.get_ready_state() == WebSocketPeer.STATE_OPEN
		and _get_peer_available_packet_count(peer_id, peer) > 0
	)


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
	var error: Error = peer.send(bytes, WebSocketPeer.WRITE_MODE_BINARY)
	if error == OK:
		_record_transport_packet_sent(bytes.size())
	return error


func _mark_peer_open(
	peer_id: int,
	peer: WebSocketPeer,
	expected_generation: int
) -> bool:
	if not _is_server_peer_current(
		expected_generation,
		peer_id,
		peer
	):
		return false
	if _open_peer_ids.has(peer_id):
		return true

	var _accepted_at_erased: bool = _peer_accepted_at_msec.erase(peer_id)
	_open_peer_ids[peer_id] = true
	_emit_peer_connected(peer_id)
	return _is_server_peer_current(
		expected_generation,
		peer_id,
		peer
	)


func _close_server_peer(
	peer_id: int,
	peer: WebSocketPeer,
	reason: String
) -> void:
	if not _is_server_peer_current(
		_session_generation,
		peer_id,
		peer
	):
		return
	if peer != null and peer.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		peer.close()

	var _erased_peer: bool = _peers.erase(peer_id)
	var _accepted_at_erased: bool = _peer_accepted_at_msec.erase(peer_id)
	_remove_service_peer_id(peer_id)
	var was_open: bool = _open_peer_ids.erase(peer_id)
	if was_open:
		_emit_peer_disconnected(peer_id)
	else:
		_handshake_failure_count += 1
		if reason == "handshake_timeout":
			_handshake_timeout_count += 1


func _close_all(should_emit_signal: bool) -> void:
	var was_active: bool = _mode != Mode.DISCONNECTED
	var client_to_close: WebSocketPeer = _client
	var server_to_stop: TCPServer = _server
	var peers_to_close: Array[WebSocketPeer] = []
	var disconnected_peer_ids: Array[int] = []
	if _client_was_open:
		disconnected_peer_ids.append(SERVER_PEER_ID)
	for peer_id_variant: Variant in _peers.keys():
		var peer_id: int = GFVariantData.to_int(peer_id_variant)
		var peer: WebSocketPeer = _get_peer_value(GFVariantData.get_option_value(_peers, peer_id))
		if peer != null:
			peers_to_close.append(peer)
		if _open_peer_ids.has(peer_id):
			disconnected_peer_ids.append(peer_id)

	var closed_generation: int = _advance_session_generation()
	_client = null
	_client_was_open = false
	_peers.clear()
	_peer_accepted_at_msec.clear()
	_open_peer_ids.clear()
	_service_peer_ids.clear()
	_service_peer_cursor = 0
	_server = null
	_mode = Mode.DISCONNECTED
	_endpoint = ""
	_transport_connected = false
	_transport_connected_at_msec = 0
	_server_peer_options.clear()
	_next_peer_id = SERVER_PEER_ID + 1
	_server_capacity = 0
	_accepted_connection_count = 0
	_capacity_rejection_count = 0
	_accept_failure_count = 0
	_handshake_failure_count = 0
	_handshake_timeout_count = 0
	_accept_attempt_count = 0
	_peer_option_rejection_count = 0
	_packet_budget_exhaustion_count = 0
	_peer_packet_budget_exhaustion_count = 0
	_service_peer_budget_exhaustion_count = 0
	_reset_last_poll_work_snapshot()

	if (
		client_to_close != null
		and client_to_close.get_ready_state()
		!= WebSocketPeer.STATE_CLOSED
	):
		client_to_close.close()
	for peer: WebSocketPeer in peers_to_close:
		if peer.get_ready_state() != WebSocketPeer.STATE_CLOSED:
			peer.close()
	if server_to_stop != null:
		server_to_stop.stop()

	if not should_emit_signal or not was_active:
		return
	for peer_id: int in disconnected_peer_ids:
		_emit_peer_disconnected(peer_id)
		if not _is_disconnected_session_current(closed_generation):
			return
	_emit_disconnected("closed")


func _reset_last_poll_work_snapshot() -> void:
	_last_poll_accept_attempt_count = 0
	_last_poll_packet_count = 0
	_last_poll_service_peer_count = 0
	_last_poll_packet_budget_exhausted = false
	_last_poll_service_peer_budget_exhausted = false


func _advance_session_generation() -> int:
	_session_generation += 1
	return _session_generation


func _is_server_generation_current(expected_generation: int) -> bool:
	return (
		_session_generation == expected_generation
		and _mode == Mode.SERVER
	)


func _is_server_session_current(
	expected_generation: int,
	expected_server: TCPServer
) -> bool:
	return (
		_is_server_generation_current(expected_generation)
		and _server == expected_server
	)


func _is_client_session_current(
	expected_generation: int,
	expected_client: WebSocketPeer
) -> bool:
	return (
		_session_generation == expected_generation
		and _mode == Mode.CLIENT
		and expected_client != null
		and _client == expected_client
	)


func _is_server_peer_current(
	expected_generation: int,
	peer_id: int,
	expected_peer: WebSocketPeer
) -> bool:
	return (
		_is_server_generation_current(expected_generation)
		and expected_peer != null
		and _peers.has(peer_id)
		and _get_peer_value(
			GFVariantData.get_option_value(_peers, peer_id)
		)
		== expected_peer
	)


func _packet_source_is_current(
	expected_mode: Mode,
	expected_generation: int,
	peer_id: int,
	peer: WebSocketPeer
) -> bool:
	if expected_mode == Mode.CLIENT:
		return (
			peer_id == SERVER_PEER_ID
			and _is_client_session_current(expected_generation, peer)
		)
	if expected_mode == Mode.SERVER:
		return _is_server_peer_current(
			expected_generation,
			peer_id,
			peer
		)
	return false


func _is_disconnected_session_current(expected_generation: int) -> bool:
	return (
		_session_generation == expected_generation
		and _mode == Mode.DISCONNECTED
		and _client == null
		and _server == null
	)


func _advance_service_peer_cursor(peer_index: int, peer_id: int) -> void:
	if _service_peer_ids.is_empty():
		_service_peer_cursor = 0
		return
	if (
		peer_index < _service_peer_ids.size()
		and _service_peer_ids[peer_index] == peer_id
	):
		_service_peer_cursor = peer_index + 1
	if _service_peer_cursor >= _service_peer_ids.size():
		_service_peer_cursor = 0


func _remove_service_peer_id(peer_id: int) -> void:
	var peer_index: int = _service_peer_ids.find(peer_id)
	if peer_index < 0:
		return
	_service_peer_ids.remove_at(peer_index)
	if peer_index < _service_peer_cursor:
		_service_peer_cursor -= 1
	if _service_peer_ids.is_empty() or _service_peer_cursor >= _service_peer_ids.size():
		_service_peer_cursor = 0


func _server_peer_handshake_timed_out(peer_id: int) -> bool:
	if not _peer_accepted_at_msec.has(peer_id):
		return false
	var accepted_at_msec: int = _peer_accepted_at_msec[peer_id]
	return _get_ticks_msec() - accepted_at_msec >= _handshake_timeout_msec


func _get_ticks_msec() -> int:
	return Time.get_ticks_msec()


func _poll_client_peer(peer: WebSocketPeer) -> void:
	peer.poll()


func _get_client_ready_state(peer: WebSocketPeer) -> int:
	return peer.get_ready_state()


func _get_server_peer_ready_state(
	_peer_id: int,
	peer: WebSocketPeer
) -> int:
	return peer.get_ready_state()


func _get_peer_available_packet_count(
	_peer_id: int,
	peer: WebSocketPeer
) -> int:
	return peer.get_available_packet_count()


func _get_peer_packet(
	_peer_id: int,
	peer: WebSocketPeer
) -> PackedByteArray:
	return peer.get_packet()


func _create_tcp_server() -> TCPServer:
	return TCPServer.new()


func _create_websocket_peer() -> WebSocketPeer:
	return WebSocketPeer.new()


func _is_server_connection_available() -> bool:
	return _server != null and _server.is_connection_available()


func _take_server_connection() -> StreamPeerTCP:
	if _server == null:
		return null
	return _server.take_connection()


func _accept_server_stream(peer: WebSocketPeer, stream: StreamPeerTCP) -> Error:
	return peer.accept_stream(stream)


func _reject_server_stream(stream: StreamPeerTCP) -> void:
	if stream == null:
		return
	stream.disconnect_from_host()


func _validate_peer_options(options: Dictionary) -> bool:
	return (
		_is_exact_positive_bounded_option(
			options,
			&"inbound_buffer_size",
			ABSOLUTE_MAX_INBOUND_BUFFER_SIZE
		)
		and _is_exact_positive_bounded_option(
			options,
			&"outbound_buffer_size",
			ABSOLUTE_MAX_OUTBOUND_BUFFER_SIZE
		)
		and _is_exact_positive_bounded_option(
			options,
			&"max_queued_packets",
			ABSOLUTE_MAX_QUEUED_PACKETS
		)
		and _supported_protocols_option_is_valid(options)
		and _exact_bool_option_is_valid(options, &"no_delay")
	)


func _normalize_peer_options(options: Dictionary) -> Dictionary:
	var normalized: Dictionary = {}
	if _has_option(options, &"supported_protocols"):
		normalized["supported_protocols"] = (
			_get_validated_supported_protocols(options)
		)
	if _has_option(options, &"no_delay"):
		normalized["no_delay"] = _get_option_value(options, &"no_delay")
	normalized["inbound_buffer_size"] = _get_exact_option_int(
		options,
		&"inbound_buffer_size",
		DEFAULT_INBOUND_BUFFER_SIZE
	)
	normalized["outbound_buffer_size"] = _get_exact_option_int(
		options,
		&"outbound_buffer_size",
		DEFAULT_OUTBOUND_BUFFER_SIZE
	)
	normalized["max_queued_packets"] = _get_exact_option_int(
		options,
		&"max_queued_packets",
		DEFAULT_MAX_QUEUED_PACKETS
	)
	return normalized


func _apply_peer_options(peer: WebSocketPeer, options: Dictionary) -> Error:
	if peer == null:
		return ERR_INVALID_PARAMETER
	if not _validate_peer_options(options):
		return ERR_INVALID_PARAMETER
	if options.has("supported_protocols"):
		peer.set_supported_protocols(
			_get_validated_supported_protocols(options)
		)
	peer.set_inbound_buffer_size(_get_exact_option_int(
		options,
		&"inbound_buffer_size",
		DEFAULT_INBOUND_BUFFER_SIZE
	))
	peer.set_outbound_buffer_size(_get_exact_option_int(
		options,
		&"outbound_buffer_size",
		DEFAULT_OUTBOUND_BUFFER_SIZE
	))
	peer.set_max_queued_packets(_get_exact_option_int(
		options,
		&"max_queued_packets",
		DEFAULT_MAX_QUEUED_PACKETS
	))
	if options.has("no_delay"):
		var no_delay_value: Variant = options["no_delay"]
		if no_delay_value is bool:
			var no_delay: bool = no_delay_value
			peer.set_no_delay(no_delay)
	return OK


func _supported_protocols_option_is_valid(options: Dictionary) -> bool:
	if not _has_option(options, &"supported_protocols"):
		return true
	var raw_protocols: Variant = _get_option_value(
		options,
		&"supported_protocols"
	)
	var values: Array = []
	if raw_protocols is PackedStringArray:
		for protocol: String in _get_packed_string_array_value(raw_protocols):
			values.append(protocol)
	elif raw_protocols is Array:
		values = GFVariantData.as_array(raw_protocols)
	else:
		return false
	if values.size() > ABSOLUTE_MAX_SUPPORTED_PROTOCOL_COUNT:
		return false
	var identities: Dictionary[String, bool] = {}
	var total_bytes: int = 0
	for protocol_value: Variant in values:
		var protocol: String = ""
		if protocol_value is String:
			protocol = protocol_value
		elif protocol_value is StringName:
			var protocol_name: StringName = protocol_value
			protocol = String(protocol_name)
		else:
			return false
		if (
			not _websocket_protocol_is_valid(protocol)
			or identities.has(protocol)
		):
			return false
		identities[protocol] = true
		var protocol_bytes: int = protocol.to_utf8_buffer().size()
		if protocol_bytes > ABSOLUTE_MAX_SUPPORTED_PROTOCOL_BYTES:
			return false
		total_bytes += protocol_bytes
		if total_bytes > ABSOLUTE_MAX_SUPPORTED_PROTOCOL_TOTAL_BYTES:
			return false
	return true


func _get_validated_supported_protocols(
	options: Dictionary
) -> PackedStringArray:
	var protocols: PackedStringArray = PackedStringArray()
	if not _supported_protocols_option_is_valid(options):
		return protocols
	var raw_protocols: Variant = _get_option_value(
		options,
		&"supported_protocols"
	)
	if raw_protocols is PackedStringArray:
		return _get_packed_string_array_value(raw_protocols).duplicate()
	if raw_protocols is Array:
		for protocol_value: Variant in GFVariantData.as_array(raw_protocols):
			if protocol_value is String:
				var protocol: String = protocol_value
				var _string_appended: bool = protocols.append(protocol)
			elif protocol_value is StringName:
				var protocol_name: StringName = protocol_value
				var _name_appended: bool = protocols.append(
					String(protocol_name)
				)
	return protocols


func _websocket_protocol_is_valid(protocol: String) -> bool:
	if protocol.is_empty():
		return false
	const TOKEN_PUNCTUATION: String = "!#$%&'*+-.^_`|~"
	for byte_value: int in protocol.to_ascii_buffer():
		if (
			(byte_value >= 48 and byte_value <= 57)
			or (byte_value >= 65 and byte_value <= 90)
			or (byte_value >= 97 and byte_value <= 122)
			or TOKEN_PUNCTUATION.contains(String.chr(byte_value))
		):
			continue
		return false
	return true


func _exact_bool_option_is_valid(
	options: Dictionary,
	option_name: StringName
) -> bool:
	return (
		not _has_option(options, option_name)
		or _get_option_value(options, option_name) is bool
	)


func _is_exact_positive_bounded_option(
	options: Dictionary,
	option_name: StringName,
	absolute_maximum: int
) -> bool:
	if not _has_option(options, option_name):
		return true
	var option_value: Variant = _get_option_value(options, option_name)
	if not option_value is int:
		return false
	var int_value: int = option_value
	return int_value > 0 and int_value <= absolute_maximum


func _get_exact_option_int(
	options: Dictionary,
	option_name: StringName,
	default_value: int
) -> int:
	if not _has_option(options, option_name):
		return default_value
	var option_value: Variant = _get_option_value(options, option_name)
	if option_value is int:
		var int_value: int = option_value
		return int_value
	return default_value


func _has_option(options: Dictionary, option_name: StringName) -> bool:
	return options.has(option_name) or options.has(String(option_name))


func _get_option_value(options: Dictionary, option_name: StringName) -> Variant:
	if options.has(option_name):
		return options[option_name]
	var text_option_name: String = String(option_name)
	if options.has(text_option_name):
		return options[text_option_name]
	return null


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
