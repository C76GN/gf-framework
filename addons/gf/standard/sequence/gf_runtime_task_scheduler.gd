## 按 requirement 仲裁运行时任务的调度器。
##
## [br]
## 调度器负责维护正在运行的 [GFRuntimeTask]、处理 requirement 冲突、执行可中断任务、
## 并在 requirement 空闲时恢复默认任务。它只提供通用生命周期与资源占用语义，不绑定输入、
## 动画、角色控制器或项目业务状态。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 6.0.0
class_name GFRuntimeTaskScheduler
extends GFUtility


# --- 信号 ---

## 任务成功进入调度器时发出。
##
## [br]
## @api public
## [br]
## @category event
## [br]
## @since 6.0.0
## [br]
## @param task: 成功进入调度器的任务。
signal task_scheduled(task: GFRuntimeTask)

## 任务因为冲突或无效参数被拒绝时发出。
##
## [br]
## @api public
## [br]
## @category event
## [br]
## @since 6.0.0
## [br]
## @param task: 被拒绝的任务。
## [br]
## @param reason: 拒绝原因。
signal task_rejected(task: GFRuntimeTask, reason: StringName)

## 任务正常完成时发出。
##
## [br]
## @api public
## [br]
## @category event
## [br]
## @since 6.0.0
## [br]
## @param task: 正常完成的任务。
signal task_completed(task: GFRuntimeTask)

## 任务被取消或中断时发出。
##
## [br]
## @api public
## [br]
## @category event
## [br]
## @since 6.0.0
## [br]
## @param task: 被取消或中断的任务。
signal task_cancelled(task: GFRuntimeTask)


# --- 常量 ---

## 调度器正在提交另一项任务所有权变更时的拒绝原因。
##
## [br]
## @api public
## [br]
## @since 8.0.0
const REJECTION_SCHEDULER_BUSY: StringName = &"scheduler_busy"


# --- 公共变量 ---

## Requirement 空闲时是否自动调度已注册的默认任务。
##
## [br]
## @api public
## [br]
## @category config
## [br]
## @since 6.0.0
var auto_schedule_default_tasks: bool = true


# --- 私有变量 ---

var _active_tasks: Array[GFRuntimeTask] = []
var _requirement_owners: Dictionary = {}
var _default_tasks: Dictionary = {}
var _schedule_resolution_active: bool = false
var _dispose_active: bool = false


# --- Godot 生命周期方法 ---

## 创建运行时任务调度器。
##
## [br]
## @api public
## [br]
## @category lifecycle
## [br]
## @since 6.0.0
func _init() -> void:
	tick_enabled = true
	physics_tick_enabled = true


# --- 公共方法 ---

## 调度一个任务。
##
## [br]
## 若任务 requirement 被不可中断任务占用，本方法返回 [code]false[/code] 并发出
## [signal task_rejected]。若冲突任务可中断，调度器会先取消冲突任务再调度新任务。
## [br]
## @api public
## [br]
## @category task
## [br]
## @since 6.0.0
## [br]
## @param task: 要调度的任务。
## [br]
## @return 成功进入调度器或已在调度器中时返回 true。
func schedule(task: GFRuntimeTask) -> bool:
	if task == null:
		task_rejected.emit(task, &"invalid_task")
		return false
	if _schedule_resolution_active or _dispose_active:
		task_rejected.emit(task, REJECTION_SCHEDULER_BUSY)
		return false
	if is_scheduled(task):
		return true
	if task.is_scheduled():
		task_rejected.emit(task, &"already_scheduled")
		return false
	var rejection_reason: StringName = task.get_schedule_rejection_reason()
	if rejection_reason != &"":
		task_rejected.emit(task, rejection_reason)
		return false
	var requirements: Array[Object] = task.get_requirements()
	task.begin_schedule_resolution()
	_schedule_resolution_active = true
	var current_index_result: Dictionary = _build_requirement_owner_index(_active_tasks)
	if not GFVariantData.get_option_bool(current_index_result, "ok", false):
		_schedule_resolution_active = false
		task.end_schedule_resolution()
		task_rejected.emit(task, &"requirement_index_invalid")
		return false
	var current_index: Dictionary = GFVariantData.get_option_dictionary(
		current_index_result,
		"index"
	)
	_requirement_owners = current_index
	var conflicts: Array[GFRuntimeTask] = _get_conflicting_tasks(requirements, current_index)
	for conflict: GFRuntimeTask in conflicts:
		if conflict != null and not conflict.is_interruptible():
			_schedule_resolution_active = false
			task.end_schedule_resolution()
			task_rejected.emit(task, &"requirement_busy")
			return false

	var proposed_tasks: Array[GFRuntimeTask] = []
	for active_task: GFRuntimeTask in _active_tasks:
		if not conflicts.has(active_task):
			proposed_tasks.append(active_task)
	proposed_tasks.append(task)
	var proposed_index_result: Dictionary = _build_requirement_owner_index(proposed_tasks, task)
	if not GFVariantData.get_option_bool(proposed_index_result, "ok", false):
		_schedule_resolution_active = false
		task.end_schedule_resolution()
		task_rejected.emit(task, &"requirement_index_invalid")
		return false

	for conflict: GFRuntimeTask in conflicts:
		conflict.mark_unscheduled()
	task.mark_scheduled()
	_active_tasks = proposed_tasks
	_requirement_owners = GFVariantData.get_option_dictionary(proposed_index_result, "index")
	for conflict: GFRuntimeTask in conflicts:
		_end_detached_task(conflict, true)
	_schedule_resolution_active = false
	task_scheduled.emit(task)
	return true


