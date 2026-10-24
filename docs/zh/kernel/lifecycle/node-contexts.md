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
5. 可控退出先等待 `context.close_async()` 完成，再移除节点；直接退出树则同步强制 `dispose()` 局部模块。

正常关闭期间，Context 停止报告 READY，`is_context_available()` 返回 `false`，`wait_until_ready()` 与 `initialize_context()` 返回 `null`。`context_closing` 会立即撤销子树 Controller 的事件绑定，不会把跨帧 quiesce 转成强制释放。正常关闭结束不会发出 `context_failed`；`close_async()` 的结果分别说明上下文是否已关闭、工作是否完成静默关闭。直接调用 Architecture 的 `dispose()`、父级失效和节点离树仍沿用各自的失效或强制释放规则。

如果把 `auto_init` 设为 `false`，Context 仍会创建局部架构并执行 `install()` / `install_bindings()`，但不会自动进入四阶段生命周期。需要在合适的业务时机调用 `await context.initialize_context()`；该方法会等待安装完成、统一触发初始化，并在 stage4 成功或任一阶段失败时沿用 `context_ready` / `context_failed` 语义。第三阶段 `ready()` 完成但 activation 仍在等待时，Context 继续保持未 ready，子树不能提前取得运行时准入。

`install()` 与 `install_bindings()` 收到的 `GFAsyncScope` 是该局部上下文安装过程的取消边界。`SCOPED` 节点退出树、父级架构失败、scope 自取消或上下文失败时，框架会取消 scope 并执行登记的清理回调；安装逻辑中每次 `await` 后都应检查 `scope.is_cancel_requested()`，避免已离树的上下文继续写入外部副作用。每次入树拥有独立 generation，旧协程迟到完成不能修改新一轮安装；Context 的 READY 与 FAILED 互斥，首次失败原因保持稳定。Context 会固定本轮选择的父级 Architecture identity，并在父级首次 READY 后固定其 lifecycle generation；父级声明依赖只有在父 Architecture 已 READY、对应模块已 ACTIVE 时才能满足。install await、局部初始化和 Context READY 期间，父级被替换、失败、dispose 或跨 generation 重试都会让当前 Context fail closed。Scoped Context 一旦进入 FAILED，会立即 dispose 自己拥有的架构并停止 tick，但不会接管父级的释放；若 owned Architecture 在 READY 后被外部 dispose，Context 也会撤销 READY 并进入 FAILED。Inherited Context 不拥有共享架构，因此失败时同样不会替父级执行 dispose。

如果把 `process_scoped_ticks` 设为 `false`，该 Context 只负责创建和生命周期管理，不再驱动局部架构的 `tick()` / `physics_tick()`。这种模式适合由外部调度器统一驱动局部架构；否则局部 `GFSystem.tick()` 和 `GFUtility.tick()` 不会自动执行。

如果只想让某个节点树分支复用父级上下文，可以把 `scope_mode` 设为 `INHERITED`。继承模式不会创建或释放局部架构，但只会在继承架构完成 activation 并提交 READY 后发出同样的 `context_ready` 信号；如果父级架构稍后才初始化完成，上下文会等待后再发出信号。继承来源在本轮入树期间不会热迁移：全局或最近父 Context 改成另一 Architecture 时，当前 Inherited Context 会失败，调用方应让对应场景分支退出并重新进入以建立新 generation。等待、安装和 READY 期间若继承架构或 Scoped 架构的父级初始化失败、进入 quiescing/dispose 或 lifecycle generation 漂移，Context 会立即进入 `FAILED` 并发出 `context_failed`；即使 `context_wait_timeout_seconds <= 0`，也不会对不可恢复的生命周期终态永久逐帧等待。`FAILED` 是当前 Context generation 的终态：即使共享 Architecture 随后以同一 identity 重试并重新 READY，该 Context 子树中的 `GFController` 仍不会恢复事件绑定，也不会通过架构、模块、命令、查询或事件代理访问它；无 Context 的全局 Controller 不受此限制，可随全局 Architecture 重试正常恢复。

局部上下文中的 `GFController` 无需额外传参，会自动沿父节点查找最近的 `GFNodeContext`。注册到局部上下文的 `GFSystem` / `GFModel` / `GFUtility` 也会在注册时获得当前架构引用，因此基类提供的 `get_model()`、`get_system()`、`get_utility()` 会优先使用局部架构，并在本地未命中时回退父架构。

