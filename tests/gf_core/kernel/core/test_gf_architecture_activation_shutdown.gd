## 验证 GFArchitecture 第四阶段激活与异步关闭边界。
extends GutTest


# --- 测试用模块 ---

class TickBootstrapUtility extends GFUtility:
	var lifecycle_log: Array[String] = []
	var activation_completion: GFAsyncCompletion = null
	var tick_count: int = 0
	var dispose_count: int = 0

	func _init(shared_log: Array[String]) -> void:
		lifecycle_log = shared_log
		tick_enabled = true

	func begin_activation(_scope: GFAsyncScope) -> GFAsyncCompletion:
		lifecycle_log.append("provider_activation")
		activation_completion = GFAsyncCompletion.new()
		return activation_completion

	func tick(_delta: float) -> void:
		tick_count += 1
		if tick_count >= 2 and activation_completion != null:
			var _succeeded: bool = activation_completion.succeed()

	func begin_quiesce(_scope: GFAsyncScope) -> GFAsyncCompletion:
		lifecycle_log.append("provider_quiesce")
		var completion: GFAsyncCompletion = GFAsyncCompletion.new()
		var _succeeded: bool = completion.succeed()
		return completion

	func dispose() -> void:
		dispose_count += 1


class DependentBootstrapSystem extends GFSystem:
	var lifecycle_log: Array[String] = []
	var dispose_count: int = 0

	func _init(shared_log: Array[String]) -> void:
		lifecycle_log = shared_log

	func get_required_utilities() -> Array[Script]:
		return [TickBootstrapUtility]

	func begin_activation(_scope: GFAsyncScope) -> GFAsyncCompletion:
		var provider: Object = get_utility(TickBootstrapUtility)
		lifecycle_log.append(
			"consumer_activation_ready"
			if provider is TickBootstrapUtility
			else "consumer_activation_missing"
		)
		var completion: GFAsyncCompletion = GFAsyncCompletion.new()
		var _succeeded: bool = completion.succeed()
		return completion

	func begin_quiesce(_scope: GFAsyncScope) -> GFAsyncCompletion:
		lifecycle_log.append("consumer_quiesce")
		var completion: GFAsyncCompletion = GFAsyncCompletion.new()
		var _succeeded: bool = completion.succeed()
		return completion

	func dispose() -> void:
		dispose_count += 1


class FailingActivationUtility extends GFUtility:
	var dispose_count: int = 0

	func begin_activation(_scope: GFAsyncScope) -> GFAsyncCompletion:
		var completion: GFAsyncCompletion = GFAsyncCompletion.new()
		var _failed: bool = completion.fail("activation fixture failure")
		return completion

	func dispose() -> void:
		dispose_count += 1


class PendingActivationUtility extends GFUtility:
	func begin_activation(_scope: GFAsyncScope) -> GFAsyncCompletion:
		return GFAsyncCompletion.new()


class StableShutdownUtility extends GFUtility:
	var activation_count: int = 0
	var quiesce_count: int = 0
	var dispose_count: int = 0

	func begin_activation(_scope: GFAsyncScope) -> GFAsyncCompletion:
		activation_count += 1
		var completion: GFAsyncCompletion = GFAsyncCompletion.new()
		var _succeeded: bool = completion.succeed()
		return completion

	func begin_quiesce(_scope: GFAsyncScope) -> GFAsyncCompletion:
		quiesce_count += 1
		var completion: GFAsyncCompletion = GFAsyncCompletion.new()
		var _succeeded: bool = completion.succeed()
		return completion

	func dispose() -> void:
		dispose_count += 1


class AwaitedHotRegisterUtility extends GFUtility:
	var activation_completion: GFAsyncCompletion = null
	var activation_count: int = 0
	var quiesce_count: int = 0
	var dispose_count: int = 0

	func begin_activation(_scope: GFAsyncScope) -> GFAsyncCompletion:
		activation_count += 1
		activation_completion = GFAsyncCompletion.new()
		return activation_completion

	func begin_quiesce(_scope: GFAsyncScope) -> GFAsyncCompletion:
		quiesce_count += 1
		var completion: GFAsyncCompletion = GFAsyncCompletion.new()
		var _succeeded: bool = completion.succeed()
		return completion

	func dispose() -> void:
		dispose_count += 1

	func complete_activation() -> bool:
		return (
			activation_completion != null
			and activation_completion.succeed()
		)


class AwaitedHotReplaceUtility extends GFUtility:
	var block_activation: bool = false
	var activation_completion: GFAsyncCompletion = null
	var activation_count: int = 0
	var quiesce_count: int = 0
	var dispose_count: int = 0

	func _init(p_block_activation: bool) -> void:
		block_activation = p_block_activation

	func begin_activation(_scope: GFAsyncScope) -> GFAsyncCompletion:
		activation_count += 1
		activation_completion = GFAsyncCompletion.new()
		if not block_activation:
			var _succeeded: bool = activation_completion.succeed()
		return activation_completion

	func begin_quiesce(_scope: GFAsyncScope) -> GFAsyncCompletion:
		quiesce_count += 1
		var completion: GFAsyncCompletion = GFAsyncCompletion.new()
		var _succeeded: bool = completion.succeed()
		return completion

	func dispose() -> void:
		dispose_count += 1

	func complete_activation() -> bool:
		return (
			activation_completion != null
			and activation_completion.succeed()
		)


class FailDuringHotActivationUtility extends GFUtility:
	var dispose_count: int = 0

	func begin_activation(_scope: GFAsyncScope) -> GFAsyncCompletion:
		var architecture: GFArchitecture = _get_architecture_or_null()
		if architecture != null:
			architecture.fail_initialization(
				"[test] fail during synchronous hot activation"
			)
		var completion: GFAsyncCompletion = GFAsyncCompletion.new()
		var _succeeded: bool = completion.succeed()
		return completion

	func dispose() -> void:
		dispose_count += 1


class CancelDuringQuiesceUtility extends GFUtility:
	var cancellation_source: GFCancellationSource = null
	var quiesce_count: int = 0
	var dispose_count: int = 0

	func _init(source: GFCancellationSource) -> void:
		cancellation_source = source

	func begin_quiesce(_scope: GFAsyncScope) -> GFAsyncCompletion:
		quiesce_count += 1
		var _cancelled: bool = cancellation_source.cancel(
			&"cancel_during_synchronous_quiesce"
		)
		var completion: GFAsyncCompletion = GFAsyncCompletion.new()
		var _succeeded: bool = completion.succeed()
		return completion

	func dispose() -> void:
		dispose_count += 1


class DeadlineCrossingQuiesceUtility extends GFUtility:
	var block_msec: int = 0
	var quiesce_count: int = 0
	var dispose_count: int = 0

	func _init(p_block_msec: int) -> void:
		block_msec = p_block_msec

	func begin_quiesce(_scope: GFAsyncScope) -> GFAsyncCompletion:
		quiesce_count += 1
		var release_at_msec: int = Time.get_ticks_msec() + block_msec
		while Time.get_ticks_msec() < release_at_msec:
			pass
		var completion: GFAsyncCompletion = GFAsyncCompletion.new()
		var _succeeded: bool = completion.succeed()
		return completion

	func dispose() -> void:
		dispose_count += 1


class AwaitedHotUnregisterUtility extends GFUtility:
	var quiesce_completion: GFAsyncCompletion = null
	var quiesce_count: int = 0
	var dispose_count: int = 0

	func begin_quiesce(_scope: GFAsyncScope) -> GFAsyncCompletion:
		quiesce_count += 1
		quiesce_completion = GFAsyncCompletion.new()
		return quiesce_completion

	func complete_quiesce() -> bool:
		return (
			quiesce_completion != null
			and quiesce_completion.succeed()
		)

	func dispose() -> void:
		dispose_count += 1


