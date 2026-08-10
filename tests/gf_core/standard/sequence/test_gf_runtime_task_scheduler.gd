## 测试运行时任务调度器的生命周期、冲突仲裁、默认任务和组合任务。
extends GutTest


# --- 辅助类 ---

class RecordingTask extends GFRuntimeTask:
	var order: Array[String] = []
	var label: String = ""
	var finish_after_ticks: int = 1
	var tick_count: int = 0
	var reset_on_initialize: bool = false

	func _init(
		p_order: Array[String],
		p_label: String,
		p_requirements: Array[Object] = [],
		p_interruptible: bool = true,
		p_finish_after_ticks: int = 1
	) -> void:
		super._init(p_requirements, p_interruptible)
		order = p_order
		label = p_label
		finish_after_ticks = p_finish_after_ticks
		task_id = StringName(label)

	func initialize(_scheduler: GFRuntimeTaskScheduler) -> void:
		if reset_on_initialize:
			tick_count = 0
		order.append("init_" + label)

	func tick(_delta: float) -> void:
		tick_count += 1
		order.append("tick_" + label)

	func physics_tick(_delta: float) -> void:
		tick_count += 1
		order.append("physics_" + label)

	func is_finished() -> bool:
		return tick_count >= finish_after_ticks

	func end(interrupted: bool) -> void:
		order.append(("cancel_" if interrupted else "end_") + label)


class SelfCancellingTask extends GFRuntimeTask:
	var finished_checks: int = 0
	var cancel_count: int = 0
	var _scheduler: GFRuntimeTaskScheduler = null

	func initialize(scheduler: GFRuntimeTaskScheduler) -> void:
		_scheduler = scheduler

	func tick(_delta: float) -> void:
		if _scheduler != null:
			var _cancelled: bool = _scheduler.cancel(self)

	func is_finished() -> bool:
		finished_checks += 1
		return true

	func end(interrupted: bool) -> void:
		if interrupted:
			cancel_count += 1


class InitializeCancellingTask extends GFRuntimeTask:
	var tick_count: int = 0
	var cancel_count: int = 0

	func initialize(scheduler: GFRuntimeTaskScheduler) -> void:
		var _cancelled: bool = scheduler.cancel(self)

	func tick(_delta: float) -> void:
		tick_count += 1

	func end(interrupted: bool) -> void:
		if interrupted:
			cancel_count += 1


class ParentCancellingTask extends GFRuntimeTask:
	var parent_group: GFRuntimeTaskGroup = null
	var initialize_count: int = 0
	var tick_count: int = 0
	var end_count: int = 0

	func initialize(scheduler: GFRuntimeTaskScheduler) -> void:
		initialize_count += 1
		var _cancelled: bool = scheduler.cancel(parent_group)

	func tick(_delta: float) -> void:
		tick_count += 1

	func end(_interrupted: bool) -> void:
		end_count += 1


class ReplacementObserverTask extends GFRuntimeTask:
	var scheduler: GFRuntimeTaskScheduler = null
	var challenger: GFRuntimeTask = null
	var protected_requirement: Object = null
	var observed_owner: GFRuntimeTask = null
	var reentrant_task: GFRuntimeTask = null
	var reentrant_schedule_result: bool = true
	var committed_task_cancel_result: bool = true

	func end(interrupted: bool) -> void:
		if not interrupted:
			return
		observed_owner = scheduler.get_task_for_requirement(get_requirements()[0])
		var _mutation_result: GFRuntimeTask = challenger.add_requirement(protected_requirement)
		reentrant_schedule_result = scheduler.schedule(reentrant_task)
		committed_task_cancel_result = scheduler.cancel(challenger)
		scheduler.dispose()
		scheduler.tick(0.1)
		scheduler.physics_tick(0.1)


class DisposeObserverTask extends GFRuntimeTask:
	var scheduler: GFRuntimeTaskScheduler = null
	var reentrant_task: GFRuntimeTask = null
	var reentrant_schedule_result: bool = true
	var default_requirement: Object = null
	var default_task: GFRuntimeTask = null
	var default_registration_result: bool = true
	var observed_active_count: int = -1
	var end_count: int = 0

	func end(interrupted: bool) -> void:
		if not interrupted:
			return
		end_count += 1
		observed_active_count = scheduler.get_active_tasks().size()
		reentrant_schedule_result = scheduler.schedule(reentrant_task)
		default_registration_result = scheduler.register_default_task(
			default_requirement,
			default_task
		)


class EndReschedulingTask extends GFRuntimeTask:
	var scheduler: GFRuntimeTaskScheduler = null
	var trace: Array[String] = []
	var initialize_count: int = 0
	var tick_count: int = 0
	var finished_check_count: int = 0
	var end_count: int = 0
	var reschedule_result: bool = false

	func initialize(p_scheduler: GFRuntimeTaskScheduler) -> void:
		scheduler = p_scheduler
		initialize_count += 1
		trace.append("init_%d" % initialize_count)

	func tick(_delta: float) -> void:
		tick_count += 1
		trace.append("tick_%d" % tick_count)
		if tick_count == 1 and scheduler != null:
			var _cancelled: bool = scheduler.cancel(self)

	func is_finished() -> bool:
		finished_check_count += 1
		trace.append("finished_%d" % initialize_count)
		return true

	func end(interrupted: bool) -> void:
		end_count += 1
		trace.append("end_%s" % str(interrupted))
		if interrupted and end_count == 1 and scheduler != null:
			reschedule_result = scheduler.schedule(self)


# --- 测试方法 ---

