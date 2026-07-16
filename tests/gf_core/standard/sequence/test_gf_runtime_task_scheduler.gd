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

	func end(interrupted: bool) -> void:
		if not interrupted:
			return
		observed_owner = scheduler.get_task_for_requirement(get_requirements()[0])
		var _mutation_result: GFRuntimeTask = challenger.add_requirement(protected_requirement)
		reentrant_schedule_result = scheduler.schedule(reentrant_task)


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

	assert_same(replacement_owner.observed_owner, challenger, "中断回调应观察到已经提交的新 owner。")
	assert_false(challenger.has_requirement(protected_requirement), "中断回调不能修改已提交任务的 requirements。")
	assert_same(scheduler.get_task_for_requirement(protected_requirement), protected_owner, "回调不能覆盖不可中断 requirement owner。")
	assert_false(replacement_owner.reentrant_schedule_result, "所有权提交期间应拒绝重入 schedule()。")
	assert_false(reentrant_task.is_scheduled(), "被拒绝的重入任务不应进入调度器。")


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
	assert_eq(group.get_mode(), GFRuntimeTaskGroup.Mode.PARALLEL_ALL, "无内部冲突的单任务组应允许切换到并行模式。")
	assert_eq(group.get_tasks(), [first], "冲突子任务不应被加入并行任务组。")


func test_has_requirement_ignores_released_object() -> void:
	var requirement: Node = Node.new()
	var task: GFRuntimeTask = GFRuntimeTask.new([requirement])
	requirement.free()

	assert_false(task.has_requirement(requirement), "已释放 Object 不应继续命中 requirement 查询。")
	assert_true(task.get_requirements().is_empty(), "查询副本也应过滤已释放 requirement。")
