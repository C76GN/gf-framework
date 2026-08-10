# GFArchitecture 生命周期事务与诊断不变量回归测试。
extends GutTest


# --- 常量 ---

const REPLACEMENT_EVENT_ID: StringName = &"gf.test.replacement.rollback"
const REPLACEMENT_SERVICE_KEY: StringName = &"gf.test.replacement.service"
const STAGED_SERVICE_KEY: StringName = &"gf.test.topology.staged_service"


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
	assert_eq(disposing_utility.init_count, 0, "依赖注入使事务失效后不得继续 init Hook。")
	assert_eq(disposing_utility.async_init_count, 0, "依赖注入使事务失效后不得继续 async_init Hook。")
	assert_eq(disposing_utility.ready_count, 0, "依赖注入使事务失效后不得继续 ready Hook。")
	assert_eq(disposing_utility.activation_count, 0, "依赖注入使事务失效后不得继续 activation Hook。")
	assert_eq(disposing_utility.dispose_count, 1, "未提交候选必须且只应释放一次。")
	assert_eq(
		GFVariantData.get_option_int(
			architecture.get_dependency_diagnostics(),
			"module_count"
		),
		0,
		"dispose 重入后不得复活 lifecycle plan。"
	)


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


func test_hot_registration_is_invisible_until_activation_commits() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	assert_true(await architecture.init(), "测试架构应先进入 READY。")
	var candidate: PendingHotRegistrationUtility = (
		PendingHotRegistrationUtility.new()
	)
	var register_state: Dictionary = {
		"done": false,
		"result": false,
	}

	@warning_ignore("missing_await")
	_await_pending_hot_register(architecture, candidate, register_state)
	await get_tree().process_frame

	assert_eq(candidate.activation_count, 1, "测试候选应停在 activation pending。")
	assert_false(
		architecture.is_accepting_runtime_work(),
		"热注册事务未稳定时必须关闭普通运行时工作准入。"
	)
	assert_false(
		GFVariantData.get_option_bool(register_state, "done"),
		"activation pending 时外层热注册不得提前完成。"
	)
	assert_null(
		architecture.get_local_utility(PendingHotRegistrationUtility),
		"staged 候选在 activation 完成前不得进入本地注册表。"
	)
	assert_null(
		architecture.get_utility(PendingHotRegistrationUtility),
		"普通依赖查询也不得观察到尚未提交的 staged 候选。"
	)
	var lifecycle_tick_count: int = candidate.tick_count
	architecture.tick(0.1)
	assert_eq(
		candidate.tick_count,
		lifecycle_tick_count,
		"pending 候选只能由 lifecycle tick 推进，普通 tick 不得重复驱动。"
	)

	assert_true(candidate.complete_activation())
	await _wait_for_transaction_state(register_state)

	assert_true(GFVariantData.get_option_bool(register_state, "done"))
	assert_true(GFVariantData.get_option_bool(register_state, "result"))
	assert_true(
		architecture.is_accepting_runtime_work(),
		"热注册提交后应恢复普通运行时工作准入。"
	)
	assert_same(
		architecture.get_local_utility(PendingHotRegistrationUtility),
		candidate,
		"activation 成功后本地查询应原子切换到已提交候选。"
	)
	assert_same(
		architecture.get_utility(PendingHotRegistrationUtility),
		candidate,
		"activation 成功后普通查询应与本地注册表看到同一实例。"
	)
	architecture.dispose()
	assert_eq(candidate.dispose_count, 1)


func test_pending_hot_replace_closes_acceptance_and_regular_tick_does_not_double_drive() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var previous: PendingHotRegistrationUtility = (
		PendingHotRegistrationUtility.new(false, true)
	)
	assert_true(await architecture.register_utility_instance(previous))
	assert_true(await architecture.init())
	var replacement: PendingHotRegistrationUtility = (
		PendingHotRegistrationUtility.new(true)
	)
	var replace_state: Dictionary = {
		"done": false,
		"result": false,
	}

	@warning_ignore("missing_await")
	_await_pending_hot_replace(architecture, replacement, replace_state)
	await get_tree().process_frame

	assert_false(
		architecture.is_accepting_runtime_work(),
		"热替换事务未稳定时必须关闭普通运行时工作准入。"
	)
	assert_false(GFVariantData.get_option_bool(replace_state, "done"))
	assert_same(
		architecture.get_local_utility(PendingHotRegistrationUtility),
		previous,
		"替换提交前注册表必须继续公开旧实例。"
	)
	assert_false(
		architecture.is_module_ready(replacement),
		"尚未提交的 staged replacement 不得公开 ready 状态。"
	)
	assert_false(
		replacement.is_ready_in_architecture(),
		"staged replacement 的模块便捷查询也不得越过原子提交点。"
	)
	var previous_tick_count: int = previous.tick_count
	var replacement_tick_count: int = replacement.tick_count
	architecture.tick(0.1)
	assert_eq(previous.tick_count, previous_tick_count)
	assert_eq(
		replacement.tick_count,
		replacement_tick_count,
		"普通 tick 不得重复驱动 staged replacement。"
	)

	assert_true(replacement.complete_activation())
	assert_true(
		await _wait_for_module_quiesce_start(previous),
		"candidate activation 后应等待旧模块 quiesce。"
	)
	assert_false(GFVariantData.get_option_bool(replace_state, "done"))
	assert_same(
		architecture.get_local_utility(PendingHotRegistrationUtility),
		previous,
		"旧模块 quiesce 完成前注册表仍必须公开旧实例。"
	)
	assert_false(
		architecture.is_module_ready(replacement),
		"旧模块 quiesce 期间 staged replacement 仍不得公开 ready。"
	)
	assert_false(
		architecture.is_module_active(replacement),
		"完成 activation 但尚未提交的 replacement 不得公开 active。"
	)
	assert_false(
		replacement.is_ready_in_architecture(),
		"staged replacement 在整个事务提交前都必须保持不可见。"
	)
	assert_true(previous.complete_quiesce(), "测试门闩应成功完成旧模块 quiesce。")
	await _wait_for_transaction_state(replace_state)

	assert_true(GFVariantData.get_option_bool(replace_state, "result"))
	assert_true(architecture.is_accepting_runtime_work())
	assert_same(
		architecture.get_local_utility(PendingHotRegistrationUtility),
		replacement,
		"替换成功后注册表应原子切换到新实例。"
	)
	assert_true(architecture.is_module_ready(replacement))
	assert_true(architecture.is_module_active(replacement))
	assert_true(replacement.is_ready_in_architecture())
	assert_false(architecture.is_module_ready(previous))
	assert_false(architecture.is_module_active(previous))
	assert_eq(previous.dispose_count, 1)
	architecture.dispose()
	assert_eq(replacement.dispose_count, 1)


func test_hot_register_stages_service_until_atomic_commit() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	assert_true(await architecture.init())
	var candidate: StagedServiceProviderUtility = (
		StagedServiceProviderUtility.new(true, false)
	)
	var register_state: Dictionary = {
		"done": false,
		"result": false,
	}

	@warning_ignore("missing_await")
	_await_staged_service_register(architecture, candidate, register_state)
	await get_tree().process_frame

	assert_true(candidate.service_registered, "候选应已写入事务内 service intent。")
	assert_null(
		architecture.get_service(STAGED_SERVICE_KEY),
		"候选提交前不得公开 staged service provider。"
	)
	assert_false(architecture.is_accepting_runtime_work())

	assert_true(candidate.complete_activation())
	await _wait_for_transaction_state(register_state)

	assert_true(GFVariantData.get_option_bool(register_state, "result"))
	assert_same(
		architecture.get_service(STAGED_SERVICE_KEY),
		candidate,
		"候选与 service provider 必须在同一提交点原子可见。"
	)
	architecture.dispose()
	assert_eq(candidate.dispose_count, 1)


func test_hot_replace_switches_service_provider_only_at_commit() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var previous: StagedServiceProviderUtility = (
		StagedServiceProviderUtility.new(false, false)
	)
	assert_true(await architecture.register_utility_instance(previous))
	assert_true(await architecture.init())
	assert_same(architecture.get_service(STAGED_SERVICE_KEY), previous)
	var replacement: StagedServiceProviderUtility = (
		StagedServiceProviderUtility.new(true, false)
	)
	var replace_state: Dictionary = {
		"done": false,
		"result": false,
	}

	@warning_ignore("missing_await")
	_await_staged_service_replace(architecture, replacement, replace_state)
	await get_tree().process_frame

	assert_true(replacement.service_registered)
	assert_same(
		architecture.get_service(STAGED_SERVICE_KEY),
		previous,
		"替换候选 pending 时 service 查询必须继续返回旧 provider。"
	)
	assert_false(GFVariantData.get_option_bool(replace_state, "done"))

	assert_true(replacement.complete_activation())
	await _wait_for_transaction_state(replace_state)

	assert_true(GFVariantData.get_option_bool(replace_state, "result"))
	assert_same(
		architecture.get_service(STAGED_SERVICE_KEY),
		replacement,
		"替换提交后 service 查询必须原子切换到新 provider。"
	)
	assert_eq(previous.dispose_count, 1)
	architecture.dispose()
	assert_eq(replacement.dispose_count, 1)


func test_failed_hot_replace_preserves_previous_service_provider() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var previous: StagedServiceProviderUtility = (
		StagedServiceProviderUtility.new(false, false)
	)
	assert_true(await architecture.register_utility_instance(previous))
	assert_true(await architecture.init())
	var rejected: StagedServiceProviderUtility = (
		StagedServiceProviderUtility.new(false, true)
	)

	assert_false(
		await architecture.replace_utility(
			StagedServiceProviderUtility,
			rejected
		)
	)

	assert_same(
		architecture.get_service(STAGED_SERVICE_KEY),
		previous,
		"替换失败必须保留旧 service provider。"
	)
	assert_same(
		architecture.get_local_utility(StagedServiceProviderUtility),
		previous,
		"替换失败必须保留旧 Utility。"
	)
	assert_eq(previous.dispose_count, 0)
	assert_eq(rejected.dispose_count, 1)
	assert_push_error("[GFArchitecture] 热模块 activation 失败")
	architecture.dispose()
	assert_eq(previous.dispose_count, 1)


func test_hot_replace_rejects_provider_identity_drift_for_active_consumer() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var previous: StableDependencyProviderUtility = (
		StableDependencyProviderUtility.new()
	)
	var consumer: StableDependencyConsumerSystem = (
		StableDependencyConsumerSystem.new()
	)
	assert_true(await architecture.register_utility_instance(previous))
	assert_true(await architecture.register_system_instance(consumer))
	assert_true(await architecture.init())
	var replacement: StableDependencyProviderUtility = (
		StableDependencyProviderUtility.new()
	)

	assert_false(
		await architecture.replace_utility(
			StableDependencyProviderUtility,
			replacement
		),
		"活动 Consumer 的已解析 provider 身份不得被热替换漂移。"
	)

	assert_same(
		architecture.get_local_utility(
			StableDependencyProviderUtility
		),
		previous
	)
	assert_eq(previous.dispose_count, 0, "拒绝替换时旧 provider 应继续活动。")
	assert_eq(replacement.dispose_count, 1, "拒绝的 replacement 应且只应清理一次。")
	assert_push_error(
		"[GFArchitecture] hot replace 失败：既有活动模块的声明或解析目标发生漂移"
	)
	architecture.dispose()
	assert_eq(previous.dispose_count, 1)


