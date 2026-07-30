## 验证 GFNodeContext 的异步生命周期状态不变量。
extends GutTest


# --- 常量 ---

const _GF_ASYNC_CALL_SCRIPT = preload("res://addons/gf/kernel/core/gf_async_call.gd")
const CONTEXT_INSTALL_CANCEL_REASON: String = "[test] context install cancelled"
const CONTEXT_INSTALL_FAILURE_REASON: String = "[test] context install failed"
const PARENT_FAILURE_DURING_INSTALL_REASON: String = "[test] parent failed during child install"
const PARENT_FAILURE_WHILE_READY_REASON: String = "[test] parent failed while child ready"
const REENTRANT_CONTEXT_FAILURE_REASON: String = "[test] reentrant context failure"


# --- 辅助类 ---

class BlockingInitializationUtility extends GFUtility:
	signal release_initialization

	var async_started: bool = false
	var dispose_call_count: int = 0
	var tick_call_count: int = 0

	func _init() -> void:
		tick_enabled = true

	func async_init(_scope: GFAsyncScope) -> void:
		async_started = true
		await release_initialization

	func dispose() -> void:
		dispose_call_count += 1

	func tick(_delta: float) -> void:
		tick_call_count += 1


class SchedulingProbeArchitecture extends GFArchitecture:
	var reported_ready: bool = false
	var tick_dispatch_count: int = 0
	var physics_tick_dispatch_count: int = 0

	func is_inited() -> bool:
		return reported_ready

	func tick(_delta: float) -> void:
		tick_dispatch_count += 1

	func physics_tick(_delta: float) -> void:
		physics_tick_dispatch_count += 1


class BlockingInitializationContext extends GFNodeContext:
	var blocking_utility: BlockingInitializationUtility = null

	func _init() -> void:
		scope_mode = GFNodeContext.ScopeMode.SCOPED
		context_wait_timeout_seconds = 0.01

	func install(architecture_instance: GFArchitecture, _scope: GFAsyncScope) -> void:
		blocking_utility = BlockingInitializationUtility.new()
		var _registered: bool = await architecture_instance.register_utility_instance(blocking_utility)


class ReenteredInstallContext extends GFNodeContext:
	signal release_first_install
	signal release_second_install

	var install_started: bool = false
	var install_call_count: int = 0
	var install_completion_count: int = 0

	func _init() -> void:
		scope_mode = GFNodeContext.ScopeMode.SCOPED
		context_wait_timeout_seconds = 0.0

	func install(_architecture_instance: GFArchitecture, _scope: GFAsyncScope) -> void:
		install_started = true
		install_call_count += 1
		var install_index: int = install_call_count
		if install_index == 1:
			await release_first_install
		else:
			await release_second_install
		install_completion_count += 1


class ParentLifecycleBlockingContext extends GFNodeContext:
	signal release_install

	var install_started: bool = false
	var install_finished: bool = false
	var install_bindings_call_count: int = 0
	var observed_scope: GFAsyncScope = null

	func _init() -> void:
		scope_mode = GFNodeContext.ScopeMode.SCOPED
		context_wait_timeout_seconds = 0.0

	func install(_architecture_instance: GFArchitecture, scope: GFAsyncScope) -> void:
		install_started = true
		observed_scope = scope
		await release_install
		install_finished = true

	func install_bindings(_binder: Variant, _scope: GFAsyncScope) -> void:
		install_bindings_call_count += 1


class CancelledInstallContext extends GFNodeContext:
	var install_started: bool = false
	var install_finished: bool = false
	var install_bindings_call_count: int = 0

	func _init() -> void:
		scope_mode = GFNodeContext.ScopeMode.SCOPED
		context_wait_timeout_seconds = 0.01

	func install(_architecture_instance: GFArchitecture, scope: GFAsyncScope) -> void:
		install_started = true
		while not scope.is_cancel_requested():
			await get_tree().process_frame
		install_finished = true

	func install_bindings(_binder: Variant, _scope: GFAsyncScope) -> void:
		install_bindings_call_count += 1


class ReentrantDisposeUtility extends GFUtility:
	var context: GFNodeContext = null
	var dispose_call_count: int = 0

	func dispose() -> void:
		dispose_call_count += 1
		if context != null:
			context._fail_context(REENTRANT_CONTEXT_FAILURE_REASON)


class SelfCancellingInstallContext extends GFNodeContext:
	var install_bindings_call_count: int = 0
	var reentrant_utility: ReentrantDisposeUtility = null

	func _init() -> void:
		scope_mode = GFNodeContext.ScopeMode.SCOPED
		auto_init = false
		context_wait_timeout_seconds = 0.0

	func install(architecture_instance: GFArchitecture, scope: GFAsyncScope) -> void:
		reentrant_utility = ReentrantDisposeUtility.new()
		reentrant_utility.context = self
		var registered: bool = await architecture_instance.register_utility_instance(
			reentrant_utility
		)
		if not registered:
			return
		var _cancelled_scope: bool = scope.cancel(CONTEXT_INSTALL_CANCEL_REASON)

	func install_bindings(_binder: Variant, _scope: GFAsyncScope) -> void:
		install_bindings_call_count += 1


