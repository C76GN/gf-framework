## GFBgmStartResult: 单次 BGM start request 的不可变类型化终态。
##
## 结果使用闭合 status/reason/error/disposition 联合。只有 `STARTED` 携带已提交的规范
## 会话句柄；其他终态不伪造会话身份或播放 owner。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 11.0.0
## [br]
## @layer standard/utilities/audio
class_name GFBgmStartResult
extends RefCounted


# --- 枚举 ---

## BGM start request 的唯一 caller 终态。
## [br]
## @api public
## [br]
## @since 11.0.0
enum Status {
	## 后端或本地播放器已经接受并提交会话。
	STARTED,
	## 请求在接纳前因输入、生命周期或重入边界被拒绝。
	REJECTED,
	## 有效请求在准备或提交阶段失败。
	FAILED,
	## 更新且有效的 BGM 请求取代了当前等待请求。
	SUPERSEDED,
	## 调用方或 owner/Utility 生命周期取消了等待请求。
	CANCELLED,
}

## 当前请求与可选 Audio Backend 的交互结果。
## [br]
## @api public
## [br]
## @since 11.0.0
enum BackendDisposition {
	## 没有可用后端，或请求在探测前终结。
	NOT_ATTEMPTED,
	## 后端明确不处理该请求，本地路径可继续准备。
	NOT_CLAIMED,
	## 后端声明可处理但拒绝接受播放，本地路径可继续准备。
	REJECTED,
	## 后端接受并持有已提交的 BGM 会话。
	STARTED,
	## 后端调用身份、backend topology/epoch 变化，或已接受候选的 Session 发布失败，
	## 使原请求失效；返回值不得提交。
	INVALIDATED,
}


# --- 常量 ---

## 本地播放器接受并提交会话。
## [br]
## @api public
## [br]
## @since 11.0.0
const REASON_LOCAL_STARTED: StringName = &"local_started"

## Audio Backend 接受并提交会话。
## [br]
## @api public
## [br]
## @since 11.0.0
const REASON_BACKEND_STARTED: StringName = &"backend_started"

## 后端未接受请求，本地 fallback 接受并提交会话。
## [br]
## @api public
## [br]
## @since 11.0.0
const REASON_BACKEND_FALLBACK_STARTED: StringName = &"backend_fallback_started"

## BGM 路径为空或不符合请求契约。
## [br]
## @api public
## [br]
## @since 11.0.0
const REASON_INVALID_PATH: StringName = &"invalid_path"

## BGM options 不符合闭合选项契约。
## [br]
## @api public
## [br]
## @since 11.0.0
const REASON_INVALID_OPTIONS: StringName = &"invalid_options"

## GFAudioClip 为空、没有 source 或无法冻结。
## [br]
## @api public
## [br]
## @since 11.0.0
const REASON_INVALID_CLIP: StringName = &"invalid_clip"

## 播放区间不符合本地或后端的精确执行契约。
## [br]
## @api public
## [br]
## @since 11.0.0
const REASON_INVALID_PLAYBACK_REGION: StringName = &"invalid_playback_region"

## Audio Utility 尚未初始化或已经释放。
## [br]
## @api public
## [br]
## @since 11.0.0
const REASON_UTILITY_NOT_INITIALIZED: StringName = &"utility_not_initialized"

## BGM 请求从 Audio Backend 回调中重入，不能安全接纳。
## [br]
## @api public
## [br]
## @since 11.0.0
const REASON_BACKEND_DISPATCH_IN_PROGRESS: StringName = &"backend_dispatch_in_progress"

## 请求 owner 在接纳前已经无效。
## [br]
## @api public
## [br]
## @since 11.0.0
const REASON_OWNER_UNAVAILABLE: StringName = &"owner_unavailable"

## 异步或同步资源加载没有取得音频流。
## [br]
## @api public
## [br]
## @since 11.0.0
const REASON_ASSET_LOAD_FAILED: StringName = &"asset_load_failed"

## 取得的音频流无法构造可执行播放计划。
## [br]
## @api public
## [br]
## @since 11.0.0
const REASON_STREAM_UNPLAYABLE: StringName = &"stream_unplayable"

## 后端拒绝后，本地 fallback 也无法开始。
## [br]
## @api public
## [br]
## @since 11.0.0
const REASON_BACKEND_REJECTED_AND_LOCAL_FAILED: StringName = (
	&"backend_rejected_and_local_failed"
)

## 从旧 backend-owned 会话交接到本地会话时，后端拒绝释放 owner。
## [br]
## @api public
## [br]
## @since 11.0.0
const REASON_BACKEND_OWNER_RELEASE_FAILED: StringName = &"backend_owner_release_failed"