## 取消一个任务。
##
## [br]
## @api public
## [br]
## @category task
## [br]
## @since 6.0.0
## [br]
## @param task: 要取消的任务。
## [br]
## @return 成功取消时返回 true。
func cancel(task: GFRuntimeTask) -> bool:
	if _schedule_resolution_active or _dispose_active:
		return false
	if task == null or not is_scheduled(task):
		return false
	return _finish_task(task, true)


## 取消所有任务。
##
## [br]
## @api public
## [br]
## @category task
## [br]
## @since 6.0.0
func cancel_all() -> void:
	var snapshot: Array[GFRuntimeTask] = get_active_tasks()
	for task: GFRuntimeTask in snapshot:
		var _cancel_result: bool = cancel(task)


## 注册 requirement 空闲时应运行的默认任务。
##
## [br]
## 默认任务会自动添加该 requirement。若任务需要占用更多对象，可在注册前或注册后继续
## 调用 [method GFRuntimeTask.add_requirement]。
## [br]
## @api public
## [br]
## @category task
## [br]
## @since 6.0.0
## [br]
## @param requirement: 空闲时应恢复默认任务的对象。
## [br]
## @param task: 默认任务。
## [br]
## @return 注册成功时返回 true。
func register_default_task(requirement: Object, task: GFRuntimeTask) -> bool:
	if (
		_schedule_resolution_active
		or _dispose_active
		or requirement == null
		or not is_instance_valid(requirement)
		or task == null
	):
		return false
	if not task.has_requirement(requirement):
		var _add_requirement_result: GFRuntimeTask = task.add_requirement(requirement)
		if not task.has_requirement(requirement):
			return false
	_default_tasks[requirement.get_instance_id()] = {
		"requirement_ref": weakref(requirement),
		"task": task,
	}
	return true


## 注销 requirement 的默认任务。
##
## [br]
## @api public
## [br]
## @category task
## [br]
## @since 6.0.0
## [br]
## @param requirement: 要注销默认任务的对象。
## [br]
## @return 注销成功时返回 true。
func unregister_default_task(requirement: Object) -> bool:
	if (
		_schedule_resolution_active
		or _dispose_active
		or requirement == null
		or not is_instance_valid(requirement)
	):
		return false
	return _default_tasks.erase(requirement.get_instance_id())


## 返回 requirement 的默认任务。
##
## [br]
## @api public
## [br]
## @category query
## [br]
## @since 6.0.0
## [br]
## @param requirement: 要查询默认任务的对象。
## [br]
## @return requirement 对应的默认任务；不存在时返回 null。
func get_default_task(requirement: Object) -> GFRuntimeTask:
	if requirement == null or not is_instance_valid(requirement):
		return null
	var value: Variant = _default_tasks.get(requirement.get_instance_id(), null)
	var record: Dictionary = _default_record_from_value(value)
	if _default_record_requirement(record) == requirement:
		return _default_record_task(record)
	return null


## 判断任务是否正在调度器中运行。
##
## [br]
## @api public
## [br]
## @category query
## [br]
## @since 6.0.0
## [br]
## @param task: 要检查的任务。
## [br]
## @return 任务正在调度器中运行时返回 true。
func is_scheduled(task: GFRuntimeTask) -> bool:
	return task != null and _active_tasks.has(task)


## 判断 requirement 是否空闲。
##
## [br]
## @api public
## [br]
## @category query
## [br]
## @since 6.0.0
## [br]
## @param requirement: 要检查的对象。
## [br]
## @return requirement 当前没有任务占用时返回 true。
func is_requirement_available(requirement: Object) -> bool:
	return get_task_for_requirement(requirement) == null


## 返回当前占用 requirement 的任务。
##
## [br]
## @api public
## [br]
## @category query
## [br]
## @since 6.0.0
## [br]
## @param requirement: 要查询占用任务的对象。
## [br]
## @return 当前占用 requirement 的任务；不存在时返回 null。
func get_task_for_requirement(requirement: Object) -> GFRuntimeTask:
	if requirement == null or not is_instance_valid(requirement):
		return null
	return _get_task_for_requirement_from_index(requirement, _requirement_owners)