class FailingInstallContext extends GFNodeContext:
	var install_bindings_call_count: int = 0

	func _init() -> void:
		scope_mode = GFNodeContext.ScopeMode.SCOPED
		context_wait_timeout_seconds = 0.0

	func install(architecture_instance: GFArchitecture, _scope: GFAsyncScope) -> void:
		architecture_instance.fail_initialization(CONTEXT_INSTALL_FAILURE_REASON)

	func install_bindings(_binder: Variant, _scope: GFAsyncScope) -> void:
		install_bindings_call_count += 1


class InheritedNoTimeoutContext extends GFNodeContext:
	func _init() -> void:
		scope_mode = GFNodeContext.ScopeMode.INHERITED
		context_wait_timeout_seconds = 0.0


class ScopedNoTimeoutContext extends GFNodeContext:
	func _init() -> void:
		scope_mode = GFNodeContext.ScopeMode.SCOPED
		context_wait_timeout_seconds = 0.0


class ScopedManualNoTimeoutContext extends GFNodeContext:
	func _init() -> void:
		scope_mode = GFNodeContext.ScopeMode.SCOPED
		auto_init = false
		context_wait_timeout_seconds = 0.0


class TreeExitShutdownProbeUtility extends GFUtility:
	var quiesce_call_count: int = 0
	var dispose_call_count: int = 0

	func begin_quiesce(_scope: GFAsyncScope) -> GFAsyncCompletion:
		quiesce_call_count += 1
		var completion: GFAsyncCompletion = GFAsyncCompletion.new()
		var _completed: bool = completion.succeed()
		return completion

	func dispose() -> void:
		dispose_call_count += 1


class TreeExitShutdownProbeContext extends GFNodeContext:
	var shutdown_probe: TreeExitShutdownProbeUtility = null

	func _init() -> void:
		scope_mode = GFNodeContext.ScopeMode.SCOPED
		context_wait_timeout_seconds = 0.0

	func install(architecture_instance: GFArchitecture, _scope: GFAsyncScope) -> void:
		shutdown_probe = TreeExitShutdownProbeUtility.new()
		var _registered: bool = await architecture_instance.register_utility_instance(
			shutdown_probe
		)


# --- GUT 生命周期方法 ---

func before_each() -> void:
	_clear_global_architecture()


func after_each() -> void:
	_clear_global_architecture()


# --- 测试方法 ---

func test_context_ready_requires_architecture_stage_four_commit() -> void:
	var context: ScopedManualNoTimeoutContext = ScopedManualNoTimeoutContext.new()
	watch_signals(context)
	add_child(context)
	await get_tree().process_frame
	var original_architecture: GFArchitecture = context.get_architecture()
	if original_architecture != null:
		original_architecture.dispose()
	var probe_architecture: SchedulingProbeArchitecture = (
		SchedulingProbeArchitecture.new()
	)
	context._architecture = probe_architecture
	context._owns_architecture = true
	context._context_state = GFNodeContext._ContextState.INITIALIZING
	context._capture_parent_architecture(null)

	context._mark_context_ready(probe_architecture)

	assert_false(
		context.is_context_ready(),
		"尚未提交 stage4 的架构不得发布 context_ready。"
	)
	assert_signal_not_emitted(
		context,
		"context_ready",
		"stage4 前不得发出 context_ready。"
	)

	probe_architecture.reported_ready = true
	context._mark_context_ready(probe_architecture)

	assert_true(context.is_context_ready(), "stage4 完成后 Context 应进入 READY。")
	assert_signal_emitted(
		context,
		"context_ready",
		"stage4 完成后应发出 context_ready。"
	)

	context.queue_free()
	await get_tree().process_frame


func test_tree_exit_keeps_forced_synchronous_dispose_fallback() -> void:
	var context: TreeExitShutdownProbeContext = TreeExitShutdownProbeContext.new()
	add_child(context)
	var context_architecture: GFArchitecture = await context.wait_until_ready()
	var shutdown_probe: TreeExitShutdownProbeUtility = context.shutdown_probe

	assert_not_null(context_architecture, "测试 Context 应先完成四阶段初始化。")
	assert_not_null(shutdown_probe, "测试 Context 应安装 shutdown probe。")

	context.queue_free()
	await get_tree().process_frame

	assert_true(context_architecture.is_disposed(), "tree exit 必须同步强制释放 owned 架构。")
	assert_eq(
		shutdown_probe.quiesce_call_count,
		0,
		"SceneTree 退出路径不得启动不可等待的异步 quiesce。"
	)
	assert_eq(
		shutdown_probe.dispose_call_count,
		1,
		"tree exit 强制路径必须恰好 dispose 模块一次。"
	)