func test_hot_unregister_rejects_alternate_fallback_resolution_drift() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var exact_provider: FallbackProviderUtility = (
		FallbackProviderUtility.new()
	)
	var alternate_provider: AlternateFallbackProviderUtility = (
		AlternateFallbackProviderUtility.new()
	)
	var consumer: FallbackConsumerSystem = FallbackConsumerSystem.new()
	assert_true(await architecture.register_utility_instance(exact_provider))
	assert_true(
		await architecture.register_utility_instance(alternate_provider)
	)
	assert_true(await architecture.register_system_instance(consumer))
	assert_true(await architecture.init())

	assert_false(
		await architecture.unregister_utility(FallbackProviderUtility),
		"移除 exact provider 导致 assignable fallback 漂移时必须拒绝。"
	)

	assert_same(
		architecture.get_local_utility(FallbackProviderUtility),
		exact_provider
	)
	assert_same(
		architecture.get_local_utility(
			AlternateFallbackProviderUtility
		),
		alternate_provider
	)
	assert_eq(exact_provider.dispose_count, 0)
	assert_push_error(
		"[GFArchitecture] hot unregister 失败：既有活动模块的声明或解析目标发生漂移"
	)
	architecture.dispose()
	assert_eq(exact_provider.dispose_count, 1)
	assert_eq(alternate_provider.dispose_count, 1)


func test_unrelated_hot_register_rejects_existing_dependency_hook_drift() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var primary: DriftPrimaryProviderUtility = (
		DriftPrimaryProviderUtility.new()
	)
	var alternate: DriftAlternateProviderUtility = (
		DriftAlternateProviderUtility.new()
	)
	var consumer: DriftingDependencyConsumerSystem = (
		DriftingDependencyConsumerSystem.new()
	)
	assert_true(await architecture.register_utility_instance(primary))
	assert_true(await architecture.register_utility_instance(alternate))
	assert_true(await architecture.register_system_instance(consumer))
	assert_true(await architecture.init())
	consumer.use_alternate = true
	var unrelated: UnrelatedHotUtility = UnrelatedHotUtility.new()

	assert_false(
		await architecture.register_utility_instance(unrelated),
		"无关热注册也不得接受既有 required Hook 的声明漂移。"
	)

	assert_null(architecture.get_local_utility(UnrelatedHotUtility))
	assert_eq(unrelated.inject_count, 0, "计划稳定性失败后不得继续准备无关候选。")
	assert_eq(unrelated.dispose_count, 1)
	assert_same(
		architecture.get_local_utility(DriftPrimaryProviderUtility),
		primary
	)
	assert_push_error(
		"[GFArchitecture] hot register 失败：既有活动模块的声明或解析目标发生漂移"
	)
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


func test_hot_replacement_ready_reentry_cannot_supersede_outer_transaction() -> void:
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

	assert_true(replaced, "replacement ready 回调中的重入注销应被拒绝，外层事务应正常提交。")
	assert_same(
		architecture.get_local_utility(ReadyReentrantReplacementUtility),
		replacement_utility,
		"重入注销不得越过外层拓扑事务移除 replacement。"
	)
	assert_true(
		architecture.is_module_ready(replacement_utility),
		"成功提交的 replacement 应保留 ready stage。"
	)
	assert_eq(replacement_utility.dispose_count, 0, "活动 replacement 在架构释放前不得被释放。")
	assert_eq(previous_utility.dispose_count, 1, "被 supersede 的旧实例应只释放一次。")
	assert_push_error(
		"[GFArchitecture] unregister_utility 失败：另一项模块拓扑事务尚未完成。"
	)
	architecture.dispose()
	assert_eq(replacement_utility.dispose_count, 1, "架构释放时 replacement 应且只应释放一次。")


func test_hot_replace_fails_closed_when_detached_dispose_fails_architecture() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var previous: DetachedDisposeReentryUtility = (
		DetachedDisposeReentryUtility.new(
			DetachedDisposeReentryUtility.Reentry.FAIL_INITIALIZATION
		)
	)
	var replacement: DetachedDisposeReentryUtility = (
		DetachedDisposeReentryUtility.new()
	)
	assert_true(await architecture.register_utility_instance(previous))
	assert_true(await architecture.init())

	var replaced: bool = await architecture.replace_utility(
		DetachedDisposeReentryUtility,
		replacement
	)
	var dependency_report: Dictionary = (
		architecture.get_dependency_diagnostics()
	)

	assert_false(
		replaced,
		"detached previous.dispose() 使生命周期失败后，replace 不得报告成功。"
	)
	assert_true(architecture.has_initialization_failed())
	assert_null(
		architecture.get_local_utility(DetachedDisposeReentryUtility),
		"失败清理后不得把 replacement 或 previous 复活进注册表。"
	)
	assert_eq(
		GFVariantData.get_option_int(dependency_report, "module_count"),
		0,
		"失败清理后不得恢复候选或旧 lifecycle plan。"
	)
	assert_eq(previous.dispose_count, 1)
	assert_eq(replacement.dispose_count, 1)
	assert_push_error("[test] detached previous dispose failure")

	architecture.dispose()
	architecture.dispose()
	assert_eq(previous.dispose_count, 1, "终态清理不得重复释放 previous。")
	assert_eq(replacement.dispose_count, 1, "终态清理不得重复释放 replacement。")


func test_hot_unregister_fails_closed_when_detached_dispose_disposes_architecture() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var previous: DetachedDisposeReentryUtility = (
		DetachedDisposeReentryUtility.new(
			DetachedDisposeReentryUtility.Reentry.DISPOSE_ARCHITECTURE
		)
	)
	assert_true(await architecture.register_utility_instance(previous))
	assert_true(await architecture.init())

	var unregistered_value: Variant = await architecture.call(
		&"unregister_utility",
		DetachedDisposeReentryUtility
	)
	var unregistered: bool = GFVariantData.to_bool(unregistered_value)
	var dependency_report: Dictionary = (
		architecture.get_dependency_diagnostics()
	)

	assert_false(
		unregistered,
		"detached previous.dispose() 进入 DISPOSED 后，unregister 不得报告成功。"
	)
	assert_true(architecture.is_disposed())
	assert_null(
		architecture.get_local_utility(DetachedDisposeReentryUtility),
		"dispose 重入后不得把已 detached 实例复活进注册表。"
	)
	assert_eq(
		GFVariantData.get_option_int(dependency_report, "module_count"),
		0,
		"dispose 重入后不得恢复 unregister 前的 lifecycle plan。"
	)
	assert_eq(previous.dispose_count, 1)

	architecture.dispose()
	architecture.dispose()
	assert_eq(previous.dispose_count, 1, "重复终态调用不得再次释放 previous。")


func test_hot_candidate_ready_failure_stops_activation_and_clears_plan() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var stable: StableDependencyProviderUtility = (
		StableDependencyProviderUtility.new()
	)
	assert_true(await architecture.register_utility_instance(stable))
	assert_true(await architecture.init())
	var candidate: ReadyInvalidatingUtility = ReadyInvalidatingUtility.new()

	assert_false(await architecture.register_utility_instance(candidate))

	assert_true(architecture.has_initialization_failed())
	assert_eq(candidate.inject_count, 1)
	assert_eq(candidate.init_count, 1)
	assert_eq(candidate.async_init_count, 1)
	assert_eq(candidate.ready_count, 1)
	assert_eq(
		candidate.activation_count,
		0,
		"ready Hook 使事务失败后不得继续 activation Hook。"
	)
	assert_eq(candidate.dispose_count, 1)
	assert_eq(stable.dispose_count, 1)
	assert_eq(
		GFVariantData.get_option_int(
			architecture.get_dependency_diagnostics(),
			"module_count"
		),
		0,
		"ready Hook 失败后不得复活候选或旧 lifecycle plan。"
	)
	assert_push_error("[test] fail during hot candidate ready")
	architecture.dispose()
	assert_eq(candidate.dispose_count, 1)
	assert_eq(stable.dispose_count, 1)


func test_plan_hook_dispose_stops_remaining_hooks_and_candidate_pipeline() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	assert_true(await architecture.init())
	var candidate: PlanHookInvalidatingUtility = (
		PlanHookInvalidatingUtility.new(
			architecture,
			PlanHookInvalidatingUtility.Invalidation.DISPOSE
		)
	)

	assert_false(await architecture.register_utility_instance(candidate))

	assert_true(architecture.is_disposed())
	_assert_plan_hook_invalidation_stopped(candidate)
	assert_eq(
		GFVariantData.get_option_int(
			architecture.get_dependency_diagnostics(),
			"module_count"
		),
		0,
		"plan Hook dispose 后不得复活 lifecycle plan。"
	)
	architecture.dispose()
	assert_eq(candidate.dispose_count, 1)


func test_plan_hook_failure_stops_remaining_hooks_and_candidate_pipeline() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	assert_true(await architecture.init())
	var candidate: PlanHookInvalidatingUtility = (
		PlanHookInvalidatingUtility.new(
			architecture,
			PlanHookInvalidatingUtility.Invalidation.FAIL
		)
	)

	assert_false(await architecture.register_utility_instance(candidate))

	assert_true(architecture.has_initialization_failed())
	_assert_plan_hook_invalidation_stopped(candidate)
	assert_eq(
		GFVariantData.get_option_int(
			architecture.get_dependency_diagnostics(),
			"module_count"
		),
		0,
		"plan Hook failure 后不得复活 lifecycle plan。"
	)
	assert_push_error("[test] fail during lifecycle plan hook")
	architecture.dispose()
	assert_eq(candidate.dispose_count, 1)


func test_synchronous_hot_activation_crossing_frozen_deadline_fails() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	architecture.activation_timeout_seconds = 0.001
	assert_true(await architecture.init())
	var candidate: DeadlineCrossingActivationUtility = (
		DeadlineCrossingActivationUtility.new(25)
	)

	assert_false(await architecture.register_utility_instance(candidate))

	assert_true(architecture.is_inited(), "局部 activation 超时不应破坏既有 READY 架构。")
	assert_true(architecture.is_accepting_runtime_work())
	assert_null(
		architecture.get_local_utility(
			DeadlineCrossingActivationUtility
		)
	)
	assert_eq(candidate.activation_count, 1)
	assert_eq(candidate.dispose_count, 1)
	assert_push_error("[GFArchitecture] 热模块 activation 失败")
	architecture.dispose()
	assert_eq(candidate.dispose_count, 1)


