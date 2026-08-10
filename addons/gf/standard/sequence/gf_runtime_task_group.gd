## 组合多个运行时任务的复合任务。
##
## [br]
## 任务组用于把多个 [GFRuntimeTask] 编排为顺序、等待全部或等待任一完成的流程。
## 子任务在组内部推进，不会单独注册到外层调度器；外层调度器只看到一个占用聚合后的任务。
## 子任务必须构成有界、无环且无重复实例的树；外层组进入调度器时会原子预留并冻结全部后代，
## 直到各后代完成或任务组结束。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 6.0.0
class_name GFRuntimeTaskGroup
extends GFRuntimeTask


# --- 枚举 ---

## 子任务推进模式。
##
## [br]
## @api public
## [br]
## @category config
## [br]
## @since 6.0.0
enum Mode {
	## 按顺序执行，每次只推进一个子任务。
	SEQUENCE,
	## 同时推进所有子任务，全部完成后任务组完成。
	PARALLEL_ALL,
	## 同时推进所有子任务，任一完成后任务组完成。
	PARALLEL_RACE,
}


# --- 常量 ---

## 子任务已被其他调度器或任务组持有时的拒绝原因。
##
## [br]
## @api public
## [br]
## @since 8.0.0
const REJECTION_CHILD_SCHEDULED: StringName = &"group_child_scheduled"

## 并行任务组存在组内 requirement 冲突时的拒绝原因。
##
## [br]
## @api public
## [br]
## @since 8.0.0
const REJECTION_PARALLEL_REQUIREMENT_CONFLICT: StringName = &"group_parallel_requirement_conflict"

## 子任务图包含 self-cycle 或祖先回边时的拒绝原因。
##
## [br]
## @api public
## [br]
## @since unreleased
const REJECTION_TASK_GRAPH_CYCLE: StringName = &"group_task_graph_cycle"

## 同一任务实例从子任务图中的多个位置可达时的拒绝原因。
##
## [br]
## @api public
## [br]
## @since unreleased
const REJECTION_TASK_GRAPH_REUSED: StringName = &"group_task_graph_reused"

## 子任务图超过框架有界遍历预算时的拒绝原因。
##
## [br]
## @api public
## [br]
## @since unreleased
const REJECTION_TASK_GRAPH_LIMIT: StringName = &"group_task_graph_limit"

## 子任务组模式不属于 [enum Mode] 闭合集合时的拒绝原因。
##
## [br]
## @api public
## [br]
## @since unreleased
const REJECTION_INVALID_MODE: StringName = &"group_invalid_mode"

## 子任务树允许的最大嵌套深度；根任务组深度为 0。
##
## [br]
## @api public
## [br]
## @since unreleased
const MAX_TASK_GRAPH_DEPTH: int = 256

## 单个任务组调度树允许的最大任务实例数，包含根任务组。
##
## [br]
## @api public
## [br]
## @since unreleased
const MAX_TASK_GRAPH_NODES: int = 4096


# --- 公共变量 ---

## [method get_mode] 为 [enum Mode.PARALLEL_RACE] 时，首个子任务完成后是否中断其他子任务。
##
## [br]
## @api public
## [br]
## @category config
## [br]
## @since 6.0.0
var cancel_remaining_on_finish: bool = true


# --- 私有变量 ---

var _scheduler_ref: WeakRef = null
var _current_index: int = 0
var _completed_task_ids: Dictionary = {}
var _initializing_task_ids: Dictionary = {}
var _tasks: Array[GFRuntimeTask] = []
var _mode: Mode = Mode.SEQUENCE


# --- Godot 生命周期方法 ---

## 创建运行时任务组。
##
## [br]
## @api public
## [br]
## @category lifecycle
## [br]
## @since 6.0.0
## [br]
## @param p_tasks: 初始子任务列表。
## [br]
## @param p_mode: 子任务推进模式。
func _init(p_tasks: Array[GFRuntimeTask] = [], p_mode: Mode = Mode.SEQUENCE) -> void:
	super._init()
	if _is_valid_mode(p_mode):
		_mode = p_mode
	else:
		push_warning("[GFRuntimeTaskGroup] 无效任务组模式，使用 SEQUENCE。")
	var _tasks_configured: bool = set_tasks(p_tasks)


