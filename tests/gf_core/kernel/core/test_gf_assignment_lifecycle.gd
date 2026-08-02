## 测试 Gf 架构赋值的取消、提交与重入语义。
extends GutTest


# --- 常量 ---

const GF_AUTOLOAD_NODE_SCRIPT = preload("res://addons/gf/kernel/core/gf.gd")
const GF_ASYNC_CALL_SCRIPT = preload("res://addons/gf/kernel/core/gf_async_call.gd")
const INSTALLERS_SETTING: String = "gf/project/installers"
const INSTALLER_TIMEOUT_SETTING: String = "gf/project/installer_timeout_seconds"
const FACADE_INSTALLER_PATH: String = "res://tests/gf_core/fixtures/installers/gf_facade_installer.gd"
const OBSERVED_COMMITTED_ARCHITECTURE_SETTING: String = "gf/test/facade_installer_observed_committed_architecture"
const WAIT_FOR_RELEASE_SETTING: String = "gf/test/facade_installer_wait_for_release"
const STARTED_SETTING: String = "gf/test/facade_installer_started"
const RELEASE_SETTING: String = "gf/test/facade_installer_release"
const CANCELLED_SETTING: String = "gf/test/facade_installer_cancelled"
const CLEANUP_SETTING: String = "gf/test/facade_installer_cleanup"


# --- 辅助类 ---

class ReentrantAssignmentUtility extends GFUtility:
	var assignment_callback: Callable

	func dispose() -> void:
		if assignment_callback.is_valid():
			GF_ASYNC_CALL_SCRIPT.run_detached(assignment_callback)


class ReentrantCreateUtility extends GFUtility:
	var facade: GF_AUTOLOAD_NODE_SCRIPT
	var observed_state: Dictionary

	func dispose() -> void:
		observed_state["architecture"] = facade.create_architecture()


class CancelFacadeAssignmentUtility extends GFUtility:
	var facade: GF_AUTOLOAD_NODE_SCRIPT

	func async_init(_scope: GFAsyncScope) -> void:
		var assignment_scope: GFAsyncScope = facade._pending_architecture_assignment_scope
		if assignment_scope != null:
			var _cancelled_assignment: bool = assignment_scope.cancel(
				"[test] installer-owned assignment scope cancelled during candidate init"
			)


class DisposeReentrantSetArchitecture extends GFArchitecture:
	var facade: GF_AUTOLOAD_NODE_SCRIPT
	var reentrant_set_result: bool = true

	func _on_dispose() -> void:
		var raw_set_result: Variant = facade.call(&"set_architecture", self)
		reentrant_set_result = GFVariantData.to_bool(raw_set_result)


class BlockingActivationUtility extends GFUtility:
	var activation_started: bool = false
	var activation_completion: GFAsyncCompletion = null
	var dispose_call_count: int = 0

	func begin_activation(_scope: GFAsyncScope) -> GFAsyncCompletion:
		activation_started = true
		activation_completion = GFAsyncCompletion.new()
		return activation_completion

	func dispose() -> void:
		dispose_call_count += 1

	func complete_activation() -> void:
		if activation_completion != null:
			var _completed: bool = activation_completion.succeed()


class BlockingQuiesceUtility extends GFUtility:
	var quiesce_started: bool = false
	var quiesce_completion: GFAsyncCompletion = null
	var dispose_call_count: int = 0

	func begin_quiesce(_scope: GFAsyncScope) -> GFAsyncCompletion:
		quiesce_started = true
		quiesce_completion = GFAsyncCompletion.new()
		return quiesce_completion

	func dispose() -> void:
		dispose_call_count += 1

	func complete_quiesce() -> void:
		if quiesce_completion != null:
			var _completed: bool = quiesce_completion.succeed()


class FailingQuiesceUtility extends GFUtility:
	var dispose_call_count: int = 0

	func begin_quiesce(_scope: GFAsyncScope) -> GFAsyncCompletion:
		var completion: GFAsyncCompletion = GFAsyncCompletion.new()
		var _failed: bool = completion.fail("[test] old architecture quiesce failed")
		return completion

	func dispose() -> void:
		dispose_call_count += 1


class ExternalLeaseProviderUtility extends GFUtility:
	var dispose_call_count: int = 0

	func dispose() -> void:
		dispose_call_count += 1


class ExternalLeaseConsumerSystem extends GFSystem:
	func get_required_utilities() -> Array[Script]:
		return [ExternalLeaseProviderUtility]


# --- Godot 生命周期方法 ---

func before_each() -> void:
	_clear_test_settings()
	ProjectSettings.set_setting(INSTALLERS_SETTING, [])
	ProjectSettings.set_setting(INSTALLER_TIMEOUT_SETTING, 0.0)


func after_each() -> void:
	_clear_test_settings()
	ProjectSettings.set_setting(INSTALLERS_SETTING, [])
	ProjectSettings.set_setting(INSTALLER_TIMEOUT_SETTING, 0.0)


# --- 测试用例 ---

