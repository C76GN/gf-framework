## GFQuestUtility: 轻量级任务进度监听系统。
##
## 基于 `simple event` 将业务事件映射为任务进度累积，
## 适合用于成就、收集与击杀类目标的低成本跟踪。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFQuestUtility
extends GFUtility


# --- 信号 ---

## 当任务开始监听时发出。
## [br]
## @api public
## [br]
## @param quest_id: 任务 ID。
signal quest_started(quest_id: StringName)

## 当任务进入可接取状态时发出。
## [br]
## @api public
## [br]
## @param quest_id: 任务 ID。
signal quest_available(quest_id: StringName)

## 当任务接取条件拒绝时发出。
## [br]
## @api public
## [br]
## @param quest_id: 任务 ID。
## [br]
## @param reason: 拒绝原因。
signal quest_acceptance_blocked(quest_id: StringName, reason: String)

## 当任务进度变化时发出。
## [br]
## @api public
## [br]
## @param quest_id: 任务 ID。
## [br]
## @param current: 当前进度。
## [br]
## @param target: 目标进度。
signal quest_progressed(quest_id: StringName, current: int, target: int)

## 当任务完成时发出。
## [br]
## @api public
## [br]
## @param quest_id: 完成的任务 ID。
signal quest_completed(quest_id: StringName)

## 当任务完成条件被阻塞器拒绝时发出。
## [br]
## @api public
## [br]
## @param quest_id: 任务 ID。
## [br]
## @param reason: 阻塞原因。
signal quest_completion_blocked(quest_id: StringName, reason: String)

## 当任务取消时发出。
## [br]
## @api public
## [br]
## @param quest_id: 任务 ID。
signal quest_cancelled(quest_id: StringName)

## 当任务失败时发出。
## [br]
## @api public
## [br]
## @param quest_id: 任务 ID。
signal quest_failed(quest_id: StringName)


# --- 常量 ---

## 任务已定义、可接取但尚未开始监听。
## [br]
## @api public
const STATUS_AVAILABLE: StringName = &"available"

## 任务正在监听事件并累计进度。
## [br]
## @api public
const STATUS_ACTIVE: StringName = &"active"

## 任务已完成。
## [br]
## @api public
const STATUS_COMPLETED: StringName = &"completed"

## 任务已取消。
## [br]
## @api public
const STATUS_CANCELLED: StringName = &"cancelled"

## 任务已失败。
## [br]
## @api public
const STATUS_FAILED: StringName = &"failed"


# --- 公共变量 ---

## 是否允许事件传入负数进度。默认关闭，避免任务进度被异常 payload 反向扣减。
## [br]
## @api public
var allow_negative_progress: bool = false


# --- 私有变量 ---

# 任务表：quest_id -> _QuestData。
var _quests: Dictionary = {}

# 事件到任务列表的映射：event_id -> Array[StringName]。
var _event_to_quests: Dictionary = {}

# 已注册的事件处理器：event_id -> Callable。
var _event_handlers: Dictionary = {}


# --- GF 生命周期方法 ---

## 初始化任务监听状态。
## [br]
## @api framework_internal
func init() -> void:
	_unregister_all_event_handlers()
	_quests.clear()
	_event_to_quests.clear()


## 释放任务监听状态并注销 simple event 回调。
## [br]
## @api framework_internal
func dispose() -> void:
	_unregister_all_event_handlers()
	_quests.clear()
	_event_to_quests.clear()


# --- 公共方法 ---

## 开始监听一个任务。
## [br]
## @api public
## [br]
## @param quest_id: 任务 ID。
## [br]
## @param target_event: 推进该任务的事件 ID。
## [br]
## @param target_count: 完成任务所需的累计次数。
func start_quest(quest_id: StringName, target_event: StringName, target_count: int = 1) -> void:
	if quest_id == &"" or target_event == &"":
		push_error("[GFQuestUtility] quest_id 和 target_event 不能为空。")
		return

	if _quests.has(quest_id):
		push_warning("[GFQuestUtility] 任务已存在：%s" % quest_id)
		return

	var data: _QuestData = _create_quest_data(quest_id, target_event, target_count, {})
	data._status = STATUS_ACTIVE
	_quests[quest_id] = data

	quest_started.emit(quest_id)

	if target_count <= 0:
		quest_progressed.emit(quest_id, data._current_count, data._target_count)
		var _completed: bool = _try_complete_quest(data)
		return

	_attach_quest_to_event(data)


