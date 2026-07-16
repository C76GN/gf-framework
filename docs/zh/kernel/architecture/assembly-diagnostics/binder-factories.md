# 声明式装配与工厂

从 `1.9.1` 起，Installer 与 NodeContext 可以使用声明式装配器。

## 典型流程

```gdscript
func install_bindings(binder: Variant, _scope: GFAsyncScope) -> void:
	if not binder is GFBinder:
		return

	await _register_project_bindings(binder)


func _register_project_bindings(binder: GFBinder) -> void:
	var _registered_player_model: bool = await binder.bind_model(PlayerModel).as_singleton()
	var _registered_config_provider: bool = await binder.bind_utility(JSONConfigProvider).with_alias(GFConfigProvider).as_singleton()
	var _registered_damage_factory: bool = binder.bind_factory(DealDamageCommand).from_factory(func() -> Object:
		return DealDamageCommand.new()
	).as_transient()
```

声明式装配不会替代原有 `register_model_instance()`、`register_system_instance()`、`register_utility_instance()`。它只是把“绑定来源、别名和生命周期”集中写清楚，适合大型项目或插件式模块。

## 核心类

声明式装配器由 `GFBinder` 和 `GFBindBuilder` 提供：`GFBinder` 是传给 Installer 的入口对象，负责创建 `bind_model()`、`bind_system()`、`bind_utility()`、`bind_factory()` 这些绑定链；这些入口会返回明确的 `GFBindBuilder`，由 Builder 承接 `.from_factory()`、`.from_instance()`、`.with_alias()`、`.as_singleton()`、`.as_transient()` 等声明。完成入口返回 `bool`，调用方可以在 Installer 或测试中直接判断绑定是否成功。

`GFInstaller.install_bindings()` 的 binder 参数仍是 `Variant`，因为它是框架生命周期钩子；第二个参数 `GFAsyncScope` 表示本轮安装的协作取消边界。项目代码进入声明式链之前应先把 binder 收窄为 `GFBinder`，之后就可以保持完整的类型提示和补全。

## 使用边界

`Model`、`System`、`Utility` 都是生命周期模块，只支持单例式注册；`as_transient()` 只适合短生命周期工厂对象，`.with_alias()` 也只对生命周期模块生效。

对于不需要进入生命周期的短生命周期对象，`GFArchitecture` 提供轻量工厂能力。详细注册、生命周期和父子架构回退规则见 [生命周期、装配与依赖](../../lifecycle/index.md)。

工厂适合 Command、Query、技能执行载体等一次性对象，不建议用于需要参与 `init()`、`tick()`、`dispose()` 的长期模块。

当子架构回退到父级工厂时，transient 工厂创建的对象会注入发起解析的子架构，从而优先访问当前局部上下文。

singleton 工厂仍由拥有该绑定的架构持有和注入，并在工厂替换、注销或架构销毁时清理缓存实例的 owner 事件监听、调用 `dispose()`（如果存在）和释放依赖作用域。