func test_candidate_is_not_published_before_stage_four_activation_completes() -> void:
	var facade: GF_AUTOLOAD_NODE_SCRIPT = GF_AUTOLOAD_NODE_SCRIPT.new()
	var candidate: GFArchitecture = GFArchitecture.new()
	var activation_utility: BlockingActivationUtility = BlockingActivationUtility.new()
	var assignment_state: Dictionary = {
		"done": false,
		"result": false,
	}
	assert_true(
		await candidate.register_utility_instance(activation_utility),
		"测试 activation Utility 应成功注册到 candidate。"
	)

	GF_ASYNC_CALL_SCRIPT.run_detached(
		Callable(self, &"_capture_assignment_result"),
		[facade, candidate, assignment_state]
	)
	assert_true(
		await _wait_for_activation_start(activation_utility),
		"candidate 应进入第四阶段 activation。"
	)

	assert_false(facade.has_architecture(), "activation 完成前 candidate 不得发布。")
	assert_false(
		GFVariantData.get_option_bool(assignment_state, "done"),
		"activation 完成前 assignment 不得提前返回。"
	)
	assert_true(candidate.is_activating(), "candidate 应保持 ACTIVATING 状态。")

	activation_utility.complete_activation()
	assert_true(
		await _wait_for_result(assignment_state),
		"activation 完成后 assignment 应有界返回。"
	)

	assert_true(
		GFVariantData.get_option_bool(assignment_state, "result"),
		"完整第四阶段成功后 candidate 应提交。"
	)
	assert_true(candidate.is_inited(), "已提交 candidate 必须处于 READY。")
	assert_same(facade.get_architecture(), candidate, "最终 identity 应为已激活 candidate。")

	facade._exit_tree()
	facade.free()


func test_replacement_waits_for_old_architecture_shutdown_before_publish() -> void:
	var facade: GF_AUTOLOAD_NODE_SCRIPT = GF_AUTOLOAD_NODE_SCRIPT.new()
	var previous_architecture: GFArchitecture = GFArchitecture.new()
	var quiesce_utility: BlockingQuiesceUtility = BlockingQuiesceUtility.new()
	var candidate: GFArchitecture = GFArchitecture.new()
	var assignment_state: Dictionary = {
		"done": false,
		"result": false,
	}
	assert_true(
		await previous_architecture.register_utility_instance(quiesce_utility),
		"测试 quiesce Utility 应成功注册到旧架构。"
	)
	assert_true(
		await facade.set_architecture(previous_architecture),
		"旧架构应先完成提交。"
	)

	GF_ASYNC_CALL_SCRIPT.run_detached(
		Callable(self, &"_capture_assignment_result"),
		[facade, candidate, assignment_state]
	)
	assert_true(
		await _wait_for_quiesce_start(quiesce_utility),
		"replacement 应先进入旧架构 quiesce。"
	)

	assert_true(candidate.is_inited(), "candidate 应先完成第四阶段再关闭旧架构。")
	assert_false(
		facade.has_architecture(),
		"QUIESCING 旧架构不得继续作为可获取的全局 identity。"
	)
	assert_false(
		GFVariantData.get_option_bool(assignment_state, "done"),
		"旧架构 shutdown 完成前 replacement 不得发布。"
	)

	quiesce_utility.complete_quiesce()
	assert_true(
		await _wait_for_result(assignment_state),
		"旧架构完成 quiesce 后 replacement 应有界返回。"
	)

	assert_true(
		GFVariantData.get_option_bool(assignment_state, "result"),
		"成功 shutdown 后 replacement 应提交。"
	)
	assert_true(previous_architecture.is_disposed(), "旧架构必须进入 DISPOSED。")
	assert_eq(quiesce_utility.dispose_call_count, 1, "旧模块必须恰好 dispose 一次。")
	assert_same(facade.get_architecture(), candidate, "candidate 应成为唯一全局 identity。")

	facade._exit_tree()
	facade.free()


func test_failed_old_shutdown_rejects_and_cleans_unpublished_candidate() -> void:
	var facade: GF_AUTOLOAD_NODE_SCRIPT = GF_AUTOLOAD_NODE_SCRIPT.new()
	var previous_architecture: GFArchitecture = GFArchitecture.new()
	var failing_utility: FailingQuiesceUtility = FailingQuiesceUtility.new()
	var candidate: GFArchitecture = GFArchitecture.new()
	assert_true(
		await previous_architecture.register_utility_instance(failing_utility),
		"失败 quiesce Utility 应成功注册到旧架构。"
	)
	assert_true(
		await facade.set_architecture(previous_architecture),
		"旧架构应先完成提交。"
	)
	watch_signals(facade)

	var assignment_result: bool = await facade.set_architecture(candidate)
	await get_tree().process_frame

	assert_false(assignment_result, "typed shutdown 失败必须拒绝 replacement。")
	assert_true(previous_architecture.is_disposed(), "失败 shutdown 仍必须终结旧架构。")
	assert_eq(failing_utility.dispose_call_count, 1, "失败 shutdown 也必须恰好 dispose 一次。")
	assert_true(candidate.is_disposed(), "未发布 candidate 必须被强制清理。")
	assert_false(facade.has_architecture(), "失败 replacement 后不得持有 terminal 旧 identity。")
	assert_null(facade._architecture, "失败 replacement 后全局 identity 必须清空。")
	var shutdown_result: GFArchitectureShutdownResult = (
		previous_architecture.get_last_shutdown_result()
	)
	assert_not_null(shutdown_result, "旧架构必须保留 typed shutdown 结果。")
	if shutdown_result != null:
		assert_eq(
			shutdown_result.get_status(),
			GFArchitectureShutdownResult.Status.FAILED,
			"quiesce 失败必须保留 FAILED 终态。"
		)
	assert_signal_emitted(
		facade,
		"architecture_identity_changed",
		"terminal 旧 identity 被清理时必须发布身份变化。"
	)

	facade._exit_tree()
	facade.free()