# --- 公共方法 ---

## 原子替换子任务列表，并重建任务组 requirement。
##
## [br]
## @api public
## [br]
## @category config
## [br]
## @since 8.0.0
## [br]
## @param next_tasks: 新的子任务列表；不接受空值、重复/循环/超限图或已调度任务。
## [br]
## @return 全部校验通过并完成替换时返回 true。
func set_tasks(next_tasks: Array[GFRuntimeTask]) -> bool:
	if not _can_reconfigure_group():
		return false
	var candidate: Array[GFRuntimeTask] = []
	for task: GFRuntimeTask in next_tasks:
		if task == null or task.is_scheduled() or task.has_initialized() or candidate.has(task):
			return false
		candidate.append(task)
	var graph: Dictionary = _inspect_task_graph(candidate)
	if not GFVariantData.get_option_bool(graph, "ok"):
		return false
	_refresh_descendant_requirements(graph)
	if _mode != Mode.SEQUENCE and _tasks_have_parallel_requirement_conflict(candidate):
		return false
	_tasks = candidate
	_refresh_graph_requirements(graph, _tasks)
	return true


## 设置子任务推进模式。
##
## [br]
## @api public
## [br]
## @category config
## [br]
## @since 8.0.0
## [br]
## @param next_mode: 新的推进模式。
## [br]
## @return 模式有效、任务组未锁定且现有子任务满足新模式约束时返回 true。
func set_mode(next_mode: Mode) -> bool:
	if not _can_reconfigure_group():
		return false
	if not _is_valid_mode(next_mode):
		push_warning("[GFRuntimeTaskGroup] 无效任务组模式，保留当前模式。")
		return false
	var graph: Dictionary = _inspect_task_graph(_tasks)
	if not GFVariantData.get_option_bool(graph, "ok"):
		return false
	_refresh_graph_requirements(graph, _tasks)
	if next_mode != Mode.SEQUENCE and _tasks_have_parallel_requirement_conflict(_tasks):
		return false
	_mode = next_mode
	return true


## 返回子任务推进模式。
##
## [br]
## @api public
## [br]
## @category query
## [br]
## @since 8.0.0
## [br]
## @return 当前推进模式。
func get_mode() -> Mode:
	return _mode

## 添加子任务，并把子任务 requirement 合并到任务组。
##
## [br]
## @api public
## [br]
## @category config
## [br]
## @since 6.0.0
## [br]
## @param task: 要添加的子任务。
## [br]
## @return 当前任务组。
func add_task(task: GFRuntimeTask) -> GFRuntimeTaskGroup:
	if not _can_reconfigure_group():
		return self
	if task == null:
		return self
	if task.is_scheduled() or task.has_initialized():
		push_warning("[GFRuntimeTaskGroup] 已调度子任务不能加入任务组。")
		return self
	if _tasks.has(task):
		return self
	var candidate: Array[GFRuntimeTask] = _tasks.duplicate()
	candidate.append(task)
	var graph: Dictionary = _inspect_task_graph(candidate)
	if not GFVariantData.get_option_bool(graph, "ok"):
		push_warning("[GFRuntimeTaskGroup] 子任务图必须是有界、无环且无重复实例的树。")
		return self
	_refresh_descendant_requirements(graph)
	if _mode != Mode.SEQUENCE and _would_create_parallel_requirement_conflict(task):
		push_warning("[GFRuntimeTaskGroup] 并行任务组不能包含占用相同 requirement 的子任务。")
		return self
	_tasks.append(task)
	_refresh_graph_requirements(graph, _tasks)
	return self


## 移除子任务并重建任务组 requirement。
##
## [br]
## @api public
## [br]
## @category config
## [br]
## @since 6.0.0
## [br]
## @param task: 要移除的子任务。
## [br]
## @return 成功移除时返回 true。
func remove_task(task: GFRuntimeTask) -> bool:
	if not _can_reconfigure_group():
		return false
	if task == null or not _tasks.has(task):
		return false
	_tasks.erase(task)
	rebuild_requirements()
	return true


## 重建任务组 requirement 聚合。
##
## [br]
## @api public
## [br]
## @category config
## [br]
## @since 6.0.0
func rebuild_requirements() -> void:
	if not _can_reconfigure_group():
		return
	_rebuild_requirements_unchecked()


