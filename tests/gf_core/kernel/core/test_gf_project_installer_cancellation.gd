## 项目 Installer 主动取消的终态与迟到写入回归。
extends GutTest


# --- 常量 ---

const INSTALLERS_SETTING: String = "gf/project/installers"
const INSTALLER_TIMEOUT_SETTING: String = "gf/project/installer_timeout_seconds"
const CANCELLING_INSTALLER_PATH: String = "res://tests/gf_core/fixtures/installers/gf_cancelling_installer.gd"
const STAGE_SETTING: String = "gf/test/cancelling_installer_stage"
const STARTED_SETTING: String = "gf/test/cancelling_installer_started"
const CANCEL_RELEASE_SETTING: String = "gf/test/cancelling_installer_cancel_release"
const REGISTER_BEFORE_CANCEL_SETTING: String = "gf/test/cancelling_installer_register_before_cancel"
const CONTINUE_AFTER_CANCEL_SETTING: String = "gf/test/cancelling_installer_continue_after_cancel"
const WAIT_FOR_FRAMEWORK_CANCEL_SETTING: String = "gf/test/cancelling_installer_wait_for_framework_cancel"
const FAIL_ARCHITECTURE_SETTING: String = "gf/test/cancelling_installer_fail_architecture"
const LATE_RELEASE_SETTING: String = "gf/test/cancelling_installer_late_release"
const LATE_WRITE_ATTEMPTED_SETTING: String = "gf/test/cancelling_installer_late_write_attempted"
const CLEANUP_COUNT_SETTING: String = "gf/test/cancelling_installer_cleanup_count"
const STAGE_INSTALL: String = "install"
const STAGE_BINDINGS: String = "install_bindings"
const CANCEL_REASON: String = "[test] project installer requested cancellation"
const InstallerModelFixture = preload("res://tests/gf_core/fixtures/installers/installer_model_fixture.gd")
const AsyncInstallerUtilityFixture = preload("res://tests/gf_core/fixtures/installers/async_installer_utility_fixture.gd")
const MANAGED_SETTINGS: Array[String] = [
	INSTALLERS_SETTING,
	INSTALLER_TIMEOUT_SETTING,
	STAGE_SETTING,
	STARTED_SETTING,
	CANCEL_RELEASE_SETTING,
	REGISTER_BEFORE_CANCEL_SETTING,
	CONTINUE_AFTER_CANCEL_SETTING,
	WAIT_FOR_FRAMEWORK_CANCEL_SETTING,
	FAIL_ARCHITECTURE_SETTING,
	LATE_RELEASE_SETTING,
	LATE_WRITE_ATTEMPTED_SETTING,
	CLEANUP_COUNT_SETTING,
]


# --- 辅助类 ---

class InstallerFinishedReentryProbe:
	var architecture: GFArchitecture = null
	var call_count: int = 0
	var begin_result: bool = true
	var finish_attempted: bool = false
	var applied_after_finish: bool = true
	var attempt_init: bool = true
	var init_attempted: bool = false
	var init_result: bool = true
	var model_script: Script = null
	var utility_script: Script = null
	var observed_model: Object = null
	var observed_utility: Object = null

	func _init(
		p_architecture: GFArchitecture,
		p_model_script: Script = null,
		p_utility_script: Script = null,
		p_attempt_init: bool = true
	) -> void:
		architecture = p_architecture
		model_script = p_model_script
		utility_script = p_utility_script
		attempt_init = p_attempt_init

	func on_project_installers_finished() -> void:
		call_count += 1
		if model_script != null:
			observed_model = architecture.get_local_model(model_script)
		if utility_script != null:
			observed_utility = architecture.get_local_utility(utility_script)
		begin_result = architecture.begin_project_installers()
		if not begin_result:
			finish_attempted = true
			architecture.finish_project_installers()
		applied_after_finish = architecture.has_project_installers_applied()
		if attempt_init:
			init_attempted = true
			init_result = await architecture.init()