## 验证调度器会初始化、推进并完成任务。
func test_scheduler_runs_task_lifecycle() -> void:
	var scheduler: GFRuntimeTaskScheduler = GFRuntimeTaskScheduler.new()
	var order: Array[String] = []
	var task: RecordingTask = RecordingTask.new(order, "task")
	watch_signals(scheduler)

	assert_true(scheduler.schedule(task), "有效任务应能进入调度器。")
	assert_true(task.is_scheduled(), "任务应被标记为 scheduled。")

	scheduler.tick(0.1)

	assert_eq(order, ["init_task", "tick_task", "end_task"], "任务应按 initialize -> tick -> end 顺序执行。")
	assert_false(task.is_scheduled(), "任务完成后应离开调度器。")
	assert_true(scheduler.get_active_tasks().is_empty(), "完成后活动任务列表应为空。")
	assert_signal_emitted(scheduler, "task_scheduled", "成功调度应发出 task_scheduled。")
	assert_signal_emitted(scheduler, "task_completed", "正常完成应发出 task_completed。")


## 验证不可中断任务占用 requirement 时会拒绝新任务。
func test_requirement_conflict_rejects_non_interruptible_owner() -> void:
	var scheduler: GFRuntimeTaskScheduler = GFRuntimeTaskScheduler.new()
	var requirement: RefCounted = RefCounted.new()
	var order: Array[String] = []
	var owner_task: RecordingTask = RecordingTask.new(order, "owner", [requirement], false, 99)
	var challenger: RecordingTask = RecordingTask.new(order, "challenger", [requirement], true, 1)
	watch_signals(scheduler)

	assert_true(scheduler.schedule(owner_task), "占用者应先进入调度器。")
	assert_false(scheduler.schedule(challenger), "不可中断占用者存在时应拒绝新任务。")

	assert_same(scheduler.get_task_for_requirement(requirement), owner_task, "Requirement 应仍由原任务占用。")
	assert_false(challenger.is_scheduled(), "被拒绝任务不应进入调度器。")
	assert_signal_emitted(scheduler, "task_rejected", "冲突拒绝应发出 task_rejected。")


## 验证可中断任务会被新任务替换。
func test_requirement_conflict_interrupts_owner() -> void:
	var scheduler: GFRuntimeTaskScheduler = GFRuntimeTaskScheduler.new()
	var requirement: RefCounted = RefCounted.new()
	var order: Array[String] = []
	var owner_task: RecordingTask = RecordingTask.new(order, "owner", [requirement], true, 99)
	var challenger: RecordingTask = RecordingTask.new(order, "challenger", [requirement], true, 1)
	watch_signals(scheduler)

	assert_true(scheduler.schedule(owner_task), "占用者应先进入调度器。")
	assert_true(scheduler.schedule(challenger), "可中断占用者应允许被替换。")

	assert_eq(order, ["cancel_owner"], "新任务进入时应中断旧任务。")
	assert_same(scheduler.get_task_for_requirement(requirement), challenger, "Requirement 应转移给新任务。")
	assert_false(owner_task.is_scheduled(), "旧任务应离开调度器。")
	assert_true(challenger.is_scheduled(), "新任务应进入调度器。")
	assert_signal_emitted(scheduler, "task_cancelled", "被替换的任务应发出取消信号。")


func test_scheduled_task_rejects_requirement_mutation() -> void:
	var scheduler: GFRuntimeTaskScheduler = GFRuntimeTaskScheduler.new()
	var requirement_a: RefCounted = RefCounted.new()
	var requirement_b: RefCounted = RefCounted.new()
	var order: Array[String] = []
	var task: RecordingTask = RecordingTask.new(order, "locked", [requirement_a], true, 99)

	assert_true(scheduler.schedule(task), "任务应能进入调度器。")
	var _add_result: GFRuntimeTask = task.add_requirement(requirement_b)
	assert_false(task.remove_requirement(requirement_a), "已调度任务不应允许移除 requirement。")
	task.clear_requirements()
	var _set_result: GFRuntimeTask = task.set_requirements([requirement_b])
	for _index: int in range(4):
		assert_push_warning(
			"[GFRuntimeTask] 调度仲裁中或已调度的任务不能修改 requirements；请取消并重新配置。"
		)

	assert_true(task.has_requirement(requirement_a), "已调度任务应保留原 requirement。")
	assert_false(task.has_requirement(requirement_b), "已调度任务不应接受新增 requirement。")


func test_register_default_task_rejects_scheduled_task_missing_requirement() -> void:
	var scheduler: GFRuntimeTaskScheduler = GFRuntimeTaskScheduler.new()
	var active_requirement: RefCounted = RefCounted.new()
	var default_requirement: RefCounted = RefCounted.new()
	var order: Array[String] = []
	var task: RecordingTask = RecordingTask.new(order, "active", [active_requirement], true, 99)

	assert_true(scheduler.schedule(task), "任务应能先进入调度器。")
	assert_false(scheduler.register_default_task(default_requirement, task), "已调度且不能新增 requirement 的任务不应注册为默认任务。")
	assert_push_warning("[GFRuntimeTask] 调度仲裁中或已调度的任务不能修改 requirements；请取消并重新配置。")

	assert_false(task.has_requirement(default_requirement), "失败注册不应修改已调度任务 requirement。")
	assert_null(scheduler.get_default_task(default_requirement), "失败注册不应留下默认任务记录。")


