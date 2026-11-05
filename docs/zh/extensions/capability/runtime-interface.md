# Capability 运行时接口与 Utility 注册

这一页说明 Capability 作为 receiver 上的小型运行时接口时应承担的职责，以及 `GFCapabilityUtility` 的注册方式。

## 作为运行时接口

Capability 可以被项目当作运行时接口使用：系统、交互逻辑或技能逻辑查询 receiver 是否拥有某个能力类型，再只依赖该能力公开的方法和数据，而不依赖 receiver 的具体脚本类。例如 `InteractableCapability`、`DamageableCapability`、`SelectableCapability` 这类小契约，适合表达“这个对象支持交互 / 承伤 / 选中”，并允许敌人、道具、UI 控件或临时生成对象用不同场景结构实现同一能力。

这种用法应保持能力职责小而稳定。能力脚本可以持有局部状态、引用 receiver、实现 Hook、声明 `required_capabilities`，但不应变成包含移动、战斗、存档、UI 和任务规则的巨大对象；需要全局调度、跨实体缓存、Tick 顺序或长期核心数据时，应把这些职责放回 `GFSystem`、`GFUtility`、`GFModel` 或项目自己的资源，再让 Capability 只作为 receiver 上的查询入口和局部行为适配层。能力实例也具有单一 receiver 语义，同一个实例不要复用到多个对象；复用配置时用新实例或 `GFCapabilityRecipe`。同一实例不能在同一 receiver 上重复建立不同声明类型的记录；已有具体类型记录仍可通过基类查询和复用。

`GFCapabilityUtility.dispose()` 只注销由该 Utility 实际登记、且登记身份与实例都仍匹配的能力；由 Utility 创建或实例化的能力会一起释放，外部传入或场景中已有的能力只解除登记。多个 Utility 仍可查询同一 receiver 的共享能力，加入查询分组或读取已有能力不会取得自动注销权。其他 Utility 替换的同类型实例也不会被旧 Utility 的销毁误删；即使移除后重新登记的是同一个外部实例，新登记也不会继承旧 Utility 的注销资格。

跨 Utility 依赖仍遵守“依赖者尚在时拒绝移除”的规则。销毁不会接管或级联清理其他 Utility 的能力；被依赖阻止的登记保留在原 Utility 中，待依赖者移除后可再次调用 `dispose()`。协调多个 Utility 生命周期的项目应按依赖者先于依赖项的顺序销毁，并保留尚未清理完成的 Utility 引用。


## 注册 Utility

```gdscript
## 在项目 Installer 的绑定阶段注册单例，由架构管理其初始化与释放。
func install_bindings(binder: Variant, _scope: GFAsyncScope) -> void:
	binder.bind_utility(GFCapabilityUtility).as_singleton()
```