func test_synchronous_hot_quiesce_crossing_frozen_deadline_fails_closed() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	architecture.shutdown_timeout_seconds = 0.001
	var utility: DeadlineCrossingTopologyQuiesceUtility = (
		DeadlineCrossingTopologyQuiesceUtility.new(25)
	)
	assert_true(await architecture.register_utility_instance(utility))
	assert_true(await architecture.init())

	assert_false(
		await architecture.unregister_utility(
			DeadlineCrossingTopologyQuiesceUtility
		)
	)

	assert_true(
		architecture.is_disposed(),
		"已接纳的 topology quiesce 超时必须 fail-closed 释放架构。"
	)
	assert_eq(utility.quiesce_count, 1)
	assert_eq(utility.dispose_count, 1)
	assert_push_error("[GFArchitecture] 模块拓扑事务 quiesce 失败")
	architecture.dispose()
	assert_eq(utility.dispose_count, 1)


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


func test_project_installer_completion_requires_running_transition() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	watch_signals(architecture)

	architecture.mark_project_installers_applied()
	architecture.finish_project_installers()

	assert_false(
		architecture.has_project_installers_applied(),
		"未 begin 的 mark/finish 不得伪造 Installer 已完成。"
	)
	assert_false(architecture.is_project_installers_running())
	assert_signal_not_emitted(
		architecture,
		"project_installers_finished",
		"非法状态转换不得唤醒等待方。"
	)

	assert_true(architecture.begin_project_installers(), "合法事务应先进入 running。")
	architecture.finish_project_installers()
	assert_true(architecture.has_project_installers_applied())
	assert_false(architecture.is_project_installers_running())
	assert_signal_emit_count(
		architecture,
		"project_installers_finished",
		1,
		"running 到 applied 必须恰好唤醒一次等待方。"
	)

	architecture.mark_project_installers_applied()
	assert_signal_emit_count(
		architecture,
		"project_installers_finished",
		1,
		"终态后的重复 mark 必须保持幂等。"
	)
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


func test_parent_external_dependency_lease_blocks_topology_until_child_shutdown() -> void:
	var parent: GFArchitecture = GFArchitecture.new()
	var provider: StableDependencyProviderUtility = (
		StableDependencyProviderUtility.new()
	)
	assert_true(await parent.register_utility_instance(provider))
	assert_true(await parent.init())
	var child: GFArchitecture = GFArchitecture.new(parent)
	assert_true(
		await child.register_system_instance(
			StableDependencyConsumerSystem.new()
		)
	)
	assert_true(await child.init())
	var rejected_replacement: StableDependencyProviderUtility = (
		StableDependencyProviderUtility.new()
	)

	var blocked_parent_shutdown: GFArchitectureShutdownResult = (
		await parent.shutdown_async()
	)
	assert_eq(
		blocked_parent_shutdown.get_status(),
		GFArchitectureShutdownResult.Status.FAILED
	)
	assert_eq(blocked_parent_shutdown.get_error_code(), ERR_BUSY)
	assert_true(
		parent.is_inited(),
		"被 child 外部依赖租约拒绝的正常关闭必须保留父架构 READY。"
	)
	assert_true(parent.is_accepting_runtime_work())
	assert_false(parent.is_quiescing())
	assert_false(parent.is_disposed())
	assert_false(
		await parent.replace_utility(
			StableDependencyProviderUtility,
			rejected_replacement
		),
		"活动 child 的父级外部依赖租约必须拒绝 provider replace。"
	)
	assert_false(
		await parent.unregister_utility(
			StableDependencyProviderUtility
		),
		"活动 child 的父级外部依赖租约必须拒绝 provider unregister。"
	)
	assert_same(
		parent.get_local_utility(StableDependencyProviderUtility),
		provider
	)
	assert_eq(provider.dispose_count, 0)
	assert_push_error("活动子架构仍持有父级外部模块依赖租约")
	assert_push_error("活动子架构仍持有父级外部模块依赖租约")

	var child_shutdown: GFArchitectureShutdownResult = (
		await child.shutdown_async()
	)
	assert_true(child_shutdown.is_successful())
	assert_true(
		await parent.unregister_utility(
			StableDependencyProviderUtility
		),
		"child 完成关闭并释放租约后，父级拓扑事务应恢复可用。"
	)
	assert_eq(provider.dispose_count, 1)
	parent.dispose()


func test_child_shutdown_retains_parent_lease_through_cleanup_hooks() -> void:
	var parent: GFArchitecture = GFArchitecture.new()
	var provider: StableDependencyProviderUtility = (
		StableDependencyProviderUtility.new()
	)
	assert_true(await parent.register_utility_instance(provider))
	assert_true(await parent.init())
	var child: GFArchitecture = GFArchitecture.new(parent)
	var cleanup_probe: ParentShutdownDuringCleanupUtility = (
		ParentShutdownDuringCleanupUtility.new(parent)
	)
	assert_true(await child.register_utility_instance(cleanup_probe))
	assert_true(await child.init())

	var child_shutdown: GFArchitectureShutdownResult = await child.shutdown_async()
	assert_true(child_shutdown.is_successful(), "child 应正常完成关闭。")
	assert_true(
		await _wait_for_cleanup_parent_shutdown(cleanup_probe),
		"child dispose 中发起的父级 shutdown 应有界返回。"
	)
	_assert_cleanup_parent_shutdown_was_blocked(cleanup_probe)
	assert_false(parent.is_disposed(), "child 清理完成前的重入不得终结 parent。")
	assert_true(parent.is_accepting_runtime_work(), "ERR_BUSY 后 parent 应保持 READY。")
	assert_eq(provider.dispose_count, 0, "child 清理期间 parent provider 必须保持存活。")

	var parent_shutdown: GFArchitectureShutdownResult = await parent.shutdown_async()
	assert_true(parent_shutdown.is_successful(), "child 显式释放租约后 parent 应可关闭。")
	assert_eq(provider.dispose_count, 1, "parent 最终关闭应只释放 provider 一次。")


func test_child_init_failure_retains_parent_lease_through_cleanup_hooks() -> void:
	var parent: GFArchitecture = GFArchitecture.new()
	var provider: StableDependencyProviderUtility = (
		StableDependencyProviderUtility.new()
	)
	assert_true(await parent.register_utility_instance(provider))
	assert_true(await parent.init())
	var child: GFArchitecture = GFArchitecture.new(parent)
	var cleanup_probe: ParentShutdownDuringCleanupUtility = (
		ParentShutdownDuringCleanupUtility.new(parent)
	)
	assert_true(await child.register_utility_instance(cleanup_probe))
	assert_true(
		await child.register_utility_instance(FailingChildActivationUtility.new())
	)

	assert_false(await child.init(), "测试 child 应在 activation 阶段失败。")
	assert_true(
		await _wait_for_cleanup_parent_shutdown(cleanup_probe),
		"child 失败清理中的父级 shutdown 应有界返回。"
	)
	_assert_cleanup_parent_shutdown_was_blocked(cleanup_probe)
	assert_false(parent.is_disposed(), "child 失败清理不得提前终结 parent。")
	assert_true(parent.is_accepting_runtime_work(), "child 失败后 parent 仍应保持 READY。")
	assert_eq(provider.dispose_count, 0, "child 失败清理期间 provider 必须保持存活。")
	assert_push_error("[GFArchitecture] activation 失败")

	var parent_shutdown: GFArchitectureShutdownResult = await parent.shutdown_async()
	assert_true(parent_shutdown.is_successful(), "child 失败清理释放租约后 parent 应可关闭。")
	assert_eq(provider.dispose_count, 1, "parent 最终关闭应只释放 provider 一次。")
	child.dispose()


func test_parent_factory_dependency_lease_blocks_shutdown_without_freezing_module_topology() -> void:
	var parent: GFArchitecture = GFArchitecture.new()
	var provider_state: Dictionary = {"call_count": 0}
	var factory: Callable = func() -> Object:
		provider_state["call_count"] = (
			GFVariantData.get_option_int(
				provider_state,
				"call_count"
			)
			+ 1
		)
		return FactoryLeaseProduct.new()
	assert_true(
		parent.register_factory(
			FactoryLeaseProduct,
			factory
		)
	)
	assert_true(await parent.init())
	var child: GFArchitecture = GFArchitecture.new(parent)
	assert_true(
		await child.register_system_instance(
			FactoryLeaseConsumerSystem.new()
		)
	)
	assert_true(await child.init())

	var product: Object = child.create_instance(FactoryLeaseProduct)
	assert_not_null(product)
	assert_eq(
		GFVariantData.get_option_int(provider_state, "call_count"),
		1
	)
	var unrelated_utility: UnrelatedHotUtility = UnrelatedHotUtility.new()
	assert_true(
		await parent.register_utility_instance(unrelated_utility),
		"仅依赖父级 factory 的 child 不应冻结无关模块拓扑。"
	)
	assert_same(
		parent.get_local_utility(UnrelatedHotUtility),
		unrelated_utility
	)

	var blocked_parent_shutdown: GFArchitectureShutdownResult = (
		await parent.shutdown_async()
	)
	assert_eq(
		blocked_parent_shutdown.get_status(),
		GFArchitectureShutdownResult.Status.FAILED
	)
	assert_eq(blocked_parent_shutdown.get_error_code(), ERR_BUSY)
	assert_true(parent.is_accepting_runtime_work())

	var child_shutdown: GFArchitectureShutdownResult = (
		await child.shutdown_async()
	)
	assert_true(child_shutdown.is_successful())
	var parent_shutdown: GFArchitectureShutdownResult = (
		await parent.shutdown_async()
	)
	assert_true(parent_shutdown.is_successful())
	assert_eq(unrelated_utility.dispose_count, 1)


func test_mixed_parent_dependency_lease_preserves_module_topology_scope() -> void:
	var parent: GFArchitecture = GFArchitecture.new()
	var provider: StableDependencyProviderUtility = (
		StableDependencyProviderUtility.new()
	)
	var factory: Callable = func() -> Object:
		return FactoryLeaseProduct.new()
	assert_true(await parent.register_utility_instance(provider))
	assert_true(parent.register_factory(FactoryLeaseProduct, factory))
	assert_true(await parent.init())
	var child: GFArchitecture = GFArchitecture.new(parent)
	assert_true(
		await child.register_system_instance(
			MixedExternalDependencyConsumerSystem.new()
		)
	)
	assert_true(await child.init())

	assert_false(
		await parent.register_utility_instance(UnrelatedHotUtility.new()),
		"同 owner 的 factory lease 不得把 module lease 的拓扑 scope 降级。"
	)
	assert_push_error("活动子架构仍持有父级外部模块依赖租约")
	var blocked_shutdown: GFArchitectureShutdownResult = (
		await parent.shutdown_async()
	)
	assert_eq(blocked_shutdown.get_error_code(), ERR_BUSY)

	var child_shutdown: GFArchitectureShutdownResult = (
		await child.shutdown_async()
	)
	assert_true(child_shutdown.is_successful())
	var parent_shutdown: GFArchitectureShutdownResult = (
		await parent.shutdown_async()
	)
	assert_true(parent_shutdown.is_successful())


