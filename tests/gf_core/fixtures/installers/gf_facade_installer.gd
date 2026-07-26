# 验证 set_architecture 提交可见性与 pending assignment 取消清理的 Installer 夹具。
extends GFInstaller


# --- 常量 ---

const AsyncInstallerUtilityFixture = preload("res://tests/gf_core/fixtures/installers/async_installer_utility_fixture.gd")
const OBSERVED_COMMITTED_ARCHITECTURE_SETTING: String = "gf/test/facade_installer_observed_committed_architecture"
const WAIT_FOR_RELEASE_SETTING: String = "gf/test/facade_installer_wait_for_release"
const STARTED_SETTING: String = "gf/test/facade_installer_started"
const RELEASE_SETTING: String = "gf/test/facade_installer_release"
const CANCELLED_SETTING: String = "gf/test/facade_installer_cancelled"
const CLEANUP_SETTING: String = "gf/test/facade_installer_cleanup"


# --- 公共方法 ---

func install(architecture: GFArchitecture, scope: GFAsyncScope) -> void:
	ProjectSettings.set_setting(
		OBSERVED_COMMITTED_ARCHITECTURE_SETTING,
		Gf.has_architecture() and Gf.get_architecture() != architecture
	)
	if _project_setting_bool(WAIT_FOR_RELEASE_SETTING):
		ProjectSettings.set_setting(STARTED_SETTING, true)
		var _registered_cleanup: bool = scope.register_cleanup(Callable(self, &"_mark_cleanup"))
		var _connected_cancelled: Error = scope.cancel_requested.connect(_on_scope_cancel_requested) as Error
		while not _project_setting_bool(RELEASE_SETTING) and not scope.is_cancel_requested():
			var scene_tree: SceneTree = _get_scene_tree()
			if scene_tree == null:
				break
			await scene_tree.process_frame
		if scope.is_cancel_requested():
			return
	await architecture.register_utility_instance(AsyncInstallerUtilityFixture.new())


# --- 私有/辅助方法 ---

func _mark_cleanup() -> void:
	ProjectSettings.set_setting(CLEANUP_SETTING, true)


func _get_scene_tree() -> SceneTree:
	var main_loop: MainLoop = Engine.get_main_loop()
	if main_loop is SceneTree:
		return main_loop
	return null


func _project_setting_bool(setting_name: String) -> bool:
	var value: Variant = ProjectSettings.get_setting(setting_name, false)
	if value is bool:
		var bool_value: bool = value
		return bool_value
	return false


# --- 信号处理函数 ---

func _on_scope_cancel_requested(_reason: StringName) -> void:
	ProjectSettings.set_setting(CANCELLED_SETTING, true)