## 验证默认任务会在 requirement 空闲时自动恢复。
func test_default_task_runs_when_requirement_becomes_idle() -> void:
	var scheduler: GFRuntimeTaskScheduler = GFRuntimeTaskScheduler.new()
	var requirement: RefCounted = RefCounted.new()
	var order: Array[String] = []
	var default_task: RecordingTask = RecordingTask.new(order, "default", [requirement], true, 99)
	default_task.reset_on_initialize = true
	var foreground: RecordingTask = RecordingTask.new(order, "foreground", [requirement], true, 1)

	assert_true(scheduler.register_default_task(requirement, default_task), "应能注册默认任务。")
	scheduler.tick(0.1)

	assert_true(default_task.is_scheduled(), "首次推进后默认任务应占用空闲 requirement。")
	assert_true(scheduler.schedule(foreground), "前台任务应能中断可中断默认任务。")
	scheduler.tick(0.1)
	scheduler.tick(0.1)

	assert_eq(
		order,
		[
			"cancel_default",
			"init_foreground",
			"tick_foreground",
			"end_foreground",
			"init_default",
			"tick_default",
		],
		"默认任务应在前台任务完成后的下一次推进中恢复。"
	)
	assert_same(scheduler.get_task_for_requirement(requirement), default_task, "Requirement 应重新回到默认任务。")


func test_default_task_is_pruned_when_requirement_is_released() -> void:
	var scheduler: GFRuntimeTaskScheduler = GFRuntimeTaskScheduler.new()
	var requirement: Node = Node.new()
	var requirement_id: int = requirement.get_instance_id()
	var order: Array[String] = []
	var default_task: RecordingTask = RecordingTask.new(order, "default", [], true, 99)

	assert_true(scheduler.register_default_task(requirement, default_task), "应能注册默认任务。")
	requirement.free()
	scheduler.tick(0.1)

	var snapshot: Dictionary = scheduler.get_debug_snapshot()
	var default_requirement_ids: Array = GFVariantData.get_option_array(snapshot, "default_requirement_ids")
	assert_false(default_task.is_scheduled(), "已释放 requirement 的默认任务不应被调度。")
	assert_false(default_requirement_ids.has(requirement_id), "已释放 requirement 的默认任务记录应被清理。")


## 验证 Callable 任务可用闭包定义生命周期。
func test_callable_runtime_task_runs_callbacks() -> void:
	var scheduler: GFRuntimeTaskScheduler = GFRuntimeTaskScheduler.new()
	var order: Array[String] = []
	var task: GFCallableRuntimeTask = GFCallableRuntimeTask.new(
		func(_task: GFCallableRuntimeTask, _scheduler: GFRuntimeTaskScheduler) -> void:
			order.append("init"),
		func(_delta: float, _task: GFCallableRuntimeTask, _scheduler: GFRuntimeTaskScheduler) -> void:
			order.append("tick"),
		Callable(),
		func(interrupted: bool, _task: GFCallableRuntimeTask, _scheduler: GFRuntimeTaskScheduler) -> void:
			order.append("end_%s" % [str(interrupted)])
	)

	assert_true(scheduler.schedule(task), "Callable 任务应能进入调度器。")
	scheduler.tick(0.1)

	assert_eq(order, ["init", "tick", "end_false"], "Callable 任务应按回调生命周期执行。")


## 验证顺序任务组按子任务声明顺序推进。
func test_task_group_sequence_runs_children_in_order() -> void:
	var scheduler: GFRuntimeTaskScheduler = GFRuntimeTaskScheduler.new()
	var order: Array[String] = []
	var group: GFRuntimeTaskGroup = GFRuntimeTaskGroup.new([
		RecordingTask.new(order, "first"),
		RecordingTask.new(order, "second"),
	], GFRuntimeTaskGroup.Mode.SEQUENCE)

	assert_true(scheduler.schedule(group), "任务组应能进入调度器。")
	scheduler.tick(0.1)
	scheduler.tick(0.1)

	assert_eq(
		order,
		["init_first", "tick_first", "end_first", "init_second", "tick_second", "end_second"],
		"顺序任务组应逐个初始化、推进并结束子任务。"
	)
	assert_false(group.is_scheduled(), "所有子任务完成后任务组应结束。")


func test_scheduled_task_group_rejects_child_mutation() -> void:
	var scheduler: GFRuntimeTaskScheduler = GFRuntimeTaskScheduler.new()
	var order: Array[String] = []
	var first: RecordingTask = RecordingTask.new(order, "first", [], true, 99)
	var second: RecordingTask = RecordingTask.new(order, "second", [], true, 99)
	var group: GFRuntimeTaskGroup = GFRuntimeTaskGroup.new([first], GFRuntimeTaskGroup.Mode.PARALLEL_ALL)

	assert_true(scheduler.schedule(group), "任务组应能进入调度器。")
	var _add_result: GFRuntimeTaskGroup = group.add_task(second)
	assert_false(group.remove_task(first), "已调度任务组不应允许移除子任务。")
	group.rebuild_requirements()
	for _index: int in range(3):
		assert_push_warning("[GFRuntimeTaskGroup] 调度仲裁中或已调度的任务组不能修改配置。")

	assert_eq(group.get_tasks(), [first], "已调度任务组不应接受子任务集合变更。")


func test_scheduler_rejects_group_child_scheduled_independently() -> void:
	var scheduler: GFRuntimeTaskScheduler = GFRuntimeTaskScheduler.new()
	var order: Array[String] = []
	var first: RecordingTask = RecordingTask.new(order, "first", [], true, 99)
	var group: GFRuntimeTaskGroup = GFRuntimeTaskGroup.new([first], GFRuntimeTaskGroup.Mode.PARALLEL_ALL)
	watch_signals(scheduler)

	assert_true(scheduler.schedule(group), "任务组应能进入调度器。")
	scheduler.tick(0.1)

	assert_true(first.is_scheduled(), "子任务应由任务组内部调度。")
	assert_false(scheduler.schedule(first), "已被任务组调度的子任务不应再次进入外层调度器。")
	assert_eq(scheduler.get_active_tasks(), [group], "外层调度器不应同时持有任务组和其子任务。")
	assert_signal_emitted(scheduler, "task_rejected", "重复所有权应发出拒绝信号。")


