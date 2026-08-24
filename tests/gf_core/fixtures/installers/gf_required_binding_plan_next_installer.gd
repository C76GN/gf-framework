## required binding plan 失败后不得运行的后继 Installer 夹具。
extends GFInstaller


# --- 常量 ---

const RAN_SETTING: String = "gf/test/required_binding_plan_next_installer_ran"


# --- 公共方法 ---

func install(_architecture: GFArchitecture, _scope: GFAsyncScope) -> void:
	ProjectSettings.set_setting(RAN_SETTING, true)
