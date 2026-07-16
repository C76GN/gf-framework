# 工厂注入

如果命令或查询内部会调用 `get_model()`、`get_system()`、`get_utility()`，推荐通过架构工厂创建实例，而不是直接 `new()`。这样对象会自动接收当前 `GFArchitecture` 注入，在 `GFNodeContext` 局部上下文中也能优先访问本地模块。

局部上下文中的 Command / Query 应通过当前 architecture 的 `create_instance()`、`send_command()`、`send_query()` 或显式 `inject_dependencies()` 进入执行流程。

## 注册工厂

```gdscript
func install_bindings(binder: Variant, _scope: GFAsyncScope) -> void:
	binder.bind_factory(TakeDamageCommand).as_transient()
	binder.bind_factory(GetPlayerTotalAttackPowerQuery).as_transient()
```

## 创建并执行

```gdscript
var command := Gf.create_instance(TakeDamageCommand) as TakeDamageCommand
command.target_id = "monster_99"
command.raw_damage = 999
Gf.send_command(command)

var query := Gf.create_instance(GetPlayerTotalAttackPowerQuery) as GetPlayerTotalAttackPowerQuery
var final_atk := Gf.send_query(query) as float
```

工厂默认生命周期是 `GFBindingLifetimes.Lifetime.TRANSIENT`，每次解析都会调用 provider，通常用于创建新的 Command / Query，适合携带本次执行参数的对象。

框架不会强制校验 provider 返回的一定是新对象；如果需要复用昂贵的无状态执行器，可以用 `register_factory(..., GFBindingLifetimes.Lifetime.SINGLETON)` 或 `register_factory_instance()`，但不要把带有本次执行参数的命令注册成 singleton。

当局部架构回退到父级 transient 工厂时，新对象会注入发起解析的局部架构；singleton 工厂则始终注入拥有该绑定的架构。这使全局工厂定义可以服务局部场景，同时保留单例对象的稳定归属。

singleton 工厂被替换、注销或随架构销毁时，缓存实例会清理 owner 事件监听、执行 `dispose()`（如果存在）并释放依赖作用域。