class CancelAfterAsyncInitUtility extends GFUtility:
	var cancellation_source: GFCancellationSource = null
	var ready_count: int = 0
	var activation_count: int = 0
	var dispose_count: int = 0

	func _init(source: GFCancellationSource) -> void:
		cancellation_source = source

	func async_init(_scope: GFAsyncScope) -> void:
		var _cancelled: bool = cancellation_source.cancel(
			&"cancel_after_async_init"
		)

	func ready() -> void:
		ready_count += 1

	func begin_activation(_scope: GFAsyncScope) -> GFAsyncCompletion:
		activation_count += 1
		var completion: GFAsyncCompletion = GFAsyncCompletion.new()
		var _succeeded: bool = completion.succeed()
		return completion

	func dispose() -> void:
		dispose_count += 1


class CancelAfterActivationSuccessUtility extends GFUtility:
	var cancellation_source: GFCancellationSource = null
	var activation_count: int = 0
	var dispose_count: int = 0

	func _init(source: GFCancellationSource) -> void:
		cancellation_source = source

	func begin_activation(_scope: GFAsyncScope) -> GFAsyncCompletion:
		activation_count += 1
		var completion: GFAsyncCompletion = GFAsyncCompletion.new()
		var _succeeded: bool = completion.succeed()
		var _cancelled: bool = cancellation_source.cancel(
			&"cancel_before_ready_commit"
		)
		return completion

	func dispose() -> void:
		dispose_count += 1


class ReversePlanDependencyUtility extends GFUtility:
	var dispose_log: Array[String] = []
	var dispose_count: int = 0

	func _init(shared_log: Array[String]) -> void:
		dispose_log = shared_log

	func dispose() -> void:
		dispose_count += 1
		dispose_log.append("dependency")


class ReversePlanConsumerUtility extends GFUtility:
	var dispose_log: Array[String] = []
	var dispose_count: int = 0

	func _init(shared_log: Array[String]) -> void:
		dispose_log = shared_log

	func get_required_utilities() -> Array[Script]:
		return [ReversePlanDependencyUtility]

	func dispose() -> void:
		dispose_count += 1
		dispose_log.append("consumer")


class ReversePlanFailingUtility extends GFUtility:
	var dispose_log: Array[String] = []
	var dispose_count: int = 0

	func _init(shared_log: Array[String]) -> void:
		dispose_log = shared_log

	func get_required_utilities() -> Array[Script]:
		return [ReversePlanConsumerUtility]

	func begin_activation(_scope: GFAsyncScope) -> GFAsyncCompletion:
		var completion: GFAsyncCompletion = GFAsyncCompletion.new()
		var _failed: bool = completion.fail("reverse cleanup fixture failure")
		return completion

	func dispose() -> void:
		dispose_count += 1
		dispose_log.append("failing")


class ReadyFailureDisposeProbeUtility extends GFUtility:
	var dispose_count: int = 0

	func dispose() -> void:
		dispose_count += 1


class CapturedPendingActivationUtility extends GFUtility:
	var activation_completion: GFAsyncCompletion = null
	var activation_count: int = 0
	var dispose_count: int = 0

	func begin_activation(_scope: GFAsyncScope) -> GFAsyncCompletion:
		activation_count += 1
		activation_completion = GFAsyncCompletion.new()
		return activation_completion

	func dispose() -> void:
		dispose_count += 1

	func complete_activation() -> bool:
		return (
			activation_completion != null
			and activation_completion.succeed()
		)


class TickDrivenQuiesceUtility extends GFUtility:
	var quiesce_completion: GFAsyncCompletion = null
	var quiesce_started: bool = false
	var quiesce_tick_count: int = 0
	var quiesce_count: int = 0
	var dispose_count: int = 0

	func _init() -> void:
		tick_enabled = true

	func tick(_delta: float) -> void:
		if not quiesce_started:
			return
		quiesce_tick_count += 1
		if quiesce_tick_count >= 2 and quiesce_completion != null:
			var _succeeded: bool = quiesce_completion.succeed()

	func begin_quiesce(_scope: GFAsyncScope) -> GFAsyncCompletion:
		quiesce_count += 1
		quiesce_started = true
		quiesce_completion = GFAsyncCompletion.new()
		return quiesce_completion

	func dispose() -> void:
		dispose_count += 1


class FailingQuiesceUtility extends GFUtility:
	var quiesce_count: int = 0
	var dispose_count: int = 0

	func begin_quiesce(_scope: GFAsyncScope) -> GFAsyncCompletion:
		quiesce_count += 1
		var completion: GFAsyncCompletion = GFAsyncCompletion.new()
		var _failed: bool = completion.fail("typed quiesce fixture failure")
		return completion

	func dispose() -> void:
		dispose_count += 1


class PendingDependentQuiesceUtility extends GFUtility:
	var quiesce_completion: GFAsyncCompletion = null
	var quiesce_count: int = 0
	var dispose_count: int = 0

	func get_required_utilities() -> Array[Script]:
		return [StableShutdownUtility]

	func begin_quiesce(_scope: GFAsyncScope) -> GFAsyncCompletion:
		quiesce_count += 1
		quiesce_completion = GFAsyncCompletion.new()
		return quiesce_completion

	func dispose() -> void:
		dispose_count += 1

	func complete_quiesce() -> bool:
		return (
			quiesce_completion != null
			and quiesce_completion.succeed()
		)


class ReentrantShutdownDisposeUtility extends GFUtility:
	var owner_architecture: GFArchitecture = null
	var dispose_count: int = 0
	var reentrant_request_count: int = 0
	var reentrant_done: bool = false
	var reentrant_result: GFArchitectureShutdownResult = null

	func _init(architecture: GFArchitecture) -> void:
		owner_architecture = architecture

	func dispose() -> void:
		dispose_count += 1
		if owner_architecture == null:
			return
		reentrant_request_count += 1
		@warning_ignore("missing_await")
		_capture_reentrant_shutdown(owner_architecture)

	func _capture_reentrant_shutdown(architecture: GFArchitecture) -> void:
		reentrant_result = await architecture.shutdown_async()
		reentrant_done = true


class ReentrantFailureCleanupUtility extends GFUtility:
	var owner_architecture: GFArchitecture = null
	var dispose_count: int = 0

	func _init(architecture: GFArchitecture) -> void:
		owner_architecture = architecture

	func begin_activation(_scope: GFAsyncScope) -> GFAsyncCompletion:
		var completion: GFAsyncCompletion = GFAsyncCompletion.new()
		var _failed: bool = completion.fail(
			"reentrant failure cleanup fixture"
		)
		return completion

	func dispose() -> void:
		dispose_count += 1
		if owner_architecture != null:
			owner_architecture.dispose()


class NestedCleanupSiblingUtility extends GFUtility:
	var dispose_count: int = 0

	func dispose() -> void:
		dispose_count += 1


class SecondIndependentUtility extends GFUtility:
	var dispose_count: int = 0

	func dispose() -> void:
		dispose_count += 1


class RuntimeFactoryProduct extends RefCounted:
	pass


# --- 测试 ---

func test_lifecycle_timeout_properties_accept_only_finite_closed_range() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var property_names: Array[StringName] = [
		&"module_async_init_timeout_seconds",
		&"activation_timeout_seconds",
		&"shutdown_timeout_seconds",
	]
	var invalid_values: Array[float] = [NAN, INF, -INF, -0.001, 86_400.001]
	for property_name: StringName in property_names:
		architecture.set(property_name, 0.0)
		assert_eq(_get_lifecycle_timeout_property(architecture, property_name), 0.0, "0 应是合法的无 deadline 边界。")
		architecture.set(property_name, 86_400.0)
		assert_eq(_get_lifecycle_timeout_property(architecture, property_name), 86_400.0, "86400 应是合法上界。")
		for invalid_value: float in invalid_values:
			architecture.set(property_name, invalid_value)
			assert_eq(
				_get_lifecycle_timeout_property(architecture, property_name),
				86_400.0,
				"无效 timeout 不得覆盖最近一次合法值：%s" % property_name
			)
	assert_push_error_count(15, "三个 timeout 属性应分别拒绝五种非有限或越界输入。")
	architecture.dispose()