func test_task_group_reserves_and_locks_all_children_before_first_tick() -> void:
	var scheduler: GFRuntimeTaskScheduler = GFRuntimeTaskScheduler.new()
	var other_scheduler: GFRuntimeTaskScheduler = GFRuntimeTaskScheduler.new()
	var order: Array[String] = []
	var first: RecordingTask = RecordingTask.new(order, "first", [], true, 99)
	var future: RecordingTask = RecordingTask.new(order, "future", [], true, 99)
	var late_requirement: RefCounted = RefCounted.new()
	var group: GFRuntimeTaskGroup = GFRuntimeTaskGroup.new(
		[first, future],
		GFRuntimeTaskGroup.Mode.SEQUENCE
	)

	assert_true(scheduler.schedule(group), "任务组提交时应原子预留整棵子任务树。")
	assert_true(first.is_scheduled(), "首个子任务应在 first tick 前已由任务组预留。")
	assert_true(future.is_scheduled(), "未来子任务也应在 first tick 前已由任务组预留。")
	assert_false(scheduler.schedule(future), "同一调度器不能再次持有未来子任务。")
	assert_false(other_scheduler.schedule(future), "其他调度器也不能持有已被任务组预留的子任务。")
	var _mutation_result: GFRuntimeTask = future.add_requirement(late_requirement)
	assert_push_warning(
		"[GFRuntimeTask] 调度仲裁中或已调度的任务不能修改 requirements；请取消并重新配置。"
	)
	assert_false(future.has_requirement(late_requirement), "预留后的未来子任务 requirement 必须冻结。")

	assert_true(scheduler.cancel(group), "first tick 前应能取消整个任务组。")
	assert_false(first.is_scheduled(), "取消任务组应释放尚未初始化的首个子任务。")
	assert_false(future.is_scheduled(), "取消任务组应释放尚未初始化的未来子任务。")
	assert_true(order.is_empty(), "未初始化的预留子任务不应收到 end 回调。")


func test_task_group_rejects_child_already_scheduled_outside_group() -> void:
	var scheduler: GFRuntimeTaskScheduler = GFRuntimeTaskScheduler.new()
	var order: Array[String] = []
	var child: RecordingTask = RecordingTask.new(order, "child", [], true, 99)

	assert_true(scheduler.schedule(child), "子任务先进入外层调度器。")
	var group: GFRuntimeTaskGroup = GFRuntimeTaskGroup.new([child], GFRuntimeTaskGroup.Mode.PARALLEL_ALL)

	assert_true(group.get_tasks().is_empty(), "已调度任务不应被加入任务组。")
	assert_eq(scheduler.get_active_tasks(), [child], "外层调度器应仍只持有原子任务。")


func test_task_group_rebuilds_child_requirements_before_scheduling() -> void:
	var scheduler: GFRuntimeTaskScheduler = GFRuntimeTaskScheduler.new()
	var requirement_a: RefCounted = RefCounted.new()
	var requirement_b: RefCounted = RefCounted.new()
	var order: Array[String] = []
	var owner_task: RecordingTask = RecordingTask.new(order, "owner", [requirement_b], false, 99)
	var child: RecordingTask = RecordingTask.new(order, "child", [requirement_a], true, 99)
	var group: GFRuntimeTaskGroup = GFRuntimeTaskGroup.new([child], GFRuntimeTaskGroup.Mode.SEQUENCE)
	var _added_requirement: GFRuntimeTask = child.add_requirement(requirement_b)

	assert_true(scheduler.schedule(owner_task), "外层 owner 应先占用新增 requirement。")
	assert_false(scheduler.schedule(group), "任务组调度前应反映子任务最新 requirement 并被冲突拒绝。")
	assert_false(group.is_scheduled(), "冲突拒绝后任务组不应进入调度器。")


func test_parallel_task_group_rejects_duplicate_child_requirements() -> void:
	var requirement: RefCounted = RefCounted.new()
	var order: Array[String] = []
	var first: RecordingTask = RecordingTask.new(order, "first", [requirement], true, 99)
	var second: RecordingTask = RecordingTask.new(order, "second", [requirement], true, 99)
	var group: GFRuntimeTaskGroup = GFRuntimeTaskGroup.new([first], GFRuntimeTaskGroup.Mode.PARALLEL_ALL)

	var _add_result: GFRuntimeTaskGroup = group.add_task(second)
	assert_push_warning("[GFRuntimeTaskGroup] 并行任务组不能包含占用相同 requirement 的子任务。")

	assert_eq(group.get_tasks(), [first], "并行任务组不应接受共享 requirement 的第二个子任务。")


func test_parallel_task_group_rejects_requirements_changed_after_add() -> void:
	var scheduler: GFRuntimeTaskScheduler = GFRuntimeTaskScheduler.new()
	var requirement_a: RefCounted = RefCounted.new()
	var requirement_b: RefCounted = RefCounted.new()
	var order: Array[String] = []
	var first: RecordingTask = RecordingTask.new(order, "first", [requirement_a], true, 99)
	var second: RecordingTask = RecordingTask.new(order, "second", [requirement_b], true, 99)
	var group: GFRuntimeTaskGroup = GFRuntimeTaskGroup.new([first, second], GFRuntimeTaskGroup.Mode.PARALLEL_ALL)
	watch_signals(scheduler)

	var _mutated: GFRuntimeTask = second.add_requirement(requirement_a)

	assert_false(scheduler.schedule(group), "并行任务组调度前应重新拒绝后续改出的组内 requirement 冲突。")
	assert_false(group.is_scheduled(), "组内冲突拒绝后任务组不应进入调度器。")
	assert_eq(order, [], "被拒绝的任务组不应初始化任何子任务。")
	assert_signal_emitted(scheduler, "task_rejected", "组内 requirement 冲突应发出拒绝信号。")


