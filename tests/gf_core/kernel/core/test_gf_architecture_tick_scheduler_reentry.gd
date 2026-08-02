## 验证架构 tick 调度的生命周期准入、delta 收束、重入和延迟缓存刷新。
extends GutTest


# --- 辅助类 ---

class ReentrantTickSystem extends GFSystem:
	var scheduler_ref: WeakRef = null
	var order: Array[String] = []
	var attempted_reentry: bool = false

	func _init(
		scheduler_instance: GFArchitectureTickScheduler,
		shared_order: Array[String]
	) -> void:
		scheduler_ref = weakref(scheduler_instance)
		order = shared_order
		tick_enabled = true

	func tick(_delta: float) -> void:
		order.append("reentrant")
		if attempted_reentry:
			return
		attempted_reentry = true
		var scheduler_value: Variant = scheduler_ref.get_ref()
		if not scheduler_value is GFArchitectureTickScheduler:
			return
		var scheduler: GFArchitectureTickScheduler = scheduler_value
		scheduler.refresh()
		scheduler.drive_tick(0.25, null)


class FollowerTickSystem extends GFSystem:
	var order: Array[String] = []

	func _init(shared_order: Array[String]) -> void:
		order = shared_order
		tick_enabled = true

	func tick(_delta: float) -> void:
		order.append("follower")


class CountingTickSystem extends GFSystem:
	var tick_calls: int = 0
	var physics_tick_calls: int = 0
	var tick_deltas: Array[float] = []

	func _init() -> void:
		tick_enabled = true
		physics_tick_enabled = true

	func tick(delta: float) -> void:
		tick_calls += 1
		tick_deltas.append(delta)

	func physics_tick(_delta: float) -> void:
		physics_tick_calls += 1


class CountingTickUtility extends GFUtility:
	var tick_calls: int = 0
	var physics_tick_calls: int = 0

	func _init() -> void:
		tick_enabled = true
		physics_tick_enabled = true

	func tick(_delta: float) -> void:
		tick_calls += 1

	func physics_tick(_delta: float) -> void:
		physics_tick_calls += 1


class ReentrantTimeProvider extends RefCounted:
	var scheduler: GFArchitectureTickScheduler = null
	var trigger_callback: StringName = &""
	var attempted_reentry: bool = false
	var get_scaled_delta_calls: int = 0
	var is_time_paused_calls: int = 0
	var should_substep_physics_calls: int = 0
	var get_physics_scaled_delta_steps_calls: int = 0

	func _init(
		scheduler_instance: GFArchitectureTickScheduler,
		trigger_callback_name: StringName
	) -> void:
		scheduler = scheduler_instance
		trigger_callback = trigger_callback_name

	func get_scaled_delta(delta: float) -> float:
		get_scaled_delta_calls += 1
		_attempt_reentry(&"get_scaled_delta", false)
		return delta

	func is_time_paused() -> bool:
		is_time_paused_calls += 1
		_attempt_reentry(&"is_time_paused", false)
		return false

	func should_substep_physics(_delta: float) -> bool:
		should_substep_physics_calls += 1
		_attempt_reentry(&"should_substep_physics", true)
		return true

	func get_physics_scaled_delta_steps(delta: float) -> Array:
		get_physics_scaled_delta_steps_calls += 1
		_attempt_reentry(&"get_physics_scaled_delta_steps", true)
		return [delta]

	func _attempt_reentry(
		callback_name: StringName,
		physics: bool
	) -> void:
		if attempted_reentry or callback_name != trigger_callback:
			return
		attempted_reentry = true
		if physics:
			scheduler.drive_physics_tick(0.25, self)
			return
		scheduler.drive_tick(0.25, self)


# --- 测试方法 ---

