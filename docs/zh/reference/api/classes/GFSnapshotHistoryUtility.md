# GFSnapshotHistoryUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/history/gf_snapshot_history_utility.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

通用快照历史与回滚工具。 管理一组有序快照，支持捕获、前后跳转、按 ID 恢复和调试快照。 默认会使用注入架构的 `get_global_snapshot()` / `restore_global_snapshot()`， 也可以通过回调接入任意项目自定义状态。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`snapshot_recorded`](#member-gfsnapshothistoryutility-signals-snapshot_recorded) | `signal snapshot_recorded(snapshot_id: int, metadata: Dictionary)` |
| 信号 | [`snapshot_restored`](#member-gfsnapshothistoryutility-signals-snapshot_restored) | `signal snapshot_restored(snapshot_id: int, index: int)` |
| 信号 | [`history_changed`](#member-gfsnapshothistoryutility-signals-history_changed) | `signal history_changed(snapshot: Dictionary)` |
| 属性 | [`max_history_size`](#member-gfsnapshothistoryutility-properties-max_history_size) | `var max_history_size: int:` |
| 属性 | [`current_index`](#member-gfsnapshothistoryutility-properties-current_index) | `var current_index: int:` |
| 属性 | [`snapshot_count`](#member-gfsnapshothistoryutility-properties-snapshot_count) | `var snapshot_count: int:` |
| 方法 | [`dispose`](#member-gfsnapshothistoryutility-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`configure`](#member-gfsnapshothistoryutility-methods-configure) | `func configure( capture_callback: Callable = Callable(), restore_callback: Callable = Callable(), options: Dictionary = {} ) -> void:` |
| 方法 | [`capture`](#member-gfsnapshothistoryutility-methods-capture) | `func capture(metadata: Dictionary = {}) -> int:` |
| 方法 | [`push_snapshot`](#member-gfsnapshothistoryutility-methods-push_snapshot) | `func push_snapshot(data: Variant, metadata: Dictionary = {}) -> int:` |
| 方法 | [`step`](#member-gfsnapshothistoryutility-methods-step) | `func step(offset: int) -> bool:` |
| 方法 | [`step_back`](#member-gfsnapshothistoryutility-methods-step_back) | `func step_back() -> bool:` |
| 方法 | [`step_forward`](#member-gfsnapshothistoryutility-methods-step_forward) | `func step_forward() -> bool:` |
| 方法 | [`restore_index`](#member-gfsnapshothistoryutility-methods-restore_index) | `func restore_index(index: int) -> bool:` |
| 方法 | [`restore_snapshot_id`](#member-gfsnapshothistoryutility-methods-restore_snapshot_id) | `func restore_snapshot_id(snapshot_id: int) -> bool:` |
| 方法 | [`can_step_back`](#member-gfsnapshothistoryutility-methods-can_step_back) | `func can_step_back() -> bool:` |
| 方法 | [`can_step_forward`](#member-gfsnapshothistoryutility-methods-can_step_forward) | `func can_step_forward() -> bool:` |
| 方法 | [`get_current_snapshot`](#member-gfsnapshothistoryutility-methods-get_current_snapshot) | `func get_current_snapshot() -> Dictionary:` |
| 方法 | [`get_history`](#member-gfsnapshothistoryutility-methods-get_history) | `func get_history() -> Array[Dictionary]:` |
| 方法 | [`clear`](#member-gfsnapshothistoryutility-methods-clear) | `func clear() -> void:` |
| 方法 | [`get_debug_snapshot`](#member-gfsnapshothistoryutility-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfsnapshothistoryutility-signals-snapshot_recorded"></a>

### `snapshot_recorded`

- API：`public`

```gdscript
signal snapshot_recorded(snapshot_id: int, metadata: Dictionary)
```

捕获或推入快照后发出。

参数：

| 名称 | 说明 |
|---|---|
| `snapshot_id` | 快照 ID。 |
| `metadata` | 快照元数据副本。 |

结构：

- `metadata`: Dictionary[String, Variant] snapshot metadata copied from capture() or push_snapshot().

<a id="member-gfsnapshothistoryutility-signals-snapshot_restored"></a>

### `snapshot_restored`

- API：`public`

```gdscript
signal snapshot_restored(snapshot_id: int, index: int)
```

恢复快照后发出。

参数：

| 名称 | 说明 |
|---|---|
| `snapshot_id` | 快照 ID。 |
| `index` | 恢复后的当前位置。 |

<a id="member-gfsnapshothistoryutility-signals-history_changed"></a>

### `history_changed`

- API：`public`

```gdscript
signal history_changed(snapshot: Dictionary)
```

历史内容或当前位置变化后发出。

参数：

| 名称 | 说明 |
|---|---|
| `snapshot` | 调试快照。 |

结构：

- `snapshot`: Dictionary produced by get_debug_snapshot().

## 属性

<a id="member-gfsnapshothistoryutility-properties-max_history_size"></a>

### `max_history_size`

- API：`public`

```gdscript
var max_history_size: int:
```

最多保留的快照数量；为 0 时不限制。

<a id="member-gfsnapshothistoryutility-properties-current_index"></a>

### `current_index`

- API：`public`

```gdscript
var current_index: int:
```

当前快照索引；没有快照时为 -1。

<a id="member-gfsnapshothistoryutility-properties-snapshot_count"></a>

### `snapshot_count`

- API：`public`

```gdscript
var snapshot_count: int:
```

当前快照数量。

## 方法

<a id="member-gfsnapshothistoryutility-methods-dispose"></a>

### `dispose`

- API：`public`

```gdscript
func dispose() -> void:
```

释放快照历史并清理捕获、恢复回调。

<a id="member-gfsnapshothistoryutility-methods-configure"></a>

### `configure`

- API：`public`

```gdscript
func configure( capture_callback: Callable = Callable(), restore_callback: Callable = Callable(), options: Dictionary = {} ) -> void:
```

配置快照捕获与恢复回调。

参数：

| 名称 | 说明 |
|---|---|
| `capture_callback` | 可选捕获回调，签名为 func() -> Variant。 |
| `restore_callback` | 可选恢复回调，签名为 func(data: Variant) -> void。 |
| `options` | 可选设置，支持 max_history_size、restore_command_builder。 |

结构：

- `options`: Dictionary with max_history_size: int and restore_command_builder: Callable.

<a id="member-gfsnapshothistoryutility-methods-capture"></a>

### `capture`

- API：`public`

```gdscript
func capture(metadata: Dictionary = {}) -> int:
```

捕获当前状态并写入历史。

参数：

| 名称 | 说明 |
|---|---|
| `metadata` | 快照元数据。 |

返回：快照 ID；捕获失败时返回 0。

结构：

- `metadata`: Dictionary[String, Variant] copied into the snapshot record.

<a id="member-gfsnapshothistoryutility-methods-push_snapshot"></a>

### `push_snapshot`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func push_snapshot(data: Variant, metadata: Dictionary = {}) -> int:
```

推入一份外部快照数据。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 快照数据。 |
| `metadata` | 快照元数据。 |

返回：快照 ID。

结构：

- `data`: Pure Variant snapshot payload; Object and Resource references are rejected.
- `metadata`: Dictionary[String, Variant] copied into the snapshot record.

<a id="member-gfsnapshothistoryutility-methods-step"></a>

### `step`

- API：`public`

```gdscript
func step(offset: int) -> bool:
```

按相对偏移恢复快照。

参数：

| 名称 | 说明 |
|---|---|
| `offset` | 相对当前位置的偏移，负数向旧快照移动，正数向新快照移动。 |

返回：成功恢复时返回 true。

<a id="member-gfsnapshothistoryutility-methods-step_back"></a>

### `step_back`

- API：`public`

```gdscript
func step_back() -> bool:
```

恢复到上一份快照。

返回：成功恢复时返回 true。

<a id="member-gfsnapshothistoryutility-methods-step_forward"></a>

### `step_forward`

- API：`public`

```gdscript
func step_forward() -> bool:
```

恢复到下一份快照。

返回：成功恢复时返回 true。

<a id="member-gfsnapshothistoryutility-methods-restore_index"></a>

### `restore_index`

- API：`public`

```gdscript
func restore_index(index: int) -> bool:
```

按索引恢复快照。

参数：

| 名称 | 说明 |
|---|---|
| `index` | 快照索引。 |

返回：成功恢复时返回 true。

<a id="member-gfsnapshothistoryutility-methods-restore_snapshot_id"></a>

### `restore_snapshot_id`

- API：`public`

```gdscript
func restore_snapshot_id(snapshot_id: int) -> bool:
```

按快照 ID 恢复快照。

参数：

| 名称 | 说明 |
|---|---|
| `snapshot_id` | 快照 ID。 |

返回：成功恢复时返回 true。

<a id="member-gfsnapshothistoryutility-methods-can_step_back"></a>

### `can_step_back`

- API：`public`

```gdscript
func can_step_back() -> bool:
```

是否可以恢复到上一份快照。

返回：可以后退时返回 true。

<a id="member-gfsnapshothistoryutility-methods-can_step_forward"></a>

### `can_step_forward`

- API：`public`

```gdscript
func can_step_forward() -> bool:
```

是否可以恢复到下一份快照。

返回：可以前进时返回 true。

<a id="member-gfsnapshothistoryutility-methods-get_current_snapshot"></a>

### `get_current_snapshot`

- API：`public`

```gdscript
func get_current_snapshot() -> Dictionary:
```

获取当前快照副本。

返回：当前快照记录；没有快照时返回空字典。

结构：

- `return`: Dictionary with id, created_at_unix, metadata, and data.

<a id="member-gfsnapshothistoryutility-methods-get_history"></a>

### `get_history`

- API：`public`

```gdscript
func get_history() -> Array[Dictionary]:
```

获取全部历史副本。

返回：快照记录数组。

结构：

- `return`: Array[Dictionary] of snapshot records with id, created_at_unix, metadata, and data.

<a id="member-gfsnapshothistoryutility-methods-clear"></a>

### `clear`

- API：`public`

```gdscript
func clear() -> void:
```

清空历史。

<a id="member-gfsnapshothistoryutility-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：工具状态字典。

结构：

- `return`: Dictionary with snapshot_count, current_index, current_snapshot_id, max_history_size, can_step_back, can_step_forward, and ids.
