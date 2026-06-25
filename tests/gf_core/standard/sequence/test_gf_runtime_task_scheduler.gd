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
