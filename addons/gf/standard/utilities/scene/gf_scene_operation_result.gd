## GFSceneOperationResult: 单次类型化场景请求的不可变终态。
##
## 结果冻结请求种类、资源身份、可选 PackedScene 与闭合 status/reason/error 联合。
## 所有身份 getter 返回隔离快照，调用方不能改写 Operation 已冻结的资源身份。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since unreleased
## [br]
## @layer standard/utilities/scene
class_name GFSceneOperationResult
extends RefCounted


# --- 枚举 ---

## 类型化场景请求的唯一 caller 终态。
## [br]
## @api public
## [br]
## @since unreleased
enum Status {
	## 场景已缓存，或已经在安全帧成功切换。
	COMPLETED,
	## 请求在 Broker dispatch 前或 admission 边界被拒绝。
	REJECTED,
	## 有效请求在资源加载、类型校验或场景切换阶段失败。
	FAILED,
	## caller、token、owner、path 或共享 Broker 生命周期取消了当前 consumer。
	CANCELLED,
	## Scene Utility 已释放。
	DISPOSED,
}


# --- 常量 ---

## 已在安全帧成功切换到目标场景。
## [br]
## @api public
## [br]
## @since unreleased
const REASON_SCENE_LOADED: StringName = &"scene_loaded"

## 场景资源已成功预加载；是否继续保留在缓存由容量与 fixed 策略决定。
## [br]
## @api public
## [br]
## @since unreleased
const REASON_SCENE_PRELOADED: StringName = &"scene_preloaded"

## 请求直接命中已有场景缓存。
## [br]
## @api public
## [br]
## @since unreleased
const REASON_CACHE_HIT: StringName = &"cache_hit"

## 场景路径为空、逃逸项目根目录、不存在或不是 PackedScene。
## [br]
## @api public
## [br]
## @since unreleased
const REASON_INVALID_PATH: StringName = &"invalid_path"

## 请求 owner 在接纳前已经无效。
## [br]
## @api public
## [br]
## @since unreleased
const REASON_OWNER_UNAVAILABLE: StringName = &"owner_unavailable"

## 已有 load 请求正在等待，不允许 replacement。
## [br]
## @api public
## [br]
## @since unreleased
const REASON_LOAD_BUSY: StringName = &"load_busy"

## Resource Broker 拒绝 consumer Lease 或底层请求 admission。
## [br]
## @api public
## [br]
## @since unreleased
const REASON_BROKER_REJECTED: StringName = &"broker_rejected"

## 已接纳的 Broker 请求在运行期加载失败。
## [br]
## @api public
## [br]
## @since unreleased
const REASON_RESOURCE_LOAD_FAILED: StringName = &"resource_load_failed"

## Broker 完成的资源不是 PackedScene。
## [br]
## @api public
## [br]
## @since unreleased
const REASON_RESOURCE_TYPE_MISMATCH: StringName = &"resource_type_mismatch"

## PackedScene 已准备完成，但安全帧场景切换失败。
## [br]
## @api public
## [br]
## @since unreleased
const REASON_SCENE_CHANGE_FAILED: StringName = &"scene_change_failed"

## caller 通过 Operation.cancel() 显式取消当前 consumer。
## [br]
## @api public
## [br]
## @since unreleased
const REASON_CALLER_CANCELLED: StringName = &"caller_cancelled"

## 绑定的 cancellation token 请求取消。
## [br]
## @api public
## [br]
## @since unreleased
const REASON_TOKEN_CANCELLED: StringName = &"token_cancelled"

## 绑定的请求 owner 已释放。
## [br]
## @api public
## [br]
## @since unreleased
const REASON_OWNER_RELEASED: StringName = &"owner_released"

## 旧 path-level cancel API 取消了同路径的全部 consumer。
## [br]
## @api public
## [br]
## @since unreleased
const REASON_PATH_CANCELLED: StringName = &"path_cancelled"

## 共享 Resource Broker 被外部调用方显式取消。
## [br]
## @api public
## [br]
## @since unreleased
const REASON_EXTERNAL_CANCELLED: StringName = &"external_cancelled"

## 共享 Resource Broker 已释放并取消当前 consumer Lease。
## [br]
## @api public
## [br]
## @since unreleased
const REASON_BROKER_DISPOSED: StringName = &"broker_disposed"

## Broker 返回了未纳入公开闭合集的取消原因。
## [br]
## @api public
## [br]
## @since unreleased
const REASON_BROKER_CANCELLED: StringName = &"broker_cancelled"

## Scene Utility 已释放并终结所有等待请求。
## [br]
## @api public
## [br]
## @since unreleased
const REASON_UTILITY_DISPOSED: StringName = &"utility_disposed"

const _KIND_LOAD: int = 0
const _KIND_PRELOAD: int = 1


# --- 私有变量 ---

var _status: Status = Status.REJECTED
var _request_id: int = 0
var _kind: int = _KIND_LOAD
var _scene_identity: GFResourceIdentity = null
var _scene: PackedScene = null
var _reason: StringName = &""
var _error_code: Error = ERR_UNCONFIGURED
var _configured: bool = false


# --- 公共方法 ---

## 获取请求终态。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return `Status` 闭合枚举值。
func get_status() -> Status:
	return _status


## 检查请求是否成功完成。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 仅 `COMPLETED` 返回 true。
func is_successful() -> bool:
	return _configured and _status == Status.COMPLETED


## 获取 Scene Utility 内唯一请求 ID。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 大于零的请求 ID；尚未配置时返回 0。
func get_request_id() -> int:
	return _request_id


## 获取请求执行种类。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 与 `GFSceneOperation.Kind` 对应的 int enum。
func get_kind() -> int:
	return _kind


