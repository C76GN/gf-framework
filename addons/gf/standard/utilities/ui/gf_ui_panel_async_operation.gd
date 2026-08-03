## GFUIPanelAsyncOperation: 单次异步 UI 面板请求的可观察句柄。
##
## 句柄冻结 UI 分配的请求序号、路径、层级与操作类型，并且只接受一个终态。
## 成功面板仅以弱引用保存，句柄不会延长面板节点的生命周期。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since unreleased
class_name GFUIPanelAsyncOperation
extends RefCounted


# --- 信号 ---

## 请求进入终态时发出一次。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param handle: 已完成的当前句柄。
signal completed(handle: GFUIPanelAsyncOperation)


# --- 常量 ---

## 请求尚未进入终态时由 get_status() 返回的状态。
## [br]
## @api public
## [br]
## @since unreleased
const STATUS_PENDING: int = -1

## 压入面板操作。
## [br]
## @api public
## [br]
## @since unreleased
const OPERATION_PUSH: StringName = &"push"

## 替换层级操作。
## [br]
## @api public
## [br]
## @since unreleased
const OPERATION_REPLACE: StringName = &"replace"
const _STATUS_OPENED: int = 0
const _STATUS_FAILED: int = 1
const _STATUS_CANCELLED: int = 2


# --- 私有变量 ---

var _serial: int = 0
var _path: String = ""
var _layer: int = -1
var _operation: StringName = &""
var _status: int = STATUS_PENDING
var _panel_reference: WeakRef = null
var _configured: bool = false


# --- 公共方法 ---

## 获取 UI 分配的请求序号。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 配置后为大于零的请求序号；未配置时为 0。
func get_serial() -> int:
	return _serial


## 获取面板场景路径。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 请求创建时冻结的场景路径。
func get_path() -> String:
	return _path


## 获取目标 UI 层级。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 请求创建时冻结的逻辑层 ID。
func get_layer() -> int:
	return _layer


## 获取 push 或 replace 操作。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: `OPERATION_*` 常量之一。
func get_operation() -> StringName:
	return _operation


## 检查请求是否仍在等待终态。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 已配置且尚未完成时返回 true。
func is_pending() -> bool:
	return _configured and _status == STATUS_PENDING


## 检查请求是否已有终态。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 已完成时返回 true。
func is_completed() -> bool:
	return _configured and _status != STATUS_PENDING


## 获取请求状态。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 等待中返回 STATUS_PENDING；完成后返回 GFUIUtility.AsyncPanelLoadStatus。
func get_status() -> int:
	return _status


## 获取成功打开的面板。
##
## 句柄只保存弱引用；面板已释放、请求失败或请求取消时返回 null。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 当前仍有效的成功面板；否则返回 null。
func get_panel() -> Node:
	if _panel_reference == null:
		return null
	var panel_value: Variant = _panel_reference.get_ref()
	if panel_value is Node:
		var panel: Node = panel_value
		return panel
	return null


## 获取稳定调试快照。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 请求身份与终态摘要。
## [br]
## @schema return: Dictionary，包含 serial、path、layer、operation、pending、completed、status、has_panel 和 panel_instance_id。
func get_debug_snapshot() -> Dictionary:
	var panel: Node = get_panel()
	return {
		"serial": _serial,
		"path": _path,
		"layer": _layer,
		"operation": String(_operation),
		"pending": is_pending(),
		"completed": is_completed(),
		"status": _status,
		"has_panel": panel != null,
		"panel_instance_id": panel.get_instance_id() if panel != null else 0,
	}


# --- 框架内部方法 ---

## 由 GFUIUtility 初始化请求身份。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param serial: 同一 GFUIUtility 实例内全局单调的请求序号。
## [br]
## @param path: 面板场景路径。
## [br]
## @param layer: 目标逻辑层 ID。
## [br]
## @param operation: push 或 replace。
## [br]
## @return: 首次配置且输入有效时返回 true。
func configure_for_framework(
	serial: int,
	path: String,
	layer: int,
	operation: StringName
) -> bool:
	if _configured or serial <= 0:
		return false
	if operation not in [OPERATION_PUSH, OPERATION_REPLACE]:
		return false
	_serial = serial
	_path = path
	_layer = layer
	_operation = operation
	_configured = true
	return true


## 由 GFUIUtility 写入并发出唯一终态。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param status: GFUIUtility.AsyncPanelLoadStatus 终态。
## [br]
## @param panel: 成功打开的面板；失败或取消时为 null。
## [br]
## @return: 首次完成成功返回 true。
func complete_for_framework(status: int, panel: Node) -> bool:
	if not is_pending() or status not in [_STATUS_OPENED, _STATUS_FAILED, _STATUS_CANCELLED]:
		return false
	if status == _STATUS_OPENED and not is_instance_valid(panel):
		return false
	_status = status
	_panel_reference = weakref(panel) if status == _STATUS_OPENED else null
	completed.emit(self)
	return true