## 定义一个可接取任务，但暂不开始监听事件。
## [br]
## @api public
## [br]
## @param quest_id: 任务 ID。
## [br]
## @param target_event: 推进该任务的事件 ID。
## [br]
## @param target_count: 完成任务所需的累计次数。
## [br]
## @param metadata: 任务元数据。框架不解释该字段。
## [br]
## @schema metadata: Dictionary，项目自定义任务元数据；GF 会复制保存并在任务报告中透传。
func define_quest(
	quest_id: StringName,
	target_event: StringName,
	target_count: int = 1,
	metadata: Dictionary = {}
) -> void:
	if quest_id == &"":
		push_error("[GFQuestUtility] quest_id 不能为空。")
		return
	if _quests.has(quest_id):
		push_warning("[GFQuestUtility] 任务已存在：%s" % quest_id)
		return

	var data: _QuestData = _create_quest_data(quest_id, target_event, target_count, metadata)
	data._status = STATUS_AVAILABLE
	_quests[quest_id] = data
	quest_available.emit(quest_id)


## 接取一个已定义任务，并开始监听事件。
## [br]
## @api public
## [br]
## @param quest_id: 任务 ID。
## [br]
## @return: 接取成功返回 true。
func accept_quest(quest_id: StringName) -> bool:
	var data: _QuestData = _get_quest_data(quest_id)
	if data == null or data._status == STATUS_COMPLETED or data._status == STATUS_CANCELLED or data._status == STATUS_FAILED:
		return false
	if data._status == STATUS_ACTIVE:
		return true
	if data._event_id == &"":
		push_error("[GFQuestUtility] accept_quest 失败：target_event 为空。")
		return false
	var acceptance_result: Dictionary = _check_conditions(data._acceptance_conditions, data)
	if not GFVariantData.get_option_bool(acceptance_result, "ok", true):
		quest_acceptance_blocked.emit(quest_id, GFVariantData.get_option_string(acceptance_result, "reason", "blocked"))
		return false

	data._status = STATUS_ACTIVE
	quest_started.emit(quest_id)
	if data._target_count <= 0:
		quest_progressed.emit(quest_id, data._current_count, data._target_count)
		var _completed: bool = _try_complete_quest(data)
	else:
		_attach_quest_to_event(data)
	return true


## 手动完成一个任务。
## [br]
## @api public
## [br]
## @param quest_id: 任务 ID。
## [br]
## @return: 完成成功返回 true。
func complete_quest(quest_id: StringName) -> bool:
	var data: _QuestData = _get_quest_data(quest_id)
	if data == null or data._status != STATUS_ACTIVE:
		return false
	return _try_complete_quest(data)


## 取消一个任务。
## [br]
## @api public
## [br]
## @param quest_id: 任务 ID。
## [br]
## @return: 取消成功返回 true。
func cancel_quest(quest_id: StringName) -> bool:
	var data: _QuestData = _get_quest_data(quest_id)
	if data == null or data._status == STATUS_COMPLETED or data._status == STATUS_CANCELLED or data._status == STATUS_FAILED:
		return false
	_detach_quest_from_event(data)
	data._status = STATUS_CANCELLED
	quest_cancelled.emit(quest_id)
	return true


## 标记任务失败。
## [br]
## @api public
## [br]
## @param quest_id: 任务 ID。
## [br]
## @param reason: 可选失败原因，会写入任务 metadata 的 last_failure_reason。
## [br]
## @return: 标记成功返回 true。
func fail_quest(quest_id: StringName, reason: String = "") -> bool:
	var data: _QuestData = _get_quest_data(quest_id)
	if data == null or data._status == STATUS_COMPLETED or data._status == STATUS_CANCELLED or data._status == STATUS_FAILED:
		return false

	_detach_quest_from_event(data)
	data._status = STATUS_FAILED
	if not reason.is_empty():
		data._metadata["last_failure_reason"] = reason
	quest_failed.emit(quest_id)
	return true


