# GF Turn Based 扩展安装器。
extends GFInstaller


# --- 常量 ---

const _GF_TURN_FLOW_SYSTEM_SCRIPT = preload("res://addons/gf/extensions/turn_based/runtime/gf_turn_flow_system.gd")


# --- 框架内部方法 ---

## 注册 Turn Based 扩展的运行时服务。
## [br]
## @api framework_internal
## [br]
## @param architecture: 要装配的架构实例。
## [br]
## @param _scope: 本轮安装的取消作用域。
func install(architecture: GFArchitecture, _scope: GFAsyncScope) -> void:
	if architecture == null:
		return
	if architecture.get_local_system(_GF_TURN_FLOW_SYSTEM_SCRIPT) != null:
		return
	var _registered_turn_flow: bool = await architecture.register_system_instance(_GF_TURN_FLOW_SYSTEM_SCRIPT.new())
