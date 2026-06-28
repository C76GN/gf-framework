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
	if is_scheduled(task):
		return true
	if task.is_scheduled():
		task_rejected.emit(task, &"already_scheduled")
		return false
	var conflicts: Array[GFRuntimeTask] = _get_conflicting_tasks(task)
	for conflict: GFRuntimeTask in conflicts:
		if conflict != null and not conflict.is_interruptible():
			task_rejected.emit(task, &"requirement_busy")
			return false
	for conflict: GFRuntimeTask in conflicts:
		var _cancel_result: bool = cancel(conflict)
	_active_tasks.append(task)
	_assign_requirements(task)
	task.mark_scheduled()
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
	if task == null or not is_scheduled(task):
		return false
	_finish_task(task, true)
	return true


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
	if requirement == null or not is_instance_valid(requirement) or task == null:
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
	if requirement == null or not is_instance_valid(requirement):
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
	var key: int = requirement.get_instance_id()
	var value: Variant = _requirement_owners.get(key, null)
	if value is GFRuntimeTask:
		var task: GFRuntimeTask = value
		if is_scheduled(task):
			return task
	var _erase_result: bool = _requirement_owners.erase(key)
	return null


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
	cancel_all()
	_requirement_owners.clear()
	_default_tasks.clear()


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
	var task_snapshots: Array[Dictionary] = []
	for task: GFRuntimeTask in get_active_tasks():
		task_snapshots.append(task.get_debug_snapshot())
	return {
		"active_tasks": task_snapshots,
		"requirement_owner_ids": _requirement_owners.keys(),
		"default_requirement_ids": _default_tasks.keys(),
	}


# --- 私有/辅助方法 ---

func _run_tasks(delta: float, use_physics: bool) -> void:
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
			_finish_task(task, false)
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


func _finish_task(task: GFRuntimeTask, interrupted: bool) -> void:
	if task == null or not _active_tasks.has(task):
		return
	_active_tasks.erase(task)
	_release_requirements(task)
	if task.is_scheduled():
		task.end(interrupted)
	task.mark_unscheduled()
	if interrupted:
		task_cancelled.emit(task)
	else:
		task_completed.emit(task)


func _assign_requirements(task: GFRuntimeTask) -> void:
	for requirement: Object in task.get_requirements():
		_requirement_owners[requirement.get_instance_id()] = task


func _release_requirements(task: GFRuntimeTask) -> void:
	var keys_to_remove: Array[int] = []
	for key: Variant in _requirement_owners.keys():
		if _requirement_owners.get(key, null) == task:
			if key is int:
				var requirement_id: int = key
				keys_to_remove.append(requirement_id)
	for key: int in keys_to_remove:
		var _erase_result: bool = _requirement_owners.erase(key)


func _get_conflicting_tasks(task: GFRuntimeTask) -> Array[GFRuntimeTask]:
	var conflicts: Array[GFRuntimeTask] = []
	for requirement: Object in task.get_requirements():
		var owner: GFRuntimeTask = get_task_for_requirement(requirement)
		if owner != null and owner != task and not conflicts.has(owner):
			conflicts.append(owner)
	return conflicts


func _schedule_available_defaults() -> void:
	_prune_invalid_default_tasks()
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
		if get_task_for_requirement(requirement) != null:
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
