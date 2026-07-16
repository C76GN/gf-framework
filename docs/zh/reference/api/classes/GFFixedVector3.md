# GFFixedVector3

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/numeric/gf_fixed_vector3.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`5.0.0`

基于统一整数缩放的三维定点向量值对象。 它适合锁步、回放、黄金测试和需要稳定序列化的三维坐标或方向值。 该类型不替代 Vector3i 格子坐标，也不替代 Godot Vector3 在渲染和物理中的浮点表达。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`raw_x`](#member-gffixedvector3-properties-raw_x) | `var raw_x: int = 0:` |
| 属性 | [`raw_y`](#member-gffixedvector3-properties-raw_y) | `var raw_y: int = 0:` |
| 属性 | [`raw_z`](#member-gffixedvector3-properties-raw_z) | `var raw_z: int = 0:` |
| 属性 | [`decimal_places`](#member-gffixedvector3-properties-decimal_places) | `var decimal_places: int = 2:` |
| 方法 | [`from_raw`](#member-gffixedvector3-methods-from_raw) | `static func from_raw( p_raw_x: int, p_raw_y: int, p_raw_z: int, p_decimal_places: int = 2 ) -> GFFixedVector3:` |
| 方法 | [`from_decimal_strings`](#member-gffixedvector3-methods-from_decimal_strings) | `static func from_decimal_strings( x_text: String, y_text: String, z_text: String, p_decimal_places: int = 2, rounding_mode: int = GFFixedDecimal.RoundingMode.HALF_UP ) -> GFFixedVector3:` |
| 方法 | [`from_vector3`](#member-gffixedvector3-methods-from_vector3) | `static func from_vector3( value: Vector3, p_decimal_places: int = 2, rounding_mode: int = GFFixedDecimal.RoundingMode.HALF_UP ) -> GFFixedVector3:` |
| 方法 | [`from_dict`](#member-gffixedvector3-methods-from_dict) | `static func from_dict(data: Dictionary) -> GFFixedVector3:` |
| 方法 | [`from_bytes`](#member-gffixedvector3-methods-from_bytes) | `static func from_bytes(data: PackedByteArray) -> GFFixedVector3:` |
| 方法 | [`clone`](#member-gffixedvector3-methods-clone) | `func clone() -> GFFixedVector3:` |
| 方法 | [`is_zero`](#member-gffixedvector3-methods-is_zero) | `func is_zero() -> bool:` |
| 方法 | [`get_x_decimal`](#member-gffixedvector3-methods-get_x_decimal) | `func get_x_decimal() -> GFFixedDecimal:` |
| 方法 | [`get_y_decimal`](#member-gffixedvector3-methods-get_y_decimal) | `func get_y_decimal() -> GFFixedDecimal:` |
| 方法 | [`get_z_decimal`](#member-gffixedvector3-methods-get_z_decimal) | `func get_z_decimal() -> GFFixedDecimal:` |
| 方法 | [`to_vector3`](#member-gffixedvector3-methods-to_vector3) | `func to_vector3() -> Vector3:` |
| 方法 | [`rescaled`](#member-gffixedvector3-methods-rescaled) | `func rescaled( target_decimal_places: int, rounding_mode: int = GFFixedDecimal.RoundingMode.HALF_UP ) -> GFFixedVector3:` |
| 方法 | [`negated`](#member-gffixedvector3-methods-negated) | `func negated() -> GFFixedVector3:` |
| 方法 | [`add`](#member-gffixedvector3-methods-add) | `func add(other: GFFixedVector3) -> GFFixedVector3:` |
| 方法 | [`subtract`](#member-gffixedvector3-methods-subtract) | `func subtract(other: GFFixedVector3) -> GFFixedVector3:` |
| 方法 | [`multiply_scalar`](#member-gffixedvector3-methods-multiply_scalar) | `func multiply_scalar( scalar: GFFixedDecimal, target_decimal_places: int = -1, rounding_mode: int = GFFixedDecimal.RoundingMode.HALF_UP ) -> GFFixedVector3:` |
| 方法 | [`dot`](#member-gffixedvector3-methods-dot) | `func dot( other: GFFixedVector3, target_decimal_places: int = -1, rounding_mode: int = GFFixedDecimal.RoundingMode.HALF_UP ) -> GFFixedDecimal:` |
| 方法 | [`length_squared`](#member-gffixedvector3-methods-length_squared) | `func length_squared( target_decimal_places: int = -1, rounding_mode: int = GFFixedDecimal.RoundingMode.HALF_UP ) -> GFFixedDecimal:` |
| 方法 | [`equals_exact`](#member-gffixedvector3-methods-equals_exact) | `func equals_exact(other: GFFixedVector3) -> bool:` |
| 方法 | [`to_dict`](#member-gffixedvector3-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`apply_dict`](#member-gffixedvector3-methods-apply_dict) | `func apply_dict(data: Dictionary) -> bool:` |
| 方法 | [`to_bytes`](#member-gffixedvector3-methods-to_bytes) | `func to_bytes() -> PackedByteArray:` |
| 方法 | [`apply_bytes`](#member-gffixedvector3-methods-apply_bytes) | `func apply_bytes(data: PackedByteArray) -> bool:` |

## 属性

<a id="member-gffixedvector3-properties-raw_x"></a>

### `raw_x`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
var raw_x: int = 0:
```

X 分量的整数缩放值。

<a id="member-gffixedvector3-properties-raw_y"></a>

### `raw_y`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
var raw_y: int = 0:
```

Y 分量的整数缩放值。

<a id="member-gffixedvector3-properties-raw_z"></a>

### `raw_z`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
var raw_z: int = 0:
```

Z 分量的整数缩放值。

<a id="member-gffixedvector3-properties-decimal_places"></a>

### `decimal_places`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
var decimal_places: int = 2:
```

三个分量共享的小数位数。

## 方法

<a id="member-gffixedvector3-methods-from_raw"></a>

### `from_raw`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func from_raw( p_raw_x: int, p_raw_y: int, p_raw_z: int, p_decimal_places: int = 2 ) -> GFFixedVector3:
```

从 raw 分量创建定点三维向量。

参数：

| 名称 | 说明 |
|---|---|
| `p_raw_x` | X 分量整数缩放值。 |
| `p_raw_y` | Y 分量整数缩放值。 |
| `p_raw_z` | Z 分量整数缩放值。 |
| `p_decimal_places` | 三个分量共享的小数位。 |

返回：定点三维向量实例。

<a id="member-gffixedvector3-methods-from_decimal_strings"></a>

### `from_decimal_strings`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func from_decimal_strings( x_text: String, y_text: String, z_text: String, p_decimal_places: int = 2, rounding_mode: int = GFFixedDecimal.RoundingMode.HALF_UP ) -> GFFixedVector3:
```

从普通十进制字符串创建定点三维向量。

参数：

| 名称 | 说明 |
|---|---|
| `x_text` | X 分量十进制字符串。 |
| `y_text` | Y 分量十进制字符串。 |
| `z_text` | Z 分量十进制字符串。 |
| `p_decimal_places` | 目标小数位。 |
| `rounding_mode` | 舍入策略。 |

返回：定点三维向量实例。

<a id="member-gffixedvector3-methods-from_vector3"></a>

### `from_vector3`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func from_vector3( value: Vector3, p_decimal_places: int = 2, rounding_mode: int = GFFixedDecimal.RoundingMode.HALF_UP ) -> GFFixedVector3:
```

从 Godot Vector3 创建定点三维向量。 这是显式浮点适配入口，不应用作 deterministic 真值来源。

参数：

| 名称 | 说明 |
|---|---|
| `value` | Godot 浮点三维向量。 |
| `p_decimal_places` | 目标小数位。 |
| `rounding_mode` | 舍入策略。 |

返回：定点三维向量实例。

<a id="member-gffixedvector3-methods-from_dict"></a>

### `from_dict`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func from_dict(data: Dictionary) -> GFFixedVector3:
```

从状态字典恢复定点三维向量。

参数：

| 名称 | 说明 |
|---|---|
| `data` | `to_dict()` 输出的状态字典。 |

返回：定点三维向量实例。

结构：

- `data`: Dictionary with `type`, `version`, `raw_x`, `raw_y`, `raw_z`, and `decimal_places` fields.

<a id="member-gffixedvector3-methods-from_bytes"></a>

### `from_bytes`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func from_bytes(data: PackedByteArray) -> GFFixedVector3:
```

从固定字节序列恢复定点三维向量。

参数：

| 名称 | 说明 |
|---|---|
| `data` | `to_bytes()` 输出的字节序列。 |

返回：定点三维向量实例。

<a id="member-gffixedvector3-methods-clone"></a>

### `clone`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func clone() -> GFFixedVector3:
```

克隆当前向量。

返回：内容相同的新实例。

<a id="member-gffixedvector3-methods-is_zero"></a>

### `is_zero`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func is_zero() -> bool:
```

当前向量是否为零向量。

返回：三个 raw 分量都为 0 时返回 true。

<a id="member-gffixedvector3-methods-get_x_decimal"></a>

### `get_x_decimal`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func get_x_decimal() -> GFFixedDecimal:
```

X 分量转为 GFFixedDecimal。

返回：X 分量定点数。

<a id="member-gffixedvector3-methods-get_y_decimal"></a>

### `get_y_decimal`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func get_y_decimal() -> GFFixedDecimal:
```

Y 分量转为 GFFixedDecimal。

返回：Y 分量定点数。

<a id="member-gffixedvector3-methods-get_z_decimal"></a>

### `get_z_decimal`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func get_z_decimal() -> GFFixedDecimal:
```

Z 分量转为 GFFixedDecimal。

返回：Z 分量定点数。

<a id="member-gffixedvector3-methods-to_vector3"></a>

### `to_vector3`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func to_vector3() -> Vector3:
```

转为 Godot Vector3。 该转换会回到 float，仅用于渲染、调试或 Godot API 适配。

返回：Godot 浮点三维向量。

<a id="member-gffixedvector3-methods-rescaled"></a>

### `rescaled`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func rescaled( target_decimal_places: int, rounding_mode: int = GFFixedDecimal.RoundingMode.HALF_UP ) -> GFFixedVector3:
```

重设小数位数。

参数：

| 名称 | 说明 |
|---|---|
| `target_decimal_places` | 目标小数位。 |
| `rounding_mode` | 降位时的舍入策略。 |

返回：重设后的定点三维向量。

<a id="member-gffixedvector3-methods-negated"></a>

### `negated`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func negated() -> GFFixedVector3:
```

获取相反向量。

返回：新的定点三维向量。

<a id="member-gffixedvector3-methods-add"></a>

### `add`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func add(other: GFFixedVector3) -> GFFixedVector3:
```

与另一个定点三维向量相加。

参数：

| 名称 | 说明 |
|---|---|
| `other` | 另一个定点三维向量。 |

返回：相加结果。

<a id="member-gffixedvector3-methods-subtract"></a>

### `subtract`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func subtract(other: GFFixedVector3) -> GFFixedVector3:
```

与另一个定点三维向量相减。

参数：

| 名称 | 说明 |
|---|---|
| `other` | 另一个定点三维向量。 |

返回：相减结果。

<a id="member-gffixedvector3-methods-multiply_scalar"></a>

### `multiply_scalar`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func multiply_scalar( scalar: GFFixedDecimal, target_decimal_places: int = -1, rounding_mode: int = GFFixedDecimal.RoundingMode.HALF_UP ) -> GFFixedVector3:
```

乘以定点标量。

参数：

| 名称 | 说明 |
|---|---|
| `scalar` | 定点标量。 |
| `target_decimal_places` | 结果小数位；传 -1 时沿用较高小数位。 |
| `rounding_mode` | 结果降位时的舍入策略。 |

返回：乘法结果。

<a id="member-gffixedvector3-methods-dot"></a>

### `dot`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func dot( other: GFFixedVector3, target_decimal_places: int = -1, rounding_mode: int = GFFixedDecimal.RoundingMode.HALF_UP ) -> GFFixedDecimal:
```

计算点积。

参数：

| 名称 | 说明 |
|---|---|
| `other` | 另一个定点三维向量。 |
| `target_decimal_places` | 结果小数位；传 -1 时沿用较高小数位。 |
| `rounding_mode` | 结果降位时的舍入策略。 |

返回：点积定点数。

<a id="member-gffixedvector3-methods-length_squared"></a>

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

<a id="member-gffixedvector3-methods-equals_exact"></a>

### `equals_exact`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func equals_exact(other: GFFixedVector3) -> bool:
```

判断 raw 分量和小数位是否完全一致。

参数：

| 名称 | 说明 |
|---|---|
| `other` | 另一个定点三维向量。 |

返回：raw 分量和小数位完全一致时返回 true。

<a id="member-gffixedvector3-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func to_dict() -> Dictionary:
```

导出 JSON 安全状态字典。 raw 分量固定写为十进制字符串，避免 JSON 64 位整数精度丢失。

返回：可稳定恢复定点三维向量的状态字典。

结构：

- `return`: Dictionary with `type: String`, `version: int`, `raw_x: String`, `raw_y: String`, `raw_z: String`, and `decimal_places: int`.

<a id="member-gffixedvector3-methods-apply_dict"></a>

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

- `data`: Dictionary with `type`, `version`, `raw_x`, `raw_y`, `raw_z`, and `decimal_places` fields.

<a id="member-gffixedvector3-methods-to_bytes"></a>

### `to_bytes`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func to_bytes() -> PackedByteArray:
```

导出固定二进制序列。 格式为 `GFF3` magic、版本、小数位，以及每个分量的符号位和 8 字节大端绝对 raw 值。

返回：可稳定恢复定点三维向量的字节序列。

<a id="member-gffixedvector3-methods-apply_bytes"></a>

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
