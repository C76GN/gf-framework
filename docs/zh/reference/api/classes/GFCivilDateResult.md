# GFCivilDateResult

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/time/gf_civil_date_result.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`unreleased`

公民日期创建或运算的不可变结果。 成功与失败都使用稳定状态表达，避免用零值日期、隐式钳制或 null 猜测失败原因。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`STATUS_OK`](#member-gfcivildateresult-constants-status_ok) | `const STATUS_OK: StringName = &"ok"` |
| 常量 | [`STATUS_OUT_OF_RANGE`](#member-gfcivildateresult-constants-status_out_of_range) | `const STATUS_OUT_OF_RANGE: StringName = &"out_of_range"` |
| 常量 | [`STATUS_INVALID_DATE`](#member-gfcivildateresult-constants-status_invalid_date) | `const STATUS_INVALID_DATE: StringName = &"invalid_date"` |
| 常量 | [`STATUS_INVALID_FORMAT`](#member-gfcivildateresult-constants-status_invalid_format) | `const STATUS_INVALID_FORMAT: StringName = &"invalid_format"` |
| 方法 | [`is_successful`](#member-gfcivildateresult-methods-is_successful) | `func is_successful() -> bool:` |
| 方法 | [`get_status`](#member-gfcivildateresult-methods-get_status) | `func get_status() -> StringName:` |
| 方法 | [`get_date`](#member-gfcivildateresult-methods-get_date) | `func get_date() -> GFCivilDate:` |
| 方法 | [`get_error`](#member-gfcivildateresult-methods-get_error) | `func get_error() -> String:` |

## 常量

<a id="member-gfcivildateresult-constants-status_ok"></a>

### `STATUS_OK`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_OK: StringName = &"ok"
```

日期已成功创建或计算。

<a id="member-gfcivildateresult-constants-status_out_of_range"></a>

### `STATUS_OUT_OF_RANGE`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_OUT_OF_RANGE: StringName = &"out_of_range"
```

年份或运算结果超出支持范围。

<a id="member-gfcivildateresult-constants-status_invalid_date"></a>

### `STATUS_INVALID_DATE`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_INVALID_DATE: StringName = &"invalid_date"
```

年、月、日组合不是有效公民日期。

<a id="member-gfcivildateresult-constants-status_invalid_format"></a>

### `STATUS_INVALID_FORMAT`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_INVALID_FORMAT: StringName = &"invalid_format"
```

日期文本或字典不符合声明的稳定格式。

## 方法

<a id="member-gfcivildateresult-methods-is_successful"></a>

### `is_successful`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_successful() -> bool:
```

检查操作是否成功。

返回：包含有效日期时返回 true。

<a id="member-gfcivildateresult-methods-get_status"></a>

### `get_status`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_status() -> StringName:
```

获取稳定结果状态。

返回：`STATUS_*` 常量之一。

<a id="member-gfcivildateresult-methods-get_date"></a>

### `get_date`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_date() -> GFCivilDate:
```

获取成功日期。

返回：成功时返回不可变日期；失败时返回 null。

<a id="member-gfcivildateresult-methods-get_error"></a>

### `get_error`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_error() -> String:
```

获取稳定失败说明。

返回：成功时为空字符串。
