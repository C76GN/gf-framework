## 主动取消项目 Installer 的回归测试夹具。
extends GFInstaller


# --- 常量 ---

const InstallerModelFixture = preload("res://tests/gf_core/fixtures/installers/installer_model_fixture.gd")
const AsyncInstallerUtilityFixture = preload("res://tests/gf_core/fixtures/installers/async_installer_utility_fixture.gd")
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


# --- 公共方法 ---

func install(architecture: GFArchitecture, scope: GFAsyncScope) -> void:
	if _project_setting_text(STAGE_SETTING) != STAGE_INSTALL:
		return
	ProjectSettings.set_setting(STARTED_SETTING, true)
	var _registered_cleanup: bool = scope.register_cleanup(
		Callable(self, &"_increment_cleanup_count")
	)
	if _project_setting_bool(REGISTER_BEFORE_CANCEL_SETTING):
		await architecture.register_model_instance(InstallerModelFixture.new())
	if _project_setting_bool(FAIL_ARCHITECTURE_SETTING):
		architecture.fail_initialization(CANCEL_REASON)
		return
	if _project_setting_bool(WAIT_FOR_FRAMEWORK_CANCEL_SETTING):
		await scope.cancel_requested
		return
	await _wait_for_project_setting(CANCEL_RELEASE_SETTING)
	var _cancelled_scope: bool = scope.cancel(CANCEL_REASON)
	if not _project_setting_bool(CONTINUE_AFTER_CANCEL_SETTING):
		return
	await _wait_for_project_setting(LATE_RELEASE_SETTING)
	ProjectSettings.set_setting(LATE_WRITE_ATTEMPTED_SETTING, true)
	await architecture.register_model_instance(InstallerModelFixture.new())


func install_bindings(binder: Variant, scope: GFAsyncScope) -> void:
	if _project_setting_text(STAGE_SETTING) != STAGE_BINDINGS:
		return
	ProjectSettings.set_setting(STARTED_SETTING, true)
	var _registered_cleanup: bool = scope.register_cleanup(
		Callable(self, &"_increment_cleanup_count")
	)
	if _project_setting_bool(REGISTER_BEFORE_CANCEL_SETTING) and binder is GFBinder:
		var pre_cancel_binder: GFBinder = binder
		await _bind_utility(pre_cancel_binder)
	if _project_setting_bool(WAIT_FOR_FRAMEWORK_CANCEL_SETTING):
		await scope.cancel_requested
		return
	await _wait_for_project_setting(CANCEL_RELEASE_SETTING)
	var _cancelled_scope: bool = scope.cancel(CANCEL_REASON)
	if not _project_setting_bool(CONTINUE_AFTER_CANCEL_SETTING):
		return
	await _wait_for_project_setting(LATE_RELEASE_SETTING)
	ProjectSettings.set_setting(LATE_WRITE_ATTEMPTED_SETTING, true)
	if binder is GFBinder:
		var late_binder: GFBinder = binder
		await _bind_utility(late_binder)


# --- 私有/辅助方法 ---

func _bind_utility(binder: GFBinder) -> void:
	await binder.bind_utility(AsyncInstallerUtilityFixture).as_singleton()


func _increment_cleanup_count() -> void:
	var current_count: int = _project_setting_int(CLEANUP_COUNT_SETTING)
	ProjectSettings.set_setting(CLEANUP_COUNT_SETTING, current_count + 1)


func _wait_for_project_setting(setting_name: String) -> void:
	while not _project_setting_bool(setting_name):
		var scene_tree: SceneTree = _get_scene_tree()
		if scene_tree == null:
			return
		await scene_tree.process_frame


func _get_scene_tree() -> SceneTree:
	var main_loop: MainLoop = Engine.get_main_loop()
	if main_loop is SceneTree:
		return main_loop
	return null


func _project_setting_bool(setting_name: String) -> bool:
	var value: Variant = ProjectSettings.get_setting(setting_name, false)
	if value is bool:
		return value
	if value is int:
		return value != 0
	if value is float:
		var float_value: float = value
		return not is_zero_approx(float_value)
	return false


func _project_setting_text(setting_name: String) -> String:
	var value: Variant = ProjectSettings.get_setting(setting_name, "")
	if value is String:
		return value
	if value is StringName:
		var string_name_value: StringName = value
		return String(string_name_value)
	return ""


func _project_setting_int(setting_name: String) -> int:
	var value: Variant = ProjectSettings.get_setting(setting_name, 0)
	if value is int:
		return value
	return 0