Controller 仍按当前父链解析最近 Context，普通 `reparent()` 会迁移事件绑定。对于跨树显示，只在 UI host 边界指定业务来源，不需要给每个 Controller 固定架构引用。在局部 Context 的 `install()` 中创建 UIUtility 后调用 `ui.configure_host(self)`，再注册该 Utility；其 host 默认位于此 Context 下。局部架构中的 UIUtility 缺少该配置时会明确初始化失败，避免面板静默进入全局作用域。

如果显示位置位于 `SceneTree.root` 或另一个 Viewport 下，调用 `ui.configure_host(self, mount_parent)`。UIUtility 创建并拥有 host、CanvasLayer 和面板；host 使用 `INHERITED GFNodeContext` 的显式来源绑定借用业务架构，不拥有来源 Context。绘制层级仍由 `CanvasLayer.layer` 管理，无需为改变绘制顺序而移动业务作用域。

普通节点也可复用同一机制：在进入树前对 `INHERITED` Context 调用 `bind_source_context(source_context)`。来源必须已经在树中；绑定记录 Context 身份和本轮进入树代次。来源关闭、离树、释放或重入后，旧绑定不回退父链或全局架构。`get_architecture()` 保留架构引用供诊断及生命周期协作；业务准入使用 `is_context_available()`，Context 的模块查询和 Controller 会自动检查该准入。

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

场景关闭使用 `close_async()`。它协调本地绑定和逻辑子 Context 的关闭，架构内部的模块关闭仍由 `GFArchitecture.shutdown_async()` 完成：

```gdscript
var result: GFContextCloseResult = await context.close_async(null, 10.0)
if not result.is_drained():
	push_warning(result.get_error())
if result.is_closed():
	context.queue_free()
```

`SCOPED` 先关闭逻辑子 Context，再静默关闭自有架构。`INHERITED` 关闭本地绑定和自己的逻辑子 Context，不关闭借用的共享架构。显式来源绑定的 UI portal 也计入来源的逻辑子 Context，即使其显示节点位于另一棵父链。关闭立即停止新 Controller 工作，父架构仍保持存活直到子关闭完成。

并发和信号重入的 `close_async()` 共享同一次尝试的结果，以第一个调用的取消 token 和超时为准；重复关闭已结束的 Context 返回原结果。超时预算由子关闭和自有架构共同消耗，最终同步释放不承诺墙钟硬上限。取消、超时或初始化期间的关闭可能得到 `is_closed() == true`、`is_drained() == false`，调用者不能把“已释放”当作数据已落盘。

不在该 Context 所有权树中的架构依赖由其真正所有者管理。若架构因仍有外部子依赖而返回 `ERR_BUSY`，Context 保持 CLOSING，结果的 `is_closed()` 为 `false`；关闭外部依赖后可以重试，不会恢复业务准入。安装中的关闭会取消安装 scope，迟到的安装/初始化结果不能恢复 READY。若 scope 清理回调让同一个节点同步离树并重新入树，旧关闭只结算旧代次，不会向新代次发出关闭通知或关闭其 UI。

节点 `_exit_tree()` 无法可靠 `await`，因此保留同步 `dispose()` 的强制释放兜底。若正常关闭等待尚未结束，离树会使该次等待得到明确的未排空终态，旧协程不能覆盖新入树代次的状态。数据关键路径不能把 `queue_free()` 当作 flush。

## 大版本迁移

- 场景退出代码由 `context.get_architecture().shutdown_async()` 改为 `context.close_async()`，并分别判断 `is_closed()` 与 `is_drained()`。
- 局部 UI 的安装代码增加 `configure_host(self)`；仅在有跨树显示需求时传入 `mount_parent`。不再要求项目为局部 HUD 绕开 UI 栈。
- Panel 不保存固定 Controller 架构绑定；显式来源放在 host 的 Context 边界，保留普通节点重挂载的事件迁移行为。
- 本次变更不重写存档或场景资源字段；已有 `scope_mode` 仍表示 INHERITED/SCOPED。项目若将 UI 目标作为自己的配置或 Resource 字段持久化，应显式迁移该配置，不能依靠旧的根节点挂载推断业务来源。