# --- 私有变量 ---

var _previous_settings: Dictionary = {}


# --- Godot 生命周期方法 ---

func before_each() -> void:
	_previous_settings.clear()
	for setting_name: String in MANAGED_SETTINGS:
		_previous_settings[setting_name] = {
			"had_setting": ProjectSettings.has_setting(setting_name),
			"value": ProjectSettings.get_setting(setting_name, null),
		}
	_reset_test_settings()
	GFAutoload.reset_tree_exit_state()
	_dispose_current_architecture()


func after_each() -> void:
	ProjectSettings.set_setting(CANCEL_RELEASE_SETTING, true)
	ProjectSettings.set_setting(LATE_RELEASE_SETTING, true)
	await _wait_frames(3)
	_dispose_current_architecture()
	GFAutoload.reset_tree_exit_state()
	for setting_name: String in MANAGED_SETTINGS:
		var raw_state: Variant = _previous_settings.get(setting_name, {})
		if not raw_state is Dictionary:
			continue
		var state: Dictionary = raw_state
		if _dictionary_bool(state, "had_setting", false):
			ProjectSettings.set_setting(
				setting_name,
				state.get("value")
			)
		elif ProjectSettings.has_setting(setting_name):
			ProjectSettings.clear(setting_name)
	_previous_settings.clear()


# --- 测试用例 ---

func test_install_cancellation_rolls_back_and_settles_once() -> void:
	ProjectSettings.set_setting(STAGE_SETTING, STAGE_INSTALL)
	ProjectSettings.set_setting(CANCEL_RELEASE_SETTING, true)
	ProjectSettings.set_setting(REGISTER_BEFORE_CANCEL_SETTING, true)
	var architecture: GFArchitecture = Gf.create_architecture()
	var reentry_probe: InstallerFinishedReentryProbe = (
		InstallerFinishedReentryProbe.new(architecture, InstallerModelFixture)
	)
	var _connected_finished: Error = architecture.project_installers_finished.connect(
		reentry_probe.on_project_installers_finished
	) as Error
	watch_signals(architecture)

	var initialized: bool = await Gf.init()

	assert_false(initialized, "Installer 主动取消后 Gf.init() 应有界返回 false。")
	assert_false(architecture.is_project_installers_running(), "取消必须关闭 Installer running 状态。")
	assert_false(architecture.has_project_installers_applied(), "取消不得提交 Installer applied。")
	assert_true(architecture.has_initialization_failed(), "取消必须进入现有初始化失败终态。")
	assert_eq(architecture.last_initialization_error, CANCEL_REASON, "应保留 scope 的首次取消原因。")
	assert_null(architecture.get_local_model(InstallerModelFixture), "取消前注册的 Model 必须回滚。")
	assert_signal_emit_count(architecture, "project_installers_finished", 1)
	assert_eq(reentry_probe.call_count, 1, "Installer terminal signal 必须恰好一次。")
	assert_false(reentry_probe.begin_result, "terminal signal 同步重入不得开始覆盖旧回滚的新一轮。")
	assert_true(reentry_probe.finish_attempted, "terminal signal 应执行 finish 重入探针。")
	assert_false(reentry_probe.applied_after_finish, "terminal signal 重入不得重新提交 applied。")
	assert_true(reentry_probe.init_attempted, "terminal signal 应执行 init 重入探针。")
	assert_false(reentry_probe.init_result, "失败结算完成前不得清除 FAILED 并重启 lifecycle。")
	assert_null(reentry_probe.observed_model, "terminal signal 发出前必须完成 Model 回滚。")
	assert_push_error(CANCEL_REASON)


