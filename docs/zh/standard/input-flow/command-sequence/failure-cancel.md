# 取消、超时与失败策略

`GFCommandSequence` 的取消和失败策略只控制序列执行状态。项目层仍需要定义业务副作用如何撤销、错误如何展示、日志如何记录，以及是否允许用户重试。

## 取消与超时

`cancel()` 会先通知当前步骤的 `cancel(context)` 钩子；普通对象步骤如果提供无参 `cancel()` 也会被调用。随后序列会停止当前等待、不再执行后续步骤，并发出 `sequence_cancelled`。

`step_started` 是 execute 前的可否决边界：监听器在该信号中取消时，步骤尚未开始，因此不会调用
该步骤的 execute 或 cancel hook。Signal 等待默认有 30 秒超时。
`with_signal_timeout(seconds, respect_time_scale)` 可配置有限数值的等待上限，并默认跟随
`GFTimeUtility` 的暂停与 `time_scale`；非有限值会被拒绝并保留最近一次有效配置。超时只结束序列
等待，不会回滚已经发生的外部副作用。

如果序列已经进入失败回滚阶段，`cancel()` 也会通知当前 undo step 的取消入口。`last_run_report` 会用 `rollback_status` 区分 `not_run`、`completed`、`failed`、`cancelled` 和 `timeout`，并用 `rollback_cancelled` / `rollback_timeout` 提供布尔快捷字段。项目侧需要把“原步骤失败”和“回滚没有完整完成”分开展示时，应读取这些字段，而不是只解析 `rollback_errors` 文本。

## 失败结果

步骤返回以下字典形态时，序列会判定失败：

- `{"ok": false, "error": "..."}`
- `{"success": false}`
- `{"status": "error"}`
- `{"status": "failed"}`
- `{"status": "failure"}`

失败时序列会发出 `step_failed`，并把结果写入 `last_run_report`；失败步骤不会同时发出 `step_completed`。只 `push_error()` 或返回任意自定义对象不会自动被视为失败；项目层应把可判定失败的步骤收敛为这些结果字典。

## 停止与回滚

默认策略会继续执行后续步骤。开启 `stop_on_error` 后，序列在失败时停止；开启 `rollback_on_failure` 后，序列会逆序调用已完成步骤的 `undo()`。

当回滚对象是 `GFUndoableCommand` 时，序列会与 `GFCommandHistoryUtility` 一样，把同步返回值或
异步 Signal 的规范化 payload 传给 `is_undo_successful()`。该 hook 返回 `false` 时，
`rollback_status` 为 `failed`，并记录稳定的 `undo_failed` 错误；Dictionary 失败结果仍保留其
更具体的错误文本。

```gdscript
var sequence := GFCommandSequence.new([
	PrepareStep.new(),
	ApplyStep.new(),
	CommitStep.new(),
]).with_failure_policy(true, true)

await sequence.run()

if sequence.last_run_report.get("failed", false):
	push_warning(sequence.last_run_report.get("error", "Sequence failed."))
```

## 运行报告契约

`last_run_report` 与 `sequence_failed(report)` 使用相同的闭合顶层字段：

| 字段 | 类型 | 语义 |
| --- | --- | --- |
| `cancelled` | `bool` | 本次 run 是否收到取消；可与 `failed=true` 同时出现，取消 terminal signal 优先。 |
| `failed` | `bool` | 是否至少有一个步骤报告失败。 |
| `failed_index` | `int` | 最近一次失败步骤索引；没有失败时为 `-1`。 |
| `error` | `String` | 最近一次失败的稳定错误文本；没有失败时为空。 |
| `succeeded` | `int` | 已成功完成的步骤数，不含失败步骤补偿。 |
| `rolled_back` | `bool` | 是否进入了 rollback 流程。 |
| `rollback_failed` | `bool` | rollback 终态是否为 `failed`、`cancelled` 或 `timeout`。 |
| `rollback_status` | `StringName` | `not_run`、`completed`、`failed`、`cancelled` 或 `timeout`。 |
| `rollback_cancelled` | `bool` | rollback 是否被取消。 |
| `rollback_timeout` | `bool` | rollback 等待是否超时。 |
| `rollback_attempted_count` | `int` | 实际调用 `undo()` 的次数。 |
| `rollback_errors` | `Array[Dictionary]` | 逐次失败补偿的索引、错误、状态和 JSON-safe 结果。 |
| `results` | `Array[Dictionary]` | 已产生终态的步骤结果；每项包含 `index`、`ok`、`error`、JSON-safe `result`，等待步骤还包含 wait 字段。 |

失败报告只描述流程执行状态，不解释错误业务含义。项目层可以把它接到日志、诊断面板、编辑器验证工具或自己的恢复流程。
