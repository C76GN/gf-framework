# Kernel 场景级局部上下文

这一页说明 `GFNodeContext` 如何为关卡、战斗房间、测试场景或调试面板创建局部架构，并与父级架构或全局 `Gf` 协作。

## 场景级局部上下文

对于关卡、战斗房间、测试场景或调试面板，可以使用 `GFNodeContext` 创建随场景存在的局部架构：

```gdscript
class_name BattleContext
extends GFNodeContext


func _init() -> void:
	scope_mode = GFNodeContext.ScopeMode.SCOPED


func install(architecture: GFArchitecture, scope: GFAsyncScope) -> void:
	await architecture.register_system_instance(BattleSystem.new())
	if scope.is_cancel_requested():
		return
	await architecture.register_utility_instance(BattleHudUtility.new())


func install_bindings(binder: Variant, _scope: GFAsyncScope) -> void:
	binder.bind_factory(ResolveBattleCommand).as_transient()
```

`SCOPED` 上下文会：

1. 创建新的 `GFArchitecture`。
2. 将最近的父级上下文或全局 `Gf` 架构作为父级依赖来源。
3. 在 `auto_init == true` 时自动初始化局部模块。
4. 在节点退出树时自动 `dispose()` 局部模块。

如果把 `auto_init` 设为 `false`，Context 仍会创建局部架构并执行 `install()` / `install_bindings()`，但不会自动进入三阶段生命周期。需要在合适的业务时机调用 `await context.initialize_context()`；该方法会等待安装完成、统一触发初始化，并在成功或失败时沿用 `context_ready` / `context_failed` 语义。

`install()` 与 `install_bindings()` 收到的 `GFAsyncScope` 是该局部上下文安装过程的取消边界。`SCOPED` 节点退出树、父级架构失败或上下文失败时，框架会取消 scope 并执行登记的清理回调；安装逻辑中每次 `await` 后都应检查 `scope.is_cancel_requested()`，避免已离树的上下文继续写入外部副作用。

如果把 `process_scoped_ticks` 设为 `false`，该 Context 只负责创建和生命周期管理，不再驱动局部架构的 `tick()` / `physics_tick()`。这种模式适合由外部调度器统一驱动局部架构；否则局部 `GFSystem.tick()` 和 `GFUtility.tick()` 不会自动执行。

如果只想让某个节点树分支复用父级上下文，可以把 `scope_mode` 设为 `INHERITED`。继承模式不会创建或释放局部架构，但会在继承到的架构 ready 后发出同样的 `context_ready` 信号；如果父级架构稍后才初始化完成，上下文会等待后再发出信号。

局部上下文中的 `GFController` 无需额外传参，会自动沿父节点查找最近的 `GFNodeContext`。注册到局部上下文的 `GFSystem` / `GFModel` / `GFUtility` 也会在注册时获得当前架构引用，因此基类提供的 `get_model()`、`get_system()`、`get_utility()` 会优先使用局部架构，并在本地未命中时回退父架构。

如果 Controller 需要在 `_ready()` 中立刻访问 scoped 架构，而该架构还在异步初始化，可以等待上下文就绪。等待失败、父级架构初始化失败或上下文超时时会返回 `null`，调用方应显式处理：

```gdscript
func _ready() -> void:
	var architecture := await wait_for_context_ready()
	if architecture == null:
		return
	var battle_model := architecture.get_model(BattleModel) as BattleModel
	_refresh(battle_model)
```

普通节点也可以直接等待 `GFNodeContext.wait_until_ready()`，它会在当前上下文架构真正就绪后返回可用的 `GFArchitecture`；如果上下文或父级架构失败，则返回 `null` 并发出 `context_failed`。
