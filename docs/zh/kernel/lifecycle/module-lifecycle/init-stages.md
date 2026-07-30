# 四阶段初始化、激活与关闭

`GFArchitecture.init()` 会先冻结 Model、Utility、System 注册快照，并从模块声明的依赖编译生命周期 DAG。缺失依赖、歧义解析或本地循环都会在任何模块生命周期阶段 Hook 执行前使初始化失败；不存在“继续多轮扫描，等待某个 Hook 再补注册”的兼容路径。

有效 DAG 对四个阶段都使用同一份依赖优先顺序。依赖关系先于 `lifecycle_priority`；只有多个已满足依赖的模块同时可执行时，框架才用模块类别、较高的 `lifecycle_priority` 和注册顺序稳定破平。父架构提供的依赖只作为外部满足项，不会变成本地 DAG 节点；父 Architecture 必须已经提交 READY，父级模块还必须处于 ACTIVE。

子架构完成计划编译后、执行计划内模块的 `init()` / `async_init()` / `ready()` / activation Hook 前，会为实际命中的父级 required module/factory 取得弱所有权租约。正常生命周期中，租约使依赖提供者和中间父链在 child 整个活动 generation 内保持可用：模块依赖会阻止相关父级改变模块拓扑，任一外部依赖都会使父级正常 `shutdown_async()` 以 `ERR_BUSY` 失败且不改变生命周期状态。child 初始化失败、正常关闭或强制释放都会幂等释放租约。项目仍应先启动父架构、再初始化子架构，并按相反顺序先关闭 child、最后关闭 parent。

`GFArchitectureLifecyclePlan` 是框架内部用于冻结上述顺序、依赖闭包与有界诊断的计划对象；项目代码不应自行构造、修改或长期持有它。对外诊断由 Architecture 从同一份计划快照投影，避免执行顺序与诊断结果分别扫描后发生漂移。

所有 `GFModel`、`GFSystem` 和 `GFUtility` 基类都提供对应的强类型虚方法。普通 `Object` 或未继承这些基类的对象不能依靠同名方法参与架构生命周期。

| 阶段 | Hook | 主要职责 | 运行时状态 |
| --- | --- | --- | --- |
| 1 | `init()` | 初始化模块自己的同步状态 | 未开放 |
| 2 | `async_init(scope)` | 准备模块自己的异步资源 | 未开放 |
| 3 | `ready()` | 解析已 ready 的声明依赖并完成装配 | 未开放 |
| 4 | `begin_activation(scope)` | 启动运行期能力并提交类型化终态 | 全部成功后才开放 |

## 第一阶段：同步初始化

```gdscript
func init() -> void:
	# 只建立当前模块自己的同步状态。
```

`init()` 适合绑定初始响应式属性、设置默认数值和建立本模块内部不变量。不要在这里启动请求、派发事件或依赖偶然的注册顺序读取其他模块。

## 第二阶段：异步准备

```gdscript
func async_init(scope: GFAsyncScope) -> void:
	while not _local_preparation_finished:
		if scope.is_cancel_requested():
			return
		await Engine.get_main_loop().process_frame
```

`async_init(scope)` 在所有模块完成第一阶段后按 DAG 顺序串行运行。它仍是主线程 coroutine；首个 `await` 前的同步段不能被框架抢占。长任务应拆成可让帧的有界步骤，并在每个 `await` 或外部回调返回后检查 `scope.is_cancel_requested()`。

这一阶段用于准备当前模块自己的资源，不是启动依赖型运行时流程的入口。需要访问已经 ready 的兄弟服务、等待该服务由 tick 推进的操作，并阻止架构过早对外可用时，应使用第四阶段。

## 第三阶段：装配完成

```gdscript
func ready() -> void:
	var value: Variant = get_utility(ProjectConfigUtility, true)
	if value is ProjectConfigUtility:
		_config = value
```

`ready()` 执行时，当前模块的本地声明依赖已经按 DAG 顺序完成第三阶段，可以安全缓存 Model、System 或 Utility。`ready()` 仍是同步装配 Hook；此时 `is_module_ready()` 可以为 true，但架构尚未提交 READY，命令、查询、事件派发、普通 tick 和模块自己的新工作准入都不应开始。