func test_forced_parent_dispose_prevents_child_from_invoking_parent_factory() -> void:
	var parent: GFArchitecture = GFArchitecture.new()
	var provider_state: Dictionary = {"call_count": 0}
	var dispose_probe: FactoryInvocationDuringDisposeUtility = (
		FactoryInvocationDuringDisposeUtility.new()
	)
	var factory: Callable = func() -> Object:
		provider_state["call_count"] = (
			GFVariantData.get_option_int(
				provider_state,
				"call_count"
			)
			+ 1
		)
		return FactoryLeaseProduct.new()
	assert_true(await parent.register_utility_instance(dispose_probe))
	assert_true(
		parent.register_factory(
			FactoryLeaseProduct,
			factory
		)
	)
	assert_true(await parent.init())
	var child: GFArchitecture = GFArchitecture.new(parent)
	assert_true(
		await child.register_system_instance(
			FactoryLeaseConsumerSystem.new()
		)
	)
	assert_true(await child.init())
	dispose_probe.child_architecture = child
	dispose_probe.requested_script = FactoryLeaseProduct

	parent.dispose()

	assert_null(
		dispose_probe.factory_result,
		"强制释放父级期间，child 不得调用正在关闭 owner 的 factory provider。"
	)
	assert_eq(
		GFVariantData.get_option_int(provider_state, "call_count"),
		0
	)
	assert_push_error("工厂所属架构未开放运行时准入")
	child.dispose()


func test_owner_denial_releases_unreturned_transient_fallback() -> void:
	var parent: GFArchitecture = GFArchitecture.new()
	var dispose_probe: FactoryInvocationDuringDisposeUtility = (
		FactoryInvocationDuringDisposeUtility.new()
	)
	var parent_factory: Callable = func() -> Object:
		return FactoryLeaseProduct.new()
	assert_true(await parent.register_utility_instance(dispose_probe))
	assert_true(
		parent.register_factory(
			FactoryLeaseProduct,
			parent_factory
		)
	)
	assert_true(await parent.init())
	var child: GFArchitecture = GFArchitecture.new(parent)
	var transient_factory: TransientFallbackAfterOwnerDeniedFactory = (
		TransientFallbackAfterOwnerDeniedFactory.new(child)
	)
	assert_true(
		child.register_factory(
			TransientFallbackProduct,
			Callable(transient_factory, &"create")
		)
	)
	assert_true(
		await child.register_system_instance(
			FactoryLeaseConsumerSystem.new()
		)
	)
	assert_true(await child.init())
	dispose_probe.child_architecture = child
	dispose_probe.requested_script = TransientFallbackProduct

	parent.dispose()

	assert_true(
		transient_factory.nested_result_was_null,
		"父级 owner 拒绝后，嵌套 factory 请求应返回 null。"
	)
	assert_null(
		dispose_probe.factory_result,
		"共享解析上下文失败后，外层 transient fallback 不得交付。"
	)
	assert_not_null(transient_factory.rejected_instance_ref)
	if transient_factory.rejected_instance_ref != null:
		var rejected_instance_value: Variant = (
			transient_factory.rejected_instance_ref.get_ref()
		)
		assert_true(
			rejected_instance_value == null,
			"未交付的 transient Node 必须释放，不能形成 orphan。"
		)
	assert_push_error("工厂所属架构未开放运行时准入")
	child.dispose()


func test_parent_external_dependency_lease_closes_activation_race_and_forced_dispose_releases() -> void:
	var parent: GFArchitecture = GFArchitecture.new()
	var provider: StableDependencyProviderUtility = (
		StableDependencyProviderUtility.new()
	)
	assert_true(await parent.register_utility_instance(provider))
	assert_true(await parent.init())
	var child: GFArchitecture = GFArchitecture.new(parent)
	var consumer: ExternalLeaseActivationConsumerSystem = (
		ExternalLeaseActivationConsumerSystem.new(
			ExternalLeaseActivationConsumerSystem.ActivationMode.PENDING
		)
	)
	assert_true(await child.register_system_instance(consumer))
	var init_state: Dictionary = {
		"done": false,
		"result": false,
	}
	@warning_ignore("missing_await")
	_await_architecture_init(child, init_state)
	await get_tree().process_frame
	assert_not_null(
		consumer.activation_completion,
		"测试 child 应停在 pending activation。"
	)

	assert_false(
		await parent.unregister_utility(
			StableDependencyProviderUtility
		),
		"child activation pending 期间父级 provider 也必须受租约保护。"
	)
	assert_eq(provider.dispose_count, 0)
	assert_push_error("活动子架构仍持有父级外部模块依赖租约")

	child.dispose()
	child.dispose()
	await _wait_for_transaction_state(init_state)
	assert_true(GFVariantData.get_option_bool(init_state, "done"))
	assert_false(GFVariantData.get_option_bool(init_state, "result"))
	assert_true(
		await parent.unregister_utility(
			StableDependencyProviderUtility
		),
		"forced dispose 必须幂等释放 child 的外部依赖租约。"
	)
	assert_eq(provider.dispose_count, 1)
	parent.dispose()


func test_failed_child_activation_releases_parent_external_dependency_lease() -> void:
	var parent: GFArchitecture = GFArchitecture.new()
	var provider: StableDependencyProviderUtility = (
		StableDependencyProviderUtility.new()
	)
	assert_true(await parent.register_utility_instance(provider))
	assert_true(await parent.init())
	var child: GFArchitecture = GFArchitecture.new(parent)
	var consumer: ExternalLeaseActivationConsumerSystem = (
		ExternalLeaseActivationConsumerSystem.new(
			ExternalLeaseActivationConsumerSystem.ActivationMode.FAIL
		)
	)
	assert_true(await child.register_system_instance(consumer))

	assert_false(await child.init())
	assert_true(child.has_initialization_failed())
	assert_push_error("[GFArchitecture] activation 失败")
	assert_true(
		await parent.unregister_utility(
			StableDependencyProviderUtility
		),
		"child 初始化失败清理必须释放父级外部依赖租约。"
	)
	assert_eq(provider.dispose_count, 1)
	child.dispose()
	parent.dispose()


func test_factory_rejects_owned_result_when_provider_disposes_owner() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var state: Dictionary = {
		"dispose_count": 0,
		"release_count": 0,
	}
	var factory: DisposeOwnerDuringProvideFactory = (
		DisposeOwnerDuringProvideFactory.new(architecture, state)
	)
	assert_true(
		architecture.register_factory(
			FactoryLifecycleGuardProduct,
			Callable(factory, &"create"),
			GFBindingLifetimes.Lifetime.SINGLETON
		)
	)
	assert_true(await architecture.init())

	var result: Object = architecture.create_instance(
		FactoryLifecycleGuardProduct
	)

	assert_null(
		result,
		"provider 关闭 owner 后返回的实例不得缓存或交付。"
	)
	assert_true(architecture.is_disposed())
	assert_eq(
		GFVariantData.get_option_int(state, "dispose_count"),
		1,
		"框架拥有的未交付实例必须且只 dispose 一次。"
	)
	assert_eq(
		GFVariantData.get_option_int(state, "release_count"),
		0,
		"provider 后准入失效发生在注入前，不得伪造注入作用域释放。"
	)
	var instance_ref_value: Variant = state.get("instance_ref")
	assert_true(instance_ref_value is WeakRef)
	if instance_ref_value is WeakRef:
		var instance_ref: WeakRef = instance_ref_value
		var released_instance_value: Variant = instance_ref.get_ref()
		assert_true(
			released_instance_value == null,
			"框架拥有的未交付 Node 必须立即释放。"
		)


func test_parent_singleton_factory_rejects_result_when_provider_disposes_requester() -> void:
	var parent: GFArchitecture = GFArchitecture.new()
	var state: Dictionary = {
		"dispose_count": 0,
		"release_count": 0,
		"nested_result_was_null": false,
	}
	var late_state: Dictionary = {
		"provider_count": 0,
		"inject_count": 0,
	}
	var factory: DisposeRequesterDuringProvideFactory = (
		DisposeRequesterDuringProvideFactory.new(
			parent,
			state
		)
	)
	assert_true(
		parent.register_factory(
			FactoryLifecycleGuardProduct,
			Callable(factory, &"create"),
			GFBindingLifetimes.Lifetime.SINGLETON
		)
	)
	var late_factory: LateTransientFactory = (
		LateTransientFactory.new(late_state)
	)
	assert_true(
		parent.register_factory(
			LateTransientProduct,
			Callable(late_factory, &"create")
		)
	)
	assert_true(await parent.init())
	var child: GFArchitecture = GFArchitecture.new(parent)
	assert_true(await child.init())
	factory.requester_architecture = child

	var result: Object = child.create_instance(
		FactoryLifecycleGuardProduct
	)

	assert_null(
		result,
		"父级 Singleton provider 关闭真实 requester 后不得缓存或交付结果。"
	)
	assert_true(child.is_disposed())
	assert_true(parent.is_accepting_runtime_work())
	assert_eq(GFVariantData.get_option_int(state, "dispose_count"), 1)
	assert_eq(
		GFVariantData.get_option_int(state, "release_count"),
		0,
		"requester 在 provider 内失效发生于注入前。"
	)
	assert_true(
		GFVariantData.get_option_bool(state, "nested_result_was_null"),
		"requester 关闭必须立即使共享解析上下文失败。"
	)
	assert_eq(
		GFVariantData.get_option_int(late_state, "provider_count"),
		0,
		"共享上下文失败后不得执行同一 provider 内的迟到 factory。"
	)
	assert_eq(
		GFVariantData.get_option_int(late_state, "inject_count"),
		0
	)
	var instance_ref_value: Variant = state.get("instance_ref")
	assert_true(instance_ref_value is WeakRef)
	if instance_ref_value is WeakRef:
		var instance_ref: WeakRef = instance_ref_value
		var released_instance_value: Variant = instance_ref.get_ref()
		assert_true(released_instance_value == null)
	parent.dispose()


func test_parent_provider_owner_disposal_blocks_late_child_factory() -> void:
	var parent: GFArchitecture = GFArchitecture.new()
	var outer_state: Dictionary = {
		"dispose_count": 0,
		"release_count": 0,
		"nested_result_was_null": false,
	}
	var late_state: Dictionary = {
		"provider_count": 0,
		"inject_count": 0,
	}
	var factory: DisposeOwnerThenRequesterFactory = (
		DisposeOwnerThenRequesterFactory.new(
			parent,
			outer_state
		)
	)
	assert_true(
		parent.register_factory(
			FactoryLifecycleGuardProduct,
			Callable(factory, &"create"),
			GFBindingLifetimes.Lifetime.SINGLETON
		)
	)
	assert_true(await parent.init())
	var child: GFArchitecture = GFArchitecture.new(parent)
	var late_factory: LateTransientFactory = (
		LateTransientFactory.new(late_state)
	)
	assert_true(
		child.register_factory(
			LateTransientProduct,
			Callable(late_factory, &"create")
		)
	)
	assert_true(await child.init())
	factory.requester_architecture = child

	var result: Object = child.create_instance(
		FactoryLifecycleGuardProduct
	)

	assert_null(result)
	assert_true(parent.is_disposed())
	assert_true(child.is_accepting_runtime_work())
	assert_true(
		GFVariantData.get_option_bool(
			outer_state,
			"nested_result_was_null"
		)
	)
	assert_eq(
		GFVariantData.get_option_int(late_state, "provider_count"),
		0,
		"owner 关闭必须通过共享上下文阻止 child 的迟到 provider。"
	)
	assert_eq(GFVariantData.get_option_int(late_state, "inject_count"), 0)
	assert_eq(
		GFVariantData.get_option_int(outer_state, "dispose_count"),
		1
	)
	assert_eq(
		GFVariantData.get_option_int(outer_state, "release_count"),
		0
	)
	child.dispose()