func test_busy_old_shutdown_preserves_committed_identity_for_retry() -> void:
	var facade: GF_AUTOLOAD_NODE_SCRIPT = GF_AUTOLOAD_NODE_SCRIPT.new()
	var previous_architecture: GFArchitecture = GFArchitecture.new()
	var provider: ExternalLeaseProviderUtility = ExternalLeaseProviderUtility.new()
	assert_true(
		await previous_architecture.register_utility_instance(provider),
		"父架构的外部依赖 provider 应成功注册。"
	)
	assert_true(
		await facade.set_architecture(previous_architecture),
		"父架构应先完成 facade 提交。"
	)
	var child_architecture: GFArchitecture = GFArchitecture.new(previous_architecture)
	assert_true(
		await child_architecture.register_system_instance(
			ExternalLeaseConsumerSystem.new()
		),
		"child 的外部依赖 consumer 应成功注册。"
	)
	assert_true(await child_architecture.init(), "child 应取得父架构外部依赖租约。")
	var rejected_candidate: GFArchitecture = GFArchitecture.new()
	watch_signals(facade)

	var rejected_result: bool = await facade.set_architecture(rejected_candidate)

	assert_false(rejected_result, "活动 child 租约应拒绝 facade replacement。")
	assert_true(rejected_candidate.is_disposed(), "被拒绝的未发布 candidate 应完成释放。")
	assert_true(previous_architecture.is_inited(), "ERR_BUSY 不得终结既有父架构。")
	assert_true(
		previous_architecture.is_accepting_runtime_work(),
		"ERR_BUSY 不得关闭既有父架构的工作准入。"
	)
	assert_false(previous_architecture.is_disposed(), "ERR_BUSY 不得强制 dispose 父架构。")
	assert_true(facade.has_architecture(), "可重试失败后 facade 应保留可用 identity。")
	assert_same(
		facade.get_architecture(),
		previous_architecture,
		"可重试失败不得清除或替换已提交 identity。"
	)
	assert_signal_not_emitted(
		facade,
		"architecture_identity_changed",
		"未改变 identity 的 ERR_BUSY replacement 不得发布身份变化。"
	)

	var child_shutdown: GFArchitectureShutdownResult = (
		await child_architecture.shutdown_async()
	)
	assert_true(child_shutdown.is_successful(), "child 关闭后应释放父架构租约。")
	var retry_candidate: GFArchitecture = GFArchitecture.new()
	assert_true(
		await facade.set_architecture(retry_candidate),
		"child 释放租约后，使用新 candidate 重试 replacement 应成功。"
	)
	assert_true(previous_architecture.is_disposed(), "成功重试应正常终结旧父架构。")
	assert_eq(provider.dispose_call_count, 1, "父级 provider 必须且只应释放一次。")
	assert_same(facade.get_architecture(), retry_candidate, "重试 candidate 应成为最终 identity。")

	facade._exit_tree()
	facade.free()


func test_newer_replacement_owns_commit_after_shared_old_shutdown() -> void:
	var facade: GF_AUTOLOAD_NODE_SCRIPT = GF_AUTOLOAD_NODE_SCRIPT.new()
	var previous_architecture: GFArchitecture = GFArchitecture.new()
	var quiesce_utility: BlockingQuiesceUtility = BlockingQuiesceUtility.new()
	var intermediate_candidate: GFArchitecture = GFArchitecture.new()
	var latest_candidate: GFArchitecture = GFArchitecture.new()
	var intermediate_state: Dictionary = {
		"done": false,
		"result": true,
	}
	var latest_state: Dictionary = {
		"done": false,
		"result": false,
	}
	assert_true(
		await previous_architecture.register_utility_instance(quiesce_utility),
		"测试 quiesce Utility 应成功注册到旧架构。"
	)
	assert_true(
		await facade.set_architecture(previous_architecture),
		"旧架构应先完成提交。"
	)

	GF_ASYNC_CALL_SCRIPT.run_detached(
		Callable(self, &"_capture_assignment_result"),
		[facade, intermediate_candidate, intermediate_state]
	)
	assert_true(
		await _wait_for_quiesce_start(quiesce_utility),
		"首个 replacement 应进入旧架构 quiesce。"
	)
	GF_ASYNC_CALL_SCRIPT.run_detached(
		Callable(self, &"_capture_assignment_result"),
		[facade, latest_candidate, latest_state]
	)
	await get_tree().process_frame

	assert_true(
		intermediate_candidate.is_disposed(),
		"更新 replacement 必须立即清理失去提交权的 candidate。"
	)
	assert_false(
		GFVariantData.get_option_bool(intermediate_state, "done"),
		"旧 shutdown 返回前陈旧 continuation 可以等待，但不得拥有提交权。"
	)

	quiesce_utility.complete_quiesce()
	assert_true(
		await _wait_for_result(intermediate_state),
		"陈旧 replacement 应在共享 shutdown 完成后有界返回。"
	)
	assert_true(
		await _wait_for_result(latest_state),
		"最新 replacement 应在共享 shutdown 完成后有界返回。"
	)

	assert_false(
		GFVariantData.get_option_bool(intermediate_state, "result"),
		"陈旧 replacement 的迟到写回必须被 serial 门禁拒绝。"
	)
	assert_true(
		GFVariantData.get_option_bool(latest_state, "result"),
		"最新 replacement 应保留唯一提交权。"
	)
	assert_same(
		facade.get_architecture(),
		latest_candidate,
		"共享 shutdown 完成后不得由陈旧 continuation 覆盖最新 identity。"
	)

	facade._exit_tree()
	facade.free()


