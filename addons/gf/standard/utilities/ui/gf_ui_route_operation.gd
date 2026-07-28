## GFUIRouteOperation: 单次异步路由打开的可观察句柄。
##
## 句柄由 GFUIRouterUtility 分配请求身份并只接受一个终态。相同 pending 路由
## 会返回同一句柄，调用方无需自行按路径合并请求。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 10.0.0
class_name GFUIRouteOperation
extends RefCounted


# --- 信号 ---

## 路由请求进入终态时发出一次。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param result: 与当前请求 ID 匹配的隔离结果。
signal completed(result: GFUIRouteResult)


# --- 常量 ---

## 压入路由操作。
## [br]
## @api public
## [br]
## @since 10.0.0
const OPERATION_PUSH: StringName = &"push"

## 替换路由操作。
## [br]
## @api public
## [br]
## @since 10.0.0
const OPERATION_REPLACE: StringName = &"replace"


# --- 私有变量 ---

var _request_id: int = 0
var _route_id: StringName = &""
var _operation: StringName = &""
var _preload_policy: StringName = &""
var _started_at_msec: int = 0
var _preload_session: GFAssetLoadSession = null
var _result: GFUIRouteResult = null


# --- 公共方法 ---

## 获取 Router 内唯一请求 ID。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 大于零的请求 ID。
func get_request_id() -> int:
	return _request_id


## 获取规范化路由 ID。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 当前请求路由 ID。
func get_route_id() -> StringName:
	return _route_id


## 获取 push 或 replace 操作。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return `OPERATION_*` 常量之一。
func get_operation() -> StringName:
	return _operation


## 获取请求预加载策略。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return Router 接受或拒绝的策略标识。
func get_preload_policy() -> StringName:
	return _preload_policy


## 获取请求开始时间。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 单调时钟毫秒值。
func get_started_at_msec() -> int:
	return _started_at_msec


## 检查请求是否仍在等待终态。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 已配置且未完成时返回 true。
func is_pending() -> bool:
	return _request_id > 0 and _result == null


## 检查请求是否已有终态。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 已完成时返回 true。
func is_completed() -> bool:
	return _result != null


## 获取当前预加载会话。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 已启动的会话；未启用或尚未启动时返回 null。
func get_preload_session() -> GFAssetLoadSession:
	return _preload_session


## 获取终态结果副本。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 已完成结果；等待中返回 null。
func get_result() -> GFUIRouteResult:
	return _result.duplicate_result() if _result != null else null


## 获取稳定调试快照。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 请求身份、pending 状态、预加载会话和终态摘要。
## [br]
## @schema return: Dictionary with request_id, route_id, operation, preload_policy, started_at_msec, pending, completed, preload_session_id, and result.
func get_debug_snapshot() -> Dictionary:
	return {
		"request_id": _request_id,
		"route_id": String(_route_id),
		"operation": String(_operation),
		"preload_policy": String(_preload_policy),
		"started_at_msec": _started_at_msec,
		"pending": is_pending(),
		"completed": is_completed(),
		"preload_session_id": String(_preload_session.get_session_id()) if _preload_session != null else "",
		"result": _result.to_dict() if _result != null else {},
	}


# --- 框架内部方法 ---

## 由 UI Router 初始化请求身份。
## [br]
## @api framework_internal
## [br]
## @since 10.0.0
## [br]
## @param request_id: Router 内唯一请求 ID。
## [br]
## @param route_id: 规范化路由 ID。
## [br]
## @param operation: push 或 replace。
## [br]
## @param preload_policy: 请求预加载策略。
## [br]
## @param started_at_msec: 请求开始单调时间。
## [br]
## @return 首次配置且输入有效时返回 true。
func configure_for_framework(
	request_id: int,
	route_id: StringName,
	operation: StringName,
	preload_policy: StringName,
	started_at_msec: int
) -> bool:
	if _request_id != 0 or request_id <= 0:
		return false
	if operation not in [OPERATION_PUSH, OPERATION_REPLACE]:
		return false
	_request_id = request_id
	_route_id = route_id
	_operation = operation
	_preload_policy = preload_policy
	_started_at_msec = maxi(started_at_msec, 0)
	return true


## 由 UI Router 关联预加载事务。
## [br]
## @api framework_internal
## [br]
## @since 10.0.0
## [br]
## @param session: 已启动的资产预加载会话。
## [br]
## @return 首次关联成功返回 true。
func attach_preload_session_for_framework(session: GFAssetLoadSession) -> bool:
	if not is_pending() or session == null or _preload_session != null:
		return false
	_preload_session = session
	return true


## 由 UI Router 写入并发出唯一终态。
## [br]
## @api framework_internal
## [br]
## @since 10.0.0
## [br]
## @param result: 与当前请求身份一致的结果。
## [br]
## @return 首次完成成功返回 true。
func complete_for_framework(result: GFUIRouteResult) -> bool:
	if not is_pending() or result == null:
		return false
	if (
		result.get_request_id() != _request_id
		or result.get_route_id() != _route_id
		or result.get_operation() != _operation
	):
		return false
	_result = result.duplicate_result()
	completed.emit(_result.duplicate_result())
	return true