## 获取请求冻结的资源身份副本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 隔离的 GFResourceIdentity 快照；尚未配置时返回 null。
func get_scene_identity() -> GFResourceIdentity:
	return _scene_identity.duplicate_identity() if _scene_identity != null else null


## 获取成功完成的 PackedScene。
##
## PackedScene 是 Broker 或缓存交付的规范资源引用；结果副本共享该资源，不复制资源内容。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return `COMPLETED` 时返回场景资源；其它终态返回 null。
func get_scene() -> PackedScene:
	return _scene


## 获取闭合终态原因。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 当前 status 允许的 `REASON_*` 常量之一。
func get_reason() -> StringName:
	return _reason


## 获取终态 Error 码。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return `COMPLETED` 为 OK；其它 status 为与 reason 对应的非 OK 码。
func get_error_code() -> Error:
	return _error_code


## 创建隔离的结果 value 副本。
##
## 资源身份会深复制，PackedScene 保持规范共享引用。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 新结果对象。
func duplicate_result() -> GFSceneOperationResult:
	var copy: GFSceneOperationResult = GFSceneOperationResult.new()
	if _configured:
		var _configured_copy: bool = copy.configure_for_framework(
			_status,
			_request_id,
			_kind,
			_scene_identity,
			_scene,
			_reason,
			_error_code
		)
	return copy


## 转换为闭合诊断字典。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 请求身份、种类、终态、可选场景与错误信息。
## [br]
## @schema return: Exact Dictionary with status: int enum, successful: bool, request_id: int, kind: int enum, scene_identity: Dictionary, scene: PackedScene or null, has_scene: bool, reason: StringName, and error_code: int fields.
func to_dict() -> Dictionary:
	return {
		"status": int(_status),
		"successful": is_successful(),
		"request_id": _request_id,
		"kind": _kind,
		"scene_identity": (
			_scene_identity.to_dictionary()
			if _scene_identity != null
			else {}
		),
		"scene": _scene,
		"has_scene": _scene != null,
		"reason": _reason,
		"error_code": int(_error_code),
	}


# --- 框架内部方法 ---

## 由 Scene Utility 一次性冻结闭合终态。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/scene
## [br]
## @since unreleased
## [br]
## @param status: 请求唯一 caller 终态。
## [br]
## @param request_id: Utility 内唯一且大于零的请求 ID。
## [br]
## @param kind: 与 `GFSceneOperation.Kind` 对应的 int enum。
## [br]
## @param scene_identity: 请求冻结的资源身份。
## [br]
## @param scene: 仅 `COMPLETED` 必须携带的 PackedScene。
## [br]
## @param reason: 当前 status 允许的 `REASON_*` 常量。
## [br]
## @param error_code: 与 status/reason 精确匹配的 Error。
## [br]
## @return 首次完整配置闭合联合成功返回 true。
func configure_for_framework(
	status: Status,
	request_id: int,
	kind: int,
	scene_identity: GFResourceIdentity,
	scene: PackedScene,
	reason: StringName,
	error_code: Error
) -> bool:
	if (
		_configured
		or request_id <= 0
		or not Status.values().has(int(status))
		or kind not in [_KIND_LOAD, _KIND_PRELOAD]
		or scene_identity == null
		or not _terminal_union_is_valid(status, kind, scene, reason, error_code)
	):
		return false
	_status = status
	_request_id = request_id
	_kind = kind
	_scene_identity = scene_identity.duplicate_identity()
	_scene = scene
	_reason = reason
	_error_code = error_code
	_configured = true
	return true


## 检查结果是否已由 Scene Utility 完整配置。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/scene
## [br]
## @since unreleased
## [br]
## @return closed union 已冻结时返回 true。
func is_configured_for_framework() -> bool:
	return _configured


# --- 私有/辅助方法 ---

static func _terminal_union_is_valid(
	status: Status,
	kind: int,
	scene: PackedScene,
	reason: StringName,
	error_code: Error
) -> bool:
	match status:
		Status.COMPLETED:
			return (
				scene != null
				and error_code == OK
				and (
					(kind == _KIND_LOAD and reason == REASON_SCENE_LOADED)
					or (
						kind == _KIND_PRELOAD
						and reason in [REASON_SCENE_PRELOADED, REASON_CACHE_HIT]
					)
				)
			)
		Status.REJECTED:
			if scene != null or error_code == OK:
				return false
			match reason:
				REASON_INVALID_PATH:
					return error_code == ERR_INVALID_PARAMETER
				REASON_OWNER_UNAVAILABLE:
					return error_code == ERR_UNAVAILABLE
				REASON_LOAD_BUSY:
					return kind == _KIND_LOAD and error_code == ERR_BUSY
				REASON_BROKER_REJECTED:
					return true
		Status.FAILED:
			if scene != null or error_code == OK:
				return false
			match reason:
				REASON_RESOURCE_LOAD_FAILED:
					return error_code == ERR_CANT_OPEN
				REASON_RESOURCE_TYPE_MISMATCH:
					return error_code == ERR_INVALID_DATA
				REASON_SCENE_CHANGE_FAILED:
					return kind == _KIND_LOAD and error_code == ERR_CANT_CREATE
		Status.CANCELLED:
			return (
				scene == null
				and error_code == ERR_SKIP
				and reason in [
					REASON_CALLER_CANCELLED,
					REASON_TOKEN_CANCELLED,
					REASON_OWNER_RELEASED,
					REASON_PATH_CANCELLED,
					REASON_EXTERNAL_CANCELLED,
					REASON_BROKER_DISPOSED,
					REASON_BROKER_CANCELLED,
				]
			)
		Status.DISPOSED:
			return (
				scene == null
				and reason == REASON_UTILITY_DISPOSED
				and error_code == ERR_UNAVAILABLE
			)
	return false