## 验证新赋值会取消尚未提交的 Installer scope，且旧 candidate 不会迟到提交。
func test_replacement_cancels_pending_assignment_scope() -> void:
	var facade: GF_AUTOLOAD_NODE_SCRIPT = GF_AUTOLOAD_NODE_SCRIPT.new()
	var pending_architecture: GFArchitecture = GFArchitecture.new()
	var replacement_architecture: GFArchitecture = GFArchitecture.new()
	var pending_result: Dictionary = {
		"done": false,
		"result": false,
	}
	ProjectSettings.set_setting(INSTALLERS_SETTING, [FACADE_INSTALLER_PATH])
	ProjectSettings.set_setting(WAIT_FOR_RELEASE_SETTING, true)
	GF_ASYNC_CALL_SCRIPT.run_detached(
		Callable(self, &"_capture_assignment_result"),
		[facade, pending_architecture, pending_result]
	)
	assert_true(
		await _wait_for_project_setting(STARTED_SETTING),
		"pending assignment 的 Installer 应在替换前进入等待点。"
	)

	ProjectSettings.set_setting(INSTALLERS_SETTING, [])
	var replacement_result: bool = await facade.set_architecture(replacement_architecture)
	await get_tree().process_frame
	var cancellation_observed: bool = _project_setting_bool(CANCELLED_SETTING)
	var cleanup_observed: bool = _project_setting_bool(CLEANUP_SETTING)

	ProjectSettings.set_setting(RELEASE_SETTING, true)
	assert_true(
		await _wait_for_result(pending_result),
		"被替代的 assignment 协程必须在有界帧数内返回。"
	)

	assert_true(replacement_result, "较新的架构赋值应成功提交。")
	assert_false(GFVariantData.to_bool(pending_result.get("result", true)), "被替代的赋值应返回 false。")
	assert_true(cancellation_observed, "被替代赋值的 Installer scope 应收到取消。")
	assert_true(cleanup_observed, "取消 pending assignment 时应执行 scope cleanup。")
	assert_same(facade.get_architecture(), replacement_architecture, "迟到完成的旧赋值不得覆盖最新架构。")

	facade._exit_tree()
	facade.free()


## 验证同一 candidate 的并发重复赋值会被明确拒绝，且不会取消或 dispose 首个 assignment。
func test_concurrent_same_candidate_assignment_preserves_original_scope() -> void:
	var facade: GF_AUTOLOAD_NODE_SCRIPT = GF_AUTOLOAD_NODE_SCRIPT.new()
	var pending_architecture: GFArchitecture = GFArchitecture.new()
	var original_result: Dictionary = {
		"done": false,
		"result": false,
	}
	var duplicate_result: Dictionary = {
		"done": false,
		"result": true,
	}
	ProjectSettings.set_setting(INSTALLERS_SETTING, [FACADE_INSTALLER_PATH])
	ProjectSettings.set_setting(WAIT_FOR_RELEASE_SETTING, true)
	GF_ASYNC_CALL_SCRIPT.run_detached(
		Callable(self, &"_capture_assignment_result"),
		[facade, pending_architecture, original_result]
	)
	assert_true(
		await _wait_for_project_setting(STARTED_SETTING),
		"首个 assignment 的 Installer 应在重复赋值前进入等待点。"
	)

	GF_ASYNC_CALL_SCRIPT.run_detached(
		Callable(self, &"_capture_assignment_result"),
		[facade, pending_architecture, duplicate_result]
	)
	assert_true(
		await _wait_for_result(duplicate_result, 3),
		"同一 candidate 的并发重复赋值应立即被拒绝。"
	)
	assert_false(
		GFVariantData.to_bool(duplicate_result.get("result", true)),
		"同一 candidate 的并发重复赋值应返回 false。"
	)
	assert_false(
		_project_setting_bool(CANCELLED_SETTING),
		"拒绝重复赋值不得取消首个 assignment scope。"
	)
	assert_false(
		_project_setting_bool(CLEANUP_SETTING),
		"拒绝重复赋值不得提前执行首个 assignment cleanup。"
	)

	ProjectSettings.set_setting(RELEASE_SETTING, true)
	assert_true(
		await _wait_for_result(original_result),
		"首个 assignment 必须在释放 Installer 后有界完成。"
	)
	assert_true(
		GFVariantData.to_bool(original_result.get("result", false)),
		"重复赋值不得破坏首个 assignment 的成功提交。"
	)
	assert_true(facade.has_architecture(), "首个 assignment 应保留最终提交权。")
	if facade.has_architecture():
		assert_same(
			facade.get_architecture(),
			pending_architecture,
			"最终提交的架构应是共享的 candidate。"
		)
	assert_false(
		_project_setting_bool(CANCELLED_SETTING),
		"首个 assignment 成功完成时 scope 不应收到取消。"
	)
	assert_false(
		_project_setting_bool(CLEANUP_SETTING),
		"首个 assignment 成功完成时不应执行取消 cleanup。"
	)

	facade._exit_tree()
	facade.free()