## 返回当前子任务聚合后的占用对象副本。
##
## [br]
## @api public
## [br]
## @category query
## [br]
## @since 8.0.0
## [br]
## @return 仍然有效的占用对象副本。
func get_requirements() -> Array[Object]:
	if not is_configuration_locked():
		_rebuild_requirements_unchecked()
	return super.get_requirements()


## 返回子任务副本。
##
## [br]
## @api public
## [br]
## @category query
## [br]
## @since 6.0.0
## [br]
## @return 子任务副本。
func get_tasks() -> Array[GFRuntimeTask]:
	var result: Array[GFRuntimeTask] = []
	for task: GFRuntimeTask in _tasks:
		if task != null:
			result.append(task)
	return result


## 初始化任务组。
##
## [br]
## @api public
## [br]
## @category lifecycle
## [br]
## @since 6.0.0
## [br]
## @param scheduler: 当前调度器。
func initialize(scheduler: GFRuntimeTaskScheduler) -> void:
	var group_generation: int = get_schedule_generation()
	_scheduler_ref = weakref(scheduler) if scheduler != null else null
	_current_index = 0
	_completed_task_ids.clear()
	_initializing_task_ids.clear()
	if _mode == Mode.SEQUENCE:
		_initialize_sequence_child(group_generation)
		return
	for task: GFRuntimeTask in get_tasks():
		if not is_schedule_generation_current(group_generation):
			break
		if not _initialize_child(task, group_generation):
			if not is_schedule_generation_current(group_generation):
				break


## 按帧推进任务组。
##
## [br]
## @api public
## [br]
## @category lifecycle
## [br]
## @since 6.0.0
## [br]
## @param delta: 帧间隔秒数。
func tick(delta: float) -> void:
	if _mode == Mode.SEQUENCE:
		_tick_sequence(delta, false)
		return
	_tick_parallel(delta, false)


## 按物理帧推进任务组。
##
## [br]
## @api public
## [br]
## @category lifecycle
## [br]
## @since 6.0.0
## [br]
## @param delta: 物理帧间隔秒数。
func physics_tick(delta: float) -> void:
	if _mode == Mode.SEQUENCE:
		_tick_sequence(delta, true)
		return
	_tick_parallel(delta, true)


## 判断任务组是否已经完成。
##
## [br]
## @api public
## [br]
## @category lifecycle
## [br]
## @since 6.0.0
## [br]
## @return 任务组已完成时返回 true。
func is_finished() -> bool:
	if _tasks.is_empty():
		return true
	if _mode == Mode.SEQUENCE:
		return _current_index >= _tasks.size()
	if _mode == Mode.PARALLEL_RACE:
		return not _completed_task_ids.is_empty()
	return _completed_task_ids.size() >= get_tasks().size()


## 结束任务组。
##
## [br]
## @api public
## [br]
## @category lifecycle
## [br]
## @since 6.0.0
## [br]
## @param interrupted: 为 true 时表示任务组被其他任务或调度器取消。
func end(interrupted: bool) -> void:
	if interrupted:
		_cancel_open_children(true)
	elif _mode == Mode.PARALLEL_RACE:
		_cancel_open_children(cancel_remaining_on_finish)
	_initializing_task_ids.clear()
	_scheduler_ref = null


# --- 框架内部方法 ---

