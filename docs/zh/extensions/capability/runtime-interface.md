# Capability 运行时接口与 Utility 注册

这一页说明 Capability 作为 receiver 上的小型运行时接口时应承担的职责，以及 `GFCapabilityUtility` 的注册方式。

## 作为运行时接口

Capability 可以被项目当作运行时接口使用：系统、交互逻辑或技能逻辑查询 receiver 是否拥有某个能力类型，再只依赖该能力公开的方法和数据，而不依赖 receiver 的具体脚本类。例如 `InteractableCapability`、`DamageableCapability`、`SelectableCapability` 这类小契约，适合表达“这个对象支持交互 / 承伤 / 选中”，并允许敌人、道具、UI 控件或临时生成对象用不同场景结构实现同一能力。

这种用法应保持能力职责小而稳定。能力脚本可以持有局部状态、引用 receiver、实现 Hook、声明 `required_capabilities`，但不应变成包含移动、战斗、存档、UI 和任务规则的巨大对象；需要全局调度、跨实体缓存、Tick 顺序或长期核心数据时，应把这些职责放回 `GFSystem`、`GFUtility`、`GFModel` 或项目自己的资源，再让 Capability 只作为 receiver 上的查询入口和局部行为适配层。能力实例也具有单一 receiver 语义，同一个实例不要复用到多个对象；复用配置时用新实例或 `GFCapabilityRecipe`。当架构销毁时，`GFCapabilityUtility.dispose()` 会注销仍在索引中的 receiver 能力；由 Utility 创建或实例化的能力会一起释放，外部传入或场景中已有的能力只解除登记。


## 注册 Utility

```gdscript
func install_bindings(binder: Variant, _scope: GFAsyncScope) -> void:
	binder.bind_utility(GFCapabilityUtility).as_singleton()
```
