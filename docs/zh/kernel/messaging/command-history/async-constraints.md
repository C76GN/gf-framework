# 异步撤销与重做

如果 `GFUndoableCommand.execute()` 或 `undo()` 会返回 `Signal`，例如等待动画、网络确认或异步资源流程，请使用异步版本的历史操作。

```gdscript
var history := Gf.get_utility(GFCommandHistoryUtility) as GFCommandHistoryUtility

await history.undo_last_async()
await history.redo_async()
```

同步版本 `undo_last()` / `redo()` 会保持原有立即返回的行为，适合纯数据命令。

异步版本会在命令返回 `Signal` 时等待真实终态，再把完成参数规范化后传给对应结果 hook：

- Signal 无参数时传入 `null`；
- 只有一个参数时直接传入该值；
- 有两个至 16 个参数时传入保持发射顺序的 `Array`；
- 超过 16 个参数时发出 warning，并只保留前 16 个。

需要携带更多字段时，应把它们封装进单个类型化 Result 或 `Dictionary` payload 后再发射，不要依赖超宽 Signal 参数列表。

`is_undo_successful(result)` 或 `is_redo_successful(result)` 返回 `true` 后，历史工具才会移动命令并执行容量裁剪；返回 `false` 时，命令回到来源栈原位置，另一侧栈完全不变。默认 hook 返回 `true`，所以无参数 Signal 和未声明失败语义的命令保持默认成功。

`GFCommandHistoryUtility.async_stall_warning_seconds` 是停滞告警阈值，不是 timeout 或 cancellation。超过阈值后历史工具只发出一次 warning，并继续持有处理锁，直到命令 Signal 进入真实终态；因此迟到完成不会让 world state 与撤销/重做栈分叉。设为 `0` 可关闭告警，但不会关闭等待。

处理锁会一直覆盖 Signal 等待、结果 hook 和最终栈提交，不会在 hook 前提前释放。期间历史工具会拒绝新的执行、记录、撤销、重做、清空、容量修改或恢复请求；结果 hook 不应重入历史写操作。来源命令在成功提交前仍保留在原栈，因此只读历史查询和序列化始终观察最近一次完整提交。相同非重入规则也适用于同步命令的 `execute()` / `undo()`、`should_record()` 和结果 hook。`init()` / `dispose()` 会使旧操作的 lifecycle generation 失效，旧异步 continuation 返回后不会把命令恢复或提交到新一代历史栈。

若项目必须在截止时间取消副作用，应让命令自身使用 `GFCancellationToken` 或显式 terminal operation，并在命令完成后再让历史栈推进；历史层不会伪装成底层取消器。

需要排队的高频操作应放入项目层队列或 `GFCommandSequence`。