## 验证竞速任务组会在首个子任务完成后中断剩余子任务。
func test_task_group_race_cancels_remaining_children() -> void:
	var scheduler: GFRuntimeTaskScheduler = GFRuntimeTaskScheduler.new()
	var order: Array[String] = []
	var slow: RecordingTask = RecordingTask.new(order, "slow", [], true, 99)
	var fast: RecordingTask = RecordingTask.new(order, "fast", [], true, 1)
	var group: GFRuntimeTaskGroup = GFRuntimeTaskGroup.new(
		[slow, fast],
		GFRuntimeTaskGroup.Mode.PARALLEL_RACE
	)

	assert_true(scheduler.schedule(group), "竞速任务组应能进入调度器。")
	scheduler.tick(0.1)

	assert_eq(
		order,
		[
			"init_slow",
			"init_fast",
			"tick_slow",
			"tick_fast",
			"end_fast",
			"cancel_slow",
		],
		"竞速任务组应在首个子任务完成后中断未完成子任务。"
	)
	assert_false(group.is_scheduled(), "竞速完成后任务组应离开调度器。")


func test_task_group_race_closes_remaining_children_when_not_interrupted() -> void:
	var scheduler: GFRuntimeTaskScheduler = GFRuntimeTaskScheduler.new()
	var order: Array[String] = []
	var slow: RecordingTask = RecordingTask.new(order, "slow", [], true, 99)
	var fast: RecordingTask = RecordingTask.new(order, "fast", [], true, 1)
	var group: GFRuntimeTaskGroup = GFRuntimeTaskGroup.new(
		[slow, fast],
		GFRuntimeTaskGroup.Mode.PARALLEL_RACE
	)
	group.cancel_remaining_on_finish = false

	assert_true(scheduler.schedule(group), "竞速任务组应能进入调度器。")
	scheduler.tick(0.1)

	assert_eq(
		order,
		[
			"init_slow",
			"init_fast",
			"tick_slow",
			"tick_fast",
			"end_fast",
			"end_slow",
		],
		"竞速完成后即使不标记中断，也必须关闭未完成子任务。"
	)
	assert_false(group.is_scheduled(), "竞速完成后任务组应离开调度器。")


func test_scheduler_skips_finished_check_after_self_cancel() -> void:
	var scheduler: GFRuntimeTaskScheduler = GFRuntimeTaskScheduler.new()
	var task: SelfCancellingTask = SelfCancellingTask.new()

	assert_true(scheduler.schedule(task), "任务应能进入调度器。")
	scheduler.tick(0.1)

	assert_false(task.is_scheduled(), "自取消任务应离开调度器。")
	assert_eq(task.cancel_count, 1, "自取消任务应以 interrupted=true 结束。")
	assert_eq(task.finished_checks, 0, "任务在 tick 内自取消后不应再执行 is_finished。")


func test_scheduler_does_not_advance_generation_rescheduled_from_end() -> void:
	var scheduler: GFRuntimeTaskScheduler = GFRuntimeTaskScheduler.new()
	var task: EndReschedulingTask = EndReschedulingTask.new()

	assert_true(scheduler.schedule(task), "第一代任务应能进入调度器。")
	var first_generation: int = task.get_schedule_generation()
	scheduler.tick(0.1)

	assert_true(task.reschedule_result, "第一代 end 回调应能同步提交同一实例的新调度代。")
	assert_true(task.is_scheduled(), "新调度代应保留在活动集合中。")
	assert_gt(task.get_schedule_generation(), first_generation, "重新调度必须分配新的 generation。")
	assert_false(task.has_initialized(), "新调度代不能继承旧代 initialized 状态。")
	assert_eq(task.finished_check_count, 0, "旧代 tick 返回后不能检查新代 is_finished。")
	assert_eq(
		task.trace,
		["init_1", "tick_1", "end_true"],
		"旧代后置路径必须在 generation 改变处截断。"
	)

	scheduler.tick(0.1)

	assert_eq(task.initialize_count, 2, "新代推进前必须重新 initialize 恰好一次。")
	assert_eq(task.finished_check_count, 1, "新代只能在 initialize 与 tick 后检查完成。")
	assert_eq(task.end_count, 2, "两个调度代应分别只有一个 terminal end。")
	assert_false(task.is_scheduled(), "第二代正常完成后应离开调度器。")


func test_scheduler_skips_tick_after_initialize_self_cancel() -> void:
	var scheduler: GFRuntimeTaskScheduler = GFRuntimeTaskScheduler.new()
	var task: InitializeCancellingTask = InitializeCancellingTask.new()

	assert_true(scheduler.schedule(task), "任务应能进入调度器。")
	scheduler.tick(0.1)

	assert_false(task.is_scheduled(), "初始化中自取消任务应离开调度器。")
	assert_eq(task.cancel_count, 1, "初始化中自取消任务应以 interrupted=true 结束。")
	assert_eq(task.tick_count, 0, "任务在 initialize 内自取消后不应继续 tick。")