## 本地播放器拒绝已经准备完成的执行计划。
## [br]
## @api public
## [br]
## @since 11.0.0
const REASON_LOCAL_PLAYER_REJECTED: StringName = &"local_player_rejected"

## Audio Backend 已接受物理播放候选，但框架无法发布规范 Session 身份。
## [br]
## @api public
## [br]
## @since 11.0.0
const REASON_SESSION_PUBLICATION_FAILED: StringName = &"session_publication_failed"

## 更新且有效的 BGM 请求取代了当前等待请求。
## [br]
## @api public
## [br]
## @since 11.0.0
const REASON_NEWER_REQUEST: StringName = &"newer_request"

## 调用方显式取消等待中的 start request。
## [br]
## @api public
## [br]
## @since 11.0.0
const REASON_CALLER_CANCELLED: StringName = &"caller_cancelled"

## 请求 owner 已退出生命周期。
## [br]
## @api public
## [br]
## @since 11.0.0
const REASON_OWNER_RELEASED: StringName = &"owner_released"

## BGM 通道被显式停止。
## [br]
## @api public
## [br]
## @since 11.0.0
const REASON_STOP_REQUESTED: StringName = &"stop_requested"

## Audio Utility 已释放。
## [br]
## @api public
## [br]
## @since 11.0.0
const REASON_UTILITY_DISPOSED: StringName = &"utility_disposed"

## Audio Backend topology 变更流程在请求等待期间开始，并使当前请求失效。
## [br]
## @api public
## [br]
## @since 11.0.0
const REASON_BACKEND_CHANGED: StringName = &"backend_changed"


# --- 私有变量 ---

var _status: Status = Status.REJECTED
var _request_id: int = 0
var _reason: StringName = &""
var _error_code: Error = ERR_UNCONFIGURED
var _history_key: String = ""
var _owner_kind: GFBgmSessionHandle.OwnerKind = GFBgmSessionHandle.OwnerKind.NONE
var _backend_disposition: BackendDisposition = BackendDisposition.NOT_ATTEMPTED
var _session_handle: GFBgmSessionHandle = null
var _configured: bool = false


# --- 公共方法 ---

## 获取请求终态。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return `STARTED`、`REJECTED`、`FAILED`、`SUPERSEDED` 或 `CANCELLED`。
func get_status() -> Status:
	return _status


## 检查请求是否成功提交播放会话。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 仅 `STARTED` 返回 true。
func is_successful() -> bool:
	return _configured and _status == Status.STARTED


## 获取 Utility 内唯一请求 ID。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 大于零的请求 ID；尚未配置时返回 0。
func get_request_id() -> int:
	return _request_id


## 获取闭合终态原因。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 当前 status 允许的 `REASON_*` 常量之一。
func get_reason() -> StringName:
	return _reason


## 获取终态 Error 码。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return `STARTED` 为 OK；其他 status 为与 reason 对应的非 OK 码。
func get_error_code() -> Error:
	return _error_code


## 获取请求冻结的 BGM history key。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 请求 history key；未提供时为空字符串。
func get_history_key() -> String:
	return _history_key


## 获取已提交会话的物理播放 owner。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return `STARTED` 为 `LOCAL` 或 `BACKEND`；其他终态为 `NONE`。
func get_owner_kind() -> GFBgmSessionHandle.OwnerKind:
	return _owner_kind


## 获取本次请求的 Audio Backend 处理结果。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return `BackendDisposition` 闭合枚举值。
func get_backend_disposition() -> BackendDisposition:
	return _backend_disposition


## 检查请求是否在 backend 未接纳后由本地播放器成功提交。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return `STARTED/LOCAL` 且 backend 为 `NOT_CLAIMED` 或 `REJECTED` 时返回 true。
func used_backend_fallback() -> bool:
	return (
		is_successful()
		and _owner_kind == GFBgmSessionHandle.OwnerKind.LOCAL
		and _backend_disposition in [
			BackendDisposition.NOT_CLAIMED,
			BackendDisposition.REJECTED,
		]
	)


## 获取已提交会话 ID。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return `STARTED` 返回大于零的会话 ID；其他终态返回 0。
func get_session_id() -> int:
	return _session_handle.get_session_id() if _session_handle != null else 0


## 获取已提交的规范会话句柄。
##
## 结果副本共享同一个会话 capability，避免复制出彼此独立的终态或停止权限。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return `STARTED` 返回规范句柄；其他终态返回 null。
func get_session_handle() -> GFBgmSessionHandle:
	return _session_handle


