@tool

## 同一原生编辑器历史共享的 Flow 写入门禁与显式重建确认。
## 原生历史强持有状态，状态弱引用原生 owner；真实补偿任务保留到恢复完成。
## [br]
## @api framework_internal
## [br]
## @category internal_helper
class_name GFFlowEditorHistoryState
extends RefCounted


# --- 信号 ---

## 资格或报告变化；页面应撤销旧确认并重新读取状态。
## [br]
## @api framework_internal
signal changed


# --- 常量 ---

## 状态只挂在实际历史对象上，不维护静态强引用目录。
## [br]
## @api private
const _META_KEY: StringName = &"_gf_flow_editor_history_state"


# --- 私有变量 ---

## 原生管理器的弱身份；关闭编辑器 owner 后不延长其生命周期。
## [br]
## @api private
var _manager_ref: WeakRef = null

## 实际 UndoRedo 的弱身份；历史本身通过 metadata 持有本状态。
## [br]
## @api private
var _history_ref: WeakRef = null

## 明确清除的原生历史 ID；绝不使用 clear_history 的全部历史默认参数。
## [br]
## @api private
var _history_id: int = EditorUndoRedoManager.INVALID_HISTORY

## 单调资格代次；原生版本和游标可能往返，不能独立授权旧确认。
## [br]
## @api private
var _epoch: int = 0

## 已绑定原生命令出现失败，历史位置不能代表资源已成功写入或撤销。
## [br]
## @api private
var _desynchronized: bool = false

## 真实未完成补偿的命令；命令只弱引用状态，避免 RefCounted 环。
## [br]
## @api private
var _recovery_commands: Array[GFFlowGraphEditCommand] = []

## 原生失败回调仍可能尚未移动游标，延后一轮开放确认。
## [br]
## @api private
var _settling: bool = false

## 确认清除过程中阻止同步回调重入 Flow 写入或再次清除。
## [br]
## @api private
var _resetting: bool = false

## 确认完成通知只保留一次待派发回调，不在清除函数尾部重新开放同步操作栈。
## [br]
## @api private
var _completion_notification_pending: bool = false

## 已排队完成状态的代次；较新的原生事件已通知时跳过旧完成通知。
## [br]
## @api private
var _completion_notification_epoch: int = -1


# --- 框架内部方法 ---

## 获取实际原生历史上唯一的共享状态；不执行项目图查询或资源写入。
## [br]
## @api framework_internal
## [br]
## @param manager: 实际 EditorUndoRedoManager，不消费兼容对象的猜测协议。
## [br]
## @param graph: 本次编辑的真实资源历史上下文。
## [br]
## @return: 同历史共享状态；owner、历史或既有 metadata 不满足资格时为 null。
static func acquire(manager: EditorUndoRedoManager, graph: GFFlowGraph) -> GFFlowEditorHistoryState:
	if not is_instance_valid(manager) or not is_instance_valid(graph):
		return null
	var history_id: int = manager.get_object_history_id(graph)
	if history_id == EditorUndoRedoManager.INVALID_HISTORY:
		return null
	var history: UndoRedo = manager.get_history_undo_redo(history_id)
	if not is_instance_valid(history):
		return null
	if history.has_meta(_META_KEY):
		var value: Variant = history.get_meta(_META_KEY)
		if value is GFFlowEditorHistoryState:
			var existing: GFFlowEditorHistoryState = value
			if existing._matches_owner(manager, history, history_id):
				return existing
		return null
	if manager.is_committing_action():
		return null
	var state: GFFlowEditorHistoryState = GFFlowEditorHistoryState.new()
	state._manager_ref = weakref(manager)
	state._history_ref = weakref(history)
	state._history_id = history_id
	var history_error: int = history.version_changed.connect(state._on_native_history_changed)
	if history_error != OK:
		return null
	var manager_error: int = manager.history_changed.connect(state._on_native_history_changed)
	if manager_error != OK:
		history.version_changed.disconnect(state._on_native_history_changed)
		return null
	history.set_meta(_META_KEY, state)
	return state


## 检查同一历史中的 Flow 写入是否暂停；不影响其它编辑器工具的原生操作。
## [br]
## @api framework_internal
## [br]
## @return: 失配、真实补偿任务或正在清除时为 true。
func is_blocked() -> bool:
	return _desynchronized or not _recovery_commands.is_empty() or _resetting


## 返回持续的页面资格与清除范围；读取本身不清除历史。
## [br]
## @api framework_internal
## [br]
## @return: 独立状态值。
## [br]
## @schema return: Dictionary，固定 supported、blocked、desynchronized、compensation_required、can_reset、busy: bool，history_id: int，scope: StringName（global/scene/remote/unavailable），summary: String。
func get_status() -> Dictionary:
	var supported: bool = _has_live_owner()
	return {
		"supported": supported, "blocked": is_blocked(),
		"desynchronized": _desynchronized,
		"compensation_required": not _recovery_commands.is_empty(),
		"can_reset": _can_reset(), "busy": _resetting or _settling or (supported and (_get_manager().is_committing_action() or _get_history().is_committing_action())),
		"history_id": _history_id, "scope": _scope() if supported else &"unavailable",
		"summary": _summary(supported),
	}


