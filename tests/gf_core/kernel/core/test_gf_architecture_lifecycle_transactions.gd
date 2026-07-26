# GFArchitecture 生命周期事务与诊断不变量回归测试。
extends GutTest


# --- 常量 ---

const REPLACEMENT_EVENT_ID: StringName = &"gf.test.replacement.rollback"
const REPLACEMENT_SERVICE_KEY: StringName = &"gf.test.replacement.service"


# --- 测试用例 ---

func test_init_fails_when_a_registered_module_does_not_reach_ready_stage() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var cancelling_utility: CancellingAsyncUtility = CancellingAsyncUtility.new()

	assert_true(
		await architecture.register_utility_instance(cancelling_utility),
		"取消 async scope 的 Utility 应先成功进入注册表。"
	)

	var initialized: bool = await architecture.init()

	assert_false(initialized, "任一已注册模块未完成 ready 时，架构初始化必须失败。")
	assert_true(architecture.has_initialization_failed(), "生命周期后置条件失败应进入明确的 failed 状态。")
	assert_false(architecture.is_inited(), "存在未完成模块时不得提交架构 ready 状态。")
	assert_false(architecture.is_module_ready(cancelling_utility), "取消 async scope 的模块不得被报告为 ready。")
	assert_push_error_count(1, "生命周期推进停滞应输出一条框架级错误。")
	architecture.dispose()


func test_registration_does_not_commit_after_injection_disposes_architecture() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var disposing_utility: DisposeDuringInjectionUtility = DisposeDuringInjectionUtility.new()

	var registered: bool = await architecture.register_utility_instance(disposing_utility)
	var lifecycle_state: Dictionary = architecture.get_debug_lifecycle_state()
	var registered_utilities: Dictionary = GFVariantData.get_option_dictionary(lifecycle_state, "utilities")

	assert_false(registered, "注入回调 dispose 架构后，外层注册不得继续提交。")
	assert_true(registered_utilities.is_empty(), "已 dispose 的架构不得被重入注册重新写入模块。")
	assert_true(disposing_utility.dependencies_released, "未提交模块的注入作用域必须被释放。")
	assert_push_error_count(1, "被重入失效的注册事务应报告一次明确错误。")


func test_preinitialization_replacement_does_not_commit_after_injection_disposes_architecture() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var previous_utility: PreInitializationReplacementUtility = PreInitializationReplacementUtility.new(false)
	var replacement_utility: PreInitializationReplacementUtility = PreInitializationReplacementUtility.new(true)
	assert_true(
		await architecture.register_utility_instance(previous_utility),
		"旧 Utility 应先进入未初始化架构的注册表。"
	)

	var replaced: bool = await architecture.replace_utility(
		PreInitializationReplacementUtility,
		replacement_utility
	)

	assert_false(replaced, "replacement 注入期间 dispose 架构后，外层替换不得提交。")
	assert_null(
		architecture.get_local_utility(PreInitializationReplacementUtility),
		"已 dispose 的架构不得被 replacement 迟到写回。"
	)
	assert_eq(previous_utility.dispose_count, 1, "旧实例应随架构 dispose 且只释放一次。")
	assert_eq(replacement_utility.dispose_count, 1, "未提交 replacement 必须释放且只释放一次。")
	assert_true(replacement_utility.dependencies_released, "未提交 replacement 必须释放注入作用域。")


func test_hot_registration_rolls_back_when_async_init_cancels() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	assert_true(await architecture.init(), "测试架构应先进入 READY。")
	var cancelling_utility: CancellingAsyncUtility = CancellingAsyncUtility.new()

	var registered: bool = await architecture.register_utility_instance(cancelling_utility)

	assert_false(registered, "热注册模块取消 async scope 后应返回 false。")
	assert_null(
		architecture.get_local_utility(CancellingAsyncUtility),
		"返回 false 的热注册不得把未 ready 模块留在注册表。"
	)
	assert_true(cancelling_utility.disposed, "回滚热注册时应释放未提交模块。")
	assert_true(architecture.is_inited(), "局部热注册取消不应破坏既有 READY 架构。")
	architecture.dispose()