func test_shutdown_timeout_override_validates_before_state_change() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	for invalid_value: float in [NAN, INF, -INF, -2.0, 86_400.001]:
		var invalid_result: GFArchitectureShutdownResult = (
			await architecture.shutdown_async(null, invalid_value)
		)
		assert_eq(
			invalid_result.get_status(),
			GFArchitectureShutdownResult.Status.FAILED,
			"无效 override 应返回 FAILED typed 结果。"
		)
		assert_eq(invalid_result.get_error_code(), ERR_INVALID_PARAMETER)
		assert_false(architecture.is_disposed(), "参数错误不得改变生命周期状态。")

	assert_true(await architecture.init())
	var upper_bound_result: GFArchitectureShutdownResult = (
		await architecture.shutdown_async(null, 86_400.0)
	)
	assert_true(upper_bound_result.is_successful(), "86400 override 应被正常接受。")
	var disposed_result: GFArchitectureShutdownResult = (
		await architecture.shutdown_async(null, 0.0)
	)
	assert_eq(
		disposed_result.get_status(),
		GFArchitectureShutdownResult.Status.ALREADY_DISPOSED,
		"合法 override 下的重复关闭应返回 ALREADY_DISPOSED。"
	)

	var zero_timeout_architecture: GFArchitecture = GFArchitecture.new()
	assert_true(await zero_timeout_architecture.init())
	var zero_timeout_result: GFArchitectureShutdownResult = (
		await zero_timeout_architecture.shutdown_async(null, 0.0)
	)
	assert_true(zero_timeout_result.is_successful(), "0 override 应作为合法无 deadline 值。")


func test_activation_waits_for_dependency_tick_before_ready_commit() -> void:
	var lifecycle_log: Array[String] = []
	var architecture: GFArchitecture = GFArchitecture.new()
	var consumer: DependentBootstrapSystem = DependentBootstrapSystem.new(
		lifecycle_log
	)
	var provider: TickBootstrapUtility = TickBootstrapUtility.new(lifecycle_log)

	assert_true(await architecture.register_system_instance(consumer))
	assert_true(await architecture.register_utility_instance(provider))
	assert_true(await architecture.init())
	assert_true(architecture.is_inited())
	assert_true(architecture.is_module_active(provider))
	assert_true(architecture.is_module_active(consumer))
	assert_gte(provider.tick_count, 2)
	assert_eq(
		lifecycle_log,
		["provider_activation", "consumer_activation_ready"],
		"依赖必须先激活，且只允许依赖闭包 tick 推进 bootstrap。"
	)

	var shutdown_result: GFArchitectureShutdownResult = (
		await architecture.shutdown_async()
	)
	assert_true(shutdown_result.is_successful())
	assert_eq(
		lifecycle_log,
		[
			"provider_activation",
			"consumer_activation_ready",
			"consumer_quiesce",
			"provider_quiesce",
		],
		"quiesce 必须严格逆转已提交的激活顺序。"
	)
	assert_eq(consumer.dispose_count, 1)
	assert_eq(provider.dispose_count, 1)


func test_activation_failure_never_opens_runtime_admission() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var utility: FailingActivationUtility = FailingActivationUtility.new()
	assert_true(await architecture.register_utility_instance(utility))

	assert_false(await architecture.init())
	assert_true(architecture.has_initialization_failed())
	assert_false(architecture.is_accepting_runtime_work())
	assert_false(architecture.is_module_active(utility))
	assert_eq(utility.dispose_count, 1)
	assert_push_error("[GFArchitecture] activation 失败")
	architecture.dispose()


func test_failed_initialization_requires_an_explicit_retry_call() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var utility: FailingActivationUtility = FailingActivationUtility.new()
	assert_true(await architecture.register_utility_instance(utility))

	assert_false(await architecture.init())
	assert_true(architecture.has_initialization_failed())
	assert_false(architecture.is_accepting_runtime_work())
	assert_eq(utility.dispose_count, 1)
	assert_push_error("[GFArchitecture] activation 失败")

	assert_true(await architecture.init())
	assert_true(architecture.is_inited())
	assert_true(architecture.is_accepting_runtime_work())
	assert_eq(utility.dispose_count, 1, "失败模块不得被隐式重新登记或重复释放。")

	var result: GFArchitectureShutdownResult = await architecture.shutdown_async()
	assert_true(result.is_successful())


func test_pre_cancelled_initialization_fails_closed() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var source: GFCancellationSource = GFCancellationSource.new()
	assert_true(source.cancel(&"test_cancel"))

	assert_false(await architecture.init(source.get_token()))
	assert_true(architecture.has_initialization_failed())
	assert_false(architecture.is_accepting_runtime_work())
	assert_push_error("[GFArchitecture] 初始化已取消")
	architecture.dispose()
	source.dispose()


func test_pending_activation_without_scene_tree_fails_instead_of_busy_spin() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	architecture.activation_timeout_seconds = 0.01
	var utility: PendingActivationUtility = PendingActivationUtility.new()
	assert_true(await architecture.register_utility_instance(utility))

	assert_false(await architecture.init())
	assert_true(architecture.has_initialization_failed())
	assert_push_error("[GFArchitecture] activation 失败")
	architecture.dispose()


func test_pending_activation_external_cancellation_rejects_late_success() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var source: GFCancellationSource = GFCancellationSource.new()
	var utility: CapturedPendingActivationUtility = (
		CapturedPendingActivationUtility.new()
	)
	assert_true(await architecture.register_utility_instance(utility))
	var init_state: Dictionary = {
		"done": false,
		"result": false,
	}

	@warning_ignore("missing_await")
	_await_init(architecture, source.get_token(), init_state)
	await get_tree().process_frame
	assert_eq(utility.activation_count, 1)
	assert_not_null(utility.activation_completion)
	assert_true(source.cancel(&"cancel_pending_activation"))
	await _wait_until_states_done([init_state])

	assert_false(GFVariantData.get_option_bool(init_state, "result"))
	assert_true(architecture.has_initialization_failed())
	assert_false(architecture.is_inited())
	assert_false(architecture.is_accepting_runtime_work())
	assert_true(utility.activation_completion.is_cancelled())
	assert_eq(
		utility.activation_completion.get_cancel_reason(),
		&"cancel_pending_activation"
	)
	assert_false(utility.complete_activation(), "取消终态不得接受迟到 activation 成功。")
	assert_eq(utility.dispose_count, 1)
	assert_push_error("[GFArchitecture] activation 已取消")

	architecture.dispose()
	assert_eq(utility.dispose_count, 1)
	source.dispose()


func test_concurrent_init_waiter_can_cancel_without_aborting_shared_activation() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var utility: CapturedPendingActivationUtility = (
		CapturedPendingActivationUtility.new()
	)
	var primary_state: Dictionary = {
		"done": false,
		"result": false,
	}
	var waiter_state: Dictionary = {
		"done": false,
		"result": true,
	}
	var waiter_source: GFCancellationSource = GFCancellationSource.new()
	assert_true(await architecture.register_utility_instance(utility))

	@warning_ignore("missing_await")
	_await_init(architecture, null, primary_state)
	await get_tree().process_frame
	assert_true(architecture.is_activating())

	@warning_ignore("missing_await")
	_await_init(architecture, waiter_source.get_token(), waiter_state)
	await get_tree().process_frame
	assert_true(waiter_source.cancel(&"cancel_joined_init_wait"))
	await _wait_until_states_done([waiter_state])

	assert_false(GFVariantData.get_option_bool(waiter_state, "result"))
	assert_false(GFVariantData.get_option_bool(primary_state, "done"))
	assert_true(architecture.is_activating(), "waiter 取消不得劫持共享初始化事务。")
	assert_false(utility.activation_completion.is_cancelled())

	assert_true(utility.complete_activation())
	await _wait_until_states_done([primary_state])
	assert_true(GFVariantData.get_option_bool(primary_state, "result"))
	assert_true(architecture.is_inited())

	var already_cancelled: GFCancellationSource = GFCancellationSource.new()
	assert_true(already_cancelled.cancel(&"ready_idempotent_call"))
	assert_true(
		await architecture.init(already_cancelled.get_token()),
		"架构已经 READY 时，幂等成功应优先于调用方取消状态。"
	)

	var result: GFArchitectureShutdownResult = await architecture.shutdown_async()
	assert_true(result.is_successful())
	waiter_source.dispose()
	already_cancelled.dispose()