## 添加接取条件。条件返回 false 或包含 ok=false 的 Dictionary 时阻止接取。
## [br]
## @api public
## [br]
## @param quest_id: 任务 ID。
## [br]
## @param condition: 条件回调。
func add_acceptance_condition(quest_id: StringName, condition: Callable) -> void:
	if not condition.is_valid():
		return
	var data: _QuestData = _get_quest_data(quest_id)
	if data == null:
		return
	data._acceptance_conditions.append(condition)


## 清空任务接取条件。
## [br]
## @api public
## [br]
## @param quest_id: 任务 ID。
func clear_acceptance_conditions(quest_id: StringName) -> void:
	var data: _QuestData = _get_quest_data(quest_id)
	if data != null:
		data._acceptance_conditions.clear()


## 添加完成阻塞器。阻塞器返回 false 或包含 ok=false 的 Dictionary 时阻止完成。
## [br]
## @api public
## [br]
## @param quest_id: 任务 ID。
## [br]
## @param blocker: 阻塞器回调。
func add_completion_blocker(quest_id: StringName, blocker: Callable) -> void:
	if not blocker.is_valid():
		return
	var data: _QuestData = _get_quest_data(quest_id)
	if data == null:
		return
	data._completion_blockers.append(blocker)


## 清空任务完成阻塞器。
## [br]
## @api public
## [br]
## @param quest_id: 任务 ID。
func clear_completion_blockers(quest_id: StringName) -> void:
	var data: _QuestData = _get_quest_data(quest_id)
	if data != null:
		data._completion_blockers.clear()


## 设置任务父级关系。
## [br]
## @api public
## [br]
## @param quest_id: 子任务 ID。
## [br]
## @param parent_quest_id: 父任务 ID。
## [br]
## @return: 设置成功返回 true。
func set_quest_parent(quest_id: StringName, parent_quest_id: StringName) -> bool:
	if quest_id == &"" or parent_quest_id == &"" or quest_id == parent_quest_id:
		return false
	var data: _QuestData = _get_quest_data(quest_id)
	var parent: _QuestData = _get_quest_data(parent_quest_id)
	if data == null or parent == null:
		return false
	if _is_descendant_quest(quest_id, parent_quest_id):
		return false

	_detach_quest_parent(data)
	data._parent_id = parent_quest_id
	if not parent._child_ids.has(String(quest_id)):
		_append_packed_string(parent._child_ids, String(quest_id))
	parent._child_ids.sort()
	return true


## 清除任务父级关系。
## [br]
## @api public
## [br]
## @param quest_id: 任务 ID。
func clear_quest_parent(quest_id: StringName) -> void:
	var data: _QuestData = _get_quest_data(quest_id)
	if data != null:
		_detach_quest_parent(data)


## 获取任务的直接子任务 ID。
## [br]
## @api public
## [br]
## @param quest_id: 任务 ID。
## [br]
## @return: 子任务 ID 列表。
func get_child_quests(quest_id: StringName) -> PackedStringArray:
	var data: _QuestData = _get_quest_data(quest_id)
	return data._child_ids.duplicate() if data != null else PackedStringArray()


## 获取任务树报告。
## [br]
## @api public
## [br]
## @param root_quest_id: 根任务 ID。
## [br]
## @return: 树形报告；任务不存在时返回空字典。
## [br]
## @schema return: Dictionary，包含任务报告字段、children: Array[Dictionary]、total_count、completed_count 与 aggregate_progress。
func get_quest_tree_report(root_quest_id: StringName) -> Dictionary:
	var root_data: _QuestData = _get_quest_data(root_quest_id)
	if root_data == null:
		return {}
	return _build_quest_tree_report(root_data)


