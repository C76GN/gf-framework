## GFUIRouteResult: UI 路由异步打开的不可变终态。
##
## 结果把路由校验、可选预加载、面板提交和生命周期中止统一为稳定状态，
## 并保留预加载事务结果，避免项目通过日志或时序猜测失败阶段。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 10.0.0
class_name GFUIRouteResult
extends RefCounted


# --- 常量 ---

## 面板已进入目标 UI 栈。
## [br]
## @api public
## [br]
## @since 10.0.0
const STATUS_OPENED: StringName = &"opened"

## 路由不存在。
## [br]
## @api public
## [br]
## @since 10.0.0
const STATUS_MISSING_ROUTE: StringName = &"missing_route"

## 路由资源无效。
## [br]
## @api public
## [br]
## @since 10.0.0
const STATUS_INVALID_ROUTE: StringName = &"invalid_route"

## Router 无法获取 UI Utility。
## [br]
## @api public
## [br]
## @since 10.0.0
const STATUS_MISSING_UI_UTILITY: StringName = &"missing_ui_utility"

## 路由目标逻辑层未注册。
## [br]
## @api public
## [br]
## @since 10.0.0
const STATUS_MISSING_UI_LAYER: StringName = &"missing_ui_layer"

## 同一路径、层级和操作已有不同路由请求。
## [br]
## @api public
## [br]
## @since 10.0.0
const STATUS_ASYNC_CONFLICT: StringName = &"async_conflict"

## 预加载策略不受支持。
## [br]
## @api public
## [br]
## @since 10.0.0
const STATUS_INVALID_PRELOAD_POLICY: StringName = &"invalid_preload_policy"

## 请求 owner 或异步作用域不满足生命周期契约。
## [br]
## @api public
## [br]
## @since 11.0.0
const STATUS_INVALID_LIFECYCLE: StringName = &"invalid_lifecycle"

## 预加载策略需要 Asset Utility，但当前架构未提供。
## [br]
## @api public
## [br]
## @since 10.0.0
const STATUS_MISSING_ASSET_UTILITY: StringName = &"missing_asset_utility"

## 无法构建满足策略要求的预加载计划。
## [br]
## @api public
## [br]
## @since 10.0.0
const STATUS_PRELOAD_PLAN_FAILED: StringName = &"preload_plan_failed"

## 资产预加载事务失败或回滚。
## [br]
## @api public
## [br]
## @since 10.0.0
const STATUS_PRELOAD_FAILED: StringName = &"preload_failed"

## 面板资源加载、实例化或入栈失败。
## [br]
## @api public
## [br]
## @since 10.0.0
const STATUS_PANEL_FAILED: StringName = &"panel_failed"

## 请求在面板提交前因 owner/scope 结束，或在提交后被底层 UI 取消。
## [br]
## @api public
## [br]
## @since 10.0.0
const STATUS_CANCELLED: StringName = &"cancelled"

## Router 在面板提交前释放，结果确定为未打开。
## [br]
## @api public
## [br]
## @since 10.0.0
const STATUS_DISPOSED: StringName = &"disposed"

## Router 在面板提交后释放，无法再可靠观察底层终态。
## [br]
## @api public
## [br]
## @since 10.0.0
const STATUS_OUTCOME_UNKNOWN: StringName = &"outcome_unknown"


# --- 私有变量 ---

var _request_id: int = 0
var _route_id: StringName = &""
var _operation: StringName = &""
var _status: StringName = &""
var _reason: StringName = &""
var _layer: int = -1
var _panel_ref: WeakRef = null
var _preload_policy: StringName = &""
var _preload_attempted: bool = false
var _preload_successful: bool = false
var _preload_plan_report: Dictionary = {}
var _preload_result: GFAssetLoadSessionResult = null
var _started_at_msec: int = 0
var _completed_at_msec: int = 0
var _metadata: Dictionary = {}


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
## @return 本次请求的路由 ID。
func get_route_id() -> StringName:
	return _route_id


## 获取路由操作。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return `GFUIRouteOperation.OPERATION_*` 常量之一。
func get_operation() -> StringName:
	return _operation


## 获取终态状态。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return `STATUS_*` 常量之一。
func get_status() -> StringName:
	return _status


## 检查路由是否成功打开。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 面板已进入目标 UI 栈时返回 true。
func is_successful() -> bool:
	return _status == STATUS_OPENED


## 获取稳定原因码。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 失败或尽力预加载降级原因；无原因时为空。
func get_reason() -> StringName:
	return _reason


## 获取目标逻辑层。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 有效路由的目标层；路由解析前失败时为 -1。
func get_layer() -> int:
	return _layer


## 获取仍存活的面板实例。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 成功面板；失败或面板已释放时返回 null。
func get_panel() -> Node:
	if _panel_ref == null:
		return null
	var value: Object = _panel_ref.get_ref()
	if value is Node and is_instance_valid(value):
		var panel: Node = value
		return panel
	return null


## 获取本次请求的预加载策略。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return Router 接受或拒绝的策略标识。
func get_preload_policy() -> StringName:
	return _preload_policy


## 检查是否实际启动过资产预加载事务。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 已创建并启动预加载会话时返回 true。
func was_preload_attempted() -> bool:
	return _preload_attempted


## 检查预加载事务是否成功提交。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 会话进入 committed 终态时返回 true。
func was_preload_successful() -> bool:
	return _preload_successful


## 获取 JSON 安全的预加载规划报告副本。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 不包含 Resource 实例的规划摘要。
## [br]
## @schema return: Dictionary with bounded route preload diagnostics and optional asset_plan_description.
func get_preload_plan_report() -> Dictionary:
	return _preload_plan_report.duplicate(true)