## 保留可达的真实补偿入口，跨页面恢复时使用命令自己的资源上下文。
## [br]
## @api framework_internal
## [br]
## @return: 第一个仍需补偿的实际命令；没有任务时为 null。
func get_recovery_command() -> GFFlowGraphEditCommand:
	return _recovery_commands[0] if not _recovery_commands.is_empty() else null


## 捕获一次明确确认的历史资格；页面另外绑定自己的图、上下文及可见性代次。
## [br]
## @api framework_internal
## [br]
## @return: 只包含身份和有界标量，不持有图资源或页面。
## [br]
## @schema return: 成功 Dictionary 固定 ok: true，guard_id、manager_id、history_object_id、history_id、epoch、version、cursor、count: int；失败固定 ok: false、error: int（Error）、reason: StringName。
func capture_reset_token() -> Dictionary:
	if not _can_reset():
		return {"ok": false, "error": ERR_UNAVAILABLE, "reason": &"reset_unavailable"}
	var manager: EditorUndoRedoManager = _get_manager()
	var history: UndoRedo = _get_history()
	return {
		"ok": true, "guard_id": get_instance_id(), "manager_id": manager.get_instance_id(),
		"history_object_id": history.get_instance_id(), "history_id": _history_id,
		"epoch": _epoch, "version": history.get_version(),
		"cursor": history.get_current_action(), "count": history.get_history_count(),
	}


## 消费确认后只清除实际指定历史；不保存或改写资源，不执行旧动作的撤销。
## 清除同步信号中其它工具仍可能变更原生历史；后置条件失败时保持失配门禁。
## [br]
## @api framework_internal
## [br]
## @param token: capture_reset_token 返回的原始完整成功快照。
## [br]
## @schema token: 同 capture_reset_token 的成功结果，所有 int 字段必须与当前身份、代次和原生历史相等。
## [br]
## @return: 清除是否完成与实际门禁结果；history_cleared 只报告后置空历史，不承诺原子回滚原生或项目回调。
## [br]
## @schema return: Dictionary，固定 ok: bool、error: int（Error）、reason: StringName、history_id: int、scope: StringName、history_cleared: bool、blocked: bool。
func confirm_reset(token: Dictionary) -> Dictionary:
	if not _can_reset() or not _token_matches(token):
		return _reset_result(false, ERR_BUSY, &"confirmation_stale", false)
	var manager: EditorUndoRedoManager = _get_manager()
	var history: UndoRedo = _get_history()
	var admitted_version: int = history.get_version()
	var admitted_cursor: int = history.get_current_action()
	var admitted_count: int = history.get_history_count()
	var admitted_epoch: int = _epoch + 1
	_resetting = true
	_epoch += 1
	if not _matches_owner(manager, history, _history_id) or _epoch != admitted_epoch or not _recovery_commands.is_empty() or manager.is_committing_action() or history.is_committing_action() or history.get_version() != admitted_version or history.get_current_action() != admitted_cursor or history.get_history_count() != admitted_count:
		_resetting = false
		_queue_completion_notification()
		return _reset_result(false, ERR_BUSY, &"confirmation_stale", false)
	# true 不把仍未写磁盘的内存版本冒充“已保存”。不使用清除全部历史的默认 ID。
	manager.clear_history(_history_id, true)
	var cleared: bool = _matches_owner(manager, history, _history_id) and history.get_history_count() == 0 and history.get_current_action() == -1 and not history.has_undo() and not history.has_redo()
	_resetting = false
	if cleared and _recovery_commands.is_empty():
		_desynchronized = false
	_queue_completion_notification()
	if cleared and not is_blocked():
		return _reset_result(true, OK, &"rebuilt", true)
	return _reset_result(false, ERR_BUSY, &"postcondition_failed", cleared)


## 命令基类已更新错误缓存后记录实际结果；失败即暂停同历史 Flow 写入。
## [br]
## @api framework_internal
## [br]
## @param command: 已绑定本历史的命令；命令只弱引用本状态。
## [br]
## @param result: 实际 get_flow_edit_result 返回值，不制造补偿任务。
## [br]
## @schema result: 同 GFFlowGraphEditCommand.get_flow_edit_result 的固定结果；transaction 为真实 Batch 报告。
func record_command_result(command: GFFlowGraphEditCommand, result: Dictionary) -> void:
	if command == null:
		return
	var transaction: Dictionary = GFVariantData.get_option_dictionary(result, "transaction")
	var requires_recovery: bool = GFVariantData.get_option_bool(transaction, "recovery_required")
	if requires_recovery and not _recovery_commands.has(command):
		_recovery_commands.append(command)
	elif not requires_recovery:
		_recovery_commands.erase(command)
	var operation: StringName = GFVariantData.get_option_string_name(result, "operation")
	if not GFVariantData.get_option_bool(result, "ok") and operation in [&"execute", &"revert"]:
		_desynchronized = true
		if not _settling:
			_settling = true
			_finish_settling.call_deferred()
	_epoch += 1
	changed.emit()