## 返回任务组调度前拒绝原因。
##
## [br]
## 调度前会重新检查子任务所有权、嵌套子任务调度条件，以及并行模式下的组内
## requirement 冲突，避免后续子任务变更绕过 add_task() 的即时校验。
## [br]
## @api framework_internal
## [br]
## @category lifecycle
## [br]
## @since 8.0.0
## [br]
## @return 调度拒绝原因；为空表示可调度。
func get_schedule_rejection_reason() -> StringName:
	var parent_reason: StringName = super.get_schedule_rejection_reason()
	if parent_reason != &"":
		return parent_reason
	if not _is_valid_mode(_mode):
		return REJECTION_INVALID_MODE
	var graph: Dictionary = _inspect_task_graph(_tasks)
	if not GFVariantData.get_option_bool(graph, "ok"):
		return GFVariantData.get_option_string_name(
			graph,
			"reason",
			REJECTION_TASK_GRAPH_LIMIT
		)
	_refresh_graph_requirements(graph, _tasks)
	for task_value: Variant in GFVariantData.get_option_array(graph, "members"):
		if not (task_value is GFRuntimeTask):
			continue
		var task: GFRuntimeTask = task_value
		if task == self:
			continue
		if task.is_scheduled() or task.has_initialized():
			return REJECTION_CHILD_SCHEDULED
		if not (task is GFRuntimeTaskGroup):
			var child_reason: StringName = task.get_schedule_rejection_reason()
			if child_reason != &"":
				return child_reason
	for group_value: Variant in GFVariantData.get_option_array(graph, "groups_postorder"):
		if not (group_value is GFRuntimeTaskGroup):
			continue
		var group: GFRuntimeTaskGroup = group_value
		if not _is_valid_mode(group._mode):
			return REJECTION_INVALID_MODE
		if (
			group._mode != Mode.SEQUENCE
			and group._tasks_have_parallel_requirement_conflict(group._tasks)
		):
			return REJECTION_PARALLEL_REQUIREMENT_CONFLICT
	return &""


## 返回根任务组及其全部后代的有界、无重复调度树。
## [br]
## 图无效时返回空数组，使调度提交失败关闭。
## [br]
## @api framework_internal
## [br]
## @category lifecycle
## [br]
## @since 11.0.0
## [br]
## @return: 调度提交时必须一起冻结的任务实例列表。
func get_schedule_members() -> Array[GFRuntimeTask]:
	var graph: Dictionary = _inspect_task_graph(_tasks)
	var result: Array[GFRuntimeTask] = []
	if not GFVariantData.get_option_bool(graph, "ok"):
		return result
	for value: Variant in GFVariantData.get_option_array(graph, "members"):
		if value is GFRuntimeTask:
			var task: GFRuntimeTask = value
			result.append(task)
	return result


# --- 私有/辅助方法 ---

func _tick_sequence(delta: float, use_physics: bool) -> void:
	var group_generation: int = get_schedule_generation()
	if not is_schedule_generation_current(group_generation):
		return
	if _current_index >= _tasks.size():
		return
	var task: GFRuntimeTask = _tasks[_current_index]
	if task == null:
		_current_index += 1
		_initialize_sequence_child(group_generation)
		return
	if not _initialize_child(task, group_generation):
		return
	var child_generation: int = task.get_schedule_generation()
	if use_physics:
		task.physics_tick(delta)
	else:
		task.tick(delta)
	if (
		not is_schedule_generation_current(group_generation)
		or not task.is_schedule_generation_current(child_generation)
		or _is_child_completed(task)
	):
		return
	var child_finished: bool = task.is_finished()
	if (
		not is_schedule_generation_current(group_generation)
		or not task.is_schedule_generation_current(child_generation)
		or _is_child_completed(task)
	):
		return
	if child_finished:
		_finish_child(task, false)
		if not is_schedule_generation_current(group_generation):
			return
		_current_index += 1
		_initialize_sequence_child(group_generation)


func _tick_parallel(delta: float, use_physics: bool) -> void:
	var group_generation: int = get_schedule_generation()
	for task: GFRuntimeTask in get_tasks():
		if not is_schedule_generation_current(group_generation):
			return
		if _is_child_completed(task):
			continue
		if not _initialize_child(task, group_generation):
			continue
		var child_generation: int = task.get_schedule_generation()
		if use_physics:
			task.physics_tick(delta)
		else:
			task.tick(delta)
		if (
			not is_schedule_generation_current(group_generation)
			or not task.is_schedule_generation_current(child_generation)
			or _is_child_completed(task)
		):
			return
		var child_finished: bool = task.is_finished()
		if (
			not is_schedule_generation_current(group_generation)
			or not task.is_schedule_generation_current(child_generation)
			or _is_child_completed(task)
		):
			return
		if child_finished:
			_finish_child(task, false)
			if not is_schedule_generation_current(group_generation):
				return
			if _mode == Mode.PARALLEL_RACE:
				_cancel_open_children(cancel_remaining_on_finish)
				return


