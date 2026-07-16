## 可被运行时调度器管理的通用任务协议。
##
## [br]
## Runtime task 用于描述“占用一组运行时对象并按帧推进”的行为单元，例如角色默认状态、
## 临时交互、工具模式或项目自定义流程。任务只声明依赖、生命周期和完成条件，不解释业务含义。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 6.0.0
class_name GFRuntimeTask
extends RefCounted


# --- 公共变量 ---

## 调试和诊断用任务标识。
##
## [br]
## @api public
## [br]
## @category state
## [br]
## @since 6.0.0
var task_id: StringName = &""

## 当其他任务请求相同 requirement 时，当前任务是否允许被中断。
##
## [br]
## @api public
## [br]
## @category state
## [br]
## @since 6.0.0
var interruptible: bool = true


# --- 私有变量 ---

var _requirements: Array[Object] = []
var _scheduled: bool = false
var _initialized: bool = false
var _schedule_resolution_locked: bool = false


# --- Godot 生命周期方法 ---

## 创建运行时任务。
##
## [br]
## @api public
## [br]
## @category lifecycle
## [br]
## @since 6.0.0
## [br]
## @param p_requirements: 初始占用对象列表。
## [br]
## @param p_interruptible: 任务是否允许被其他任务中断。
func _init(p_requirements: Array[Object] = [], p_interruptible: bool = true) -> void:
	interruptible = p_interruptible
	var _set_requirements_result: GFRuntimeTask = set_requirements(p_requirements)


# --- 公共方法 ---

## 替换任务占用对象列表。
##
## [br]
## @api public
## [br]
## @category config
## [br]
## @since 6.0.0
## [br]
## @param next_requirements: 新的占用对象列表。
## [br]
## @return 当前任务。
func set_requirements(next_requirements: Array[Object]) -> GFRuntimeTask:
	if not _can_mutate_requirements():
		return self
	_requirements.clear()
	for requirement: Object in next_requirements:
		var _add_requirement_result: GFRuntimeTask = add_requirement(requirement)
	return self


## 添加一个占用对象。
##
## [br]
## @api public
## [br]
## @category config
## [br]
## @since 6.0.0
## [br]
## @param requirement: 要添加的占用对象。
## [br]
## @return 当前任务。
func add_requirement(requirement: Object) -> GFRuntimeTask:
	if not _can_mutate_requirements():
		return self
	if requirement == null or not is_instance_valid(requirement):
		return self
	if _requirements.has(requirement):
		return self
	_requirements.append(requirement)
	return self


## 移除一个占用对象。
##
## [br]
## @api public
## [br]
## @category config
## [br]
## @since 6.0.0
## [br]
## @param requirement: 要移除的占用对象。
## [br]
## @return 成功移除时返回 true。
func remove_requirement(requirement: Object) -> bool:
	if not _can_mutate_requirements():
		return false
	if requirement == null:
		return false
	if not _requirements.has(requirement):
		return false
	_requirements.erase(requirement)
	return true


## 清空占用对象列表。
##
## [br]
## @api public
## [br]
## @category config
## [br]
## @since 6.0.0
func clear_requirements() -> void:
	if not _can_mutate_requirements():
		return
	_requirements.clear()


## 返回仍然有效的占用对象副本。
##
## [br]
## @api public
## [br]
## @category query
## [br]
## @since 6.0.0
## [br]
## @return 仍然有效的占用对象副本。
func get_requirements() -> Array[Object]:
	var result: Array[Object] = []
	for requirement: Object in _requirements:
		if requirement != null and is_instance_valid(requirement):
			result.append(requirement)
	return result


## 判断任务是否占用指定对象。
##
## [br]
## @api public
## [br]
## @category query
## [br]
## @since 6.0.0
## [br]
## @param requirement: 要检查的占用对象。
## [br]
## @return 任务占用该对象时返回 true。
## [br]
## @schema requirement: Object requirement reference; released or non-Object values return false.
func has_requirement(requirement: Variant) -> bool:
	if typeof(requirement) != TYPE_OBJECT or not is_instance_valid(requirement):
		return false
	var requirement_object: Object = requirement
	return _requirements.has(requirement_object)


## 设置任务是否可中断。
##
## [br]
## @api public
## [br]
## @category config
## [br]
## @since 6.0.0
## [br]
## @param value: 是否允许被中断。
## [br]
## @return 当前任务。
func set_interruptible(value: bool) -> GFRuntimeTask:
	interruptible = value
	return self


## 判断任务是否可中断。
##
## [br]
## @api public
## [br]
## @category query
## [br]
## @since 6.0.0
## [br]
## @return 任务允许被中断时返回 true。
func is_interruptible() -> bool:
	return interruptible


## 判断任务是否已经进入调度器。
##
## [br]
## @api public
## [br]
## @category query
## [br]
## @since 6.0.0
## [br]
## @return 任务已经进入调度器时返回 true。
func is_scheduled() -> bool:
	return _scheduled


## 判断任务本轮调度是否已经初始化。
##
## [br]
## @api public
## [br]
## @category query
## [br]
## @since 6.0.0
## [br]
## @return 本轮调度已经完成初始化时返回 true。
func has_initialized() -> bool:
	return _initialized


