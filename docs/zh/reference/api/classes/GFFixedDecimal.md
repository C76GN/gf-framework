# GFFixedDecimal

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/numeric/gf_fixed_decimal.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`3.17.0`

基于整数缩放的定点小数值对象。 适合处理货币、税率、经营数值等对“累计误差”敏感、 但又不需要无限精度十进制库的场景。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`RoundingMode`](#member-gffixeddecimal-enums-roundingmode) | `enum RoundingMode` |
| 常量 | [`MAX_DECIMAL_PLACES`](#member-gffixeddecimal-constants-max_decimal_places) | `const MAX_DECIMAL_PLACES: int = 18` |
| 属性 | [`raw_value`](#member-gffixeddecimal-properties-raw_value) | `var raw_value: int = 0` |
| 属性 | [`decimal_places`](#member-gffixeddecimal-properties-decimal_places) | `var decimal_places: int = 2` |
| 方法 | [`from_int`](#member-gffixeddecimal-methods-from_int) | `static func from_int(value: int, p_decimal_places: int = 2) -> GFFixedDecimal:` |
| 方法 | [`from_float`](#member-gffixeddecimal-methods-from_float) | `static func from_float( value: float, p_decimal_places: int = 2, rounding_mode: RoundingMode = RoundingMode.HALF_UP ) -> GFFixedDecimal:` |
| 方法 | [`from_string`](#member-gffixeddecimal-methods-from_string) | `static func from_string( value: String, p_decimal_places: int = 2, rounding_mode: RoundingMode = RoundingMode.HALF_UP ) -> GFFixedDecimal:` |
| 方法 | [`from_dict`](#member-gffixeddecimal-methods-from_dict) | `static func from_dict(data: Dictionary) -> GFFixedDecimal:` |
| 方法 | [`from_bytes`](#member-gffixeddecimal-methods-from_bytes) | `static func from_bytes(data: PackedByteArray) -> GFFixedDecimal:` |
| 方法 | [`clone`](#member-gffixeddecimal-methods-clone) | `func clone() -> GFFixedDecimal:` |
| 方法 | [`is_zero`](#member-gffixeddecimal-methods-is_zero) | `func is_zero() -> bool:` |
| 方法 | [`abs_value`](#member-gffixeddecimal-methods-abs_value) | `func abs_value() -> GFFixedDecimal:` |
| 方法 | [`negated`](#member-gffixeddecimal-methods-negated) | `func negated() -> GFFixedDecimal:` |
| 方法 | [`rescaled`](#member-gffixeddecimal-methods-rescaled) | `func rescaled( target_decimal_places: int, rounding_mode: RoundingMode = RoundingMode.HALF_UP ) -> GFFixedDecimal:` |
| 方法 | [`compare_to`](#member-gffixeddecimal-methods-compare_to) | `func compare_to(other: GFFixedDecimal) -> int:` |
| 方法 | [`add`](#member-gffixeddecimal-methods-add) | `func add(other: GFFixedDecimal) -> GFFixedDecimal:` |
| 方法 | [`subtract`](#member-gffixeddecimal-methods-subtract) | `func subtract(other: GFFixedDecimal) -> GFFixedDecimal:` |
| 方法 | [`multiply`](#member-gffixeddecimal-methods-multiply) | `func multiply( other: GFFixedDecimal, target_decimal_places: int = -1, rounding_mode: RoundingMode = RoundingMode.HALF_UP ) -> GFFixedDecimal:` |
| 方法 | [`divide`](#member-gffixeddecimal-methods-divide) | `func divide( other: GFFixedDecimal, target_decimal_places: int = -1, rounding_mode: RoundingMode = RoundingMode.HALF_UP ) -> GFFixedDecimal:` |
| 方法 | [`to_float`](#member-gffixeddecimal-methods-to_float) | `func to_float() -> float:` |
| 方法 | [`to_big_number`](#member-gffixeddecimal-methods-to_big_number) | `func to_big_number() -> GFBigNumber:` |
| 方法 | [`to_decimal_string`](#member-gffixeddecimal-methods-to_decimal_string) | `func to_decimal_string(trim_zeroes: bool = false) -> String:` |
| 方法 | [`to_dict`](#member-gffixeddecimal-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`apply_dict`](#member-gffixeddecimal-methods-apply_dict) | `func apply_dict(data: Dictionary) -> bool:` |
| 方法 | [`to_bytes`](#member-gffixeddecimal-methods-to_bytes) | `func to_bytes() -> PackedByteArray:` |
| 方法 | [`apply_bytes`](#member-gffixeddecimal-methods-apply_bytes) | `func apply_bytes(data: PackedByteArray) -> bool:` |

## 枚举

<a id="member-gffixeddecimal-enums-roundingmode"></a>

### `RoundingMode`

- API：`public`

```gdscript
enum RoundingMode {
	## 四舍五入，0.5 始终朝绝对值更大的方向进位。
	HALF_UP,
	## 银行家舍入，0.5 时向最近的偶数靠拢。
	HALF_EVEN,
	## 向负无穷方向取整。
	FLOOR,
	## 向正无穷方向取整。
	CEIL,
	## 直接截断，朝 0 逼近。
	TRUNCATE,
}
```

缩放或除法时使用的舍入策略。

## 常量

<a id="member-gffixeddecimal-constants-max_decimal_places"></a>

### `MAX_DECIMAL_PLACES`

- API：`public`

```gdscript
const MAX_DECIMAL_PLACES: int = 18
```

定点数可保留的小数位上限，避免整数缩放时溢出。

## 属性

<a id="member-gffixeddecimal-properties-raw_value"></a>

### `raw_value`

- API：`public`

```gdscript
var raw_value: int = 0
```

实际保存的整数值。

<a id="member-gffixeddecimal-properties-decimal_places"></a>

### `decimal_places`

- API：`public`

```gdscript
var decimal_places: int = 2
```

小数位数。

## 方法

<a id="member-gffixeddecimal-methods-from_int"></a>

### `from_int`

- API：`public`

```gdscript
static func from_int(value: int, p_decimal_places: int = 2) -> GFFixedDecimal:
```

从 int 构建定点数。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 原始整数。 |
| `p_decimal_places` | 目标小数位。 |

返回：定点数实例。

<a id="member-gffixeddecimal-methods-from_float"></a>

### `from_float`

- API：`public`

```gdscript
static func from_float( value: float, p_decimal_places: int = 2, rounding_mode: RoundingMode = RoundingMode.HALF_UP ) -> GFFixedDecimal:
```

从 float 构建定点数。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 原始浮点数。 |
| `p_decimal_places` | 目标小数位。 |
| `rounding_mode` | 舍入策略。 |

返回：定点数实例。

<a id="member-gffixeddecimal-methods-from_string"></a>

### `from_string`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
static func from_string( value: String, p_decimal_places: int = 2, rounding_mode: RoundingMode = RoundingMode.HALF_UP ) -> GFFixedDecimal:
```

从字符串构建定点数。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 普通十进制字符串；科学计数法会作为 float 兼容路径解析，不适合作为严格十进制导入源。 |
| `p_decimal_places` | 目标小数位。 |
| `rounding_mode` | 舍入策略。 |

返回：定点数实例。

<a id="member-gffixeddecimal-methods-from_dict"></a>

### `from_dict`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func from_dict(data: Dictionary) -> GFFixedDecimal:
```

从状态字典恢复定点数。

参数：

| 名称 | 说明 |
|---|---|
| `data` | `to_dict()` 输出的状态字典。 |

返回：定点数实例。

结构：

- `data`: Dictionary with `type`, `version`, `raw_value`, and `decimal_places` fields.

<a id="member-gffixeddecimal-methods-from_bytes"></a>

### `from_bytes`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func from_bytes(data: PackedByteArray) -> GFFixedDecimal:
```

从固定字节序列恢复定点数。

参数：

| 名称 | 说明 |
|---|---|
| `data` | `to_bytes()` 输出的字节序列。 |

返回：定点数实例。

<a id="member-gffixeddecimal-methods-clone"></a>

### `clone`

- API：`public`

```gdscript
func clone() -> GFFixedDecimal:
```

克隆当前定点数。

返回：内容相同的新实例。

<a id="member-gffixeddecimal-methods-is_zero"></a>

### `is_zero`

- API：`public`

```gdscript
func is_zero() -> bool:
```

当前值是否为零。

返回：为零时返回 true。

<a id="member-gffixeddecimal-methods-abs_value"></a>

### `abs_value`

- API：`public`

```gdscript
func abs_value() -> GFFixedDecimal:
```

获取绝对值。

返回：新的定点数实例。

<a id="member-gffixeddecimal-methods-negated"></a>

### `negated`

- API：`public`

```gdscript
func negated() -> GFFixedDecimal:
```

获取相反数。

返回：新的定点数实例。

<a id="member-gffixeddecimal-methods-rescaled"></a>

### `rescaled`

- API：`public`

```gdscript
func rescaled( target_decimal_places: int, rounding_mode: RoundingMode = RoundingMode.HALF_UP ) -> GFFixedDecimal:
```

重设小数位数。

参数：

| 名称 | 说明 |
|---|---|
| `target_decimal_places` | 目标小数位数。 |
| `rounding_mode` | 降位时的舍入策略。 |

返回：重设后的定点数实例。

<a id="member-gffixeddecimal-methods-compare_to"></a>

### `compare_to`

- API：`public`

```gdscript
func compare_to(other: GFFixedDecimal) -> int:
```

与另一个定点数比较大小。

参数：

| 名称 | 说明 |
|---|---|
| `other` | 另一个定点数。 |

返回：大于返回 1，小于返回 -1，相等返回 0。

<a id="member-gffixeddecimal-methods-add"></a>

### `add`

- API：`public`

```gdscript
func add(other: GFFixedDecimal) -> GFFixedDecimal:
```

与另一个定点数相加。

参数：

| 名称 | 说明 |
|---|---|
| `other` | 另一个定点数。 |

返回：相加结果。

<a id="member-gffixeddecimal-methods-subtract"></a>

### `subtract`

- API：`public`

```gdscript
func subtract(other: GFFixedDecimal) -> GFFixedDecimal:
```

与另一个定点数相减。

参数：

| 名称 | 说明 |
|---|---|
| `other` | 另一个定点数。 |

返回：相减结果。

<a id="member-gffixeddecimal-methods-multiply"></a>

### `multiply`

- API：`public`

```gdscript
func multiply( other: GFFixedDecimal, target_decimal_places: int = -1, rounding_mode: RoundingMode = RoundingMode.HALF_UP ) -> GFFixedDecimal:
```

与另一个定点数相乘。

参数：

| 名称 | 说明 |
|---|---|
| `other` | 另一个定点数。 |
| `target_decimal_places` | 结果小数位；传 -1 时取两者较大值。 |
| `rounding_mode` | 结果降位时的舍入策略。 |

返回：相乘结果。

<a id="member-gffixeddecimal-methods-divide"></a>

### `divide`

- API：`public`

```gdscript
func divide( other: GFFixedDecimal, target_decimal_places: int = -1, rounding_mode: RoundingMode = RoundingMode.HALF_UP ) -> GFFixedDecimal:
```

与另一个定点数相除。

参数：

| 名称 | 说明 |
|---|---|
| `other` | 另一个定点数。 |
| `target_decimal_places` | 结果小数位；传 -1 时取两者较大值。 |
| `rounding_mode` | 除法舍入策略。 |

返回：相除结果。

<a id="member-gffixeddecimal-methods-to_float"></a>

### `to_float`

- API：`public`

```gdscript
func to_float() -> float:
```

转换为 float。

返回：浮点值。

<a id="member-gffixeddecimal-methods-to_big_number"></a>

### `to_big_number`

- API：`public`

```gdscript
func to_big_number() -> GFBigNumber:
```

转换为 GFBigNumber。

返回：对应的大数值对象。

<a id="member-gffixeddecimal-methods-to_decimal_string"></a>

### `to_decimal_string`

- API：`public`

```gdscript
func to_decimal_string(trim_zeroes: bool = false) -> String:
```

转换为普通字符串。

参数：

| 名称 | 说明 |
|---|---|
| `trim_zeroes` | 是否裁掉尾部 0。 |

返回：十进制字符串。

<a id="member-gffixeddecimal-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func to_dict() -> Dictionary:
```

导出 JSON 安全的状态字典。 `raw_value` 固定写为十进制字符串，避免 JSON 64 位整数精度丢失。

返回：可稳定恢复定点数的状态字典。

结构：

- `return`: Dictionary with `type: String`, `version: int`, `raw_value: String`, and `decimal_places: int`.

<a id="member-gffixeddecimal-methods-apply_dict"></a>

### `apply_dict`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func apply_dict(data: Dictionary) -> bool:
```

应用 JSON 安全状态字典。

参数：

| 名称 | 说明 |
|---|---|
| `data` | `to_dict()` 输出的状态字典。 |

返回：状态有效并已应用时返回 true。

结构：

- `data`: Dictionary with `type`, `version`, `raw_value`, and `decimal_places` fields.

<a id="member-gffixeddecimal-methods-to_bytes"></a>

### `to_bytes`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func to_bytes() -> PackedByteArray:
```

导出固定二进制序列。 格式为 `GFFD` magic、版本、小数位、符号位和 8 字节大端绝对 raw 值。

返回：可稳定恢复定点数的字节序列。

<a id="member-gffixeddecimal-methods-apply_bytes"></a>

### `apply_bytes`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func apply_bytes(data: PackedByteArray) -> bool:
```

应用固定二进制序列。

参数：

| 名称 | 说明 |
|---|---|
| `data` | `to_bytes()` 输出的字节序列。 |

返回：字节序列有效并已应用时返回 true。
