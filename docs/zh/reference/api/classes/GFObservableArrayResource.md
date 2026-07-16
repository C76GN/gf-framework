# GFObservableArrayResource

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/collections/gf_observable_array_resource.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`6.0.0`

可观察数组资源。 保存一份 Array 数据，并通过显式方法发出单项变更和批量变更信号。 它不是 Array 的替身，不拦截直接字段修改；调用方应通过方法提交变更， 以便 UI、编辑器工具、状态同步或诊断面板接收稳定的变更报告。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`item_changed`](#member-gfobservablearrayresource-signals-item_changed) | `signal item_changed(operation: StringName, index: int, old_value: Variant, new_value: Variant, metadata: Dictionary)` |
| 信号 | [`items_changed`](#member-gfobservablearrayresource-signals-items_changed) | `signal items_changed(changes: Array[Dictionary], metadata: Dictionary)` |
| 常量 | [`OPERATION_APPEND`](#member-gfobservablearrayresource-constants-operation_append) | `const OPERATION_APPEND: StringName = &"append"` |
| 常量 | [`OPERATION_SET`](#member-gfobservablearrayresource-constants-operation_set) | `const OPERATION_SET: StringName = &"set"` |
| 常量 | [`OPERATION_ERASE`](#member-gfobservablearrayresource-constants-operation_erase) | `const OPERATION_ERASE: StringName = &"erase"` |
| 常量 | [`OPERATION_CLEAR`](#member-gfobservablearrayresource-constants-operation_clear) | `const OPERATION_CLEAR: StringName = &"clear"` |
| 常量 | [`OPERATION_REPLACE`](#member-gfobservablearrayresource-constants-operation_replace) | `const OPERATION_REPLACE: StringName = &"replace"` |
| 属性 | [`items`](#member-gfobservablearrayresource-properties-items) | `var items: Array = []` |
| 属性 | [`metadata`](#member-gfobservablearrayresource-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`set_items`](#member-gfobservablearrayresource-methods-set_items) | `func set_items(values: Array, emit_change: bool = true, change_metadata: Dictionary = {}) -> Dictionary:` |
| 方法 | [`get_items`](#member-gfobservablearrayresource-methods-get_items) | `func get_items() -> Array:` |
| 方法 | [`append_item`](#member-gfobservablearrayresource-methods-append_item) | `func append_item(value: Variant, change_metadata: Dictionary = {}) -> Dictionary:` |
| 方法 | [`set_item`](#member-gfobservablearrayresource-methods-set_item) | `func set_item(index: int, value: Variant, change_metadata: Dictionary = {}) -> Dictionary:` |
| 方法 | [`erase_item_at`](#member-gfobservablearrayresource-methods-erase_item_at) | `func erase_item_at(index: int, change_metadata: Dictionary = {}) -> Dictionary:` |
| 方法 | [`clear_items`](#member-gfobservablearrayresource-methods-clear_items) | `func clear_items(change_metadata: Dictionary = {}) -> Dictionary:` |
| 方法 | [`begin_batch`](#member-gfobservablearrayresource-methods-begin_batch) | `func begin_batch(change_metadata: Dictionary = {}) -> void:` |
| 方法 | [`end_batch`](#member-gfobservablearrayresource-methods-end_batch) | `func end_batch(change_metadata: Dictionary = {}) -> Dictionary:` |
| 方法 | [`get_count`](#member-gfobservablearrayresource-methods-get_count) | `func get_count() -> int:` |
| 方法 | [`is_empty`](#member-gfobservablearrayresource-methods-is_empty) | `func is_empty() -> bool:` |
| 方法 | [`get_debug_snapshot`](#member-gfobservablearrayresource-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfobservablearrayresource-signals-item_changed"></a>

### `item_changed`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
signal item_changed(operation: StringName, index: int, old_value: Variant, new_value: Variant, metadata: Dictionary)
```

非 batch 模式下单项变更后发出。batch 内变更只在 end_batch() 时汇总到 items_changed。

参数：

| 名称 | 说明 |
|---|---|
| `operation` | 操作类型。 |
| `index` | 变更索引。 |
| `old_value` | 旧值。 |
| `new_value` | 新值。 |
| `metadata` | 调用方元数据。 |

结构：

- `old_value`: Variant copied from the array before mutation.
- `new_value`: Variant copied into the array after mutation.
- `metadata`: Dictionary copied from the mutation call.

<a id="member-gfobservablearrayresource-signals-items_changed"></a>

### `items_changed`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
signal items_changed(changes: Array[Dictionary], metadata: Dictionary)
```

一批变更完成后发出；非 batch 单项变更也会作为单元素 changes 发出。

参数：

| 名称 | 说明 |
|---|---|
| `changes` | 变更报告列表。 |
| `metadata` | 批量元数据。 |

结构：

- `changes`: Array[Dictionary] mutation reports.
- `metadata`: Dictionary copied from begin_batch()/end_batch().

## 常量

<a id="member-gfobservablearrayresource-constants-operation_append"></a>

### `OPERATION_APPEND`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const OPERATION_APPEND: StringName = &"append"
```

追加元素。

<a id="member-gfobservablearrayresource-constants-operation_set"></a>

### `OPERATION_SET`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const OPERATION_SET: StringName = &"set"
```

设置元素。

<a id="member-gfobservablearrayresource-constants-operation_erase"></a>

### `OPERATION_ERASE`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const OPERATION_ERASE: StringName = &"erase"
```

移除元素。

<a id="member-gfobservablearrayresource-constants-operation_clear"></a>

### `OPERATION_CLEAR`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const OPERATION_CLEAR: StringName = &"clear"
```

清空数组。

<a id="member-gfobservablearrayresource-constants-operation_replace"></a>

### `OPERATION_REPLACE`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const OPERATION_REPLACE: StringName = &"replace"
```

替换全部数组内容。

## 属性

<a id="member-gfobservablearrayresource-properties-items"></a>

### `items`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var items: Array = []
```

当前数组数据。

结构：

- `items`: Array caller-owned values; mutate through methods to emit reports.

<a id="member-gfobservablearrayresource-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var metadata: Dictionary = {}
```

调用方元数据。

结构：

- `metadata`: Dictionary caller-defined resource metadata.

## 方法

<a id="member-gfobservablearrayresource-methods-set_items"></a>

### `set_items`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func set_items(values: Array, emit_change: bool = true, change_metadata: Dictionary = {}) -> Dictionary:
```

替换全部数组内容。

参数：

| 名称 | 说明 |
|---|---|
| `values` | 新数组数据。 |
| `emit_change` | 是否发出变更信号。 |
| `change_metadata` | 调用方元数据。 |

返回：变更报告。

结构：

- `values`: Array copied into items.
- `change_metadata`: Dictionary copied into the change report.
- `return`: Dictionary with ok, operation, index, old_value, new_value, metadata, and count.

<a id="member-gfobservablearrayresource-methods-get_items"></a>

### `get_items`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func get_items() -> Array:
```

获取数组副本。

返回：数组副本。

结构：

- `return`: Array duplicated from items.

<a id="member-gfobservablearrayresource-methods-append_item"></a>

### `append_item`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func append_item(value: Variant, change_metadata: Dictionary = {}) -> Dictionary:
```

追加元素。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 新元素。 |
| `change_metadata` | 调用方元数据。 |

返回：变更报告。

结构：

- `value`: Variant copied into the array.
- `change_metadata`: Dictionary copied into the change report.
- `return`: Dictionary with ok, operation, index, old_value, new_value, and metadata.

<a id="member-gfobservablearrayresource-methods-set_item"></a>

### `set_item`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func set_item(index: int, value: Variant, change_metadata: Dictionary = {}) -> Dictionary:
```

设置指定索引的元素。

参数：

| 名称 | 说明 |
|---|---|
| `index` | 目标索引。 |
| `value` | 新元素。 |
| `change_metadata` | 调用方元数据。 |

返回：变更报告。

结构：

- `value`: Variant copied into the array.
- `change_metadata`: Dictionary copied into the change report.
- `return`: Dictionary with ok, operation, index, old_value, new_value, metadata, and optional error.

<a id="member-gfobservablearrayresource-methods-erase_item_at"></a>

### `erase_item_at`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func erase_item_at(index: int, change_metadata: Dictionary = {}) -> Dictionary:
```

移除指定索引的元素。

参数：

| 名称 | 说明 |
|---|---|
| `index` | 目标索引。 |
| `change_metadata` | 调用方元数据。 |

返回：变更报告。

结构：

- `change_metadata`: Dictionary copied into the change report.
- `return`: Dictionary with ok, operation, index, old_value, new_value, metadata, and optional error.

<a id="member-gfobservablearrayresource-methods-clear_items"></a>

### `clear_items`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func clear_items(change_metadata: Dictionary = {}) -> Dictionary:
```

清空数组。

参数：

| 名称 | 说明 |
|---|---|
| `change_metadata` | 调用方元数据。 |

返回：变更报告。

结构：

- `change_metadata`: Dictionary copied into the change report.
- `return`: Dictionary with ok, operation, index, old_value, new_value, metadata, and count.

<a id="member-gfobservablearrayresource-methods-begin_batch"></a>

### `begin_batch`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func begin_batch(change_metadata: Dictionary = {}) -> void:
```

开始批量变更。

参数：

| 名称 | 说明 |
|---|---|
| `change_metadata` | 批量元数据。 |

结构：

- `change_metadata`: Dictionary merged into the batch report.

<a id="member-gfobservablearrayresource-methods-end_batch"></a>

### `end_batch`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func end_batch(change_metadata: Dictionary = {}) -> Dictionary:
```

结束批量变更。

参数：

| 名称 | 说明 |
|---|---|
| `change_metadata` | 批量元数据。 |

返回：批量报告。

结构：

- `change_metadata`: Dictionary merged into the batch report.
- `return`: Dictionary with ok, change_count, changes, and metadata.

<a id="member-gfobservablearrayresource-methods-get_count"></a>

### `get_count`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func get_count() -> int:
```

获取元素数量。

返回：元素数量。

<a id="member-gfobservablearrayresource-methods-is_empty"></a>

### `is_empty`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func is_empty() -> bool:
```

判断数组是否为空。

返回：为空时返回 true。

<a id="member-gfobservablearrayresource-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：调试快照。

结构：

- `return`: Dictionary with count, batch_depth, pending_change_count, metadata, and items.
