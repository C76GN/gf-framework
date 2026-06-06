# GF Content Package 扩展安装器。
extends GFInstaller


# --- 常量 ---

const _GF_CONTENT_PACKAGE_UTILITY_SCRIPT = preload("res://addons/gf/extensions/content_package/runtime/gf_content_package_utility.gd")


# --- 框架内部方法 ---

## 注册 Content Package 扩展的运行时服务。
## [br]
## @api framework_internal
## [br]
## @param architecture: 要装配的架构实例。
func install(architecture: GFArchitecture) -> void:
	if architecture == null:
		return
	if architecture.get_local_utility(_GF_CONTENT_PACKAGE_UTILITY_SCRIPT) != null:
		return
	await architecture.register_utility_instance(_GF_CONTENT_PACKAGE_UTILITY_SCRIPT.new())
