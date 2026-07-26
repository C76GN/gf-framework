# 命令历史与撤销重做

`GFCommandHistoryUtility` 用于管理命令执行历史、撤销、重做、序列化、恢复和异步操作约束。

当你使用 `GFCommand` 编码操作指令时，可以接入 GF Framework 提供的基于 `GFUndoableCommand` 的撤销重做栈扩展体系。基本接入步骤是：让命令继承 `GFUndoableCommand`，使用 `GFCommandHistoryUtility.execute_command(cmd)` 统一执行，再通过历史工具统一撤销和重做。

## 使用边界

`GFCommandHistoryUtility` 只管理历史栈和调用顺序。每个命令如何执行、撤销、保存快照和恢复状态，仍由命令类自己负责。

`undo()` 或重做阶段的 `execute()` 进入终态，并不一定代表业务状态已经成功变更。命令可以覆盖 `is_undo_successful(result)` 与 `is_redo_successful(result)` 报告终态结果；只有 hook 返回 `true`，历史工具才会把命令原子地移动到另一侧栈。返回 `false` 时，历史 API 同样返回 `false`，命令保持在来源栈原位置，另一侧栈的身份、顺序与容量均不改变。

```gdscript
class_name RestoreDocumentCommand
extends GFUndoableCommand

func undo() -> Variant:
	return _restore_document()

func is_undo_successful(undo_result: Variant) -> bool:
	return GFVariantData.to_bool(undo_result, false)
```

两个 hook 默认返回 `true`，因此未覆盖它们的既有命令以及返回 `null` 的命令继续采用成功语义。

通过 `execute_command()`、撤销或重做进入的命令回调统一运行在非重入历史操作内，包括命令的 `execute()` / `undo()`、`should_record()` 和两个结果 hook。回调返回前，新的执行、记录、撤销、重做、清空、容量修改和历史恢复请求都会被拒绝；需要触发后续命令时，应把意图交给项目层队列，并在当前历史 API 完成后再执行。只读计数、历史副本和序列化仍可使用，并始终观察最近一次完整提交的栈，不暴露等待中或 hook 内的临时移动。

## 阅读入口

- [序列化与恢复](persistence.md)：`serialize_history()`、`deserialize_history()`、命令构建器和历史容量。
- [异步撤销与重做](async-constraints.md)：Signal 终态 payload、停滞告警、原子处理锁、并发操作拒绝和项目层排队。

命令历史、快照历史和流程编排的更多用法，可继续阅读 [本地存储、编码、同步与快照](../../../standard/utilities/io/storage-snapshot/index.md) 与 [撤销历史与指令序列](../../../standard/input-flow/command-sequence/index.md)。
