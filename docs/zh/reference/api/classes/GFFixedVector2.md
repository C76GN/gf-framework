# GFFixedVector2

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/numeric/gf_fixed_vector2.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`5.0.0`

基于统一整数缩放的二维定点向量值对象。 它适合锁步、回放、黄金测试和需要稳定序列化的二维坐标或方向值。 该类型不替代 Vector2i 格子坐标，也不替代 Godot Vector2 在渲染和物理中的浮点表达。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`raw_x`](#member-gffixedvector2-properties-raw_x) | `var raw_x: int = 0:` |
| 属性 | [`raw_y`](#member-gffixedvector2-properties-raw_y) | `var raw_y: int = 0:` |
| 属性 | [`decimal_places`](#member-gffixedvector2-properties-decimal_places) | `var decimal_places: int = 2:` |
| 方法 | [`from_raw`](#member-gffixedvector2-methods-from_raw) | `static func from_raw(p_raw_x: int, p_raw_y: int, p_decimal_places: int = 2) -> GFFixedVector2:` |
| 方法 | [`from_decimal_strings`](#member-gffixedvector2-methods-from_decimal_strings) | `static func from_decimal_strings( x_text: String, y_text: String, p_decimal_places: int = 2, rounding_mode: int = GFFixedDecimal.RoundingMode.HALF_UP ) -> GFFixedVector2:` |
| 方法 | [`from_vector2`](#member-gffixedvector2-methods-from_vector2) | `static func from_vector2( value: Vector2, p_decimal_places: int = 2, rounding_mode: int = GFFixedDecimal.RoundingMode.HALF_UP ) -> GFFixedVector2:` |
| 方法 | [`from_dict`](#member-gffixedvector2-methods-from_dict) | `static func from_dict(data: Dictionary) -> GFFixedVector2:` |
| 方法 | [`from_bytes`](#member-gffixedvector2-methods-from_bytes) | `static func from_bytes(data: PackedByteArray) -> GFFixedVector2:` |
| 方法 | [`clone`](#member-gffixedvector2-methods-clone) | `func clone() -> GFFixedVector2:` |
| 方法 | [`is_zero`](#member-gffixedvector2-methods-is_zero) | `func is_zero() -> bool:` |
| 方法 | [`get_x_decimal`](#member-gffixedvector2-methods-get_x_decimal) | `func get_x_decimal() -> GFFixedDecimal:` |
| 方法 | [`get_y_decimal`](#member-gffixedvector2-methods-get_y_decimal) | `func get_y_decimal() -> GFFixedDecimal:` |
| 方法 | [`to_vector2`](#member-gffixedvector2-methods-to_vector2) | `func to_vector2() -> Vector2:` |
| 方法 | [`rescaled`](#member-gffixedvector2-methods-rescaled) | `func rescaled( target_decimal_places: int, rounding_mode: int = GFFixedDecimal.RoundingMode.HALF_UP ) -> GFFixedVector2:` |
| 方法 | [`negated`](#member-gffixedvector2-methods-negated) | `func negated() -> GFFixedVector2:` |
| 方法 | [`add`](#member-gffixedvector2-methods-add) | `func add(other: GFFixedVector2) -> GFFixedVector2:` |
| 方法 | [`subtract`](#member-gffixedvector2-methods-subtract) | `func subtract(other: GFFixedVector2) -> GFFixedVector2:` |
| 方法 | [`multiply_scalar`](#member-gffixedvector2-methods-multiply_scalar) | `func multiply_scalar( scalar: GFFixedDecimal, target_decimal_places: int = -1, rounding_mode: int = GFFixedDecimal.RoundingMode.HALF_UP ) -> GFFixedVector2:` |
| 方法 | [`dot`](#member-gffixedvector2-methods-dot) | `func dot( other: GFFixedVector2, target_decimal_places: int = -1, rounding_mode: int = GFFixedDecimal.RoundingMode.HALF_UP ) -> GFFixedDecimal:` |
| 方法 | [`length_squared`](#member-gffixedvector2-methods-length_squared) | `func length_squared( target_decimal_places: int = -1, rounding_mode: int = GFFixedDecimal.RoundingMode.HALF_UP ) -> GFFixedDecimal:` |
| 方法 | [`equals_exact`](#member-gffixedvector2-methods-equals_exact) | `func equals_exact(other: GFFixedVector2) -> bool:` |
| 方法 | [`to_dict`](#member-gffixedvector2-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`apply_dict`](#member-gffixedvector2-methods-apply_dict) | `func apply_dict(data: Dictionary) -> bool:` |
| 方法 | [`to_bytes`](#member-gffixedvector2-methods-to_bytes) | `func to_bytes() -> PackedByteArray:` |
| 方法 | [`apply_bytes`](#member-gffixedvector2-methods-apply_bytes) | `func apply_bytes(data: PackedByteArray) -> bool:` |

## 属性

<a id="member-gffixedvector2-properties-raw_x"></a>

### `raw_x`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
var raw_x: int = 0:
```

X 分量的整数缩放值。

<a id="member-gffixedvector2-properties-raw_y"></a>

### `raw_y`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
var raw_y: int = 0:
```

Y 分量的整数缩放值。

<a id="member-gffixedvector2-properties-decimal_places"></a>

### `decimal_places`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
var decimal_places: int = 2:
```

两个分量共享的小数位数。

## 方法

<a id="member-gffixedvector2-methods-from_raw"></a>

### `from_raw`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func from_raw(p_raw_x: int, p_raw_y: int, p_decimal_places: int = 2) -> GFFixedVector2:
```

从 raw 分量创建定点二维向量。

参数：

| 名称 | 说明 |
|---|---|
| `p_raw_x` | X 分量整数缩放值。 |
| `p_raw_y` | Y 分量整数缩放值。 |
| `p_decimal_places` | 两个分量共享的小数位。 |

返回：定点二维向量实例。

<a id="member-gffixedvector2-methods-from_decimal_strings"></a>

### `from_decimal_strings`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func from_decimal_strings( x_text: String, y_text: String, p_decimal_places: int = 2, rounding_mode: int = GFFixedDecimal.RoundingMode.HALF_UP ) -> GFFixedVector2:
```

从普通十进制字符串创建定点二维向量。

参数：

| 名称 | 说明 |
|---|---|
| `x_text` | X 分量十进制字符串。 |
| `y_text` | Y 分量十进制字符串。 |
| `p_decimal_places` | 目标小数位。 |
| `rounding_mode` | 舍入策略。 |

返回：定点二维向量实例。

<a id="member-gffixedvector2-methods-from_vector2"></a>

### `from_vector2`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func from_vector2( value: Vector2, p_decimal_places: int = 2, rounding_mode: int = GFFixedDecimal.RoundingMode.HALF_UP ) -> GFFixedVector2:
```

从 Godot Vector2 创建定点二维向量。 这是显式浮点适配入口，不应用作 deterministic 真值来源。

参数：

| 名称 | 说明 |
|---|---|
| `value` | Godot 浮点二维向量。 |
| `p_decimal_places` | 目标小数位。 |
| `rounding_mode` | 舍入策略。 |

返回：定点二维向量实例。

<a id="member-gffixedvector2-methods-from_dict"></a>

### `from_dict`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func from_dict(data: Dictionary) -> GFFixedVector2:
```

从状态字典恢复定点二维向量。

参数：

| 名称 | 说明 |
|---|---|
| `data` | `to_dict()` 输出的状态字典。 |

返回：定点二维向量实例。

结构：

- `data`: Dictionary with `type`, `version`, `raw_x`, `raw_y`, and `decimal_places` fields.

<a id="member-gffixedvector2-methods-from_bytes"></a>

### `from_bytes`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func from_bytes(data: PackedByteArray) -> GFFixedVector2:
```

从固定字节序列恢复定点二维向量。

参数：

| 名称 | 说明 |
|---|---|
| `data` | `to_bytes()` 输出的字节序列。 |

返回：定点二维向量实例。

<a id="member-gffixedvector2-methods-clone"></a>

### `clone`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func clone() -> GFFixedVector2:
```

克隆当前向量。

返回：内容相同的新实例。

<a id="member-gffixedvector2-methods-is_zero"></a>

### `is_zero`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func is_zero() -> bool:
```

当前向量是否为零向量。

返回：两个 raw 分量都为 0 时返回 true。

<a id="member-gffixedvector2-methods-get_x_decimal"></a>

### `get_x_decimal`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func get_x_decimal() -> GFFixedDecimal:
```

X 分量转为 GFFixedDecimal。

返回：X 分量定点数。

<a id="member-gffixedvector2-methods-get_y_decimal"></a>

### `get_y_decimal`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func get_y_decimal() -> GFFixedDecimal:
```

Y 分量转为 GFFixedDecimal。

返回：Y 分量定点数。

<a id="member-gffixedvector2-methods-to_vector2"></a>

### `to_vector2`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func to_vector2() -> Vector2:
```

转为 Godot Vector2。 该转换会回到 float，仅用于渲染、调试或 Godot API 适配。

返回：Godot 浮点二维向量。

<a id="member-gffixedvector2-methods-rescaled"></a>

### `rescaled`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func rescaled( target_decimal_places: int, rounding_mode: int = GFFixedDecimal.RoundingMode.HALF_UP ) -> GFFixedVector2:
```

重设小数位数。

参数：

| 名称 | 说明 |
|---|---|
| `target_decimal_places` | 目标小数位。 |
| `rounding_mode` | 降位时的舍入策略。 |

返回：重设后的定点二维向量。

<a id="member-gffixedvector2-methods-negated"></a>

### `negated`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func negated() -> GFFixedVector2:
```

获取相反向量。

返回：新的定点二维向量。

<a id="member-gffixedvector2-methods-add"></a>

### `add`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func add(other: GFFixedVector2) -> GFFixedVector2:
```

与另一个定点二维向量相加。

参数：

| 名称 | 说明 |
|---|---|
| `other` | 另一个定点二维向量。 |

返回：相加结果。

<a id="member-gffixedvector2-methods-subtract"></a>

### `subtract`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func subtract(other: GFFixedVector2) -> GFFixedVector2:
```

与另一个定点二维向量相减。

参数：

| 名称 | 说明 |
|---|---|
| `other` | 另一个定点二维向量。 |

返回：相减结果。

<a id="member-gffixedvector2-methods-multiply_scalar"></a>

### `multiply_scalar`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func multiply_scalar( scalar: GFFixedDecimal, target_decimal_places: int = -1, rounding_mode: int = GFFixedDecimal.RoundingMode.HALF_UP ) -> GFFixedVector2:
```

乘以定点标量。

参数：

| 名称 | 说明 |
|---|---|
| `scalar` | 定点标量。 |
| `target_decimal_places` | 结果小数位；传 -1 时沿用较高小数位。 |
| `rounding_mode` | 结果降位时的舍入策略。 |

返回：乘法结果。

<a id="member-gffixedvector2-methods-dot"></a>

### `dot`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func dot( other: GFFixedVector2, target_decimal_places: int = -1, rounding_mode: int = GFFixedDecimal.RoundingMode.HALF_UP ) -> GFFixedDecimal:
```

计算点积。

参数：

| 名称 | 说明 |
|---|---|
| `other` | 另一个定点二维向量。 |
| `target_decimal_places` | 结果小数位；传 -1 时沿用较高小数位。 |
| `rounding_mode` | 结果降位时的舍入策略。 |

返回：点积定点数。

<a id="member-gffixedvector2-methods-length_squared"></a>

### `length_squared`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func length_squared( target_decimal_places: int = -1, rounding_mode: int = GFFixedDecimal.RoundingMode.HALF_UP ) -> GFFixedDecimal:
```

计算长度平方。

参数：

| 名称 | 说明 |
|---|---|
| `target_decimal_places` | 结果小数位；传 -1 时沿用当前小数位。 |
| `rounding_mode` | 结果降位时的舍入策略。 |

返回：长度平方定点数。

<a id="member-gffixedvector2-methods-equals_exact"></a>

### `equals_exact`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func equals_exact(other: GFFixedVector2) -> bool:
```

判断 raw 分量和小数位是否完全一致。

参数：

| 名称 | 说明 |
|---|---|
| `other` | 另一个定点二维向量。 |

返回：raw 分量和小数位完全一致时返回 true。

<a id="member-gffixedvector2-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func to_dict() -> Dictionary:
```

导出 JSON 安全状态字典。 raw 分量固定写为十进制字符串，避免 JSON 64 位整数精度丢失。

返回：可稳定恢复定点二维向量的状态字典。

结构：

- `return`: Dictionary with `type: String`, `version: int`, `raw_x: String`, `raw_y: String`, and `decimal_places: int`.

<a id="member-gffixedvector2-methods-apply_dict"></a>

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

- `data`: Dictionary with `type`, `version`, `raw_x`, `raw_y`, and `decimal_places` fields.

<a id="member-gffixedvector2-methods-to_bytes"></a>

### `to_bytes`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func to_bytes() -> PackedByteArray:
```

导出固定二进制序列。 格式为 `GFF2` magic、版本、小数位，以及每个分量的符号位和 8 字节大端绝对 raw 值。

返回：可稳定恢复定点二维向量的字节序列。

<a id="member-gffixedvector2-methods-apply_bytes"></a>

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