func test_node_context_dispatches_owned_ticks_only_while_context_is_ready() -> void:
	var context: ScopedNoTimeoutContext = ScopedNoTimeoutContext.new()
	var probe_architecture: SchedulingProbeArchitecture = SchedulingProbeArchitecture.new()
	context._architecture = probe_architecture
	context._owns_architecture = true
	context._context_state = GFNodeContext._ContextState.INITIALIZING

	context._process(0.25)
	context._physics_process(0.25)
	assert_eq(
		probe_architecture.tick_dispatch_count,
		0,
		"INITIALIZING 时 NodeContext 不得调用 Architecture.tick()。"
	)
	assert_eq(
		probe_architecture.physics_tick_dispatch_count,
		0,
		"INITIALIZING 时 NodeContext 不得调用 Architecture.physics_tick()。"
	)

	probe_architecture.reported_ready = true
	context._context_state = GFNodeContext._ContextState.READY
	context._process(0.25)
	context._physics_process(0.25)
	assert_eq(
		probe_architecture.tick_dispatch_count,
		1,
		"READY 时 NodeContext 必须直接调度 Architecture.tick()。"
	)
	assert_eq(
		probe_architecture.physics_tick_dispatch_count,
		1,
		"READY 时 NodeContext 必须直接调度 Architecture.physics_tick()。"
	)

	context._context_state = GFNodeContext._ContextState.FAILED
	context._process(0.25)
	context._physics_process(0.25)
	assert_eq(
		probe_architecture.tick_dispatch_count,
		1,
		"FAILED 后 NodeContext 必须停止 tick 调度。"
	)
	assert_eq(
		probe_architecture.physics_tick_dispatch_count,
		1,
		"FAILED 后 NodeContext 必须停止 physics tick 调度。"
	)

	context._architecture = null
	context._owns_architecture = false
	probe_architecture.dispose()
	context.free()


func test_failed_context_disposes_owned_architecture_and_cannot_later_become_ready_or_tick() -> void:
	var context: BlockingInitializationContext = BlockingInitializationContext.new()
	watch_signals(context)
	add_child(context)
	await get_tree().process_frame

	assert_true(context.blocking_utility.async_started, "测试夹具应阻塞在架构 async_init。")
	assert_false(
		context._should_tick_owned_architecture(),
		"INITIALIZING Context 的 NodeContext 调度门必须保持关闭。"
	)
	var architecture: GFArchitecture = await context.wait_until_ready()

	assert_null(architecture, "等待超时后应返回 null。")
	assert_true(context.is_context_failed(), "等待超时后上下文应进入 FAILED。")
	assert_push_warning("[GFNodeContext] 等待上下文初始化超时。")
	var failed_architecture: GFArchitecture = context.get_architecture()
	assert_true(failed_architecture.is_disposed(), "FAILED Scoped Context 必须释放 owned Architecture。")
	assert_eq(context.blocking_utility.dispose_call_count, 1, "失败清理必须恰好释放模块一次。")

	context.blocking_utility.release_initialization.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(context.is_context_failed(), "迟到的初始化成功不能离开 FAILED 终态。")
	assert_false(context.is_context_ready(), "FAILED 与 READY 必须互斥。")
	assert_true(failed_architecture.is_disposed(), "迟到初始化不能复活已释放的 Architecture。")
	assert_false(failed_architecture.is_inited(), "迟到初始化不能把已释放的 Architecture 提交为 READY。")
	assert_eq(context.blocking_utility.dispose_call_count, 1, "迟到 continuation 不得重复释放模块。")
	assert_false(
		context._should_tick_owned_architecture(),
		"FAILED Context 的 NodeContext 调度门必须保持关闭。"
	)
	assert_eq(context.blocking_utility.tick_call_count, 0, "FAILED Context 不得继续驱动 owned Architecture。")
	assert_signal_not_emitted(context, "context_ready", "失败后不能再发出 context_ready。")

	context.queue_free()
	await get_tree().process_frame


func test_reentered_context_ignores_previous_generation_install_completion() -> void:
	var context: ReenteredInstallContext = ReenteredInstallContext.new()
	add_child(context)
	assert_eq(context.install_call_count, 1, "首个 generation 应已进入 install 等待点。")
	remove_child(context)
	add_child(context)

	await get_tree().process_frame
	assert_true(context.install_started, "重新进入树后应启动当前 generation 的 install。")
	assert_eq(context.install_call_count, 2, "重新进入树后应有两个 install generation 等待完成。")

	var initialization_state: Dictionary = {
		"done": false,
		"architecture": null,
	}
	_GF_ASYNC_CALL_SCRIPT.run_detached(
		Callable(self, &"_capture_context_initialization"),
		[context, initialization_state]
	)
	await get_tree().process_frame
	await get_tree().process_frame

	context.release_first_install.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(
		context.install_completion_count,
		1,
		"必须先让旧 generation 的 install continuation 单独恢复。"
	)
	assert_false(
		GFVariantData.get_option_bool(initialization_state, "done"),
		"旧 generation 不能清除当前 generation 的安装状态并提前初始化。"
	)
	assert_false(context.is_context_ready(), "当前 install 完成前上下文不能 READY。")

	context.release_second_install.emit()
	for _frame_index: int in range(4):
		await get_tree().process_frame

	assert_eq(context.install_completion_count, 2, "当前 generation 的 install 也应完成。")
	assert_true(
		GFVariantData.get_option_bool(initialization_state, "done"),
		"当前 install 完成后 initialize_context 应结束。"
	)
	assert_true(context.is_context_ready(), "当前 generation 完整安装后应进入 READY。")

	context.queue_free()
	await get_tree().process_frame