func test_pending_activation_deadline_rejects_late_success() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	architecture.activation_timeout_seconds = 0.001
	var utility: CapturedPendingActivationUtility = (
		CapturedPendingActivationUtility.new()
	)
	assert_true(await architecture.register_utility_instance(utility))

	assert_false(await architecture.init())

	assert_eq(utility.activation_count, 1)
	assert_not_null(utility.activation_completion)
	assert_true(utility.activation_completion.is_cancelled())
	assert_eq(
		utility.activation_completion.get_cancel_reason(),
		&"lifecycle_timeout"
	)
	assert_false(utility.complete_activation(), "超时终态不得接受迟到 activation 成功。")
	assert_true(architecture.has_initialization_failed())
	assert_false(architecture.is_inited())
	assert_false(architecture.is_accepting_runtime_work())
	assert_eq(utility.dispose_count, 1)
	assert_push_error("[GFArchitecture] activation 失败")

	architecture.dispose()
	assert_eq(utility.dispose_count, 1)


func test_forced_dispose_runs_module_cleanup_exactly_once() -> void:
	var lifecycle_log: Array[String] = []
	var architecture: GFArchitecture = GFArchitecture.new()
	var provider: TickBootstrapUtility = TickBootstrapUtility.new(lifecycle_log)
	assert_true(await architecture.register_utility_instance(provider))
	assert_true(await architecture.init())

	architecture.dispose()
	architecture.dispose()

	assert_eq(provider.dispose_count, 1)
	assert_true(architecture.is_disposed())
	var result: GFArchitectureShutdownResult = architecture.get_last_shutdown_result()
	assert_not_null(result)
	assert_eq(result.get_status(), GFArchitectureShutdownResult.Status.FORCED)
	var unfinished_modules: Array[Dictionary] = result.get_unfinished_modules()
	assert_eq(unfinished_modules.size(), 1)
	assert_eq(
		GFVariantData.get_option_int(unfinished_modules[0], "instance_id"),
		provider.get_instance_id()
	)
	assert_eq(
		GFVariantData.get_option_string_name(unfinished_modules[0], "status"),
		&"skipped"
	)


func test_shutdown_interrupting_activation_reports_forced_unfinished_module() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var utility: CapturedPendingActivationUtility = (
		CapturedPendingActivationUtility.new()
	)
	var init_state: Dictionary = {
		"done": false,
		"result": true,
	}
	assert_true(await architecture.register_utility_instance(utility))
	@warning_ignore("missing_await")
	_await_init(architecture, null, init_state)
	await get_tree().process_frame
	assert_true(architecture.is_activating())

	var result: GFArchitectureShutdownResult = await architecture.shutdown_async()
	await _wait_until_states_done([init_state])

	assert_eq(result.get_status(), GFArchitectureShutdownResult.Status.FORCED)
	assert_false(GFVariantData.get_option_bool(init_state, "result"))
	assert_eq(utility.dispose_count, 1)
	var unfinished_modules: Array[Dictionary] = result.get_unfinished_modules()
	assert_eq(unfinished_modules.size(), 1)
	assert_eq(
		GFVariantData.get_option_int(unfinished_modules[0], "instance_id"),
		utility.get_instance_id()
	)
	assert_eq(
		GFVariantData.get_option_string_name(unfinished_modules[0], "status"),
		&"skipped"
	)


func test_direct_dispose_hook_reentrant_shutdown_publishes_one_terminal_result() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var utility: ReentrantShutdownDisposeUtility = (
		ReentrantShutdownDisposeUtility.new(architecture)
	)
	var signal_state: Dictionary = {
		"count": 0,
		"status": -1,
	}
	var shutdown_callback: Callable = Callable(
		self,
		&"_record_shutdown_finished"
	).bind(signal_state)
	var connect_error: Error = architecture.shutdown_finished.connect(
		shutdown_callback
	) as Error
	assert_eq(connect_error, OK)
	assert_true(await architecture.register_utility_instance(utility))
	assert_true(await architecture.init())

	architecture.dispose()
	await get_tree().process_frame

	assert_true(architecture.is_disposed())
	assert_eq(utility.dispose_count, 1)
	assert_eq(utility.reentrant_request_count, 1)
	assert_true(utility.reentrant_done)
	assert_not_null(utility.reentrant_result)
	if utility.reentrant_result != null:
		assert_eq(
			utility.reentrant_result.get_status(),
			GFArchitectureShutdownResult.Status.FORCED
		)
		assert_eq(utility.reentrant_result.get_duplicate_request_count(), 1)
	assert_eq(GFVariantData.get_option_int(signal_state, "count"), 1)
	assert_eq(
		GFVariantData.get_option_int(signal_state, "status"),
		GFArchitectureShutdownResult.Status.FORCED
	)
	var last_result: GFArchitectureShutdownResult = (
		architecture.get_last_shutdown_result()
	)
	assert_not_null(last_result)
	assert_eq(last_result.get_duplicate_request_count(), 1)


func test_failure_cleanup_reentrant_dispose_releases_each_module_once() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var sibling: NestedCleanupSiblingUtility = NestedCleanupSiblingUtility.new()
	var failing: ReentrantFailureCleanupUtility = (
		ReentrantFailureCleanupUtility.new(architecture)
	)
	assert_true(await architecture.register_utility_instance(sibling))
	assert_true(await architecture.register_utility_instance(failing))

	assert_false(await architecture.init())

	assert_true(architecture.is_disposed())
	assert_eq(failing.dispose_count, 1)
	assert_eq(sibling.dispose_count, 1)
	var result: GFArchitectureShutdownResult = architecture.get_last_shutdown_result()
	assert_not_null(result)
	if result != null:
		assert_eq(result.get_status(), GFArchitectureShutdownResult.Status.FORCED)
	assert_push_error("[GFArchitecture] activation 失败")

	architecture.dispose()
	assert_eq(failing.dispose_count, 1)
	assert_eq(sibling.dispose_count, 1)


func test_hot_register_runs_full_activation_transaction() -> void:
	var lifecycle_log: Array[String] = []
	var architecture: GFArchitecture = GFArchitecture.new()
	assert_true(await architecture.init())
	var provider: TickBootstrapUtility = TickBootstrapUtility.new(lifecycle_log)

	assert_true(await architecture.register_utility_instance(provider))
	assert_true(architecture.is_module_active(provider))
	assert_gte(provider.tick_count, 2)
	assert_eq(lifecycle_log, ["provider_activation"])

	var result: GFArchitectureShutdownResult = await architecture.shutdown_async()
	assert_true(result.is_successful())
	assert_eq(provider.dispose_count, 1)


func test_factory_creation_is_rejected_while_hot_topology_is_pending() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var invocation_state: Dictionary = {"count": 0}
	var factory: Callable = func() -> Object:
		invocation_state["count"] = (
			GFVariantData.get_option_int(invocation_state, "count") + 1
		)
		return RuntimeFactoryProduct.new()
	assert_true(architecture.register_factory(RuntimeFactoryProduct, factory))
	assert_true(await architecture.init())
	var candidate: AwaitedHotRegisterUtility = (
		AwaitedHotRegisterUtility.new()
	)
	var topology_state: Dictionary = {
		"done": false,
		"result": false,
	}

	@warning_ignore("missing_await")
	_await_hot_register(architecture, candidate, topology_state)
	await get_tree().process_frame
	assert_false(architecture.is_accepting_runtime_work())
	assert_null(architecture.create_instance(RuntimeFactoryProduct))
	assert_eq(GFVariantData.get_option_int(invocation_state, "count"), 0)
	assert_push_error("模块拓扑事务尚未完成")

	assert_true(candidate.complete_activation())
	await _wait_until_states_done([topology_state])
	assert_true(GFVariantData.get_option_bool(topology_state, "result"))
	assert_not_null(architecture.create_instance(RuntimeFactoryProduct))
	assert_eq(GFVariantData.get_option_int(invocation_state, "count"), 1)

	var result: GFArchitectureShutdownResult = await architecture.shutdown_async()
	assert_true(result.is_successful())


