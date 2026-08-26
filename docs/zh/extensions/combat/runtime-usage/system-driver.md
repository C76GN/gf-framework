# 系统驱动与装配

`GFCombatSystem` 继承自 `GFSystem`，负责在每一帧更新所有已注册实体的 Buff 和技能状态。Combat 扩展启用并允许自动装配 Installer 时，会自动注册 `GFCombatSystem` 与 `GFSkillTargetingUtility2D`；项目 Installer 不需要重复注册它们。

只有在禁用自动装配或需要替换默认实现时，才手动装配：

```gdscript
func install(architecture: GFArchitecture, _scope: GFAsyncScope) -> void:
	var combat_sys := GFCombatSystem.new()
	await architecture.register_system_instance(combat_sys)
```

手动装配时，项目需要保证系统只注册一次，并明确自己的 Installer 顺序。扩展自动装配、启用状态和 Installer 规则见[扩展启用与装配](../../installation.md)。