func _initialize_sequence_child(group_generation: int) -> void:
	if (
		not is_schedule_generation_current(group_generation)
		or _current_index >= _tasks.size()
	):
		return
	var task: GFRuntimeTask = _tasks[_current_index]
	if task != null:
		var _child_initialize_result: bool = _initialize_child(task, group_generation)


func _initialize_child(task: GFRuntimeTask, group_generation: int) -> bool:
	if (
		not is_schedule_generation_current(group_generation)
		or task == null
		or _is_child_completed(task)
	):
		return false
	var child_generation: int = task.get_schedule_generation()
	if not task.is_schedule_generation_current(child_generation):
		return false
	if task.has_initialized():
		return true
	_initializing_task_ids[task.get_instance_id()] = true
	task.initialize(_get_scheduler_or_null())
	var _was_initializing: bool = _initializing_task_ids.erase(task.get_instance_id())
	if (
		not is_schedule_generation_current(group_generation)
		or not task.is_schedule_generation_current(child_generation)
		or _is_child_completed(task)
	):
		return false
	task.mark_initialized()
	return true


func _finish_child(task: GFRuntimeTask, interrupted: bool) -> void:
	if task == null or _is_child_completed(task):
		return
	_completed_task_ids[task.get_instance_id()] = true
	var _was_initializing: bool = _initializing_task_ids.erase(task.get_instance_id())
	task.mark_unscheduled()
	task.end(interrupted)


func _cancel_open_children(interrupted: bool) -> void:
	for task: GFRuntimeTask in get_tasks():
		if task == null or _is_child_completed(task):
			continue
		if task.has_initialized() or _is_child_initializing(task):
			_finish_child(task, interrupted)
		elif task.is_scheduled():
			_release_uninitialized_task_tree(task)


func _is_child_completed(task: GFRuntimeTask) -> bool:
	return task != null and _completed_task_ids.has(task.get_instance_id())


func _is_child_initializing(task: GFRuntimeTask) -> bool:
	return task != null and _initializing_task_ids.has(task.get_instance_id())


func _release_uninitialized_task_tree(task: GFRuntimeTask) -> void:
	if task == null:
		return
	for member: GFRuntimeTask in task.get_schedule_members():
		if member != null and member.is_scheduled() and not member.has_initialized():
			member.mark_unscheduled()


func _get_scheduler_or_null() -> GFRuntimeTaskScheduler:
	if _scheduler_ref == null:
		return null
	var scheduler: Variant = _scheduler_ref.get_ref()
	if scheduler is GFRuntimeTaskScheduler:
		return scheduler
	return null


func _rebuild_requirements_unchecked() -> void:
	var graph: Dictionary = _inspect_task_graph(_tasks)
	if not GFVariantData.get_option_bool(graph, "ok"):
		return
	_refresh_graph_requirements(graph, _tasks)


func _rebuild_direct_requirements_unchecked(source_tasks: Array[GFRuntimeTask]) -> void:
	var aggregate_requirements: Array[Object] = []
	for task: GFRuntimeTask in source_tasks:
		if task == null:
			continue
		for requirement: Object in _get_child_requirements(task):
			if not aggregate_requirements.has(requirement):
				aggregate_requirements.append(requirement)
	_replace_requirements_unchecked(aggregate_requirements)


func _tasks_have_parallel_requirement_conflict(source_tasks: Array[GFRuntimeTask]) -> bool:
	var owners_by_requirement_id: Dictionary = {}
	for task: GFRuntimeTask in source_tasks:
		if task == null:
			continue
		for requirement: Object in _get_child_requirements(task):
			if requirement == null or not is_instance_valid(requirement):
				continue
			var requirement_id: int = requirement.get_instance_id()
			if owners_by_requirement_id.has(requirement_id):
				return true
			owners_by_requirement_id[requirement_id] = task
	return false


func _would_create_parallel_requirement_conflict(next_task: GFRuntimeTask) -> bool:
	for next_requirement: Object in _get_child_requirements(next_task):
		if next_requirement == null or not is_instance_valid(next_requirement):
			continue
		for task: GFRuntimeTask in _tasks:
			if task != null and _get_child_requirements(task).has(next_requirement):
				return true
	return false


func _get_child_requirements(task: GFRuntimeTask) -> Array[Object]:
	if task == null:
		return []
	if task is GFRuntimeTaskGroup:
		return task.get_requirement_snapshot()
	return task.get_requirements()