## 手动触发一次任务事件。
## [br]
## @api public
## [br]
## @param event_id: 事件 ID。
## [br]
## @param amount: 本次增加的进度值。
func emit_quest_event(event_id: StringName, amount: int = 1) -> void:
	var arch: GFArchitecture = _get_arch()
	if arch != null:
		arch.send_simple_event(event_id, amount)
	else:
		_on_quest_event_triggered(amount, event_id)


## 查询任务是否已经完成。
## [br]
## @api public
## [br]
## @param quest_id: 任务 ID。
## [br]
## @return: 已完成时返回 true。
func is_quest_completed(quest_id: StringName) -> bool:
	if _quests.has(quest_id):
		var data: _QuestData = _get_quest_data(quest_id)
		return data != null and data._is_completed

	return false


## 获取任务进度百分比。
## [br]
## @api public
## [br]
## @param quest_id: 任务 ID。
## [br]
## @return: 范围在 0.0 到 1.0 之间的进度值。
func get_quest_progress(quest_id: StringName) -> float:
	if _quests.has(quest_id):
		var data: _QuestData = _get_quest_data(quest_id)
		if data == null:
			return 0.0
		if data._target_count <= 0:
			return 1.0

		return clampf(float(data._current_count) / float(data._target_count), 0.0, 1.0)

	return 0.0


## 获取任务状态。
## [br]
## @api public
## [br]
## @param quest_id: 任务 ID。
## [br]
## @return: 状态文本。
func get_quest_status(quest_id: StringName) -> StringName:
	var data: _QuestData = _get_quest_data(quest_id)
	return data._status if data != null else &""


## 获取指定状态的任务 ID。
## [br]
## @api public
## [br]
## @param status: 任务状态。
## [br]
## @return: 任务 ID 列表。
func get_quests_by_status(status: StringName) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for quest_id: StringName in _quests.keys():
		var data: _QuestData = _get_quest_data(quest_id)
		if data != null and data._status == status:
			_append_packed_string(result, String(quest_id))
	result.sort()
	return result


## 获取任务报告。
## [br]
## @api public
## [br]
## @param quest_id: 任务 ID。
## [br]
## @return: 任务报告字典。
## [br]
## @schema return: Dictionary，包含 quest_id、event_id、target_count、current_count、is_completed、status、parent_id、child_ids、metadata、acceptance_condition_count 与 completion_blocker_count。
func get_quest_report(quest_id: StringName) -> Dictionary:
	var data: _QuestData = _get_quest_data(quest_id)
	if data == null:
		return {}
	return data._to_dict()


## 获取任务系统调试快照。
## [br]
## @api public
## [br]
## @return: 调试快照字典。
## [br]
## @schema return: Dictionary，包含 quest_count、event_count 与 quests；quests 键为 String 任务 ID，值为任务报告字典。
func get_debug_snapshot() -> Dictionary:
	var reports: Dictionary = {}
	for quest_id: StringName in _quests.keys():
		var data: _QuestData = _get_quest_data(quest_id)
		if data != null:
			reports[String(quest_id)] = data._to_dict()
	return {
		"quest_count": _quests.size(),
		"event_count": _event_to_quests.size(),
		"quests": reports,
	}


# --- 私有/辅助方法 ---

func _on_quest_event_triggered(payload: Variant, event_id: StringName) -> void:
	if not _event_to_quests.has(event_id):
		return

	var amount: int = _payload_to_amount(payload)
	if not allow_negative_progress:
		amount = maxi(amount, 0)

	var list: Array = _get_event_quest_list(event_id).duplicate()
	for quest_id_variant: Variant in list:
		var quest_id: StringName = GFVariantData.to_string_name(quest_id_variant)
		var data: _QuestData = _get_quest_data(quest_id)
		if data == null or data._status != STATUS_ACTIVE or data._is_completed:
			continue

		data._current_count += amount
		if data._current_count >= data._target_count:
			data._current_count = data._target_count
			quest_progressed.emit(quest_id, data._current_count, data._target_count)
			var _completed: bool = _try_complete_quest(data)
		else:
			quest_progressed.emit(quest_id, data._current_count, data._target_count)


