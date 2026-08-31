# GFCivilDateDifferenceResult

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/time/gf_civil_date_difference_result.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`11.0.0`

两个公民日期的不可变关系结果。 成功时同时表达有符号日差与比较次序，失败时不使用 0 伪装相等。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`STATUS_OK`](#member-gfcivildatedifferenceresult-constants-status_ok) | `const STATUS_OK: StringName = &"ok"` |
| 常量 | [`STATUS_INVALID_DATE`](#member-gfcivildatedifferenceresult-constants-status_invalid_date) | `const STATUS_INVALID_DATE: StringName = &"invalid_date"` |
| 方法 | [`is_successful`](#member-gfcivildatedifferenceresult-methods-is_successful) | `func is_successful() -> bool:` |
| 方法 | [`get_status`](#member-gfcivildatedifferenceresult-methods-get_status) | `func get_status() -> StringName:` |
| 方法 | [`get_days`](#member-gfcivildatedifferenceresult-methods-get_days) | `func get_days() -> int:` |
| 方法 | [`get_comparison`](#member-gfcivildatedifferenceresult-methods-get_comparison) | `func get_comparison() -> int:` |
| 方法 | [`get_error`](#member-gfcivildatedifferenceresult-methods-get_error) | `func get_error() -> String:` |

## 常量

<a id="member-gfcivildatedifferenceresult-constants-status_ok"></a>

### `STATUS_OK`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const STATUS_OK: StringName = &"ok"
```

日期关系已成功计算。

<a id="member-gfcivildatedifferenceresult-constants-status_invalid_date"></a>

### `STATUS_INVALID_DATE`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const STATUS_INVALID_DATE: StringName = &"invalid_date"
```

任一输入不是有效公民日期。

## 方法

<a id="member-gfcivildatedifferenceresult-methods-is_successful"></a>

### `is_successful`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func is_successful() -> bool:
```

检查日期关系是否成功计算。

返回：成功时返回 true。

<a id="member-gfcivildatedifferenceresult-methods-get_status"></a>

### `get_status`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_status() -> StringName:
```

获取稳定结果状态。

返回：`STATUS_*` 常量之一。

<a id="member-gfcivildatedifferenceresult-methods-get_days"></a>

### `get_days`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_days() -> int:
```

获取从左侧日期到右侧日期的有符号日数。

返回：成功时的 `right - left` 日差；失败时返回 0，应先检查 [method is_successful]。

<a id="member-gfcivildatedifferenceresult-methods-get_comparison"></a>

### `get_comparison`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_comparison() -> int:
```

获取左侧日期相对右侧日期的比较结果。

返回：左侧较早为 -1，相等为 0，较晚为 1；失败时返回 0。

<a id="member-gfcivildatedifferenceresult-methods-get_error"></a>

### `get_error`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_error() -> String:
```

获取失败说明。

返回：成功时为空字符串。