func test_quiescing_candidate_cannot_steal_pending_assignment() -> void:
	var facade: GF_AUTOLOAD_NODE_SCRIPT = GF_AUTOLOAD_NODE_SCRIPT.new()
	var quiescing_candidate: GFArchitecture = GFArchitecture.new()
	var quiesce_utility: BlockingQuiesceUtility = BlockingQuiesceUtility.new()
	assert_true(
		await quiescing_candidate.register_utility_instance(quiesce_utility),
		"quiescing candidate 的测试 Utility 应成功注册。"
	)
	assert_true(await quiescing_candidate.init(), "测试 candidate 应先进入 READY。")
	var shutdown_state: Dictionary = {
		"done": false,
		"result": null,
	}
	GF_ASYNC_CALL_SCRIPT.run_detached(
		Callable(self, &"_capture_shutdown_result"),
		[quiescing_candidate, shutdown_state]
	)
	assert_true(
		await _wait_for_quiesce_start(quiesce_utility),
		"测试 candidate 应进入 QUIESCING。"
	)

	var pending_candidate: GFArchitecture = GFArchitecture.new()
	var activation_utility: BlockingActivationUtility = BlockingActivationUtility.new()
	assert_true(
		await pending_candidate.register_utility_instance(activation_utility),
		"合法 pending candidate 的测试 Utility 应成功注册。"
	)
	var pending_state: Dictionary = {
		"done": false,
		"result": false,
	}
	GF_ASYNC_CALL_SCRIPT.run_detached(
		Callable(self, &"_capture_assignment_result"),
		[facade, pending_candidate, pending_state]
	)
	assert_true(
		await _wait_for_activation_start(activation_utility),
		"合法 candidate 应先停在 activation pending。"
	)
	var pending_scope: GFAsyncScope = facade._pending_architecture_assignment_scope
	var pending_serial: int = facade._architecture_assignment_serial

	var rejected_result: bool = await facade.set_architecture(quiescing_candidate)

	assert_false(rejected_result, "QUIESCING candidate 必须在进入赋值事务前被拒绝。")
	assert_eq(
		facade._architecture_assignment_serial,
		pending_serial,
		"拒绝 QUIESCING candidate 不得推进 assignment serial。"
	)
	assert_same(
		facade._pending_architecture_assignment,
		pending_candidate,
		"拒绝 QUIESCING candidate 不得抢占合法 pending 槽。"
	)
	assert_same(
		facade._pending_architecture_assignment_scope,
		pending_scope,
		"拒绝 QUIESCING candidate 不得替换合法 pending scope。"
	)
	assert_true(pending_scope.is_active(), "合法 pending scope 不得被取消。")
	assert_false(pending_candidate.is_disposed(), "合法 pending candidate 不得被清理。")
	assert_true(quiescing_candidate.is_quiescing(), "入口拒绝不得强制终结外部 candidate。")

	activation_utility.complete_activation()
	assert_true(
		await _wait_for_result(pending_state),
		"合法 pending assignment 应在 activation 完成后有界返回。"
	)
	assert_true(
		GFVariantData.get_option_bool(pending_state, "result"),
		"被非法 candidate 竞争后，原 assignment 仍应成功提交。"
	)
	assert_same(facade.get_architecture(), pending_candidate, "合法 candidate 应保留提交权。")

	quiesce_utility.complete_quiesce()
	assert_true(
		await _wait_for_result(shutdown_state),
		"外部 quiescing candidate 应能独立完成 shutdown。"
	)
	var raw_shutdown_result: Variant = shutdown_state.get("result")
	assert_true(
		raw_shutdown_result is GFArchitectureShutdownResult,
		"外部 shutdown 应返回 typed 结果。"
	)
	if raw_shutdown_result is GFArchitectureShutdownResult:
		var shutdown_result: GFArchitectureShutdownResult = raw_shutdown_result
		assert_true(shutdown_result.is_successful(), "入口拒绝不得破坏外部 shutdown。")

	facade._exit_tree()
	facade.free()


func test_assignment_scope_cancelled_during_candidate_init_cannot_commit() -> void:
	var facade: GF_AUTOLOAD_NODE_SCRIPT = GF_AUTOLOAD_NODE_SCRIPT.new()
	var candidate: GFArchitecture = GFArchitecture.new()
	var cancelling_utility: CancelFacadeAssignmentUtility = (
		CancelFacadeAssignmentUtility.new()
	)
	cancelling_utility.facade = facade
	assert_true(
		await candidate.register_utility_instance(cancelling_utility),
		"取消 facade assignment 的测试 Utility 应先进入 candidate。"
	)

	var assignment_result: bool = await facade.set_architecture(candidate)

	assert_false(assignment_result, "已取消的 assignment scope 不得提交 candidate。")
	assert_false(facade.has_architecture(), "scope 取消后 facade 不得暴露 candidate。")
	assert_null(
		facade._pending_architecture_assignment,
		"scope 自取消后必须清除 pending assignment 指针。"
	)
	assert_null(
		facade._pending_architecture_assignment_scope,
		"scope 自取消后必须清除 pending scope 指针。"
	)
	assert_true(candidate.is_disposed(), "已取消且未提交的 candidate 应完成释放。")

	facade._exit_tree()
	facade.free()


func test_assignment_is_finalized_before_identity_signal_reentry() -> void:
	var facade: GF_AUTOLOAD_NODE_SCRIPT = GF_AUTOLOAD_NODE_SCRIPT.new()
	var candidate: GFArchitecture = GFArchitecture.new()
	var replacement: GFArchitecture = GFArchitecture.new()
	var candidate_result: Dictionary = {
		"done": false,
		"result": false,
	}
	var signal_state: Dictionary = {
		"triggered": false,
		"scope_completed": false,
		"pending_cleared": false,
		"replacement_result": false,
	}
	ProjectSettings.set_setting(INSTALLERS_SETTING, [FACADE_INSTALLER_PATH])
	ProjectSettings.set_setting(WAIT_FOR_RELEASE_SETTING, true)
	GF_ASYNC_CALL_SCRIPT.run_detached(
		Callable(self, &"_capture_assignment_result"),
		[facade, candidate, candidate_result]
	)
	assert_true(
		await _wait_for_project_setting(STARTED_SETTING),
		"测试 candidate 应在 Installer 等待点保留 pending scope。"
	)
	var candidate_scope: GFAsyncScope = facade._pending_architecture_assignment_scope
	assert_not_null(candidate_scope, "identity signal 前应能捕获 candidate assignment scope。")
	var _identity_connect_error: Error = facade.architecture_identity_changed.connect(
		func(
			_previous_architecture: GFArchitecture,
			current_architecture: GFArchitecture
		) -> void:
			if current_architecture != candidate or GFVariantData.get_option_bool(
				signal_state,
				"triggered"
			):
				return
			signal_state["triggered"] = true
			signal_state["scope_completed"] = candidate_scope.is_completed()
			signal_state["pending_cleared"] = (
				facade._pending_architecture_assignment == null
				and facade._pending_architecture_assignment_scope == null
			)
			var raw_replacement_result: Variant = facade.call(
				&"set_architecture",
				replacement
			)
			signal_state["replacement_result"] = GFVariantData.to_bool(
				raw_replacement_result
			)
	) as Error

	ProjectSettings.set_setting(RELEASE_SETTING, true)
	assert_true(
		await _wait_for_result(candidate_result),
		"释放 Installer 后 candidate assignment 应有界完成。"
	)

	assert_true(
		GFVariantData.get_option_bool(candidate_result, "result"),
		"identity signal 中启动的后续事务不应否定已经原子提交的 candidate。"
	)
	assert_true(
		GFVariantData.get_option_bool(signal_state, "scope_completed"),
		"发布 identity 前必须 complete 成功 assignment scope。"
	)
	assert_true(
		GFVariantData.get_option_bool(signal_state, "pending_cleared"),
		"发布 identity 前必须清除 pending 指针。"
	)
	assert_true(
		GFVariantData.get_option_bool(signal_state, "replacement_result"),
		"identity listener 发起的后续 replacement 应作为独立事务成功。"
	)
	assert_false(
		_project_setting_bool(CANCELLED_SETTING),
		"已提交 candidate 的 scope 不得被后续 identity listener 当作 pending 取消。"
	)
	assert_false(
		_project_setting_bool(CLEANUP_SETTING),
		"成功 assignment 登记的取消 cleanup 必须在发布 identity 前丢弃。"
	)
	assert_same(
		facade.get_architecture(),
		replacement,
		"identity listener 的后续事务应拥有最终架构身份。"
	)

	facade._exit_tree()
	facade.free()