func test_factory_creation_is_rejected_after_quiesce_closes_admission() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var invocation_state: Dictionary = {"count": 0}
	var factory: Callable = func() -> Object:
		invocation_state["count"] = (
			GFVariantData.get_option_int(invocation_state, "count") + 1
		)
		return RuntimeFactoryProduct.new()
	var provider: StableShutdownUtility = StableShutdownUtility.new()
	var quiesce_gate: PendingDependentQuiesceUtility = (
		PendingDependentQuiesceUtility.new()
	)
	assert_true(architecture.register_factory(RuntimeFactoryProduct, factory))
	assert_true(await architecture.register_utility_instance(provider))
	assert_true(await architecture.register_utility_instance(quiesce_gate))
	assert_true(await architecture.init())
	var shutdown_state: Dictionary = {
		"done": false,
		"result": null,
	}

	@warning_ignore("missing_await")
	_await_shutdown(architecture, null, 1.0, shutdown_state)
	await get_tree().process_frame
	assert_true(architecture.is_quiescing())
	assert_null(architecture.create_instance(RuntimeFactoryProduct))
	assert_eq(GFVariantData.get_option_int(invocation_state, "count"), 0)
	assert_push_error("架构正在 quiesce")

	assert_true(quiesce_gate.complete_quiesce())
	await _wait_until_states_done([shutdown_state])
	var result: GFArchitectureShutdownResult = (
		_shutdown_result_from_state(shutdown_state)
	)
	assert_not_null(result)
	assert_true(result.is_successful())


func test_synchronous_hot_activation_failure_does_not_restore_plan_or_double_dispose() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var stable: StableShutdownUtility = StableShutdownUtility.new()
	assert_true(await architecture.register_utility_instance(stable))
	assert_true(await architecture.init())
	var candidate: FailDuringHotActivationUtility = (
		FailDuringHotActivationUtility.new()
	)

	assert_false(await architecture.register_utility_instance(candidate))
	assert_true(architecture.has_initialization_failed())
	assert_eq(stable.dispose_count, 1)
	assert_eq(candidate.dispose_count, 1)
	var dependency_report: Dictionary = architecture.get_dependency_diagnostics()
	assert_eq(
		GFVariantData.get_option_int(dependency_report, "module_count"),
		0,
		"同步成功 completion 不得在 fail_initialization 后恢复陈旧 lifecycle plan。"
	)
	assert_push_error("[test] fail during synchronous hot activation")
	assert_push_error("[GFArchitecture] 热模块 activation 失败")

	architecture.dispose()
	architecture.dispose()
	assert_eq(stable.dispose_count, 1, "失败清理后的旧计划模块不得再次 dispose。")
	assert_eq(candidate.dispose_count, 1, "失败清理后的热注册候选不得再次 dispose。")


func test_hot_replace_activates_candidate_before_old_quiesce_and_commit() -> void:
	var lifecycle_log: Array[String] = []
	var architecture: GFArchitecture = GFArchitecture.new()
	var previous: TickBootstrapUtility = TickBootstrapUtility.new(lifecycle_log)
	assert_true(await architecture.register_utility_instance(previous))
	assert_true(await architecture.init())
	var replacement: TickBootstrapUtility = TickBootstrapUtility.new(lifecycle_log)

	assert_true(
		await architecture.replace_utility(
			TickBootstrapUtility,
			replacement
		)
	)
	assert_eq(
		architecture.get_utility(TickBootstrapUtility, true),
		replacement
	)
	assert_true(architecture.is_module_active(replacement))
	assert_false(architecture.is_module_active(previous))
	assert_eq(previous.dispose_count, 1)
	assert_eq(
		lifecycle_log,
		[
			"provider_activation",
			"provider_activation",
			"provider_quiesce",
		],
		"候选 activation 成功后，旧实例必须先 quiesce 再提交替换。"
	)

	var result: GFArchitectureShutdownResult = await architecture.shutdown_async()
	assert_true(result.is_successful())
	assert_eq(previous.dispose_count, 1)
	assert_eq(replacement.dispose_count, 1)


func test_hot_unregister_rejects_removing_live_dependency() -> void:
	var lifecycle_log: Array[String] = []
	var architecture: GFArchitecture = GFArchitecture.new()
	var provider: TickBootstrapUtility = TickBootstrapUtility.new(lifecycle_log)
	var consumer: DependentBootstrapSystem = DependentBootstrapSystem.new(
		lifecycle_log
	)
	assert_true(await architecture.register_utility_instance(provider))
	assert_true(await architecture.register_system_instance(consumer))
	assert_true(await architecture.init())

	assert_false(
		await architecture.unregister_utility(TickBootstrapUtility),
		"仍被活动模块声明依赖的 provider 不得从候选 DAG 移除。"
	)
	assert_eq(
		architecture.get_utility(TickBootstrapUtility, true),
		provider
	)
	assert_push_error("[GFArchitecture] hot unregister 失败")

	var result: GFArchitectureShutdownResult = await architecture.shutdown_async()
	assert_true(result.is_successful())


func test_hot_unregister_quiesces_and_removes_independent_module() -> void:
	var lifecycle_log: Array[String] = []
	var architecture: GFArchitecture = GFArchitecture.new()
	var provider: TickBootstrapUtility = TickBootstrapUtility.new(lifecycle_log)
	assert_true(await architecture.register_utility_instance(provider))
	assert_true(await architecture.init())

	assert_true(await architecture.unregister_utility(TickBootstrapUtility))
	assert_null(architecture.get_utility(TickBootstrapUtility))
	assert_eq(provider.dispose_count, 1)
	assert_eq(
		lifecycle_log,
		["provider_activation", "provider_quiesce"]
	)

	var result: GFArchitectureShutdownResult = await architecture.shutdown_async()
	assert_true(result.is_successful())
	assert_eq(provider.dispose_count, 1)


func test_hot_unregister_uses_stable_identity_not_registry_ordinal() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var first: StableShutdownUtility = StableShutdownUtility.new()
	var second: SecondIndependentUtility = SecondIndependentUtility.new()
	assert_true(await architecture.register_utility_instance(first))
	assert_true(await architecture.register_utility_instance(second))
	assert_true(await architecture.init())

	assert_true(
		await architecture.unregister_utility(StableShutdownUtility),
		"删除同类注册表的首项不得让后续独立模块因 ordinal 改变被误判依赖漂移。"
	)

	assert_eq(first.dispose_count, 1)
	assert_same(
		architecture.get_local_utility(
			SecondIndependentUtility,
			true
		),
		second
	)
	assert_true(architecture.is_module_active(second))
	assert_eq(second.dispose_count, 0)

	var result: GFArchitectureShutdownResult = await architecture.shutdown_async()
	assert_true(result.is_successful())
	assert_eq(second.dispose_count, 1)


