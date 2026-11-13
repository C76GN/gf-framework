## GFQuestUtility: 冻结定义驱动的任务进度与生命周期。
##
## 历史和当前指标由项目查询或显式输入提供，累计指标只接受接取后的整数增量。
## 完成策略与指标模式分离；快照恢复不查询指标、不重放任务事件，也不发放奖励。
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
## @since 3.17.0
## [br]
## @param quest_id: 任务 ID。
## [br]
## @param current: 当前进度。
## [br]
## @param target: 目标进度。
signal quest_progressed(
	quest_id: StringName,
	current: int,
	target: int
)

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

## 饱和整数加法使用的有符号 64 位上界。
## [br]
## @api private
const _INT64_MAX: int = 9223372036854775807

## 饱和整数加法使用的有符号 64 位下界。
## [br]
## @api private
const _INT64_MIN: int = -9223372036854775807 - 1


# --- 私有变量 ---

# 任务表：quest_id -> _QuestData。
## 按任务 ID 保存任务运行状态。
## [br]
## @api private
var _quests: Dictionary = {}

# 事件到任务列表的映射：event_id -> Array[StringName]。
## 按事件 ID 保存正在监听该事件的任务 ID 列表。
## [br]
## @api private
var _event_to_quests: Dictionary = {}

# 已注册的事件处理器：event_id -> Callable。
## 按事件 ID 保存已注册的 simple event 监听器。
## [br]
## @api private
var _event_handlers: Dictionary = {}

## 最新已注册定义；已接取状态另外持有冻结版本。
## [br]
## @api private
var _definitions: Dictionary = {}

## 指标 ID 到项目查询函数，函数无参数并返回 int，其他结果表示不可用。
## [br]
## @api private
var _metric_queries: Dictionary = {}

## 项目显式输入的查询型指标缓存；恢复快照时清空。
## [br]
## @api private
var _metric_values: Dictionary = {}

## 查询型指标到活动任务的索引。
## [br]
## @api private
var _query_to_quests: Dictionary = {}

## 指标输入与查询绑定的修订号，防止重入结果覆盖新输入。
## [br]
## @api private
var _metric_revisions: Dictionary = {}

## 为指标绑定和输入分配单调修订号。
## [br]
## @api private
var _next_metric_revision: int = 0

## 正在执行的查询，用于拒绝同指标递归查询。
## [br]
## @api private
var _refreshing_metrics: Dictionary = {}

## 整批恢复或释放后让在途同步回调失效。
## [br]
## @api private
var _epoch: int = 0

## 释放后关闭新任务入口。
## [br]
## @api private
var _disposed: bool = false

## 每个任务至多保留一次待发进度；同任务重入合并到最新状态。
## [br]
## @api private
var _pending_progress: Dictionary[StringName, _QuestData] = {}

## 阻止同步信号重入产生逆序通知。
## [br]
## @api private
var _publishing_progress: bool = false


# --- GF 生命周期方法 ---

## 只续发超过单次256条预算的进度通知，不轮询指标查询。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param _delta: 不用于指标或任务计时。
func tick(_delta: float) -> void:
	_drain_progress_notifications()


# --- 公共方法 ---

## 注册新定义或发布更高版本；已接取和终态任务保留原定义。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param definition: 通过 GFQuestDefinition 工厂创建的定义。
## [br]
## @return 注册成功为 true；重复版本内容不同、版本回退、无效定义或超过4096任务时拒绝。
func define_quest(definition: GFQuestDefinition) -> bool:
	if (
		_disposed
		or definition == null
		or definition.get_quest_id() == &""
	):
		return false
	var quest_id: StringName = definition.get_quest_id()
	var current_value: Variant = _definitions.get(quest_id)
	if current_value is GFQuestDefinition:
		var current: GFQuestDefinition = current_value
		if definition.get_version() <= current.get_version():
			return definition.to_record() == current.to_record()
	elif _definitions.size() >= 4096:
		return false
	_definitions[quest_id] = definition
	var data: _QuestData = _get_quest_data(quest_id)
	if data != null:
		if data._status == STATUS_AVAILABLE:
			data._definition = definition
			data._event_id = definition.get_metric_id()
			data._target_count = definition.get_target()
			data._metadata = GFVariantData.get_option_dictionary(
				definition.to_record(),
				"metadata"
			)
		return true
	data = _create_quest_data(definition)
	_quests[quest_id] = data
	quest_available.emit(quest_id)
	return true


## 接取任务，冻结当前定义与项目提供的接取信息。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param quest_id: 已注册的任务身份。
## [br]
## @param acceptance_data: 项目记录的周期、业务请求身份或时间样本，不由框架推断。
## [br]
## @schema acceptance_data: 原生纯数据 Dictionary，深度16、2048节点、64KiB；不包含回调或对象。
## [br]
## @return 接取成功或原本已经 active 时为 true；终态、非法数据或条件拒绝时为 false。
func accept_quest(quest_id: StringName, acceptance_data: Dictionary = {}) -> bool:
	var data: _QuestData = _get_quest_data(quest_id)
	if (
		data == null
		or data._checking_acceptance
		or _disposed
	):
		return false
	if data._status == STATUS_ACTIVE:
		return true
	if data._status != STATUS_AVAILABLE:
		return false
	var measured: Dictionary = GFDeterministicVariantSerializer.measure_canonical(
		acceptance_data,
		{
			"allow_floats": true,
			"max_depth": 16,
			"max_items": 2048,
			"max_output_bytes": 65536,
			"max_string_length": 65536,
		}
	)
	if not GFVariantData.get_option_bool(measured, "ok"):
		return false
	var frozen_acceptance: Dictionary = acceptance_data.duplicate(true)
	var definition: GFQuestDefinition = data._definition
	data._checking_acceptance = true
	var acceptance_result: Dictionary = _check_conditions(data._acceptance_conditions, data)
	data._checking_acceptance = false
	if not _is_current_quest_in_status(data, STATUS_AVAILABLE) or definition != data._definition:
		return false
	if not GFVariantData.get_option_bool(acceptance_result, "ok"):
		quest_acceptance_blocked.emit(
			quest_id,
			GFVariantData.get_option_string(
				acceptance_result,
				"reason",
				"blocked"
			)
		)
		return false
	data._status = STATUS_ACTIVE
	data._accepted = true
	data._acceptance_data = frozen_acceptance
	data._metric_available = definition.get_mode() == GFQuestDefinition.SINCE_ACCEPTANCE
	_attach_quest_to_event(data)
	quest_started.emit(quest_id)
	if not _is_current_active_quest(data):
		return true
	if definition.get_mode() != GFQuestDefinition.SINCE_ACCEPTANCE:
		var _refreshed: bool = refresh_metric(definition.get_metric_id())
	else:
		_maybe_complete_automatically(data)
	return true