func test_install_bindings_cancellation_rolls_back_and_settles() -> void:
	ProjectSettings.set_setting(STAGE_SETTING, STAGE_BINDINGS)
	ProjectSettings.set_setting(CANCEL_RELEASE_SETTING, true)
	ProjectSettings.set_setting(REGISTER_BEFORE_CANCEL_SETTING, true)
	var architecture: GFArchitecture = Gf.create_architecture()
	var reentry_probe: InstallerFinishedReentryProbe = (
		InstallerFinishedReentryProbe.new(
			architecture,
			null,
			AsyncInstallerUtilityFixture
		)
	)
	var _connected_finished: Error = architecture.project_installers_finished.connect(
		reentry_probe.on_project_installers_finished
	) as Error
	watch_signals(architecture)

	var initialized: bool = await Gf.init()

	assert_false(initialized, "install_bindings() 主动取消后 Gf.init() 应返回 false。")
	assert_false(architecture.is_project_installers_running())
	assert_false(architecture.has_project_installers_applied())
	assert_true(architecture.has_initialization_failed())
	assert_eq(architecture.last_initialization_error, CANCEL_REASON)
	assert_null(
		architecture.get_local_utility(AsyncInstallerUtilityFixture),
		"取消前声明绑定的 Utility 必须回滚。"
	)
	assert_signal_emit_count(architecture, "project_installers_finished", 1)
	assert_eq(reentry_probe.call_count, 1)
	assert_false(reentry_probe.begin_result)
	assert_true(reentry_probe.finish_attempted)
	assert_false(reentry_probe.applied_after_finish)
	assert_true(reentry_probe.init_attempted)
	assert_false(reentry_probe.init_result)
	assert_null(reentry_probe.observed_utility, "terminal signal 发出前必须完成 Utility 回滚。")
	assert_push_error(CANCEL_REASON)


func test_installer_reported_failure_keeps_terminal_reentry_closed() -> void:
	ProjectSettings.set_setting(STAGE_SETTING, STAGE_INSTALL)
	ProjectSettings.set_setting(FAIL_ARCHITECTURE_SETTING, true)
	ProjectSettings.set_setting(REGISTER_BEFORE_CANCEL_SETTING, true)
	var architecture: GFArchitecture = Gf.create_architecture()
	var reentry_probe: InstallerFinishedReentryProbe = (
		InstallerFinishedReentryProbe.new(architecture, InstallerModelFixture)
	)
	var _connected_finished: Error = architecture.project_installers_finished.connect(
		reentry_probe.on_project_installers_finished
	) as Error
	watch_signals(architecture)

	var initialized: bool = await Gf.init()

	assert_false(initialized)
	assert_true(architecture.has_initialization_failed())
	assert_false(architecture.is_project_installers_running())
	assert_false(architecture.has_project_installers_applied())
	assert_signal_emit_count(architecture, "project_installers_finished", 1)
	assert_eq(reentry_probe.call_count, 1)
	assert_false(reentry_probe.begin_result, "Installer 主动 fail 的同步 signal 内不得开始重试。")
	assert_true(reentry_probe.finish_attempted)
	assert_false(reentry_probe.applied_after_finish, "Installer 主动 fail 后不得被 finish 重入覆盖。")
	assert_true(reentry_probe.init_attempted)
	assert_false(reentry_probe.init_result, "Installer 主动 fail 的 signal 内不得重启 lifecycle。")
	assert_null(reentry_probe.observed_model, "Installer 主动 fail 的 terminal signal 必须晚于回滚。")
	assert_eq(_project_setting_int(CLEANUP_COUNT_SETTING), 1, "失败应恰好一次清理 Installer scope。")
	assert_push_error(CANCEL_REASON)