func test_parent_factory_rejects_owned_result_when_injection_disposes_requester() -> void:
	var parent: GFArchitecture = GFArchitecture.new()
	var state: Dictionary = {
		"inject_count": 0,
		"dispose_count": 0,
		"release_count": 0,
	}
	var factory: InjectionDisposesRequesterFactory = (
		InjectionDisposesRequesterFactory.new(state)
	)
	assert_true(
		parent.register_factory(
			FactoryRequesterGuardProduct,
			Callable(factory, &"create")
		)
	)
	assert_true(await parent.init())
	var child: GFArchitecture = GFArchitecture.new(parent)
	assert_true(await child.init())

	var result: Object = child.create_instance(
		FactoryRequesterGuardProduct
	)

	assert_null(
		result,
		"注入期间关闭 requester 后，父级 factory 结果不得交付。"
	)
	assert_true(child.is_disposed())
	assert_true(parent.is_accepting_runtime_work())
	assert_eq(GFVariantData.get_option_int(state, "inject_count"), 1)
	assert_eq(
		GFVariantData.get_option_int(state, "dispose_count"),
		1,
		"框架拥有的拒绝结果必须且只 dispose 一次。"
	)
	assert_eq(
		GFVariantData.get_option_int(state, "release_count"),
		1,
		"已开始的 requester 注入作用域必须且只释放一次。"
	)
	var instance_ref_value: Variant = state.get("instance_ref")
	assert_true(instance_ref_value is WeakRef)
	if instance_ref_value is WeakRef:
		var instance_ref: WeakRef = instance_ref_value
		var released_instance_value: Variant = instance_ref.get_ref()
		assert_true(
			released_instance_value == null,
			"拒绝的 transient Node 不得形成 orphan。"
		)
	parent.dispose()


func test_parent_factory_instance_keeps_external_ownership_after_requester_disposal() -> void:
	var parent: GFArchitecture = GFArchitecture.new()
	var state: Dictionary = {
		"inject_count": 0,
		"second_hook_count": 0,
		"dispose_count": 0,
		"release_count": 0,
	}
	var external_instance: ExternalRequesterGuardProduct = (
		ExternalRequesterGuardProduct.new(state)
	)
	assert_true(
		parent.register_factory_instance(
			ExternalRequesterGuardProduct,
			external_instance
		)
	)
	assert_true(await parent.init())
	var child: GFArchitecture = GFArchitecture.new(parent)
	assert_true(await child.init())
	external_instance.requester_architecture = child

	var result: Object = child.create_instance(
		ExternalRequesterGuardProduct
	)

	assert_null(
		result,
		"外部 Singleton 实例在注入期间关闭 requester 后不得交付。"
	)
	assert_true(child.is_disposed())
	assert_true(parent.is_accepting_runtime_work())
	assert_true(is_instance_valid(external_instance))
	assert_same(external_instance.injected_architecture, parent)
	assert_eq(GFVariantData.get_option_int(state, "inject_count"), 1)
	assert_eq(
		GFVariantData.get_option_int(state, "second_hook_count"),
		0,
		"requester generation 失效后不得继续调用后续 inject Hook。"
	)
	assert_eq(
		GFVariantData.get_option_int(state, "dispose_count"),
		0,
		"register_factory_instance 的外部实例归属不得被框架夺取。"
	)
	assert_eq(
		GFVariantData.get_option_int(state, "release_count"),
		1,
		"框架仍需释放已经建立的 owner 注入作用域。"
	)
	assert_true(is_instance_valid(external_instance))
	assert_eq(GFVariantData.get_option_int(state, "dispose_count"), 0)
	assert_eq(GFVariantData.get_option_int(state, "release_count"), 1)
	child.dispose()
	parent.dispose()
	assert_true(
		is_instance_valid(external_instance),
		"父级释放 factory binding 后仍不得夺取外部实例所有权。"
	)
	assert_eq(GFVariantData.get_option_int(state, "dispose_count"), 0)
	assert_eq(
		GFVariantData.get_option_int(state, "release_count"),
		1,
		"父级释放不得重复释放已经关闭的外部实例注入作用域。"
	)
	external_instance.free()


func test_factory_rejects_queued_instance_before_later_injection_hooks() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var state: Dictionary = {
		"inject_count": 0,
		"second_hook_count": 0,
		"dispose_count": 0,
	}
	var factory: QueueFreeingInjectionFactory = (
		QueueFreeingInjectionFactory.new(state)
	)
	assert_true(
		architecture.register_factory(
			QueueFreeingInjectionProduct,
			Callable(factory, &"create"),
			GFBindingLifetimes.Lifetime.SINGLETON
		)
	)
	assert_true(await architecture.init())

	var result: Object = architecture.create_instance(
		QueueFreeingInjectionProduct
	)

	assert_null(result, "已 queue_free 的注入结果不得缓存或交付。")
	assert_eq(GFVariantData.get_option_int(state, "inject_count"), 1)
	assert_eq(
		GFVariantData.get_option_int(state, "second_hook_count"),
		0,
		"实例进入 queued 状态后不得继续调用后续 inject Hook。"
	)
	assert_eq(
		GFVariantData.get_option_int(state, "dispose_count"),
		1,
		"框架拥有的 queued 拒绝结果仍应 exactly-once dispose。"
	)
	await get_tree().process_frame
	var instance_ref_value: Variant = state.get("instance_ref")
	assert_true(instance_ref_value is WeakRef)
	if instance_ref_value is WeakRef:
		var instance_ref: WeakRef = instance_ref_value
		var released_instance_value: Variant = instance_ref.get_ref()
		assert_true(released_instance_value == null)
	architecture.dispose()


func test_nested_singleton_rollback_does_not_double_clean_after_owner_disposal() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var outer_state: Dictionary = {
		"dispose_count": 0,
		"release_count": 0,
	}
	var nested_state: Dictionary = {
		"dispose_count": 0,
		"release_count": 0,
	}
	var nested_factory: NestedLifecycleGuardFactory = (
		NestedLifecycleGuardFactory.new(nested_state)
	)
	var outer_factory: DisposeOwnerAfterNestedSingletonFactory = (
		DisposeOwnerAfterNestedSingletonFactory.new(
			architecture,
			outer_state
		)
	)
	assert_true(
		architecture.register_factory(
			FactoryLifecycleGuardProduct,
			Callable(outer_factory, &"create"),
			GFBindingLifetimes.Lifetime.SINGLETON
		)
	)
	assert_true(
		architecture.register_factory(
			NestedLifecycleGuardProduct,
			Callable(nested_factory, &"create"),
			GFBindingLifetimes.Lifetime.SINGLETON
		)
	)
	assert_true(await architecture.init())

	var result: Object = architecture.create_instance(
		FactoryLifecycleGuardProduct
	)

	assert_null(result)
	assert_true(architecture.is_disposed())
	assert_eq(
		GFVariantData.get_option_int(outer_state, "dispose_count"),
		1
	)
	assert_eq(
		GFVariantData.get_option_int(outer_state, "release_count"),
		0
	)
	assert_eq(
		GFVariantData.get_option_int(nested_state, "dispose_count"),
		1,
		"owner dispose 与 resolution rollback 不得重复 dispose 已清理 Singleton。"
	)
	assert_eq(
		GFVariantData.get_option_int(nested_state, "release_count"),
		1,
		"owner dispose 与 resolution rollback 不得重复释放注入作用域。"
	)


func test_parent_transient_rejection_cleans_actual_child_event_scope() -> void:
	var parent: GFArchitecture = GFArchitecture.new()
	var state: Dictionary = {
		"registered_listener_count": 0,
		"second_hook_count": 0,
		"dispose_count": 0,
		"release_count": 0,
		"scope_bind_count": 0,
		"scope_clear_count": 0,
	}
	var factory: ChildEventFailureFactory = (
		ChildEventFailureFactory.new(state)
	)
	assert_true(
		parent.register_factory(
			ChildEventFailureProduct,
			Callable(factory, &"create")
		)
	)
	assert_true(await parent.init())
	var child: GFArchitecture = GFArchitecture.new(parent)
	assert_true(await child.init())

	var result: Object = child.create_instance(
		ChildEventFailureProduct
	)

	assert_null(result)
	assert_eq(
		GFVariantData.get_option_int(state, "registered_listener_count"),
		1,
		"fixture 应先在实际注入的 child 注册 owner event。"
	)
	assert_eq(
		GFVariantData.get_option_int(state, "second_hook_count"),
		0,
		"嵌套解析失败后不得继续调用后续 inject Hook。"
	)
	assert_eq(GFVariantData.get_option_int(state, "dispose_count"), 1)
	assert_eq(GFVariantData.get_option_int(state, "release_count"), 1)
	assert_eq(GFVariantData.get_option_int(state, "scope_bind_count"), 1)
	assert_eq(
		GFVariantData.get_option_int(state, "scope_clear_count"),
		0,
		"release_dependencies 进入 queued 状态后不得继续调用 scope clear Hook。"
	)
	assert_eq(
		GFVariantData.get_option_int(
			child.get_event_debug_stats(),
			"listener_count"
		),
		0,
		"父级 transient 拒绝结果必须清理实际 child 注入作用域。"
	)
	assert_eq(
		GFVariantData.get_option_int(
			parent.get_event_debug_stats(),
			"listener_count"
		),
		0
	)
	await get_tree().process_frame
	var instance_ref_value: Variant = state.get("instance_ref")
	assert_true(instance_ref_value is WeakRef)
	if instance_ref_value is WeakRef:
		var instance_ref: WeakRef = instance_ref_value
		var released_instance_value: Variant = instance_ref.get_ref()
		assert_true(released_instance_value == null)
	assert_push_error("create_instance 失败：未注册工厂")
	child.dispose()
	parent.dispose()