func test_schedule_commits_requirement_ownership_before_interrupt_callbacks() -> void:
	var scheduler: GFRuntimeTaskScheduler = GFRuntimeTaskScheduler.new()
	var contested_requirement: RefCounted = RefCounted.new()
	var protected_requirement: RefCounted = RefCounted.new()
	var protected_owner: GFRuntimeTask = GFRuntimeTask.new([protected_requirement], false)
	var challenger: GFRuntimeTask = GFRuntimeTask.new([contested_requirement], true)
	var reentrant_task: GFRuntimeTask = GFRuntimeTask.new()
	var replacement_owner: ReplacementObserverTask = ReplacementObserverTask.new([contested_requirement], true)
	replacement_owner.scheduler = scheduler
	replacement_owner.challenger = challenger
	replacement_owner.protected_requirement = protected_requirement
	replacement_owner.reentrant_task = reentrant_task

	assert_true(scheduler.schedule(protected_owner), "受保护 requirement 应先被不可中断任务占用。")
	assert_true(scheduler.schedule(replacement_owner), "可中断 owner 应进入调度器。")
	assert_true(scheduler.schedule(challenger), "challenger 应原子替换可中断 owner。")
	assert_push_warning("[GFRuntimeTask] 调度仲裁中或已调度的任务不能修改 requirements；请取消并重新配置。")

	assert_same(replacement_owner.observed_owner, challenger, "中断回调应观察到已经提交的新 owner。")
	assert_false(challenger.has_requirement(protected_requirement), "中断回调不能修改已提交任务的 requirements。")
	assert_same(scheduler.get_task_for_requirement(protected_requirement), protected_owner, "回调不能覆盖不可中断 requirement owner。")
	assert_false(replacement_owner.reentrant_schedule_result, "所有权提交期间应拒绝重入 schedule()。")
	assert_false(reentrant_task.is_scheduled(), "被拒绝的重入任务不应进入调度器。")
	assert_false(
		replacement_owner.committed_task_cancel_result,
		"所有权提交期间应拒绝回调取消刚提交的任务。"
	)
	assert_true(challenger.is_scheduled(), "所有权提交期间的 dispose 回调不得清空刚提交的任务。")
	assert_same(
		scheduler.get_task_for_requirement(contested_requirement),
		challenger,
		"所有权提交回调结束后活动任务与 owner 索引应保持一致。"
	)


func test_requirement_index_rebuild_prunes_released_objects_from_active_tasks() -> void:
	var scheduler: GFRuntimeTaskScheduler = GFRuntimeTaskScheduler.new()
	var released_requirement: Node = Node.new()
	var released_requirement_id: int = released_requirement.get_instance_id()
	var live_requirement: RefCounted = RefCounted.new()
	var live_requirement_id: int = live_requirement.get_instance_id()
	var task: GFRuntimeTask = GFRuntimeTask.new(
		[released_requirement, live_requirement],
		false
	)

	assert_true(scheduler.schedule(task), "任务应能占用两个有效 requirements。")
	released_requirement.free()
	var rejected_challenger: GFRuntimeTask = GFRuntimeTask.new([live_requirement])

	assert_false(
		scheduler.schedule(rejected_challenger),
		"仍有效 requirement 由不可中断任务占用时，新任务应被拒绝。"
	)
	assert_false(
		scheduler._requirement_owners.has(released_requirement_id),
		"被拒绝的调度边界也应提交从活动任务重建的当前 owner 索引。"
	)

	var snapshot: Dictionary = scheduler.get_debug_snapshot()
	var owner_ids: Array = GFVariantData.get_option_array(snapshot, "requirement_owner_ids")
	assert_false(owner_ids.has(released_requirement_id), "事务重建应删除活动任务已经释放的 requirement ID。")
	assert_true(owner_ids.has(live_requirement_id), "事务重建不能删除同一活动任务仍有效的 requirement。")
	assert_false(
		scheduler._requirement_owners.has(released_requirement_id),
		"诊断边界应将成功重建的 owner 索引原子提交回派生缓存。"
	)
	assert_same(scheduler.get_task_for_requirement(live_requirement), task, "仍有效 requirement 应继续解析到原活动任务。")


func test_requirement_index_rebuild_does_not_publish_partial_duplicate_state() -> void:
	var scheduler: GFRuntimeTaskScheduler = GFRuntimeTaskScheduler.new()
	var duplicate_requirement: RefCounted = RefCounted.new()
	var sentinel_requirement: RefCounted = RefCounted.new()
	var sentinel_task: GFRuntimeTask = GFRuntimeTask.new([sentinel_requirement])
	var first: GFRuntimeTask = GFRuntimeTask.new([duplicate_requirement])
	var second: GFRuntimeTask = GFRuntimeTask.new([duplicate_requirement])
	first.mark_scheduled()
	second.mark_scheduled()
	var corrupted_active_tasks: Array[GFRuntimeTask] = [first, second]
	scheduler._active_tasks = corrupted_active_tasks
	scheduler._requirement_owners = {
		sentinel_requirement.get_instance_id(): {
			"requirement_ref": weakref(sentinel_requirement),
			"task": sentinel_task,
		},
	}

	assert_false(scheduler._rebuild_requirement_owner_index(), "重复 owner 应使候选索引整体失败。")
	assert_eq(scheduler._requirement_owners.size(), 1, "失败重建不得发布部分候选索引。")
	assert_true(
		scheduler._requirement_owners.has(sentinel_requirement.get_instance_id()),
		"失败重建应保留此前完整索引，等待调用边界 fail closed。"
	)


