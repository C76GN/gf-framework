## 测试 GFInstaller 生命周期钩子与 GFBinder 返回的绑定构建器。
extends GutTest


func test_installer_bindings_register_utility_through_binder() -> void:
	var inst: ProjectInstallerProbe = ProjectInstallerProbe.new()
	var arch: GFArchitecture = GFArchitecture.new()
	var scope: GFAsyncScope = GFAsyncScope.new()

	await inst.install_bindings(arch.create_binder(), scope)

	assert_true(arch.get_utility(GFSeedUtility) is GFSeedUtility, "Installer 应能通过 Binder 注册 Utility。")


func test_binder_bind_utility_returns_bind_builder() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var binder: GFBinder = GFBinder.new(arch)
	var builder: Variant = binder.bind_utility(GFSeedUtility)
	assert_true(builder is GFBindBuilder, "bind_utility 应返回 GFBindBuilder。")


# --- 辅助类型 ---

class ProjectInstallerProbe extends GFInstaller:
	func install_bindings(binder: Variant, _scope: GFAsyncScope) -> void:
		if binder is GFBinder:
			var typed_binder: GFBinder = binder
			var _registered_seed: bool = await typed_binder.bind_utility(GFSeedUtility).as_singleton()