func test_shutdown_waits_for_accepted_hot_register_before_quiescing_final_plan() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var stable: StableShutdownUtility = StableShutdownUtility.new()
	assert_true(await architecture.register_utility_instance(stable))
	assert_true(await architecture.init())

	var candidate: AwaitedHotRegisterUtility = AwaitedHotRegisterUtility.new()
	var register_state: Dictionary = {
		"done": false,
		"result": false,
	}
	@warning_ignore("missing_await")
	_await_hot_register(architecture, candidate, register_state)
	await get_tree().process_frame
	assert_eq(candidate.activation_count, 1)

	var shutdown_state: Dictionary = {
		"done": false,
		"result": null,
	}
	@warning_ignore("missing_await")
	_await_shutdown(architecture, null, 0.5, shutdown_state)
	await get_tree().process_frame

	assert_false(architecture.is_accepting_runtime_work(), "shutdown 开始后必须先关闭新工作准入。")
	assert_false(
		GFVariantData.get_option_bool(shutdown_state, "done"),
		"已接纳 hot register 未稳定前 shutdown 不得提前完成。"
	)
	assert_eq(stable.quiesce_count, 0, "topology 稳定前不得 quiesce 旧计划模块。")
	assert_eq(candidate.quiesce_count, 0, "topology 稳定前不得 quiesce 注册候选。")

	assert_true(candidate.complete_activation())
	await _wait_until_states_done([register_state, shutdown_state])

	assert_true(GFVariantData.get_option_bool(register_state, "result"))
	var result: GFArchitectureShutdownResult = _shutdown_result_from_state(
		shutdown_state
	)
	assert_not_null(result)
	assert_true(result.is_successful())
	assert_eq(stable.quiesce_count, 1, "最终计划中的旧模块只应 quiesce 一次。")
	assert_eq(candidate.quiesce_count, 1, "最终计划中的注册候选只应 quiesce 一次。")
	assert_eq(stable.dispose_count, 1)
	assert_eq(candidate.dispose_count, 1)


func test_shutdown_waits_for_accepted_hot_replace_before_quiescing_final_plan() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var previous: AwaitedHotReplaceUtility = AwaitedHotReplaceUtility.new(false)
	assert_true(await architecture.register_utility_instance(previous))
	assert_true(await architecture.init())

	var replacement: AwaitedHotReplaceUtility = AwaitedHotReplaceUtility.new(true)
	var replace_state: Dictionary = {
		"done": false,
		"result": false,
	}
	@warning_ignore("missing_await")
	_await_hot_replace(architecture, replacement, replace_state)
	await get_tree().process_frame
	assert_eq(replacement.activation_count, 1)

	var shutdown_state: Dictionary = {
		"done": false,
		"result": null,
	}
	@warning_ignore("missing_await")
	_await_shutdown(architecture, null, 0.5, shutdown_state)
	await get_tree().process_frame

	assert_false(architecture.is_accepting_runtime_work(), "shutdown 开始后必须先关闭新工作准入。")
	assert_false(
		GFVariantData.get_option_bool(shutdown_state, "done"),
		"已接纳 hot replace 未稳定前 shutdown 不得提前完成。"
	)
	assert_eq(previous.quiesce_count, 0, "候选 activation 未完成前不得 quiesce 旧实例。")
	assert_eq(replacement.quiesce_count, 0, "topology 稳定前不得 quiesce 替换候选。")

	assert_true(replacement.complete_activation())
	await _wait_until_states_done([replace_state, shutdown_state])

	assert_true(GFVariantData.get_option_bool(replace_state, "result"))
	var result: GFArchitectureShutdownResult = _shutdown_result_from_state(
		shutdown_state
	)
	assert_not_null(result)
	assert_true(result.is_successful())
	assert_eq(previous.quiesce_count, 1, "旧实例只应由已接纳 replace 事务 quiesce 一次。")
	assert_eq(replacement.quiesce_count, 1, "最终计划中的替换实例只应由 shutdown quiesce 一次。")
	assert_eq(previous.dispose_count, 1)
	assert_eq(replacement.dispose_count, 1)


func test_topology_wait_timeout_forces_cleanup_without_late_commit_or_double_dispose() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var previous: AwaitedHotReplaceUtility = AwaitedHotReplaceUtility.new(false)
	assert_true(await architecture.register_utility_instance(previous))
	assert_true(await architecture.init())

	var replacement: AwaitedHotReplaceUtility = AwaitedHotReplaceUtility.new(true)
	var replace_state: Dictionary = {
		"done": false,
		"result": false,
	}
	@warning_ignore("missing_await")
	_await_hot_replace(architecture, replacement, replace_state)
	await get_tree().process_frame
	assert_eq(replacement.activation_count, 1)

	var result: GFArchitectureShutdownResult = await architecture.shutdown_async(
		null,
		0.001
	)

	assert_eq(result.get_status(), GFArchitectureShutdownResult.Status.TIMED_OUT)
	assert_true(architecture.is_disposed())
	assert_eq(previous.dispose_count, 1, "shutdown 返回时旧实例必须已经 exactly-once 释放。")
	assert_eq(
		replacement.dispose_count,
		1,
		"shutdown 超时结果返回下一行，未提交替换候选必须已经清理。"
	)

	await _wait_until_states_done([replace_state])
	assert_false(GFVariantData.get_option_bool(replace_state, "result"))
	assert_eq(previous.dispose_count, 1, "强制释放旧实例必须 exactly-once。")
	assert_eq(replacement.dispose_count, 1, "未提交替换候选也必须 exactly-once 清理。")

	assert_false(replacement.complete_activation(), "超时取消后的 activation completion 不得迟到成功。")
	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(previous.dispose_count, 1, "迟到恢复不得重复释放旧实例。")
	assert_eq(replacement.dispose_count, 1, "迟到恢复不得重复释放替换候选。")
	assert_true(architecture.is_disposed(), "迟到恢复不得重新提交 topology。")
	assert_push_error("[GFArchitecture] 热模块 activation 失败")


func test_topology_wait_cancel_cleans_pending_replacement_before_return() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var previous: AwaitedHotReplaceUtility = AwaitedHotReplaceUtility.new(false)
	assert_true(await architecture.register_utility_instance(previous))
	assert_true(await architecture.init())

	var replacement: AwaitedHotReplaceUtility = AwaitedHotReplaceUtility.new(true)
	var replace_state: Dictionary = {
		"done": false,
		"result": false,
	}
	@warning_ignore("missing_await")
	_await_hot_replace(architecture, replacement, replace_state)
	await get_tree().process_frame
	assert_eq(replacement.activation_count, 1)

	var source: GFCancellationSource = GFCancellationSource.new()
	@warning_ignore("missing_await")
	_cancel_on_next_frame(source, &"cancel_pending_hot_replacement")
	var result: GFArchitectureShutdownResult = await architecture.shutdown_async(
		source.get_token(),
		0.5
	)

	assert_eq(result.get_status(), GFArchitectureShutdownResult.Status.CANCELLED)
	assert_eq(result.get_cancel_reason(), "cancel_pending_hot_replacement")
	assert_true(architecture.is_disposed())
	assert_eq(previous.dispose_count, 1, "shutdown 返回时旧实例必须已经 exactly-once 释放。")
	assert_eq(
		replacement.dispose_count,
		1,
		"shutdown 取消结果返回下一行，未提交替换候选必须已经清理。"
	)

	await _wait_until_states_done([replace_state])
	assert_false(GFVariantData.get_option_bool(replace_state, "result"))
	assert_false(replacement.complete_activation(), "取消后的 activation completion 不得迟到成功。")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(previous.dispose_count, 1)
	assert_eq(replacement.dispose_count, 1, "迟到 continuation 不得重复清理替换候选。")
	assert_push_error("[GFArchitecture] 热模块 activation 失败")
	source.dispose()