func test_cancel_does_not_publish_partial_state_when_candidate_index_is_invalid() -> void:
	var scheduler: GFRuntimeTaskScheduler = GFRuntimeTaskScheduler.new()
	var order: Array[String] = []
	var cancelled_task: RecordingTask = RecordingTask.new(order, "cancelled", [], true, 99)
	var duplicate_requirement: RefCounted = RefCounted.new()
	var sentinel_requirement: RefCounted = RefCounted.new()
	var sentinel_task: GFRuntimeTask = GFRuntimeTask.new([sentinel_requirement])
	var first: GFRuntimeTask = GFRuntimeTask.new([duplicate_requirement])
	var second: GFRuntimeTask = GFRuntimeTask.new([duplicate_requirement])
	cancelled_task.mark_scheduled()
	first.mark_scheduled()
	second.mark_scheduled()
	var corrupted_active_tasks: Array[GFRuntimeTask] = [cancelled_task, first, second]
	scheduler._active_tasks = corrupted_active_tasks
	scheduler._requirement_owners = {
		sentinel_requirement.get_instance_id(): {
			"requirement_ref": weakref(sentinel_requirement),
			"task": sentinel_task,
		},
	}

	assert_false(scheduler.cancel(cancelled_task), "候选索引无效时取消操作应 fail closed。")
	assert_eq(
		scheduler.get_active_tasks(),
		corrupted_active_tasks,
		"失败取消不得先修改活动任务集合。"
	)
	assert_true(cancelled_task.is_scheduled(), "失败取消不得先修改任务 scheduled 状态。")
	assert_true(order.is_empty(), "失败取消不得调用任务 end 回调。")
	assert_eq(scheduler._requirement_owners.size(), 1, "失败取消不得替换此前完整索引。")
	assert_true(
		scheduler._requirement_owners.has(sentinel_requirement.get_instance_id()),
		"失败取消应保留此前完整索引。"
	)


func test_dispose_commits_empty_active_state_before_callbacks_and_rejects_reentrant_schedule() -> void:
	var scheduler: GFRuntimeTaskScheduler = GFRuntimeTaskScheduler.new()
	var requirement: RefCounted = RefCounted.new()
	var default_requirement: RefCounted = RefCounted.new()
	var reentrant_task: GFRuntimeTask = GFRuntimeTask.new([requirement])
	var default_task: GFRuntimeTask = GFRuntimeTask.new()
	var active_task: DisposeObserverTask = DisposeObserverTask.new([requirement])
	active_task.scheduler = scheduler
	active_task.reentrant_task = reentrant_task
	active_task.default_requirement = default_requirement
	active_task.default_task = default_task
	watch_signals(scheduler)

	assert_true(scheduler.schedule(active_task), "任务应能在 dispose 前进入调度器。")
	scheduler.dispose()

	assert_eq(active_task.end_count, 1, "dispose 应恰好一次以 interrupted=true 结束活动任务。")
	assert_eq(active_task.observed_active_count, 0, "结束回调应观察到已经提交的空活动任务集合。")
	assert_false(active_task.reentrant_schedule_result, "dispose 生命周期窗口应拒绝回调重入 schedule()。")
	assert_false(
		active_task.default_registration_result,
		"dispose 生命周期窗口应拒绝回调重新注册默认任务。"
	)
	assert_false(reentrant_task.is_scheduled(), "被拒绝的重入任务不应留下 scheduled 状态。")
	assert_null(
		scheduler.get_default_task(default_requirement),
		"dispose 回调不得在释放后留下默认任务记录。"
	)
	assert_true(scheduler.get_active_tasks().is_empty(), "dispose 后活动任务集合应为空。")
	assert_true(
		GFVariantData.get_option_array(
			scheduler.get_debug_snapshot(),
			"requirement_owner_ids"
		).is_empty(),
		"dispose 后 requirement owner 索引应与空活动任务集合一致。"
	)
	assert_signal_emitted(scheduler, "task_rejected", "重入调度应明确发出 task_rejected。")


func test_task_group_stops_initialization_when_child_cancels_parent() -> void:
	var scheduler: GFRuntimeTaskScheduler = GFRuntimeTaskScheduler.new()
	var cancelling_child: ParentCancellingTask = ParentCancellingTask.new()
	var sibling_order: Array[String] = []
	var sibling: RecordingTask = RecordingTask.new(sibling_order, "sibling", [], true, 99)
	var group: GFRuntimeTaskGroup = GFRuntimeTaskGroup.new(
		[cancelling_child, sibling],
		GFRuntimeTaskGroup.Mode.PARALLEL_ALL
	)
	cancelling_child.parent_group = group

	assert_true(scheduler.schedule(group), "任务组应能进入调度器。")
	scheduler.tick(0.1)

	assert_false(group.is_scheduled(), "子任务初始化中取消父组后，父组应立即离开调度器。")
	assert_eq(cancelling_child.initialize_count, 1, "取消父组的子任务只应初始化一次。")
	assert_eq(cancelling_child.tick_count, 0, "父组取消后不应继续 tick 当前子任务。")
	assert_eq(cancelling_child.end_count, 1, "父组取消应只结束当前子任务一次。")
	assert_false(cancelling_child.has_initialized(), "已被父组结束的子任务不应在 initialize 返回后重新标记 initialized。")
	assert_true(sibling_order.is_empty(), "父组取消后不应继续初始化后续并行子任务。")
	cancelling_child.parent_group = null