## 验证 Gf 离开场景树时会取消 pending assignment，且 candidate 永远不能迟到提交。
func test_tree_exit_cancels_pending_assignment_scope() -> void:
	var facade: GF_AUTOLOAD_NODE_SCRIPT = GF_AUTOLOAD_NODE_SCRIPT.new()
	facade.name = "GfAssignmentExitProbe"
	get_tree().root.add_child(facade)
	var pending_architecture: GFArchitecture = GFArchitecture.new()
	var pending_result: Dictionary = {
		"done": false,
		"result": false,
	}
	ProjectSettings.set_setting(INSTALLERS_SETTING, [FACADE_INSTALLER_PATH])
	ProjectSettings.set_setting(WAIT_FOR_RELEASE_SETTING, true)
	GF_ASYNC_CALL_SCRIPT.run_detached(
		Callable(self, &"_capture_assignment_result"),
		[facade, pending_architecture, pending_result]
	)
	assert_true(
		await _wait_for_project_setting(STARTED_SETTING),
		"pending assignment 的 Installer 应在退出树前进入等待点。"
	)

	get_tree().root.remove_child(facade)
	await get_tree().process_frame
	var cancellation_observed: bool = _project_setting_bool(CANCELLED_SETTING)
	var cleanup_observed: bool = _project_setting_bool(CLEANUP_SETTING)

	ProjectSettings.set_setting(RELEASE_SETTING, true)
	assert_true(
		await _wait_for_result(pending_result),
		"退出树取消的 assignment 协程必须在有界帧数内返回。"
	)

	assert_false(GFVariantData.to_bool(pending_result.get("result", true)), "退出场景树后的 pending assignment 应返回 false。")
	assert_true(cancellation_observed, "退出场景树时 Installer scope 应收到取消。")
	assert_true(cleanup_observed, "退出场景树时应执行 pending scope cleanup。")
	assert_false(facade.has_architecture(), "退出场景树后 candidate 不得迟到成为 committed architecture。")

	facade.free()


## 验证取消 pending scope 的同步 cleanup 重入 create 时，较新的提交不会被外层覆盖。
func test_create_architecture_cleanup_reentry_preserves_latest_identity() -> void:
	var facade: GF_AUTOLOAD_NODE_SCRIPT = GF_AUTOLOAD_NODE_SCRIPT.new()
	var pending_architecture: GFArchitecture = GFArchitecture.new()
	var pending_scope: GFAsyncScope = facade._begin_architecture_assignment(
		pending_architecture
	)
	var reentrant_state: Dictionary = {}
	assert_not_null(pending_scope, "测试应先建立一个真实 pending assignment scope。")
	assert_true(
		pending_scope.register_cleanup(
			Callable(self, &"_capture_created_architecture").bind(
				facade,
				reentrant_state
			)
		),
		"测试 cleanup 应成功注册到 pending scope。"
	)

	var outer_result: GFArchitecture = facade.create_architecture()
	var reentrant_result: GFArchitecture = null
	var raw_reentrant_result: Variant = reentrant_state.get("architecture")
	if raw_reentrant_result is GFArchitecture:
		reentrant_result = raw_reentrant_result

	assert_not_null(reentrant_result, "cleanup 重入应成功创建较新的默认架构。")
	assert_same(
		outer_result,
		reentrant_result,
		"外层 create 应返回竞争后的当前架构，不得覆盖 cleanup 的较新提交。"
	)
	assert_same(
		facade.get_architecture(),
		reentrant_result,
		"cleanup 的较新架构身份必须保留为最终提交。"
	)
	assert_true(pending_architecture.is_disposed(), "被取消的 candidate 应完成释放。")

	facade._exit_tree()
	facade.free()