func _refresh_descendant_requirements(graph: Dictionary) -> void:
	for group_value: Variant in GFVariantData.get_option_array(graph, "groups_postorder"):
		if not (group_value is GFRuntimeTaskGroup):
			continue
		var group: GFRuntimeTaskGroup = group_value
		if group == self:
			continue
		group._rebuild_direct_requirements_unchecked(group._tasks)


func _refresh_graph_requirements(
	graph: Dictionary,
	root_tasks: Array[GFRuntimeTask]
) -> void:
	for group_value: Variant in GFVariantData.get_option_array(graph, "groups_postorder"):
		if not (group_value is GFRuntimeTaskGroup):
			continue
		var group: GFRuntimeTaskGroup = group_value
		group._rebuild_direct_requirements_unchecked(
			root_tasks if group == self else group._tasks
		)


func _inspect_task_graph(root_tasks: Array[GFRuntimeTask]) -> Dictionary:
	var visit_states: Dictionary = {
		get_instance_id(): 1,
	}
	var members: Array[GFRuntimeTask] = [self]
	var groups_postorder: Array[GFRuntimeTaskGroup] = []
	var frames: Array[Dictionary] = [{
		"group": self,
		"children": root_tasks,
		"next_index": 0,
		"depth": 0,
	}]

	while not frames.is_empty():
		var frame_index: int = frames.size() - 1
		var frame: Dictionary = frames[frame_index]
		var children: Array = GFVariantData.get_option_array(frame, "children")
		var next_index: int = GFVariantData.get_option_int(frame, "next_index")
		if next_index >= children.size():
			var completed_group_value: Variant = GFVariantData.get_option_value(frame, "group")
			if not (completed_group_value is GFRuntimeTaskGroup):
				return _make_graph_inspection_failure(REJECTION_TASK_GRAPH_REUSED)
			var completed_group: GFRuntimeTaskGroup = completed_group_value
			visit_states[completed_group.get_instance_id()] = 2
			groups_postorder.append(completed_group)
			frames.pop_back()
			continue

		frame["next_index"] = next_index + 1
		frames[frame_index] = frame
		var child_value: Variant = children[next_index]
		if not (child_value is GFRuntimeTask):
			return _make_graph_inspection_failure(REJECTION_TASK_GRAPH_REUSED)
		var child: GFRuntimeTask = child_value
		if child == null or not is_instance_valid(child):
			return _make_graph_inspection_failure(REJECTION_TASK_GRAPH_REUSED)
		var child_id: int = child.get_instance_id()
		if visit_states.has(child_id):
			var visit_state: int = GFVariantData.to_int(visit_states[child_id])
			return _make_graph_inspection_failure(
				REJECTION_TASK_GRAPH_CYCLE
				if visit_state == 1
				else REJECTION_TASK_GRAPH_REUSED
			)

		var child_depth: int = GFVariantData.get_option_int(frame, "depth") + 1
		if (
			child_depth > MAX_TASK_GRAPH_DEPTH
			or members.size() >= MAX_TASK_GRAPH_NODES
		):
			return _make_graph_inspection_failure(REJECTION_TASK_GRAPH_LIMIT)
		visit_states[child_id] = 1
		members.append(child)
		if child is GFRuntimeTaskGroup:
			var child_group: GFRuntimeTaskGroup = child
			frames.append({
				"group": child_group,
				"children": child_group._tasks,
				"next_index": 0,
				"depth": child_depth,
			})
		else:
			visit_states[child_id] = 2

	return {
		"ok": true,
		"reason": &"",
		"members": members,
		"groups_postorder": groups_postorder,
	}


func _make_graph_inspection_failure(reason: StringName) -> Dictionary:
	return {
		"ok": false,
		"reason": reason,
		"members": [],
		"groups_postorder": [],
	}


func _is_valid_mode(value: Variant) -> bool:
	return (
		value is int
		and (
			value == Mode.SEQUENCE
			or value == Mode.PARALLEL_ALL
			or value == Mode.PARALLEL_RACE
		)
	)


func _can_reconfigure_group() -> bool:
	if not is_configuration_locked():
		return true
	push_warning("[GFRuntimeTaskGroup] 调度仲裁中或已调度的任务组不能修改配置。")
	return false
