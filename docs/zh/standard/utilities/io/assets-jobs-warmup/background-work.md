# 后台工作协调器

这一页说明 `GFBackgroundWorkUtility` 如何执行纯数据 CPU/IO 线程任务、合并资源线程加载，并把结果安排回主线程应用。

## 核心模型 (`GFBackgroundWorkUtility` / `GFBackgroundWorkTask`)

`GFBackgroundWorkUtility` 适合真正需要线程执行的“纯数据工作”：解析大型 JSON、生成寻路网格中间数据、压缩/解压缓存、计算导入报告，或把 Godot 的 threaded `ResourceLoader` 请求纳入统一状态面板。它和 `GFJobQueueUtility` 的分工不同：任务队列只保存状态并等待项目消费；后台工作协调器会启动受限数量的 `Thread`，通过显式共享的 `GFResourceBroker` 观察资源加载，并把结果安排回下一次 `tick()` 的主线程应用回调。

```gdscript
var background := Gf.get_utility(GFBackgroundWorkUtility) as GFBackgroundWorkUtility

background.submit_cpu_work(
	func(input: Variant) -> Dictionary:
		var rows := input as Array
		return {
			"count": rows.size(),
			"checksum": hash(rows),
		},
	rows_from_disk,
	func(task: GFBackgroundWorkTask) -> void:
		# 这里已经回到主线程，可以写入 Model、创建节点或刷新 UI。
		print(task.result)
)
```

## 线程数据边界

默认情况下，`submit_cpu_work()` 和 `submit_io_work()` 会拒绝包含 `Object`、`Resource`、`Callable`、`Signal` 或 `RID` 的 payload，只接受标量、数学结构、PackedArray、Array 和 Dictionary 组成的纯 Variant 数据。这个限制是故意的：线程中不直接触碰场景树、Resource 实例或托管对象，才能避免把 Unity JobSystem 中“绕过托管类型检查却丢掉优化价值”的问题搬进 Godot。确实需要迁移旧代码时可以用 `options["allow_object_payloads"] = true` 或全局 `allow_object_payloads` 打开，但推荐做法仍是只传路径、ID、数值和结构化数据。

已接受任务会强持有 `RefCounted` worker target，直到对应线程完成 join；主线程 `apply_callback` 的 `RefCounted` target 则持有到任务进入 completed、failed 或 cancelled 终态。这样局部创建的纯数据处理器不会在排队期间提前释放。框架不会据此延长 `Node` 的场景树生命周期：需要节点拥有任务时，仍应由项目在节点退出时取消任务，并让回调只写入仍有效的权威状态。

## 调度、取消与诊断

资源加载使用 `submit_resource_load(path, type_hint, apply_callback)`。Utility 内相同路径、兼容 `type_hint` 的任务会合并兴趣；共享 Broker 还会让 Asset、Scene 和 BackgroundWork 的相同资源身份复用一个底层 threaded request。取消某个任务只移除该任务兴趣并阻止 GF 侧应用和完成回调；最后一个兴趣离开后才取消当前 Utility 的 Lease，若它也是 Broker 最后一个消费者，已发起请求会进入 drain。若同路径新任务在本地取消记录尚未完成下一次轮询前到达，Utility 会重新取得 live Lease，而不会让新任务继承旧 Lease 的取消终态。CPU/IO 线程任务也是协作式取消：等待中的任务会立刻进入 `cancelled`，运行中的任务会等 worker 返回后再落到取消终态。`get_debug_snapshot()` 会报告等待、运行、资源请求、Broker draining/admission、应用队列和终态任务 ID，适合和运行时诊断面板或加载界面联动。

未注入 Broker 时，`submit_resource_load()` 不会建立私有加载通道，而是立即返回
`failed` 任务；`task.result` 为结构化字典，其中 `request_error` 是
`ERR_UNCONFIGURED`、`reason` 是 `resource_broker_not_configured`。该错误码与
调试快照一致，调用方无需从本地化错误文本反推失败类型。

CPU/IO 等待任务使用 `GFPriorityWorkQueue` 仲裁。`options["priority"]` 仍表示基础优先级，但等待中的任务会按 `priority_aging_interval_msec` 和 `priority_aging_step` 获得无上限加成：刚进入场景所需的解析工作可以先跑，而较早排入的缓存整理、索引生成或遥测压缩也会最终获得执行机会。这个机制只改变启动顺序，不解释 priority 的业务含义，也不抢占已经运行的线程。`get_debug_snapshot()` 的 `queued_priority_entries` 会给出 work ID、基础/有效优先级、等待时间和稳定顺序，不暴露 worker、payload 或任务对象；诊断面板可据此区分“确实在等待”和“调度参数不合理”。

## 主线程应用预算

主线程应用回调用 `max_apply_per_tick` 限制每帧数量；如果每个应用回调成本差异很大，可以再设置 `max_apply_seconds_per_tick` 作为时间预算。时间预算小于等于 `0.0` 时关闭；启用后每次 `tick()` 仍至少尝试一个应用回调，避免预算过低导致队列永远不前进。重活仍应放在线程 worker 中完成，`apply_callback` 只做写回 Model、创建节点或刷新 UI 这类必须回到主线程的收尾。

## 使用边界

这套工具不替代 `GFAssetUtility` 或 `GFSceneUtility` 的专用缓存/切场景能力。需要资源句柄、分组预加载和 LRU 缓存时继续用 `GFAssetUtility`；需要场景切换和 loading scene 时继续用 `GFSceneUtility`；需要“排队后由项目自己的系统逐帧消费”时继续用 `GFJobQueueUtility`。架构模式应为三者注册同一个 `GFResourceBroker`；独立模式应显式注入或调用单 Utility 的 `setup_standalone_resource_broker()`。`GFBackgroundWorkUtility` 的定位是把通用 CPU/IO 纯数据工作和主线程应用边界标准化。