func test_factory_resolution_rejects_reentrant_topology_mutation() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var state: Dictionary = {
		"dispose_count": 0,
		"release_count": 0,
		"mutation_result": true,
		"nested_result_was_null": false,
	}
	var late_state: Dictionary = {
		"provider_count": 0,
		"inject_count": 0,
	}
	var cached_state: Dictionary = {
		"provider_count": 0,
	}
	var factory: ReentrantTopologyFactory = (
		ReentrantTopologyFactory.new(architecture, state)
	)
	assert_true(
		architecture.register_factory(
			FactoryLifecycleGuardProduct,
			Callable(factory, &"create")
		)
	)
	var late_factory: LateTransientFactory = (
		LateTransientFactory.new(late_state)
	)
	assert_true(
		architecture.register_factory(
			LateTransientProduct,
			Callable(late_factory, &"create")
		)
	)
	var cached_factory: CachedResolutionGuardFactory = (
		CachedResolutionGuardFactory.new(cached_state)
	)
	assert_true(
		architecture.register_factory(
			CachedResolutionGuardProduct,
			Callable(cached_factory, &"create"),
			GFBindingLifetimes.Lifetime.SINGLETON
		)
	)
	assert_true(await architecture.init())
	assert_not_null(
		architecture.create_instance(CachedResolutionGuardProduct)
	)

	var result: Object = architecture.create_instance(
		FactoryLifecycleGuardProduct
	)

	assert_null(
		result,
		"provider 内拒绝的拓扑重入必须使整条 factory 解析失败。"
	)
	assert_false(
		GFVariantData.get_option_bool(state, "mutation_result", true)
	)
	assert_false(architecture.has_factory(ReentrantTopologyProduct))
	assert_true(
		GFVariantData.get_option_bool(state, "nested_result_was_null")
	)
	assert_eq(
		GFVariantData.get_option_int(late_state, "provider_count"),
		0,
		"解析上下文失败后不得继续执行其它 provider。"
	)
	assert_eq(GFVariantData.get_option_int(late_state, "inject_count"), 0)
	assert_true(
		GFVariantData.get_option_bool(state, "cached_result_was_null"),
		"失败上下文不得交付已经存在的 Singleton cache。"
	)
	assert_eq(
		GFVariantData.get_option_int(cached_state, "provider_count"),
		1,
		"失败上下文不得重新进入或重新创建 cached Singleton。"
	)
	assert_eq(GFVariantData.get_option_int(state, "dispose_count"), 1)
	assert_eq(GFVariantData.get_option_int(state, "release_count"), 0)
	var instance_ref_value: Variant = state.get("instance_ref")
	assert_true(instance_ref_value is WeakRef)
	if instance_ref_value is WeakRef:
		var instance_ref: WeakRef = instance_ref_value
		var released_instance_value: Variant = instance_ref.get_ref()
		assert_true(released_instance_value == null)
	assert_push_error("工厂解析期间禁止重入修改模块拓扑")
	architecture.dispose()


func test_successful_nested_transient_transfer_is_not_retroactively_rolled_back() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var outer_state: Dictionary = {
		"dispose_count": 0,
		"release_count": 0,
	}
	var transient_state: Dictionary = {
		"provider_count": 0,
		"inject_count": 0,
		"dispose_count": 0,
		"release_count": 0,
	}
	var transient_factory: TransferredTransientFactory = (
		TransferredTransientFactory.new(transient_state)
	)
	var outer_factory: FailureAfterTransientTransferFactory = (
		FailureAfterTransientTransferFactory.new(
			architecture,
			outer_state
		)
	)
	assert_true(
		architecture.register_factory(
			TransferredTransientProduct,
			Callable(transient_factory, &"create")
		)
	)
	assert_true(
		architecture.register_factory(
			FactoryLifecycleGuardProduct,
			Callable(outer_factory, &"create")
		)
	)
	assert_true(await architecture.init())

	var result: Object = architecture.create_instance(
		FactoryLifecycleGuardProduct
	)

	assert_null(result)
	assert_not_null(outer_factory.transferred_instance)
	assert_true(
		is_instance_valid(outer_factory.transferred_instance),
		"成功返回给直接调用者的 transient 已完成所有权转移。"
	)
	assert_eq(
		GFVariantData.get_option_int(transient_state, "provider_count"),
		1
	)
	assert_eq(
		GFVariantData.get_option_int(transient_state, "inject_count"),
		1
	)
	assert_eq(
		GFVariantData.get_option_int(transient_state, "dispose_count"),
		0,
		"外层解析后续失败不得追溯夺回已交付 transient 的所有权。"
	)
	assert_eq(
		GFVariantData.get_option_int(transient_state, "release_count"),
		0
	)
	assert_eq(GFVariantData.get_option_int(outer_state, "dispose_count"), 1)
	assert_push_error("工厂解析期间禁止重入修改模块拓扑")
	outer_factory.transferred_instance.free()
	outer_factory.transferred_instance = null
	architecture.dispose()


# --- 辅助方法 ---

func _await_architecture_init(
	architecture: GFArchitecture,
	state: Dictionary
) -> void:
	state["result"] = await architecture.init()
	state["done"] = true


func _await_pending_hot_register(
	architecture: GFArchitecture,
	candidate: PendingHotRegistrationUtility,
	state: Dictionary
) -> void:
	state["result"] = await architecture.register_utility_instance(candidate)
	state["done"] = true


func _await_pending_hot_replace(
	architecture: GFArchitecture,
	candidate: PendingHotRegistrationUtility,
	state: Dictionary
) -> void:
	state["result"] = await architecture.replace_utility(
		PendingHotRegistrationUtility,
		candidate
	)
	state["done"] = true


func _await_staged_service_register(
	architecture: GFArchitecture,
	candidate: StagedServiceProviderUtility,
	state: Dictionary
) -> void:
	state["result"] = await architecture.register_utility_instance(candidate)
	state["done"] = true


func _await_staged_service_replace(
	architecture: GFArchitecture,
	candidate: StagedServiceProviderUtility,
	state: Dictionary
) -> void:
	state["result"] = await architecture.replace_utility(
		StagedServiceProviderUtility,
		candidate
	)
	state["done"] = true


func _wait_for_transaction_state(state: Dictionary) -> void:
	for _frame: int in range(30):
		if GFVariantData.get_option_bool(state, "done"):
			return
		await get_tree().process_frame


func _wait_for_module_quiesce_start(
	module: PendingHotRegistrationUtility,
	max_frames: int = 30
) -> bool:
	for _frame: int in range(max_frames):
		if module.quiesce_completion != null:
			return true
		await get_tree().process_frame
	return module.quiesce_completion != null


func _wait_for_cleanup_parent_shutdown(
	probe: ParentShutdownDuringCleanupUtility,
	max_frames: int = 30
) -> bool:
	for _frame: int in range(max_frames):
		if probe.parent_shutdown_done:
			return true
		await get_tree().process_frame
	return probe.parent_shutdown_done


func _assert_cleanup_parent_shutdown_was_blocked(
	probe: ParentShutdownDuringCleanupUtility
) -> void:
	assert_eq(probe.dispose_count, 1, "child cleanup probe 必须且只应 dispose 一次。")
	assert_eq(probe.release_count, 1, "child cleanup probe 必须且只应 release 一次。")
	assert_false(
		probe.parent_disposed_during_release,
		"parent 必须 outlive child 的 release_dependencies()。"
	)
	assert_not_null(probe.parent_shutdown_result, "重入父级 shutdown 应返回 typed 结果。")
	if probe.parent_shutdown_result != null:
		assert_eq(
			probe.parent_shutdown_result.get_status(),
			GFArchitectureShutdownResult.Status.FAILED,
			"child 仍持有 lease 时父级 shutdown 必须失败。"
		)
		assert_eq(
			probe.parent_shutdown_result.get_error_code(),
			ERR_BUSY,
			"child cleanup 期间父级 shutdown 应以 ERR_BUSY fail closed。"
		)


func _assert_plan_hook_invalidation_stopped(
	candidate: PlanHookInvalidatingUtility
) -> void:
	assert_eq(candidate.model_hook_count, 1)
	assert_eq(
		candidate.system_hook_count,
		0,
		"首个 dependency Hook 使事务失效后不得继续 system Hook。"
	)
	assert_eq(
		candidate.utility_hook_count,
		0,
		"首个 dependency Hook 使事务失效后不得继续 utility Hook。"
	)
	assert_eq(
		candidate.factory_hook_count,
		0,
		"首个 dependency Hook 使事务失效后不得继续 factory Hook。"
	)
	assert_eq(candidate.inject_count, 0)
	assert_eq(candidate.init_count, 0)
	assert_eq(candidate.async_init_count, 0)
	assert_eq(candidate.ready_count, 0)
	assert_eq(candidate.activation_count, 0)
	assert_eq(candidate.dispose_count, 1)


# --- 内部类 ---

class CancellingAsyncUtility extends GFUtility:
	var disposed: bool = false

	func async_init(scope: GFAsyncScope) -> void:
		var _cancelled_scope: bool = scope.cancel("[test] cancel async lifecycle")

	func dispose() -> void:
		disposed = true


class PendingHotRegistrationUtility extends GFUtility:
	var block_activation: bool = true
	var block_quiesce: bool = false
	var activation_completion: GFAsyncCompletion = null
	var quiesce_completion: GFAsyncCompletion = null
	var activation_count: int = 0
	var tick_count: int = 0
	var dispose_count: int = 0

	func _init(
		should_block_activation: bool = true,
		should_block_quiesce: bool = false
	) -> void:
		block_activation = should_block_activation
		block_quiesce = should_block_quiesce
		tick_enabled = true

	func begin_activation(_scope: GFAsyncScope) -> GFAsyncCompletion:
		activation_count += 1
		activation_completion = GFAsyncCompletion.new()
		if not block_activation:
			var _succeeded: bool = activation_completion.succeed()
		return activation_completion

	func begin_quiesce(_scope: GFAsyncScope) -> GFAsyncCompletion:
		quiesce_completion = GFAsyncCompletion.new()
		if not block_quiesce:
			var _succeeded: bool = quiesce_completion.succeed()
		return quiesce_completion

	func tick(_delta: float) -> void:
		tick_count += 1

	func complete_activation() -> bool:
		return (
			activation_completion != null
			and activation_completion.succeed()
		)

	func complete_quiesce() -> bool:
		return (
			quiesce_completion != null
			and quiesce_completion.succeed()
		)

	func dispose() -> void:
		dispose_count += 1


class StagedServiceProviderUtility extends GFUtility:
	var block_activation: bool = false
	var fail_activation: bool = false
	var activation_completion: GFAsyncCompletion = null
	var service_registered: bool = false
	var dispose_count: int = 0

	func _init(
		should_block_activation: bool,
		should_fail_activation: bool
	) -> void:
		block_activation = should_block_activation
		fail_activation = should_fail_activation

	func init() -> void:
		var architecture: GFArchitecture = _get_architecture()
		service_registered = architecture.register_service(
			STAGED_SERVICE_KEY,
			self
		)

	func begin_activation(_scope: GFAsyncScope) -> GFAsyncCompletion:
		activation_completion = GFAsyncCompletion.new()
		if fail_activation:
			var _failed: bool = activation_completion.fail(
				"[test] staged service activation rejected"
			)
		elif not block_activation:
			var _succeeded: bool = activation_completion.succeed()
		return activation_completion

	func begin_quiesce(_scope: GFAsyncScope) -> GFAsyncCompletion:
		var completion: GFAsyncCompletion = GFAsyncCompletion.new()
		var _succeeded: bool = completion.succeed()
		return completion

	func complete_activation() -> bool:
		return (
			activation_completion != null
			and activation_completion.succeed()
		)

	func dispose() -> void:
		dispose_count += 1


