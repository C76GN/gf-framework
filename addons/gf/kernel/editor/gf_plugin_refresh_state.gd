@tool

# 根 EditorPlugin 刷新流程的纯 generation 状态机。
#
# 该脚本不访问 EditorFileSystem、SceneTree 或具体 helper；组合入口负责执行它返回的
# wait/scan/apply/done 动作。这样可在普通 headless GUT 中验证合并、重扫和取消语义。
extends RefCounted


# --- 常量 ---

## 等待当前 EditorFileSystem 扫描完成。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const ACTION_WAIT: StringName = &"wait"

## 启动绑定当前最新 generation 的扫描。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const ACTION_SCAN: StringName = &"scan"

## 应用扫描完成的稳定 generation。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const ACTION_APPLY: StringName = &"apply"

## 当前没有待处理刷新工作。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const ACTION_DONE: StringName = &"done"


# --- 私有变量 ---

var _requested_generation: int = 0
var _scan_generation: int = 0
var _applied_generation: int = 0
var _pending: bool = false
var _waiting_for_existing_scan: bool = false
var _deadline_msec: int = 0


# --- 框架内部方法 ---

## 请求一次刷新，并把请求 generation 单调递增。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param now_msec: 当前单调时钟毫秒值。
## [br]
## @param timeout_msec: 首次请求建立的刷新超时预算。
## [br]
## @return: true 表示调用方需要调度本批次的首次启动回调。
func request(now_msec: int, timeout_msec: int) -> bool:
	_requested_generation += 1
	if _pending:
		return false
	_pending = true
	_deadline_msec = now_msec + maxi(timeout_msec, 1)
	return true


## 决定刷新批次的首个动作。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param existing_scan_active: 进入批次时是否已有文件系统扫描。
## [br]
## @return: 下一步 wait、scan 或 done 动作。
## [br]
## @schema return: Dictionary，包含 kind: StringName 和 generation: int。
func begin(existing_scan_active: bool) -> Dictionary:
	if not _pending:
		return _make_action(ACTION_DONE)
	if existing_scan_active:
		_waiting_for_existing_scan = true
		return _make_action(ACTION_WAIT)
	return _make_scan_action()


## 在文件系统进入空闲状态后决定重扫、应用或结束。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @return: 下一步 scan、apply 或 done 动作。
## [br]
## @schema return: Dictionary，包含 kind: StringName 和 generation: int。
func after_scan_idle() -> Dictionary:
	if not _pending:
		return _make_action(ACTION_DONE)
	if _waiting_for_existing_scan or _requested_generation != _scan_generation:
		return _make_scan_action()
	return _make_action(ACTION_APPLY, _scan_generation)


## 在调用方完成一次 generation 应用后决定重扫或结束。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param generation: 刚完成应用的 generation。
## [br]
## @return: 下一步 scan 或 done 动作。
## [br]
## @schema return: Dictionary，包含 kind: StringName 和 generation: int。
func after_applied(generation: int) -> Dictionary:
	if not _pending:
		return _make_action(ACTION_DONE)
	if generation != _scan_generation:
		return _make_scan_action()
	_applied_generation = generation
	if _requested_generation != generation:
		return _make_scan_action()
	_pending = false
	_scan_generation = 0
	_deadline_msec = 0
	return _make_action(ACTION_DONE, generation)


## 判断当前 pending 批次是否已经用尽超时预算。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param now_msec: 当前单调时钟毫秒值。
## [br]
## @return: 达到或超过 deadline 时为 true。
func is_expired(now_msec: int) -> bool:
	return _pending and now_msec >= _deadline_msec


## 取消 pending 批次并清空所有 generation 状态。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
func cancel() -> void:
	_requested_generation = 0
	_scan_generation = 0
	_applied_generation = 0
	_pending = false
	_waiting_for_existing_scan = false
	_deadline_msec = 0


## 查询是否存在待处理刷新批次。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @return: 存在 pending 批次时为 true。
func is_pending() -> bool:
	return _pending


## 获取当前最新请求 generation。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @return: 最新请求 generation；取消后为 0。
func get_requested_generation() -> int:
	return _requested_generation


## 获取最近成功应用的 generation。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @return: 最近成功应用 generation；尚未应用或取消后为 0。
func get_applied_generation() -> int:
	return _applied_generation


# --- 私有/辅助方法 ---

func _make_scan_action() -> Dictionary:
	_scan_generation = _requested_generation
	_waiting_for_existing_scan = false
	return _make_action(ACTION_SCAN, _scan_generation)


func _make_action(kind: StringName, generation: int = 0) -> Dictionary:
	return {
		"kind": kind,
		"generation": generation,
	}
