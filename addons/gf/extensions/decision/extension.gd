# GF Decision 扩展安装器。
extends GFInstaller


# --- 常量 ---

const _GF_DECISION_UTILITY_SCRIPT = preload("res://addons/gf/extensions/decision/runtime/gf_decision_utility.gd")


# --- 框架内部方法 ---

## 注册 Decision 扩展的运行时服务。
## [br]
## @api framework_internal
## [br]
## @param architecture: 要装配的架构实例。
## [br]
## @param _scope: 本轮安装的取消作用域。
func install(architecture: GFArchitecture, _scope: GFAsyncScope) -> void:
	if architecture == null:
		return
	if architecture.get_local_utility(_GF_DECISION_UTILITY_SCRIPT) != null:
		return
	var _registered_decision: bool = await architecture.register_utility_instance(_GF_DECISION_UTILITY_SCRIPT.new())