func test_concurrent_init_waiter_is_released_by_installer_cancellation() -> void:
	ProjectSettings.set_setting(STAGE_SETTING, STAGE_INSTALL)
	var architecture: GFArchitecture = Gf.create_architecture()
	watch_signals(architecture)
	var first_state: Dictionary = {"done": false, "result": true}
	var second_state: Dictionary = {"done": false, "result": true}

	@warning_ignore("missing_await")
	_await_gf_init(first_state)
	await _wait_until_project_setting(STARTED_SETTING)
	@warning_ignore("missing_await")
	_await_gf_init(second_state)
	await get_tree().process_frame
	assert_false(
		_dictionary_bool(second_state, "done", false),
		"第二个 Gf.init() 应等待活动 Installer 的 terminal signal。"
	)

	ProjectSettings.set_setting(CANCEL_RELEASE_SETTING, true)
	await _wait_frames(3)

	assert_true(_dictionary_bool(first_state, "done", false))
	assert_true(_dictionary_bool(second_state, "done", false), "取消必须唤醒并发等待方。")
	assert_false(_dictionary_bool(first_state, "result", true))
	assert_false(_dictionary_bool(second_state, "result", true))
	assert_false(architecture.is_project_installers_running())
	assert_true(architecture.has_initialization_failed())
	assert_signal_emit_count(architecture, "project_installers_finished", 1)
	assert_push_error(CANCEL_REASON)


func test_timeout_cancel_resume_keeps_terminal_reentry_closed() -> void:
	ProjectSettings.set_setting(STAGE_SETTING, STAGE_BINDINGS)
	ProjectSettings.set_setting(WAIT_FOR_FRAMEWORK_CANCEL_SETTING, true)
	ProjectSettings.set_setting(INSTALLER_TIMEOUT_SETTING, 0.01)
	var architecture: GFArchitecture = Gf.create_architecture()
	var reentry_probe: InstallerFinishedReentryProbe = (
		InstallerFinishedReentryProbe.new(architecture)
	)
	var _connected_finished: Error = architecture.project_installers_finished.connect(
		reentry_probe.on_project_installers_finished
	) as Error
	watch_signals(architecture)

	var initialized: bool = await Gf.init()
	var expected_error: String = (
		"[GF] 项目 Installer 超时：%s 的 install_bindings() 超过 0.01 秒。"
		% CANCELLING_INSTALLER_PATH
	)

	assert_false(initialized)
	assert_true(architecture.has_initialization_failed())
	assert_false(architecture.is_project_installers_running())
	assert_false(architecture.has_project_installers_applied())
	assert_eq(architecture.last_initialization_error, expected_error)
	assert_signal_emit_count(architecture, "project_installers_finished", 1)
	assert_eq(reentry_probe.call_count, 1)
	assert_false(reentry_probe.begin_result, "timeout cancel 同步恢复后仍须阻止 signal 内重试。")
	assert_true(reentry_probe.finish_attempted)
	assert_false(reentry_probe.applied_after_finish, "timeout terminal 不得被 finish 重入覆盖。")
	assert_true(reentry_probe.init_attempted)
	assert_false(reentry_probe.init_result, "timeout terminal signal 内不得重启 lifecycle。")
	assert_eq(_project_setting_int(CLEANUP_COUNT_SETTING), 1)
	assert_push_error(expected_error)