## 确认完成；查询型任务先取得新指标，external 策略只检查项目阻塞器。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param quest_id: 活动任务 ID。
## [br]
## @return 本次确认成功为 true；未达标、指标不可用、已终止或被阻塞时为 false。
func complete_quest(quest_id: StringName) -> bool:
	var data: _QuestData = _get_quest_data(quest_id)
	if (
		data == null
		or data._status != STATUS_ACTIVE
		or data._checking_completion
	):
		return false
	if data._definition.get_completion() != GFQuestDefinition.EXTERNAL and data._definition.get_mode() != GFQuestDefinition.SINCE_ACCEPTANCE:
		if not refresh_metric(data._event_id):
			return false
		if _is_current_quest_in_status(data, STATUS_COMPLETED):
			return true
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
	if (
		data == null
		or data._status == STATUS_COMPLETED
		or data._status == STATUS_CANCELLED
		or data._status == STATUS_FAILED
	):
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
	if (
		data == null
		or data._status == STATUS_COMPLETED
		or data._status == STATUS_CANCELLED
		or data._status == STATUS_FAILED
	):
		return false

	_detach_quest_from_event(data)
	data._status = STATUS_FAILED
	data._failure_reason = reason.left(4096)
	if not reason.is_empty():
		data._metadata["last_failure_reason"] = data._failure_reason
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
	if (
		quest_id == &""
		or parent_quest_id == &""
		or quest_id == parent_quest_id
	):
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
		_append_packed_string(
			parent._child_ids,
			String(quest_id)
		)
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
## @since unreleased
## [br]
## @param event_id: 事件 ID。
## [br]
## @param amount: 本次增加的进度值。
func emit_quest_event(event_id: StringName, amount: int) -> void:
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
		if data._definition.get_completion() == GFQuestDefinition.EXTERNAL:
			return 1.0 if data._is_completed else 0.0
		if not data._metric_available:
			return 0.0
		if data._target_count <= 0:
			return 1.0

		return clampf(
			float(data._current_count) / float(data._target_count),
			0.0,
			1.0
		)

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
			_append_packed_string(
				result,
				String(quest_id)
			)
	result.sort()
	return result


## 获取任务报告。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param quest_id: 任务 ID。
## [br]
## @return: 任务报告字典。
## [br]
## @schema return: Dictionary，包含 quest_id、event_id、target_count、current_count、is_completed、status、parent_id、child_ids、metadata、acceptance_condition_count、completion_blocker_count、definition_version、metric_mode、completion_policy、metric_available、eligible、accepted 与 acceptance_data。资格是缓存状态，不执行查询或阻塞器。
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


## 注册项目指标查询；不自动调用，查询必须无参数并返回 int。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param metric_id: 非空指标身份，最多256字符。
## [br]
## @param query: 同步主线程查询；无效或非 int 返回值使该指标不可用。
## [br]
## @return 绑定成功；最多4096个查询。
func register_metric_query(metric_id: StringName, query: Callable) -> bool:
	if (
		_disposed
		or not query.is_valid()
		or not _valid_metric_id(metric_id)
		or _metric_values.has(metric_id)
	):
		return false
	if not _metric_queries.has(metric_id) and _metric_queries.size() >= 4096:
		return false
	_metric_queries[metric_id] = query
	_touch_metric(metric_id)
	_invalidate_metric(metric_id)
	return true


## 移除查询和该指标的显式输入，已有活动任务的指标变为不可用。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param metric_id: 指标身份。
func clear_metric_source(metric_id: StringName) -> void:
	if not _metric_queries.has(metric_id) and not _metric_values.has(metric_id):
		return
	var _removed_query: bool = _metric_queries.erase(metric_id)
	var _removed_value: bool = _metric_values.erase(metric_id)
	var _removed_revision: bool = _metric_revisions.erase(metric_id)
	_invalidate_metric(metric_id)


## 输入历史或当前指标值，并仅更新受此指标影响的活动任务。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param metric_id: 项目指标身份。
## [br]
## @param value: 精确整数；每个定义自行决定是否接受负数。
## [br]
## @return 输入被接受时为 true。注册了查询时拒绝混用显式输入；最多4096个缓存指标。
func set_metric_value(metric_id: StringName, value: int) -> bool:
	if (
		_disposed
		or not _valid_metric_id(metric_id)
		or _metric_queries.has(metric_id)
	):
		return false
	if not _metric_values.has(metric_id) and _metric_values.size() >= 4096:
		return false
	_metric_values[metric_id] = value
	_touch_metric(metric_id)
	_apply_metric_value(metric_id, value)
	return true