## 创建隔离的结果 value 副本。
##
## 标量字段会复制；会话句柄保持规范共享引用。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 新结果对象。
func duplicate_result() -> GFBgmStartResult:
	var copy: GFBgmStartResult = GFBgmStartResult.new()
	var _configured_copy: bool = copy.configure_for_framework(
		_status,
		_request_id,
		_reason,
		_error_code,
		_history_key,
		_owner_kind,
		_backend_disposition,
		_session_handle
	)
	return copy


## 转换为不暴露对象引用的闭合报告字典。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 请求、终态、backend 处理结果和会话身份的隔离报告。
## [br]
## @schema return: Exact Dictionary with status: int enum, request_id: int, reason: StringName, error_code: int, history_key: String, owner_kind: int enum, backend_disposition: int enum, used_backend_fallback: bool, and session_id: int fields.
func to_dict() -> Dictionary:
	return {
		"status": int(_status),
		"request_id": _request_id,
		"reason": _reason,
		"error_code": int(_error_code),
		"history_key": _history_key,
		"owner_kind": int(_owner_kind),
		"backend_disposition": int(_backend_disposition),
		"used_backend_fallback": used_backend_fallback(),
		"session_id": get_session_id(),
	}


# --- 框架内部方法 ---

## 由 Audio Utility 写入唯一闭合终态。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/audio
## [br]
## @since 11.0.0
## [br]
## @param status: 请求唯一 caller 终态。
## [br]
## @param request_id: Utility 内唯一且大于零的请求 ID。
## [br]
## @param reason: 当前 status 允许的 `REASON_*` 常量。
## [br]
## @param error_code: 与 status/reason 精确匹配的 Error 码。
## [br]
## @param history_key: 请求冻结的 history key。
## [br]
## @param owner_kind: 仅 `STARTED` 可为 `LOCAL` 或 `BACKEND`。
## [br]
## @param backend_disposition: 请求与可选 Audio Backend 的闭合交互结果。
## [br]
## @param session_handle: 仅 `STARTED` 必须携带的规范会话句柄。
## [br]
## @return 首次完整配置闭合联合成功返回 true。
func configure_for_framework(
	status: Status,
	request_id: int,
	reason: StringName,
	error_code: Error,
	history_key: String,
	owner_kind: GFBgmSessionHandle.OwnerKind,
	backend_disposition: BackendDisposition,
	session_handle: GFBgmSessionHandle = null
) -> bool:
	if (
		_configured
		or request_id <= 0
		or not Status.values().has(int(status))
		or not BackendDisposition.values().has(int(backend_disposition))
		or not GFBgmSessionHandle.OwnerKind.values().has(int(owner_kind))
		or not _status_reason_error_is_valid(status, reason, error_code)
		or not _reason_disposition_is_valid(status, reason, backend_disposition)
		or not _session_union_is_valid(
			status,
			request_id,
			reason,
			history_key,
			owner_kind,
			backend_disposition,
			session_handle
		)
	):
		return false

	_status = status
	_request_id = request_id
	_reason = reason
	_error_code = error_code
	_history_key = history_key
	_owner_kind = owner_kind
	_backend_disposition = backend_disposition
	_session_handle = session_handle
	_configured = true
	return true


## 检查结果是否已由 Audio Utility 完整配置。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/audio
## [br]
## @since 11.0.0
## [br]
## @return closed union 已冻结时返回 true。
func is_configured_for_framework() -> bool:
	return _configured


# --- 私有/辅助方法 ---

static func _status_reason_error_is_valid(
	status: Status,
	reason: StringName,
	error_code: Error
) -> bool:
	match status:
		Status.STARTED:
			return error_code == OK and reason in [
				REASON_LOCAL_STARTED,
				REASON_BACKEND_STARTED,
				REASON_BACKEND_FALLBACK_STARTED,
			]
		Status.REJECTED:
			return (
				(reason in [
					REASON_INVALID_PATH,
					REASON_INVALID_OPTIONS,
					REASON_INVALID_CLIP,
					REASON_INVALID_PLAYBACK_REGION,
				] and error_code == ERR_INVALID_PARAMETER)
				or (reason in [
					REASON_UTILITY_NOT_INITIALIZED,
					REASON_OWNER_UNAVAILABLE,
				] and error_code == ERR_UNAVAILABLE)
				or (
					reason == REASON_BACKEND_DISPATCH_IN_PROGRESS
					and error_code == ERR_BUSY
				)
			)
		Status.FAILED:
			match reason:
				REASON_ASSET_LOAD_FAILED, REASON_BACKEND_REJECTED_AND_LOCAL_FAILED:
					return error_code == ERR_CANT_OPEN
				REASON_STREAM_UNPLAYABLE:
					return error_code == ERR_INVALID_DATA
				REASON_BACKEND_OWNER_RELEASE_FAILED:
					return error_code == ERR_UNAVAILABLE
				REASON_LOCAL_PLAYER_REJECTED, REASON_SESSION_PUBLICATION_FAILED:
					return error_code == ERR_CANT_CREATE
		Status.SUPERSEDED:
			return reason == REASON_NEWER_REQUEST and error_code == ERR_BUSY
		Status.CANCELLED:
			return error_code == ERR_SKIP and reason in [
				REASON_CALLER_CANCELLED,
				REASON_OWNER_RELEASED,
				REASON_STOP_REQUESTED,
				REASON_UTILITY_DISPOSED,
				REASON_BACKEND_CHANGED,
			]
	return false


