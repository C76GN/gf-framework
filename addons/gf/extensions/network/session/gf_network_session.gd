## GFNetworkSession: 网络会话状态快照。
##
## 记录当前网络工具的主机/客户端意图与连接状态，不绑定房间、账号或匹配逻辑。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 3.17.0
class_name GFNetworkSession
extends RefCounted


# --- 信号 ---

## 会话开始时发出。
## [br]
## @api public
## [br]
## @param mode: Mode 枚举值。
## [br]
## @param endpoint: 会话端点。
signal session_started(mode: int, endpoint: String)

## 会话连接成功时发出。
## [br]
## @api public
## [br]
## @param local_peer_id: 本地 peer 标识。
signal session_connected(local_peer_id: int)

## 会话关闭时发出。
## [br]
## @api public
## [br]
## @param reason: 关闭原因。
signal session_closed(reason: String)


# --- 枚举 ---

## 会话模式。
## [br]
## @api public
enum Mode {
	## 无活动会话。
	NONE,
	## 主机会话。
	HOST,
	## 客户端会话。
	CLIENT,
}


# --- 公共变量 ---

## 当前模式。
## [br]
## @api public
var mode: Mode = Mode.NONE

## 会话端点。
## [br]
## @api public
var endpoint: String = ""

## 本地 peer 标识。
## [br]
## @api public
var local_peer_id: int = -1

## 最大远端数量。
## [br]
## @api public
var max_peers: int = 0

## 会话是否已经启动。
## [br]
## @api public
var is_active: bool = false

## 后端是否已报告连接成功。
## [br]
## @api public
var has_connection: bool = false

## 启动时间。
## [br]
## @api public
var started_at_unix: float = 0.0

## 项目自定义元数据。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary，保存项目自定义会话元数据。
var metadata: Dictionary = {}


# --- 公共方法 ---

## 标记主机会话已开始。
## [br]
## @api public
## [br]
## @param options: 启动选项。
## [br]
## @schema options: Dictionary，支持 endpoint、port、max_clients、max_peers、local_peer_id、metadata。
func start_host(options: Dictionary = {}) -> void:
	mode = Mode.HOST
	var default_endpoint: String = "0.0.0.0:%d" % GFVariantData.get_option_int(options, "port")
	endpoint = GFVariantData.get_option_string(options, "endpoint", default_endpoint)
	max_peers = GFVariantData.get_option_int(
		options,
		"max_clients",
		GFVariantData.get_option_int(options, "max_peers")
	)
	local_peer_id = GFVariantData.get_option_int(options, "local_peer_id", 1)
	metadata = _get_metadata_copy(options)
	is_active = true
	has_connection = false
	started_at_unix = Time.get_unix_time_from_system()
	session_started.emit(mode, endpoint)


## 标记客户端会话已开始。
## [br]
## @api public
## [br]
## @param next_endpoint: 远端端点。
## [br]
## @param options: 连接选项。
## [br]
## @schema options: Dictionary，支持 max_peers、local_peer_id、metadata。
func start_client(next_endpoint: String, options: Dictionary = {}) -> void:
	mode = Mode.CLIENT
	endpoint = next_endpoint
	max_peers = GFVariantData.get_option_int(options, "max_peers")
	local_peer_id = GFVariantData.get_option_int(options, "local_peer_id", -1)
	metadata = _get_metadata_copy(options)
	is_active = true
	has_connection = false
	started_at_unix = Time.get_unix_time_from_system()
	session_started.emit(mode, endpoint)


## 标记后端已经连接。
## [br]
## @api public
## [br]
## @param next_local_peer_id: 本地 peer；小于 0 时保留原值。
func mark_connected(next_local_peer_id: int = -1) -> void:
	if next_local_peer_id >= 0:
		local_peer_id = next_local_peer_id
	has_connection = true
	session_connected.emit(local_peer_id)


## 关闭会话。
## [br]
## @api public
## [br]
## @param reason: 关闭原因。
func close(reason: String = "closed") -> void:
	if not is_active and mode == Mode.NONE:
		return

	mode = Mode.NONE
	endpoint = ""
	local_peer_id = -1
	max_peers = 0
	is_active = false
	has_connection = false
	started_at_unix = 0.0
	metadata.clear()
	session_closed.emit(reason)


## 获取调试快照。
## [br]
## @api public
## [br]
## @return 会话状态字典。
## [br]
## @schema return: Dictionary，包含 mode、mode_name、endpoint、local_peer_id、max_peers、is_active、has_connection、started_at_unix、metadata。
func get_debug_snapshot() -> Dictionary:
	return GFNetworkDebugTools.sanitize_debug_dictionary({
		"mode": mode,
		"mode_name": _get_mode_name(mode),
		"endpoint": endpoint,
		"local_peer_id": local_peer_id,
		"max_peers": max_peers,
		"is_active": is_active,
		"has_connection": has_connection,
		"started_at_unix": started_at_unix,
		"metadata": metadata.duplicate(true),
	})


# --- 私有/辅助方法 ---

func _get_mode_name(query_mode: Mode) -> String:
	match query_mode:
		Mode.HOST:
			return "host"
		Mode.CLIENT:
			return "client"
		_:
			return "none"


func _get_metadata_copy(options: Dictionary) -> Dictionary:
	var metadata_variant: Variant = GFVariantData.get_option_value(options, "metadata")
	if metadata_variant == null:
		return {}

	if metadata_variant is Dictionary:
		return GFVariantData.to_dictionary(metadata_variant)
	push_warning("[GFNetworkSession] metadata 必须是 Dictionary，已忽略。")
	return {}