## 返回当前活动任务副本。
##
## [br]
## @api public
## [br]
## @category query
## [br]
## @since 6.0.0
## [br]
## @return 当前活动任务副本。
func get_active_tasks() -> Array[GFRuntimeTask]:
	var result: Array[GFRuntimeTask] = []
	for task: GFRuntimeTask in _active_tasks:
		if task != null:
			result.append(task)
	return result


## 推进活动任务。
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
	_run_tasks(delta, false)


## 推进活动任务的物理帧逻辑。
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
	_run_tasks(delta, true)


## 释放调度器持有的任务。
##
## [br]
## @api public
## [br]
## @category lifecycle
## [br]
## @since 6.0.0
func dispose() -> void:
	if _schedule_resolution_active or _dispose_active:
		return
	_dispose_active = true
	var snapshot: Array[GFRuntimeTask] = get_active_tasks()
	for task: GFRuntimeTask in snapshot:
		task.mark_unscheduled()
	_active_tasks = []
	_requirement_owners = {}
	_default_tasks.clear()
	for task: GFRuntimeTask in snapshot:
		_end_detached_task(task, true)
	_default_tasks.clear()
	_dispose_active = false


## 返回调度器诊断快照。
##
## [br]
## @api public
## [br]
## @category diagnostics
## [br]
## @since 6.0.0
## [br]
## @return 调度器诊断快照。
## [br]
## @schema return: Dictionary with active_tasks, requirement_owner_ids, and default_requirement_ids.
func get_debug_snapshot() -> Dictionary:
	_prune_invalid_default_tasks()
	var requirement_index_valid: bool = _rebuild_requirement_owner_index()
	var task_snapshots: Array[Dictionary] = []
	for task: GFRuntimeTask in get_active_tasks():
		task_snapshots.append(task.get_debug_snapshot())
	return {
		"active_tasks": task_snapshots,
		"requirement_owner_ids": (
			_requirement_owners.keys()
			if requirement_index_valid
			else []
		),
		"default_requirement_ids": _default_tasks.keys(),
	}


# --- 私有/辅助方法 ---

func _run_tasks(delta: float, use_physics: bool) -> void:
	if _schedule_resolution_active or _dispose_active:
		return
	if not _rebuild_requirement_owner_index():
		return
	var snapshot: Array[GFRuntimeTask] = get_active_tasks()
	for task: GFRuntimeTask in snapshot:
		if not is_scheduled(task):
			continue
		if not _ensure_initialized(task):
			continue
		if use_physics:
			task.physics_tick(delta)
		else:
			task.tick(delta)
		if not is_scheduled(task):
			continue
		if task.is_finished():
			var _finished: bool = _finish_task(task, false)
	if auto_schedule_default_tasks:
		_schedule_available_defaults()


func _ensure_initialized(task: GFRuntimeTask) -> bool:
	if task == null:
		return false
	if task.has_initialized():
		return true
	task.initialize(self)
	if not is_scheduled(task):
		return false
	task.mark_initialized()
	return true


func _finish_task(task: GFRuntimeTask, interrupted: bool) -> bool:
	if task == null or not _active_tasks.has(task):
		return false
	if not _detach_task(task):
		return false
	_end_detached_task(task, interrupted)
	return true


func _detach_task(task: GFRuntimeTask) -> bool:
	if task == null or not _active_tasks.has(task):
		return false
	var proposed_tasks: Array[GFRuntimeTask] = []
	for active_task: GFRuntimeTask in _active_tasks:
		if active_task != task:
			proposed_tasks.append(active_task)
	var proposed_index_result: Dictionary = _build_requirement_owner_index(proposed_tasks)
	if not GFVariantData.get_option_bool(proposed_index_result, "ok", false):
		return false
	task.mark_unscheduled()
	_active_tasks = proposed_tasks
	_requirement_owners = GFVariantData.get_option_dictionary(proposed_index_result, "index")
	return true


func _end_detached_task(task: GFRuntimeTask, interrupted: bool) -> void:
	if task == null:
		return
	task.end(interrupted)
	if interrupted:
		task_cancelled.emit(task)
	else:
		task_completed.emit(task)


