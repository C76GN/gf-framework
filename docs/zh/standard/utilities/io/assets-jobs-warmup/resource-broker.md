# 共享 Resource Broker

`GFResourceBroker` 是 `GFAssetUtility`、`GFSceneUtility` 与
`GFBackgroundWorkUtility` 共用的 threaded `ResourceLoader` admission 边界。
它不使用全局单例，也不自动猜测项目中的实例：架构模式应显式注册一个共享
Broker，独立模式应显式创建并注入。

## 架构注册

在 Architecture 初始化前注册 Broker 和消费者 Utility。消费者的 `ready()` 会
解析同一实例：

```gdscript
var broker := GFResourceBroker.new()
var assets := GFAssetUtility.new()
var scenes := GFSceneUtility.new()
var background := GFBackgroundWorkUtility.new()

await architecture.register_utility_instance(broker)
await architecture.register_utility_instance(assets)
await architecture.register_utility_instance(scenes)
await architecture.register_utility_instance(background)
await architecture.init()
```

`GFResourceBroker` 是三类消费者在架构模式下的必需依赖。`ready()` 查找失败时
不会创建兼容 fallback：`get_resource_broker()` 保持 `null`，资源请求以
`ERR_UNCONFIGURED` 失败，消费者调试快照的 `resource_broker.configured` 为
`false`，`error` 为 `resource_broker_not_configured`，`request_error` 为
`ERR_UNCONFIGURED`。`GFAssetUtility.load_async()` 此时用 `null` 完成失败回调；
`GFSceneUtility.load_scene_async()` 同步返回 `ERR_UNCONFIGURED` 并沿用场景失败
信号；`GFBackgroundWorkUtility.submit_resource_load()` 返回 `failed` 任务，其
`result.request_error` 为同一错误码。headless 也不会绕过 Broker 改走同步
`ResourceLoader.load()`。项目应修正装配，不应把该状态当成可忽略的性能降级。

如果只独立使用一个消费者，可以调用
`setup_standalone_resource_broker()`。多个消费者需要互相协调时，不要分别创建
私有 Broker；应创建一个 `GFResourceBroker`，调用 `init()`，再分别通过
`set_resource_broker()` 注入。独立 Broker 不在 Architecture 的 tick 列表中时，
调用方必须持续调用 `pump()`；`dispose()` 后已经发起且无法中止的请求仍需
`pump()` 到 `is_idle()`，才能完成 drain。

## 有界 admission

Broker 默认允许 4 个活动底层请求和 256 个等待请求。配置始终被限制在
`1..ABSOLUTE_MAX_ACTIVE_REQUESTS` 与
`1..ABSOLUTE_MAX_PENDING_REQUESTS`；当前绝对上限分别是 64 和 4096。同一资源
身份的兼容请求只增加消费者 Lease，不重复占用 pending 配额或发起第二个底层
请求。

不同资源请求按严格 FIFO admission。`options` 支持：

- `exclusive = true`：本请求活动期间不 admission 其他底层请求。
- `require_idle = true`：只有 Broker 已经没有活动或 draining 请求时才 admission。
- `consumer_id`：只用于诊断的稳定消费者标识。

队首独占或 require-idle 请求不会被后续共享请求绕过。同一路径仍在排队时，
后来加入的 Lease 可以把该底层请求单调升级为更严格的 admission 约束。请求
已经活动或 draining 时，只有原始 admission 已满足同等约束才能复用；后来才
要求 exclusive / require-idle 的 Lease 会失败关闭，不伪造一次“独占启动”。

同路径 queued record 最初没有 `type_hint`、后来收到非空兼容提示时，会在
admission 前收紧底层请求。底层请求已经发起后才提出更强 `type_hint` 无法补做
原生类型约束，因此该 Lease 会失败关闭；空提示消费者仍可加入已经用强提示
发起的请求。

所有需要互相隔离的 `ResourceLoader.load_threaded_request()` 都必须通过同一个
Broker；框架无法协调绕过 Broker 直接发起的项目请求。

## Lease、取消与 drain

每次 `request()` 返回独立的 `GFResourceLease`。取消或释放一个 Lease 只移除
当前消费者的兴趣；同路径其他消费者仍可正常取得资源。最后一个消费者离开
后：

- 尚未 admission 的记录会立即从队列移除。
- 已经发起的 Godot threaded request 会进入 draining，继续轮询到成功或失败，
  但结果不再交付给已取消消费者。

`poll_lease()` 返回 queued、loading、completed、failed 或 cancelled 状态。
调用 `release()` 会在首次调用时立即释放 Lease 的本地 Broker/Resource 引用，
且重复调用幂等；若底层请求已开始，Broker 仍会继续 drain。Broker 的
`get_debug_snapshot()` 会报告 active、pending、draining、独占状态、路径和当前
预算，不输出资源内容。

Asset 与 Scene Utility 的 `dispose()` 会先关闭新 admission，再取消已有请求和
分发取消信号/回调。即使项目代码从这些同步通知中重入加载 API，也只会立即得到
`ERR_UNAVAILABLE`（Asset 的 void 回调入口收到 `null`），不会创建遗留 Lease。

## 场景邻居稳定边界

开启 `GFSceneUtility.auto_preload_map_neighbors_on_switch` 后，邻居预载不会在调用
切场的同一帧立即发起。Scene Utility 会先监听目标 `SceneTree.scene_changed`，
确认切换到预期资源身份，再等待一个 process frame；渲染环境继续等待
`RenderingServer.frame_post_draw`，headless 环境等待一个零时长 SceneTree
timer。随后邻居计划以 `exclusive + require_idle` 进入共享 Broker，避免与仍在
活动的 Asset warmup 重叠。

新切换、图谱或半径变更、关闭自动预载以及 `dispose()` 都会取消旧 generation。
手动预载加入同一路径时会提升为持久兴趣；自动预载加入既有手动请求时持有独立
Lease，因此取消旧 generation 不会误杀手动请求。批量登记每个邻居前后以及
Broker/信号等同步可重入边界都会重验 generation；一旦配置在回调中变化，旧
批次不会继续创建后续邻居请求。