## 显式刷新一个指标；不进行每帧全量轮询。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param metric_id: 要刷新的历史或当前指标。
## [br]
## @return 查询或显式缓存有效且未被重入替换时为 true；非法结果使指标不可用。
func refresh_metric(metric_id: StringName) -> bool:
	if _disposed or _refreshing_metrics.has(metric_id):
		return false
	var epoch: int = _epoch
	var revision: int = GFVariantData.get_option_int(_metric_revisions, metric_id)
	_refreshing_metrics[metric_id] = true
	var value: Variant = _metric_values.get(metric_id)
	if _metric_queries.has(metric_id):
		var query: Callable = _metric_queries[metric_id]
		value = query.call() if query.is_valid() else null
		if epoch != _epoch:
			return false
		if revision != GFVariantData.get_option_int(_metric_revisions, metric_id):
			var _removed_stale: bool = _refreshing_metrics.erase(metric_id)
			return false
	if not value is int:
		_invalidate_metric(metric_id)
		if epoch == _epoch:
			var _removed_invalid: bool = _refreshing_metrics.erase(metric_id)
		return false
	var integer_value: int = value
	_apply_metric_value(metric_id, integer_value)
	if epoch != _epoch:
		return false
	var _removed: bool = _refreshing_metrics.erase(metric_id)
	return revision == GFVariantData.get_option_int(_metric_revisions, metric_id)


## 查询缓存指标是否满足完成门槛，不执行项目查询或完成阻塞器。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param quest_id: 任务身份。
## [br]
## @return 活动任务的指标可用且达标时为 true；external 表示允许项目尝试确认，并非业务事实已成立。
func is_quest_eligible(quest_id: StringName) -> bool:
	var data: _QuestData = _get_quest_data(quest_id)
	return _is_current_active_quest(data) and _is_eligible(data)


## 导出一个任务的冻结状态；报告和状态副本都不能修改运行任务。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param quest_id: 任务身份。
## [br]
## @return 独立状态；任务不存在时为 null。
func get_quest_state(quest_id: StringName) -> GFQuestState:
	var data: _QuestData = _get_quest_data(quest_id)
	return GFQuestState.from_record(data._to_state_record()) if data != null else null


## 导出扁平任务快照，包含父级身份但不保存运行时回调。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 可持久化的有界副本；超过整包预算时返回空字典，调用方不得将空字典作为有效存档。
## [br]
## @schema return: 封闭 Dictionary，format_version:int=1、states:Array[Dictionary]（GFQuestState记录，按quest_id排序）。最多4096任务，整个包深度24、200000节点、16MiB。
func export_snapshot() -> Dictionary:
	var records: Array[Dictionary] = []
	var identities: Array = _quests.keys()
	identities.sort()
	for quest_id: StringName in identities:
		records.append(_get_quest_data(quest_id)._to_state_record())
	var snapshot: Dictionary = { "format_version": 1, "states": records }
	return snapshot if _within_snapshot_budget(snapshot) else {}


## 原子恢复任务状态，不发出任务或奖励事件，不执行查询和条件回调。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param snapshot: export_snapshot 产生的封闭快照。
## [br]
## @schema snapshot: 与 export_snapshot.return 相同。未知任务、重复身份、无效状态、缺失父级和环均拒绝。已接取任务采用快照定义；未接取任务采用当前目录定义。目录中新增且快照未包含的任务从available开始。
## [br]
## @return 全部验证和替换成功时为 true；失败不改变任务、监听或输入缓存。查询型活动任务恢复为指标不可用，须显式刷新。
func restore_snapshot(snapshot: Dictionary) -> bool:
	var prepared: Dictionary = _prepare_snapshot_restore(snapshot)
	var report: Dictionary = prepared["report"]
	if not GFVariantData.get_option_bool(report, "ok"):
		return false
	var candidates: Dictionary = prepared["candidates"]
	for quest_id: StringName in candidates:
		var data: _QuestData = candidates[quest_id]
		var previous: _QuestData = _get_quest_data(quest_id)
		if previous != null:
			data._acceptance_conditions = previous._acceptance_conditions.duplicate()
			data._completion_blockers = previous._completion_blockers.duplicate()
	_epoch += 1
	_unregister_all_event_handlers()
	_event_to_quests.clear()
	_pending_progress.clear()
	_query_to_quests.clear()
	_metric_values.clear()
	_refreshing_metrics.clear()
	_quests = candidates
	for quest_id: StringName in _quests:
		var data: _QuestData = _get_quest_data(quest_id)
		if data._status == STATUS_ACTIVE:
			_attach_quest_to_event(data)
	return true


## 只读检查当前目录能否恢复快照，不替换任务、监听或指标缓存。
##
## 与 restore_snapshot 共用候选准备，不执行查询、条件、任务信号或奖励。
## 报告只说明调用当时的输入与目录；正式恢复会重新验证，不能复用旧报告准入。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param snapshot: 待恢复的封闭快照。
## [br]
## @schema snapshot: 与 restore_snapshot.snapshot 相同；不要求先执行实际恢复。
## [br]
## @return 当前输入和目录的独立校验报告；不输出错误日志。
## [br]
## @schema return: 封闭基础字段 ok:bool、error_kind:String、path:String；成功时后两项为空。容量错误可含 limit:int、observed:int；纯数据错误另含 measurement:Dictionary、limits:Dictionary，并可含 limit_kind:String、observed_is_lower_bound:bool。path 为从输入参数名开始的 / 分段路径，~ 和 / 分别转义为 ~0 和 ~1；空路径指当前服务。observed_is_lower_bound=true 时 observed 只是确定下界，measurement 失败计数只描述已遍历前缀。报告不含对象或可复用准入令牌。 /snapshot/states/N 指输入中第 N 个状态，N 从 0 开始；invalid_state 定位整条状态记录，其内部字段须符合 GFQuestState 记录契约。
func validate_restore_snapshot(snapshot: Dictionary) -> Dictionary:
	var prepared: Dictionary = _prepare_snapshot_restore(snapshot)
	var report: Dictionary = prepared["report"]
	return report


# --- 框架内部方法 ---

## 初始化空目录、查询绑定和任务状态。
## [br]
## @api framework_internal
func init() -> void:
	_clear_runtime()
	_disposed = false


