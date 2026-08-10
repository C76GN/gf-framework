# 通用任务队列

这一页说明 `GFJobQueueUtility` 和 `GFJob` 如何保存等待、执行中、完成、失败、取消和暂停状态，并由项目处理器消费任务。

## 通用任务队列

`GFJobQueueUtility` 适合承载“先排队，稍后由项目系统消费”的通用任务，例如导入、批处理、后台计算、生成预览或任意需要进度反馈的工作。它只管理等待、执行中、完成、失败、取消、暂停和调试快照，不内置线程模型、下载协议或业务含义：

```gdscript
var jobs := Gf.get_utility(GFJobQueueUtility) as GFJobQueueUtility

var job := jobs.enqueue(&"build", { "path": "res://data/items.json" }, { "kind": "import" })
var active := jobs.start_next_job(&"build")
if active != null:
	jobs.update_job_progress(active.job_id, 0.5, "half")
	jobs.complete_job(active.job_id, { "count": 120 })
```

如果项目希望同步消费一项任务，可以使用 `run_next_job(queue_name, processor)`，回调返回 `false` 或 `{ "ok": false, "error": "..." }` 时会进入失败状态。`complete_job()`、`fail_job()` 和 `cancel_job()` 都会先从等待队列移除对应对象，因此直接终结尚未启动的任务也不会被再次领取。`pause_queue()` / `resume_queue()` 只影响后续 `start_next_job()`，不会取消已经开始的任务；需要真正中止外部工作时，项目层应在自己的处理器里响应取消状态。完成、失败和取消历史分别受 `max_completed_jobs`、`max_failed_jobs`、`max_cancelled_jobs` 限制；`get_debug_snapshot()` 会报告三类终态保留数量，适合诊断面板读取。

## Worker 消费

当任务需要由场景节点持续消费时，可以挂一个 `GFJobWorker`。它通过 `queue_utility` 或全局架构找到 `GFJobQueueUtility`，按 `batch_size` 调用项目提供的 `processor`，并把返回值写回完成或失败状态：

```gdscript
var worker := GFJobWorker.new()
worker.queue_name = &"import"
worker.batch_size = 4
worker.set_processor(func(job: GFJob) -> Dictionary:
	return { "ok": true, "result": job.data }
)
add_child(worker)
```

`GFJobWorker` 不创建线程，也不解释任务数据；如果处理器返回 Signal，Worker 会等待信号发出，并把信号结果按同步返回值同样写回完成或失败状态。信号不携带结果时视为完成。`signal_timeout_seconds` 默认提供等待上限，超时或取消会把任务标记为失败，避免某个永不发射的处理器让 worker 长期停在 `_processing` 状态；`signal_timeout_respects_time_scale` 控制该等待是否跟随 `GFTimeUtility`。这个模式适合桥接项目自己的异步导入、下载、预览生成或工具流程。

如果任务在异步处理器等待期间被外部取消，Worker 不会再把迟到的 Signal 结果写回完成状态，也不会发出 `job_processed`。项目需要展示取消结果时，应监听队列侧的任务状态或在自己的取消流程中更新 UI，而不是把 `job_processed` 当作所有终态通知。