func test_task_group_rejects_cycles_and_reused_descendants_transactionally() -> void:
	var self_group: GFRuntimeTaskGroup = GFRuntimeTaskGroup.new()
	assert_false(self_group.set_tasks([self_group]), "任务组必须拒绝直接 self-cycle。")
	var _self_add_result: GFRuntimeTaskGroup = self_group.add_task(self_group)
	assert_push_warning("[GFRuntimeTaskGroup] 子任务图必须是有界、无环且无重复实例的树。")
	assert_true(self_group.get_tasks().is_empty(), "self-cycle 失败后旧配置必须保持不变。")

	var first_group: GFRuntimeTaskGroup = GFRuntimeTaskGroup.new()
	var second_group: GFRuntimeTaskGroup = GFRuntimeTaskGroup.new()
	assert_true(first_group.set_tasks([second_group]), "无环单向嵌套应被接受。")
	assert_false(second_group.set_tasks([first_group]), "任务组必须拒绝祖先回边。")
	assert_true(second_group.get_tasks().is_empty(), "间接 cycle 失败后 candidate 不得部分提交。")

	var shared_leaf: GFRuntimeTask = GFRuntimeTask.new()
	var left: GFRuntimeTaskGroup = GFRuntimeTaskGroup.new([shared_leaf])
	var right: GFRuntimeTaskGroup = GFRuntimeTaskGroup.new([shared_leaf])
	var root: GFRuntimeTaskGroup = GFRuntimeTaskGroup.new()
	assert_false(root.set_tasks([left, right]), "同一 descendant 不能从任务树中的两个位置可达。")
	assert_true(root.get_tasks().is_empty(), "重复 descendant 失败后根配置必须保持不变。")


func test_task_group_enforces_bounded_graph_depth_without_recursion() -> void:
	var nested_task: GFRuntimeTask = GFRuntimeTask.new()
	for _depth: int in range(GFRuntimeTaskGroup.MAX_TASK_GRAPH_DEPTH):
		var parent: GFRuntimeTaskGroup = GFRuntimeTaskGroup.new()
		assert_true(parent.set_tasks([nested_task]), "深度预算以内的无环任务树应被接受。")
		nested_task = parent

	var overflow_parent: GFRuntimeTaskGroup = GFRuntimeTaskGroup.new()
	assert_false(
		overflow_parent.set_tasks([nested_task]),
		"超过任务图深度预算的 candidate 应在有界遍历内失败关闭。"
	)
	assert_true(overflow_parent.get_tasks().is_empty(), "深度超限不得部分提交 candidate。")

	var too_many_children: Array[GFRuntimeTask] = []
	for _index: int in range(GFRuntimeTaskGroup.MAX_TASK_GRAPH_NODES):
		too_many_children.append(GFRuntimeTask.new())
	var wide_root: GFRuntimeTaskGroup = GFRuntimeTaskGroup.new()
	assert_false(
		wide_root.set_tasks(too_many_children),
		"包含根组后超过任务图节点预算的宽图也应失败关闭。"
	)
	assert_true(wide_root.get_tasks().is_empty(), "节点数超限不得部分提交 candidate。")


func test_task_group_rejects_invalid_dynamic_mode() -> void:
	var group: GFRuntimeTaskGroup = GFRuntimeTaskGroup.new()
	var previous_mode: int = group.get_mode()
	var result: Variant = group.call("set_mode", 99)

	assert_false(GFVariantData.to_bool(result, true), "反射入口传入未知 mode 时必须失败关闭。")
	assert_push_warning("[GFRuntimeTaskGroup] 无效任务组模式，保留当前模式。")
	assert_eq(group.get_mode(), previous_mode, "非法 mode 不得改变任务组状态。")


func test_callable_runtime_task_rejects_non_bool_finished_result_once_per_generation() -> void:
	var scheduler: GFRuntimeTaskScheduler = GFRuntimeTaskScheduler.new()
	var task: GFCallableRuntimeTask = GFCallableRuntimeTask.new(
		Callable(),
		Callable(),
		func(_task: GFCallableRuntimeTask, _scheduler: GFRuntimeTaskScheduler) -> int:
			return 1
	)
	task.finish_after_initialize = false

	assert_true(scheduler.schedule(task), "Callable 任务应能进入调度器。")
	scheduler.tick(0.1)
	scheduler.tick(0.1)

	assert_push_warning(
		"[GFCallableRuntimeTask] finished_callable 必须返回 bool；无效结果按 false 处理。"
	)
	assert_true(task.is_scheduled(), "非 bool 完成结果必须按 false 失败关闭。")
	assert_true(scheduler.cancel(task), "测试结束时应能释放失败关闭的任务。")


func test_task_group_configuration_is_controlled_and_transactional() -> void:
	var requirement: RefCounted = RefCounted.new()
	var first: GFRuntimeTask = GFRuntimeTask.new([requirement])
	var second: GFRuntimeTask = GFRuntimeTask.new([requirement])
	var group: GFRuntimeTaskGroup = GFRuntimeTaskGroup.new([first])
	var copied_tasks: Array[GFRuntimeTask] = group.get_tasks()
	copied_tasks.clear()

	assert_eq(group.get_tasks(), [first], "get_tasks() 返回值不应暴露内部集合。")
	assert_false(group.set_tasks([first, first]), "重复子任务应使批量配置整体失败。")
	assert_eq(group.get_tasks(), [first], "失败的批量配置不应产生部分更新。")
	assert_true(group.set_mode(GFRuntimeTaskGroup.Mode.PARALLEL_ALL), "无内部冲突的单任务组应允许切换到并行模式。")
	var _add_conflicting_task_result: GFRuntimeTaskGroup = group.add_task(second)
	assert_push_warning("[GFRuntimeTaskGroup] 并行任务组不能包含占用相同 requirement 的子任务。")
	assert_eq(group.get_mode(), GFRuntimeTaskGroup.Mode.PARALLEL_ALL, "无内部冲突的单任务组应允许切换到并行模式。")
	assert_eq(group.get_tasks(), [first], "冲突子任务不应被加入并行任务组。")


func test_has_requirement_ignores_released_object() -> void:
	var requirement: Node = Node.new()
	var task: GFRuntimeTask = GFRuntimeTask.new([requirement])
	requirement.free()

	assert_false(task.has_requirement(requirement), "已释放 Object 不应继续命中 requirement 查询。")
	assert_true(task.get_requirements().is_empty(), "查询副本也应过滤已释放 requirement。")
