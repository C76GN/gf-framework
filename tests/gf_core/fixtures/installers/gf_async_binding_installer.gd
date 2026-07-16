## Gf 异步声明式绑定 Installer 回归测试夹具。
extends GFInstaller


# --- 常量 ---

const AsyncInstallerUtilityFixture = preload("res://tests/gf_core/fixtures/installers/async_installer_utility_fixture.gd")


# --- 公共方法 ---

func install_bindings(binder: Variant, _scope: GFAsyncScope) -> void:
	var scene_tree: SceneTree = _get_scene_tree()
	if scene_tree != null:
		await scene_tree.process_frame
	if binder is GFBinder:
		var typed_binder: GFBinder = binder
		await _bind_utility(typed_binder)


# --- 私有/辅助方法 ---

func _bind_utility(binder: GFBinder) -> void:
	await binder.bind_utility(AsyncInstallerUtilityFixture).as_singleton()


func _get_scene_tree() -> SceneTree:
	var main_loop: MainLoop = Engine.get_main_loop()
	if main_loop is SceneTree:
		return main_loop
	return null