## 释放所有回调与状态，并使重入中的旧查询失效。
## [br]
## @api framework_internal
func dispose() -> void:
	_disposed = true
	_clear_runtime()


# --- 私有/辅助方法 ---

## 完整构造与校验候选，不复制运行回调、不提交索引、不执行查询、条件或信号。
## [br]
## @api private
func _prepare_snapshot_restore(snapshot: Dictionary) -> Dictionary:
	if _disposed:
		return { "report": _validation_report("service_disposed") }
	for key: Variant in snapshot:
		if not key is String:
			return { "report": _validation_report("invalid_key_type", "/snapshot") }
		var field: String = key
		if field not in ["format_version", "states"]:
			var path: String = "/snapshot/" + field.replace("~", "~0").replace("/", "~1")
			return { "report": _validation_report("unknown_field", path) }
	if not snapshot.has("format_version"):
		return { "report": _validation_report("required", "/snapshot/format_version") }
	if not snapshot.get("format_version") is int:
		return { "report": _validation_report("invalid_type", "/snapshot/format_version") }
	if snapshot["format_version"] != 1:
		return { "report": _validation_report("unsupported_version", "/snapshot/format_version") }
	if not snapshot.has("states"):
		return { "report": _validation_report("required", "/snapshot/states") }
	if not snapshot.get("states") is Array:
		return { "report": _validation_report("invalid_type", "/snapshot/states") }
	var records: Array = snapshot["states"]
	if records.size() > 4096:
		return {
			"report": _validation_report(
				"state_limit",
				"/snapshot/states",
				4096,
				records.size()
			),
		}
	var report: Dictionary = _validate_snapshot_budget(snapshot)
	if not GFVariantData.get_option_bool(report, "ok"):
		return { "report": report }
	var candidates: Dictionary = {}
	for quest_id: StringName in _definitions:
		var definition: GFQuestDefinition = _definitions[quest_id]
		candidates[quest_id] = _create_quest_data(definition)
	var record_paths: Dictionary = {}
	for index: int in range(records.size()):
		var path: String = "/snapshot/states/" + str(index)
		var value: Variant = records[index]
		if not value is Dictionary:
			return { "report": _validation_report("invalid_type", path) }
		var record: Dictionary = value
		var state: GFQuestState = GFQuestState.from_record(record)
		if state == null:
			return { "report": _validation_report("invalid_state", path) }
		var definition: GFQuestDefinition = state.get_definition()
		var quest_id: StringName = definition.get_quest_id()
		if not _definitions.has(quest_id):
			return {
				"report": _validation_report(
					"unknown_quest",
					path + "/definition/quest_id"
				),
			}
		if record_paths.has(quest_id):
			return {
				"report": _validation_report(
					"duplicate_id",
					path + "/definition/quest_id"
				),
			}
		record_paths[quest_id] = path
		var accepted: bool = GFVariantData.get_option_bool(record, "accepted")
		if not accepted:
			definition = _definitions[quest_id]
		var data: _QuestData = _create_quest_data(definition)
		data._status = state.get_status()
		data._current_count = state.get_current_count()
		data._metric_available = state.is_metric_available()
		data._accepted = accepted
		data._acceptance_data = GFVariantData.get_option_dictionary(record, "acceptance_data")
		data._parent_id = GFVariantData.get_option_string_name(record, "parent_id")
		data._failure_reason = GFVariantData.get_option_string(record, "failure_reason")
		data._is_completed = data._status == STATUS_COMPLETED
		if not data._failure_reason.is_empty():
			data._metadata["last_failure_reason"] = data._failure_reason
		if data._status == STATUS_ACTIVE and definition.get_mode() != GFQuestDefinition.SINCE_ACCEPTANCE:
			data._metric_available = false
		candidates[quest_id] = data
	report = _link_candidate_tree(candidates, record_paths)
	if not GFVariantData.get_option_bool(report, "ok"):
		return { "report": report }
	return { "report": report, "candidates": candidates }


## 每次创建独立纯数据报告，不保存全局错误或可复用的准入资格。
## [br]
## @api private
static func _validation_report(
	error_kind: String = "",
	path: String = "",
	limit: int = -1,
	observed: int = -1
) -> Dictionary:
	var report: Dictionary = {
		"ok": error_kind.is_empty(),
		"error_kind": error_kind,
		"path": path,
	}
	if limit >= 0:
		report["limit"] = limit
		report["observed"] = observed
	return report


## 保留底层计量和预算，不从错误文本猜测种类或把前缀计数当作总量。
## [br]
## @api private
static func _data_validation_report(
	measured: Dictionary,
	limits: Dictionary,
	path: String
) -> Dictionary:
	if GFVariantData.get_option_bool(measured, "ok"):
		return _validation_report()
	var report: Dictionary = _validation_report("data_invalid", path)
	report["measurement"] = measured.duplicate(true)
	report["limits"] = limits.duplicate()
	var limit_kind: String = GFVariantData.get_option_string(measured, "limit_kind")
	if not limit_kind.is_empty():
		report["error_kind"] = "budget_exceeded"
		report["limit_kind"] = limit_kind
		report["limit"] = GFVariantData.get_option_int(measured, "limit")
		report["observed"] = GFVariantData.get_option_int(measured, "observed")
		report["observed_is_lower_bound"] = GFVariantData.get_option_bool(measured, "observed_is_lower_bound")
	elif GFVariantData.get_option_string(measured, "failure_kind") == "output_limit":
		var output_limit: int = GFVariantData.get_option_int(limits, "max_output_bytes")
		report["error_kind"] = "budget_exceeded"
		report["limit_kind"] = "max_output_bytes"
		report["limit"] = output_limit
		report["observed"] = output_limit + 1
		report["observed_is_lower_bound"] = true
	return report


