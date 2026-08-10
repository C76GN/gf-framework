# GF Domain 扩展安装器。
extends GFInstaller


# --- 框架内部方法 ---

## 注册 Domain 扩展的运行时服务。
## [br]
## @api framework_internal
## [br]
## @param architecture: 要装配的架构实例。
## [br]
## @param scope: 本轮安装的取消作用域。
func install(architecture: GFArchitecture, scope: GFAsyncScope) -> void:
	if _should_stop_installation(architecture, scope):
		return
	if architecture.get_local_utility(GFLevelUtility) == null:
		var registered_level: bool = await architecture.register_utility_instance(
			GFLevelUtility.new()
		)
		if _should_stop_installation(architecture, scope):
			return
		if not registered_level:
			architecture.fail_initialization(
				"[GFDomainExtension] GFLevelUtility registration failed."
			)
			return
	if architecture.get_local_utility(GFQuestUtility) == null:
		var registered_quest: bool = await architecture.register_utility_instance(
			GFQuestUtility.new()
		)
		if _should_stop_installation(architecture, scope):
			return
		if not registered_quest:
			architecture.fail_initialization(
				"[GFDomainExtension] GFQuestUtility registration failed."
			)


func _should_stop_installation(
	architecture: GFArchitecture,
	scope: GFAsyncScope
) -> bool:
	return (
		architecture == null
		or scope == null
		or not scope.is_active()
		or architecture.has_initialization_failed()
		or architecture.is_disposed()
	)