## 获取资产预加载事务结果副本。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 已完成会话的结果；未启动或尚未完成时返回 null。
func get_preload_result() -> GFAssetLoadSessionResult:
	return _preload_result.duplicate_result() if _preload_result != null else null


## 获取请求开始时间。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 单调时钟毫秒值。
func get_started_at_msec() -> int:
	return _started_at_msec


## 获取请求完成时间。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 单调时钟毫秒值。
func get_completed_at_msec() -> int:
	return _completed_at_msec


## 获取请求持续时间。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 非负毫秒数。
func get_duration_msec() -> int:
	return maxi(_completed_at_msec - _started_at_msec, 0)


## 获取调用方元数据副本。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return `async_options.metadata` 的隔离副本。
## [br]
## @schema return: Dictionary caller-defined route operation metadata.
func get_metadata() -> Dictionary:
	return _metadata.duplicate(true)


## 创建隔离结果副本。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 新结果对象。
func duplicate_result() -> GFUIRouteResult:
	var copy: GFUIRouteResult = GFUIRouteResult.new()
	var _configured: bool = copy.configure_for_framework(
		_request_id,
		_route_id,
		_operation,
		_status,
		_reason,
		_layer,
		get_panel(),
		_preload_policy,
		_preload_attempted,
		_preload_successful,
		_preload_plan_report,
		_preload_result,
		_started_at_msec,
		_completed_at_msec,
		_metadata
	)
	return copy


## 转换为可序列化诊断字典。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 请求身份、终态、预加载摘要和持续时间。
## [br]
## @schema return: Dictionary with request_id, route_id, operation, status, ok, reason, layer, panel_instance_id, preload_policy, preload_attempted, preload_successful, preload_plan_report, preload_result, started_at_msec, completed_at_msec, duration_msec, and metadata.
func to_dict() -> Dictionary:
	var panel: Node = get_panel()
	var raw_result: Dictionary = {
		"request_id": _request_id,
		"route_id": String(_route_id),
		"operation": String(_operation),
		"status": String(_status),
		"ok": is_successful(),
		"reason": String(_reason),
		"layer": _layer,
		"panel_instance_id": panel.get_instance_id() if panel != null else 0,
		"preload_policy": String(_preload_policy),
		"preload_attempted": _preload_attempted,
		"preload_successful": _preload_successful,
		"preload_plan_report": _preload_plan_report.duplicate(true),
		"preload_result": _preload_result.to_dict() if _preload_result != null else {},
		"started_at_msec": _started_at_msec,
		"completed_at_msec": _completed_at_msec,
		"duration_msec": get_duration_msec(),
		"metadata": _metadata.duplicate(true),
	}
	return GFReportValueCodec.to_report_dictionary(raw_result)


# --- 框架内部方法 ---

## 由 UI Router 写入唯一终态。
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
## @param status: `STATUS_*` 常量之一。
## [br]
## @param reason: 稳定原因码。
## [br]
## @param layer: 目标逻辑层。
## [br]
## @param panel: 可选成功面板。
## [br]
## @param preload_policy: 请求预加载策略。
## [br]
## @param preload_attempted: 是否启动会话。
## [br]
## @param preload_successful: 会话是否提交。
## [br]
## @param preload_plan_report: JSON 安全规划报告。
## [br]
## @schema preload_plan_report: Dictionary with bounded route preload diagnostics and no Object values.
## [br]
## @param preload_result: 可选资产会话结果。
## [br]
## @param started_at_msec: 请求开始单调时间。
## [br]
## @param completed_at_msec: 请求完成单调时间。
## [br]
## @param metadata: 调用方元数据。
## [br]
## @schema metadata: Dictionary caller-defined route operation metadata.
## [br]
## @return 首次配置且输入有效时返回 true。
func configure_for_framework(
	request_id: int,
	route_id: StringName,
	operation: StringName,
	status: StringName,
	reason: StringName,
	layer: int,
	panel: Node,
	preload_policy: StringName,
	preload_attempted: bool,
	preload_successful: bool,
	preload_plan_report: Dictionary,
	preload_result: GFAssetLoadSessionResult,
	started_at_msec: int,
	completed_at_msec: int,
	metadata: Dictionary
) -> bool:
	if _request_id != 0 or request_id <= 0:
		return false
	if operation not in [&"push", &"replace"]:
		return false
	if not _is_valid_status(status) or completed_at_msec < started_at_msec:
		return false
	_request_id = request_id
	_route_id = route_id
	_operation = operation
	_status = status
	_reason = reason
	_layer = layer
	_panel_ref = weakref(panel) if panel != null else null
	_preload_policy = preload_policy
	_preload_attempted = preload_attempted
	_preload_successful = preload_attempted and preload_successful
	_preload_plan_report = preload_plan_report.duplicate(true)
	_preload_result = preload_result.duplicate_result() if preload_result != null else null
	_started_at_msec = started_at_msec
	_completed_at_msec = completed_at_msec
	_metadata = metadata.duplicate(true)
	return true


# --- 私有/辅助方法 ---

static func _is_valid_status(status: StringName) -> bool:
	return status in [
		STATUS_OPENED,
		STATUS_MISSING_ROUTE,
		STATUS_INVALID_ROUTE,
		STATUS_MISSING_UI_UTILITY,
		STATUS_MISSING_UI_LAYER,
		STATUS_ASYNC_CONFLICT,
		STATUS_INVALID_PRELOAD_POLICY,
		STATUS_INVALID_LIFECYCLE,
		STATUS_MISSING_ASSET_UTILITY,
		STATUS_PRELOAD_PLAN_FAILED,
		STATUS_PRELOAD_FAILED,
		STATUS_PANEL_FAILED,
		STATUS_CANCELLED,
		STATUS_DISPOSED,
		STATUS_OUTCOME_UNKNOWN,
	]