func test_nested_drive_is_rejected_without_flushing_outer_cache() -> void:
	var systems: Dictionary = {}
	var utilities: Dictionary = {}
	var lifecycle_stages: Dictionary = {}
	var scheduler: GFArchitectureTickScheduler = GFArchitectureTickScheduler.new()
	var order: Array[String] = []
	var reentrant: ReentrantTickSystem = ReentrantTickSystem.new(scheduler, order)
	var follower: FollowerTickSystem = FollowerTickSystem.new(order)
	systems[ReentrantTickSystem] = reentrant
	systems[FollowerTickSystem] = follower
	lifecycle_stages[reentrant] = 4
	lifecycle_stages[follower] = 4
	var _configured_scheduler: GFArchitectureTickScheduler = scheduler.configure(
		systems,
		utilities,
		lifecycle_stages
	)

	scheduler.drive_tick(0.25, null)

	assert_eq(
		order,
		["reentrant", "follower"],
		"嵌套 drive 必须被拒绝，且外层剩余记录仍应恰好执行一次。"
	)
	assert_push_warning(
		"[GFArchitectureTickScheduler] 已拒绝嵌套 tick/physics_tick 调度；"
		+ "同一架构的 drive 调用不能重入。"
	)

	order.clear()
	scheduler.drive_tick(0.25, null)
	assert_eq(order, ["reentrant", "follower"], "外层结束后的缓存刷新不应破坏下一帧调度。")


func test_get_scaled_delta_provider_reentry_is_rejected_before_recursion() -> void:
	var counter: CountingTickSystem = CountingTickSystem.new()
	var scheduler: GFArchitectureTickScheduler = _make_counting_scheduler(counter)
	var provider: ReentrantTimeProvider = ReentrantTimeProvider.new(
		scheduler,
		&"get_scaled_delta"
	)

	scheduler.drive_tick(0.25, provider)

	assert_eq(provider.get_scaled_delta_calls, 1, "缩放回调重入不得递归调用 provider。")
	assert_eq(counter.tick_calls, 1, "缩放回调重入时外层 tick 应恰好执行一次。")
	_assert_reentry_warning()
	scheduler.drive_tick(0.25, provider)
	assert_eq(counter.tick_calls, 2, "缩放回调返回后 drive guard 必须恢复。")


func test_is_time_paused_provider_reentry_is_rejected_before_recursion() -> void:
	var counter: CountingTickSystem = CountingTickSystem.new()
	var scheduler: GFArchitectureTickScheduler = _make_counting_scheduler(counter)
	var provider: ReentrantTimeProvider = ReentrantTimeProvider.new(
		scheduler,
		&"is_time_paused"
	)

	scheduler.drive_tick(0.25, provider)

	assert_eq(provider.is_time_paused_calls, 1, "暂停查询重入不得递归调用 provider。")
	assert_eq(counter.tick_calls, 1, "暂停查询重入时外层 tick 应恰好执行一次。")
	_assert_reentry_warning()
	scheduler.drive_tick(0.25, provider)
	assert_eq(counter.tick_calls, 2, "暂停查询返回后 drive guard 必须恢复。")


func test_should_substep_provider_reentry_is_rejected_before_recursion() -> void:
	var counter: CountingTickSystem = CountingTickSystem.new()
	var scheduler: GFArchitectureTickScheduler = _make_counting_scheduler(counter)
	var provider: ReentrantTimeProvider = ReentrantTimeProvider.new(
		scheduler,
		&"should_substep_physics"
	)

	scheduler.drive_physics_tick(0.25, provider)

	assert_eq(
		provider.should_substep_physics_calls,
		1,
		"子步策略回调重入不得递归调用 provider。"
	)
	assert_eq(
		counter.physics_tick_calls,
		1,
		"子步策略回调重入时外层 physics_tick 应恰好执行一次。"
	)
	_assert_reentry_warning()
	scheduler.drive_physics_tick(0.25, provider)
	assert_eq(counter.physics_tick_calls, 2, "子步策略返回后 drive guard 必须恢复。")


