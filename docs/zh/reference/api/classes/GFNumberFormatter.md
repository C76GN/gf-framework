# GFNumberFormatter

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/formatting/gf_number_formatter.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

统一的数字显示格式化工具。 负责普通数字、定点小数与大数值对象在 UI 中的显示转换， 提供完整显示、紧凑缩写、科学计数法、工程计数法与自动模式。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`Notation`](#member-gfnumberformatter-enums-notation) | `enum Notation` |
| 枚举 | [`ScientificStyle`](#member-gfnumberformatter-enums-scientificstyle) | `enum ScientificStyle` |
| 方法 | [`format_number`](#member-gfnumberformatter-methods-format_number) | `static func format_number( value: Variant, notation: Notation = Notation.AUTO, decimal_places: int = 2, trim_zeroes: bool = true, use_truncation: bool = false, scientific_style: ScientificStyle = ScientificStyle.E_LOWER ) -> String:` |
| 方法 | [`format_full`](#member-gfnumberformatter-methods-format_full) | `static func format_full( value: Variant, decimal_places: int = 2, trim_zeroes: bool = true, use_grouping: bool = false, use_truncation: bool = false ) -> String:` |
| 方法 | [`format_compact`](#member-gfnumberformatter-methods-format_compact) | `static func format_compact( value: Variant, decimal_places: int = 2, trim_zeroes: bool = true, use_truncation: bool = false, suffixes: PackedStringArray = PackedStringArray() ) -> String:` |
| 方法 | [`format_scientific`](#member-gfnumberformatter-methods-format_scientific) | `static func format_scientific( value: Variant, decimal_places: int = 2, trim_zeroes: bool = true, use_truncation: bool = false, style: ScientificStyle = ScientificStyle.E_LOWER, engineering: bool = false ) -> String:` |
| 方法 | [`format_auto`](#member-gfnumberformatter-methods-format_auto) | `static func format_auto( value: Variant, decimal_places: int = 2, trim_zeroes: bool = true, use_truncation: bool = false, scientific_style: ScientificStyle = ScientificStyle.E_LOWER ) -> String:` |

## 枚举

<a id="member-gfnumberformatter-enums-notation"></a>

### `Notation`

- API：`public`

```gdscript
enum Notation { ## 尽量输出普通十进制表示。 FULL, ## 输出紧凑缩写表示，如 12.3k。 COMPACT_SHORT, ## 输出科学计数法，如 1.23e8。 SCIENTIFIC, ## 输出工程计数法，如 123.4e6。 ENGINEERING, ## 自动选择更适合当前量级的表示方式。 AUTO, }
```

格式化记法。

<a id="member-gfnumberformatter-enums-scientificstyle"></a>

### `ScientificStyle`

- API：`public`

```gdscript
enum ScientificStyle { ## 使用小写 e。 E_LOWER, ## 使用大写 E。 E_UPPER, ## 使用 x 10^n 形式。 POWER_OF_TEN, }
```

科学计数法输出风格。

## 方法

<a id="member-gfnumberformatter-methods-format_number"></a>

### `format_number`

- API：`public`

```gdscript
static func format_number( value: Variant, notation: Notation = Notation.AUTO, decimal_places: int = 2, trim_zeroes: bool = true, use_truncation: bool = false, scientific_style: ScientificStyle = ScientificStyle.E_LOWER ) -> String:
```

统一入口：按指定记法格式化一个数字值。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 支持 int/float/String/GFBigNumber/GFFixedDecimal。 |
| `notation` | 目标记法。 |
| `decimal_places` | 小数位数。 |
| `trim_zeroes` | 是否裁掉尾部 0。 |
| `use_truncation` | 是否使用截断而不是四舍五入。 |
| `scientific_style` | 科学计数法的输出风格。 |

返回：格式化后的字符串。

结构：

- `value`: Variant numeric value accepted by the formatter.

<a id="member-gfnumberformatter-methods-format_full"></a>

### `format_full`

- API：`public`

```gdscript
static func format_full( value: Variant, decimal_places: int = 2, trim_zeroes: bool = true, use_grouping: bool = false, use_truncation: bool = false ) -> String:
```

输出普通十进制字符串。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 支持 int/float/String/GFBigNumber/GFFixedDecimal。 |
| `decimal_places` | 小数位数。 |
| `trim_zeroes` | 是否裁掉尾部 0。 |
| `use_grouping` | 是否为整数部分添加千分位分隔。 |
| `use_truncation` | 是否使用截断而不是四舍五入。 |

返回：普通十进制字符串。

结构：

- `value`: Variant numeric value accepted by the formatter.

<a id="member-gfnumberformatter-methods-format_compact"></a>

### `format_compact`

- API：`public`

```gdscript
static func format_compact( value: Variant, decimal_places: int = 2, trim_zeroes: bool = true, use_truncation: bool = false, suffixes: PackedStringArray = PackedStringArray() ) -> String:
```

输出紧凑缩写字符串，如 1.2k / 3.4M。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 支持 int/float/String/GFBigNumber/GFFixedDecimal。 |
| `decimal_places` | 小数位数。 |
| `trim_zeroes` | 是否裁掉尾部 0。 |
| `use_truncation` | 是否使用截断而不是四舍五入。 |
| `suffixes` | 自定义后缀表；为空时使用默认值。 |

返回：紧凑缩写字符串。

结构：

- `value`: Variant numeric value accepted by the formatter.

<a id="member-gfnumberformatter-methods-format_scientific"></a>

### `format_scientific`

- API：`public`

```gdscript
static func format_scientific( value: Variant, decimal_places: int = 2, trim_zeroes: bool = true, use_truncation: bool = false, style: ScientificStyle = ScientificStyle.E_LOWER, engineering: bool = false ) -> String:
```

输出科学计数法或工程计数法字符串。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 支持 int/float/String/GFBigNumber/GFFixedDecimal。 |
| `decimal_places` | 小数位数。 |
| `trim_zeroes` | 是否裁掉尾部 0。 |
| `use_truncation` | 是否使用截断而不是四舍五入。 |
| `style` | 输出风格。 |
| `engineering` | 为 true 时输出工程计数法。 |

返回：科学计数法字符串。

结构：

- `value`: Variant numeric value accepted by the formatter.

<a id="member-gfnumberformatter-methods-format_auto"></a>

### `format_auto`

- API：`public`

```gdscript
static func format_auto( value: Variant, decimal_places: int = 2, trim_zeroes: bool = true, use_truncation: bool = false, scientific_style: ScientificStyle = ScientificStyle.E_LOWER ) -> String:
```

自动选择最合适的数字记法。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 支持 int/float/String/GFBigNumber/GFFixedDecimal。 |
| `decimal_places` | 小数位数。 |
| `trim_zeroes` | 是否裁掉尾部 0。 |
| `use_truncation` | 是否使用截断而不是四舍五入。 |
| `scientific_style` | 科学计数法输出风格。 |

返回：自动挑选后的字符串。

结构：

- `value`: Variant numeric value accepted by the formatter.
