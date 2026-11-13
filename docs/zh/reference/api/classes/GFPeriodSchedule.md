# GFPeriodSchedule

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/time/gf_period_schedule.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`unreleased`

UTC 或固定偏移下的冻结周期政策。 只计算 daily、weekly 或 fixed 窗口，不处理地区时区、DST、闰秒、奖励或补签。 周期身份包含计划身份、版本、实际政策和窗口起点；改变政策不会复用旧身份。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`create`](#member-gfperiodschedule-methods-create) | `static func create( schedule_id: StringName, version: int, options: Dictionary = {} ) -> GFPeriodSchedule:` |
| 方法 | [`get_window`](#member-gfperiodschedule-methods-get_window) | `func get_window(unix_msec: int) -> GFTimeWindow:` |
| 方法 | [`to_record`](#member-gfperiodschedule-methods-to_record) | `func to_record() -> Dictionary:` |

## 方法

<a id="member-gfperiodschedule-methods-create"></a>

### `create`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func create( schedule_id: StringName, version: int, options: Dictionary = {} ) -> GFPeriodSchedule:
```

创建有版本的周期计划。

参数：

| 名称 | 说明 |
|---|---|
| `schedule_id` | 非空计划身份，最多256字符，无首尾空白和控制字符。 |
| `version` | 正整数政策版本，应随项目结算政策变更递增。 |
| `options` | 显式周期政策。 |

返回：冻结计划；非法或不适用字段返回 null。

结构：

- `options`: 封闭 Dictionary。period:String=daily|weekly|fixed（默认daily）。daily/weekly 可含 offset_minutes:int[-840,840]（默认0）、reset_second:int[0,86399]（默认0）；weekly 可含 weekday:int[0,6]（周日0，默认周一1）。fixed 必须含 anchor_msec:int（±4×10^15）、interval_msec:int[1,4×10^15]，不接受日历字段。daily 不接受 weekday。

<a id="member-gfperiodschedule-methods-get_window"></a>

### `get_window`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_window(unix_msec: int) -> GFTimeWindow:
```

求包含给定时间戳的唯一左闭右开窗口。

参数：

| 名称 | 说明 |
|---|---|
| `unix_msec` | Unix 毫秒时间戳，范围 ±4×10^15；负值和锚点前时间同样支持。 |

返回：有明确周期身份的窗口；越界或未经工厂创建时为 null。

<a id="member-gfperiodschedule-methods-to_record"></a>

### `to_record`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func to_record() -> Dictionary:
```

获取实际生效的冻结政策。

返回：政策副本；未经工厂创建时为空。

结构：

- `return`: 封闭 Dictionary，schedule_id:String、version:int、period:String、anchor_msec:int、interval_msec:int、offset_minutes:int、reset_second:int、weekday:int；fixed 的日历字段为0，daily的weekday为0。
