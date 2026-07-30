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
	var model_registered: bool = await architecture.register_model_instance(BattleModel.new())
	if scope.is_cancel_requested():
		return
	if not model_registered:
		architecture.fail_initialization("BattleModel 注册失败。")
		return

	var utility_registered: bool = await architecture.register_utility_instance(BattleHudUtility.new())
	if scope.is_cancel_requested():
		return
	if not utility_registered:
		architecture.fail_initialization("BattleHudUtility 注册失败。")
		return

	var system_registered: bool = await architecture.register_system_instance(BattleSystem.new())
	if scope.is_cancel_requested():
		return
	if not system_registered:
		architecture.fail_initialization("BattleSystem 注册失败。")
		return


func install_bindings(binder: Variant, _scope: GFAsyncScope) -> void:
	if not binder is GFBinder:
		push_error("BattleContext 收到无效 Binder。")
		return
	var typed_binder: GFBinder = binder
	if not typed_binder.bind_factory(ResolveBattleCommand).as_transient():
		push_error("ResolveBattleCommand 工厂绑定失败。")
```

`SCOPED` 上下文会：

1. 创建新的 `GFArchitecture`。
2. 将最近且已提交 READY 的父级上下文或全局 `Gf` 架构作为父级依赖来源。
3. 在 `auto_init == true` 时编译局部依赖 DAG 并完成四阶段初始化。
4. 只在第四阶段成功、局部架构提交 READY 后发出 `context_ready`。
5. 在节点退出树时同步强制 `dispose()` 局部模块。

如果把 `auto_init` 设为 `false`，Context 仍会创建局部架构并执行 `install()` / `install_bindings()`，但不会自动进入四阶段生命周期。需要在合适的业务时机调用 `await context.initialize_context()`；该方法会等待安装完成、统一触发初始化，并在 stage4 成功或任一阶段失败时沿用 `context_ready` / `context_failed` 语义。第三阶段 `ready()` 完成但 activation 仍在等待时，Context 继续保持未 ready，子树不能提前取得运行时准入。

`install()` 与 `install_bindings()` 收到的 `GFAsyncScope` 是该局部上下文安装过程的取消边界。`SCOPED` 节点退出树、父级架构失败、scope 自取消或上下文失败时，框架会取消 scope 并执行登记的清理回调；安装逻辑中每次 `await` 后都应检查 `scope.is_cancel_requested()`，避免已离树的上下文继续写入外部副作用。每次入树拥有独立 generation，旧协程迟到完成不能修改新一轮安装；Context 的 READY 与 FAILED 互斥，首次失败原因保持稳定。Context 会固定本轮选择的父级 Architecture identity，并在父级首次 READY 后固定其 lifecycle generation；父级声明依赖只有在父 Architecture 已 READY、对应模块已 ACTIVE 时才能满足。install await、局部初始化和 Context READY 期间，父级被替换、失败、dispose 或跨 generation 重试都会让当前 Context fail closed。Scoped Context 一旦进入 FAILED，会立即 dispose 自己拥有的架构并停止 tick，但不会接管父级的释放；若 owned Architecture 在 READY 后被外部 dispose，Context 也会撤销 READY 并进入 FAILED。Inherited Context 不拥有共享架构，因此失败时同样不会替父级执行 dispose。

如果把 `process_scoped_ticks` 设为 `false`，该 Context 只负责创建和生命周期管理，不再驱动局部架构的 `tick()` / `physics_tick()`。这种模式适合由外部调度器统一驱动局部架构；否则局部 `GFSystem.tick()` 和 `GFUtility.tick()` 不会自动执行。

如果只想让某个节点树分支复用父级上下文，可以把 `scope_mode` 设为 `INHERITED`。继承模式不会创建或释放局部架构，但只会在继承架构完成 activation 并提交 READY 后发出同样的 `context_ready` 信号；如果父级架构稍后才初始化完成，上下文会等待后再发出信号。继承来源在本轮入树期间不会热迁移：全局或最近父 Context 改成另一 Architecture 时，当前 Inherited Context 会失败，调用方应让对应场景分支退出并重新进入以建立新 generation。等待、安装和 READY 期间若继承架构或 Scoped 架构的父级初始化失败、进入 quiescing/dispose 或 lifecycle generation 漂移，Context 会立即进入 `FAILED` 并发出 `context_failed`；即使 `context_wait_timeout_seconds <= 0`，也不会对不可恢复的生命周期终态永久逐帧等待。`FAILED` 是当前 Context generation 的终态：即使共享 Architecture 随后以同一 identity 重试并重新 READY，该 Context 子树中的 `GFController` 仍不会恢复事件绑定，也不会通过架构、模块、命令、查询或事件代理访问它；无 Context 的全局 Controller 不受此限制，可随全局 Architecture 重试正常恢复。

局部上下文中的 `GFController` 无需额外传参，会自动沿父节点查找最近的 `GFNodeContext`。注册到局部上下文的 `GFSystem` / `GFModel` / `GFUtility` 也会在注册时获得当前架构引用，因此基类提供的 `get_model()`、`get_system()`、`get_utility()` 会优先使用局部架构，并在本地未命中时回退父架构。

这个解析规则依赖真实节点父链。当前 `GFUIUtility` 会把 HUD、POPUP、TOP 层创建在 `SceneTree.root` 下，并把入栈 Panel 重挂到对应根级 `CanvasLayer`。因此通过 UI 栈打开的 Panel 不再是原局部 Context 的后代；若 Panel 自身未再创建新 Context，其中的 `GFController` 会回退到全局架构。即使 `GFUIUtility` 本身注册在局部架构中，也不会改变 Panel 的父链。

必须消费局部 Model / System 的 HUD 应保留在 Context 子树内，例如把场景自己的 `CanvasLayer` 作为 `GFNodeContext` 子节点。全局菜单、跨场景提示和只消费全局模块的 HUD 仍适合 `GFUIUtility`。根级 Panel 若只需短暂展示局部结果，可通过配置回调传入 DTO 或项目适配器，并在 Context 退出前关闭，不应长期缓存局部模块。

如果 Controller 需要在 `_ready()` 中立刻访问 scoped 架构，而该架构还在异步初始化，可以等待上下文就绪。等待失败、父级架构初始化失败或上下文超时时会返回 `null`，调用方应显式处理：

```gdscript
func _ready() -> void:
	var architecture := await wait_for_context_ready()
	if architecture == null:
		return
	var battle_model := architecture.get_model(BattleModel) as BattleModel
	_refresh(battle_model)