func test_cancelled_install_does_not_continue_into_install_bindings() -> void:
	var context: CancelledInstallContext = CancelledInstallContext.new()
	add_child(context)
	await get_tree().process_frame

	assert_true(context.install_started, "测试夹具应进入 install。")
	var architecture: GFArchitecture = await context.wait_until_ready()

	assert_null(architecture, "安装超时后等待应返回 null。")
	assert_push_warning("[GFNodeContext] 等待上下文初始化超时。")
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(context.install_finished, "取消 scope 后 install 应在检查点结束。")
	assert_eq(
		context.install_bindings_call_count,
		0,
		"安装 scope 取消后不能继续执行 install_bindings。"
	)
	assert_true(context.is_context_failed(), "取消安装后上下文应保持 FAILED。")

	context.queue_free()
	await get_tree().process_frame


func test_install_scope_self_cancellation_enters_failed_terminal_state() -> void:
	var context: SelfCancellingInstallContext = SelfCancellingInstallContext.new()
	watch_signals(context)
	add_child(context)
	await get_tree().process_frame

	var initialization_state: Dictionary = {
		"done": false,
		"architecture": null,
	}
	_GF_ASYNC_CALL_SCRIPT.run_detached(
		Callable(self, &"_capture_context_initialization"),
		[context, initialization_state]
	)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(context.is_context_failed(), "install 主动取消 scope 后上下文必须进入 FAILED。")
	assert_false(context.is_context_ready(), "取消安装的上下文不得进入 READY。")
	assert_eq(context.get_context_failure_reason(), CONTEXT_INSTALL_CANCEL_REASON)
	assert_eq(context.install_bindings_call_count, 0, "取消 install 后不得继续 install_bindings。")
	assert_not_null(context.reentrant_utility, "测试夹具必须安装可重入释放的 Utility。")
	assert_eq(context.reentrant_utility.dispose_call_count, 1, "失败清理必须恰好释放模块一次。")
	assert_true(context.get_architecture().is_disposed(), "取消安装后必须释放 owned Architecture。")
	assert_true(
		GFVariantData.get_option_bool(initialization_state, "done"),
		"FAILED 终态下 initialize_context 应立即返回。"
	)
	assert_true(
		GFVariantData.get_option_value(initialization_state, "architecture") == null,
		"取消安装后 initialize_context 应返回 null。"
	)
	assert_signal_emitted(context, "context_failed", "install scope 取消应发出 context_failed。")
	assert_push_warning("[GFNodeContext] %s" % CONTEXT_INSTALL_CANCEL_REASON)

	context.queue_free()
	await get_tree().process_frame


func test_install_architecture_failure_stops_bindings_and_cannot_retry_to_ready() -> void:
	var context: FailingInstallContext = FailingInstallContext.new()
	watch_signals(context)
	add_child(context)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(context.is_context_failed(), "install 中架构失败后上下文必须进入 FAILED。")
	assert_false(context.is_context_ready(), "失败架构不得被上下文自动重试为 READY。")
	assert_eq(context.get_context_failure_reason(), CONTEXT_INSTALL_FAILURE_REASON)
	assert_eq(context.install_bindings_call_count, 0, "架构失败后不得继续 install_bindings。")
	assert_signal_emitted(context, "context_failed", "安装架构失败应发出 context_failed。")
	assert_push_error(CONTEXT_INSTALL_FAILURE_REASON)
	assert_push_warning("[GFNodeContext] %s" % CONTEXT_INSTALL_FAILURE_REASON)

	context.queue_free()
	await get_tree().process_frame


func test_context_preserves_first_failure_reason() -> void:
	var context: BlockingInitializationContext = BlockingInitializationContext.new()
	add_child(context)
	await get_tree().process_frame

	var architecture: GFArchitecture = await context.wait_until_ready()
	assert_null(architecture, "首次等待超时应返回 null。")
	assert_push_warning("[GFNodeContext] 等待上下文初始化超时。")
	assert_eq(
		context.get_context_failure_reason(),
		"等待上下文初始化超时。",
		"首次失败原因应被记录。"
	)

	context._fail_context("[test] later context failure")
	context.blocking_utility.release_initialization.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(
		context.get_context_failure_reason(),
		"等待上下文初始化超时。",
		"FAILED 终态不能被迟到失败改写原因。"
	)

	context.queue_free()
	await get_tree().process_frame


