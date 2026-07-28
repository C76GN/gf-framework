## GFNetworkLobbyOperationResult: Lobby 操作终态结果。
##
## 通过 request_id 和 operation 将 SDK 回调关联到唯一请求，并统一承载单个 Lobby、
## 查询列表、失败状态与耗时。结果是不可回写到 Handle 的深拷贝快照。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 10.0.0
class_name GFNetworkLobbyOperationResult
extends RefCounted


# --- 公共变量 ---

## 请求 ID。
## [br]
## @api public
## [br]
## @since 10.0.0
var request_id: StringName = &""

## 操作类型。
## [br]
## @api public
## [br]
## @since 10.0.0
var operation: StringName = &""

## 操作是否成功。
## [br]
## @api public
## [br]
## @since 10.0.0
var ok: bool = false

## 稳定终态状态。
## [br]
## @api public
## [br]
## @since 10.0.0
var status: StringName = &""

## 相关 Lobby ID。
## [br]
## @api public
## [br]
## @since 10.0.0
var lobby_id: String = ""

## 单个 Lobby 快照。
## [br]
## @api public
## [br]
## @since 10.0.0
var lobby: GFNetworkLobbyDescriptor = null

## 查询操作返回的 Lobby 快照列表。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @schema lobbies: Array[GFNetworkLobbyDescriptor] queried lobby snapshots.
var lobbies: Array[GFNetworkLobbyDescriptor] = []

## 失败原因标识。
## [br]
## @api public
## [br]
## @since 10.0.0
var error: StringName = &""

## 人读说明。
## [br]
## @api public
## [br]
## @since 10.0.0
var message: String = ""

## 开始单调时间戳，单位毫秒；-1 表示未知。
## [br]
## @api public
## [br]
## @since 10.0.0
var started_at_msec: int = -1

## 完成单调时间戳，单位毫秒；-1 表示未知。
## [br]
## @api public
## [br]
## @since 10.0.0
var completed_at_msec: int = -1

## 调用方或 Adapter 结果元数据。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @schema metadata: Dictionary caller-defined result metadata.
var metadata: Dictionary = {}


# --- 私有变量 ---

var _payload_valid: bool = true


# --- 公共方法 ---

## 配置成功结果。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param request: 对应请求。
## [br]
## @param options: 可包含 status、lobby、lobbies、lobby_id、started_at_msec、completed_at_msec 和 metadata。
## [br]
## @schema options: Dictionary successful lobby result fields.
## [br]
## @return 当前结果。
func configure_success(
	request: GFNetworkLobbyOperationRequest,
	options: Dictionary = {}
) -> GFNetworkLobbyOperationResult:
	_apply_request(request)
	_payload_valid = true
	ok = true
	status = GFVariantData.get_option_string_name(options, "status", &"ok")
	lobby = _get_lobby(options, "lobby")
	lobbies = _get_lobbies(options)
	var option_lobby_id: String = GFVariantData.get_option_string(
		options,
		"lobby_id"
	).strip_edges()
	if not option_lobby_id.is_empty():
		lobby_id = option_lobby_id
	elif lobby != null:
		lobby_id = lobby.lobby_id
	error = &""
	message = ""
	started_at_msec = maxi(
		GFVariantData.get_option_int(options, "started_at_msec", -1),
		-1
	)
	completed_at_msec = maxi(
		GFVariantData.get_option_int(options, "completed_at_msec", -1),
		-1
	)
	metadata = GFVariantData.get_option_dictionary(options, "metadata")
	return self