func test_cancelled_detached_installer_blocks_retry_and_late_binding() -> void:
	ProjectSettings.set_setting(STAGE_SETTING, STAGE_BINDINGS)
	ProjectSettings.set_setting(CANCEL_RELEASE_SETTING, true)
	ProjectSettings.set_setting(CONTINUE_AFTER_CANCEL_SETTING, true)
	ProjectSettings.set_setting(INSTALLER_TIMEOUT_SETTING, 1.0)
	var architecture: GFArchitecture = Gf.create_architecture()
	watch_signals(architecture)

	var first_initialized: bool = await Gf.init()
	assert_false(first_initialized)
	assert_true(architecture.has_initialization_failed())
	assert_false(architecture.is_project_installers_running())
	assert_signal_emit_count(architecture, "project_installers_finished", 1)
	if architecture.is_project_installers_running():
		# 仅帮助旧实现从缺失的 terminal settlement 中收敛，避免红测永久 await。
		architecture.fail_initialization(CANCEL_REASON)
	assert_push_error(CANCEL_REASON)

	ProjectSettings.set_setting(INSTALLERS_SETTING, [])
	var early_retry_initialized: bool = await Gf.init()
	assert_false(early_retry_initialized, "旧 Installer continuation 未收尾前重试必须 fail fast。")
	assert_true(architecture.has_initialization_failed(), "早到重试不得清除旧失败状态。")

	ProjectSettings.set_setting(LATE_RELEASE_SETTING, true)
	await _wait_frames(4)
	assert_true(
		_project_setting_bool(LATE_WRITE_ATTEMPTED_SETTING),
		"旧 Installer 应已经尝试迟到写入。"
	)
	assert_null(
		architecture.get_local_utility(AsyncInstallerUtilityFixture),
		"旧 continuation 不得把 Utility 写入失败或重试后的架构。"
	)
	assert_push_error("[GFArchitecture] register_utility 失败：架构初始化已失败，已拒绝迟到写入。")

	var final_retry_initialized: bool = await Gf.init()
	assert_true(final_retry_initialized, "旧 continuation 收尾后同一架构应允许 deliberate retry。")
	assert_true(architecture.is_inited())
	assert_false(architecture.has_initialization_failed())
	assert_signal_emit_count(architecture, "project_installers_finished", 2)


func test_cancelled_candidate_assignment_is_rejected_and_disposed_once() -> void:
	ProjectSettings.set_setting(INSTALLERS_SETTING, [])
	var committed_architecture: GFArchitecture = GFArchitecture.new()
	assert_true(
		await Gf.set_architecture(committed_architecture),
		"测试应先提交稳定的既有 Architecture identity。"
	)
	ProjectSettings.set_setting(INSTALLERS_SETTING, [CANCELLING_INSTALLER_PATH])
	ProjectSettings.set_setting(STAGE_SETTING, STAGE_INSTALL)
	ProjectSettings.set_setting(CANCEL_RELEASE_SETTING, true)
	ProjectSettings.set_setting(REGISTER_BEFORE_CANCEL_SETTING, true)
	var candidate: GFArchitecture = GFArchitecture.new()
	var reentry_probe: InstallerFinishedReentryProbe = (
		InstallerFinishedReentryProbe.new(candidate, InstallerModelFixture)
	)
	var _connected_finished: Error = candidate.project_installers_finished.connect(
		reentry_probe.on_project_installers_finished
	) as Error
	watch_signals(candidate)

	var assigned: bool = await Gf.set_architecture(candidate)

	assert_false(assigned, "自取消的 candidate assignment 不得提交。")
	assert_null(Gf._pending_architecture_assignment, "失败 assignment 必须清空 pending candidate。")
	assert_null(Gf._pending_architecture_assignment_scope, "失败 assignment 必须清空 pending scope。")
	assert_true(candidate.is_disposed(), "未发布 candidate 必须完成释放。")
	assert_same(Gf.get_architecture(), committed_architecture, "既有 committed identity 必须保持不变。")
	assert_false(candidate.is_project_installers_running())
	assert_false(candidate.has_project_installers_applied())
	assert_signal_emit_count(candidate, "project_installers_finished", 1)
	assert_eq(reentry_probe.call_count, 1)
	assert_false(reentry_probe.begin_result)
	assert_true(reentry_probe.finish_attempted)
	assert_false(reentry_probe.applied_after_finish)
	assert_true(reentry_probe.init_attempted)
	assert_false(reentry_probe.init_result)
	assert_null(reentry_probe.observed_model, "candidate terminal signal 必须晚于模块回滚。")
	assert_eq(_project_setting_int(CLEANUP_COUNT_SETTING), 1, "assignment scope cleanup 必须恰好一次。")
	assert_push_error(CANCEL_REASON)