class StableDependencyProviderUtility extends GFUtility:
	var dispose_count: int = 0

	func dispose() -> void:
		dispose_count += 1


class ParentShutdownDuringCleanupUtility extends GFUtility:
	var parent_architecture: GFArchitecture = null
	var parent_shutdown_result: GFArchitectureShutdownResult = null
	var parent_shutdown_done: bool = false
	var parent_disposed_during_release: bool = false
	var dispose_count: int = 0
	var release_count: int = 0

	func _init(parent: GFArchitecture) -> void:
		parent_architecture = parent

	func get_required_utilities() -> Array[Script]:
		return [StableDependencyProviderUtility]

	func dispose() -> void:
		dispose_count += 1
		@warning_ignore("missing_await")
		_capture_parent_shutdown()

	func release_dependencies() -> void:
		release_count += 1
		parent_disposed_during_release = parent_architecture.is_disposed()
		super.release_dependencies()

	func _capture_parent_shutdown() -> void:
		parent_shutdown_result = await parent_architecture.shutdown_async()
		parent_shutdown_done = true


class FailingChildActivationUtility extends GFUtility:
	func begin_activation(_scope: GFAsyncScope) -> GFAsyncCompletion:
		var completion: GFAsyncCompletion = GFAsyncCompletion.new()
		var _failed: bool = completion.fail("[test] child activation failure")
		return completion


class StableDependencyConsumerSystem extends GFSystem:
	func get_required_utilities() -> Array[Script]:
		return [StableDependencyProviderUtility]


class FactoryLeaseProduct extends RefCounted:
	pass


class FactoryLeaseConsumerSystem extends GFSystem:
	func get_required_factories() -> Array[Script]:
		return [FactoryLeaseProduct]


class MixedExternalDependencyConsumerSystem extends GFSystem:
	func get_required_utilities() -> Array[Script]:
		return [StableDependencyProviderUtility]

	func get_required_factories() -> Array[Script]:
		return [FactoryLeaseProduct]


class FactoryInvocationDuringDisposeUtility extends GFUtility:
	var child_architecture: GFArchitecture = null
	var requested_script: Script = null
	var factory_result: Object = null

	func dispose() -> void:
		if child_architecture != null and requested_script != null:
			factory_result = child_architecture.create_instance(
				requested_script
			)


class TransientFallbackProduct extends Node:
	pass


class TransientFallbackAfterOwnerDeniedFactory extends RefCounted:
	var child_architecture: GFArchitecture = null
	var nested_result_was_null: bool = false
	var rejected_instance_ref: WeakRef = null

	func _init(child: GFArchitecture) -> void:
		child_architecture = child

	func create() -> Object:
		var nested_result: Object = child_architecture.create_instance(
			FactoryLeaseProduct
		)
		nested_result_was_null = nested_result == null
		var fallback: TransientFallbackProduct = (
			TransientFallbackProduct.new()
		)
		rejected_instance_ref = weakref(fallback)
		return fallback


class FactoryLifecycleGuardProduct extends Node:
	var state: Dictionary

	func _init(shared_state: Dictionary) -> void:
		state = shared_state
		state["instance_ref"] = weakref(self)

	func dispose() -> void:
		state["dispose_count"] = (
			GFVariantData.get_option_int(state, "dispose_count")
			+ 1
		)

	func release_dependencies() -> void:
		state["release_count"] = (
			GFVariantData.get_option_int(state, "release_count")
			+ 1
		)


class DisposeOwnerDuringProvideFactory extends RefCounted:
	var architecture: GFArchitecture
	var state: Dictionary

	func _init(
		owner_architecture: GFArchitecture,
		shared_state: Dictionary
	) -> void:
		architecture = owner_architecture
		state = shared_state

	func create() -> Object:
		architecture.dispose()
		return FactoryLifecycleGuardProduct.new(state)


class DisposeRequesterDuringProvideFactory extends RefCounted:
	var owner_architecture: GFArchitecture
	var requester_architecture: GFArchitecture
	var state: Dictionary

	func _init(
		binding_owner: GFArchitecture,
		shared_state: Dictionary
	) -> void:
		owner_architecture = binding_owner
		state = shared_state

	func create() -> Object:
		if requester_architecture != null:
			requester_architecture.dispose()
		var nested_result: Object = owner_architecture.create_instance(
			LateTransientProduct
		)
		state["nested_result_was_null"] = nested_result == null
		return FactoryLifecycleGuardProduct.new(state)


class DisposeOwnerThenRequesterFactory extends RefCounted:
	var owner_architecture: GFArchitecture
	var requester_architecture: GFArchitecture
	var state: Dictionary

	func _init(
		binding_owner: GFArchitecture,
		shared_state: Dictionary
	) -> void:
		owner_architecture = binding_owner
		state = shared_state

	func create() -> Object:
		owner_architecture.dispose()
		var nested_result: Object = (
			requester_architecture.create_instance(
				LateTransientProduct
			)
			if requester_architecture != null
			else null
		)
		state["nested_result_was_null"] = nested_result == null
		return FactoryLifecycleGuardProduct.new(state)


class FactoryRequesterGuardProduct extends FactoryLifecycleGuardProduct:
	func inject_dependencies(architecture: GFArchitecture) -> void:
		state["inject_count"] = (
			GFVariantData.get_option_int(state, "inject_count")
			+ 1
		)
		architecture.dispose()


class InjectionDisposesRequesterFactory extends RefCounted:
	var state: Dictionary

	func _init(shared_state: Dictionary) -> void:
		state = shared_state

	func create() -> Object:
		return FactoryRequesterGuardProduct.new(state)


class ExternalRequesterGuardProduct extends Node:
	var state: Dictionary
	var requester_architecture: GFArchitecture
	var injected_architecture: GFArchitecture

	func _init(shared_state: Dictionary) -> void:
		state = shared_state

	func inject_dependencies(architecture: GFArchitecture) -> void:
		injected_architecture = architecture
		state["inject_count"] = (
			GFVariantData.get_option_int(state, "inject_count")
			+ 1
		)
		if requester_architecture != null:
			requester_architecture.dispose()

	func inject(_architecture: GFArchitecture) -> void:
		state["second_hook_count"] = (
			GFVariantData.get_option_int(state, "second_hook_count")
			+ 1
		)

	func dispose() -> void:
		state["dispose_count"] = (
			GFVariantData.get_option_int(state, "dispose_count")
			+ 1
		)

	func release_dependencies() -> void:
		state["release_count"] = (
			GFVariantData.get_option_int(state, "release_count")
			+ 1
		)


class QueueFreeingInjectionProduct extends Node:
	var state: Dictionary

	func _init(shared_state: Dictionary) -> void:
		state = shared_state
		state["instance_ref"] = weakref(self)

	func inject_dependencies(_architecture: GFArchitecture) -> void:
		state["inject_count"] = (
			GFVariantData.get_option_int(state, "inject_count")
			+ 1
		)
		queue_free()

	func inject(_architecture: GFArchitecture) -> void:
		state["second_hook_count"] = (
			GFVariantData.get_option_int(state, "second_hook_count")
			+ 1
		)

	func dispose() -> void:
		state["dispose_count"] = (
			GFVariantData.get_option_int(state, "dispose_count")
			+ 1
		)


class QueueFreeingInjectionFactory extends RefCounted:
	var state: Dictionary

	func _init(shared_state: Dictionary) -> void:
		state = shared_state

	func create() -> Object:
		return QueueFreeingInjectionProduct.new(state)


class NestedLifecycleGuardProduct extends RefCounted:
	var state: Dictionary

	func _init(shared_state: Dictionary) -> void:
		state = shared_state

	func dispose() -> void:
		state["dispose_count"] = (
			GFVariantData.get_option_int(state, "dispose_count")
			+ 1
		)

	func release_dependencies() -> void:
		state["release_count"] = (
			GFVariantData.get_option_int(state, "release_count")
			+ 1
		)


class NestedLifecycleGuardFactory extends RefCounted:
	var state: Dictionary

	func _init(shared_state: Dictionary) -> void:
		state = shared_state

	func create() -> Object:
		return NestedLifecycleGuardProduct.new(state)


class DisposeOwnerAfterNestedSingletonFactory extends RefCounted:
	var architecture: GFArchitecture
	var state: Dictionary

	func _init(
		owner_architecture: GFArchitecture,
		shared_state: Dictionary
	) -> void:
		architecture = owner_architecture
		state = shared_state

	func create() -> Object:
		var nested_result: Object = architecture.create_instance(
			NestedLifecycleGuardProduct
		)
		if nested_result == null:
			return null
		architecture.dispose()
		return FactoryLifecycleGuardProduct.new(state)


class ChildEventFailureProduct extends Node:
	const EVENT_ID: StringName = &"gf.test.factory.child_scope"

	var state: Dictionary

	func _init(shared_state: Dictionary) -> void:
		state = shared_state
		state["instance_ref"] = weakref(self)

	func _gf_set_dependency_scope(scope: GFArchitecture) -> void:
		if scope == null:
			state["scope_clear_count"] = (
				GFVariantData.get_option_int(
					state,
					"scope_clear_count"
				)
				+ 1
			)
			return
		state["scope_bind_count"] = (
			GFVariantData.get_option_int(state, "scope_bind_count")
			+ 1
		)

	func inject_dependencies(architecture: GFArchitecture) -> void:
		var listener: GFEventListener = GFEventListener.from_callable(
			Callable(self, &"_on_event"),
			1
		)
		architecture.register_simple_event_owned(
			self,
			EVENT_ID,
			listener
		)
		state["registered_listener_count"] = (
			GFVariantData.get_option_int(
				architecture.get_event_debug_stats(),
				"listener_count"
			)
		)
		var _nested_result: Object = architecture.create_instance(
			ReentrantTopologyProduct
		)

	func inject(_architecture: GFArchitecture) -> void:
		state["second_hook_count"] = (
			GFVariantData.get_option_int(state, "second_hook_count")
			+ 1
		)

	func dispose() -> void:
		state["dispose_count"] = (
			GFVariantData.get_option_int(state, "dispose_count")
			+ 1
		)

	func release_dependencies() -> void:
		state["release_count"] = (
			GFVariantData.get_option_int(state, "release_count")
			+ 1
		)
		queue_free()

	func _on_event(_payload: Variant) -> void:
		pass


class ChildEventFailureFactory extends RefCounted:
	var state: Dictionary

	func _init(shared_state: Dictionary) -> void:
		state = shared_state

	func create() -> Object:
		return ChildEventFailureProduct.new(state)


class ReentrantTopologyProduct extends RefCounted:
	pass