## 第四阶段：显式激活

```gdscript
func begin_activation(scope: GFAsyncScope) -> GFAsyncCompletion:
	var completion: GFAsyncCompletion = GFAsyncCompletion.new()
	var _bound: bool = completion.bind_cancel_token(scope)
	if not _start_runtime_admission():
		var _failed: bool = completion.fail("Runtime admission could not start.")
		return completion
	var _succeeded: bool = completion.succeed()
	return completion
```

`begin_activation(scope)` 必须立即返回非空 `GFAsyncCompletion`，再以 `succeed()`、`fail()` 或 `cancel()` 恰好提交一次终态。框架按 DAG 顺序等待每个完成源；等待某个模块时，只驱动该模块及其本地传递依赖闭包的生命周期 tick，使 Storage、Save Profile 等已经 ready 的 tick-driven 服务可以推进 bootstrap，而不会提前开放整个运行时。

全部模块激活成功后，架构才提交 READY；此后 `is_inited()`、`is_accepting_runtime_work()` 和 `architecture.is_module_active(instance)` 才表示运行时可用。激活取消、超时、空完成源或失败终态都会 fail closed：架构不提交 READY，取消本轮作用域并清理模块，迟到回调无权恢复旧 generation。

并发 `init()` 调用共享同一初始化事务。首个调用拥有共享 cancellation token 与 timeout 策略；后续调用的 token 只取消自身等待，不能终止其它调用正在等待的 activation。架构一旦提交 READY，之后的幂等 `init()` 固定成功，即使该调用携带已经取消的 token，也不会把稳定终态重新解释为失败。

## 正常关闭与强制释放

正常、可等待的退出路径使用：

```gdscript
var result: GFArchitectureShutdownResult = await architecture.shutdown_async()
if not result.is_successful():
	push_warning(result.get_error())
```

`shutdown_async()` 会先确认没有仍依赖本架构的活动 child；命中外部依赖租约时返回 `ERR_BUSY`，且不关闭准入或改变生命周期状态。检查通过后，它首先不可逆地关闭新运行时工作准入，再按激活 DAG 的严格逆序调用 `begin_quiesce(scope)`。模块应停止接纳新工作，并让此前已经接纳的操作在完成源进入终态前收敛。框架在等待期间继续只驱动当前模块的依赖闭包；取消、超时或模块失败会写入类型化结果，其中 `unfinished_modules` 包含当前 quiesce 失败、取消或超时的模块，以及因此未开始 quiesce 的后续模块。最终仍会执行每个模块恰好一次的同步 `dispose()` 和 `release_dependencies()`。

如果关闭开始时已有被接纳的拓扑事务，框架会先等待事务稳定；deadline 或取消触发接管时，顺序固定为夺取事务写权、取消事务 scope、claim 未提交候选的恰好一次清理。迟到 continuation 不能再写回；清理状态随事务描述符收敛，不为已释放实例保留长期 tombstone。

并发 `shutdown_async()` 调用共享同一关闭流程：每个调用都会先独立校验参数，首个被接纳的调用拥有共享 cancellation token 与 deadline 策略，后续调用只等待并取得同一终态结果的隔离副本。调用方不能用重复调用缩短、延长或替换已开始流程的策略。

`dispose()` 则是 SceneTree 退出等无法等待场景的同步强制兜底：它会取消活动作用域并立即释放，也不会被 child 租约阻挡。调用方必须把这视为打破父子 outlive 契约的灾难收敛路径。强制释放、中断 activation 或无法进入正常 quiesce 时，类型化关闭结果会在清理前快照所有已经进入任一生命周期阶段的模块与未提交拓扑候选，并把它们记录到 `unfinished_modules`；它提供审计证据，但不承诺排空已接纳工作。

```gdscript
func begin_quiesce(scope: GFAsyncScope) -> GFAsyncCompletion:
	_close_runtime_admission()
	return _drain_accepted_work(scope)


func dispose() -> void:
	_release_owned_runtime_state()


func release_dependencies() -> void:
	_cached_utility = null
	super.release_dependencies()
```

GF 不会扫描并清空模块的任意成员变量。`dispose()` 负责本模块拥有的终止性清理；`release_dependencies()` 只负责清空外部模块引用和框架注入作用域。