```

普通节点也可以直接等待 `GFNodeContext.wait_until_ready()`，它会在当前上下文架构及本轮固定父级都保持有效时返回可用的 `GFArchitecture`；如果上下文或父级架构失败、等待目标已经 dispose、父级 identity 被替换或 generation 漂移，则返回 `null` 并发出 `context_failed`。`context_ready` 是同步信号；如果 listener 在回调中 dispose 架构、替换父级 identity 或让 Context 离树，`initialize_context()` / `wait_until_ready()` 会在返回前重新验证当前 generation，不会把回调已经失效的架构返回给等待方。`GFArchitecture.is_disposed()` 可用于项目自己的等待器辨认这一不可恢复终态。

## 正常关闭与离树兜底

`GFNodeContext` 不增加第二个架构关闭入口。项目能控制关闭时机，并且局部 Storage、Save Profile 或后台任务需要 drain，应先取得 owned architecture，直接等待 `shutdown_async()`，确认 typed result 后再让 Context 离树：

```gdscript
var local_architecture: GFArchitecture = context.get_architecture()
var result: GFArchitectureShutdownResult = (
	await local_architecture.shutdown_async()
)
if not result.is_successful():
	push_warning(result.get_error())
context.queue_free()
```

父级 Architecture 必须 outlive scoped child：先等待并释放所有 child，再关闭提供依赖的 parent。节点 `_exit_tree()` 无法可靠 `await`，因此始终调用同步 `dispose()` 作为 forced fallback。它保证模块最终释放且重复调用幂等，但不保证已接纳异步操作正常完成；数据关键路径不能把 `queue_free()` 当作 flush。
