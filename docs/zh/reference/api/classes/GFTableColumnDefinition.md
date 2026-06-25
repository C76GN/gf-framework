# GFTableColumnDefinition

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/ui/gf_table_column_definition.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`5.2.0`

通用表格列定义。 描述一列如何从任意行数据中读取、格式化、排序、过滤和写回值。 它不创建 Control、不绑定资源表或配置表格式，也不规定视觉、编辑器或业务语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`SortMode`](#member-gftablecolumndefinition-enums-sortmode) | `enum SortMode` |
| 属性 | [`column_id`](#member-gftablecolumndefinition-properties-column_id) | `var column_id: StringName = &""` |
| 属性 | [`value_key`](#member-gftablecolumndefinition-properties-value_key) | `var value_key: StringName = &""` |
| 属性 | [`display_label`](#member-gftablecolumndefinition-properties-display_label) | `var display_label: String = ""` |
| 属性 | [`visible`](#member-gftablecolumndefinition-properties-visible) | `var visible: bool = true` |
| 属性 | [`sortable`](#member-gftablecolumndefinition-properties-sortable) | `var sortable: bool = true` |
| 属性 | [`filterable`](#member-gftablecolumndefinition-properties-filterable) | `var filterable: bool = true` |
| 属性 | [`editable`](#member-gftablecolumndefinition-properties-editable) | `var editable: bool = false` |
| 属性 | [`sort_mode`](#member-gftablecolumndefinition-properties-sort_mode) | `var sort_mode: SortMode = SortMode.AUTO` |
| 属性 | [`metadata`](#member-gftablecolumndefinition-properties-metadata) | `var metadata: Dictionary = {}` |
| 属性 | [`value_getter`](#member-gftablecolumndefinition-properties-value_getter) | `var value_getter: Callable = Callable()` |
| 属性 | [`value_setter`](#member-gftablecolumndefinition-properties-value_setter) | `var value_setter: Callable = Callable()` |
| 属性 | [`value_formatter`](#member-gftablecolumndefinition-properties-value_formatter) | `var value_formatter: Callable = Callable()` |
| 属性 | [`value_comparator`](#member-gftablecolumndefinition-properties-value_comparator) | `var value_comparator: Callable = Callable()` |
| 方法 | [`configure`](#member-gftablecolumndefinition-methods-configure) | `func configure( p_column_id: StringName, p_display_label: String = "", p_value_key: StringName = &"" ) -> GFTableColumnDefinition:` |
| 方法 | [`get_column_key`](#member-gftablecolumndefinition-methods-get_column_key) | `func get_column_key() -> StringName:` |
| 方法 | [`get_value_key`](#member-gftablecolumndefinition-methods-get_value_key) | `func get_value_key() -> StringName:` |
| 方法 | [`get_display_label`](#member-gftablecolumndefinition-methods-get_display_label) | `func get_display_label() -> String:` |
| 方法 | [`read_value`](#member-gftablecolumndefinition-methods-read_value) | `func read_value(row_data: Variant) -> Variant:` |
| 方法 | [`write_value`](#member-gftablecolumndefinition-methods-write_value) | `func write_value(row_data: Variant, new_value: Variant) -> bool:` |
| 方法 | [`format_value`](#member-gftablecolumndefinition-methods-format_value) | `func format_value(value: Variant, row_data: Variant = null) -> String:` |
| 方法 | [`matches_query`](#member-gftablecolumndefinition-methods-matches_query) | `func matches_query(row_data: Variant, query: String, case_sensitive: bool = false) -> bool:` |
| 方法 | [`compare_values`](#member-gftablecolumndefinition-methods-compare_values) | `func compare_values( left_value: Variant, right_value: Variant, left_row: Variant = null, right_row: Variant = null ) -> int:` |
| 方法 | [`duplicate_column`](#member-gftablecolumndefinition-methods-duplicate_column) | `func duplicate_column() -> GFTableColumnDefinition:` |
| 方法 | [`describe`](#member-gftablecolumndefinition-methods-describe) | `func describe() -> Dictionary:` |

## 枚举

<a id="member-gftablecolumndefinition-enums-sortmode"></a>

### `SortMode`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
enum SortMode {
	## 根据值类型自动选择排序方式。
	AUTO,
	## 按文本排序。
	TEXT,
	## 按数字排序。
	NUMBER,
	## 按布尔值排序。
	BOOL,
}
```

默认排序值解释方式。

## 属性

<a id="member-gftablecolumndefinition-properties-column_id"></a>

### `column_id`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
var column_id: StringName = &""
```

列稳定 ID，用于排序、提交和保存 UI 状态。

<a id="member-gftablecolumndefinition-properties-value_key"></a>

### `value_key`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
var value_key: StringName = &""
```

读取行数据时使用的字段键。为空时使用 column_id。

<a id="member-gftablecolumndefinition-properties-display_label"></a>

### `display_label`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
var display_label: String = ""
```

显示标题。为空时使用 column_id。

<a id="member-gftablecolumndefinition-properties-visible"></a>

### `visible`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
var visible: bool = true
```

该列是否应出现在默认可见列中。

<a id="member-gftablecolumndefinition-properties-sortable"></a>

### `sortable`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
var sortable: bool = true
```

该列是否允许参与排序。

<a id="member-gftablecolumndefinition-properties-filterable"></a>

### `filterable`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
var filterable: bool = true
```

该列是否允许参与文本过滤。

<a id="member-gftablecolumndefinition-properties-editable"></a>

### `editable`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
var editable: bool = false
```

该列是否允许通过 write_value() 或 GFTableDataView.commit_cell_value() 写回。

<a id="member-gftablecolumndefinition-properties-sort_mode"></a>

### `sort_mode`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
var sort_mode: SortMode = SortMode.AUTO
```

默认排序方式。

<a id="member-gftablecolumndefinition-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
var metadata: Dictionary = {}
```

可选元数据，供项目 UI、编辑器工具或自定义渲染器使用。

结构：

- `metadata`: Dictionary，保存调用方附加到列定义上的元数据。

<a id="member-gftablecolumndefinition-properties-value_getter"></a>

### `value_getter`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
var value_getter: Callable = Callable()
```

自定义取值回调。有效时应接收 row 与 column 两个参数。

<a id="member-gftablecolumndefinition-properties-value_setter"></a>

### `value_setter`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
var value_setter: Callable = Callable()
```

自定义写值回调。有效时应接收 row、value 与 column 三个参数；返回 false 表示写入失败。

<a id="member-gftablecolumndefinition-properties-value_formatter"></a>

### `value_formatter`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
var value_formatter: Callable = Callable()
```

自定义格式化回调。有效时应接收 value、row 与 column 三个参数。

<a id="member-gftablecolumndefinition-properties-value_comparator"></a>

### `value_comparator`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
var value_comparator: Callable = Callable()
```

自定义比较回调。有效时应接收 left_value、right_value、left_row、right_row 与 column 五个参数。

## 方法

<a id="member-gftablecolumndefinition-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func configure( p_column_id: StringName, p_display_label: String = "", p_value_key: StringName = &"" ) -> GFTableColumnDefinition:
```

配置列定义并返回自身，便于测试或运行时快速创建列。

参数：

| 名称 | 说明 |
|---|---|
| `p_column_id` | 列稳定 ID。 |
| `p_display_label` | 可选显示标题。 |
| `p_value_key` | 可选字段键；为空时使用列 ID。 |

返回：当前列定义。

<a id="member-gftablecolumndefinition-methods-get_column_key"></a>

### `get_column_key`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func get_column_key() -> StringName:
```

获取稳定列键。

返回：列 ID。

<a id="member-gftablecolumndefinition-methods-get_value_key"></a>

### `get_value_key`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func get_value_key() -> StringName:
```

获取读取值时使用的字段键。

返回：字段键。

<a id="member-gftablecolumndefinition-methods-get_display_label"></a>

### `get_display_label`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func get_display_label() -> String:
```

获取显示标题。

返回：显示标题。

<a id="member-gftablecolumndefinition-methods-read_value"></a>

### `read_value`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func read_value(row_data: Variant) -> Variant:
```

从行数据中读取该列的值。

参数：

| 名称 | 说明 |
|---|---|
| `row_data` | 行数据，可为 Dictionary、Object、Resource 或自定义回调支持的类型。 |

返回：读取到的值。

结构：

- `row_data`: Variant，调用方保存的行数据。
- `return`: Variant，列值。

<a id="member-gftablecolumndefinition-methods-write_value"></a>

### `write_value`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func write_value(row_data: Variant, new_value: Variant) -> bool:
```

将该列的值写回行数据。

参数：

| 名称 | 说明 |
|---|---|
| `row_data` | 行数据。 |
| `new_value` | 要写入的新值。 |

返回：写入成功返回 true。

结构：

- `row_data`: Variant，调用方保存的行数据。
- `new_value`: Variant，列新值。

<a id="member-gftablecolumndefinition-methods-format_value"></a>

### `format_value`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func format_value(value: Variant, row_data: Variant = null) -> String:
```

将值格式化成用于过滤或显示的文本。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 列值。 |
| `row_data` | 行数据。 |

返回：文本值。

结构：

- `value`: Variant，待格式化列值。
- `row_data`: Variant，调用方保存的行数据。

<a id="member-gftablecolumndefinition-methods-matches_query"></a>

### `matches_query`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func matches_query(row_data: Variant, query: String, case_sensitive: bool = false) -> bool:
```

判断该列是否匹配过滤文本。

参数：

| 名称 | 说明 |
|---|---|
| `row_data` | 行数据。 |
| `query` | 过滤文本。 |
| `case_sensitive` | 是否区分大小写。 |

返回：匹配时返回 true。

结构：

- `row_data`: Variant，调用方保存的行数据。

<a id="member-gftablecolumndefinition-methods-compare_values"></a>

### `compare_values`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func compare_values( left_value: Variant, right_value: Variant, left_row: Variant = null, right_row: Variant = null ) -> int:
```

比较两个行值。

参数：

| 名称 | 说明 |
|---|---|
| `left_value` | 左侧值。 |
| `right_value` | 右侧值。 |
| `left_row` | 左侧行数据。 |
| `right_row` | 右侧行数据。 |

返回：小于返回 -1，等于返回 0，大于返回 1。

结构：

- `left_value`: Variant，左侧列值。
- `right_value`: Variant，右侧列值。
- `left_row`: Variant，左侧行数据。
- `right_row`: Variant，右侧行数据。

<a id="member-gftablecolumndefinition-methods-duplicate_column"></a>

### `duplicate_column`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func duplicate_column() -> GFTableColumnDefinition:
```

创建同内容拷贝。

返回：新列定义。

<a id="member-gftablecolumndefinition-methods-describe"></a>

### `describe`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func describe() -> Dictionary:
```

导出列定义摘要。

返回：列定义字典。

结构：

- `return`: Dictionary，包含 column_id、value_key、display_label、visible、sortable、filterable、editable、sort_mode 和 metadata。
