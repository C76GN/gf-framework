# GFCalendarGrid

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/time/gf_calendar_grid.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`unreleased`

完整周构成的不可变月历网格结果。 成功网格始终为 7 列、4 到 6 行，并包含目标月的全部日期。 返回的日期集合是隔离副本，不暴露内部数组。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`STATUS_BUILT`](#member-gfcalendargrid-constants-status_built) | `const STATUS_BUILT: StringName = &"built"` |
| 常量 | [`STATUS_INVALID_REQUEST`](#member-gfcalendargrid-constants-status_invalid_request) | `const STATUS_INVALID_REQUEST: StringName = &"invalid_request"` |
| 常量 | [`STATUS_INSUFFICIENT_ROWS`](#member-gfcalendargrid-constants-status_insufficient_rows) | `const STATUS_INSUFFICIENT_ROWS: StringName = &"insufficient_rows"` |
| 常量 | [`STATUS_OUT_OF_RANGE`](#member-gfcalendargrid-constants-status_out_of_range) | `const STATUS_OUT_OF_RANGE: StringName = &"out_of_range"` |
| 常量 | [`COLUMN_COUNT`](#member-gfcalendargrid-constants-column_count) | `const COLUMN_COUNT: int = 7` |
| 方法 | [`is_successful`](#member-gfcalendargrid-methods-is_successful) | `func is_successful() -> bool:` |
| 方法 | [`get_status`](#member-gfcalendargrid-methods-get_status) | `func get_status() -> StringName:` |
| 方法 | [`get_error`](#member-gfcalendargrid-methods-get_error) | `func get_error() -> String:` |
| 方法 | [`get_year`](#member-gfcalendargrid-methods-get_year) | `func get_year() -> int:` |
| 方法 | [`get_month`](#member-gfcalendargrid-methods-get_month) | `func get_month() -> int:` |
| 方法 | [`get_week_start`](#member-gfcalendargrid-methods-get_week_start) | `func get_week_start() -> int:` |
| 方法 | [`get_row_count`](#member-gfcalendargrid-methods-get_row_count) | `func get_row_count() -> int:` |
| 方法 | [`get_column_count`](#member-gfcalendargrid-methods-get_column_count) | `func get_column_count() -> int:` |
| 方法 | [`get_cell_count`](#member-gfcalendargrid-methods-get_cell_count) | `func get_cell_count() -> int:` |
| 方法 | [`get_cell`](#member-gfcalendargrid-methods-get_cell) | `func get_cell(index: int) -> GFCivilDate:` |
| 方法 | [`get_cells`](#member-gfcalendargrid-methods-get_cells) | `func get_cells() -> Array[GFCivilDate]:` |

## 常量

<a id="member-gfcalendargrid-constants-status_built"></a>

### `STATUS_BUILT`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_BUILT: StringName = &"built"
```

网格已成功构建。

<a id="member-gfcalendargrid-constants-status_invalid_request"></a>

### `STATUS_INVALID_REQUEST`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_INVALID_REQUEST: StringName = &"invalid_request"
```

目标日期、周起点或固定行数无效。

<a id="member-gfcalendargrid-constants-status_insufficient_rows"></a>

### `STATUS_INSUFFICIENT_ROWS`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_INSUFFICIENT_ROWS: StringName = &"insufficient_rows"
```

指定行数无法容纳目标月的全部日期。

<a id="member-gfcalendargrid-constants-status_out_of_range"></a>

### `STATUS_OUT_OF_RANGE`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_OUT_OF_RANGE: StringName = &"out_of_range"
```

完整周所需的相邻日期超出支持年份范围。

<a id="member-gfcalendargrid-constants-column_count"></a>

### `COLUMN_COUNT`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const COLUMN_COUNT: int = 7
```

网格固定列数。

## 方法

<a id="member-gfcalendargrid-methods-is_successful"></a>

### `is_successful`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_successful() -> bool:
```

检查网格是否成功构建。

返回：包含完整月历网格时返回 true。

<a id="member-gfcalendargrid-methods-get_status"></a>

### `get_status`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_status() -> StringName:
```

获取稳定构建状态。

返回：`STATUS_*` 常量之一。

<a id="member-gfcalendargrid-methods-get_error"></a>

### `get_error`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_error() -> String:
```

获取失败说明。

返回：成功时为空字符串。

<a id="member-gfcalendargrid-methods-get_year"></a>

### `get_year`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_year() -> int:
```

获取目标年份。

返回：成功时的目标年份；失败时返回 0。

<a id="member-gfcalendargrid-methods-get_month"></a>

### `get_month`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_month() -> int:
```

获取目标月份。

返回：成功时的 1 到 12；失败时返回 0。

<a id="member-gfcalendargrid-methods-get_week_start"></a>

### `get_week_start`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_week_start() -> int:
```

获取每周第一天。

返回：`GFCivilDate.Weekday` 值；失败时返回 0。

<a id="member-gfcalendargrid-methods-get_row_count"></a>

### `get_row_count`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_row_count() -> int:
```

获取网格行数。

返回：成功时为 4 到 6；失败时返回 0。

<a id="member-gfcalendargrid-methods-get_column_count"></a>

### `get_column_count`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_column_count() -> int:
```

获取固定列数。

返回：始终返回 7。

<a id="member-gfcalendargrid-methods-get_cell_count"></a>

### `get_cell_count`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_cell_count() -> int:
```

获取单元数。

返回：成功时为行数乘 7；失败时返回 0。

<a id="member-gfcalendargrid-methods-get_cell"></a>

### `get_cell`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_cell(index: int) -> GFCivilDate:
```

获取指定单元的日期。

参数：

| 名称 | 说明 |
|---|---|
| `index` | 从 0 开始的行主序索引。 |

返回：索引合法时的不可变日期；否则返回 null。

<a id="member-gfcalendargrid-methods-get_cells"></a>

### `get_cells`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_cells() -> Array[GFCivilDate]:
```

获取全部单元日期。

返回：按行主序排列的新数组；修改该数组不会影响网格。