# --- 私有/辅助方法 ---

## 读取仍存活的原生管理器。
## [br]
## @api private
func _get_manager() -> EditorUndoRedoManager:
	var value: Variant = _manager_ref.get_ref() if _manager_ref != null else null
	if value is EditorUndoRedoManager and is_instance_valid(value):
		return value
	return null


## 读取仍存活的实际原生历史。
## [br]
## @api private
func _get_history() -> UndoRedo:
	var value: Variant = _history_ref.get_ref() if _history_ref != null else null
	if value is UndoRedo and is_instance_valid(value):
		return value
	return null


## 核对拥有关系，不以相同数值 ID 替代原生历史对象身份。
## [br]
## @api private
func _matches_owner(manager: EditorUndoRedoManager, history: UndoRedo, history_id: int) -> bool:
	return is_instance_valid(manager) and is_instance_valid(history) and manager == _get_manager() and history == _get_history() and history_id == _history_id and manager.get_history_undo_redo(history_id) == history


## 检查确认是否拥有仍有效的原生历史。
## [br]
## @api private
func _has_live_owner() -> bool:
	return _matches_owner(_get_manager(), _get_history(), _history_id)


## 确认前拒绝真实补偿、失败回调尚未返回或原生提交过程。
## [br]
## @api private
func _can_reset() -> bool:
	return _desynchronized and _recovery_commands.is_empty() and not _resetting and not _settling and _has_live_owner() and not _get_manager().is_committing_action() and not _get_history().is_committing_action()


## 只消费完整的原始快照；不把字符串、浮点或未知字段转换成授权。
## [br]
## @api private
func _token_matches(token: Dictionary) -> bool:
	if token.size() != 9 or not token.get("ok") is bool or token.get("ok") != true:
		return false
	for key: String in ["guard_id", "manager_id", "history_object_id", "history_id", "epoch", "version", "cursor", "count"]:
		if not token.get(key) is int:
			return false
	var current: Dictionary = capture_reset_token()
	return current == token


## 失配提示按实际历史范围显示，不声称每份图资源有专属历史。
## [br]
## @api private
func _scope() -> StringName:
	if _history_id == EditorUndoRedoManager.GLOBAL_HISTORY:
		return &"global"
	if _history_id == EditorUndoRedoManager.REMOTE_HISTORY:
		return &"remote"
	return &"scene"


## 提供独立且持续的用户提示，不以最近一次成功操作覆盖门禁状态。
## [br]
## @api private
func _summary(supported: bool) -> String:
	if not _recovery_commands.is_empty():
		return "有未完成的属性补偿，请先恢复编辑；清除撤销历史不能恢复资源值。"
	if not supported:
		return "原生撤销历史已不可用，不能清除或重建该历史。"
	if _resetting or _settling:
		return "原生撤销操作尚在处理中，请稍后重新确认。"
	if _desynchronized:
		return "撤销历史与资源状态不一致，Flow 图写入已暂停；可保留当前值并明确重建实际共享历史。"
	return "当前原生撤销历史可正常使用。"


## 保留清除的实际结果，不把原生同步回调失败冒充可回滚事务。
## [br]
## @api private
func _reset_result(ok: bool, error: Error, reason: StringName, cleared: bool) -> Dictionary:
	return {"ok": ok, "error": error, "reason": reason, "history_id": _history_id, "scope": _scope(), "history_cleared": cleared, "blocked": is_blocked()}


## 原生失败回调栈退出后只开放确认一次，不自动清除空历史或重试失败。
## [br]
## @api private
func _finish_settling() -> void:
	_settling = false
	_epoch += 1
	changed.emit()


## 合并完成通知，实际返回结果在无外部通知回调的尾段按原生后置条件确定。
## [br]
## @api private
func _queue_completion_notification() -> void:
	_completion_notification_epoch = _epoch
	if _completion_notification_pending:
		return
	_completion_notification_pending = true
	_deliver_completion_notification.call_deferred()


## 确认函数返回后才通知页面；正常后续动作已经通知更新代次时不再派发旧状态。
## [br]
## @api private
func _deliver_completion_notification() -> void:
	_completion_notification_pending = false
	if _completion_notification_epoch != _epoch:
		return
	changed.emit()


# --- 信号处理函数 ---

## 版本/历史事件只撤销确认资格；底层 count 为空不能证明管理器栈已同步。
## [br]
## @api private
func _on_native_history_changed() -> void:
	_epoch += 1
	changed.emit()
