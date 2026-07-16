# 异步撤销与重做

如果 `GFUndoableCommand.execute()` 或 `undo()` 会返回 `Signal`，例如等待动画、网络确认或异步资源流程，请使用异步版本的历史操作。

```gdscript
var history := Gf.get_utility(GFCommandHistoryUtility) as GFCommandHistoryUtility

await history.undo_last_async()
await history.redo_async()
```

同步版本 `undo_last()` / `redo()` 会保持原有立即返回的行为，适合纯数据命令。

异步版本会在命令返回 `Signal` 时等待完成后再移动撤销/重做栈。

`GFCommandHistoryUtility.async_stall_warning_seconds` 是停滞告警阈值，不是 timeout 或 cancellation。超过阈值后历史工具只发出一次 warning，并继续持有处理锁，直到命令 Signal 进入真实终态；因此迟到完成不会让 world state 与撤销/重做栈分叉。设为 `0` 可关闭告警，但不会关闭等待。

异步命令执行期间，历史工具会拒绝新的执行、记录、清空或恢复请求并输出 warning。若项目必须在截止时间取消副作用，应让命令自身使用 `GFCancellationToken` 或显式 terminal operation，并在命令完成后再让历史栈推进；历史层不会伪装成底层取消器。

需要排队的高频操作应放入项目层队列或 `GFCommandSequence`。
