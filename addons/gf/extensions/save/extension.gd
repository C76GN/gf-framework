# GF Save 扩展安装器。
extends GFInstaller


# --- 常量 ---

const _GF_SAVE_GRAPH_UTILITY_SCRIPT = preload("res://addons/gf/extensions/save/graph/gf_save_graph_utility.gd")


# --- 框架内部方法 ---

## 注册 Save 扩展的运行时服务。
## [br]
## @api framework_internal
## [br]
## @param architecture: 要装配的架构实例。
## [br]
## @param _scope: 本轮安装的取消作用域。
func install(architecture: GFArchitecture, _scope: GFAsyncScope) -> void:
	if architecture == null:
		return
	if architecture.get_local_utility(_GF_SAVE_GRAPH_UTILITY_SCRIPT) != null:
		return
	var _registered_save_graph: bool = await architecture.register_utility_instance(_GF_SAVE_GRAPH_UTILITY_SCRIPT.new())
