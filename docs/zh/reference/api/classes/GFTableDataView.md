# GFTableDataView

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/ui/gf_table_data_view.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`5.2.0`

通用表格数据视图模型。 维护行数据、列定义、可见行索引、排序、过滤和单元格提交， 供运行时 UI、编辑器 Dock、资源表或配置表工具自行选择渲染方式。 它不创建 Control，不规定键鼠交互、主题样式或业务字段含义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`rows_changed`](#member-gftabledataview-signals-rows_changed) | `signal rows_changed(row_count: int)` |
| 信号 | [`view_changed`](#member-gftabledataview-signals-view_changed) | `signal view_changed(visible_count: int)` |
| 信号 | [`filter_changed`](#member-gftabledataview-signals-filter_changed) | `signal filter_changed(query: String, visible_count: int)` |
| 信号 | [`sort_changed`](#member-gftabledataview-signals-sort_changed) | `signal sort_changed(column_id: StringName, ascending: bool)` |
| 信号 | [`cell_value_committed`](#member-gftabledataview-signals-cell_value_committed) | `signal cell_value_committed(` |
| 属性 | [`row_id_column`](#member-gftabledataview-properties-row_id_column) | `var row_id_column: StringName = &"id"` |
| 属性 | [`case_sensitive_filter`](#member-gftabledataview-properties-case_sensitive_filter) | `var case_sensitive_filter: bool = false` |
| 属性 | [`selection_model`](#member-gftabledataview-properties-selection_model) | `var selection_model: GFTableSelectionModel = GFTableSelectionModel.new()` |
| 方法 | [`set_columns`](#member-gftabledataview-methods-set_columns) | `func set_columns(column_definitions: Array[GFTableColumnDefinition]) -> void:` |
| 方法 | [`add_column`](#member-gftabledataview-methods-add_column) | `func add_column(column: GFTableColumnDefinition) -> bool:` |
| 方法 | [`get_columns`](#member-gftabledataview-methods-get_columns) | `func get_columns() -> Array[GFTableColumnDefinition]:` |
| 方法 | [`get_column`](#member-gftabledataview-methods-get_column) | `func get_column(column_id: StringName) -> GFTableColumnDefinition:` |
| 方法 | [`set_rows`](#member-gftabledataview-methods-set_rows) | `func set_rows(row_values: Array, duplicate_rows: bool = false) -> void:` |
| 方法 | [`append_row`](#member-gftabledataview-methods-append_row) | `func append_row(row_data: Variant) -> int:` |
| 方法 | [`remove_row`](#member-gftabledataview-methods-remove_row) | `func remove_row(row_index: int, should_prune_selection: bool = true) -> bool:` |
| 方法 | [`clear_rows`](#member-gftabledataview-methods-clear_rows) | `func clear_rows() -> void:` |
| 方法 | [`get_row_count`](#member-gftabledataview-methods-get_row_count) | `func get_row_count() -> int:` |
| 方法 | [`get_visible_row_count`](#member-gftabledataview-methods-get_visible_row_count) | `func get_visible_row_count() -> int:` |
| 方法 | [`get_row`](#member-gftabledataview-methods-get_row) | `func get_row(row_index: int) -> Variant:` |
| 方法 | [`get_visible_row`](#member-gftabledataview-methods-get_visible_row) | `func get_visible_row(visible_row_index: int) -> Variant:` |
| 方法 | [`get_source_row_index`](#member-gftabledataview-methods-get_source_row_index) | `func get_source_row_index(visible_row_index: int) -> int:` |
| 方法 | [`get_visible_row_indices`](#member-gftabledataview-methods-get_visible_row_indices) | `func get_visible_row_indices() -> PackedInt32Array:` |
| 方法 | [`get_row_id`](#member-gftabledataview-methods-get_row_id) | `func get_row_id(row_index: int) -> Variant:` |
| 方法 | [`get_visible_row_id`](#member-gftabledataview-methods-get_visible_row_id) | `func get_visible_row_id(visible_row_index: int) -> Variant:` |
| 方法 | [`get_row_ids`](#member-gftabledataview-methods-get_row_ids) | `func get_row_ids() -> Array:` |
| 方法 | [`get_visible_row_ids`](#member-gftabledataview-methods-get_visible_row_ids) | `func get_visible_row_ids() -> Array:` |
| 方法 | [`set_filter_query`](#member-gftabledataview-methods-set_filter_query) | `func set_filter_query(query: String) -> void:` |
| 方法 | [`get_filter_query`](#member-gftabledataview-methods-get_filter_query) | `func get_filter_query() -> String:` |
| 方法 | [`sort_by_column`](#member-gftabledataview-methods-sort_by_column) | `func sort_by_column(column_id: StringName, ascending: bool = true) -> bool:` |
| 方法 | [`clear_sort`](#member-gftabledataview-methods-clear_sort) | `func clear_sort() -> bool:` |
| 方法 | [`get_sort_column_id`](#member-gftabledataview-methods-get_sort_column_id) | `func get_sort_column_id() -> StringName:` |
| 方法 | [`is_sort_ascending`](#member-gftabledataview-methods-is_sort_ascending) | `func is_sort_ascending() -> bool:` |
| 方法 | [`refresh_view`](#member-gftabledataview-methods-refresh_view) | `func refresh_view() -> void:` |
| 方法 | [`get_cell_value`](#member-gftabledataview-methods-get_cell_value) | `func get_cell_value(row_index: int, column_id: StringName) -> Variant:` |
| 方法 | [`commit_cell_value`](#member-gftabledataview-methods-commit_cell_value) | `func commit_cell_value(row_index: int, column_id: StringName, new_value: Variant) -> bool:` |
| 方法 | [`commit_visible_cell_value`](#member-gftabledataview-methods-commit_visible_cell_value) | `func commit_visible_cell_value( visible_row_index: int, column_id: StringName, new_value: Variant ) -> bool:` |
| 方法 | [`commit_cell_values`](#member-gftabledataview-methods-commit_cell_values) | `func commit_cell_values(changes: Array[Dictionary]) -> Dictionary:` |
| 方法 | [`commit_visible_cell_values`](#member-gftabledataview-methods-commit_visible_cell_values) | `func commit_visible_cell_values(changes: Array[Dictionary]) -> Dictionary:` |
| 方法 | [`describe_visible_row`](#member-gftabledataview-methods-describe_visible_row) | `func describe_visible_row(visible_row_index: int) -> Dictionary:` |
| 方法 | [`describe_row`](#member-gftabledataview-methods-describe_row) | `func describe_row(row_index: int, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`describe_view`](#member-gftabledataview-methods-describe_view) | `func describe_view(options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`prune_selection`](#member-gftabledataview-methods-prune_selection) | `func prune_selection(visible_only: bool = false) -> bool:` |
| 方法 | [`get_debug_snapshot`](#member-gftabledataview-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gftabledataview-signals-rows_changed"></a>

### `rows_changed`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
signal rows_changed(row_count: int)
```

行数据集合变化后发出。

参数：

| 名称 | 说明 |
|---|---|
| `row_count` | 当前行数量。 |

<a id="member-gftabledataview-signals-view_changed"></a>

### `view_changed`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
signal view_changed(visible_count: int)
```

可见行集合变化后发出。

参数：

| 名称 | 说明 |
|---|---|
| `visible_count` | 当前可见行数量。 |

<a id="member-gftabledataview-signals-filter_changed"></a>

### `filter_changed`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
signal filter_changed(query: String, visible_count: int)
```

过滤文本变化后发出。

参数：

| 名称 | 说明 |
|---|---|
| `query` | 当前过滤文本。 |
| `visible_count` | 当前可见行数量。 |

<a id="member-gftabledataview-signals-sort_changed"></a>

### `sort_changed`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
signal sort_changed(column_id: StringName, ascending: bool)
```

排序设置变化后发出。

参数：

| 名称 | 说明 |
|---|---|
| `column_id` | 当前排序列 ID；为空表示未排序。 |
| `ascending` | 是否升序。 |

<a id="member-gftabledataview-signals-cell_value_committed"></a>

### `cell_value_committed`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
signal cell_value_committed(
```

单元格成功提交后发出。

参数：

| 名称 | 说明 |
|---|---|
| `row_index` | 源行索引。 |
| `row_id` | 稳定行 ID。 |
| `column_id` | 列 ID。 |
| `old_value` | 旧值。 |
| `new_value` | 新值。 |

结构：

- `row_id`: Variant，提交前的稳定行 ID。
- `old_value`: Variant，提交前的列值。
- `new_value`: Variant，提交后的列值。

## 属性

<a id="member-gftabledataview-properties-row_id_column"></a>

### `row_id_column`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
var row_id_column: StringName = &"id"
```

用作稳定行 ID 的字段键。为空时使用源行索引。

<a id="member-gftabledataview-properties-case_sensitive_filter"></a>

### `case_sensitive_filter`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
var case_sensitive_filter: bool = false
```

过滤时是否区分大小写。

<a id="member-gftabledataview-properties-selection_model"></a>

### `selection_model`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
var selection_model: GFTableSelectionModel = GFTableSelectionModel.new()
```

该视图使用的选择模型。

## 方法

<a id="member-gftabledataview-methods-set_columns"></a>

### `set_columns`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func set_columns(column_definitions: Array[GFTableColumnDefinition]) -> void:
```

设置列定义列表。

参数：

| 名称 | 说明 |
|---|---|
| `column_definitions` | 列定义列表；null 项会被忽略。 |

结构：

- `column_definitions`: Array，包含 GFTableColumnDefinition。

<a id="member-gftabledataview-methods-add_column"></a>

### `add_column`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func add_column(column: GFTableColumnDefinition) -> bool:
```

追加列定义。

参数：

| 名称 | 说明 |
|---|---|
| `column` | 列定义。 |

返回：追加成功返回 true。

<a id="member-gftabledataview-methods-get_columns"></a>

### `get_columns`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func get_columns() -> Array[GFTableColumnDefinition]:
```

获取列定义列表副本。

返回：列定义列表。

结构：

- `return`: Array，包含 GFTableColumnDefinition。

<a id="member-gftabledataview-methods-get_column"></a>

### `get_column`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func get_column(column_id: StringName) -> GFTableColumnDefinition:
```

获取指定列定义。

参数：

| 名称 | 说明 |
|---|---|
| `column_id` | 列 ID。 |

返回：列定义；不存在时返回 null。

<a id="member-gftabledataview-methods-set_rows"></a>

### `set_rows`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func set_rows(row_values: Array, duplicate_rows: bool = false) -> void:
```

设置源行数据。

参数：

| 名称 | 说明 |
|---|---|
| `row_values` | 行数据列表。 |
| `duplicate_rows` | 是否复制 Dictionary / Array 行数据。 |

结构：

- `row_values`: Array，调用方保存的行数据。

<a id="member-gftabledataview-methods-append_row"></a>

### `append_row`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func append_row(row_data: Variant) -> int:
```

追加源行数据。

参数：

| 名称 | 说明 |
|---|---|
| `row_data` | 行数据。 |

返回：新行索引。

结构：

- `row_data`: Variant，调用方保存的行数据。

<a id="member-gftabledataview-methods-remove_row"></a>

### `remove_row`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func remove_row(row_index: int, should_prune_selection: bool = true) -> bool:
```

移除源行。

参数：

| 名称 | 说明 |
|---|---|
| `row_index` | 源行索引。 |
| `should_prune_selection` | 是否移除已不存在行 ID 的选择。 |

返回：移除成功返回 true。

<a id="member-gftabledataview-methods-clear_rows"></a>

### `clear_rows`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func clear_rows() -> void:
```

清空所有行数据。

<a id="member-gftabledataview-methods-get_row_count"></a>

### `get_row_count`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func get_row_count() -> int:
```

获取源行数量。

返回：源行数量。

<a id="member-gftabledataview-methods-get_visible_row_count"></a>

### `get_visible_row_count`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func get_visible_row_count() -> int:
```

获取可见行数量。

返回：可见行数量。

<a id="member-gftabledataview-methods-get_row"></a>

### `get_row`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func get_row(row_index: int) -> Variant:
```

获取源行数据。

参数：

| 名称 | 说明 |
|---|---|
| `row_index` | 源行索引。 |

返回：行数据；索引无效时返回 null。

结构：

- `return`: Variant，调用方保存的行数据。

<a id="member-gftabledataview-methods-get_visible_row"></a>

### `get_visible_row`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func get_visible_row(visible_row_index: int) -> Variant:
```

获取可见行数据。

参数：

| 名称 | 说明 |
|---|---|
| `visible_row_index` | 可见行索引。 |

返回：行数据；索引无效时返回 null。

结构：

- `return`: Variant，调用方保存的行数据。

<a id="member-gftabledataview-methods-get_source_row_index"></a>

### `get_source_row_index`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func get_source_row_index(visible_row_index: int) -> int:
```

获取可见行对应的源行索引。

参数：

| 名称 | 说明 |
|---|---|
| `visible_row_index` | 可见行索引。 |

返回：源行索引；无效时返回 -1。

<a id="member-gftabledataview-methods-get_visible_row_indices"></a>

### `get_visible_row_indices`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func get_visible_row_indices() -> PackedInt32Array:
```

获取可见行源索引副本。

返回：可见行源索引。

<a id="member-gftabledataview-methods-get_row_id"></a>

### `get_row_id`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func get_row_id(row_index: int) -> Variant:
```

获取源行稳定 ID。

参数：

| 名称 | 说明 |
|---|---|
| `row_index` | 源行索引。 |

返回：稳定行 ID；没有字段值时回退为源行索引。

结构：

- `return`: Variant，稳定行 ID。

<a id="member-gftabledataview-methods-get_visible_row_id"></a>

### `get_visible_row_id`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func get_visible_row_id(visible_row_index: int) -> Variant:
```

获取可见行稳定 ID。

参数：

| 名称 | 说明 |
|---|---|
| `visible_row_index` | 可见行索引。 |

返回：稳定行 ID。

结构：

- `return`: Variant，稳定行 ID。

<a id="member-gftabledataview-methods-get_row_ids"></a>

### `get_row_ids`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func get_row_ids() -> Array:
```

获取全部源行 ID。

返回：行 ID 列表。

结构：

- `return`: Array，全部源行稳定 ID。

<a id="member-gftabledataview-methods-get_visible_row_ids"></a>

### `get_visible_row_ids`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func get_visible_row_ids() -> Array:
```

获取当前可见顺序中的行 ID。

返回：可见行 ID 列表。

结构：

- `return`: Array，当前可见顺序中的稳定行 ID。

<a id="member-gftabledataview-methods-set_filter_query"></a>

### `set_filter_query`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func set_filter_query(query: String) -> void:
```

设置过滤文本。

参数：

| 名称 | 说明 |
|---|---|
| `query` | 过滤文本；空字符串显示全部行。 |

<a id="member-gftabledataview-methods-get_filter_query"></a>

### `get_filter_query`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func get_filter_query() -> String:
```

获取当前过滤文本。

返回：过滤文本。

<a id="member-gftabledataview-methods-sort_by_column"></a>

### `sort_by_column`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func sort_by_column(column_id: StringName, ascending: bool = true) -> bool:
```

按列排序。

参数：

| 名称 | 说明 |
|---|---|
| `column_id` | 排序列 ID。 |
| `ascending` | 是否升序。 |

返回：排序设置成功返回 true。

<a id="member-gftabledataview-methods-clear_sort"></a>

### `clear_sort`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func clear_sort() -> bool:
```

清除排序。

返回：排序状态发生变化时返回 true。

<a id="member-gftabledataview-methods-get_sort_column_id"></a>

### `get_sort_column_id`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func get_sort_column_id() -> StringName:
```

获取当前排序列 ID。

返回：排序列 ID；为空表示未排序。

<a id="member-gftabledataview-methods-is_sort_ascending"></a>

### `is_sort_ascending`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func is_sort_ascending() -> bool:
```

当前排序是否升序。

返回：升序时返回 true。

<a id="member-gftabledataview-methods-refresh_view"></a>

### `refresh_view`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func refresh_view() -> void:
```

重新构建可见行索引。

<a id="member-gftabledataview-methods-get_cell_value"></a>

### `get_cell_value`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func get_cell_value(row_index: int, column_id: StringName) -> Variant:
```

获取源行单元格值。

参数：

| 名称 | 说明 |
|---|---|
| `row_index` | 源行索引。 |
| `column_id` | 列 ID。 |

返回：单元格值。

结构：

- `return`: Variant，单元格值。

<a id="member-gftabledataview-methods-commit_cell_value"></a>

### `commit_cell_value`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func commit_cell_value(row_index: int, column_id: StringName, new_value: Variant) -> bool:
```

提交源行单元格值。

参数：

| 名称 | 说明 |
|---|---|
| `row_index` | 源行索引。 |
| `column_id` | 列 ID。 |
| `new_value` | 新值。 |

返回：提交成功返回 true。

结构：

- `new_value`: Variant，要提交的新值。

<a id="member-gftabledataview-methods-commit_visible_cell_value"></a>

### `commit_visible_cell_value`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func commit_visible_cell_value( visible_row_index: int, column_id: StringName, new_value: Variant ) -> bool:
```

提交可见行单元格值。

参数：

| 名称 | 说明 |
|---|---|
| `visible_row_index` | 可见行索引。 |
| `column_id` | 列 ID。 |
| `new_value` | 新值。 |

返回：提交成功返回 true。

结构：

- `new_value`: Variant，要提交的新值。

<a id="member-gftabledataview-methods-commit_cell_values"></a>

### `commit_cell_values`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func commit_cell_values(changes: Array[Dictionary]) -> Dictionary:
```

批量提交源行单元格值。 该方法会先处理所有变更，再在有实际写入时统一刷新视图并发送单元格提交信号； 它不是事务，部分失败不会回滚已成功的变更。

参数：

| 名称 | 说明 |
|---|---|
| `changes` | 单元格变更数组；每项包含 row_index、column_id 与 new_value。 |

返回：批量提交报告。

结构：

- `changes`: Array[Dictionary]，每项包含 row_index: int、column_id: StringName/String、new_value: Variant。
- `return`: Dictionary，包含 ok、requested_count、applied_count、unchanged_count、failed_count、committed 和 errors。

<a id="member-gftabledataview-methods-commit_visible_cell_values"></a>

### `commit_visible_cell_values`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func commit_visible_cell_values(changes: Array[Dictionary]) -> Dictionary:
```

批量提交可见行单元格值。 可见行索引会在任何写入发生前解析为源行索引，避免排序或过滤重建导致同一批变更漂移。 该方法不是事务，部分失败不会回滚已成功的变更。

参数：

| 名称 | 说明 |
|---|---|
| `changes` | 单元格变更数组；每项包含 visible_row_index、column_id 与 new_value。 |

返回：批量提交报告。

结构：

- `changes`: Array[Dictionary]，每项包含 visible_row_index: int、column_id: StringName/String、new_value: Variant。
- `return`: Dictionary，包含 ok、requested_count、applied_count、unchanged_count、failed_count、committed 和 errors。

<a id="member-gftabledataview-methods-describe_visible_row"></a>

### `describe_visible_row`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func describe_visible_row(visible_row_index: int) -> Dictionary:
```

描述当前可见行。

参数：

| 名称 | 说明 |
|---|---|
| `visible_row_index` | 可见行索引。 |

返回：可见行摘要。

结构：

- `return`: Dictionary，包含 ok、row_index、visible_row_index、row_id、selected 和 values。

<a id="member-gftabledataview-methods-describe_row"></a>

### `describe_row`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func describe_row(row_index: int, options: Dictionary = {}) -> Dictionary:
```

描述源行。 返回结构面向调试、导出、编辑器表格或虚拟列表渲染，不附带具体 Control 或文件格式语义。

参数：

| 名称 | 说明 |
|---|---|
| `row_index` | 源行索引。 |
| `options` | 描述选项。 |

返回：行摘要。

结构：

- `options`: Dictionary，可包含 include_values: bool、include_hidden_columns: bool、include_row_data: bool、copy_values: bool。
- `return`: Dictionary，包含 ok、row_index、visible_row_index、row_id、selected、values 和可选 row_data。

<a id="member-gftabledataview-methods-describe_view"></a>

### `describe_view`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func describe_view(options: Dictionary = {}) -> Dictionary:
```

描述当前表格视图。 默认只导出当前可见行和可见列；调用方可以通过 options 请求源行、隐藏列或原始行数据。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 描述选项。 |

返回：视图摘要。

结构：

- `options`: Dictionary，可包含 visible_only: bool、include_values: bool、include_columns: bool、include_hidden_columns: bool、include_row_data: bool、copy_values: bool。
- `return`: Dictionary，包含 row_count、visible_count、column_count、filter_query、sort_column_id、sort_ascending、visible_only、columns 和 rows。

<a id="member-gftabledataview-methods-prune_selection"></a>

### `prune_selection`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func prune_selection(visible_only: bool = false) -> bool:
```

移除已不存在源行中的选择。

参数：

| 名称 | 说明 |
|---|---|
| `visible_only` | 为 true 时只保留当前可见行选择。 |

返回：选择发生变化时返回 true。

<a id="member-gftabledataview-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：数据视图状态字典。

结构：

- `return`: Dictionary，包含 row_count、visible_count、column_count、filter_query、sort_column_id 和 sort_ascending。
