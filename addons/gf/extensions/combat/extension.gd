# GF Combat 扩展安装器。
extends GFInstaller


# --- 常量 ---

const _GF_COMBAT_SYSTEM_SCRIPT = preload("res://addons/gf/extensions/combat/core/gf_combat_system.gd")
const _GF_SKILL_TARGETING_UTILITY_2D_SCRIPT = preload("res://addons/gf/extensions/combat/skills/gf_skill_targeting_utility_2d.gd")


# --- 框架内部方法 ---

## 注册 Combat 扩展的运行时服务。
## [br]
## @api framework_internal
## [br]
## @param architecture: 要装配的架构实例。
## [br]
## @param _scope: 本轮安装的取消作用域。
func install(architecture: GFArchitecture, _scope: GFAsyncScope) -> void:
	if architecture == null:
		return
	if architecture.get_local_utility(_GF_SKILL_TARGETING_UTILITY_2D_SCRIPT) == null:
		var _registered_skill_targeting: bool = await architecture.register_utility_instance(_GF_SKILL_TARGETING_UTILITY_2D_SCRIPT.new())
	if architecture.get_local_system(_GF_COMBAT_SYSTEM_SCRIPT) == null:
		var _registered_combat_system: bool = await architecture.register_system_instance(_GF_COMBAT_SYSTEM_SCRIPT.new())