func _register_event_handler(event_id: StringName) -> void:
	var arch: GFArchitecture = _get_arch()
	if arch == null:
		return

	var event_handler: Callable = Callable(self, "_on_quest_event_triggered").bind(event_id)
	_event_handlers[event_id] = event_handler
	register_simple_event(event_id, event_handler)


func _unregister_event_handler(event_id: StringName) -> void:
	if not _event_handlers.has(event_id):
		return

	var arch: GFArchitecture = _get_arch()
	if arch != null:
		var event_handler: Callable = _get_event_handler(event_id)
		unregister_simple_event(event_id, event_handler)
	_erase_dictionary_key(_event_handlers, event_id)


func _unregister_all_event_handlers() -> void:
	var arch: GFArchitecture = _get_arch()
	if arch != null:
		for event_id: StringName in _event_handlers:
			var event_handler: Callable = _get_event_handler(event_id)
			unregister_simple_event(event_id, event_handler)

	_event_handlers.clear()


func _get_arch() -> GFArchitecture:
	return _get_architecture_or_null()


func _payload_to_amount(payload: Variant) -> int:
	var current_payload: Variant = payload
	var depth: int = 0
	while current_payload is Dictionary:
		var payload_dictionary: Dictionary = current_payload
		if not payload_dictionary.has("amount"):
			break
		depth += 1
		if depth > 16:
			push_error("[GFQuestUtility] payload.amount 嵌套过深，已回退为默认进度 1。")
			return 1
		current_payload = payload_dictionary["amount"]

	if current_payload is int:
		var int_amount: int = current_payload
		return int_amount
	if current_payload is float:
		var float_amount: float = current_payload
		return roundi(float_amount)

	return 1


func _create_quest_data(
	quest_id: StringName,
	target_event: StringName,
	target_count: int,
	metadata: Dictionary
) -> _QuestData:
	var data: _QuestData = _QuestData.new()
	data._quest_id = quest_id
	data._event_id = target_event
	data._target_count = target_count
	data._metadata = metadata.duplicate(true)
	return data


func _attach_quest_to_event(data: _QuestData) -> void:
	if data == null or data._event_id == &"":
		return
	var should_register_handler: bool = not _event_to_quests.has(data._event_id)
	var list: Array = _ensure_event_quest_list(data._event_id)
	if should_register_handler:
		_register_event_handler(data._event_id)

	if not list.has(data._quest_id):
		list.append(data._quest_id)


func _detach_quest_from_event(data: _QuestData) -> void:
	if data == null or data._event_id == &"" or not _event_to_quests.has(data._event_id):
		return
	var list: Array = _get_event_quest_list(data._event_id)
	list.erase(data._quest_id)
	if list.is_empty():
		_erase_dictionary_key(_event_to_quests, data._event_id)
		_unregister_event_handler(data._event_id)


func _try_complete_quest(data: _QuestData) -> bool:
	if data == null or data._is_completed or data._status != STATUS_ACTIVE:
		return false

	var blocker_result: Dictionary = _check_conditions(data._completion_blockers, data)
	if not GFVariantData.get_option_bool(blocker_result, "ok", true):
		quest_completion_blocked.emit(data._quest_id, GFVariantData.get_option_string(blocker_result, "reason", "blocked"))
		return false

	_detach_quest_from_event(data)
	data._is_completed = true
	data._status = STATUS_COMPLETED
	quest_completed.emit(data._quest_id)
	return true


func _check_conditions(conditions: Array[Callable], data: _QuestData) -> Dictionary:
	for condition: Callable in conditions:
		if not condition.is_valid():
			continue
		var result: Variant = condition.call(data._quest_id, data._to_dict())
		if result is Dictionary:
			var result_dictionary: Dictionary = result
			if not GFVariantData.get_option_bool(result_dictionary, "ok", false):
				return {
					"ok": false,
					"reason": GFVariantData.get_option_string(result_dictionary, "reason", "blocked"),
				}
		elif result == false:
			return {
				"ok": false,
				"reason": "blocked",
			}
	return {
		"ok": true,
		"reason": "",
	}


