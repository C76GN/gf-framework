# 显式依赖

能力可以声明依赖，`GFCapabilityUtility` 会在挂载当前能力前先补齐依赖能力。

```gdscript
class_name DamageableCapability
extends GFCapability

func _init() -> void:
	required_capabilities = [HealthCapability]

func take_damage(amount: int) -> void:
	var health := get_capability(HealthCapability) as HealthCapability
	health.health = maxi(health.health - amount, 0)
```

GF 不使用隐式构造函数参数注入，依赖关系应优先通过 `required_capabilities` 显式声明，便于编辑器检查、搜索、测试和排错。节点能力放在场景中时，可以直接在 Inspector 的 `required_capabilities` 数组里配置依赖；纯代码能力如果需要类级默认依赖，可以在 `_init()` 中设置该数组。

依赖类型可以写基类，但解析必须唯一：精确类型优先；没有精确类型时，唯一子类实现可以满足依赖；两个或更多子类同时匹配同一基类时属于歧义，运行时拒绝挂载，Inspector 校验报告 `ambiguous_required_capability`。这与“完全缺失依赖”是不同状态，不会按遇到的第一个子类继续。

`GFCapabilityUtility` 会在调用 `on_gf_capability_added()` 前写入能力实例的 `receiver` 字段，并在 `on_gf_capability_removed()` 后清空它；因此 Hook 内可以直接使用 `receiver` 或 `get_capability()` 查询同一 receiver 上已补齐的依赖能力。

添加 Hook 看到的是已经提交的注册记录，移除 Hook 看到的是已经摘除的记录；同一类型在 Hook 返回前不能重入另一项注册事务。Hook 或信号监听器如果同步释放 receiver / capability，Utility 会在回调边界重新检查存活性，并通过开始时冻结的事务令牌清理内部状态，不会再把已释放对象传给后续强类型步骤。

重写 Hook 时仍建议调用 `super`，便于兼容基类后续扩展，但依赖查询不再依赖项目脚本手动调用 `super`。

## 依赖移除策略

从 `2.0.0` 起，移除主能力时默认会清理“仅由它自动补齐且未被用户显式添加”的依赖能力。用户显式添加的依赖、或仍被其他能力依赖的能力不会被级联移除。

若某个能力希望依赖在主能力移除后继续保留，可重写：

```gdscript
func get_dependency_removal_policy() -> int:
	return GFCapabilityUtility.DependencyRemovalPolicy.KEEP_DEPENDENCIES
```
