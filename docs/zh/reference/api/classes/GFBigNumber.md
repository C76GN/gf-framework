# GFBigNumber

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/numeric/gf_big_number.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`3.17.0`

面向挂机/放置场景的近似大数值对象。 使用科学计数法的尾数 + 指数表示任意量级的数值， 适合做超出原生 int/float 直观显示范围后的比较、加减乘除与格式化输入。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`mantissa`](#member-gfbignumber-properties-mantissa) | `var mantissa: float = 0.0` |
| 属性 | [`exponent`](#member-gfbignumber-properties-exponent) | `var exponent: int = 0` |
| 方法 | [`zero`](#member-gfbignumber-methods-zero) | `static func zero() -> GFBigNumber:` |
| 方法 | [`one`](#member-gfbignumber-methods-one) | `static func one() -> GFBigNumber:` |
| 方法 | [`from_int`](#member-gfbignumber-methods-from_int) | `static func from_int(value: int) -> GFBigNumber:` |
| 方法 | [`from_float`](#member-gfbignumber-methods-from_float) | `static func from_float(value: float) -> GFBigNumber:` |
| 方法 | [`from_string`](#member-gfbignumber-methods-from_string) | `static func from_string(value: String) -> GFBigNumber:` |
| 方法 | [`from_variant`](#member-gfbignumber-methods-from_variant) | `static func from_variant(value: Variant) -> GFBigNumber:` |
| 方法 | [`clone`](#member-gfbignumber-methods-clone) | `func clone() -> GFBigNumber:` |
| 方法 | [`is_zero`](#member-gfbignumber-methods-is_zero) | `func is_zero() -> bool:` |
| 方法 | [`is_negative`](#member-gfbignumber-methods-is_negative) | `func is_negative() -> bool:` |
| 方法 | [`abs_value`](#member-gfbignumber-methods-abs_value) | `func abs_value() -> GFBigNumber:` |
| 方法 | [`negated`](#member-gfbignumber-methods-negated) | `func negated() -> GFBigNumber:` |
| 方法 | [`compare_to`](#member-gfbignumber-methods-compare_to) | `func compare_to(other: GFBigNumber) -> int:` |
| 方法 | [`add`](#member-gfbignumber-methods-add) | `func add(other: GFBigNumber) -> GFBigNumber:` |
| 方法 | [`subtract`](#member-gfbignumber-methods-subtract) | `func subtract(other: GFBigNumber) -> GFBigNumber:` |
| 方法 | [`multiply`](#member-gfbignumber-methods-multiply) | `func multiply(other: GFBigNumber) -> GFBigNumber:` |
| 方法 | [`divide`](#member-gfbignumber-methods-divide) | `func divide(other: GFBigNumber) -> GFBigNumber:` |
| 方法 | [`powi`](#member-gfbignumber-methods-powi) | `func powi(power: int) -> GFBigNumber:` |
| 方法 | [`powf`](#member-gfbignumber-methods-powf) | `func powf(power: float) -> GFBigNumber:` |
| 方法 | [`to_float`](#member-gfbignumber-methods-to_float) | `func to_float() -> float:` |
| 方法 | [`to_plain_string`](#member-gfbignumber-methods-to_plain_string) | `func to_plain_string(decimal_places: int = _DEFAULT_PLAIN_DECIMALS, trim_zeroes: bool = true) -> String:` |
| 方法 | [`to_scientific_string`](#member-gfbignumber-methods-to_scientific_string) | `func to_scientific_string( decimal_places: int = 2, trim_zeroes: bool = true, use_truncation: bool = false ) -> String:` |

## 属性

<a id="member-gfbignumber-properties-mantissa"></a>

### `mantissa`

- API：`public`

```gdscript
var mantissa: float = 0.0
```

归一化后的尾数。非零时其绝对值始终落在 [1, 10) 区间内。

<a id="member-gfbignumber-properties-exponent"></a>

### `exponent`

- API：`public`

```gdscript
var exponent: int = 0
```

以 10 为底的指数。

## 方法

<a id="member-gfbignumber-methods-zero"></a>

### `zero`

- API：`public`

```gdscript
static func zero() -> GFBigNumber:
```

创建一个值为 0 的大数。

返回：零值实例。

<a id="member-gfbignumber-methods-one"></a>

### `one`

- API：`public`

```gdscript
static func one() -> GFBigNumber:
```

创建一个值为 1 的大数。

返回：一值实例。

<a id="member-gfbignumber-methods-from_int"></a>

### `from_int`

- API：`public`

```gdscript
static func from_int(value: int) -> GFBigNumber:
```

从 int 构建大数。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 原始整数。 |

返回：归一化后的大数实例。

<a id="member-gfbignumber-methods-from_float"></a>

### `from_float`

- API：`public`

```gdscript
static func from_float(value: float) -> GFBigNumber:
```

从 float 构建大数。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 原始浮点数。 |

返回：归一化后的大数实例。

<a id="member-gfbignumber-methods-from_string"></a>

### `from_string`

- API：`public`

```gdscript
static func from_string(value: String) -> GFBigNumber:
```

从字符串构建大数，支持普通写法与科学计数法。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 原始字符串，如 "12345"、"1.23e8"。 |

返回：解析后的大数实例。

<a id="member-gfbignumber-methods-from_variant"></a>

### `from_variant`

- API：`public`

```gdscript
static func from_variant(value: Variant) -> GFBigNumber:
```

从任意支持的 Variant 构建大数。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 支持 int/float/String/GFBigNumber/GFFixedDecimal。 |

返回：对应的大数实例。

结构：

- `value`: Variant numeric value accepted by GFBigNumber.

<a id="member-gfbignumber-methods-clone"></a>

### `clone`

- API：`public`

```gdscript
func clone() -> GFBigNumber:
```

克隆当前大数。

返回：内容相同的新实例。

<a id="member-gfbignumber-methods-is_zero"></a>

### `is_zero`

- API：`public`

```gdscript
func is_zero() -> bool:
```

当前值是否为零。

返回：为零时返回 true。

<a id="member-gfbignumber-methods-is_negative"></a>

### `is_negative`

- API：`public`

```gdscript
func is_negative() -> bool:
```

当前值是否为负数。

返回：为负时返回 true。

<a id="member-gfbignumber-methods-abs_value"></a>

### `abs_value`

- API：`public`

```gdscript
func abs_value() -> GFBigNumber:
```

获取绝对值。

返回：新的大数实例。

<a id="member-gfbignumber-methods-negated"></a>

### `negated`

- API：`public`

```gdscript
func negated() -> GFBigNumber:
```

获取相反数。

返回：新的大数实例。

<a id="member-gfbignumber-methods-compare_to"></a>

### `compare_to`

- API：`public`

```gdscript
func compare_to(other: GFBigNumber) -> int:
```

比较当前值与另一个大数。

参数：

| 名称 | 说明 |
|---|---|
| `other` | 另一个大数实例。 |

返回：当前值大于 other 返回 1，小于返回 -1，相等返回 0。

<a id="member-gfbignumber-methods-add"></a>

### `add`

- API：`public`

```gdscript
func add(other: GFBigNumber) -> GFBigNumber:
```

与另一个大数相加。

参数：

| 名称 | 说明 |
|---|---|
| `other` | 另一个大数实例。 |

返回：相加结果。

<a id="member-gfbignumber-methods-subtract"></a>

### `subtract`

- API：`public`

```gdscript
func subtract(other: GFBigNumber) -> GFBigNumber:
```

与另一个大数相减。

参数：

| 名称 | 说明 |
|---|---|
| `other` | 另一个大数实例。 |

返回：相减结果。

<a id="member-gfbignumber-methods-multiply"></a>

### `multiply`

- API：`public`

```gdscript
func multiply(other: GFBigNumber) -> GFBigNumber:
```

与另一个大数相乘。

参数：

| 名称 | 说明 |
|---|---|
| `other` | 另一个大数实例。 |

返回：相乘结果。

<a id="member-gfbignumber-methods-divide"></a>

### `divide`

- API：`public`

```gdscript
func divide(other: GFBigNumber) -> GFBigNumber:
```

与另一个大数相除。

参数：

| 名称 | 说明 |
|---|---|
| `other` | 另一个大数实例。 |

返回：相除结果。

<a id="member-gfbignumber-methods-powi"></a>

### `powi`

- API：`public`

```gdscript
func powi(power: int) -> GFBigNumber:
```

将当前大数提升到整数次幂。

参数：

| 名称 | 说明 |
|---|---|
| `power` | 幂指数。 |

返回：幂运算结果。

<a id="member-gfbignumber-methods-powf"></a>

### `powf`

- API：`public`

```gdscript
func powf(power: float) -> GFBigNumber:
```

将当前大数提升到浮点次幂。

参数：

| 名称 | 说明 |
|---|---|
| `power` | 幂指数。 |

返回：幂运算结果。

<a id="member-gfbignumber-methods-to_float"></a>

### `to_float`

- API：`public`

```gdscript
func to_float() -> float:
```

将当前值转换为 float。

返回：可表达时返回浮点值，超出范围时返回 +/-INF。

<a id="member-gfbignumber-methods-to_plain_string"></a>

### `to_plain_string`

- API：`public`

```gdscript
func to_plain_string(decimal_places: int = _DEFAULT_PLAIN_DECIMALS, trim_zeroes: bool = true) -> String:
```

在量级适中时输出普通十进制字符串，过大时会回退到科学计数法。

参数：

| 名称 | 说明 |
|---|---|
| `decimal_places` | 小数位数。 |
| `trim_zeroes` | 是否裁掉尾部 0。 |

返回：普通字符串表示。

<a id="member-gfbignumber-methods-to_scientific_string"></a>

### `to_scientific_string`

- API：`public`

```gdscript
func to_scientific_string( decimal_places: int = 2, trim_zeroes: bool = true, use_truncation: bool = false ) -> String:
```

输出科学计数法字符串。

参数：

| 名称 | 说明 |
|---|---|
| `decimal_places` | 小数位数。 |
| `trim_zeroes` | 是否裁掉尾部 0。 |
| `use_truncation` | 是否使用截断而不是四舍五入。 |

返回：科学计数法字符串。
