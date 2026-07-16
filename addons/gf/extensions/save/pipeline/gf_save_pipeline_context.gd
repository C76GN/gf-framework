## GFSavePipelineContext: 存档图流程上下文。
##
## 在一次 gather/apply 操作中收集通用事件、警告、错误与共享数据。
## 上下文通过调用者传入的 context 字典传播，不要求存档载荷写死任何字段。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 3.17.0
class_name GFSavePipelineContext
extends RefCounted


# --- 公共变量 ---

## 当前操作类型，如 gather 或 apply。
## [br]
## @api public
## [br]
## @since 3.17.0
var operation: StringName = &""

## 根作用域键。
## [br]
## @api public
## [br]
## @since 3.17.0
var root_scope_key: StringName = &""

## 流程共享数据。项目层可写入自己的临时状态。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @schema shared: Dictionary，一次流程中的临时共享字段，不会自动写入存档载荷。
var shared: Dictionary = {}

## 流程事件列表。
## [br]
## @api public
## [br]
## @since 3.17.0
var events: Array[GFSavePipelineEvent] = []

## 通用警告信息。
## [br]
## @api public
## [br]
## @since 3.17.0
var warnings: PackedStringArray = PackedStringArray()

## 通用错误信息。
## [br]
## @api public
## [br]
## @since 3.17.0
var errors: PackedStringArray = PackedStringArray()

## 本次 apply 事务参与者列表。
## [br]
## @api public
## [br]
## @since 8.0.0
var transaction_participants: Array[GFSaveTransactionParticipant] = []

## 开始时间。
## [br]
## @api public
## [br]
## @since 3.17.0
var started_at_msec: int = 0

## 结束时间。
## [br]
## @api public
## [br]
## @since 3.17.0
var finished_at_msec: int = 0


# --- Godot 生命周期方法 ---

func _init(
	p_operation: StringName = &"",
	p_root_scope_key: StringName = &"",
	p_shared: Dictionary = {}
) -> void:
	var _begin_operation_result_67: Variant = begin_operation(p_operation, p_root_scope_key, p_shared)


# --- 公共方法 ---

## 开始一次流程操作。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param p_operation: 操作类型。
## [br]
## @param p_root_scope_key: 根作用域键。
## [br]
## @param p_shared: 初始共享数据。
## [br]
## @return 当前上下文。
## [br]
## @schema p_shared: Dictionary，一次流程中的临时共享字段，不会自动写入存档载荷。
func begin_operation(
	p_operation: StringName,
	p_root_scope_key: StringName = &"",
	p_shared: Dictionary = {}
) -> GFSavePipelineContext:
	operation = p_operation
	root_scope_key = p_root_scope_key
	shared = p_shared.duplicate(true)
	events.clear()
	warnings.clear()
	errors.clear()
	transaction_participants.clear()
	started_at_msec = Time.get_ticks_msec()
	finished_at_msec = 0
	return self


## 记录流程事件。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param stage: 阶段标识。
## [br]
## @param scope: 可选 Scope。
## [br]
## @param source: 可选 Source。
## [br]
## @param message: 调试消息。
## [br]
## @param payload: 附加载荷。
## [br]
## @param severity: 严重级别。
## [br]
## @return 新事件。
## [br]
## @schema payload: Dictionary，项目或流程步骤附加的诊断字段。
func record_event(
	stage: StringName,
	scope: Object = null,
	source: Object = null,
	message: String = "",
	payload: Dictionary = {},
	severity: StringName = &"info"
) -> GFSavePipelineEvent:
	var event: GFSavePipelineEvent = GFSavePipelineEvent.new().configure(stage, scope, source, message, payload, severity)
	events.append(event)
	return event


## 记录警告并同步生成 warning 事件。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param message: 警告内容。
## [br]
## @param payload: 附加载荷。
## [br]
## @schema payload: Dictionary，项目或流程步骤附加的诊断字段。
func add_warning(message: String, payload: Dictionary = {}) -> void:
	var _append_result_143: Variant = warnings.append(message)
	var _record_event_result_144: Variant = record_event(&"pipeline_warning", null, null, message, payload, &"warning")


## 记录错误并同步生成 error 事件。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param message: 错误内容。
## [br]
## @param payload: 附加载荷。
## [br]
## @schema payload: Dictionary，项目或流程步骤附加的诊断字段。
func add_error(message: String, payload: Dictionary = {}) -> void:
	var _append_result_157: Variant = errors.append(message)
	var _record_event_result_158: Variant = record_event(&"pipeline_error", null, null, message, payload, &"error")


## 登记本次 apply 事务参与者。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param participant: 参与 prepare / commit / rollback 的事务对象。
func register_transaction_participant(participant: GFSaveTransactionParticipant) -> void:
	if participant == null or transaction_participants.has(participant):
		return
	transaction_participants.append(participant)


## 注销本次 apply 事务参与者。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param participant: 要注销的事务对象。
func unregister_transaction_participant(participant: GFSaveTransactionParticipant) -> void:
	var index: int = transaction_participants.find(participant)
	if index >= 0:
		transaction_participants.remove_at(index)


## 获取本次 apply 事务参与者副本。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 事务参与者数组。
func get_transaction_participants() -> Array[GFSaveTransactionParticipant]:
	var result: Array[GFSaveTransactionParticipant] = []
	for participant: GFSaveTransactionParticipant in transaction_participants:
		if participant != null:
			result.append(participant)
	return result


## 清空本次 apply 事务参与者。
## [br]
## @api public
## [br]
## @since 8.0.0
func clear_transaction_participants() -> void:
	transaction_participants.clear()


## 标记流程结束。
## [br]
## @api public
## [br]
## @since 3.17.0
func finish() -> void:
	finished_at_msec = Time.get_ticks_msec()


## 当前流程是否已结束。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return 已结束返回 true。
func is_finished() -> bool:
	return finished_at_msec > 0


## 获取耗时毫秒。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return 耗时。
func get_elapsed_msec() -> int:
	var end_msec: int = finished_at_msec if finished_at_msec > 0 else Time.get_ticks_msec()
	return maxi(end_msec - started_at_msec, 0)


## 转换为 Dictionary。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param include_events: 是否包含事件列表。
## [br]
## @return 上下文字典。
## [br]
## @schema return: Dictionary，包含 operation、root_scope_key、JSON-safe shared、warnings、errors、started_at_msec、finished_at_msec、elapsed_msec、event_count；include_events 为 true 时包含 events: Array[Dictionary]。
func to_dict(include_events: bool = true) -> Dictionary:
	var result: Dictionary = {
		"operation": operation,
		"root_scope_key": root_scope_key,
		"shared": GFReportValueCodec.to_report_dictionary(shared, {
			"path_redaction": "basename",
		}),
		"warnings": warnings,
		"errors": errors,
		"transaction_participant_count": transaction_participants.size(),
		"started_at_msec": started_at_msec,
		"finished_at_msec": finished_at_msec,
		"elapsed_msec": get_elapsed_msec(),
		"event_count": events.size(),
	}
	if include_events:
		var event_dicts: Array[Dictionary] = []
		for event: GFSavePipelineEvent in events:
			if event != null:
				event_dicts.append(event.to_dict())
		result["events"] = event_dicts
	return result
