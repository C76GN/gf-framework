# GFObservableDictionaryResource

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/collections/gf_observable_dictionary_resource.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`6.0.0`

可观察字典资源。 保存一份 Dictionary 数据，并通过显式方法发出键值变更和批量变更信号。 它不尝试模拟 Dictionary 的全部接口，避免把业务状态模型写死到框架层。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`entry_changed`](#member-gfobservabledictionaryresource-signals-entry_changed) | `signal entry_changed(operation: StringName, entry_key: Variant, old_value: Variant, new_value: Variant, metadata: Dictionary)` |
| 信号 | [`entries_changed`](#member-gfobservabledictionaryresource-signals-entries_changed) | `signal entries_changed(changes: Array[Dictionary], metadata: Dictionary)` |
| 常量 | [`OPERATION_SET`](#member-gfobservabledictionaryresource-constants-operation_set) | `const OPERATION_SET: StringName = &"set"` |
| 常量 | [`OPERATION_ERASE`](#member-gfobservabledictionaryresource-constants-operation_erase) | `const OPERATION_ERASE: StringName = &"erase"` |
| 常量 | [`OPERATION_CLEAR`](#member-gfobservabledictionaryresource-constants-operation_clear) | `const OPERATION_CLEAR: StringName = &"clear"` |
| 常量 | [`OPERATION_REPLACE`](#member-gfobservabledictionaryresource-constants-operation_replace) | `const OPERATION_REPLACE: StringName = &"replace"` |
| 属性 | [`entries`](#member-gfobservabledictionaryresource-properties-entries) | `var entries: Dictionary = {}` |
| 属性 | [`metadata`](#member-gfobservabledictionaryresource-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`set_entries`](#member-gfobservabledictionaryresource-methods-set_entries) | `func set_entries(values: Dictionary, emit_change: bool = true, change_metadata: Dictionary = {}) -> Dictionary:` |
| 方法 | [`get_entries`](#member-gfobservabledictionaryresource-methods-get_entries) | `func get_entries() -> Dictionary:` |
| 方法 | [`set_value`](#member-gfobservabledictionaryresource-methods-set_value) | `func set_value(entry_key: Variant, value: Variant, change_metadata: Dictionary = {}) -> Dictionary:` |
| 方法 | [`erase_value`](#member-gfobservabledictionaryresource-methods-erase_value) | `func erase_value(entry_key: Variant, change_metadata: Dictionary = {}) -> Dictionary:` |
| 方法 | [`clear_entries`](#member-gfobservabledictionaryresource-methods-clear_entries) | `func clear_entries(change_metadata: Dictionary = {}) -> Dictionary:` |
| 方法 | [`begin_batch`](#member-gfobservabledictionaryresource-methods-begin_batch) | `func begin_batch(change_metadata: Dictionary = {}) -> void:` |
| 方法 | [`end_batch`](#member-gfobservabledictionaryresource-methods-end_batch) | `func end_batch(change_metadata: Dictionary = {}) -> Dictionary:` |
| 方法 | [`has_key`](#member-gfobservabledictionaryresource-methods-has_key) | `func has_key(entry_key: Variant) -> bool:` |
| 方法 | [`get_value`](#member-gfobservabledictionaryresource-methods-get_value) | `func get_value(entry_key: Variant, default_value: Variant = null) -> Variant:` |
| 方法 | [`get_count`](#member-gfobservabledictionaryresource-methods-get_count) | `func get_count() -> int:` |
| 方法 | [`is_empty`](#member-gfobservabledictionaryresource-methods-is_empty) | `func is_empty() -> bool:` |
| 方法 | [`get_debug_snapshot`](#member-gfobservabledictionaryresource-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfobservabledictionaryresource-signals-entry_changed"></a>

### `entry_changed`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
signal entry_changed(operation: StringName, entry_key: Variant, old_value: Variant, new_value: Variant, metadata: Dictionary)
```

单个键值变更后发出。

参数：

| 名称 | 说明 |
|---|---|
| `operation` | 操作类型。 |
| `entry_key` | 变更键。 |
| `old_value` | 旧值。 |
| `new_value` | 新值。 |
| `metadata` | 调用方元数据。 |

结构：

- `entry_key`: Variant dictionary key.
- `old_value`: Variant copied from the dictionary before mutation.
- `new_value`: Variant copied into the dictionary after mutation.
- `metadata`: Dictionary copied from the mutation call.

<a id="member-gfobservabledictionaryresource-signals-entries_changed"></a>

### `entries_changed`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
signal entries_changed(changes: Array[Dictionary], metadata: Dictionary)
```

一批键值变更完成后发出。

参数：

| 名称 | 说明 |
|---|---|
| `changes` | 变更报告列表。 |
| `metadata` | 批量元数据。 |

结构：

- `changes`: Array[Dictionary] mutation reports.
- `metadata`: Dictionary copied from begin_batch()/end_batch().

## 常量

<a id="member-gfobservabledictionaryresource-constants-operation_set"></a>

### `OPERATION_SET`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const OPERATION_SET: StringName = &"set"
```

设置键值。

<a id="member-gfobservabledictionaryresource-constants-operation_erase"></a>

### `OPERATION_ERASE`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const OPERATION_ERASE: StringName = &"erase"
```

移除键值。

<a id="member-gfobservabledictionaryresource-constants-operation_clear"></a>

### `OPERATION_CLEAR`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const OPERATION_CLEAR: StringName = &"clear"
```

清空字典。

<a id="member-gfobservabledictionaryresource-constants-operation_replace"></a>

### `OPERATION_REPLACE`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const OPERATION_REPLACE: StringName = &"replace"
```

替换全部字典内容。

## 属性

<a id="member-gfobservabledictionaryresource-properties-entries"></a>

### `entries`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var entries: Dictionary = {}
```

当前字典数据。

结构：

- `entries`: Dictionary caller-owned values; mutate through methods to emit reports.

<a id="member-gfobservabledictionaryresource-properties-metadata"></a>

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

<a id="member-gfobservabledictionaryresource-methods-set_entries"></a>

### `set_entries`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func set_entries(values: Dictionary, emit_change: bool = true, change_metadata: Dictionary = {}) -> Dictionary:
```

替换全部字典内容。

参数：

| 名称 | 说明 |
|---|---|
| `values` | 新字典数据。 |
| `emit_change` | 是否发出变更信号。 |
| `change_metadata` | 调用方元数据。 |

返回：变更报告。

结构：

- `values`: Dictionary copied into entries.
- `change_metadata`: Dictionary copied into the change report.
- `return`: Dictionary with ok, operation, entry_key, old_value, new_value, metadata, and count.

<a id="member-gfobservabledictionaryresource-methods-get_entries"></a>

### `get_entries`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func get_entries() -> Dictionary:
```

获取字典副本。

返回：字典副本。

结构：

- `return`: Dictionary duplicated from entries.

<a id="member-gfobservabledictionaryresource-methods-set_value"></a>

### `set_value`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func set_value(entry_key: Variant, value: Variant, change_metadata: Dictionary = {}) -> Dictionary:
```

设置键值。

参数：

| 名称 | 说明 |
|---|---|
| `entry_key` | 目标键。 |
| `value` | 新值。 |
| `change_metadata` | 调用方元数据。 |

返回：变更报告。

结构：

- `entry_key`: Variant dictionary key.
- `value`: Variant copied into the dictionary.
- `change_metadata`: Dictionary copied into the change report.
- `return`: Dictionary with ok, operation, entry_key, old_value, new_value, metadata, and existed.

<a id="member-gfobservabledictionaryresource-methods-erase_value"></a>

### `erase_value`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func erase_value(entry_key: Variant, change_metadata: Dictionary = {}) -> Dictionary:
```

移除键值。

参数：

| 名称 | 说明 |
|---|---|
| `entry_key` | 目标键。 |
| `change_metadata` | 调用方元数据。 |

返回：变更报告。

结构：

- `entry_key`: Variant dictionary key.
- `change_metadata`: Dictionary copied into the change report.
- `return`: Dictionary with ok, operation, entry_key, old_value, new_value, metadata, and optional error.

<a id="member-gfobservabledictionaryresource-methods-clear_entries"></a>

### `clear_entries`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func clear_entries(change_metadata: Dictionary = {}) -> Dictionary:
```

清空字典。

参数：

| 名称 | 说明 |
|---|---|
| `change_metadata` | 调用方元数据。 |

返回：变更报告。

结构：

- `change_metadata`: Dictionary copied into the change report.
- `return`: Dictionary with ok, operation, entry_key, old_value, new_value, metadata, and count.

<a id="member-gfobservabledictionaryresource-methods-begin_batch"></a>

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

<a id="member-gfobservabledictionaryresource-methods-end_batch"></a>

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

<a id="member-gfobservabledictionaryresource-methods-has_key"></a>

### `has_key`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func has_key(entry_key: Variant) -> bool:
```

检查键是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `entry_key` | 目标键。 |

返回：存在时返回 true。

结构：

- `entry_key`: Variant dictionary key.

<a id="member-gfobservabledictionaryresource-methods-get_value"></a>

### `get_value`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func get_value(entry_key: Variant, default_value: Variant = null) -> Variant:
```

获取键值副本。

参数：

| 名称 | 说明 |
|---|---|
| `entry_key` | 目标键。 |
| `default_value` | 缺失时的默认值。 |

返回：键值副本或默认值。

结构：

- `entry_key`: Variant dictionary key.
- `default_value`: Variant fallback returned when the key is absent.
- `return`: Variant copied from entries or default_value.

<a id="member-gfobservabledictionaryresource-methods-get_count"></a>

### `get_count`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func get_count() -> int:
```

获取键值数量。

返回：键值数量。

<a id="member-gfobservabledictionaryresource-methods-is_empty"></a>

### `is_empty`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func is_empty() -> bool:
```

判断字典是否为空。

返回：为空时返回 true。

<a id="member-gfobservabledictionaryresource-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：调试快照。

结构：

- `return`: Dictionary with count, batch_depth, pending_change_count, metadata, and entries.