func _detach_quest_parent(data: _QuestData) -> void:
	if data == null or data._parent_id == &"":
		return
	var parent: _QuestData = _get_quest_data(data._parent_id)
	if parent != null:
		var index: int = parent._child_ids.find(String(data._quest_id))
		if index >= 0:
			parent._child_ids.remove_at(index)
	data._parent_id = &""


func _is_descendant_quest(root_quest_id: StringName, expected_descendant_id: StringName) -> bool:
	var root: _QuestData = _get_quest_data(root_quest_id)
	if root == null:
		return false
	for child_id_text: String in root._child_ids:
		var child_id: StringName = StringName(child_id_text)
		if child_id == expected_descendant_id or _is_descendant_quest(child_id, expected_descendant_id):
			return true
	return false


func _build_quest_tree_report(data: _QuestData) -> Dictionary:
	var children: Array[Dictionary] = []
	var total_count: int = 1
	var completed_count: int = 1 if data._status == STATUS_COMPLETED else 0
	for child_id_text: String in data._child_ids:
		var child: _QuestData = _get_quest_data(StringName(child_id_text))
		if child == null:
			continue
		var child_report: Dictionary = _build_quest_tree_report(child)
		children.append(child_report)
		total_count += GFVariantData.get_option_int(child_report, "total_count")
		completed_count += GFVariantData.get_option_int(child_report, "completed_count")

	var report: Dictionary = data._to_dict()
	report["children"] = children
	report["total_count"] = total_count
	report["completed_count"] = completed_count
	report["aggregate_progress"] = float(completed_count) / float(total_count) if total_count > 0 else 0.0
	return report


func _get_quest_data(quest_id: StringName) -> _QuestData:
	return _variant_to_quest_data(GFVariantData.get_option_value(_quests, quest_id))


func _get_event_handler(event_id: StringName) -> Callable:
	return _variant_to_callable(GFVariantData.get_option_value(_event_handlers, event_id, Callable()))


func _get_event_quest_list(event_id: StringName) -> Array:
	return GFVariantData.as_array(GFVariantData.get_option_value(_event_to_quests, event_id, []))


func _ensure_event_quest_list(event_id: StringName) -> Array:
	if _event_to_quests.has(event_id):
		var existing_value: Variant = GFVariantData.get_option_value(_event_to_quests, event_id, [])
		if existing_value is Array:
			return GFVariantData.as_array(existing_value)

	var list: Array[StringName] = []
	_event_to_quests[event_id] = list
	return list


func _erase_dictionary_key(source: Dictionary, key: Variant) -> void:
	var _erased: bool = source.erase(key)


func _append_packed_string(target: PackedStringArray, value: String) -> void:
	var _appended: bool = target.append(value)


func _variant_to_callable(value: Variant) -> Callable:
	if value is Callable:
		return value
	return Callable()


func _variant_to_quest_data(value: Variant) -> _QuestData:
	if value is _QuestData:
		return value
	return null


# --- 内部类 ---

class _QuestData extends RefCounted:
	var _quest_id: StringName
	var _event_id: StringName
	var _target_count: int = 1
	var _current_count: int = 0
	var _is_completed: bool = false
	var _status: StringName = &"available"
	var _parent_id: StringName = &""
	var _child_ids: PackedStringArray = PackedStringArray()
	var _metadata: Dictionary = {}
	var _acceptance_conditions: Array[Callable] = []
	var _completion_blockers: Array[Callable] = []

	func _to_dict() -> Dictionary:
		return {
			"quest_id": String(_quest_id),
			"event_id": String(_event_id),
			"target_count": _target_count,
			"current_count": _current_count,
			"is_completed": _is_completed,
			"status": String(_status),
			"parent_id": String(_parent_id),
			"child_ids": _child_ids.duplicate(),
			"metadata": _metadata.duplicate(true),
			"acceptance_condition_count": _acceptance_conditions.size(),
			"completion_blocker_count": _completion_blockers.size(),
		}
