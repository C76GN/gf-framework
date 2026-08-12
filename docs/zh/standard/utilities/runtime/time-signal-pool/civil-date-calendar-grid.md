# 民用日期与月历网格

`GFCivilDate` 表达不含时刻的民用日期，`GFCalendarGridTools` 把一个月展开为稳定的 7 列日期网格。两者的输入范围和计算结果都确定，不读取系统时钟，也不依赖 `Time` 单例、操作系统区域设置或外部服务，因此适合存档字段、规则日期、编辑器工具和确定性测试。

## 日期模型

日期采用 proleptic Gregorian calendar：即把现代 Gregorian 闰年规则一致地向前推算到公元 1 年。支持范围是 `0001-01-01` 到 `9999-12-31`，没有 year zero 或 BCE。星期采用 ISO 编号（Monday 为 1，Sunday 为 7），ISO week-year 与 week number 也按 ISO 的周四归属规则计算。

所有构造和解析都返回 `GFCivilDateResult`，调用方先检查 `is_successful()`，再读取 `get_date()`。输入不会被静默修正：越界、无效日期和格式错误使用稳定的不同状态。

```gdscript
var parsed := GFCivilDate.parse_iso8601("2028-02-29")
if not parsed.is_successful():
	push_error(parsed.get_error())
	return

var date := parsed.get_date()
print(date.to_iso8601())
print(date.get_iso_week_year(), "-W", date.get_iso_week_number())
```

`parse_iso8601()` 只接受固定宽度 `YYYY-MM-DD`。`from_dict()` 使用 closed schema：字典必须恰好包含整数 `year`、`month`、`day` 三个键；缺失、额外键或错误类型都返回 `STATUS_INVALID_FORMAT`。这样配置拼写错误不会被悄悄忽略。

## 增减与比较

- `add_days()` 使用连续日序号运算；结果超出 1..9999 年时返回 `STATUS_OUT_OF_RANGE`。
- `add_months(months, clamp_day)` 与 `add_years(years, clamp_day)` 把月末策略交给调用方。`clamp_day = true` 时钳制到目标月最后一天；为 `false` 时，不存在的目标日期显式返回 `STATUS_INVALID_DATE`。
- `compare_to(other)` / `days_until(other)` 返回 `GFCivilDateDifferenceResult`。成功结果同时含比较值（较早 `-1`、相等 `0`、较晚 `1`）和 `other - self` 的有符号日差；任一输入无效时返回类型化失败。

```gdscript
var leap_day := GFCivilDate.create(2024, 2, 29).get_date()
var clamped := leap_day.add_years(1, true)
assert(clamped.is_successful())
assert(clamped.get_date().to_iso8601() == "2025-02-28")

var strict := leap_day.add_years(1, false)
assert(not strict.is_successful())
```

## 月历网格

`GFCalendarGridTools.build_month_grid(month, week_start, fixed_rows)` 接受目标月内任意有效 `GFCivilDate` 并返回 `GFCalendarGrid`。成功网格始终是 7 列、4 到 6 行的行主序日期；`week_start` 可配置，`fixed_rows = 0` 自动选择最少完整行，4..6 则请求固定行数。固定行不足、请求非法或前后补位越过支持范围时返回稳定失败状态。`get_cells()` 返回新数组，修改数组不会改变网格本身。

该 API 只提供日期数据，不包含本地化月份/星期名称、时区、夏令时、节假日、工作日规则、系统“今天”或任何日历 UI。项目应在展示和业务层显式组合 locale、time zone、holiday provider 与控件。