func test_concurrent_manual_initialization_joins_single_context_lifecycle_after_parent_ready() -> void:
	var parent_architecture: GFArchitecture = GFArchitecture.new()
	Gf._architecture = parent_architecture
	var context: ScopedManualNoTimeoutContext = ScopedManualNoTimeoutContext.new()
	add_child(context)
	var first_state: Dictionary = {
		"done": false,
		"architecture": null,
	}
	var second_state: Dictionary = {
		"done": false,
		"architecture": null,
	}
	_GF_ASYNC_CALL_SCRIPT.run_detached(
		Callable(self, &"_capture_context_initialization"),
		[context, first_state]
	)
	_GF_ASYNC_CALL_SCRIPT.run_detached(
		Callable(self, &"_capture_context_initialization"),
		[context, second_state]
	)

	var parent_initialized: bool = await parent_architecture.init()
	assert_true(parent_initialized, "测试父级架构必须完成初始化。")
	for _frame_index: int in range(5):
		await get_tree().process_frame

	assert_true(GFVariantData.get_option_bool(first_state, "done"))
	assert_true(GFVariantData.get_option_bool(second_state, "done"))
	var context_architecture: GFArchitecture = context.get_architecture()
	var first_architecture_value: Variant = GFVariantData.get_option_value(
		first_state,
		"architecture"
	)
	var second_architecture_value: Variant = GFVariantData.get_option_value(
		second_state,
		"architecture"
	)
	assert_true(first_architecture_value is GFArchitecture)
	assert_true(second_architecture_value is GFArchitecture)
	if first_architecture_value is GFArchitecture:
		var first_architecture: GFArchitecture = first_architecture_value
		assert_eq(first_architecture, context_architecture)
	if second_architecture_value is GFArchitecture:
		var second_architecture: GFArchitecture = second_architecture_value
		assert_eq(second_architecture, context_architecture)
	assert_true(context.is_context_ready(), "并发手动初始化必须汇合到同一 READY 终态。")
	assert_false(context.is_context_failed(), "合法 single-flight 不得被误判为 generation 漂移。")

	context.queue_free()
	await get_tree().process_frame


func test_scoped_context_cancels_install_when_ready_parent_fails() -> void:
	var parent_architecture: GFArchitecture = GFArchitecture.new()
	var parent_initialized: bool = await parent_architecture.init()
	assert_true(parent_initialized, "测试父级架构必须先进入 READY。")
	Gf._architecture = parent_architecture
	var context: ParentLifecycleBlockingContext = ParentLifecycleBlockingContext.new()
	watch_signals(context)
	add_child(context)

	assert_true(context.install_started, "测试夹具必须阻塞在 install await。")
	parent_architecture.fail_initialization(PARENT_FAILURE_DURING_INSTALL_REASON)
	assert_push_error(PARENT_FAILURE_DURING_INSTALL_REASON)
	await get_tree().process_frame
	await get_tree().process_frame

	var owned_architecture: GFArchitecture = context.get_architecture()
	assert_true(context.is_context_failed(), "父级失败后阻塞中的 Scoped Context 必须失败。")
	assert_eq(context.get_context_failure_reason(), PARENT_FAILURE_DURING_INSTALL_REASON)
	assert_not_null(context.observed_scope, "install 必须收到可取消作用域。")
	assert_true(
		context.observed_scope != null and context.observed_scope.is_cancel_requested(),
		"父级失败必须取消 install scope。"
	)
	assert_true(owned_architecture.is_disposed(), "父级失败必须释放 child owned Architecture。")
	assert_true(parent_architecture.has_initialization_failed(), "child 失败不得改写父级失败状态。")
	assert_false(parent_architecture.is_disposed(), "Scoped child 不得接管父级 Architecture 的释放。")
	assert_eq(context.install_bindings_call_count, 0, "父级失败后不得继续 install_bindings。")
	assert_signal_emitted(context, "context_failed", "父级失败必须发出 context_failed。")
	assert_push_warning("[GFNodeContext] %s" % PARENT_FAILURE_DURING_INSTALL_REASON)

	context.release_install.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(context.install_finished, "迟到 install continuation 应结束。")
	assert_eq(context.install_bindings_call_count, 0, "迟到 continuation 不得恢复安装流水线。")

	context.queue_free()
	await get_tree().process_frame


