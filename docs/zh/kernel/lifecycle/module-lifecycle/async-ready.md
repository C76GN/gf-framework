# 异步超时、Activation 与状态查询

`async_init()` 适合等待网络请求、本地 IO 或大批量资源异步加载。项目应避免让开发期资源加载、网络请求或外部回调永久挂起。

## 异步超时

可通过 `GFArchitecture.module_async_init_timeout_seconds` 设置模块异步初始化超时。该属性只接受 `0..86400` 的有限秒数；`0` 明确禁用 deadline，非法赋值会被拒绝并保留原值。超时会取消当前模块收到的 `GFAsyncScope`，让架构进入初始化失败状态，并唤醒等待 `init()` / `GFNodeContext.wait_until_ready()` 的调用方。

Godot coroutine 无法被框架抢占式终止。超时会阻止架构继续推进，并让 `scope.is_cancel_requested()` 返回 true；已经挂起的 `async_init(scope)` 如果之后恢复，模块内部应先检查 scope，再决定是否写回状态。需要注册临时连接、后台请求或外部句柄清理时，使用 `scope.register_cleanup()`。

超时也不会抢占首个 `await` 之前的同步执行段。需要处理大文件、批量资源索引或复杂表格解析时，应先进入可让帧的分段流程，再在每段之间检查生命周期状态；否则一次长同步段仍会卡住主线程，并推迟超时检测。

## Activation deadline

第四阶段使用独立的 `GFArchitecture.activation_timeout_seconds` 总 deadline，默认 30 秒；该属性同样只接受 `0..86400` 的有限秒数，`0` 禁用 deadline。它不是每个模块各自拥有一份完整预算。`begin_activation(scope)` 必须立即返回 `GFAsyncCompletion`，并在异步回调、Signal 或 tick-driven bootstrap 完成时提交一次终态。把 scope 绑定到完成源可以让初始化取消直接传播：

```gdscript
func begin_activation(scope: GFAsyncScope) -> GFAsyncCompletion:
	var completion: GFAsyncCompletion = GFAsyncCompletion.new()
	var _bound: bool = completion.bind_cancel_token(scope)
	_begin_bootstrap(completion)
	return completion
```

不要在 `begin_activation()` 返回前自行轮询 `architecture.tick()`，也不要为了等待兄弟服务而阻塞主线程。架构会根据声明依赖的闭包推进必要模块的 lifecycle tick；完成源失败、取消、超时或从 Hook 返回 `null` 时，本轮初始化不会提交 READY。

## Ready、Active 与架构准入

依赖查询默认保持兼容，会返回已注册但仍处于初始化过程中的模块。如果代码必须只消费完成 `ready()` 的模块，可以在 `GFArchitecture`、`Gf`、`GFNodeContext`、`GFController`、`GFCommand`、`GFQuery`、`GFSystem` 或 `GFUtility` 的 `get_model()` / `get_system()` / `get_utility()` 中传入 `require_ready = true`。

本地查询 `get_local_*()` 也支持相同参数。需要判断某个实例是否已经完成第三阶段时，可调用 `architecture.is_module_ready(instance)`，模块自身可用 `is_ready_in_architecture()`。

“ready”只表示依赖装配完成，不等同于已经接纳运行时工作。只有第四阶段成功后，`architecture.is_module_active(instance)` 才表示该模块已激活；只有架构整体提交 READY 后，`architecture.is_accepting_runtime_work()` 和 `architecture.is_inited()` 才返回 true。外部启动流程应以架构准入状态为边界，不要在第三阶段通过 ready 查询绕过 activation。

## Shutdown deadline

`GFArchitecture.shutdown_timeout_seconds` 是正常异步关闭的默认总 deadline，也只接受 `0..86400` 的有限秒数，`0` 禁用 deadline。调用 `shutdown_async(token, timeout_seconds)` 时可以传入同一区间的 per-call 覆盖值；默认 sentinel `-1.0` 表示读取 `shutdown_timeout_seconds`，不是另一个 deadline 值。非有限值、其它负值或大于 `86400` 的覆盖值会失败关闭。关闭开始后架构立即进入 quiescing，新命令、查询、事件派发、运行时写入和模块拓扑事务都会被拒绝。

模块的 `begin_quiesce(scope)` 应返回一次性完成源，并只排空关闭前已经接纳的工作。无论关闭成功、失败、取消或超时，架构最终都会同步释放所有模块；调用方应检查 `GFArchitectureShutdownResult`，不能把对象已经 disposed 误当成数据已经正常 drain。