func test_dispose_terminal_reentry_cannot_restart_project_installers() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	assert_true(architecture.begin_project_installers())
	var reentry_probe: InstallerFinishedReentryProbe = (
		InstallerFinishedReentryProbe.new(architecture, null, null, false)
	)
	var _connected_finished: Error = architecture.project_installers_finished.connect(
		reentry_probe.on_project_installers_finished
	) as Error
	watch_signals(architecture)

	architecture.dispose()

	assert_true(architecture.is_disposed())
	assert_false(architecture.is_project_installers_running())
	assert_false(architecture.has_project_installers_applied())
	assert_signal_emit_count(architecture, "project_installers_finished", 1)
	assert_eq(reentry_probe.call_count, 1)
	assert_false(reentry_probe.begin_result, "DISPOSING signal 内不得重新开始 Installer。")
	assert_true(reentry_probe.finish_attempted)
	assert_false(reentry_probe.applied_after_finish, "DISPOSING signal 内不得重新提交 applied。")


func test_ready_candidate_can_apply_installers_before_assignment() -> void:
	ProjectSettings.set_setting(INSTALLERS_SETTING, [])
	var candidate: GFArchitecture = GFArchitecture.new()
	assert_true(await candidate.init(), "测试 candidate 应先直接进入 READY。")
	assert_true(candidate.is_inited())
	assert_false(candidate.has_project_installers_applied())

	var assigned: bool = await Gf.set_architecture(candidate)

	assert_true(assigned, "READY candidate 仍应允许补跑并提交项目 Installer。")
	assert_same(Gf.get_architecture(), candidate)
	assert_true(candidate.is_inited())
	assert_true(candidate.has_project_installers_applied())
	assert_false(candidate.is_project_installers_running())


# --- 私有/辅助方法 ---

func _reset_test_settings() -> void:
	ProjectSettings.set_setting(INSTALLERS_SETTING, [CANCELLING_INSTALLER_PATH])
	ProjectSettings.set_setting(INSTALLER_TIMEOUT_SETTING, 0.0)
	ProjectSettings.set_setting(STAGE_SETTING, STAGE_INSTALL)
	ProjectSettings.set_setting(STARTED_SETTING, false)
	ProjectSettings.set_setting(CANCEL_RELEASE_SETTING, false)
	ProjectSettings.set_setting(REGISTER_BEFORE_CANCEL_SETTING, false)
	ProjectSettings.set_setting(CONTINUE_AFTER_CANCEL_SETTING, false)
	ProjectSettings.set_setting(WAIT_FOR_FRAMEWORK_CANCEL_SETTING, false)
	ProjectSettings.set_setting(FAIL_ARCHITECTURE_SETTING, false)
	ProjectSettings.set_setting(LATE_RELEASE_SETTING, false)
	ProjectSettings.set_setting(LATE_WRITE_ATTEMPTED_SETTING, false)
	ProjectSettings.set_setting(CLEANUP_COUNT_SETTING, 0)


func _dispose_current_architecture() -> void:
	var architecture: GFArchitecture = Gf._architecture
	if architecture != null:
		architecture.dispose()
	Gf._architecture = null


func _await_gf_init(state: Dictionary) -> void:
	state["result"] = await Gf.init()
	state["done"] = true


func _wait_until_project_setting(setting_name: String) -> void:
	for _frame: int in range(8):
		if _project_setting_bool(setting_name):
			return
		await get_tree().process_frame


func _wait_frames(frame_count: int) -> void:
	for _frame: int in range(frame_count):
		await get_tree().process_frame


func _dictionary_bool(options: Dictionary, key: String, default_value: bool) -> bool:
	var value: Variant = options.get(key, default_value)
	if value is bool:
		return value
	return default_value


func _project_setting_bool(setting_name: String) -> bool:
	var value: Variant = ProjectSettings.get_setting(setting_name, false)
	if value is bool:
		return value
	return false


func _project_setting_int(setting_name: String) -> int:
	var value: Variant = ProjectSettings.get_setting(setting_name, 0)
	if value is int:
		return value
	return 0
