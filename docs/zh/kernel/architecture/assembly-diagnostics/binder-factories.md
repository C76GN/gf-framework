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

## 必需绑定计划

单个 Installer 有多项不可缺少的绑定时，可以显式创建 `GFBindingPlan`，避免为每个 `bool` 重复编写失败、取消和提前返回逻辑：

```gdscript
func install_bindings(binder: Variant, scope: GFAsyncScope) -> void:
	if not binder is GFBinder:
		return

	var typed_binder: GFBinder = binder
	var plan: GFBindingPlan = typed_binder.create_required_plan()
	plan = plan.require_singleton(
		&"player_model",
		typed_binder.bind_model(PlayerModel)
	).require_singleton(
		&"config_provider",
		typed_binder.bind_utility(JSONConfigProvider).with_alias(GFConfigProvider)
	).require_transient(
		&"damage_command",
		typed_binder.bind_factory(DealDamageCommand).from_factory(
			func() -> Object:
				return DealDamageCommand.new()
		)
	)

	var result: GFBindingPlanResult = plan.execute(scope)
	if not result.is_successful():
		print(result.to_dict())
		return
```

Plan 只接纳同一 Architecture 的 Builder，并在 `require_singleton()` / `require_transient()` 时冻结来源、目标、别名和生命周期配置；之后继续修改原 Builder 不会改变已声明 entry。它只用于尚未进入初始化阶段的 candidate Architecture，并且只能执行一次。READY Architecture、执行中的重入和已结算 replay 都会在不 claim 新 scope、不中断活动 Architecture、也不执行 entry 的前提下返回拒绝结果；READY 后的模块变化继续使用热拓扑事务。

entry 严格按声明顺序执行。首个失败先冻结 `GFBindingPlanResult`，再让 candidate Architecture 保留该首因并进入初始化失败，最后结算仍活动的 Installer scope；这一顺序避免 scope cleanup 重入覆盖原始错误。失败会阻止后续 entry，并由 Architecture 回滚本轮候选装配；成功不会替 Installer 调用 `scope.complete()`。`Status`、`BindingKind`、`Phase` 与 `Reason` 是机器判断入口，`binding_id` 最长 128 字符，`target_path` 与 `detail` 最长 512 字符；`detail` 只适合展示，不应作为稳定分支键。

生命周期模块的 SELF 或 `from_factory()` 来源回调会在 Plan 执行时同步创建 candidate，回调必须同步返回与声明目标兼容的 `Object`；返回 coroutine 或错误类型会作为创建失败。生命周期 `from_instance()` 在 Architecture 准入前仍由调用方拥有；一旦进入依赖注入与注册结算，成功移交或失败清理均由 Architecture 精确处理，调用方不得再据 `bool` 猜测释放权。

`bind_factory(...).from_factory(...)` 的 Callable 则只是 deferred provider：Plan 只验证 factory binding 能否注册，不会提前调用 provider，也不保证它未来创建的对象类型或业务有效性；这些错误会在 READY 后真正解析对象时出现。`bind_factory(...).from_instance(...)` 的外部实例始终由调用方拥有，无论 legacy 或 required 路径成功、失败回滚还是 Architecture dispose，框架都只撤销自己建立的依赖注入作用域与 owner 事件监听，不会调用外部实例的 `dispose()` 或 `free()`。

## 使用边界

`Model`、`System`、`Utility` 都是生命周期模块，只支持单例式注册；`as_transient()` 只适合短生命周期工厂对象，`.with_alias()` 也只对生命周期模块生效。

对于不需要进入生命周期的短生命周期对象，`GFArchitecture` 提供轻量工厂能力。详细注册、生命周期和父子架构回退规则见 [生命周期、装配与依赖](../../lifecycle/index.md)。

工厂适合 Command、Query、技能执行载体等一次性对象，不建议用于需要参与 `init()`、`tick()`、`dispose()` 的长期模块。

当子架构回退到父级工厂时，transient 工厂创建的对象会注入发起解析的子架构，从而优先访问当前局部上下文。

singleton 工厂通过 SELF 或 Callable 创建的缓存 candidate 由拥有该 binding 的 Architecture 持有和注入，并在工厂替换、注销或架构销毁时清理 owner 事件监听、调用 `dispose()`（如果存在）和释放依赖作用域。`from_instance()` factory 是上面的 caller-owned 例外，不随 Architecture dispose 释放。