func test_concurrent_shutdown_is_single_flight_and_first_caller_owns_policy() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var utility: AwaitedHotUnregisterUtility = AwaitedHotUnregisterUtility.new()
	var signal_state: Dictionary = {
		"count": 0,
		"status": -1,
	}
	var shutdown_callback: Callable = Callable(
		self,
		&"_record_shutdown_finished"
	).bind(signal_state)
	var connect_error: Error = architecture.shutdown_finished.connect(
		shutdown_callback
	) as Error
	assert_eq(connect_error, OK)
	assert_true(await architecture.register_utility_instance(utility))
	assert_true(await architecture.init())

	var first_state: Dictionary = {
		"done": false,
		"result": null,
	}
	@warning_ignore("missing_await")
	_await_shutdown(architecture, null, 0.5, first_state)
	await get_tree().process_frame
	assert_eq(utility.quiesce_count, 1)

	var duplicate_source: GFCancellationSource = GFCancellationSource.new()
	assert_true(duplicate_source.cancel(&"duplicate_policy_must_not_win"))
	var second_state: Dictionary = {
		"done": false,
		"result": null,
	}
	@warning_ignore("missing_await")
	_await_shutdown(
		architecture,
		duplicate_source.get_token(),
		0.001,
		second_state
	)
	await get_tree().process_frame
	assert_false(GFVariantData.get_option_bool(first_state, "done"))
	assert_false(GFVariantData.get_option_bool(second_state, "done"))
	assert_eq(utility.quiesce_count, 1, "重复 shutdown 不得再次调用 quiesce hook。")

	assert_true(utility.complete_quiesce())
	await _wait_until_states_done([first_state, second_state])

	var first_result: GFArchitectureShutdownResult = (
		_shutdown_result_from_state(first_state)
	)
	var second_result: GFArchitectureShutdownResult = (
		_shutdown_result_from_state(second_state)
	)
	assert_not_null(first_result)
	assert_not_null(second_result)
	assert_true(first_result.is_successful())
	assert_true(second_result.is_successful())
	assert_eq(first_result.get_duplicate_request_count(), 1)
	assert_eq(second_result.get_duplicate_request_count(), 1)
	assert_eq(
		first_result.get_started_at_msec(),
		second_result.get_started_at_msec()
	)
	assert_eq(
		first_result.get_completed_at_msec(),
		second_result.get_completed_at_msec()
	)
	assert_eq(first_result.get_module_results(), second_result.get_module_results())
	assert_eq(utility.quiesce_count, 1)
	assert_eq(utility.dispose_count, 1)
	assert_eq(GFVariantData.get_option_int(signal_state, "count"), 1)
	assert_eq(
		GFVariantData.get_option_int(signal_state, "status"),
		GFArchitectureShutdownResult.Status.SUCCEEDED
	)
	duplicate_source.dispose()


func test_shutdown_quiesce_can_complete_from_lifecycle_tick() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var utility: TickDrivenQuiesceUtility = TickDrivenQuiesceUtility.new()
	assert_true(await architecture.register_utility_instance(utility))
	assert_true(await architecture.init())

	var result: GFArchitectureShutdownResult = await architecture.shutdown_async(
		null,
		0.5
	)

	assert_true(result.is_successful())
	assert_eq(utility.quiesce_count, 1)
	assert_gte(utility.quiesce_tick_count, 2)
	assert_true(utility.quiesce_completion.is_successful())
	assert_eq(utility.dispose_count, 1)
	var module_results: Array[Dictionary] = result.get_module_results()
	assert_eq(module_results.size(), 1)
	assert_eq(
		GFVariantData.get_option_string_name(module_results[0], "status"),
		&"succeeded"
	)


func test_failed_quiesce_returns_typed_module_evidence() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var utility: FailingQuiesceUtility = FailingQuiesceUtility.new()
	assert_true(await architecture.register_utility_instance(utility))
	assert_true(await architecture.init())

	var result: GFArchitectureShutdownResult = await architecture.shutdown_async()

	assert_eq(result.get_status(), GFArchitectureShutdownResult.Status.FAILED)
	assert_eq(result.get_error_code(), FAILED)
	assert_eq(utility.quiesce_count, 1)
	assert_eq(utility.dispose_count, 1)
	var module_results: Array[Dictionary] = result.get_module_results()
	var unfinished_modules: Array[Dictionary] = result.get_unfinished_modules()
	assert_eq(module_results.size(), 1)
	assert_eq(unfinished_modules.size(), 1)
	var module_entry: Dictionary = module_results[0]
	var unfinished_entry: Dictionary = unfinished_modules[0]
	assert_eq(
		GFVariantData.get_option_string_name(module_entry, "kind"),
		&"utility"
	)
	assert_eq(
		GFVariantData.get_option_int(module_entry, "instance_id"),
		utility.get_instance_id()
	)
	assert_eq(
		GFVariantData.get_option_string_name(module_entry, "status"),
		&"failed"
	)
	assert_eq(
		GFVariantData.get_option_string(module_entry, "reason"),
		"typed quiesce fixture failure"
	)
	assert_eq(unfinished_entry, module_entry)


func test_timed_out_quiesce_reports_current_and_skipped_modules() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var provider: StableShutdownUtility = StableShutdownUtility.new()
	var timed_out_utility: PendingDependentQuiesceUtility = (
		PendingDependentQuiesceUtility.new()
	)
	assert_true(await architecture.register_utility_instance(provider))
	assert_true(await architecture.register_utility_instance(timed_out_utility))
	assert_true(await architecture.init())

	var result: GFArchitectureShutdownResult = await architecture.shutdown_async(
		null,
		0.5
	)

	assert_eq(result.get_status(), GFArchitectureShutdownResult.Status.TIMED_OUT)
	assert_eq(result.get_error_code(), ERR_TIMEOUT)
	assert_eq(timed_out_utility.quiesce_count, 1)
	assert_eq(provider.quiesce_count, 0, "deadline 后不得开始后续 provider quiesce。")
	assert_not_null(timed_out_utility.quiesce_completion)
	if timed_out_utility.quiesce_completion != null:
		assert_true(timed_out_utility.quiesce_completion.is_cancelled())
	assert_false(timed_out_utility.complete_quiesce(), "超时 completion 不得接受迟到成功。")
	var module_results: Array[Dictionary] = result.get_module_results()
	var unfinished_modules: Array[Dictionary] = result.get_unfinished_modules()
	assert_eq(module_results.size(), 1)
	assert_eq(unfinished_modules.size(), 2)
	assert_eq(
		GFVariantData.get_option_int(module_results[0], "instance_id"),
		timed_out_utility.get_instance_id()
	)
	assert_eq(
		GFVariantData.get_option_string_name(module_results[0], "status"),
		&"timed_out"
	)
	assert_eq(
		GFVariantData.get_option_string_name(unfinished_modules[0], "status"),
		&"timed_out"
	)
	assert_eq(
		GFVariantData.get_option_int(unfinished_modules[1], "instance_id"),
		provider.get_instance_id()
	)
	assert_eq(
		GFVariantData.get_option_string_name(unfinished_modules[1], "status"),
		&"skipped"
	)
	assert_eq(timed_out_utility.dispose_count, 1)
	assert_eq(provider.dispose_count, 1)


func test_pre_cancelled_shutdown_returns_cancelled_for_empty_plan() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	assert_true(await architecture.init())
	var source: GFCancellationSource = GFCancellationSource.new()
	assert_true(source.cancel(&"pre_cancelled_empty_shutdown"))

	var result: GFArchitectureShutdownResult = await architecture.shutdown_async(
		source.get_token()
	)

	assert_eq(result.get_status(), GFArchitectureShutdownResult.Status.CANCELLED)
	assert_eq(result.get_cancel_reason(), "pre_cancelled_empty_shutdown")
	assert_true(architecture.is_disposed())
	source.dispose()


func test_synchronous_quiesce_cancellation_wins_over_successful_completion() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var source: GFCancellationSource = GFCancellationSource.new()
	var utility: CancelDuringQuiesceUtility = CancelDuringQuiesceUtility.new(
		source
	)
	assert_true(await architecture.register_utility_instance(utility))
	assert_true(await architecture.init())

	var result: GFArchitectureShutdownResult = await architecture.shutdown_async(
		source.get_token(),
		0.5
	)

	assert_eq(result.get_status(), GFArchitectureShutdownResult.Status.CANCELLED)
	assert_eq(result.get_cancel_reason(), "cancel_during_synchronous_quiesce")
	assert_eq(utility.quiesce_count, 1)
	assert_eq(utility.dispose_count, 1)
	assert_true(architecture.is_disposed())
	source.dispose()


func test_synchronous_quiesce_crossing_deadline_returns_timed_out() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var utility: DeadlineCrossingQuiesceUtility = (
		DeadlineCrossingQuiesceUtility.new(40)
	)
	assert_true(await architecture.register_utility_instance(utility))
	assert_true(await architecture.init())

	var result: GFArchitectureShutdownResult = await architecture.shutdown_async(
		null,
		0.01
	)

	assert_eq(result.get_status(), GFArchitectureShutdownResult.Status.TIMED_OUT)
	assert_eq(utility.quiesce_count, 1)
	assert_eq(utility.dispose_count, 1)
	assert_true(architecture.is_disposed())


