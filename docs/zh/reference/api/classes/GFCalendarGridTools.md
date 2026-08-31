# GFCalendarGridTools

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/time/gf_calendar_grid_tools.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`11.0.0`

从公民日期构建通用月历网格。 只计算完整周和相邻日期，不创建 UI 节点，不决定语言区域、节假日、选中态或业务标记。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`build_month_grid`](#member-gfcalendargridtools-methods-build_month_grid) | `static func build_month_grid( month: GFCivilDate, week_start: int = GFCivilDate.Weekday.MONDAY, fixed_rows: int = 0 ) -> GFCalendarGrid:` |

## 方法

<a id="member-gfcalendargridtools-methods-build_month_grid"></a>

### `build_month_grid`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
static func build_month_grid( month: GFCivilDate, week_start: int = GFCivilDate.Weekday.MONDAY, fixed_rows: int = 0 ) -> GFCalendarGrid:
```

构建包含目标月全部日期的完整周网格。

参数：

| 名称 | 说明 |
|---|---|
| `month` | 目标月内的任意有效日期，其日值不影响结果。 |
| `week_start` | \`GFCivilDate.Weekday\` 值，默认星期一。 |
| `fixed_rows` | 0 表示最小完整周数；否则必须为 4、5 或 6。 |

返回：7 列、4 到 6 行的网格，或包含稳定失败状态的结果。
