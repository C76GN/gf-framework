# 短生命周期对象工厂

如果一个对象不需要进入框架生命周期，但创建时又需要当前架构依赖，可以使用工厂。常见场景是 Command、Query、规则对象或一次性流程对象。

## 注册与创建

```gdscript
var registered := architecture.register_factory(DealDamageCommand, func() -> Object:
	return DealDamageCommand.new()
)

var command := architecture.create_instance(DealDamageCommand) as DealDamageCommand
command.execute()
```

工厂默认是 `GFBindingLifetimes.Lifetime.TRANSIENT`。每次 `create_instance()` 都会调用 provider，并把返回对象注入发起解析的架构。通常 provider 会创建新对象，但框架不会强制校验对象唯一性；如果 provider 自己返回缓存对象，transient 也会返回该对象。
`register_factory()`、`replace_factory()`、`register_factory_instance()`、`replace_factory_instance()` 和 `unregister_factory()` 都返回 `bool`；重复注册、无效生命周期或 dispose 后写入会返回 `false`。

`GFBinding` 是架构内部保存 provider、生命周期、singleton 缓存和解析回滚状态的记录类型。项目代码不应直接构造、缓存或修改它；通过上述工厂注册 API 表达所有权，才能让循环检测、失败链回滚和架构释放保持完整。

## 生命周期策略

如果希望明确复用同一个对象，可以显式注册为 `GFBindingLifetimes.Lifetime.SINGLETON`，或使用 `register_factory_instance()` 暴露已有实例。

```gdscript
var registered_command_factory := architecture.register_factory(
	DealDamageCommand,
	func() -> Object:
		return DealDamageCommand.new(),
	GFBindingLifetimes.Lifetime.TRANSIENT
)

var registered_rule_set := architecture.register_factory_instance(BattleRuleSet, BattleRuleSet.new())
```

当子架构回退到父级工厂时，transient 工厂会把发起请求的子架构注入新对象，适合局部关卡命令继续访问本地模块。singleton 工厂始终由拥有该绑定的架构持有和注入。

## 使用边界

替换、注销工厂或销毁架构时，框架会清理已缓存 singleton 实例的 owner 事件监听并释放依赖作用域。由工厂 callback 创建并由绑定缓存的实例会调用自身 `dispose()`。

通过 `register_factory_instance()` / `replace_factory_instance()` 传入的外部实例默认不由框架 dispose，避免项目对象被解绑工厂时意外销毁。外部继续持有已解绑对象时，不应再通过它访问旧架构。

`with_alias()` 只适用于 `Model`、`System` 和 `Utility`，用于 factory 绑定时会被忽略并输出 warning。