## 清空目录和全部观察索引，同时使旧查询失效。
## [br]
## @api private
func _clear_runtime() -> void:
	_epoch += 1
	_pending_progress.clear()
	_unregister_all_event_handlers()
	_quests.clear()
	_definitions.clear()
	_event_to_quests.clear()
	_query_to_quests.clear()
	_metric_queries.clear()
	_metric_values.clear()
	_metric_revisions.clear()
	_refreshing_metrics.clear()


## 检查项目指标身份。
## [br]
## @api private
func _valid_metric_id(metric_id: StringName) -> bool:
	var value: String = String(metric_id)
	if (
		value.is_empty()
		or value.length() > 256
		or value != value.strip_edges()
	):
		return false
	for index: int in range(value.length()):
		if value.unicode_at(index) < 32:
			return false
	return true


## 为同一指标的新来源或新输入记录修订号。
## [br]
## @api private
func _touch_metric(metric_id: StringName) -> void:
	_next_metric_revision += 1
	_metric_revisions[metric_id] = _next_metric_revision


## 将查询型指标标记为不可用，保留最后值用于诊断。
## [br]
## @api private
func _invalidate_metric(metric_id: StringName) -> void:
	if not _query_to_quests.has(metric_id):
		return
	var identities: Array = _query_to_quests[metric_id]
	var epoch: int = _epoch
	var revision: int = GFVariantData.get_option_int(_metric_revisions, metric_id)
	for quest_id: StringName in identities.duplicate():
		if epoch != _epoch or revision != GFVariantData.get_option_int(_metric_revisions, metric_id):
			return
		var data: _QuestData = _get_quest_data(quest_id)
		if _is_current_active_quest(data) and data._metric_available:
			data._metric_available = false
			_publish_progress(data)


## 更新相应任务并在每次项目回调后复核输入修订。
## [br]
## @api private
func _apply_metric_value(metric_id: StringName, value: int) -> void:
	if not _query_to_quests.has(metric_id):
		return
	var identities: Array = _query_to_quests[metric_id]
	var epoch: int = _epoch
	var revision: int = GFVariantData.get_option_int(_metric_revisions, metric_id)
	for quest_id: StringName in identities.duplicate():
		if epoch != _epoch or revision != GFVariantData.get_option_int(_metric_revisions, metric_id):
			return
		var data: _QuestData = _get_quest_data(quest_id)
		if not _is_current_active_quest(data):
			continue
		var available: bool = value >= 0 or data._definition.allows_negative()
		var changed: bool = (
			data._metric_available != available
			or (
				available
				and data._current_count != value
			)
		)
		data._metric_available = available
		if available:
			data._current_count = value
		if changed:
			_publish_progress(data)
		else:
			_maybe_complete_automatically(data)


## 入队后串行通知；通知完成后再依据最新状态执行自动完成判断。
## [br]
## @api private
func _publish_progress(data: _QuestData) -> void:
	_pending_progress[data._quest_id] = data
	_drain_progress_notifications()


## 每轮有界排空最新进度；恢复或释放会撤销旧状态队列。
## [br]
## @api private
func _drain_progress_notifications() -> void:
	if _publishing_progress:
		return
	_publishing_progress = true
	var sent: int = 0
	while (
		not _pending_progress.is_empty()
		and not _disposed
		and sent < 256
	):
		var quest_id: StringName = _pending_progress.keys()[0]
		var data: _QuestData = _pending_progress[quest_id]
		var _removed: bool = _pending_progress.erase(quest_id)
		if _get_quest_data(quest_id) != data:
			continue
		sent += 1
		var epoch: int = _epoch
		var metric_id: StringName = data._event_id
		var guards_metric: bool = (data._definition.get_mode() != GFQuestDefinition.SINCE_ACCEPTANCE and not _refreshing_metrics.has(metric_id))
		if guards_metric:
			_refreshing_metrics[metric_id] = true
		quest_progressed.emit(
			quest_id,
			data._current_count,
			data._target_count
		)
		if not _pending_progress.has(quest_id):
			_maybe_complete_automatically(data)
		if guards_metric and epoch == _epoch:
			var _guard_removed: bool = _refreshing_metrics.erase(metric_id)
	_publishing_progress = false


## 当前缓存是否允许进入完成阻塞检查。
## [br]
## @api private
func _is_eligible(data: _QuestData) -> bool:
	return (
		data._definition.get_completion() == GFQuestDefinition.EXTERNAL
		or (
			data._metric_available
			and data._current_count >= data._target_count
		)
	)


## 只对显式自动完成策略尝试提交，manual 和 external 均保持活动。
## [br]
## @api private
func _maybe_complete_automatically(data: _QuestData) -> void:
	if _is_current_active_quest(data) and data._definition.get_completion() == GFQuestDefinition.AUTOMATIC:
		var _completed: bool = _try_complete_quest(data)


## 测量整批快照，拒绝无界或不可持久化的数据。
## [br]
## @api private
func _within_snapshot_budget(snapshot: Dictionary) -> bool:
	return GFVariantData.get_option_bool(
		_validate_snapshot_budget(snapshot),
		"ok"
	)


## 恢复与导出共用整包预算；诊断只保留计量，不暴露候选状态。
## [br]
## @api private
func _validate_snapshot_budget(snapshot: Dictionary) -> Dictionary:
	var limits: Dictionary = {
		"allow_floats": true,
		"max_depth": 24,
		"max_items": 200000,
		"max_output_bytes": 16777216,
		"max_string_length": 65536,
	}
	var measured: Dictionary = GFDeterministicVariantSerializer.measure_canonical(snapshot, limits)
	return _data_validation_report(
		measured,
		limits,
		"/snapshot"
	)


