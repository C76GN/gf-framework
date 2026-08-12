# GFCivilDate

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/time/gf_civil_date.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`unreleased`

无时区、无时刻的不可变公民日期。 使用前推格里高利历，支持 0001-01-01 到 9999-12-31。 本类只处理日期数学，不读取系统时钟，不包含时区、语言区域、节假日或业务日规则。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`Weekday`](#member-gfcivildate-enums-weekday) | `enum Weekday` |
| 常量 | [`MIN_YEAR`](#member-gfcivildate-constants-min_year) | `const MIN_YEAR: int = 1` |
| 常量 | [`MAX_YEAR`](#member-gfcivildate-constants-max_year) | `const MAX_YEAR: int = 9999` |
| 方法 | [`create`](#member-gfcivildate-methods-create) | `static func create(year: int, month: int, day: int) -> GFCivilDateResult:` |
| 方法 | [`parse_iso8601`](#member-gfcivildate-methods-parse_iso8601) | `static func parse_iso8601(text: String) -> GFCivilDateResult:` |
| 方法 | [`from_dict`](#member-gfcivildate-methods-from_dict) | `static func from_dict(data: Dictionary) -> GFCivilDateResult:` |
| 方法 | [`from_ordinal`](#member-gfcivildate-methods-from_ordinal) | `static func from_ordinal(ordinal: int) -> GFCivilDateResult:` |
| 方法 | [`is_leap_year`](#member-gfcivildate-methods-is_leap_year) | `static func is_leap_year(year: int) -> bool:` |
| 方法 | [`get_days_in_month`](#member-gfcivildate-methods-get_days_in_month) | `static func get_days_in_month(year: int, month: int) -> int:` |
| 方法 | [`is_valid`](#member-gfcivildate-methods-is_valid) | `func is_valid() -> bool:` |
| 方法 | [`get_year`](#member-gfcivildate-methods-get_year) | `func get_year() -> int:` |
| 方法 | [`get_month`](#member-gfcivildate-methods-get_month) | `func get_month() -> int:` |
| 方法 | [`get_day`](#member-gfcivildate-methods-get_day) | `func get_day() -> int:` |
| 方法 | [`to_iso8601`](#member-gfcivildate-methods-to_iso8601) | `func to_iso8601() -> String:` |
| 方法 | [`to_dict`](#member-gfcivildate-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`to_ordinal`](#member-gfcivildate-methods-to_ordinal) | `func to_ordinal() -> int:` |
| 方法 | [`get_weekday`](#member-gfcivildate-methods-get_weekday) | `func get_weekday() -> int:` |
| 方法 | [`get_day_of_year`](#member-gfcivildate-methods-get_day_of_year) | `func get_day_of_year() -> int:` |
| 方法 | [`get_iso_week_year`](#member-gfcivildate-methods-get_iso_week_year) | `func get_iso_week_year() -> int:` |
| 方法 | [`get_iso_week_number`](#member-gfcivildate-methods-get_iso_week_number) | `func get_iso_week_number() -> int:` |
| 方法 | [`add_days`](#member-gfcivildate-methods-add_days) | `func add_days(days: int) -> GFCivilDateResult:` |
| 方法 | [`add_months`](#member-gfcivildate-methods-add_months) | `func add_months(months: int, clamp_day: bool = true) -> GFCivilDateResult:` |
| 方法 | [`add_years`](#member-gfcivildate-methods-add_years) | `func add_years(years: int, clamp_day: bool = true) -> GFCivilDateResult:` |
| 方法 | [`compare_to`](#member-gfcivildate-methods-compare_to) | `func compare_to(other: GFCivilDate) -> GFCivilDateDifferenceResult:` |
| 方法 | [`days_until`](#member-gfcivildate-methods-days_until) | `func days_until(other: GFCivilDate) -> GFCivilDateDifferenceResult:` |

## 枚举

<a id="member-gfcivildate-enums-weekday"></a>

### `Weekday`

- API：`public`
- 首次版本：`unreleased`

```gdscript
enum Weekday {
	## 星期一。
	MONDAY = 1,
	## 星期二。
	TUESDAY = 2,
	## 星期三。
	WEDNESDAY = 3,
	## 星期四。
	THURSDAY = 4,
	## 星期五。
	FRIDAY = 5,
	## 星期六。
	SATURDAY = 6,
	## 星期日。
	SUNDAY = 7,
}
```

ISO 8601 星期编号，星期一为 1，星期日为 7。

## 常量

<a id="member-gfcivildate-constants-min_year"></a>

### `MIN_YEAR`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const MIN_YEAR: int = 1
```

最小支持年份。

<a id="member-gfcivildate-constants-max_year"></a>

### `MAX_YEAR`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const MAX_YEAR: int = 9999
```

最大支持年份。

## 方法

<a id="member-gfcivildate-methods-create"></a>

### `create`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func create(year: int, month: int, day: int) -> GFCivilDateResult:
```

创建公民日期。

参数：

| 名称 | 说明 |
|---|---|
| `year` | 1 到 9999 的年份。 |
| `month` | 1 到 12 的月份。 |
| `day` | 当月有效日。 |

返回：显式成功或失败结果；不钳制输入。

<a id="member-gfcivildate-methods-parse_iso8601"></a>

### `parse_iso8601`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func parse_iso8601(text: String) -> GFCivilDateResult:
```

解析固定长度 ISO 8601 日期文本。

参数：

| 名称 | 说明 |
|---|---|
| `text` | 严格的 \`YYYY-MM-DD\` 文本，不接受空白、符号或可变位数。 |

返回：解析结果；格式错误与日期错误使用不同状态。

<a id="member-gfcivildate-methods-from_dict"></a>

### `from_dict`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func from_dict(data: Dictionary) -> GFCivilDateResult:
```

从稳定字典 schema 恢复日期。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 包含整数 year、month 与 day 的字典。 |

返回：解析结果；缺少字段或字段类型错误时为 `STATUS_INVALID_FORMAT`。

结构：

- `data`: Closed Dictionary with exactly integer year, month, and day fields.

<a id="member-gfcivildate-methods-from_ordinal"></a>

### `from_ordinal`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func from_ordinal(ordinal: int) -> GFCivilDateResult:
```

从零起点日序号创建日期。

参数：

| 名称 | 说明 |
|---|---|
| `ordinal` | 0001-01-01 为 0 的日序号。 |

返回：序号在支持范围内时的日期结果。

<a id="member-gfcivildate-methods-is_leap_year"></a>

### `is_leap_year`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func is_leap_year(year: int) -> bool:
```

检查年份是否为前推格里高利历闰年。

参数：

| 名称 | 说明 |
|---|---|
| `year` | 待检查年份。 |

返回：1 到 9999 之内且符合闰年规则时返回 true。

<a id="member-gfcivildate-methods-get_days_in_month"></a>

### `get_days_in_month`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func get_days_in_month(year: int, month: int) -> int:
```

获取指定月天数。

参数：

| 名称 | 说明 |
|---|---|
| `year` | 1 到 9999 的年份。 |
| `month` | 1 到 12 的月份。 |

返回：当月天数；输入越界时返回 0。

<a id="member-gfcivildate-methods-is_valid"></a>

### `is_valid`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_valid() -> bool:
```

检查实例是否由日期工厂成功配置。

返回：包含支持范围内有效日期时返回 true。

<a id="member-gfcivildate-methods-get_year"></a>

### `get_year`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_year() -> int:
```

获取年份。

返回：年份；未配置实例返回 0。

<a id="member-gfcivildate-methods-get_month"></a>

### `get_month`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_month() -> int:
```

获取月份。

返回：1 到 12；未配置实例返回 0。

<a id="member-gfcivildate-methods-get_day"></a>

### `get_day`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_day() -> int:
```

获取月内日。

返回：1 到当月天数；未配置实例返回 0。

<a id="member-gfcivildate-methods-to_iso8601"></a>

### `to_iso8601`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func to_iso8601() -> String:
```

转换为固定长度 ISO 8601 日期文本。

返回：`YYYY-MM-DD`；未配置实例返回空字符串。

<a id="member-gfcivildate-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func to_dict() -> Dictionary:
```

转换为稳定组件字典。

返回：包含整数 year、month 与 day 的新字典；未配置时为空字典。

结构：

- `return`: Dictionary with integer year, month, and day fields.

<a id="member-gfcivildate-methods-to_ordinal"></a>

### `to_ordinal`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func to_ordinal() -> int:
```

获取零起点日序号。

返回：0001-01-01 为 0 的日序号；未配置时返回 -1。

<a id="member-gfcivildate-methods-get_weekday"></a>

### `get_weekday`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_weekday() -> int:
```

获取 ISO 8601 星期编号。

返回：`Weekday` 值；未配置时返回 0。

<a id="member-gfcivildate-methods-get_day_of_year"></a>

### `get_day_of_year`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_day_of_year() -> int:
```

获取年内日序号。

返回：1 到 366；未配置时返回 0。

<a id="member-gfcivildate-methods-get_iso_week_year"></a>

### `get_iso_week_year`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_iso_week_year() -> int:
```

获取 ISO 周所属周年。

返回：ISO 周年；未配置时返回 0。

<a id="member-gfcivildate-methods-get_iso_week_number"></a>

### `get_iso_week_number`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_iso_week_number() -> int:
```

获取 ISO 周序号。

返回：1 到 53；未配置时返回 0。

<a id="member-gfcivildate-methods-add_days"></a>

### `add_days`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func add_days(days: int) -> GFCivilDateResult:
```

加减日数。

参数：

| 名称 | 说明 |
|---|---|
| `days` | 可为负数的日偏移。 |

返回：偏移后日期；未配置或超出支持范围时失败。

<a id="member-gfcivildate-methods-add_months"></a>

### `add_months`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func add_months(months: int, clamp_day: bool = true) -> GFCivilDateResult:
```

加减自然月。

参数：

| 名称 | 说明 |
|---|---|
| `months` | 可为负数的月偏移。 |
| `clamp_day` | 目标月不含原月内日时，true 钳制到月末，false 返回失败。 |

返回：偏移后日期或显式失败。

<a id="member-gfcivildate-methods-add_years"></a>

### `add_years`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func add_years(years: int, clamp_day: bool = true) -> GFCivilDateResult:
```

加减公民年。

参数：

| 名称 | 说明 |
|---|---|
| `years` | 可为负数的年偏移。 |
| `clamp_day` | 目标年不含原月内日时，true 钳制到月末，false 返回失败。 |

返回：偏移后日期或显式失败。

<a id="member-gfcivildate-methods-compare_to"></a>

### `compare_to`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func compare_to(other: GFCivilDate) -> GFCivilDateDifferenceResult:
```

比较当前日期与另一日期。

参数：

| 名称 | 说明 |
|---|---|
| `other` | 右侧日期。 |

返回：包含比较次序与 `other - self` 日差的类型化结果。

<a id="member-gfcivildate-methods-days_until"></a>

### `days_until`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func days_until(other: GFCivilDate) -> GFCivilDateDifferenceResult:
```

计算从当前日期到另一日期的有符号日数。

参数：

| 名称 | 说明 |
|---|---|
| `other` | 右侧日期。 |

返回：包含 `other - self` 日差和比较次序的类型化结果。