func test_failed_replacement_rolls_back_owned_events_and_services() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var old_utility: ReplacementSideEffectUtility = ReplacementSideEffectUtility.new(false)
	var replacement_utility: ReplacementSideEffectUtility = ReplacementSideEffectUtility.new(true)
	assert_true(
		await architecture.register_utility_instance(old_utility),
		"旧 Utility 应成功注册。"
	)
	assert_true(await architecture.init(), "旧 Utility 应成功完成初始化。")

	var replaced: bool = await architecture.replace_utility(
		ReplacementSideEffectUtility,
		replacement_utility
	)

	assert_false(replaced, "主动取消 async scope 的 replacement 不得提交。")
	assert_true(replacement_utility.service_registered, "测试 replacement 必须先产生 service 副作用。")
	assert_same(
		architecture.get_utility(ReplacementSideEffectUtility),
		old_utility,
		"replacement 失败后旧实例必须保持注册。"
	)
	assert_null(
		architecture.get_service(REPLACEMENT_SERVICE_KEY),
		"replacement 失败后不得残留其 service provider。"
	)
	architecture.send_simple_event(REPLACEMENT_EVENT_ID)
	assert_eq(replacement_utility.event_count, 0, "replacement 失败后不得残留 owned event listener。")
	architecture.dispose()


func test_hot_replacement_ready_reentry_cannot_commit_removed_candidate() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var previous_utility: ReadyReentrantReplacementUtility = ReadyReentrantReplacementUtility.new(false)
	var replacement_utility: ReadyReentrantReplacementUtility = ReadyReentrantReplacementUtility.new(true)
	assert_true(
		await architecture.register_utility_instance(previous_utility),
		"旧 Utility 应成功注册。"
	)
	assert_true(await architecture.init(), "旧 Utility 应成功完成初始化。")

	var replaced: bool = await architecture.replace_utility(
		ReadyReentrantReplacementUtility,
		replacement_utility
	)

	assert_false(replaced, "replacement ready 回调移除 candidate 后，外层替换不得报告成功。")
	assert_null(
		architecture.get_local_utility(ReadyReentrantReplacementUtility),
		"ready 中较新的 unregister 应拥有最终注册表状态。"
	)
	assert_false(
		architecture.is_module_ready(replacement_utility),
		"已被重入移除并释放的 candidate 不得残留 ready stage。"
	)
	assert_eq(replacement_utility.dispose_count, 1, "重入移除的 candidate 应只释放一次。")
	assert_eq(previous_utility.dispose_count, 1, "被 supersede 的旧实例应只释放一次。")
	architecture.dispose()


func test_initialization_failure_resets_applied_project_installers() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	assert_true(architecture.begin_project_installers(), "测试应先进入 Installer 应用阶段。")
	architecture.mark_project_installers_applied()
	assert_true(architecture.has_project_installers_applied(), "测试前置条件要求 Installer 已应用。")
	assert_true(
		await architecture.register_utility_instance(InstallerFailureUtility.new()),
		"触发失败的 Utility 应先成功注册。"
	)

	var initialized: bool = await architecture.init()

	assert_false(initialized, "Utility 主动触发失败后架构初始化应返回 false。")
	assert_false(
		architecture.has_project_installers_applied(),
		"初始化失败清空模块时必须同步清除 Installer applied 状态。"
	)
	assert_true(
		architecture.begin_project_installers(),
		"清理失败状态后应允许重新开始完整 Installer 应用。"
	)
	assert_push_error("[test] installer module failure")
	architecture.dispose()


func test_module_ready_is_observable_during_later_ready_callbacks() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var first_utility: FirstReadyUtility = FirstReadyUtility.new()
	var observer_utility: ReadyObserverUtility = ReadyObserverUtility.new(first_utility)
	assert_true(
		await architecture.register_utility_instance(first_utility),
		"先执行 ready 的 Utility 应成功注册。"
	)
	assert_true(
		await architecture.register_utility_instance(observer_utility),
		"观察 ready 状态的 Utility 应成功注册。"
	)

	assert_true(await architecture.init(), "两个 Utility 都应完成架构初始化。")

	assert_true(
		observer_utility.target_reported_ready,
		"模块完成 ready 后，应立即对后续 ready 回调报告为 module-ready。"
	)
	assert_same(
		observer_utility.resolved_ready_target,
		first_utility,
		"ready 回调中的 require_ready 查询应能解析已完成 ready 的前序模块。"
	)
	architecture.dispose()