func test_create_architecture_recovers_after_identity_listener_disposes_result() -> void:
	var facade: GF_AUTOLOAD_NODE_SCRIPT = GF_AUTOLOAD_NODE_SCRIPT.new()
	var disposal_state: Dictionary = {
		"triggered": false,
		"architecture": null,
	}
	var _identity_connect_error: Error = facade.architecture_identity_changed.connect(
		Callable(self, &"_dispose_first_committed_architecture").bind(
			disposal_state
		)
	) as Error

	var first_result: GFArchitecture = facade.create_architecture()
	var disposed_architecture: GFArchitecture = null
	var raw_disposed_architecture: Variant = disposal_state.get("architecture")
	if raw_disposed_architecture is GFArchitecture:
		disposed_architecture = raw_disposed_architecture

	assert_null(
		first_result,
		"identity listener 释放刚提交的默认架构后，create 不得返回 terminal 对象。"
	)
	assert_not_null(disposed_architecture, "测试 listener 应观察并释放首个默认架构。")
	assert_true(disposed_architecture.is_disposed(), "首个默认架构应处于 DISPOSED。")
	assert_false(facade.has_architecture(), "terminal identity 不得被报告为可用架构。")

	var recovered_architecture: GFArchitecture = facade.create_architecture()

	assert_not_null(recovered_architecture, "后续 create 应清除 terminal identity 并重新创建。")
	assert_ne(
		recovered_architecture,
		disposed_architecture,
		"恢复时必须创建新的 Architecture，不能复活 DISPOSED 实例。"
	)
	assert_same(
		facade.get_architecture(),
		recovered_architecture,
		"恢复后的默认架构应成为当前可用 identity。"
	)

	facade._exit_tree()
	facade.free()


## 验证 Gf 退出期间的 cleanup 不能短暂创建并向调用方泄漏失效架构。
func test_tree_exit_cleanup_cannot_create_transient_architecture() -> void:
	var facade: GF_AUTOLOAD_NODE_SCRIPT = GF_AUTOLOAD_NODE_SCRIPT.new()
	var pending_architecture: GFArchitecture = GFArchitecture.new()
	var pending_scope: GFAsyncScope = facade._begin_architecture_assignment(
		pending_architecture
	)
	var reentrant_state: Dictionary = {}
	var committed_identities: Array[GFArchitecture] = []
	assert_not_null(pending_scope, "测试应先建立一个真实 pending assignment scope。")
	assert_true(
		pending_scope.register_cleanup(
			Callable(self, &"_capture_created_architecture").bind(
				facade,
				reentrant_state
			)
		),
		"测试 cleanup 应成功注册到 pending scope。"
	)
	var _identity_connect_error: Error = facade.architecture_identity_changed.connect(
		func(
			_previous_architecture: GFArchitecture,
			current_architecture: GFArchitecture
		) -> void:
			committed_identities.append(current_architecture)
	) as Error

	facade._exit_tree()

	assert_true(
		reentrant_state.has("architecture"),
		"退出取消 pending scope 时应同步执行测试 cleanup。"
	)
	assert_true(
		reentrant_state.get("architecture") == null,
		"退出期间 create 必须 fail closed，不得返回即将失效的默认架构。"
	)
	assert_false(facade.has_architecture(), "退出终态不得残留 committed architecture。")
	assert_true(
		committed_identities.is_empty(),
		"退出 cleanup 不得产生 transient architecture identity 信号。"
	)
	assert_true(pending_architecture.is_disposed(), "退出时 pending candidate 应完成释放。")

	facade.free()


## 验证已提交架构释放回调在 Gf 退出期间也不能取回正在 DISPOSING 的旧实例。
func test_tree_exit_dispose_callback_cannot_reacquire_architecture() -> void:
	var facade: GF_AUTOLOAD_NODE_SCRIPT = GF_AUTOLOAD_NODE_SCRIPT.new()
	var architecture: GFArchitecture = GFArchitecture.new()
	var observed_state: Dictionary = {}
	var utility: ReentrantCreateUtility = ReentrantCreateUtility.new()
	utility.facade = facade
	utility.observed_state = observed_state
	assert_true(
		await architecture.register_utility_instance(utility),
		"重入测试 Utility 应成功注册。"
	)
	assert_true(
		await facade.set_architecture(architecture),
		"测试架构应先成功提交。"
	)

	facade._exit_tree()

	assert_true(observed_state.has("architecture"), "退出释放应同步调用 Utility.dispose()。")
	assert_true(
		observed_state.get("architecture") == null,
		"退出期间 create 不得返回正在 DISPOSING 的旧架构。"
	)
	assert_true(architecture.is_disposed(), "退出后的原架构应到达 DISPOSED 终态。")
	assert_false(facade.has_architecture(), "退出终态不得残留架构。")

	facade.free()


func test_gf_init_rechecks_identity_after_initialization_finished_reentry() -> void:
	var facade: GF_AUTOLOAD_NODE_SCRIPT = GF_AUTOLOAD_NODE_SCRIPT.new()
	var initial_architecture: GFArchitecture = facade.create_architecture()
	var replacement_architecture: GFArchitecture = GFArchitecture.new()
	var replacement_state: Dictionary = {
		"result": false,
	}
	var _initialization_connect_error: Error = (
		initial_architecture.initialization_finished.connect(
			Callable(self, &"_replace_architecture_from_signal").bind(
				facade,
				replacement_architecture,
				replacement_state
			)
		)
	) as Error

	var initialization_result: bool = await facade.init()

	assert_false(
		initialization_result,
		"Gf.init() 在 initialization_finished 重入改写 identity 后不得返回陈旧成功。"
	)
	assert_true(
		GFVariantData.get_option_bool(replacement_state, "result"),
		"initialization_finished listener 的 replacement 应成功提交。"
	)
	assert_same(
		facade.get_architecture(),
		replacement_architecture,
		"重入 replacement 应拥有最终架构身份。"
	)
	assert_true(initial_architecture.is_disposed(), "被替换的初始架构应完成释放。")

	facade._exit_tree()
	facade.free()