## 线性验证父级存在性与无环关系，然后建立排序后的子任务索引。
## [br]
## @api private
func _link_candidate_tree(candidates: Dictionary, record_paths: Dictionary) -> Dictionary:
	for quest_id: StringName in candidates:
		var data: _QuestData = candidates[quest_id]
		if data._parent_id != &"":
			if not candidates.has(data._parent_id):
				var path: String = record_paths.get(quest_id, "/snapshot/states")
				return _validation_report(
					"missing_parent",
					path + "/parent_id"
				)
			var parent: _QuestData = candidates[data._parent_id]
			_append_packed_string(
				parent._child_ids,
				String(quest_id)
			)
	var settled: Dictionary = {}
	for quest_id: StringName in candidates:
		var cursor: StringName = quest_id
		var trail: Dictionary = {}
		while cursor != &"" and not settled.has(cursor):
			if trail.has(cursor):
				var path: String = record_paths.get(cursor, "/snapshot/states")
				return _validation_report(
					"cycle",
					path + "/parent_id"
				)
			trail[cursor] = true
			var data: _QuestData = candidates[cursor]
			cursor = data._parent_id
		for visited: StringName in trail:
			settled[visited] = true
	for quest_id: StringName in candidates:
		var data: _QuestData = candidates[quest_id]
		data._child_ids.sort()
	return _validation_report()


## 为事件创建并注册一个绑定该事件 ID 的任务监听器。
## [br]
## @api private
func _register_event_handler(event_id: StringName) -> void:
	var arch: GFArchitecture = _get_arch()
	if arch == null:
		return

	var event_handler: GFEventListener = GFEventListener.from_callable(
		Callable(self, "_on_quest_event_triggered").bind(event_id),
		1,
		"quest_event"
	)
	_event_handlers[event_id] = event_handler
	register_simple_event(event_id, event_handler)


## 注销指定事件的监听器并从注册表移除。
## [br]
## @api private
func _unregister_event_handler(event_id: StringName) -> void:
	if not _event_handlers.has(event_id):
		return

	var arch: GFArchitecture = _get_arch()
	if arch != null:
		var event_handler: GFEventListener = _get_event_handler(event_id)
		unregister_simple_event(event_id, event_handler)
	_erase_dictionary_key(_event_handlers, event_id)


## 注销已注册的全部事件监听器并清空监听器表。
## [br]
## @api private
func _unregister_all_event_handlers() -> void:
	var arch: GFArchitecture = _get_arch()
	if arch != null:
		for event_id: StringName in _event_handlers:
			var event_handler: GFEventListener = _get_event_handler(event_id)
			unregister_simple_event(event_id, event_handler)

	_event_handlers.clear()


## 返回工具当前关联的 GFArchitecture。
## [br]
## @api private
func _get_arch() -> GFArchitecture:
	return _get_architecture_or_null()


## 将两个整数相加，并在有符号 64 位边界处饱和。
## [br]
## @api private
func _add_int_saturated(left: int, right: int) -> int:
	if right > 0 and left > _INT64_MAX - right:
		return _INT64_MAX
	if right < 0 and left < _INT64_MIN - right:
		return _INT64_MIN
	return left + right


## 从冻结定义建立未接取记录。
## [br]
## @api private
func _create_quest_data(definition: GFQuestDefinition) -> _QuestData:
	var data: _QuestData = _QuestData.new()
	data._definition = definition
	data._quest_id = definition.get_quest_id()
	data._event_id = definition.get_metric_id()
	data._target_count = definition.get_target()
	data._metadata = GFVariantData.get_option_dictionary(
		definition.to_record(),
		"metadata"
	)
	return data


## 按指标模式建立受影响任务索引；仅累计模式订阅 simple event。
## [br]
## @api private
func _attach_quest_to_event(data: _QuestData) -> void:
	if data == null or data._event_id == &"":
		return
	if data._definition.get_mode() != GFQuestDefinition.SINCE_ACCEPTANCE:
		if not _query_to_quests.has(data._event_id):
			_query_to_quests[data._event_id] = []
		var queries: Array = _query_to_quests[data._event_id]
		if not queries.has(data._quest_id):
			queries.append(data._quest_id)
		return
	var should_register_handler: bool = not _event_to_quests.has(data._event_id)
	var list: Array = _ensure_event_quest_list(data._event_id)
	if should_register_handler:
		_register_event_handler(data._event_id)
	if not list.has(data._quest_id):
		list.append(data._quest_id)


## 移除任务指标索引，最后一个累计任务退出时注销事件监听。
## [br]
## @api private
func _detach_quest_from_event(data: _QuestData) -> void:
	if data == null or data._event_id == &"":
		return
	if data._definition.get_mode() != GFQuestDefinition.SINCE_ACCEPTANCE:
		if _query_to_quests.has(data._event_id):
			var queries: Array = _query_to_quests[data._event_id]
			queries.erase(data._quest_id)
			if queries.is_empty():
				var _removed: bool = _query_to_quests.erase(data._event_id)
		return
	if not _event_to_quests.has(data._event_id):
		return
	var list: Array = _get_event_quest_list(data._event_id)
	list.erase(data._quest_id)
	if list.is_empty():
		_erase_dictionary_key(_event_to_quests, data._event_id)
		_unregister_event_handler(data._event_id)


## 资格与阻塞条件均成立后提交唯一终态，回调重入不能完成旧记录。
## [br]
## @api private
func _try_complete_quest(data: _QuestData) -> bool:
	if (
		not _is_current_active_quest(data)
		or data._checking_completion
		or not _is_eligible(data)
	):
		return false
	data._checking_completion = true
	var blocker_result: Dictionary = _check_conditions(data._completion_blockers, data)
	data._checking_completion = false
	if not _is_current_active_quest(data) or not _is_eligible(data):
		return false
	if not GFVariantData.get_option_bool(blocker_result, "ok"):
		quest_completion_blocked.emit(
			data._quest_id,
			GFVariantData.get_option_string(
				blocker_result,
				"reason",
				"blocked"
			)
		)
		return false
	_detach_quest_from_event(data)
	data._is_completed = true
	data._status = STATUS_COMPLETED
	quest_completed.emit(data._quest_id)
	return true


