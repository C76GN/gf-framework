# 操作诊断时间线

`GFOperationDiagnosticsUtility` 用于记录工具、运行时服务或项目流程的一次性操作、阶段耗时和异常事件。它只保存普通字典和数组，适合接入编辑器面板、支持报告、运行时调试器或项目自己的调试 UI，不绑定任何外部服务、远程协议或业务流程。

## 定位

当一个工具需要回答“最近做了什么、哪一步慢、同类错误出现了几次”时，可以把记录写入 `GFOperationDiagnosticsUtility`。它和 `GFDiagnosticsUtility` 的关系是：前者维护有界时间线，后者负责聚合快照和命令入口。把 `GFOperationDiagnosticsUtility` 注册到架构后，`GFDiagnosticsUtility.collect_snapshot()` 会在 `tools.operation_diagnostics` 中包含它的 `get_debug_snapshot()`。如果同时注册并启用 `GFAsyncTrackerUtility`，总快照也会在 `tools.async_tracker` 中包含活动异步句柄摘要。

## 典型流程

```gdscript
var operation_diagnostics := Gf.get_utility(GFOperationDiagnosticsUtility) as GFOperationDiagnosticsUtility
var operation_id := operation_diagnostics.begin_operation(&"tools.import", {
	"component": &"config",
	"metadata": {
		"source": "items.cfg",
	},
})

var parse_started := Time.get_ticks_usec()
# 执行解析逻辑。
operation_diagnostics.record_phase_from_ticks(operation_id, &"parse", parse_started)

operation_diagnostics.record_state_snapshot(operation_id, &"write", GFOperationDiagnosticsUtility.STATE_RUNNING, {
	"progress": 0.75,
	"attempt": 1,
	"max_attempts": 3,
})

operation_diagnostics.finish_operation(operation_id, true, {
	"metadata": {
		"row_count": 128,
	},
})
```

如果调用方已经有耗时结果，可直接使用 `record_completed_operation()`。异常事件使用 `record_incident()`，相同 `severity`、`category`、`code`、`component`、`phase` 和 `message` 的事件会合并，递增 `occurrence_count` 并刷新 `last_seen_*`。

## 状态轨迹

长流程除了阶段耗时，通常还需要说明“当前在哪一步、重试到第几次、进度是多少、是否等待用户决策”。`record_state_snapshot()` 把这些信息追加到操作的 `state_trace`，并同步更新 `current_state_id`、`current_state_status`、`progress`、`attempt`、`max_attempts`、`user_action_required` 和 `last_error`。

```gdscript
operation_diagnostics.record_state_snapshot(operation_id, &"confirm_overwrite", GFOperationDiagnosticsUtility.STATE_WAITING_FOR_USER, {
	"user_action_required": true,
	"progress": 0.9,
})
```

状态 ID 和 metadata 由调用方定义；GF 不解释这些字段，也不替项目执行重试、弹窗或恢复。健康快照会统计等待用户决策的操作数量，便于编辑器页面或支持报告提示流程正在等待上层决定。

## 异步句柄追踪

`GFAsyncTrackerUtility` 默认关闭，适合在开发构建、编辑器工具或项目调试模式中显式启用。它只保存弱引用、标签、metadata、可选堆栈和可选快照回调，不会替代任务调度，也不会阻止被追踪对象释放。

```gdscript
var tracker := Gf.get_utility(GFAsyncTrackerUtility) as GFAsyncTrackerUtility
tracker.tracking_enabled = true

var completion := GFAsyncCompletion.new()
var tracking_id := tracker.track_handle(
	completion,
	&"asset.preload",
	{ "asset": asset_path },
	Callable(completion, "get_debug_snapshot")
)

# 流程结束后移除追踪。
tracker.untrack_id(tracking_id)
```

## 常用 API

- `begin_operation(operation_type, options)`：创建运行中的操作记录并返回 `operation_id`。
- `record_phase()` / `record_phase_from_ticks()`：为操作追加阶段耗时。
- `record_state_snapshot()` / `get_operation_state_trace()`：为长流程追加状态、进度、重试和用户决策点记录。
- `finish_operation(operation_id, success, options)`：写入成功或失败状态、最终耗时和 metadata。
- `record_incident(severity, code, message, options)`：记录可聚合异常事件。
- `record_async_snapshot(operation_type, snapshot, options)`：把异步对象的普通字典快照记录为 running、completed 或 failed 操作，并把失败、取消或超时转为 `async` 分类 incident。
- `get_operations()` / `get_incidents()` / `get_timeline()`：按最近更新倒序读取历史，并支持基础过滤。
- `get_health_snapshot()`：返回 `status`、失败操作数、慢操作数、最近操作和最近异常。
- `build_copy_text()`：生成适合复制到 issue、日志或支持报告的简短文本。
- `GFAsyncTrackerUtility.track_handle()` / `untrack_id()` / `get_debug_snapshot()`：可选追踪活动异步句柄，并接入 `GFDiagnosticsUtility` 工具快照。

## 注意事项

`max_operations`、`max_incidents` 与 `max_state_trace_entries` 控制内存上限，默认只保留近期记录。`slow_operation_threshold_ms` 只影响健康快照中的慢操作统计，不会自动把慢操作写成错误事件；项目可以按自身策略决定是否调用 `record_incident()`。

记录中的 `metadata` 是项目自定义字典，GF 不解释其中字段。面向玩家、线上调试或远程工具暴露这些数据前，应在项目层做权限、脱敏和字段白名单。异步追踪同样应保持默认关闭，只在明确需要诊断活动句柄时启用。