func test_disposing_candidate_cannot_be_reassigned_to_facade() -> void:
	var facade: GF_AUTOLOAD_NODE_SCRIPT = GF_AUTOLOAD_NODE_SCRIPT.new()
	var architecture: DisposeReentrantSetArchitecture = (
		DisposeReentrantSetArchitecture.new()
	)
	architecture.facade = facade
	assert_true(
		await facade.set_architecture(architecture),
		"测试架构应先成功提交。"
	)

	architecture.dispose()

	assert_false(
		architecture.reentrant_set_result,
		"DISPOSING candidate 的同步 set_architecture() 重入必须 fail closed。"
	)
	assert_true(architecture.is_disposed(), "外层 dispose 应保持 DISPOSED 终态。")
	assert_false(
		facade.has_architecture(),
		"facade 不得把已释放 identity 报告为可用架构。"
	)
	assert_null(
		facade._pending_architecture_assignment,
		"被拒绝的 disposing candidate 不得进入 pending 槽。"
	)

	facade._exit_tree()
	facade.free()


## 验证旧架构 dispose 回调触发重入赋值时，最新 assignment 拥有最终提交权。
func test_dispose_reentry_preserves_latest_assignment() -> void:
	var facade: GF_AUTOLOAD_NODE_SCRIPT = GF_AUTOLOAD_NODE_SCRIPT.new()
	var committed_architecture: GFArchitecture = GFArchitecture.new()
	var reentrant_utility: ReentrantAssignmentUtility = ReentrantAssignmentUtility.new()
	var intermediate_architecture: GFArchitecture = GFArchitecture.new()
	var latest_architecture: GFArchitecture = GFArchitecture.new()
	var latest_result: Dictionary = {
		"done": false,
		"result": false,
	}
	reentrant_utility.assignment_callback = Callable(
		self,
		&"_capture_assignment_result"
	).bind(
		facade,
		latest_architecture,
		latest_result
	)
	assert_true(
		await committed_architecture.register_utility_instance(reentrant_utility),
		"重入测试 Utility 应成功注册到初始架构。"
	)
	assert_true(
		await facade.set_architecture(committed_architecture),
		"初始架构应先成功提交。"
	)

	var intermediate_result: bool = await facade.set_architecture(intermediate_architecture)
	assert_true(
		await _wait_for_result(latest_result),
		"dispose 重入触发的最新 assignment 必须在有界帧数内返回。"
	)

	assert_false(intermediate_result, "dispose 期间被重入替代的外层 assignment 应返回 false。")
	assert_true(GFVariantData.to_bool(latest_result.get("result", false)), "重入触发的最新 assignment 应成功。")
	assert_same(facade.get_architecture(), latest_architecture, "dispose 返回后不得用旧 assignment 覆盖最新架构。")

	facade._exit_tree()
	facade.free()


# --- 私有/辅助方法 ---

func _capture_assignment_result(
	facade: GF_AUTOLOAD_NODE_SCRIPT,
	architecture_instance: GFArchitecture,
	state: Dictionary
) -> void:
	state["result"] = await facade.set_architecture(architecture_instance)
	state["done"] = true


func _capture_shutdown_result(
	architecture: GFArchitecture,
	state: Dictionary
) -> void:
	state["result"] = await architecture.shutdown_async()
	state["done"] = true


func _capture_created_architecture(
	facade: GF_AUTOLOAD_NODE_SCRIPT,
	state: Dictionary
) -> void:
	state["architecture"] = facade.create_architecture()


func _replace_architecture_from_signal(
	facade: GF_AUTOLOAD_NODE_SCRIPT,
	replacement_architecture: GFArchitecture,
	state: Dictionary
) -> void:
	var raw_replacement_result: Variant = facade.call(
		&"set_architecture",
		replacement_architecture
	)
	state["result"] = GFVariantData.to_bool(raw_replacement_result)


func _dispose_first_committed_architecture(
	_previous_architecture: GFArchitecture,
	current_architecture: GFArchitecture,
	state: Dictionary
) -> void:
	if current_architecture == null or GFVariantData.get_option_bool(state, "triggered"):
		return
	state["triggered"] = true
	state["architecture"] = current_architecture
	current_architecture.dispose()


func _wait_for_project_setting(setting_name: String, max_frames: int = 30) -> bool:
	for _frame_index: int in range(max_frames):
		if _project_setting_bool(setting_name):
			return true
		await get_tree().process_frame
	return _project_setting_bool(setting_name)


func _wait_for_result(state: Dictionary, max_frames: int = 30) -> bool:
	for _frame_index: int in range(max_frames):
		if GFVariantData.to_bool(state.get("done", false)):
			return true
		await get_tree().process_frame
	return GFVariantData.to_bool(state.get("done", false))


func _wait_for_activation_start(
	activation_utility: BlockingActivationUtility,
	max_frames: int = 30
) -> bool:
	for _frame_index: int in range(max_frames):
		if activation_utility.activation_started:
			return true
		await get_tree().process_frame
	return activation_utility.activation_started


func _wait_for_quiesce_start(
	quiesce_utility: BlockingQuiesceUtility,
	max_frames: int = 30
) -> bool:
	for _frame_index: int in range(max_frames):
		if quiesce_utility.quiesce_started:
			return true
		await get_tree().process_frame
	return quiesce_utility.quiesce_started


func _project_setting_bool(setting_name: String) -> bool:
	return GFVariantData.to_bool(ProjectSettings.get_setting(setting_name, false))


func _clear_test_settings() -> void:
	for setting_name: String in [
		OBSERVED_COMMITTED_ARCHITECTURE_SETTING,
		WAIT_FOR_RELEASE_SETTING,
		STARTED_SETTING,
		RELEASE_SETTING,
		CANCELLED_SETTING,
		CLEANUP_SETTING,
	]:
		if ProjectSettings.has_setting(setting_name):
			ProjectSettings.clear(setting_name)