## 对回调列表快照执行严格的 bool 或带 ok:bool 的结果协议。
## [br]
## @api private
func _check_conditions(conditions: Array[Callable], data: _QuestData) -> Dictionary:
	var initial_status: StringName = data._status
	for condition: Callable in conditions.duplicate():
		if not condition.is_valid():
			return { "ok": false, "reason": "condition_unavailable" }
		var result: Variant = condition.call(
			data._quest_id,
			data._to_dict()
		)
		if not _is_current_quest_in_status(data, initial_status):
			return { "ok": false, "reason": "state_changed" }
		if result is bool:
			if not result:
				return { "ok": false, "reason": "blocked" }
		elif result is Dictionary:
			var record: Dictionary = result
			if not record.get("ok") is bool or not record.get("reason", "") is String:
				return { "ok": false, "reason": "invalid_condition_result" }
			if not GFVariantData.get_option_bool(record, "ok"):
				return {
					"ok": false,
					"reason": GFVariantData.get_option_string(
						record,
						"reason",
						"blocked"
					),
				}
		else:
			return { "ok": false, "reason": "invalid_condition_result" }
	return { "ok": true, "reason": "" }


## 从当前父任务移除该子任务并清除其父级 ID。
## [br]
## @api private
func _detach_quest_parent(data: _QuestData) -> void:
	if data == null or data._parent_id == &"":
		return
	var parent: _QuestData = _get_quest_data(data._parent_id)
	if parent != null:
		var index: int = parent._child_ids.find(String(data._quest_id))
		if index >= 0:
			parent._child_ids.remove_at(index)
	data._parent_id = &""


## 遍历子任务关系，判断指定任务是否位于根任务后代中。
## [br]
## @api private
func _is_descendant_quest(root_quest_id: StringName, expected_descendant_id: StringName) -> bool:
	var root: _QuestData = _get_quest_data(root_quest_id)
	if root == null:
		return false
	var pending: Array[StringName] = []
	for child_id_text: String in root._child_ids:
		pending.append(StringName(child_id_text))
	var visited: Dictionary = {}
	while not pending.is_empty():
		var child_id: StringName = pending.pop_back()
		if child_id == expected_descendant_id:
			return true
		if visited.has(child_id):
			continue
		visited[child_id] = true
		var child: _QuestData = _get_quest_data(child_id)
		if child == null:
			continue
		for nested_child_id_text: String in child._child_ids:
			pending.append(StringName(nested_child_id_text))
	return false


## 以迭代后序遍历构建任务树报告和聚合完成进度。
## [br]
## @api private
func _build_quest_tree_report(data: _QuestData) -> Dictionary:
	if data == null:
		return {}
	var pending: Array[Dictionary] = [
		{ "quest_id": data._quest_id, "expanded": false, },
	]
	var scheduled: Dictionary = { data._quest_id: true }
	var reports: Dictionary = {}
	while not pending.is_empty():
		var frame: Dictionary = pending.pop_back()
		var quest_id: StringName = GFVariantData.get_option_string_name(
			frame,
			"quest_id",
			&""
		)
		var current: _QuestData = _get_quest_data(quest_id)
		if current == null:
			continue
		if not GFVariantData.get_option_bool(
			frame,
			"expanded",
			false
		):
			pending.append({ "quest_id": quest_id, "expanded": true, })
			for index: int in range(
				current._child_ids.size() - 1,
				-1,
				-1
			):
				var child_id: StringName = StringName(current._child_ids[index])
				if child_id == &"" or scheduled.has(child_id):
					continue
				scheduled[child_id] = true
				pending.append({ "quest_id": child_id, "expanded": false, })
			continue

		var children: Array[Dictionary] = []
		var total_count: int = 1
		var completed_count: int = 1 if current._status == STATUS_COMPLETED else 0
		for child_id_text: String in current._child_ids:
			var child_id: StringName = StringName(child_id_text)
			var child_report: Dictionary = _get_report_dictionary_ref(reports, child_id)
			if child_report.is_empty():
				continue
			children.append(child_report)
			total_count += GFVariantData.get_option_int(child_report, "total_count")
			completed_count += GFVariantData.get_option_int(child_report, "completed_count")

		var report: Dictionary = current._to_dict()
		report["children"] = children
		report["total_count"] = total_count
		report["completed_count"] = completed_count
		report["aggregate_progress"] = float(completed_count) / float(total_count) if total_count > 0 else 0.0
		reports[quest_id] = report
	return _get_report_dictionary_ref(reports, data._quest_id)


## 从报告表中读取指定任务报告并收窄为 Dictionary。
## [br]
## @api private
func _get_report_dictionary_ref(reports: Dictionary, quest_id: StringName) -> Dictionary:
	var value: Variant = GFVariantData.get_option_value(
		reports,
		quest_id,
		{}
	)
	if value is Dictionary:
		var report: Dictionary = value
		return report
	return {}


## 从任务表读取指定记录并收窄为内部任务数据类型。
## [br]
## @api private
func _get_quest_data(quest_id: StringName) -> _QuestData:
	return _variant_to_quest_data(GFVariantData.get_option_value(_quests, quest_id))


## 检查任务对象仍是表中当前实例且状态匹配。
## [br]
## @api private
func _is_current_quest_in_status(data: _QuestData, expected_status: StringName) -> bool:
	if data == null:
		return false
	return _get_quest_data(data._quest_id) == data and data._status == expected_status


## 检查任务记录仍是当前活动任务。
## [br]
## @api private
func _is_current_active_quest(data: _QuestData) -> bool:
	return _is_current_quest_in_status(data, STATUS_ACTIVE)


## 从事件监听器表读取并收窄指定事件的 GFEventListener。
## [br]
## @api private
func _get_event_handler(event_id: StringName) -> GFEventListener:
	var value: Variant = GFVariantData.get_option_value(_event_handlers, event_id)
	if value is GFEventListener:
		var listener: GFEventListener = value
		return listener
	return null