func test_scoped_context_cancels_install_when_ready_parent_is_disposed() -> void:
	var parent_architecture: GFArchitecture = GFArchitecture.new()
	var parent_initialized: bool = await parent_architecture.init()
	assert_true(parent_initialized, "测试父级架构必须先进入 READY。")
	Gf._architecture = parent_architecture
	var context: ParentLifecycleBlockingContext = ParentLifecycleBlockingContext.new()
	watch_signals(context)
	add_child(context)

	assert_true(context.install_started, "测试夹具必须阻塞在 install await。")
	parent_architecture.dispose()
	await get_tree().process_frame
	await get_tree().process_frame

	var owned_architecture: GFArchitecture = context.get_architecture()
	assert_true(context.is_context_failed(), "父级 dispose 后阻塞中的 Scoped Context 必须失败。")
	assert_eq(context.get_context_failure_reason(), "父级架构生命周期已结束。")
	assert_true(
		context.observed_scope != null and context.observed_scope.is_cancel_requested(),
		"父级 dispose 必须取消 install scope。"
	)
	assert_true(owned_architecture.is_disposed(), "父级 dispose 必须释放 child owned Architecture。")
	assert_eq(context.install_bindings_call_count, 0, "父级 dispose 后不得继续 install_bindings。")
	assert_signal_emitted(context, "context_failed", "父级 dispose 必须发出 context_failed。")
	assert_push_warning("[GFNodeContext] 父级架构生命周期已结束。")

	context.release_install.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(context.install_finished, "迟到 install continuation 应结束。")
	assert_eq(context.install_bindings_call_count, 0, "迟到 continuation 不得恢复安装流水线。")

	context.queue_free()
	await get_tree().process_frame


func test_scoped_context_rejects_parent_identity_replacement_during_install() -> void:
	var parent_architecture: GFArchitecture = GFArchitecture.new()
	var parent_initialized: bool = await parent_architecture.init()
	assert_true(parent_initialized, "测试父级架构必须先进入 READY。")
	Gf._architecture = parent_architecture
	var replacement_parent: GFArchitecture = GFArchitecture.new()
	var replacement_initialized: bool = await replacement_parent.init()
	assert_true(replacement_initialized, "replacement parent 必须先进入 READY。")
	var context: ParentLifecycleBlockingContext = ParentLifecycleBlockingContext.new()
	watch_signals(context)
	add_child(context)
	var owned_architecture: GFArchitecture = context.get_architecture()

	owned_architecture.set_parent_architecture(replacement_parent)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(context.is_context_failed(), "install 期间父级 identity 改变必须失败。")
	assert_eq(context.get_context_failure_reason(), "父级架构身份已变化。")
	assert_true(
		context.observed_scope != null and context.observed_scope.is_cancel_requested(),
		"父级 identity 改变必须取消 install scope。"
	)
	assert_true(owned_architecture.is_disposed(), "identity 漂移失败必须释放 owned Architecture。")
	assert_false(parent_architecture.is_disposed(), "原父级不得由 child 释放。")
	assert_false(replacement_parent.is_disposed(), "replacement parent 不得由 child 释放。")
	assert_signal_emitted(context, "context_failed", "identity 漂移必须发出 context_failed。")
	assert_push_warning("[GFNodeContext] 父级架构身份已变化。")

	context.release_install.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	context.queue_free()
	await get_tree().process_frame
	replacement_parent.dispose()


func test_scoped_context_rejects_parent_generation_retry_during_install() -> void:
	var parent_architecture: GFArchitecture = GFArchitecture.new()
	var parent_initialized: bool = await parent_architecture.init()
	assert_true(parent_initialized, "测试父级架构必须先进入 READY。")
	Gf._architecture = parent_architecture
	var context: ParentLifecycleBlockingContext = ParentLifecycleBlockingContext.new()
	watch_signals(context)
	add_child(context)
	var owned_architecture: GFArchitecture = context.get_architecture()

	parent_architecture.fail_initialization(PARENT_FAILURE_DURING_INSTALL_REASON)
	assert_push_error(PARENT_FAILURE_DURING_INSTALL_REASON)
	var parent_retried: bool = await parent_architecture.init()
	assert_true(parent_retried, "测试父级架构应完成失败后的新 generation。")
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(context.is_context_failed(), "父级失败并重试后也不能跨 generation 继续安装。")
	assert_eq(context.get_context_failure_reason(), "父级架构生命周期已失效。")
	assert_true(
		context.observed_scope != null and context.observed_scope.is_cancel_requested(),
		"父级 generation 漂移必须取消 install scope。"
	)
	assert_true(owned_architecture.is_disposed(), "generation 漂移失败必须释放 owned Architecture。")
	assert_true(parent_architecture.is_inited(), "child 不得 dispose 已重试成功的父级。")
	assert_signal_emitted(context, "context_failed", "generation 漂移必须发出 context_failed。")
	assert_push_warning("[GFNodeContext] 父级架构生命周期已失效。")

	context.release_install.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	context.queue_free()
	await get_tree().process_frame


