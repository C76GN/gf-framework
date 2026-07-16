# 后台工作协调器

这一页说明 `GFBackgroundWorkUtility` 如何执行纯数据 CPU/IO 线程任务、合并资源线程加载，并把结果安排回主线程应用。

### 后台工作协调器 (`GFBackgroundWorkUtility` / `GFBackgroundWorkTask`)

`GFBackgroundWorkUtility` 适合真正需要线程执行的“纯数据工作”：解析大型 JSON、生成寻路网格中间数据、压缩/解压缓存、计算导入报告，或把 Godot 的 threaded `ResourceLoader` 请求纳入统一状态面板。它和 `GFJobQueueUtility` 的分工不同：任务队列只保存状态并等待项目消费；后台工作协调器会启动受限数量的 `Thread`，轮询资源线程加载，并把结果安排回下一次 `tick()` 的主线程应用回调。

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

默认情况下，`submit_cpu_work()` 和 `submit_io_work()` 会拒绝包含 `Object`、`Resource`、`Callable`、`Signal` 或 `RID` 的 payload，只接受标量、数学结构、PackedArray、Array 和 Dictionary 组成的纯 Variant 数据。这个限制是故意的：线程中不直接触碰场景树、Resource 实例或托管对象，才能避免把 Unity JobSystem 中“绕过托管类型检查却丢掉优化价值”的问题搬进 Godot。确实需要迁移旧代码时可以用 `options["allow_object_payloads"] = true` 或全局 `allow_object_payloads` 打开，但推荐做法仍是只传路径、ID、数值和结构化数据。

资源加载使用 `submit_resource_load(path, type_hint, apply_callback)`。相同路径、兼容 `type_hint` 的请求会合并到同一个 threaded `ResourceLoader` operation；每个任务持有自己的消费者引用，取消某个任务只释放该引用并阻止 GF 侧应用和完成回调，不会强行中止 Godot 已经发起的加载线程。当最后一个消费者取消后，operation 会进入 drain 状态，迟到的成功或失败结果会被消费并 suppress，避免污染应用队列。CPU/IO 线程任务也是协作式取消：等待中的任务会立刻进入 `cancelled`，运行中的任务会等 worker 返回后再落到取消终态。`get_debug_snapshot()` 会报告等待、运行、资源请求、resource draining、threaded resource operation、应用队列和终态任务 ID，适合和运行时诊断面板或加载界面联动。

主线程应用回调用 `max_apply_per_tick` 限制每帧数量；如果每个应用回调成本差异很大，可以再设置 `max_apply_seconds_per_tick` 作为时间预算。时间预算小于等于 `0.0` 时关闭；启用后每次 `tick()` 仍至少尝试一个应用回调，避免预算过低导致队列永远不前进。重活仍应放在线程 worker 中完成，`apply_callback` 只做写回 Model、创建节点或刷新 UI 这类必须回到主线程的收尾。

这套工具不替代 `GFAssetUtility` 或 `GFSceneUtility` 的专用缓存/切场景能力。需要资源句柄、分组预加载和 LRU 缓存时继续用 `GFAssetUtility`；需要场景切换和 loading scene 时继续用 `GFSceneUtility`；需要“排队后由项目自己的系统逐帧消费”时继续用 `GFJobQueueUtility`。`GFBackgroundWorkUtility` 的定位是把通用 CPU/IO 纯数据工作和主线程应用边界标准化。
