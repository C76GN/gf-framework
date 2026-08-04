# GFTableRowView

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/ui/gf_table_row_view.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`unreleased`

表格行谓词使用的隔离只读视图。 只公开稳定行 ID、源索引和已配置列的复制值，不公开源行容器。 项目谓词可以读取隐藏列，但不能通过该视图修改权威表格数据。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`get_row_id`](#member-gftablerowview-methods-get_row_id) | `func get_row_id() -> Variant:` |
| 方法 | [`get_source_row_index`](#member-gftablerowview-methods-get_source_row_index) | `func get_source_row_index() -> int:` |
| 方法 | [`has_value`](#member-gftablerowview-methods-has_value) | `func has_value(column_id: StringName) -> bool:` |
| 方法 | [`get_value`](#member-gftablerowview-methods-get_value) | `func get_value(column_id: StringName, default_value: Variant = null) -> Variant:` |
| 方法 | [`get_values`](#member-gftablerowview-methods-get_values) | `func get_values() -> Dictionary:` |

## 方法

<a id="member-gftablerowview-methods-get_row_id"></a>

### `get_row_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_row_id() -> Variant:
```

获取稳定行 ID 副本。

返回：稳定行 ID 副本。

结构：

- `return`: Variant stable row identity copy.

<a id="member-gftablerowview-methods-get_source_row_index"></a>

### `get_source_row_index`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_source_row_index() -> int:
```

获取源行索引。

返回：构建该视图时的源行索引。

<a id="member-gftablerowview-methods-has_value"></a>

### `has_value`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func has_value(column_id: StringName) -> bool:
```

判断是否包含指定列值。

参数：

| 名称 | 说明 |
|---|---|
| `column_id` | 稳定列 ID。 |

返回：存在列值时返回 true。

<a id="member-gftablerowview-methods-get_value"></a>

### `get_value`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_value(column_id: StringName, default_value: Variant = null) -> Variant:
```

获取指定列的隔离值副本。

参数：

| 名称 | 说明 |
|---|---|
| `column_id` | 稳定列 ID。 |
| `default_value` | 列不存在时返回的默认值。 |

返回：列值或默认值的副本。

结构：

- `default_value`: Variant fallback copied before return.
- `return`: Variant isolated column value copy.

<a id="member-gftablerowview-methods-get_values"></a>

### `get_values`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_values() -> Dictionary:
```

获取全部列值副本。

返回：以列 ID 为键的隔离值副本。

结构：

- `return`: Dictionary keyed by StringName column IDs with copied Variant values.
