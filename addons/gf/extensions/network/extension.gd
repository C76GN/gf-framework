# GF Network 扩展安装器。
extends GFInstaller


# --- 常量 ---

const _GF_NETWORK_UTILITY_SCRIPT = preload("res://addons/gf/extensions/network/runtime/gf_network_utility.gd")
const _GF_NETWORK_LOBBY_SERVICE_SCRIPT = preload("res://addons/gf/extensions/network/session/gf_network_lobby_service.gd")


# --- 框架内部方法 ---

## 注册 Network 扩展的运行时服务。
## [br]
## @api framework_internal
## [br]
## @param architecture: 要装配的架构实例。
## [br]
## @param _scope: 本轮安装的取消作用域。
func install(architecture: GFArchitecture, _scope: GFAsyncScope) -> void:
	if architecture == null:
		return
	if architecture.get_local_utility(_GF_NETWORK_UTILITY_SCRIPT) != null:
		if architecture.get_local_utility(_GF_NETWORK_LOBBY_SERVICE_SCRIPT) == null:
			var _registered_lobby_only: bool = await architecture.register_utility_instance(_GF_NETWORK_LOBBY_SERVICE_SCRIPT.new())
		return
	var _registered_network: bool = await architecture.register_utility_instance(_GF_NETWORK_UTILITY_SCRIPT.new())
	if architecture.get_local_utility(_GF_NETWORK_LOBBY_SERVICE_SCRIPT) == null:
		var _registered_lobby: bool = await architecture.register_utility_instance(_GF_NETWORK_LOBBY_SERVICE_SCRIPT.new())