## 配置失败结果。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param request: 对应请求。
## [br]
## @param p_error: 稳定失败原因。
## [br]
## @param p_message: 人读说明。
## [br]
## @param options: 可包含 status、started_at_msec、completed_at_msec 和 metadata。
## [br]
## @schema options: Dictionary failed lobby result fields.
## [br]
## @return 当前结果。
func configure_failure(
	request: GFNetworkLobbyOperationRequest,
	p_error: StringName,
	p_message: String = "",
	options: Dictionary = {}
) -> GFNetworkLobbyOperationResult:
	_apply_request(request)
	_payload_valid = true
	ok = false
	status = GFVariantData.get_option_string_name(options, "status", p_error)
	lobby = null
	lobbies.clear()
	error = p_error if p_error != &"" else &"failed"
	message = p_message.strip_edges()
	started_at_msec = maxi(
		GFVariantData.get_option_int(options, "started_at_msec", -1),
		-1
	)
	completed_at_msec = maxi(
		GFVariantData.get_option_int(options, "completed_at_msec", -1),
		-1
	)
	metadata = GFVariantData.get_option_dictionary(options, "metadata")
	return self


## 获取操作耗时，单位毫秒。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 完成时间减开始时间；缺少时间戳时返回 0。
func get_duration_msec() -> int:
	if started_at_msec < 0 or completed_at_msec < 0:
		return 0
	return maxi(completed_at_msec - started_at_msec, 0)


## 校验终态结构是否满足操作契约。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 结果身份、时间和操作特定载荷均有效时返回 true。
func is_valid() -> bool:
	if (
		not _payload_valid
		or request_id == &""
		or not GFNetworkLobbyOperationRequest.get_supported_operations().has(String(operation))
		or status == &""
		or started_at_msec < -1
		or completed_at_msec < -1
		or (
			started_at_msec >= 0
			and completed_at_msec >= 0
			and completed_at_msec < started_at_msec
		)
	):
		return false
	if not ok:
		return error != &""
	if error != &"":
		return false
	match operation:
		GFNetworkLobbyOperationRequest.OP_CREATE_LOBBY:
			return (
				lobby != null
				and not lobby.lobby_id.is_empty()
				and lobby_id == lobby.lobby_id
			)
		GFNetworkLobbyOperationRequest.OP_JOIN_LOBBY:
			return (
				lobby != null
				and not lobby.lobby_id.is_empty()
				and lobby_id == lobby.lobby_id
			)
		GFNetworkLobbyOperationRequest.OP_QUERY_LOBBIES:
			var seen_lobby_ids: Dictionary = {}
			for lobby_entry: GFNetworkLobbyDescriptor in lobbies:
				if (
					lobby_entry == null
					or lobby_entry.lobby_id.is_empty()
					or seen_lobby_ids.has(lobby_entry.lobby_id)
				):
					return false
				seen_lobby_ids[lobby_entry.lobby_id] = true
			return true
		GFNetworkLobbyOperationRequest.OP_LEAVE_LOBBY:
			return not lobby_id.is_empty()
		GFNetworkLobbyOperationRequest.OP_SET_LOBBY_METADATA:
			return not lobby_id.is_empty()
		GFNetworkLobbyOperationRequest.OP_SET_MEMBER_METADATA:
			return not lobby_id.is_empty()
	return false


## 检查结果是否属于给定请求。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param request: 待匹配请求。
## [br]
## @return request_id 和 operation 同时匹配时返回 true。
func matches_request(request: GFNetworkLobbyOperationRequest) -> bool:
	return (
		request != null
		and request_id == request.request_id
		and operation == request.operation
	)


## 转换为字典。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return Lobby 操作结果字典。
## [br]
## @schema return: Dictionary lobby operation result.
func to_dict() -> Dictionary:
	var lobby_entries: Array[Dictionary] = []
	for lobby_entry: GFNetworkLobbyDescriptor in lobbies:
		if lobby_entry != null:
			lobby_entries.append(lobby_entry.to_dict())
	return {
		"request_id": request_id,
		"operation": operation,
		"ok": ok,
		"status": status,
		"lobby_id": lobby_id,
		"lobby": lobby.to_dict() if lobby != null else {},
		"lobbies": lobby_entries,
		"error": error,
		"message": message,
		"started_at_msec": started_at_msec,
		"completed_at_msec": completed_at_msec,
		"metadata": metadata.duplicate(true),
	}