func test_empty_final_plan_rechecks_deadline_after_topology_stabilizes() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var utility: AwaitedHotUnregisterUtility = AwaitedHotUnregisterUtility.new()
	assert_true(await architecture.register_utility_instance(utility))
	assert_true(await architecture.init())

	@warning_ignore("missing_await")
	_complete_quiesce_after_blocking_frame(utility, 40)
	var unregister_state: Dictionary = {
		"done": false,
		"result": false,
	}
	@warning_ignore("missing_await")
	_await_hot_unregister(architecture, unregister_state)
	var result: GFArchitectureShutdownResult = await architecture.shutdown_async(
		null,
		0.01
	)

	assert_true(GFVariantData.get_option_bool(unregister_state, "done"))
	assert_true(GFVariantData.get_option_bool(unregister_state, "result"))
	assert_eq(
		result.get_status(),
		GFArchitectureShutdownResult.Status.TIMED_OUT,
		"topology 在 deadline 后稳定为空计划时，shutdown 不得错误报告成功。"
	)
	assert_eq(utility.quiesce_count, 1)
	assert_eq(utility.dispose_count, 1)
	assert_true(architecture.is_disposed())


func test_init_rechecks_cancellation_after_async_init_before_ready() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var source: GFCancellationSource = GFCancellationSource.new()
	var utility: CancelAfterAsyncInitUtility = CancelAfterAsyncInitUtility.new(
		source
	)
	assert_true(await architecture.register_utility_instance(utility))

	assert_false(await architecture.init(source.get_token()))
	assert_true(architecture.has_initialization_failed())
	assert_false(architecture.is_inited())
	assert_eq(utility.ready_count, 0, "async_init await 后必须先复检取消，再进入 ready。")
	assert_eq(utility.activation_count, 0)
	assert_eq(utility.dispose_count, 1)
	assert_push_error("[GFArchitecture] 初始化已取消")

	architecture.dispose()
	assert_eq(utility.dispose_count, 1)
	source.dispose()


func test_init_rechecks_cancellation_before_final_ready_commit() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var source: GFCancellationSource = GFCancellationSource.new()
	var utility: CancelAfterActivationSuccessUtility = (
		CancelAfterActivationSuccessUtility.new(source)
	)
	assert_true(await architecture.register_utility_instance(utility))

	assert_false(await architecture.init(source.get_token()))
	assert_eq(utility.activation_count, 1)
	assert_true(architecture.has_initialization_failed())
	assert_false(architecture.is_inited(), "最后一个 activation 成功后仍须复检取消，禁止提交 READY。")
	assert_false(architecture.is_accepting_runtime_work())
	assert_eq(utility.dispose_count, 1)
	assert_push_error("[GFArchitecture] activation 已取消")

	architecture.dispose()
	assert_eq(utility.dispose_count, 1)
	source.dispose()


func test_activation_failure_cleans_plan_in_strict_reverse_order_exactly_once() -> void:
	var dispose_log: Array[String] = []
	var architecture: GFArchitecture = GFArchitecture.new()
	var dependency: ReversePlanDependencyUtility = (
		ReversePlanDependencyUtility.new(dispose_log)
	)
	var consumer: ReversePlanConsumerUtility = (
		ReversePlanConsumerUtility.new(dispose_log)
	)
	var failing: ReversePlanFailingUtility = (
		ReversePlanFailingUtility.new(dispose_log)
	)

	assert_true(await architecture.register_utility_instance(failing))
	assert_true(await architecture.register_utility_instance(consumer))
	assert_true(await architecture.register_utility_instance(dependency))

	assert_false(await architecture.init())
	assert_eq(
		dispose_log,
		["failing", "consumer", "dependency"],
		"activation 失败必须严格逆转编译计划，不能退化为注册表遍历顺序。"
	)
	assert_eq(failing.dispose_count, 1)
	assert_eq(consumer.dispose_count, 1)
	assert_eq(dependency.dispose_count, 1)
	assert_push_error("[GFArchitecture] activation 失败")

	architecture.dispose()
	assert_eq(failing.dispose_count, 1)
	assert_eq(consumer.dispose_count, 1)
	assert_eq(dependency.dispose_count, 1)


func test_ready_failure_then_dispose_does_not_release_module_twice() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var utility: ReadyFailureDisposeProbeUtility = (
		ReadyFailureDisposeProbeUtility.new()
	)
	assert_true(await architecture.register_utility_instance(utility))
	assert_true(await architecture.init())

	architecture.fail_initialization("[test] ready failure")
	assert_true(architecture.has_initialization_failed())
	assert_eq(utility.dispose_count, 1, "READY 后首次 fail_initialization 应只释放一次。")
	assert_push_error("[test] ready failure")

	architecture.dispose()
	architecture.dispose()
	assert_true(architecture.is_disposed())
	assert_eq(utility.dispose_count, 1, "fail_initialization 后 dispose 不得重复释放模块。")


func _get_lifecycle_timeout_property(
	architecture: GFArchitecture,
	property_name: StringName
) -> float:
	match property_name:
		&"module_async_init_timeout_seconds":
			return architecture.module_async_init_timeout_seconds
		&"activation_timeout_seconds":
			return architecture.activation_timeout_seconds
		&"shutdown_timeout_seconds":
			return architecture.shutdown_timeout_seconds
		_:
			fail_test("未知的生命周期 timeout 属性：%s" % property_name)
			return -1.0


func _await_init(
	architecture: GFArchitecture,
	cancellation_token: GFCancellationToken,
	state: Dictionary
) -> void:
	state["result"] = await architecture.init(cancellation_token)
	state["done"] = true


func _await_hot_register(
	architecture: GFArchitecture,
	candidate: AwaitedHotRegisterUtility,
	state: Dictionary
) -> void:
	state["result"] = await architecture.register_utility_instance(candidate)
	state["done"] = true


func _await_hot_replace(
	architecture: GFArchitecture,
	replacement: AwaitedHotReplaceUtility,
	state: Dictionary
) -> void:
	state["result"] = await architecture.replace_utility(
		AwaitedHotReplaceUtility,
		replacement
	)
	state["done"] = true


func _await_hot_unregister(
	architecture: GFArchitecture,
	state: Dictionary
) -> void:
	state["result"] = await architecture.unregister_utility(
		AwaitedHotUnregisterUtility
	)
	state["done"] = true


func _await_shutdown(
	architecture: GFArchitecture,
	cancellation_token: GFCancellationToken,
	timeout_seconds: float,
	state: Dictionary
) -> void:
	state["result"] = await architecture.shutdown_async(
		cancellation_token,
		timeout_seconds
	)
	state["done"] = true


func _cancel_on_next_frame(
	source: GFCancellationSource,
	reason: StringName
) -> void:
	await get_tree().process_frame
	var _cancelled: bool = source.cancel(reason)


func _complete_quiesce_after_blocking_frame(
	utility: AwaitedHotUnregisterUtility,
	block_msec: int
) -> void:
	await get_tree().process_frame
	var release_at_msec: int = Time.get_ticks_msec() + block_msec
	while Time.get_ticks_msec() < release_at_msec:
		pass
	var _completed: bool = utility.complete_quiesce()


func _wait_until_states_done(states: Array[Dictionary]) -> void:
	for _frame: int in range(30):
		var all_done: bool = true
		for state: Dictionary in states:
			if not GFVariantData.get_option_bool(state, "done"):
				all_done = false
				break
		if all_done:
			return
		await get_tree().process_frame


func _shutdown_result_from_state(
	state: Dictionary
) -> GFArchitectureShutdownResult:
	var value: Variant = state.get("result")
	if value is GFArchitectureShutdownResult:
		return value
	return null


func _record_shutdown_finished(
	result: GFArchitectureShutdownResult,
	state: Dictionary
) -> void:
	state["count"] = GFVariantData.get_option_int(state, "count") + 1
	state["status"] = result.get_status()