## 获取指定事件的任务列表；映射缺失时返回空数组。
## [br]
## @api private
func _get_event_quest_list(event_id: StringName) -> Array:
	return GFVariantData.as_array(
		GFVariantData.get_option_value(
			_event_to_quests,
			event_id,
			[]
		)
	)


## 返回已有事件任务数组，或创建并保存新的 StringName 数组。
## [br]
## @api private
func _ensure_event_quest_list(event_id: StringName) -> Array:
	if _event_to_quests.has(event_id):
		var existing_value: Variant = GFVariantData.get_option_value(
			_event_to_quests,
			event_id,
			[]
		)
		if existing_value is Array:
			return GFVariantData.as_array(existing_value)

	var list: Array[StringName] = []
	_event_to_quests[event_id] = list
	return list


## 从字典中移除指定键。
## [br]
## @api private
func _erase_dictionary_key(source: Dictionary, key: Variant) -> void:
	var _erased: bool = source.erase(key)


## 向 PackedStringArray 追加一个字符串。
## [br]
## @api private
func _append_packed_string(target: PackedStringArray, value: String) -> void:
	var _appended: bool = target.append(value)


## 将任意值收窄为内部任务数据实例，否则返回 null。
## [br]
## @api private
func _variant_to_quest_data(value: Variant) -> _QuestData:
	if value is _QuestData:
		return value
	return null


# --- 信号处理函数 ---

## 累计事件仅接受 int 或单层 amount:int；非法 payload 不产生进度。
## [br]
## @api private
func _on_quest_event_triggered(payload: Variant, event_id: StringName) -> void:
	if not _event_to_quests.has(event_id):
		return
	var amount_value: Variant = payload
	if payload is Dictionary:
		var record: Dictionary = payload
		amount_value = record.get("amount")
	if not amount_value is int:
		return
	var amount: int = amount_value
	var list: Array = _get_event_quest_list(event_id).duplicate()
	var epoch: int = _epoch
	for quest_id_variant: Variant in list:
		if epoch != _epoch:
			return
		var data: _QuestData = _get_quest_data(GFVariantData.to_string_name(quest_id_variant))
		if (
			not _is_current_active_quest(data)
			or (
				amount < 0
				and not data._definition.allows_negative()
			)
		):
			continue
		data._current_count = mini(
			_add_int_saturated(data._current_count, amount),
			data._target_count
		)
		data._metric_available = true
		_publish_progress(data)


# --- 内部类 ---

## 保存单个任务的状态、父子关系、元数据与条件回调。
## [br]
## @api private
class _QuestData extends RefCounted:


	# --- 私有变量 ---

	## 该状态使用的冻结定义。
	## [br]
	## @api private
	var _definition: GFQuestDefinition

	## 指标是否具备可用于判断的样本。
	## [br]
	## @api private
	var _metric_available: bool = false

	## 是否发生过接取，用于区分未接取时取消和失败。
	## [br]
	## @api private
	var _accepted: bool = false

	## 冻结的项目接取信息。
	## [br]
	## @api private
	var _acceptance_data: Dictionary = {}

	## 最后失败原因，独立于定义元数据。
	## [br]
	## @api private
	var _failure_reason: String = ""

	## 接取条件执行期间禁止递归接取。
	## [br]
	## @api private
	var _checking_acceptance: bool = false

	## 完成阻塞器执行期间禁止递归完成。
	## [br]
	## @api private
	var _checking_completion: bool = false

	## 任务在工具实例中的索引键。
	## [br]
	## @api private
	var _quest_id: StringName

	## 驱动此任务计数的事件标识。
	## [br]
	## @api private
	var _event_id: StringName

	## 任务达成所需的目标计数。
	## [br]
	## @api private
	var _target_count: int = 1

	## 当前累计进度，导出时与目标计数一同提供。
	## [br]
	## @api private
	var _current_count: int = 0

	## 与任务完成状态一同维护的完成标记。
	## [br]
	## @api private
	var _is_completed: bool = false

	## 任务的当前状态标识，参与回调后的实例和状态复核。
	## [br]
	## @api private
	var _status: StringName = &"available"

	## 父任务标识；空名表示没有父任务。
	## [br]
	## @api private
	var _parent_id: StringName = &""

	## 直接子任务标识列表；导出字典时复制该数组。
	## [br]
	## @api private
	var _child_ids: PackedStringArray = PackedStringArray()

	## 任务附带的数据字典；导出时使用 duplicate(true)。
	## [br]
	## @api private
	var _metadata: Dictionary = {}

	## 接受任务前运行的条件回调列表。
	## [br]
	## @api private
	var _acceptance_conditions: Array[Callable] = []

	## 完成任务前检查的阻断回调列表。
	## [br]
	## @api private
	var _completion_blockers: Array[Callable] = []


	# --- 私有/辅助方法 ---

	## 导出完整状态，不保存查询、条件或监听器。
	## [br]
	## @api private
	func _to_state_record() -> Dictionary:
		return {
			"format_version": 1,
			"definition": _definition.to_record(),
			"status": String(_status),
			"current_count": _current_count,
			"metric_available": _metric_available,
			"accepted": _accepted,
			"acceptance_data": _acceptance_data.duplicate(true),
			"parent_id": String(_parent_id),
			"failure_reason": _failure_reason,
		}


	## 导出任务状态与父子标识，复制子项列表和元数据；条件回调仅导出数量。
	## [br]
	## @api private
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
			"definition_version": _definition.get_version(),
			"metric_mode": String(_definition.get_mode()),
			"completion_policy": String(_definition.get_completion()),
			"metric_available": _metric_available,
			"eligible": _status == &"active"
			and (
				_definition.get_completion() == GFQuestDefinition.EXTERNAL
				or (
					_metric_available
					and _current_count >= _target_count
				)
			),
			"accepted": _accepted,
			"acceptance_data": _acceptance_data.duplicate(true),
		}
