# GFCommandHistoryUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/history/gf_command_history_utility.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

可撤销命令历史管理器。 负责维护 `GFUndoableCommand` 的撤销栈与重做栈， 并提供同步/异步重放与历史序列化能力。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`max_history_size`](#member-gfcommandhistoryutility-properties-max_history_size) | `var max_history_size: int:` |
| 属性 | [`undo_count`](#member-gfcommandhistoryutility-properties-undo_count) | `var undo_count: int:` |
| 属性 | [`redo_count`](#member-gfcommandhistoryutility-properties-redo_count) | `var redo_count: int:` |
| 属性 | [`async_stall_warning_seconds`](#member-gfcommandhistoryutility-properties-async_stall_warning_seconds) | `var async_stall_warning_seconds: float = 30.0:` |
| 属性 | [`is_processing_async`](#member-gfcommandhistoryutility-properties-is_processing_async) | `var is_processing_async: bool:` |
| 方法 | [`init`](#member-gfcommandhistoryutility-methods-init) | `func init() -> void:` |
| 方法 | [`dispose`](#member-gfcommandhistoryutility-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`record`](#member-gfcommandhistoryutility-methods-record) | `func record(cmd: GFUndoableCommand) -> void:` |
| 方法 | [`execute_command`](#member-gfcommandhistoryutility-methods-execute_command) | `func execute_command(cmd: GFUndoableCommand) -> Variant:` |
| 方法 | [`undo_last`](#member-gfcommandhistoryutility-methods-undo_last) | `func undo_last() -> bool:` |
| 方法 | [`undo_last_async`](#member-gfcommandhistoryutility-methods-undo_last_async) | `func undo_last_async() -> bool:` |
| 方法 | [`redo`](#member-gfcommandhistoryutility-methods-redo) | `func redo() -> bool:` |
| 方法 | [`redo_async`](#member-gfcommandhistoryutility-methods-redo_async) | `func redo_async() -> bool:` |
| 方法 | [`clear`](#member-gfcommandhistoryutility-methods-clear) | `func clear() -> void:` |
| 方法 | [`can_undo`](#member-gfcommandhistoryutility-methods-can_undo) | `func can_undo() -> bool:` |
| 方法 | [`can_redo`](#member-gfcommandhistoryutility-methods-can_redo) | `func can_redo() -> bool:` |
| 方法 | [`get_undo_history`](#member-gfcommandhistoryutility-methods-get_undo_history) | `func get_undo_history() -> Array[GFUndoableCommand]:` |
| 方法 | [`get_redo_history`](#member-gfcommandhistoryutility-methods-get_redo_history) | `func get_redo_history() -> Array[GFUndoableCommand]:` |
| 方法 | [`serialize_history`](#member-gfcommandhistoryutility-methods-serialize_history) | `func serialize_history() -> Array[Dictionary]:` |
| 方法 | [`serialize_full_history`](#member-gfcommandhistoryutility-methods-serialize_full_history) | `func serialize_full_history() -> Dictionary:` |
| 方法 | [`deserialize_history`](#member-gfcommandhistoryutility-methods-deserialize_history) | `func deserialize_history(data_array: Array, command_builder: Callable) -> void:` |
| 方法 | [`deserialize_full_history`](#member-gfcommandhistoryutility-methods-deserialize_full_history) | `func deserialize_full_history(data: Dictionary, command_builder: Callable) -> void:` |

## 属性

<a id="member-gfcommandhistoryutility-properties-max_history_size"></a>

### `max_history_size`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var max_history_size: int:
```

命令历史栈的最大容量；为 0 时表示不限制。该上限分别约束撤销栈和重做栈。

<a id="member-gfcommandhistoryutility-properties-undo_count"></a>

### `undo_count`

- API：`public`

```gdscript
var undo_count: int:
```

当前撤销栈深度。

<a id="member-gfcommandhistoryutility-properties-redo_count"></a>

### `redo_count`

- API：`public`

```gdscript
var redo_count: int:
```

当前重做栈深度。

<a id="member-gfcommandhistoryutility-properties-async_stall_warning_seconds"></a>

### `async_stall_warning_seconds`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var async_stall_warning_seconds: float = 30.0:
```

异步命令等待告警阈值（秒）。超过阈值只告警并继续持有历史锁，直到命令进入真实终态。

<a id="member-gfcommandhistoryutility-properties-is_processing_async"></a>

### `is_processing_async`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var is_processing_async: bool:
```

当前是否正在处理一条异步命令的等待、终态判断或历史栈提交。

## 方法

<a id="member-gfcommandhistoryutility-methods-init"></a>

### `init`

- API：`public`

```gdscript
func init() -> void:
```

初始化命令历史并清空撤销、重做栈。

<a id="member-gfcommandhistoryutility-methods-dispose"></a>

### `dispose`

- API：`public`

```gdscript
func dispose() -> void:
```

释放命令历史并取消等待中的异步历史操作。

<a id="member-gfcommandhistoryutility-methods-record"></a>

### `record`

- API：`public`

```gdscript
func record(cmd: GFUndoableCommand) -> void:
```

记录一条已经执行完成的命令。

参数：

| 名称 | 说明 |
|---|---|
| `cmd` | 已执行的命令实例。 |

<a id="member-gfcommandhistoryutility-methods-execute_command"></a>

### `execute_command`

- API：`public`

```gdscript
func execute_command(cmd: GFUndoableCommand) -> Variant:
```

执行命令并自动记录到撤销栈。

参数：

| 名称 | 说明 |
|---|---|
| `cmd` | 要执行的命令实例。 |

返回：`execute()` 的原始返回值；异步命令可由调用方自行 `await`。

结构：

- `return`: Variant returned by GFUndoableCommand.execute(), including null or Signal.

<a id="member-gfcommandhistoryutility-methods-undo_last"></a>

### `undo_last`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func undo_last() -> bool:
```

撤销最后一条命令，并仅在结果 hook 成功时提交历史栈移动。 `is_undo_successful()` 返回 `false` 时，命令保留在撤销栈原位置，重做栈不变。

返回：成功提交撤销历史时返回 `true`，否则返回 `false`。

<a id="member-gfcommandhistoryutility-methods-undo_last_async"></a>

### `undo_last_async`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func undo_last_async() -> bool:
```

异步撤销最后一条命令，并仅在结果 hook 成功时提交历史栈移动。 Signal 完成参数会规范化后传入 `is_undo_successful()`：无参数为 null，一个参数为该值， 两个至 16 个参数为保持发射顺序的 Array；超过 16 个时告警并只保留前 16 个。 结果 hook 返回 `false` 时，命令保留在撤销栈原位置，重做栈不变。

返回：成功提交撤销历史时返回 `true`，否则返回 `false`。

<a id="member-gfcommandhistoryutility-methods-redo"></a>

### `redo`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func redo() -> bool:
```

重做最近被撤销的命令，并仅在结果 hook 成功时提交历史栈移动。 `is_redo_successful()` 返回 `false` 时，命令保留在重做栈原位置，撤销栈不变。

返回：成功提交重做历史时返回 `true`，否则返回 `false`。

<a id="member-gfcommandhistoryutility-methods-redo_async"></a>

### `redo_async`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func redo_async() -> bool:
```

异步重做最近被撤销的命令，并仅在结果 hook 成功时提交历史栈移动。 Signal 完成参数会规范化后传入 `is_redo_successful()`：无参数为 null，一个参数为该值， 两个至 16 个参数为保持发射顺序的 Array；超过 16 个时告警并只保留前 16 个。 结果 hook 返回 `false` 时，命令保留在重做栈原位置，撤销栈不变。

返回：成功提交重做历史时返回 `true`，否则返回 `false`。

<a id="member-gfcommandhistoryutility-methods-clear"></a>

### `clear`

- API：`public`

```gdscript
func clear() -> void:
```

清空所有历史记录。

<a id="member-gfcommandhistoryutility-methods-can_undo"></a>

### `can_undo`

- API：`public`

```gdscript
func can_undo() -> bool:
```

检查当前是否允许撤销。

返回：有可撤销命令时返回 `true`。

<a id="member-gfcommandhistoryutility-methods-can_redo"></a>

### `can_redo`

- API：`public`

```gdscript
func can_redo() -> bool:
```

检查当前是否允许重做。

返回：有可重做命令时返回 `true`。

<a id="member-gfcommandhistoryutility-methods-get_undo_history"></a>

### `get_undo_history`

- API：`public`

```gdscript
func get_undo_history() -> Array[GFUndoableCommand]:
```

获取撤销栈副本。

返回：撤销历史的浅拷贝。

<a id="member-gfcommandhistoryutility-methods-get_redo_history"></a>

### `get_redo_history`

- API：`public`

```gdscript
func get_redo_history() -> Array[GFUndoableCommand]:
```

获取重做栈副本。

返回：重做历史的浅拷贝。

<a id="member-gfcommandhistoryutility-methods-serialize_history"></a>

### `serialize_history`

- API：`public`

```gdscript
func serialize_history() -> Array[Dictionary]:
```

将撤销栈序列化为纯数据数组。

返回：适合持久化的历史数据。

结构：

- `return`: Array[Dictionary] serialized command snapshots produced by command serialize() or get_snapshot().

<a id="member-gfcommandhistoryutility-methods-serialize_full_history"></a>

### `serialize_full_history`

- API：`public`

```gdscript
func serialize_full_history() -> Dictionary:
```

将完整命令历史序列化为纯数据字典。 包含 `undo` 与 `redo` 两个栈，可用于全量运行时快照恢复。

返回：适合持久化的完整历史数据。

结构：

- `return`: Dictionary with undo and redo Array[Dictionary] stacks.

<a id="member-gfcommandhistoryutility-methods-deserialize_history"></a>

### `deserialize_history`

- API：`public`

```gdscript
func deserialize_history(data_array: Array, command_builder: Callable) -> void:
```

通过构造器从纯数据恢复撤销栈。

参数：

| 名称 | 说明 |
|---|---|
| `data_array` | 历史数据数组。 |
| `command_builder` | 负责反序列化命令实例的构造器。 |

结构：

- `data_array`: Array[Dictionary] serialized command snapshots produced by serialize_history().

<a id="member-gfcommandhistoryutility-methods-deserialize_full_history"></a>

### `deserialize_full_history`

- API：`public`

```gdscript
func deserialize_full_history(data: Dictionary, command_builder: Callable) -> void:
```

通过构造器从完整历史数据恢复撤销栈与重做栈。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 由 `serialize_full_history()` 生成的字典数据。 |
| `command_builder` | 负责反序列化命令实例的构造器。 |

结构：

- `data`: Dictionary with undo and redo Array[Dictionary] stacks.
