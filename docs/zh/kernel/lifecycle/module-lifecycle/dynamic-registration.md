# 初始化后的动态注册

自 `1.6.0` 起，如果架构已经完成 `Gf.init()`，之后再注册新的 Model、System 或 Utility，框架会为新模块自动补跑完整生命周期：

```text
init() -> async_init() -> ready()
```

这适合运行时加载关卡专属系统、DLC 模块、调试工具或临时玩法模块。

```gdscript
await Gf.init()

var battle_system := BattleSystem.new()
await Gf.register_system(battle_system)
# battle_system 会自动完成三阶段生命周期，随后参与 tick / physics_tick。
```

如果动态模块在 `async_init()` 中等待资源或网络流程，而调用点需要确认它已经完全 ready，可以直接使用底层架构方法并 `await`：

```gdscript
await Gf.get_architecture().register_utility_instance(RuntimeConfigProvider.new())
```

动态注册和替换采用 prepare / commit / rollback 事务。injection、`init()`、`async_init()` 或 `ready()` 中发生取消、失败、dispose 或同 key 重入时，候选实例不会留在 registry；其 service、event、injection scope 等副作用会一起回滚。替换过程中如果用户回调注册了更新实例，外层旧事务会返回失败，不会覆盖最新结果。

动态注册仍应遵守依赖边界。长期跨场景服务应在项目 Installer 中注册；关卡专属或临时模块应在卸载时明确注销，或通过场景切换瞬态清理机制处理。注册返回 `false` 时不得把候选视为已归属架构；调用方应释放自己的外部资源或创建新候选重试。
