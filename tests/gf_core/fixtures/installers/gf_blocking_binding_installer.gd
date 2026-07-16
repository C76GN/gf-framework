## 阻塞式声明绑定 Installer，用于验证并发 Gf.init() 会等待同一轮 Installer 完成。
extends GFInstaller


# --- 常量 ---

const AsyncInstallerUtilityFixture = preload("res://tests/gf_core/fixtures/installers/async_installer_utility_fixture.gd")
const STARTED_SETTING: String = "gf/test/blocking_installer_started"
const RELEASE_SETTING: String = "gf/test/release_blocking_installer"
const CANCELLED_SETTING: String = "gf/test/blocking_installer_cancelled"
const CLEANUP_SETTING: String = "gf/test/blocking_installer_cleanup"


# --- 公共方法 ---

func install_bindings(binder: Variant, scope: GFAsyncScope) -> void:
	ProjectSettings.set_setting(STARTED_SETTING, true)
	var _registered_cleanup: bool = scope.register_cleanup(Callable(self, &"_mark_cleanup"))
	var _connected_cancelled: Error = scope.cancel_requested.connect(_on_scope_cancel_requested) as Error
	while not _project_setting_bool(RELEASE_SETTING):
		var scene_tree: SceneTree = _get_scene_tree()
		if scene_tree == null:
			break
		await scene_tree.process_frame

	if binder is GFBinder:
		var typed_binder: GFBinder = binder
		await _bind_utility(typed_binder)


# --- 私有/辅助方法 ---

func _bind_utility(binder: GFBinder) -> void:
	await binder.bind_utility(AsyncInstallerUtilityFixture).as_singleton()


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
	if value is int:
		var int_value: int = value
		return int_value != 0
	if value is float:
		var float_value: float = value
		return not is_zero_approx(float_value)
	return false


func _on_scope_cancel_requested(_reason: StringName) -> void:
	ProjectSettings.set_setting(CANCELLED_SETTING, true)
