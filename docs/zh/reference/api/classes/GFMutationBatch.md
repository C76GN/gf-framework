# GFMutationBatch

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/collections/gf_mutation_batch.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

通用变更批次。 把一组 Callable 作为可提交、可回滚的批次执行。它只管理执行顺序、 结果归一化和回滚栈，不绑定资源、存档、网络或编辑器事务。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`operation_added`](#member-gfmutationbatch-signals-operation_added) | `signal operation_added(operation_id: int)` |
| 信号 | [`operation_committed`](#member-gfmutationbatch-signals-operation_committed) | `signal operation_committed(operation_id: int, result: Dictionary)` |
| 信号 | [`batch_committed`](#member-gfmutationbatch-signals-batch_committed) | `signal batch_committed(summary: Dictionary)` |
| 信号 | [`batch_rolled_back`](#member-gfmutationbatch-signals-batch_rolled_back) | `signal batch_rolled_back(summary: Dictionary)` |
| 信号 | [`cleared`](#member-gfmutationbatch-signals-cleared) | `signal cleared` |
| 属性 | [`stop_on_error`](#member-gfmutationbatch-properties-stop_on_error) | `var stop_on_error: bool = true` |
| 属性 | [`auto_clear_committed_on_success`](#member-gfmutationbatch-properties-auto_clear_committed_on_success) | `var auto_clear_committed_on_success: bool = false` |
| 方法 | [`add_operation`](#member-gfmutationbatch-methods-add_operation) | `func add_operation(operation: Callable, rollback: Callable = Callable(), metadata: Dictionary = {}) -> int:` |
| 方法 | [`commit`](#member-gfmutationbatch-methods-commit) | `func commit(max_operations: int = -1) -> Dictionary:` |
| 方法 | [`rollback_committed`](#member-gfmutationbatch-methods-rollback_committed) | `func rollback_committed(max_operations: int = -1) -> Dictionary:` |
| 方法 | [`clear`](#member-gfmutationbatch-methods-clear) | `func clear() -> void:` |
| 方法 | [`get_pending_count`](#member-gfmutationbatch-methods-get_pending_count) | `func get_pending_count() -> int:` |
| 方法 | [`get_committed_count`](#member-gfmutationbatch-methods-get_committed_count) | `func get_committed_count() -> int:` |
| 方法 | [`get_debug_snapshot`](#member-gfmutationbatch-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfmutationbatch-signals-operation_added"></a>

### `operation_added`

- API：`public`

```gdscript
signal operation_added(operation_id: int)
```

操作加入批次后发出。

参数：

| 名称 | 说明 |
|---|---|
| `operation_id` | 操作标识。 |

<a id="member-gfmutationbatch-signals-operation_committed"></a>

### `operation_committed`

- API：`public`

```gdscript
signal operation_committed(operation_id: int, result: Dictionary)
```

单个操作提交成功后发出。

参数：

| 名称 | 说明 |
|---|---|
| `operation_id` | 操作标识。 |
| `result` | 操作结果。 |

结构：

- `result`: Dictionary normalized operation result.

<a id="member-gfmutationbatch-signals-batch_committed"></a>

### `batch_committed`

- API：`public`

```gdscript
signal batch_committed(summary: Dictionary)
```

批次提交结束后发出。

参数：

| 名称 | 说明 |
|---|---|
| `summary` | 提交摘要。 |

结构：

- `summary`: Dictionary commit summary.

<a id="member-gfmutationbatch-signals-batch_rolled_back"></a>

### `batch_rolled_back`

- API：`public`

```gdscript
signal batch_rolled_back(summary: Dictionary)
```

已提交操作回滚结束后发出。

参数：

| 名称 | 说明 |
|---|---|
| `summary` | 回滚摘要。 |

结构：

- `summary`: Dictionary rollback summary.

<a id="member-gfmutationbatch-signals-cleared"></a>

### `cleared`

- API：`public`

```gdscript
signal cleared
```

批次清空后发出。

## 属性

<a id="member-gfmutationbatch-properties-stop_on_error"></a>

### `stop_on_error`

- API：`public`

```gdscript
var stop_on_error: bool = true
```

提交遇到失败时是否停止后续操作。

<a id="member-gfmutationbatch-properties-auto_clear_committed_on_success"></a>

### `auto_clear_committed_on_success`

- API：`public`

```gdscript
var auto_clear_committed_on_success: bool = false
```

全部提交成功后是否自动清空 committed 栈。

## 方法

<a id="member-gfmutationbatch-methods-add_operation"></a>

### `add_operation`

- API：`public`

```gdscript
func add_operation(operation: Callable, rollback: Callable = Callable(), metadata: Dictionary = {}) -> int:
```

添加一个批次操作。

参数：

| 名称 | 说明 |
|---|---|
| `operation` | 提交回调。 |
| `rollback` | 可选回滚回调。 |
| `metadata` | 操作元数据。 |

返回：操作标识；失败返回 -1。

结构：

- `metadata`: Dictionary copied into the normalized operation result.

<a id="member-gfmutationbatch-methods-commit"></a>

### `commit`

- API：`public`

```gdscript
func commit(max_operations: int = -1) -> Dictionary:
```

提交待处理操作。

参数：

| 名称 | 说明 |
|---|---|
| `max_operations` | 最多提交数量；小于 0 表示处理全部。 |

返回：提交摘要。

结构：

- `return`: Dictionary commit summary.

<a id="member-gfmutationbatch-methods-rollback_committed"></a>

### `rollback_committed`

- API：`public`

```gdscript
func rollback_committed(max_operations: int = -1) -> Dictionary:
```

回滚已提交操作。

参数：

| 名称 | 说明 |
|---|---|
| `max_operations` | 最多回滚数量；小于 0 表示回滚全部。 |

返回：回滚摘要。

结构：

- `return`: Dictionary rollback summary.

<a id="member-gfmutationbatch-methods-clear"></a>

### `clear`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func clear() -> void:
```

清空批次。 commit/rollback 及其同步信号派发期间调用时不执行。

<a id="member-gfmutationbatch-methods-get_pending_count"></a>

### `get_pending_count`

- API：`public`

```gdscript
func get_pending_count() -> int:
```

获取待处理操作数量。

返回：待处理操作数量。

<a id="member-gfmutationbatch-methods-get_committed_count"></a>

### `get_committed_count`

- API：`public`

```gdscript
func get_committed_count() -> int:
```

获取已提交操作数量。

返回：已提交操作数量。

<a id="member-gfmutationbatch-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：调试信息字典。

结构：

- `return`: Dictionary with pending_count, committed_count, next_operation_id, transition_state, and options.
