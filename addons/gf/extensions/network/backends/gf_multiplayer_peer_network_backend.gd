## GFMultiplayerPeerNetworkBackend: 可接管外部 MultiplayerPeer 的通用网络后端。
##
## 平台 Adapter 负责通过 Steam、小游戏或其他 SDK 创建 `MultiplayerPeer`，本类只负责
## GF bytes 边界、轮询、连接事件和所有权。它不依赖任何第三方 SDK 类型。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since unreleased
class_name GFMultiplayerPeerNetworkBackend
extends GFNetworkBackend


# --- 枚举 ---

## 被接管 Peer 的所有权。
## [br]
## @api public
## [br]
## @since unreleased
enum Ownership {
	## Backend 只借用 Peer，释放时不得关闭它。
	BORROWED,
	## Backend 拥有 Peer，释放时负责关闭它。
	OWNED,
}

## Peer 在当前会话中的角色。
## [br]
## @api public
## [br]
## @since unreleased
enum Role {
	## Adapter 未声明角色。
	UNKNOWN,
	## 主机或服务器。
	SERVER,
	## 客户端。
	CLIENT,
}


# --- 常量 ---

## 广播 peer 标识。
## [br]
## @api public
## [br]
## @since unreleased
const BROADCAST_PEER_ID: int = -1


# --- 公共变量 ---

## 每次 poll 最多派发的入站包数量。小于等于 0 表示不限制。
## [br]
## @api public
## [br]
## @since unreleased
var max_packets_per_poll: int = 64


# --- 私有变量 ---

var _peer: MultiplayerPeer = null
var _ownership: Ownership = Ownership.BORROWED
var _role: Role = Role.UNKNOWN
var _endpoint: String = ""
var _supports_channels: bool = true
var _supports_transfer_modes: bool = true
var _last_status: int = MultiplayerPeer.CONNECTION_DISCONNECTED
var _connected_peer_ids: Dictionary[int, bool] = {}


# --- 公共方法 ---

## 接管一个已由外部 Adapter 初始化的 MultiplayerPeer。
##
## Peer 必须已经处于 connecting 或 connected。替换现有 Peer 时，旧 Peer 会按其
## ownership 关闭或仅解除借用。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param peer: 外部创建的 MultiplayerPeer。
## [br]
## @param options: 支持 ownership、role、endpoint、supports_channels 和 supports_transfer_modes。
## [br]
## @schema options: Dictionary adoptable MultiplayerPeer capabilities and ownership.
## [br]
## @return Godot 错误码。
func adopt_peer(peer: MultiplayerPeer, options: Dictionary = {}) -> Error:
	if peer == null:
		return ERR_INVALID_PARAMETER
	if _peer == peer:
		return ERR_ALREADY_IN_USE
	if not options.has("ownership") or not options.has("role"):
		return ERR_INVALID_PARAMETER
	var ownership_value: Variant = options["ownership"]
	var role_value: Variant = options["role"]
	if not (ownership_value is int) or not (role_value is int):
		return ERR_INVALID_PARAMETER
	var ownership_id: int = ownership_value
	var role_id: int = role_value
	if ownership_id not in [Ownership.BORROWED, Ownership.OWNED]:
		return ERR_INVALID_PARAMETER
	var next_role: Role = _get_role(role_id)
	if next_role == Role.UNKNOWN:
		return ERR_INVALID_PARAMETER
	var status: int = peer.get_connection_status()
	if status == MultiplayerPeer.CONNECTION_DISCONNECTED:
		return ERR_INVALID_PARAMETER
	if _peer != null:
		var _released_peer: MultiplayerPeer = _detach_peer(
			true,
			true,
			"peer_replaced"
	)
	_peer = peer
	_ownership = _get_ownership(ownership_id)
	_role = next_role
	_endpoint = GFVariantData.get_option_string(options, "endpoint").strip_edges()
	_supports_channels = GFVariantData.get_option_bool(options, "supports_channels", true)
	_supports_transfer_modes = GFVariantData.get_option_bool(
		options,
		"supports_transfer_modes",
		true
	)
	_last_status = status
	_reset_transport_metrics()
	_connect_peer_signals()
	if status == MultiplayerPeer.CONNECTION_CONNECTED:
		_emit_connected()
	return OK