func test_ready_scoped_context_fails_when_parent_architecture_fails() -> void:
	var parent_architecture: GFArchitecture = GFArchitecture.new()
	var parent_initialized: bool = await parent_architecture.init()
	assert_true(parent_initialized, "测试父级架构必须先进入 READY。")
	Gf._architecture = parent_architecture
	var context: ScopedNoTimeoutContext = ScopedNoTimeoutContext.new()
	watch_signals(context)
	add_child(context)
	await get_tree().process_frame
	await get_tree().process_frame
	var owned_architecture: GFArchitecture = context.get_architecture()

	assert_true(context.is_context_ready(), "测试 child Context 必须先进入 READY。")
	parent_architecture.fail_initialization(PARENT_FAILURE_WHILE_READY_REASON)
	assert_push_error(PARENT_FAILURE_WHILE_READY_REASON)

	assert_false(context.is_context_ready(), "父级失败后 Scoped Context 不得继续报告 READY。")
	assert_true(context.is_context_failed(), "父级失败后 Scoped Context 必须进入 FAILED。")
	assert_eq(context.get_context_failure_reason(), PARENT_FAILURE_WHILE_READY_REASON)
	assert_true(owned_architecture.is_disposed(), "READY child 失败必须释放 owned Architecture。")
	assert_true(parent_architecture.has_initialization_failed(), "child 不得清除父级失败状态。")
	assert_false(parent_architecture.is_disposed(), "Scoped child 不得 dispose 父级 Architecture。")
	assert_signal_emitted(context, "context_failed", "READY child 必须发出 context_failed。")
	assert_push_warning("[GFNodeContext] %s" % PARENT_FAILURE_WHILE_READY_REASON)

	context.queue_free()
	await get_tree().process_frame


func test_ready_inherited_context_rejects_parent_identity_change_without_disposing_shared_architecture() -> void:
	var inherited_architecture: GFArchitecture = GFArchitecture.new()
	var inherited_initialized: bool = await inherited_architecture.init()
	assert_true(inherited_initialized, "测试继承架构必须先进入 READY。")
	Gf._architecture = inherited_architecture
	var context: InheritedNoTimeoutContext = InheritedNoTimeoutContext.new()
	watch_signals(context)
	add_child(context)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(context.is_context_ready(), "Inherited Context 必须先进入 READY。")
	var replacement_architecture: GFArchitecture = GFArchitecture.new()
	var replacement_initialized: bool = await replacement_architecture.init()
	assert_true(replacement_initialized, "replacement Architecture 必须先进入 READY。")

	Gf._architecture = replacement_architecture

	assert_false(context.is_context_ready(), "继承来源 identity 改变后不得继续报告 READY。")
	assert_true(context.is_context_failed(), "继承来源 identity 改变后必须进入 FAILED。")
	assert_eq(context.get_context_failure_reason(), "继承架构身份已变化。")
	assert_false(inherited_architecture.is_disposed(), "Inherited Context 不得 dispose 原共享架构。")
	assert_false(replacement_architecture.is_disposed(), "Inherited Context 不得 dispose replacement。")
	assert_signal_emitted(context, "context_failed", "identity 改变必须发出 context_failed。")
	assert_push_warning("[GFNodeContext] 继承架构身份已变化。")

	context.queue_free()
	await get_tree().process_frame
	inherited_architecture.dispose()


func test_inherited_context_fails_immediately_when_waited_architecture_is_disposed() -> void:
	var inherited_architecture: GFArchitecture = GFArchitecture.new()
	Gf._architecture = inherited_architecture
	var context: InheritedNoTimeoutContext = InheritedNoTimeoutContext.new()
	watch_signals(context)
	add_child(context)

	inherited_architecture.dispose()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(
		context.is_context_failed(),
		"禁用 timeout 时，已 dispose 的继承架构也必须让等待进入失败终态。"
	)
	assert_eq(
		context.get_context_failure_reason(),
		"继承架构生命周期已结束。"
	)
	assert_signal_emitted(
		context,
		"context_failed",
		"继承架构 dispose 后必须发出 context_failed。"
	)
	assert_push_warning("[GFNodeContext] 继承架构生命周期已结束。")

	context.queue_free()
	await get_tree().process_frame


func test_scoped_context_fails_immediately_when_parent_architecture_is_disposed() -> void:
	var parent_architecture: GFArchitecture = GFArchitecture.new()
	Gf._architecture = parent_architecture
	var context: ScopedNoTimeoutContext = ScopedNoTimeoutContext.new()
	watch_signals(context)
	add_child(context)

	parent_architecture.dispose()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(
		context.is_context_failed(),
		"禁用 timeout 时，已 dispose 的父架构也必须让 Scoped Context 失败。"
	)
	assert_eq(
		context.get_context_failure_reason(),
		"父级架构生命周期已结束。"
	)
	assert_signal_emitted(
		context,
		"context_failed",
		"父架构 dispose 后必须发出 context_failed。"
	)
	assert_push_warning("[GFNodeContext] 父级架构生命周期已结束。")

	context.queue_free()
	await get_tree().process_frame


