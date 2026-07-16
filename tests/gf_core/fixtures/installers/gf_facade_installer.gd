## 通过 Gf facade 注册模块的 Installer 回归测试夹具。
extends GFInstaller


const AsyncInstallerUtilityFixture = preload("res://tests/gf_core/fixtures/installers/async_installer_utility_fixture.gd")


func install(_architecture: GFArchitecture, _scope: GFAsyncScope) -> void:
	await Gf.register_utility(AsyncInstallerUtilityFixture.new())