func test_binding_diagnostic_projection_does_not_change_health_result() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	architecture.register_utility_alias(DiagnosticAliasBaseUtility, DiagnosticAliasTargetUtility)
	assert_push_warning_count(1, "未注册 alias target 应产生测试所需的诊断问题。")

	var full_report: Dictionary = architecture.get_binding_diagnostics({ "include_entries": true })
	var compact_report: Dictionary = architecture.get_binding_diagnostics({ "include_entries": false })
	var full_issues: Array = GFVariantData.get_option_array(full_report, "issues")
	var compact_issues: Array = GFVariantData.get_option_array(compact_report, "issues")
	var compact_registries: Dictionary = GFVariantData.get_option_dictionary(compact_report, "registries")
	var compact_utilities: Dictionary = GFVariantData.get_option_dictionary(compact_registries, "utilities")

	assert_false(GFVariantData.get_option_bool(full_report, "ok", true), "完整报告应识别无效 alias。")
	assert_false(
		GFVariantData.get_option_bool(compact_report, "ok", true),
		"隐藏明细只能改变投影，不得把同一状态改判为健康。"
	)
	assert_eq(
		GFVariantData.get_option_int(compact_report, "issue_count"),
		GFVariantData.get_option_int(full_report, "issue_count"),
		"完整与紧凑报告必须保留相同 issue_count。"
	)
	assert_eq(compact_issues, full_issues, "隐藏明细不得改变诊断问题集合。")
	assert_false(compact_utilities.has("entries"), "紧凑报告不应包含模块明细。")
	assert_false(compact_utilities.has("aliases"), "紧凑报告不应包含 alias 明细。")
	architecture.dispose()


func test_dispose_callback_cannot_reenter_initialization() -> void:
	var architecture: DisposeReentrantInitArchitecture = (
		DisposeReentrantInitArchitecture.new()
	)

	architecture.dispose()

	assert_false(
		architecture.reentrant_init_result,
		"DISPOSING 期间的同步 init() 重入必须 fail closed。"
	)
	assert_true(architecture.is_disposed(), "外层 dispose 应保持 DISPOSED 终态。")
	assert_false(architecture.is_inited(), "释放回调不得把架构短暂复活为 READY。")
	assert_push_error_count(1, "被拒绝的 dispose→init 重入应输出一次明确错误。")


