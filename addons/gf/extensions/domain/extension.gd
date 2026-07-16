# GF Domain 扩展安装器。
extends GFInstaller


# --- 框架内部方法 ---

## 注册 Domain 扩展的运行时服务。
## [br]
## @api framework_internal
## [br]
## @param architecture: 要装配的架构实例。
## [br]
## @param _scope: 本轮安装的取消作用域。
func install(architecture: GFArchitecture, _scope: GFAsyncScope) -> void:
	if architecture == null:
		return
	if architecture.get_local_utility(GFLevelUtility) == null:
		var _registered_level: bool = await architecture.register_utility_instance(GFLevelUtility.new())
	if architecture.get_local_utility(GFQuestUtility) == null:
		var _registered_quest: bool = await architecture.register_utility_instance(GFQuestUtility.new())