## 获取当前 Peer 的借用引用。
##
## 该引用只用于 Provider 状态检查，不得 poll、读取包或装配到 SceneTree.multiplayer；
## Backend 独占 Peer 数据面。需要交给 SceneMultiplayer 时先使用 `take_peer()`。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 当前 Peer；未配置时返回 null。
func get_peer() -> MultiplayerPeer:
	return _peer


## 将 Peer 及其关闭责任转移给调用方。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 原 Peer；未配置时返回 null。
func take_peer() -> MultiplayerPeer:
	return _detach_peer(false, true, "peer_taken")


## 检查 Backend 是否拥有当前 Peer。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 当前 Peer 存在且 ownership 为 OWNED 时返回 true。
func owns_peer() -> bool:
	return _peer != null and _ownership == Ownership.OWNED


## 获取外部 Peer 的会话接管字段。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return role 对应的 Session mode、端点和本地 peer ID。
## [br]
## @schema return: Dictionary network session bootstrap fields.
func get_session_bootstrap() -> Dictionary:
	if _peer == null or _role == Role.UNKNOWN:
		return {}
	return {
		"mode": (
			GFNetworkSession.Mode.HOST
			if _role == Role.SERVER
			else GFNetworkSession.Mode.CLIENT
		),
		"endpoint": _endpoint if not _endpoint.is_empty() else "multiplayer-peer",
		"local_peer_id": _peer.get_unique_id(),
		"metadata": {"backend": "GFMultiplayerPeerNetworkBackend"},
	}


## 断开并释放当前 Peer。
##
## OWNED Peer 会关闭；BORROWED Peer 只解除信号和引用，由外部 Adapter 继续管理。
## [br]
## @api public
## [br]
## @since unreleased
func disconnect_backend() -> void:
	var _released_peer: MultiplayerPeer = _detach_peer(true, true, "closed")


## 发送 bytes。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param peer_id: 目标 peer；-1 表示广播。
## [br]
## @param bytes: 消息 bytes。
## [br]
## @param options: 支持 channel、transfer_mode 和 reliable。
## [br]
## @schema options: Dictionary generic MultiplayerPeer send options.
## [br]
## @return Godot 错误码。
func send_bytes(
	peer_id: int,
	bytes: PackedByteArray,
	options: Dictionary = {}
) -> Error:
	if _peer == null:
		return ERR_UNCONFIGURED
	if bytes.is_empty():
		return ERR_INVALID_DATA
	if _peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		return ERR_CONNECTION_ERROR
	if not _supports_channels and GFVariantData.get_option_int(options, "channel") != 0:
		return ERR_UNAVAILABLE
	if not _supports_transfer_modes and (
		options.has("transfer_mode") or options.has("reliable")
	):
		return ERR_UNAVAILABLE
	_peer.set_target_peer(_map_target_peer(peer_id))
	if _supports_channels:
		_peer.transfer_channel = GFVariantData.get_option_int(options, "channel")
	if _supports_transfer_modes:
		_peer.transfer_mode = _get_transfer_mode(options)
	var error: Error = _peer.put_packet(bytes)
	_peer.set_target_peer(MultiplayerPeer.TARGET_PEER_BROADCAST)
	if error == OK:
		_record_transport_packet_sent(bytes.size())
	return error


## 轮询 Peer 状态和入站包。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param _delta: 本帧时间增量；底层 MultiplayerPeer 自行维护时钟。
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


## 获取 Backend 调试快照。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 已脱敏 Backend 状态。
## [br]
## @schema return: Dictionary adoptable MultiplayerPeer backend snapshot.
func get_debug_snapshot() -> Dictionary:
	var status: int = (
		MultiplayerPeer.CONNECTION_DISCONNECTED
		if _peer == null
		else _peer.get_connection_status()
	)
	return GFNetworkDebugTools.sanitize_debug_dictionary({
		"backend": "GFMultiplayerPeerNetworkBackend",
		"available": _peer != null,
		"ownership": _get_ownership_name(_ownership),
		"role": _get_role_name(_role),
		"endpoint": _endpoint,
		"connection_status": status,
		"connection_status_name": _get_status_name(status),
		"connected_peer_count": _connected_peer_ids.size(),
		"available_packet_count": 0 if _peer == null else _peer.get_available_packet_count(),
		"max_packets_per_poll": max_packets_per_poll,
		"supports_channels": _supports_channels,
		"supports_transfer_modes": _supports_transfer_modes,
	})