func test_initialization_finished_reentry_cannot_return_stale_success() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var dispose_callback: Callable = func() -> void:
		architecture.dispose()
	var _signal_connect_error: Error = architecture.initialization_finished.connect(
		dispose_callback,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error

	var initialized: bool = await architecture.init()

	assert_false(
		initialized,
		"initialization_finished listener 改写生命周期后，init() 不得返回陈旧成功。"
	)
	assert_true(architecture.is_disposed(), "listener 触发的 dispose 应成为最终状态。")
	assert_false(architecture.is_inited(), "被 listener 释放的架构不得继续报告 READY。")


func test_fail_initialization_cannot_resurrect_disposed_architecture() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	assert_true(await architecture.init(), "测试架构应先进入 READY。")
	architecture.dispose()
	var disposed_generation: int = architecture.get_lifecycle_generation()

	architecture.fail_initialization("[test] late failure after dispose")

	assert_true(architecture.is_disposed(), "DISPOSED 必须保持不可恢复终态。")
	assert_false(
		architecture.has_initialization_failed(),
		"dispose 后的迟到 fail_initialization 不得把终态改写为 FAILED。"
	)
	assert_eq(
		architecture.get_lifecycle_generation(),
		disposed_generation,
		"被拒绝的迟到失败不得推进 lifecycle generation。"
	)


func test_dispose_cleanup_reentry_does_not_retain_terminal_async_scope() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var active_scope: GFAsyncScope = GFAsyncScope.new()
	var reentry_state: Dictionary = { "late_scope_weak": null }
	var cleanup_registered: bool = active_scope.register_cleanup(
		func() -> void:
			var late_scope: GFAsyncScope = GFAsyncScope.new()
			reentry_state["late_scope_weak"] = weakref(late_scope)
			architecture.track_framework_async_scope(late_scope)
			late_scope = null
	)
	assert_true(cleanup_registered, "测试 cleanup 应成功注册。")
	architecture.track_framework_async_scope(active_scope)

	architecture.dispose()

	assert_true(active_scope.is_cancel_requested(), "dispose 必须取消已登记作用域。")
	var late_scope_weak_value: Variant = GFVariantData.get_option_value(
		reentry_state,
		"late_scope_weak"
	)
	assert_true(late_scope_weak_value is WeakRef, "dispose cleanup 必须执行重入登记。")
	if late_scope_weak_value is WeakRef:
		var late_scope_weak: WeakRef = late_scope_weak_value
		var retained_scope_value: Variant = late_scope_weak.get_ref()
		assert_true(
			retained_scope_value == null,
			"终态 Architecture 应立即取消且不保留 cleanup 重入登记的作用域。"
		)


# --- 内部类 ---

class CancellingAsyncUtility extends GFUtility:
	var disposed: bool = false

	func async_init(scope: GFAsyncScope) -> void:
		var _cancelled_scope: bool = scope.cancel("[test] cancel async lifecycle")

	func dispose() -> void:
		disposed = true


class DisposeDuringInjectionUtility extends GFUtility:
	var dependencies_released: bool = false

	func inject_dependencies(architecture: GFArchitecture) -> void:
		super.inject_dependencies(architecture)
		architecture.dispose()

	func release_dependencies() -> void:
		dependencies_released = true
		super.release_dependencies()


class PreInitializationReplacementUtility extends GFUtility:
	var dispose_during_injection: bool = false
	var dispose_count: int = 0
	var dependencies_released: bool = false

	func _init(should_dispose_during_injection: bool) -> void:
		dispose_during_injection = should_dispose_during_injection

	func inject_dependencies(architecture: GFArchitecture) -> void:
		super.inject_dependencies(architecture)
		if dispose_during_injection:
			architecture.dispose()

	func dispose() -> void:
		dispose_count += 1

	func release_dependencies() -> void:
		dependencies_released = true
		super.release_dependencies()


class ReplacementSideEffectUtility extends GFUtility:
	var fail_async_init: bool = false
	var injected_architecture: GFArchitecture = null
	var service_registered: bool = false
	var event_count: int = 0

	func _init(should_fail_async_init: bool) -> void:
		fail_async_init = should_fail_async_init

	func inject_dependencies(architecture: GFArchitecture) -> void:
		super.inject_dependencies(architecture)
		injected_architecture = architecture

	func init() -> void:
		if not fail_async_init or injected_architecture == null:
			return
		injected_architecture.register_simple_event_owned(
			self,
			REPLACEMENT_EVENT_ID,
			GFEventListener.from_method(self, &"_on_replacement_event", 1)
		)
		service_registered = injected_architecture.register_service(REPLACEMENT_SERVICE_KEY, self)

	func async_init(scope: GFAsyncScope) -> void:
		if fail_async_init:
			var _cancelled_scope: bool = scope.cancel("[test] reject replacement")

	func _on_replacement_event(_payload: Variant) -> void:
		event_count += 1


class ReadyReentrantReplacementUtility extends GFUtility:
	var unregister_during_ready: bool = false
	var injected_architecture: GFArchitecture = null
	var dispose_count: int = 0

	func _init(should_unregister_during_ready: bool) -> void:
		unregister_during_ready = should_unregister_during_ready

	func inject_dependencies(architecture: GFArchitecture) -> void:
		super.inject_dependencies(architecture)
		injected_architecture = architecture

	func ready() -> void:
		if unregister_during_ready and injected_architecture != null:
			injected_architecture.unregister_utility(ReadyReentrantReplacementUtility)

	func dispose() -> void:
		dispose_count += 1


class InstallerFailureUtility extends GFUtility:
	func init() -> void:
		var architecture: GFArchitecture = _get_architecture()
		architecture.fail_initialization("[test] installer module failure")


class FirstReadyUtility extends GFUtility:
	func _init() -> void:
		lifecycle_priority = 10


class ReadyObserverUtility extends GFUtility:
	var target: FirstReadyUtility = null
	var target_reported_ready: bool = false
	var resolved_ready_target: Object = null

	func _init(target_utility: FirstReadyUtility) -> void:
		target = target_utility
		lifecycle_priority = -10

	func ready() -> void:
		var architecture: GFArchitecture = _get_architecture()
		target_reported_ready = architecture.is_module_ready(target)
		resolved_ready_target = architecture.get_utility(FirstReadyUtility, true)


class DiagnosticAliasBaseUtility extends GFUtility:
	pass


class DiagnosticAliasTargetUtility extends DiagnosticAliasBaseUtility:
	pass


class DisposeReentrantInitArchitecture extends GFArchitecture:
	var reentrant_init_result: bool = true

	func _on_dispose() -> void:
		var raw_init_result: Variant = call(&"init")
		reentrant_init_result = GFVariantData.to_bool(raw_init_result)