func test_scoped_context_fails_when_owned_architecture_is_disposed_while_parent_pending() -> void:
	var parent_architecture: GFArchitecture = GFArchitecture.new()
	Gf._architecture = parent_architecture
	var context: ScopedNoTimeoutContext = ScopedNoTimeoutContext.new()
	watch_signals(context)
	add_child(context)
	var scoped_architecture: GFArchitecture = context.get_architecture()

	scoped_architecture.dispose()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(
		context.is_context_failed(),
		"等待未就绪父级时，owned Architecture dispose 必须让 Scoped Context 失败。"
	)
	assert_eq(
		context.get_context_failure_reason(),
		"上下文架构生命周期已结束。"
	)
	assert_true(scoped_architecture.is_disposed(), "失败清理后 owned Architecture 必须保持 DISPOSED。")
	assert_signal_emitted(
		context,
		"context_failed",
		"owned Architecture dispose 后必须发出 context_failed。"
	)
	assert_push_warning("[GFNodeContext] 上下文架构生命周期已结束。")

	context.queue_free()
	await get_tree().process_frame


func test_scoped_context_fails_when_owned_architecture_generation_drifts_while_parent_pending() -> void:
	var parent_architecture: GFArchitecture = GFArchitecture.new()
	Gf._architecture = parent_architecture
	var context: ScopedNoTimeoutContext = ScopedNoTimeoutContext.new()
	watch_signals(context)
	add_child(context)
	var scoped_architecture: GFArchitecture = context.get_architecture()

	var initialized: bool = await scoped_architecture.init()
	assert_true(initialized, "测试夹具应主动推进 owned Architecture generation。")
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(
		context.is_context_failed(),
		"等待未就绪父级时，owned Architecture generation 漂移必须让 Scoped Context 失败。"
	)
	assert_eq(
		context.get_context_failure_reason(),
		"上下文架构在等待父级期间生命周期已失效。"
	)
	assert_true(scoped_architecture.is_disposed(), "generation 漂移失败必须释放 owned Architecture。")
	assert_signal_emitted(
		context,
		"context_failed",
		"owned Architecture generation 漂移后必须发出 context_failed。"
	)
	assert_push_warning("[GFNodeContext] 上下文架构在等待父级期间生命周期已失效。")

	context.queue_free()
	await get_tree().process_frame


func test_ready_scoped_context_fails_when_owned_architecture_is_disposed() -> void:
	var context: ScopedNoTimeoutContext = ScopedNoTimeoutContext.new()
	watch_signals(context)
	add_child(context)
	await get_tree().process_frame
	await get_tree().process_frame
	var scoped_architecture: GFArchitecture = context.get_architecture()

	assert_true(context.is_context_ready(), "测试夹具必须先进入 READY。")
	assert_true(
		context._should_tick_owned_architecture(),
		"READY Context 的 NodeContext 调度门必须打开。"
	)
	scoped_architecture.dispose()

	assert_false(
		context.is_context_ready(),
		"READY Context 的 owned Architecture dispose 后不得继续谎报 READY。"
	)
	assert_true(
		context.is_context_failed(),
		"READY Context 的 owned Architecture dispose 后必须转入 FAILED。"
	)
	assert_eq(
		context.get_context_failure_reason(),
		"上下文架构生命周期已结束。"
	)
	assert_false(
		context._should_tick_owned_architecture(),
		"owned Architecture dispose 后 NodeContext 调度门必须关闭。"
	)
	assert_signal_emitted(
		context,
		"context_failed",
		"READY owned Architecture dispose 后必须发出 context_failed。"
	)
	assert_push_warning("[GFNodeContext] 上下文架构生命周期已结束。")

	context.queue_free()
	await get_tree().process_frame


func test_context_ready_dispose_reentry_fails_closed_before_initialize_returns() -> void:
	var context: ScopedManualNoTimeoutContext = ScopedManualNoTimeoutContext.new()
	watch_signals(context)
	var connect_error: Error = context.context_ready.connect(
		func(architecture_instance: GFArchitecture) -> void:
			architecture_instance.dispose()
	) as Error
	assert_eq(connect_error, OK, "测试应能监听 context_ready。")
	add_child(context)

	var initialized_architecture: GFArchitecture = await context.initialize_context()

	assert_null(
		initialized_architecture,
		"context_ready listener 同步 dispose 后，initialize_context 不得返回失效架构。"
	)
	assert_true(context.is_context_failed(), "信号回调失效生命周期后 Context 必须 fail closed。")
	assert_false(context.is_context_ready(), "被信号回调释放的 Context 不得继续报告 READY。")
	assert_true(context.get_architecture().is_disposed(), "listener 释放应成为 owned Architecture 终态。")
	assert_signal_emitted(context, "context_ready", "Context 应先发布本次 ready 边界。")
	assert_signal_emitted(context, "context_failed", "ready listener 失效生命周期后应同步发布失败。")
	assert_push_warning("[GFNodeContext] 上下文架构生命周期已结束。")

	context.queue_free()
	await get_tree().process_frame


# --- 辅助方法 ---

func _capture_context_initialization(context: GFNodeContext, state: Dictionary) -> void:
	var architecture: GFArchitecture = await context.initialize_context()
	state["architecture"] = architecture
	state["done"] = true


func _clear_global_architecture() -> void:
	if Gf.has_architecture():
		var architecture: GFArchitecture = Gf.get_architecture()
		architecture.dispose()
	Gf._architecture = null