func _build_requirement_owner_index(
	tasks: Array[GFRuntimeTask],
	pending_task: GFRuntimeTask = null
) -> Dictionary:
	var candidate: Dictionary = {}
	for task: GFRuntimeTask in tasks:
		if task == null:
			return {
				"ok": false,
				"reason": &"invalid_task",
				"index": {},
			}
		if task != pending_task and not task.is_scheduled():
			return {
				"ok": false,
				"reason": &"unscheduled_task",
				"index": {},
			}
		for requirement: Object in task.get_requirements():
			var requirement_id: int = requirement.get_instance_id()
			if candidate.has(requirement_id):
				var existing_record: Dictionary = GFVariantData.get_option_dictionary(
					candidate,
					requirement_id
				)
				var existing_owner: GFRuntimeTask = _get_requirement_record_task(existing_record)
				if existing_owner != task:
					return {
						"ok": false,
						"reason": &"duplicate_requirement_owner",
						"index": {},
					}
				continue
			candidate[requirement_id] = {
				"requirement_ref": weakref(requirement),
				"task": task,
			}
	return {
		"ok": true,
		"reason": &"ok",
		"index": candidate,
	}


func _rebuild_requirement_owner_index() -> bool:
	var build_result: Dictionary = _build_requirement_owner_index(_active_tasks)
	if not GFVariantData.get_option_bool(build_result, "ok", false):
		return false
	_requirement_owners = GFVariantData.get_option_dictionary(build_result, "index")
	return true


func _get_task_for_requirement_from_index(
	requirement: Object,
	owner_index: Dictionary
) -> GFRuntimeTask:
	if requirement == null or not is_instance_valid(requirement):
		return null
	var record: Dictionary = GFVariantData.get_option_dictionary(
		owner_index,
		requirement.get_instance_id()
	)
	if _get_requirement_record_requirement(record) != requirement:
		return null
	var task: GFRuntimeTask = _get_requirement_record_task(record)
	if task == null or not is_scheduled(task) or not task.has_requirement(requirement):
		return null
	return task


func _get_requirement_record_task(record: Dictionary) -> GFRuntimeTask:
	var value: Variant = GFVariantData.get_option_value(record, "task")
	if value is GFRuntimeTask:
		var task: GFRuntimeTask = value
		return task
	return null


func _get_requirement_record_requirement(record: Dictionary) -> Object:
	var value: Variant = GFVariantData.get_option_value(record, "requirement_ref")
	if not value is WeakRef:
		return null
	var requirement_ref: WeakRef = value
	var requirement_value: Variant = requirement_ref.get_ref()
	if requirement_value is Object:
		var requirement: Object = requirement_value
		if is_instance_valid(requirement):
			return requirement
	return null


func _get_conflicting_tasks(
	requirements: Array[Object],
	owner_index: Dictionary
) -> Array[GFRuntimeTask]:
	var conflicts: Array[GFRuntimeTask] = []
	for requirement: Object in requirements:
		var owner: GFRuntimeTask = _get_task_for_requirement_from_index(
			requirement,
			owner_index
		)
		if owner != null and not conflicts.has(owner):
			conflicts.append(owner)
	return conflicts


func _schedule_available_defaults() -> void:
	_prune_invalid_default_tasks()
	if not _rebuild_requirement_owner_index():
		return
	for key: Variant in _default_tasks.keys():
		var record: Dictionary = _default_record_from_value(_default_tasks.get(key, null))
		var requirement: Object = _default_record_requirement(record)
		if requirement == null:
			var _removed_invalid_default: bool = _default_tasks.erase(key)
			continue
		if _requirement_owners.has(key):
			continue
		var task: GFRuntimeTask = _default_record_task(record)
		if task == null:
			var _removed_null_default: bool = _default_tasks.erase(key)
			continue
		if is_scheduled(task):
			continue
		if _has_busy_requirement(task):
			continue
		var _schedule_result: bool = schedule(task)


func _has_busy_requirement(task: GFRuntimeTask) -> bool:
	for requirement: Object in task.get_requirements():
		if _get_task_for_requirement_from_index(requirement, _requirement_owners) != null:
			return true
	return false


func _prune_invalid_default_tasks() -> void:
	for key: Variant in _default_tasks.keys():
		var record: Dictionary = _default_record_from_value(_default_tasks.get(key, null))
		if _default_record_requirement(record) == null or _default_record_task(record) == null:
			var _removed_invalid_default: bool = _default_tasks.erase(key)


func _default_record_from_value(value: Variant) -> Dictionary:
	if value is Dictionary:
		var record: Dictionary = value
		return record
	if value is GFRuntimeTask:
		var task: GFRuntimeTask = value
		return { "task": task }
	return {}


func _default_record_task(record: Dictionary) -> GFRuntimeTask:
	var value: Variant = GFVariantData.get_option_value(record, "task")
	if value is GFRuntimeTask:
		var task: GFRuntimeTask = value
		return task
	return null


func _default_record_requirement(record: Dictionary) -> Object:
	var value: Variant = GFVariantData.get_option_value(record, "requirement_ref")
	if value is WeakRef:
		var requirement_ref: WeakRef = value
		var requirement: Variant = requirement_ref.get_ref()
		if requirement is Object:
			var object_ref: Object = requirement
			if is_instance_valid(object_ref):
				return object_ref
	return null