## 从字典应用结果字段。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param data: Lobby 操作结果字典。
## [br]
## @schema data: Dictionary lobby operation result.
func apply_dict(data: Dictionary) -> void:
	_payload_valid = true
	request_id = GFVariantData.get_option_string_name(data, "request_id")
	operation = GFVariantData.get_option_string_name(data, "operation")
	ok = GFVariantData.get_option_bool(data, "ok")
	status = GFVariantData.get_option_string_name(data, "status")
	lobby_id = GFVariantData.get_option_string(data, "lobby_id").strip_edges()
	var lobby_data: Dictionary = GFVariantData.get_option_dictionary(data, "lobby")
	lobby = GFNetworkLobbyDescriptor.from_dict(lobby_data) if not lobby_data.is_empty() else null
	lobbies = _get_lobbies_from_dict(data)
	error = GFVariantData.get_option_string_name(data, "error")
	message = GFVariantData.get_option_string(data, "message").strip_edges()
	started_at_msec = maxi(
		GFVariantData.get_option_int(data, "started_at_msec", -1),
		-1
	)
	completed_at_msec = maxi(
		GFVariantData.get_option_int(data, "completed_at_msec", -1),
		-1
	)
	metadata = GFVariantData.get_option_dictionary(data, "metadata")


## 创建结果深拷贝。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 新结果。
func duplicate_result() -> GFNetworkLobbyOperationResult:
	var result: GFNetworkLobbyOperationResult = from_dict(to_dict())
	result._payload_valid = _payload_valid
	return result


## 从字典创建结果。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param data: Lobby 操作结果字典。
## [br]
## @schema data: Dictionary lobby operation result.
## [br]
## @return 新结果。
static func from_dict(data: Dictionary) -> GFNetworkLobbyOperationResult:
	var result: GFNetworkLobbyOperationResult = GFNetworkLobbyOperationResult.new()
	result.apply_dict(data)
	return result


# --- 私有/辅助方法 ---

func _apply_request(request: GFNetworkLobbyOperationRequest) -> void:
	request_id = request.request_id if request != null else &""
	operation = request.operation if request != null else &""
	lobby_id = request.lobby_id if request != null else ""


func _get_lobby(options: Dictionary, key: String) -> GFNetworkLobbyDescriptor:
	var value: Variant = GFVariantData.get_option_value(options, key)
	if value is GFNetworkLobbyDescriptor:
		var lobby_value: GFNetworkLobbyDescriptor = value
		return lobby_value.duplicate_lobby()
	return null


func _get_lobbies(options: Dictionary) -> Array[GFNetworkLobbyDescriptor]:
	var result: Array[GFNetworkLobbyDescriptor] = []
	if not options.has("lobbies"):
		return result
	var raw_values: Variant = options["lobbies"]
	if not (raw_values is Array):
		_payload_valid = false
		return result
	var values: Array = raw_values
	for value: Variant in values:
		if not (value is GFNetworkLobbyDescriptor):
			_payload_valid = false
			continue
		var lobby_value: GFNetworkLobbyDescriptor = value
		result.append(lobby_value.duplicate_lobby())
	return result


func _get_lobbies_from_dict(data: Dictionary) -> Array[GFNetworkLobbyDescriptor]:
	var result: Array[GFNetworkLobbyDescriptor] = []
	if not data.has("lobbies"):
		return result
	var raw_values: Variant = data["lobbies"]
	if not (raw_values is Array):
		_payload_valid = false
		return result
	var values: Array = raw_values
	for value: Variant in values:
		if not (value is Dictionary):
			_payload_valid = false
			continue
		var lobby_entry_data: Dictionary = value
		result.append(GFNetworkLobbyDescriptor.from_dict(lobby_entry_data))
	return result