static func _reason_disposition_is_valid(
	status: Status,
	reason: StringName,
	backend_disposition: BackendDisposition
) -> bool:
	if status == Status.STARTED:
		match reason:
			REASON_LOCAL_STARTED:
				return backend_disposition == BackendDisposition.NOT_ATTEMPTED
			REASON_BACKEND_STARTED:
				return backend_disposition == BackendDisposition.STARTED
			REASON_BACKEND_FALLBACK_STARTED:
				return backend_disposition in [
					BackendDisposition.NOT_CLAIMED,
					BackendDisposition.REJECTED,
				]
		return false
	if status == Status.REJECTED:
		if reason == REASON_INVALID_PLAYBACK_REGION:
			return backend_disposition in [
				BackendDisposition.NOT_ATTEMPTED,
				BackendDisposition.REJECTED,
			]
		return backend_disposition == BackendDisposition.NOT_ATTEMPTED
	if status == Status.FAILED:
		match reason:
			REASON_SESSION_PUBLICATION_FAILED:
				return backend_disposition == BackendDisposition.INVALIDATED
			REASON_BACKEND_REJECTED_AND_LOCAL_FAILED:
				return backend_disposition == BackendDisposition.REJECTED
			REASON_BACKEND_OWNER_RELEASE_FAILED:
				return backend_disposition in [
					BackendDisposition.NOT_CLAIMED,
					BackendDisposition.REJECTED,
				]
			REASON_ASSET_LOAD_FAILED, REASON_STREAM_UNPLAYABLE, REASON_LOCAL_PLAYER_REJECTED:
				return backend_disposition in [
					BackendDisposition.NOT_ATTEMPTED,
					BackendDisposition.NOT_CLAIMED,
					BackendDisposition.REJECTED,
				]
		return false
	if status == Status.CANCELLED and reason == REASON_BACKEND_CHANGED:
		return backend_disposition == BackendDisposition.INVALIDATED
	return backend_disposition in [
		BackendDisposition.NOT_ATTEMPTED,
		BackendDisposition.NOT_CLAIMED,
		BackendDisposition.REJECTED,
		BackendDisposition.INVALIDATED,
	]


static func _session_union_is_valid(
	status: Status,
	request_id: int,
	reason: StringName,
	history_key: String,
	owner_kind: GFBgmSessionHandle.OwnerKind,
	backend_disposition: BackendDisposition,
	session_handle: GFBgmSessionHandle
) -> bool:
	if status != Status.STARTED:
		return (
			owner_kind == GFBgmSessionHandle.OwnerKind.NONE
			and session_handle == null
			and backend_disposition != BackendDisposition.STARTED
			and (
				backend_disposition != BackendDisposition.INVALIDATED
				or status in [Status.SUPERSEDED, Status.CANCELLED]
				or (
					status == Status.FAILED
					and reason == REASON_SESSION_PUBLICATION_FAILED
				)
			)
		)
	if (
		session_handle == null
		or not session_handle.is_configured_for_framework()
		or session_handle.get_session_id() <= 0
		or session_handle.get_request_id() != request_id
		or session_handle.get_history_key() != history_key
		or session_handle.get_owner_kind() != owner_kind
	):
		return false
	if owner_kind == GFBgmSessionHandle.OwnerKind.BACKEND:
		return (
			backend_disposition == BackendDisposition.STARTED
			and reason == REASON_BACKEND_STARTED
		)
	if owner_kind != GFBgmSessionHandle.OwnerKind.LOCAL:
		return false
	if backend_disposition == BackendDisposition.NOT_ATTEMPTED:
		return reason == REASON_LOCAL_STARTED
	return (
		backend_disposition in [
			BackendDisposition.NOT_CLAIMED,
			BackendDisposition.REJECTED,
		]
		and reason == REASON_BACKEND_FALLBACK_STARTED
	)