class LateTransientProduct extends Node:
	var state: Dictionary

	func _init(shared_state: Dictionary) -> void:
		state = shared_state
		state["instance_ref"] = weakref(self)

	func inject_dependencies(_architecture: GFArchitecture) -> void:
		state["inject_count"] = (
			GFVariantData.get_option_int(state, "inject_count")
			+ 1
		)


class LateTransientFactory extends RefCounted:
	var state: Dictionary

	func _init(shared_state: Dictionary) -> void:
		state = shared_state

	func create() -> Object:
		state["provider_count"] = (
			GFVariantData.get_option_int(state, "provider_count")
			+ 1
		)
		return LateTransientProduct.new(state)


class CachedResolutionGuardProduct extends RefCounted:
	pass


class CachedResolutionGuardFactory extends RefCounted:
	var state: Dictionary

	func _init(shared_state: Dictionary) -> void:
		state = shared_state

	func create() -> Object:
		state["provider_count"] = (
			GFVariantData.get_option_int(state, "provider_count")
			+ 1
		)
		return CachedResolutionGuardProduct.new()


class TransferredTransientProduct extends Node:
	var state: Dictionary

	func _init(shared_state: Dictionary) -> void:
		state = shared_state

	func inject_dependencies(_architecture: GFArchitecture) -> void:
		state["inject_count"] = (
			GFVariantData.get_option_int(state, "inject_count")
			+ 1
		)

	func dispose() -> void:
		state["dispose_count"] = (
			GFVariantData.get_option_int(state, "dispose_count")
			+ 1
		)

	func release_dependencies() -> void:
		state["release_count"] = (
			GFVariantData.get_option_int(state, "release_count")
			+ 1
		)


class TransferredTransientFactory extends RefCounted:
	var state: Dictionary

	func _init(shared_state: Dictionary) -> void:
		state = shared_state

	func create() -> Object:
		state["provider_count"] = (
			GFVariantData.get_option_int(state, "provider_count")
			+ 1
		)
		return TransferredTransientProduct.new(state)


class FailureAfterTransientTransferFactory extends RefCounted:
	var architecture: GFArchitecture
	var state: Dictionary
	var transferred_instance: TransferredTransientProduct

	func _init(
		binding_owner: GFArchitecture,
		shared_state: Dictionary
	) -> void:
		architecture = binding_owner
		state = shared_state

	func create() -> Object:
		transferred_instance = architecture.create_instance(
			TransferredTransientProduct
		) as TransferredTransientProduct
		var nested_factory: Callable = func() -> Object:
			return ReentrantTopologyProduct.new()
		var _mutation_result: bool = architecture.register_factory(
			ReentrantTopologyProduct,
			nested_factory
		)
		return FactoryLifecycleGuardProduct.new(state)


class ReentrantTopologyFactory extends RefCounted:
	var architecture: GFArchitecture
	var state: Dictionary

	func _init(
		owner_architecture: GFArchitecture,
		shared_state: Dictionary
	) -> void:
		architecture = owner_architecture
		state = shared_state

	func create() -> Object:
		var nested_factory: Callable = func() -> Object:
			return ReentrantTopologyProduct.new()
		state["mutation_result"] = architecture.register_factory(
			ReentrantTopologyProduct,
			nested_factory
		)
		var nested_result: Object = architecture.create_instance(
			LateTransientProduct
		)
		state["nested_result_was_null"] = nested_result == null
		var cached_result: Object = architecture.create_instance(
			CachedResolutionGuardProduct
		)
		state["cached_result_was_null"] = cached_result == null
		return FactoryLifecycleGuardProduct.new(state)


class ExternalLeaseActivationConsumerSystem extends GFSystem:
	enum ActivationMode {
		PENDING,
		FAIL,
	}

	var activation_mode: ActivationMode = ActivationMode.PENDING
	var activation_completion: GFAsyncCompletion = null

	func _init(mode: ActivationMode) -> void:
		activation_mode = mode

	func get_required_utilities() -> Array[Script]:
		return [StableDependencyProviderUtility]

	func begin_activation(_scope: GFAsyncScope) -> GFAsyncCompletion:
		activation_completion = GFAsyncCompletion.new()
		if activation_mode == ActivationMode.FAIL:
			var _failed: bool = activation_completion.fail(
				"[test] child activation rejected"
			)
		return activation_completion


class FallbackProviderUtility extends GFUtility:
	var dispose_count: int = 0

	func dispose() -> void:
		dispose_count += 1


class AlternateFallbackProviderUtility extends FallbackProviderUtility:
	pass


class FallbackConsumerSystem extends GFSystem:
	func get_required_utilities() -> Array[Script]:
		return [FallbackProviderUtility]


class DriftPrimaryProviderUtility extends GFUtility:
	pass


class DriftAlternateProviderUtility extends GFUtility:
	pass


class DriftingDependencyConsumerSystem extends GFSystem:
	var use_alternate: bool = false

	func get_required_utilities() -> Array[Script]:
		if use_alternate:
			return [DriftAlternateProviderUtility]
		return [DriftPrimaryProviderUtility]


class UnrelatedHotUtility extends GFUtility:
	var inject_count: int = 0
	var dispose_count: int = 0

	func inject_dependencies(architecture: GFArchitecture) -> void:
		inject_count += 1
		super.inject_dependencies(architecture)

	func dispose() -> void:
		dispose_count += 1


class DisposeDuringInjectionUtility extends GFUtility:
	var dependencies_released: bool = false
	var init_count: int = 0
	var async_init_count: int = 0
	var ready_count: int = 0
	var activation_count: int = 0
	var dispose_count: int = 0

	func inject_dependencies(architecture: GFArchitecture) -> void:
		super.inject_dependencies(architecture)
		architecture.dispose()

	func init() -> void:
		init_count += 1

	func async_init(_scope: GFAsyncScope) -> void:
		async_init_count += 1

	func ready() -> void:
		ready_count += 1

	func begin_activation(_scope: GFAsyncScope) -> GFAsyncCompletion:
		activation_count += 1
		var completion: GFAsyncCompletion = GFAsyncCompletion.new()
		var _succeeded: bool = completion.succeed()
		return completion

	func dispose() -> void:
		dispose_count += 1

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


class DetachedDisposeReentryUtility extends GFUtility:
	enum Reentry {
		NONE,
		FAIL_INITIALIZATION,
		DISPOSE_ARCHITECTURE,
	}

	var reentry: Reentry = Reentry.NONE
	var injected_architecture: GFArchitecture = null
	var dispose_count: int = 0

	func _init(reentry_mode: Reentry = Reentry.NONE) -> void:
		reentry = reentry_mode

	func inject_dependencies(architecture: GFArchitecture) -> void:
		super.inject_dependencies(architecture)
		injected_architecture = architecture

	func dispose() -> void:
		dispose_count += 1
		if dispose_count != 1 or injected_architecture == null:
			return
		match reentry:
			Reentry.FAIL_INITIALIZATION:
				injected_architecture.fail_initialization(
					"[test] detached previous dispose failure"
				)
			Reentry.DISPOSE_ARCHITECTURE:
				injected_architecture.dispose()


class ReadyInvalidatingUtility extends GFUtility:
	var injected_architecture: GFArchitecture = null
	var inject_count: int = 0
	var init_count: int = 0
	var async_init_count: int = 0
	var ready_count: int = 0
	var activation_count: int = 0
	var dispose_count: int = 0

	func inject_dependencies(architecture: GFArchitecture) -> void:
		inject_count += 1
		super.inject_dependencies(architecture)
		injected_architecture = architecture

	func init() -> void:
		init_count += 1

	func async_init(_scope: GFAsyncScope) -> void:
		async_init_count += 1

	func ready() -> void:
		ready_count += 1
		if injected_architecture != null:
			injected_architecture.fail_initialization(
				"[test] fail during hot candidate ready"
			)

	func begin_activation(_scope: GFAsyncScope) -> GFAsyncCompletion:
		activation_count += 1
		var completion: GFAsyncCompletion = GFAsyncCompletion.new()
		var _succeeded: bool = completion.succeed()
		return completion

	func dispose() -> void:
		dispose_count += 1


class PlanHookInvalidatingUtility extends GFUtility:
	enum Invalidation {
		DISPOSE,
		FAIL,
	}

	var architecture: GFArchitecture = null
	var invalidation: Invalidation = Invalidation.DISPOSE
	var model_hook_count: int = 0
	var system_hook_count: int = 0
	var utility_hook_count: int = 0
	var factory_hook_count: int = 0
	var inject_count: int = 0
	var init_count: int = 0
	var async_init_count: int = 0
	var ready_count: int = 0
	var activation_count: int = 0
	var dispose_count: int = 0

	func _init(
		target_architecture: GFArchitecture,
		invalidation_mode: Invalidation
	) -> void:
		architecture = target_architecture
		invalidation = invalidation_mode

	func get_required_models() -> Array[Script]:
		model_hook_count += 1
		if architecture != null:
			match invalidation:
				Invalidation.DISPOSE:
					architecture.dispose()
				Invalidation.FAIL:
					architecture.fail_initialization(
						"[test] fail during lifecycle plan hook"
					)
		return []

	func get_required_systems() -> Array[Script]:
		system_hook_count += 1
		return []

	func get_required_utilities() -> Array[Script]:
		utility_hook_count += 1
		return []

	func get_required_factories() -> Array[Script]:
		factory_hook_count += 1
		return []

	func inject_dependencies(target_architecture: GFArchitecture) -> void:
		inject_count += 1
		super.inject_dependencies(target_architecture)

	func init() -> void:
		init_count += 1

	func async_init(_scope: GFAsyncScope) -> void:
		async_init_count += 1

	func ready() -> void:
		ready_count += 1

	func begin_activation(_scope: GFAsyncScope) -> GFAsyncCompletion:
		activation_count += 1
		var completion: GFAsyncCompletion = GFAsyncCompletion.new()
		var _succeeded: bool = completion.succeed()
		return completion

	func dispose() -> void:
		dispose_count += 1


class DeadlineCrossingActivationUtility extends GFUtility:
	var block_msec: int = 0
	var activation_count: int = 0
	var dispose_count: int = 0

	func _init(block_duration_msec: int) -> void:
		block_msec = block_duration_msec

	func begin_activation(_scope: GFAsyncScope) -> GFAsyncCompletion:
		activation_count += 1
		var release_at_msec: int = Time.get_ticks_msec() + block_msec
		while Time.get_ticks_msec() < release_at_msec:
			pass
		var completion: GFAsyncCompletion = GFAsyncCompletion.new()
		var _succeeded: bool = completion.succeed()
		return completion

	func dispose() -> void:
		dispose_count += 1


class DeadlineCrossingTopologyQuiesceUtility extends GFUtility:
	var block_msec: int = 0
	var quiesce_count: int = 0
	var dispose_count: int = 0

	func _init(block_duration_msec: int) -> void:
		block_msec = block_duration_msec

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
			var _unregister_result: Variant = (
				Callable(
					injected_architecture,
					&"unregister_utility"
				).call(ReadyReentrantReplacementUtility)
			)

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
