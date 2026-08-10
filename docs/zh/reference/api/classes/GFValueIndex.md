# GFValueIndex

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/collections/gf_value_index.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

通用值索引。 为任意 item_id 关联值和字段，并支持按字段快速查询。它只维护索引结构， 不规定字段含义、业务规则或生命周期。 所有 mutation 都在同步信号前完整提交；信号监听器若重入修改同一索引， mutation 会失败关闭，调用方可在信号返回后或 deferred 阶段重试。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`item_indexed`](#member-gfvalueindex-signals-item_indexed) | `signal item_indexed(item_id: StringName)` |
| 信号 | [`item_removed`](#member-gfvalueindex-signals-item_removed) | `signal item_removed(item_id: StringName)` |
| 信号 | [`cleared`](#member-gfvalueindex-signals-cleared) | `signal cleared` |
| 属性 | [`duplicate_values`](#member-gfvalueindex-properties-duplicate_values) | `var duplicate_values: bool = true` |
| 方法 | [`set_item`](#member-gfvalueindex-methods-set_item) | `func set_item(item_id: StringName, value: Variant, fields: Dictionary = {}) -> bool:` |
| 方法 | [`remove_item`](#member-gfvalueindex-methods-remove_item) | `func remove_item(item_id: StringName) -> bool:` |
| 方法 | [`has_item`](#member-gfvalueindex-methods-has_item) | `func has_item(item_id: StringName) -> bool:` |
| 方法 | [`get_item`](#member-gfvalueindex-methods-get_item) | `func get_item(item_id: StringName, default_value: Variant = null) -> Variant:` |
| 方法 | [`get_fields`](#member-gfvalueindex-methods-get_fields) | `func get_fields(item_id: StringName) -> Dictionary:` |
| 方法 | [`query`](#member-gfvalueindex-methods-query) | `func query(field_id: StringName, field_value: Variant) -> PackedStringArray:` |
| 方法 | [`query_many`](#member-gfvalueindex-methods-query_many) | `func query_many(criteria: Dictionary, match_all: bool = true) -> PackedStringArray:` |
| 方法 | [`clear`](#member-gfvalueindex-methods-clear) | `func clear() -> void:` |
| 方法 | [`get_item_count`](#member-gfvalueindex-methods-get_item_count) | `func get_item_count() -> int:` |
| 方法 | [`get_index_count`](#member-gfvalueindex-methods-get_index_count) | `func get_index_count() -> int:` |
| 方法 | [`get_debug_snapshot`](#member-gfvalueindex-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfvalueindex-signals-item_indexed"></a>

### `item_indexed`

- API：`public`

```gdscript
signal item_indexed(item_id: StringName)
```

条目写入索引后发出。

参数：

| 名称 | 说明 |
|---|---|
| `item_id` | 条目标识。 |

<a id="member-gfvalueindex-signals-item_removed"></a>

### `item_removed`

- API：`public`

```gdscript
signal item_removed(item_id: StringName)
```

条目从索引移除后发出。

参数：

| 名称 | 说明 |
|---|---|
| `item_id` | 条目标识。 |

<a id="member-gfvalueindex-signals-cleared"></a>

### `cleared`

- API：`public`

```gdscript
signal cleared
```

索引清空后发出。

## 属性

<a id="member-gfvalueindex-properties-duplicate_values"></a>

### `duplicate_values`

- API：`public`

```gdscript
var duplicate_values: bool = true
```

读取或写入值时是否复制 Dictionary / Array。

## 方法

<a id="member-gfvalueindex-methods-set_item"></a>

### `set_item`

- API：`public`

```gdscript
func set_item(item_id: StringName, value: Variant, fields: Dictionary = {}) -> bool:
```

写入或替换一个条目。

参数：

| 名称 | 说明 |
|---|---|
| `item_id` | 条目标识。 |
| `value` | 条目值。 |
| `fields` | 可索引字段，字段值可为单值、Array 或 PackedStringArray。 |

返回：写入成功返回 true。

结构：

- `value`: Variant item value.
- `fields`: Dictionary from field id to scalar, Array, or PackedStringArray values.

<a id="member-gfvalueindex-methods-remove_item"></a>

### `remove_item`

- API：`public`

```gdscript
func remove_item(item_id: StringName) -> bool:
```

移除条目。

参数：

| 名称 | 说明 |
|---|---|
| `item_id` | 条目标识。 |

返回：移除成功返回 true。

<a id="member-gfvalueindex-methods-has_item"></a>

### `has_item`

- API：`public`

```gdscript
func has_item(item_id: StringName) -> bool:
```

检查条目是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `item_id` | 条目标识。 |

返回：存在返回 true。

<a id="member-gfvalueindex-methods-get_item"></a>

### `get_item`

- API：`public`

```gdscript
func get_item(item_id: StringName, default_value: Variant = null) -> Variant:
```

获取条目值。

参数：

| 名称 | 说明 |
|---|---|
| `item_id` | 条目标识。 |
| `default_value` | 不存在时返回的默认值。 |

返回：条目值或默认值。

结构：

- `default_value`: Variant fallback value.
- `return`: Variant item value or fallback value.

<a id="member-gfvalueindex-methods-get_fields"></a>

### `get_fields`

- API：`public`

```gdscript
func get_fields(item_id: StringName) -> Dictionary:
```

获取条目字段。

参数：

| 名称 | 说明 |
|---|---|
| `item_id` | 条目标识。 |

返回：字段副本。

结构：

- `return`: Dictionary indexed field values.

<a id="member-gfvalueindex-methods-query"></a>

### `query`

- API：`public`

```gdscript
func query(field_id: StringName, field_value: Variant) -> PackedStringArray:
```

按单个字段值查询条目标识。

参数：

| 名称 | 说明 |
|---|---|
| `field_id` | 字段标识。 |
| `field_value` | 字段值。 |

返回：条目标识列表。

结构：

- `field_value`: Variant indexed field value.

<a id="member-gfvalueindex-methods-query_many"></a>

### `query_many`

- API：`public`

```gdscript
func query_many(criteria: Dictionary, match_all: bool = true) -> PackedStringArray:
```

按多个字段查询条目标识。

参数：

| 名称 | 说明 |
|---|---|
| `criteria` | 字段到值的查询条件。 |
| `match_all` | true 表示交集查询，false 表示并集查询。 |

返回：条目标识列表。

结构：

- `criteria`: Dictionary from field id to query value.

<a id="member-gfvalueindex-methods-clear"></a>

### `clear`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func clear() -> void:
```

清空索引。 同步 mutation 信号派发期间调用时不执行；需要重入清理时应 deferred 调用。

<a id="member-gfvalueindex-methods-get_item_count"></a>

### `get_item_count`

- API：`public`

```gdscript
func get_item_count() -> int:
```

获取条目数量。

返回：条目数量。

<a id="member-gfvalueindex-methods-get_index_count"></a>

### `get_index_count`

- API：`public`

```gdscript
func get_index_count() -> int:
```

获取字段索引数量。

返回：字段索引数量。

<a id="member-gfvalueindex-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：调试信息字典。

结构：

- `return`: Dictionary with item_count, index_count, and duplicate_values.
