# 数字格式化

数字格式化工具用于把框架里的大数、定点数和普通数值输出为稳定文本。它们不负责本地化、货币符号或业务单位选择。

## `GFNumberFormatter`

`GFNumberFormatter` 是统一的数字显示格式化工具，支持：

- `FULL`：普通十进制
- `COMPACT_SHORT`：紧凑缩写，如 `12.3k`
- `SCIENTIFIC`：科学计数法，如 `1.23e8`
- `ENGINEERING`：工程计数法
- `AUTO`：自动模式

```gdscript
var coins := GFBigNumber.from_string("12345000")
print(GFNumberFormatter.format_compact(coins, 2)) # 12.35M
print(GFNumberFormatter.format_scientific(coins, 2)) # 1.23e7
```

默认紧凑后缀可通过 `get_default_compact_suffixes()` 读取；返回值是副本，修改它不会改变框架默认格式化行为。项目需要短单位、本地化单位或更长后缀表时，把自定义 `PackedStringArray` 传给 `format_compact()` 的 `suffixes` 参数，不要依赖全局可变状态。

## `GFDecimalStringFormatter`

`GFDecimalStringFormatter` 是小数字符串格式化与校验辅助，主要用于框架内部的 `GFNumberFormatter`、`GFBigNumber` 和 `GFFixedDecimal` 共享同一套舍入、截断、尾零裁剪和纯数字校验规则。

项目层如果也需要这些纯文本规则，可以直接静态调用；纯数字校验要求至少包含一个数字字符。

```gdscript
var rounded := GFDecimalStringFormatter.format_decimal_value(12.345, 2, false, false)
var truncated := GFDecimalStringFormatter.format_decimal_value(12.345, 2, false, true)
var valid := GFDecimalStringFormatter.is_valid_decimal_parts("12", "34", true)
```