# --- 可重写钩子 / 虚方法 ---

func _enrich_transport_metrics(metrics: GFNetworkTransportMetrics) -> void:
	if _peer == null:
		return
	var _queue_set: bool = metrics.set_metric(
		GFNetworkTransportMetrics.RECEIVE_QUEUE_PACKETS,
		float(_peer.get_available_packet_count())
	)


# --- 私有/辅助方法 ---

func _connect_peer_signals() -> void:
	if _peer == null:
		return
	if not _peer.peer_connected.is_connected(_on_peer_connected):
		var _connected_error: Error = _peer.peer_connected.connect(
			_on_peer_connected
		) as Error
	if not _peer.peer_disconnected.is_connected(_on_peer_disconnected):
		var _disconnected_error: Error = _peer.peer_disconnected.connect(
			_on_peer_disconnected
		) as Error


func _disconnect_peer_signals() -> void:
	if _peer == null:
		return
	if _peer.peer_connected.is_connected(_on_peer_connected):
		_peer.peer_connected.disconnect(_on_peer_connected)
	if _peer.peer_disconnected.is_connected(_on_peer_disconnected):
		_peer.peer_disconnected.disconnect(_on_peer_disconnected)


func _detach_peer(
	close_owned: bool,
	should_emit_disconnected: bool,
	reason: String
) -> MultiplayerPeer:
	if _peer == null:
		_emit_tracked_peer_disconnections()
		return null
	var detached_peer: MultiplayerPeer = _peer
	var should_close: bool = close_owned and _ownership == Ownership.OWNED
	_disconnect_peer_signals()
	_peer = null
	if should_close:
		detached_peer.close()
	_emit_tracked_peer_disconnections()
	_last_status = MultiplayerPeer.CONNECTION_DISCONNECTED
	_ownership = Ownership.BORROWED
	_role = Role.UNKNOWN
	_endpoint = ""
	_supports_channels = true
	_supports_transfer_modes = true
	if should_emit_disconnected:
		_emit_disconnected(reason)
	return detached_peer


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
			var _released_peer: MultiplayerPeer = _detach_peer(
				true,
				false,
				"connection_status_disconnected"
			)
			_emit_disconnected("connection_status_disconnected")


func _map_target_peer(peer_id: int) -> int:
	return (
		MultiplayerPeer.TARGET_PEER_BROADCAST
		if peer_id == BROADCAST_PEER_ID
		else peer_id
	)


func _get_transfer_mode(options: Dictionary) -> MultiplayerPeer.TransferMode:
	if options.has("transfer_mode"):
		return _to_transfer_mode(GFVariantData.to_int(options["transfer_mode"]))
	return (
		MultiplayerPeer.TRANSFER_MODE_RELIABLE
		if GFVariantData.get_option_bool(options, "reliable", true)
		else MultiplayerPeer.TRANSFER_MODE_UNRELIABLE
	)


func _to_transfer_mode(value: int) -> MultiplayerPeer.TransferMode:
	match value:
		MultiplayerPeer.TRANSFER_MODE_UNRELIABLE:
			return MultiplayerPeer.TRANSFER_MODE_UNRELIABLE
		MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED:
			return MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED
		_:
			return MultiplayerPeer.TRANSFER_MODE_RELIABLE


func _get_ownership(value: int) -> Ownership:
	return Ownership.OWNED if value == Ownership.OWNED else Ownership.BORROWED


func _get_role(value: int) -> Role:
	match value:
		Role.SERVER:
			return Role.SERVER
		Role.CLIENT:
			return Role.CLIENT
		_:
			return Role.UNKNOWN


func _get_ownership_name(value: Ownership) -> String:
	return "owned" if value == Ownership.OWNED else "borrowed"


func _get_role_name(value: Role) -> String:
	match value:
		Role.SERVER:
			return "server"
		Role.CLIENT:
			return "client"
		_:
			return "unknown"


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
	var _erased: bool = _connected_peer_ids.erase(peer_id)
	_emit_peer_disconnected(peer_id)


func _emit_tracked_peer_disconnections() -> void:
	var peer_ids: Array[int] = []
	for peer_id: int in _connected_peer_ids.keys():
		peer_ids.append(peer_id)
	peer_ids.sort()
	_connected_peer_ids.clear()
	for peer_id: int in peer_ids:
		_emit_peer_disconnected(peer_id)