func test_physics_steps_provider_reentry_is_rejected_before_recursion() -> void:
	var counter: CountingTickSystem = CountingTickSystem.new()
	var scheduler: GFArchitectureTickScheduler = _make_counting_scheduler(counter)
	var provider: ReentrantTimeProvider = ReentrantTimeProvider.new(
		scheduler,
		&"get_physics_scaled_delta_steps"
	)

	scheduler.drive_physics_tick(0.25, provider)

	assert_eq(
		provider.get_physics_scaled_delta_steps_calls,
		1,
		"物理步长回调重入不得递归调用 provider。"
	)
	assert_eq(
		counter.physics_tick_calls,
		1,
		"物理步长回调重入时外层 physics_tick 应恰好执行一次。"
	)
	_assert_reentry_warning()
	scheduler.drive_physics_tick(0.25, provider)
	assert_eq(counter.physics_tick_calls, 2, "物理步长回调返回后 drive guard 必须恢复。")


func test_regular_drives_require_committed_lifecycle_stage() -> void:
	var counter: CountingTickSystem = CountingTickSystem.new()
	var lifecycle_stages: Dictionary = {
		counter: 3,
	}
	var scheduler: GFArchitectureTickScheduler = GFArchitectureTickScheduler.new().configure(
		{CountingTickSystem: counter},
		{},
		lifecycle_stages
	)

	scheduler.drive_tick(0.25, null)
	scheduler.drive_physics_tick(0.25, null)

	assert_eq(counter.tick_calls, 0, "仅完成 ready 的模块不得进入普通 tick。")
	assert_eq(counter.physics_tick_calls, 0, "仅完成 ready 的模块不得进入 physics_tick。")

	lifecycle_stages[counter] = 4
	scheduler.drive_tick(0.25, null)
	scheduler.drive_physics_tick(0.25, null)

	assert_eq(counter.tick_calls, 1, "完成 activation 的模块应进入普通 tick。")
	assert_eq(counter.physics_tick_calls, 1, "完成 activation 的模块应进入 physics_tick。")


func test_lifecycle_drive_is_bounded_to_ready_allowed_tick_records() -> void:
	var allowed_counter: CountingTickSystem = CountingTickSystem.new()
	var unrelated_counter: CountingTickUtility = CountingTickUtility.new()
	var lifecycle_stages: Dictionary = {
		allowed_counter: 3,
		unrelated_counter: 4,
	}
	var scheduler: GFArchitectureTickScheduler = GFArchitectureTickScheduler.new().configure(
		{CountingTickSystem: allowed_counter},
		{CountingTickUtility: unrelated_counter},
		lifecycle_stages
	)

	scheduler.drive_lifecycle_tick(0.5, {allowed_counter: true})

	assert_eq(allowed_counter.tick_calls, 1, "生命周期驱动应推进显式允许且已 ready 的模块。")
	assert_almost_eq(
		allowed_counter.tick_deltas[0],
		0.1,
		0.0001,
		"生命周期 delta 必须限制到 0.1 秒。"
	)
	assert_eq(allowed_counter.physics_tick_calls, 0, "生命周期驱动不得调用 physics_tick。")
	assert_eq(unrelated_counter.tick_calls, 0, "生命周期驱动不得推进集合外模块。")
	assert_eq(unrelated_counter.physics_tick_calls, 0, "生命周期驱动不得推进集合外物理回调。")

	lifecycle_stages[allowed_counter] = 2
	scheduler.drive_lifecycle_tick(0.05, {allowed_counter: true})
	assert_eq(allowed_counter.tick_calls, 1, "尚未 ready 的允许模块也不得被推进。")

	lifecycle_stages.clear()
	scheduler.drive_lifecycle_tick(0.05, {allowed_counter: true})
	assert_eq(allowed_counter.tick_calls, 1, "生命周期阶段被清空后缓存记录不得继续推进。")


