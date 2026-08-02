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

`create_instance()` 是运行时准入入口，不是装配期探测接口。只有 Architecture 已经完成第四阶段并处于 READY，且没有正在提交的热模块拓扑事务时，框架才会调用 provider；初始化、activation、拓扑事务、quiesce 和 dispose 期间都在 provider 发生任何副作用前返回 `null`。装配期只检查 binding 是否存在时使用 `has_factory()` 或声明 `get_required_factories()`，不要通过试创建验证工厂。

每次解析都会在调用 provider 前固定 binding owner 与真实 requester 的生命周期 generation，并在 provider 返回后以及每个依赖注入 Hook 后复核准入、解析事务和实例存活状态。任一参与架构关闭运行时准入会立即使共享解析上下文失败；此后嵌套 `create_instance()` 会在 factory 查找、缓存读取或 provider 调用前短路。任一 Hook 触发嵌套解析失败、让 Node 进入待释放状态，或尝试在解析栈内重入修改模块拓扑，也会立即停止后续 Hook 并使整条解析失败。框架不会缓存或交付失效结果，只在实际注入目标上清理本次建立的事件与依赖作用域，并始终保留 `register_factory_instance()` 外部实例的所有权。解析回滚只清理 Binding 仍持有的缓存，关闭流程已经取得释放权的 Singleton 不会被二次释放。

Transient 的所有权在它自己的 `create_instance()` 成功返回时转给直接调用者，即使该调用者是另一个 provider。外层解析之后失败不会追溯释放已经交付的 Transient；直接调用者必须接管其成功路径与失败路径清理。若业务需要一组 Transient 在更大范围内原子提交，应使用显式的领域事务或所有权收养协议，不能把普通 `create_instance()` 的返回值假定为隐式 provisional 对象。

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