## 初始化任务。
##
## [br]
## 调度器会在第一次推进任务前调用此方法。子类可在此读取架构、准备本轮状态或发出开始事件。
## [br]
## @api public
## [br]
## @category lifecycle
## [br]
## @since 6.0.0
## [br]
## @param _scheduler: 当前调度器。
func initialize(_scheduler: GFRuntimeTaskScheduler) -> void:
	pass


## 按帧推进任务。
##
## [br]
## @api public
## [br]
## @category lifecycle
## [br]
## @since 6.0.0
## [br]
## @param _delta: 帧间隔秒数。
func tick(_delta: float) -> void:
	pass


## 按物理帧推进任务。
##
## [br]
## @api public
## [br]
## @category lifecycle
## [br]
## @since 6.0.0
## [br]
## @param _delta: 物理帧间隔秒数。
func physics_tick(_delta: float) -> void:
	pass


## 判断任务是否已经完成。
##
## [br]
## 默认任务会在初始化后的第一次检查中完成。需要跨帧运行的任务应重写此方法。
## [br]
## @api public
## [br]
## @category lifecycle
## [br]
## @since 6.0.0
## [br]
## @return 任务已完成时返回 true。
func is_finished() -> bool:
	return true


## 结束任务。
##
## [br]
## [param interrupted] 为 [code]true[/code] 时表示任务被其他任务或调度器取消。
## [br]
## @api public
## [br]
## @category lifecycle
## [br]
## @since 6.0.0
## [br]
## @param _interrupted: 为 true 时表示任务被其他任务或调度器取消。
func end(_interrupted: bool) -> void:
	pass


## 返回任务诊断快照。
##
## [br]
## @api public
## [br]
## @category diagnostics
## [br]
## @since 6.0.0
## [br]
## @return 任务诊断快照。
## [br]
## @schema return: Dictionary with task_id, interruptible, scheduled, initialized, and requirement_ids.
func get_debug_snapshot() -> Dictionary:
	var requirement_ids: Array[int] = []
	for requirement: Object in get_requirements():
		requirement_ids.append(requirement.get_instance_id())
	return {
		"task_id": task_id,
		"interruptible": interruptible,
		"scheduled": _scheduled,
		"initialized": _initialized,
		"requirement_ids": requirement_ids,
	}


# --- 框架内部方法 ---

## 返回调度前拒绝原因。
##
## [br]
## 空 StringName 表示当前任务允许进入调度器；复合任务可覆盖该入口，在调度器占用
## requirement 前拒绝内部不一致状态。
## [br]
## @api framework_internal
## [br]
## @category lifecycle
## [br]
## @since 8.0.0
## [br]
## @return 调度拒绝原因；为空表示可调度。
func get_schedule_rejection_reason() -> StringName:
	return &""


## 冻结调度仲裁期间的任务配置。
##
## [br]
## @api framework_internal
## [br]
## @category lifecycle
## [br]
## @since 8.0.0
func begin_schedule_resolution() -> void:
	_schedule_resolution_locked = true


## 解除调度仲裁期间的任务配置冻结。
##
## [br]
## @api framework_internal
## [br]
## @category lifecycle
## [br]
## @since 8.0.0
func end_schedule_resolution() -> void:
	_schedule_resolution_locked = false


## 返回任务配置当前是否被调度仲裁冻结。
##
## [br]
## @api framework_internal
## [br]
## @category query
## [br]
## @since 8.0.0
## [br]
## @return 正在调度仲裁或已经进入调度器时返回 true。
func is_configuration_locked() -> bool:
	return _schedule_resolution_locked or is_scheduled()


## 标记任务进入调度器。
##
## [br]
## @api framework_internal
## [br]
## @category lifecycle
## [br]
## @since 6.0.0
func mark_scheduled() -> void:
	_scheduled = true
	_initialized = false
	_schedule_resolution_locked = false


## 标记任务离开调度器。
##
## [br]
## @api framework_internal
## [br]
## @category lifecycle
## [br]
## @since 6.0.0
func mark_unscheduled() -> void:
	_scheduled = false
	_initialized = false
	_schedule_resolution_locked = false


## 标记任务已经完成初始化。
##
## [br]
## @api framework_internal
## [br]
## @category lifecycle
## [br]
## @since 6.0.0
func mark_initialized() -> void:
	_initialized = true


# 直接替换占用对象列表，不执行调度状态 guard。
# 仅供复合任务在调度前同步聚合后的 requirement 状态。
func _replace_requirements_unchecked(next_requirements: Array[Object]) -> void:
	_requirements.clear()
	for requirement: Object in next_requirements:
		if requirement == null or not is_instance_valid(requirement):
			continue
		if _requirements.has(requirement):
			continue
		_requirements.append(requirement)


# --- 私有/辅助方法 ---

func _can_mutate_requirements() -> bool:
	if not is_configuration_locked():
		return true
	push_warning("[GFRuntimeTask] 调度仲裁中或已调度的任务不能修改 requirements；请取消并重新配置。")
	return false