func test_lifecycle_drive_normalizes_non_monotonic_delta() -> void:
	var counter: CountingTickSystem = CountingTickSystem.new()
	var scheduler: GFArchitectureTickScheduler = _make_counting_scheduler(counter, 3)
	var allowed_instances: Dictionary = {
		counter: true,
	}

	scheduler.drive_lifecycle_tick(0.05, {})
	scheduler.drive_lifecycle_tick(-0.25, allowed_instances)
	scheduler.drive_lifecycle_tick(NAN, allowed_instances)
	scheduler.drive_lifecycle_tick(INF, allowed_instances)
	scheduler.drive_lifecycle_tick(0.05, allowed_instances)
	scheduler.drive_lifecycle_tick(0.5, allowed_instances)

	assert_eq(counter.tick_deltas.size(), 5, "有效记录应在每次生命周期推进中恰好执行一次。")
	assert_almost_eq(counter.tick_deltas[0], 0.0, 0.0001, "负 delta 应收束为零。")
	assert_almost_eq(counter.tick_deltas[1], 0.0, 0.0001, "NaN delta 应收束为零。")
	assert_almost_eq(counter.tick_deltas[2], 0.0, 0.0001, "Infinity delta 应收束为零。")
	assert_almost_eq(counter.tick_deltas[3], 0.05, 0.0001, "正常 caller delta 应保持。")
	assert_almost_eq(counter.tick_deltas[4], 0.1, 0.0001, "过大 delta 应限制到 0.1 秒。")


func test_lifecycle_drive_reuses_reentry_and_deferred_refresh_guard() -> void:
	var systems: Dictionary = {}
	var lifecycle_stages: Dictionary = {}
	var scheduler: GFArchitectureTickScheduler = GFArchitectureTickScheduler.new()
	var order: Array[String] = []
	var reentrant: ReentrantTickSystem = ReentrantTickSystem.new(scheduler, order)
	var follower: FollowerTickSystem = FollowerTickSystem.new(order)
	reentrant.tick_priority = -10
	follower.tick_priority = 10
	systems[ReentrantTickSystem] = reentrant
	systems[FollowerTickSystem] = follower
	lifecycle_stages[reentrant] = 3
	lifecycle_stages[follower] = 3
	var _configured_scheduler: GFArchitectureTickScheduler = scheduler.configure(
		systems,
		{},
		lifecycle_stages
	)
	var allowed_instances: Dictionary = {
		reentrant: true,
		follower: true,
	}

	scheduler.drive_lifecycle_tick(0.25, allowed_instances)

	assert_eq(
		order,
		["follower", "reentrant"],
		"生命周期驱动应复用 tick 缓存顺序，并拒绝嵌套 drive。"
	)
	_assert_reentry_warning()

	order.clear()
	scheduler.drive_lifecycle_tick(0.25, allowed_instances)
	assert_eq(
		order,
		["follower", "reentrant"],
		"外层生命周期驱动结束后延迟 refresh 应保留排序。"
	)


func test_uncommitted_lifecycle_candidate_is_never_exposed_to_regular_tick() -> void:
	var lifecycle_stages: Dictionary = {}
	var scheduler: GFArchitectureTickScheduler = (
		GFArchitectureTickScheduler.new().configure(
			{},
			{},
			lifecycle_stages
		)
	)
	var candidate: CountingTickUtility = CountingTickUtility.new()
	lifecycle_stages[candidate] = 3
	assert_true(scheduler.add_lifecycle_candidate(candidate))

	scheduler.drive_tick(0.1, null)
	scheduler.drive_lifecycle_tick(0.1, {candidate: true})
	scheduler.drive_physics_tick(0.1, null)

	assert_eq(candidate.tick_calls, 1)
	assert_eq(candidate.physics_tick_calls, 0)
	scheduler.remove_lifecycle_candidate(candidate)
	scheduler.drive_lifecycle_tick(0.1, {candidate: true})
	assert_eq(candidate.tick_calls, 1, "移除候选后不得继续驱动临时记录。")


# --- 私有/辅助方法 ---

func _make_counting_scheduler(
	counter: CountingTickSystem,
	lifecycle_stage: int = 4
) -> GFArchitectureTickScheduler:
	var systems: Dictionary = {
		CountingTickSystem: counter,
	}
	var lifecycle_stages: Dictionary = {
		counter: lifecycle_stage,
	}
	var scheduler: GFArchitectureTickScheduler = GFArchitectureTickScheduler.new()
	return scheduler.configure(systems, {}, lifecycle_stages)


func _assert_reentry_warning() -> void:
	assert_push_warning(
		"[GFArchitectureTickScheduler] 已拒绝嵌套 tick/physics_tick 调度；"
		+ "同一架构的 drive 调用不能重入。"
	)
