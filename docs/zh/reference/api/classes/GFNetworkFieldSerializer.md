# GFNetworkFieldSerializer

[API Reference](../index.md) / [Network](../extensions-network.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/network/serialization/gf_network_field_serializer.gd`
- 模块：`Network`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

网络状态字段编码器。 将常见 Godot 值归一化为可序列化 Variant。它只处理字段值的形态转换， 不规定同步方向、可靠性、预测、回滚或冲突解决策略。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`ValueType`](#member-gfnetworkfieldserializer-enums-valuetype) | `enum ValueType` |
| 属性 | [`value_type`](#member-gfnetworkfieldserializer-properties-value_type) | `var value_type: ValueType = ValueType.VARIANT` |
| 属性 | [`quantize_decimals`](#member-gfnetworkfieldserializer-properties-quantize_decimals) | `var quantize_decimals: int = -1` |
| 属性 | [`clamp_enabled`](#member-gfnetworkfieldserializer-properties-clamp_enabled) | `var clamp_enabled: bool = false` |
| 属性 | [`min_value`](#member-gfnetworkfieldserializer-properties-min_value) | `var min_value: float = 0.0` |
| 属性 | [`max_value`](#member-gfnetworkfieldserializer-properties-max_value) | `var max_value: float = 1.0` |
| 方法 | [`serialize_value`](#member-gfnetworkfieldserializer-methods-serialize_value) | `func serialize_value(value: Variant) -> Variant:` |
| 方法 | [`deserialize_value`](#member-gfnetworkfieldserializer-methods-deserialize_value) | `func deserialize_value(value: Variant) -> Variant:` |
| 方法 | [`duplicate_serializer`](#member-gfnetworkfieldserializer-methods-duplicate_serializer) | `func duplicate_serializer() -> GFNetworkFieldSerializer:` |

## 枚举

<a id="member-gfnetworkfieldserializer-enums-valuetype"></a>

### `ValueType`

- API：`public`

```gdscript
enum ValueType { ## 保持原始 Variant。 VARIANT, ## 布尔值。 BOOL, ## 整数。 INT, ## 浮点数。 FLOAT, ## 字符串。 STRING, ## StringName，编码时使用 String。 STRING_NAME, ## Vector2，编码为两个数值。 VECTOR2, ## Vector3，编码为三个数值。 VECTOR3, ## Vector2i，编码为两个整数。 VECTOR2I, ## Vector3i，编码为三个整数。 VECTOR3I, ## Color，编码为四个数值。 COLOR, }
```

字段值类型。

## 属性

<a id="member-gfnetworkfieldserializer-properties-value_type"></a>

### `value_type`

- API：`public`

```gdscript
var value_type: ValueType = ValueType.VARIANT
```

字段值类型。

<a id="member-gfnetworkfieldserializer-properties-quantize_decimals"></a>

### `quantize_decimals`

- API：`public`

```gdscript
var quantize_decimals: int = -1
```

浮点量化小数位；小于 0 表示不量化。

<a id="member-gfnetworkfieldserializer-properties-clamp_enabled"></a>

### `clamp_enabled`

- API：`public`

```gdscript
var clamp_enabled: bool = false
```

是否夹取数值。

<a id="member-gfnetworkfieldserializer-properties-min_value"></a>

### `min_value`

- API：`public`

```gdscript
var min_value: float = 0.0
```

数值夹取下限。

<a id="member-gfnetworkfieldserializer-properties-max_value"></a>

### `max_value`

- API：`public`

```gdscript
var max_value: float = 1.0
```

数值夹取上限。

## 方法

<a id="member-gfnetworkfieldserializer-methods-serialize_value"></a>

### `serialize_value`

- API：`public`

```gdscript
func serialize_value(value: Variant) -> Variant:
```

编码字段值。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 原始值。 |

返回：可序列化值。

结构：

- `value`: Variant，原始字段值。
- `return`: Variant，可序列化字段值；向量和颜色会编码为 Array。

<a id="member-gfnetworkfieldserializer-methods-deserialize_value"></a>

### `deserialize_value`

- API：`public`

```gdscript
func deserialize_value(value: Variant) -> Variant:
```

解码字段值。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 编码值。 |

返回：解码后的值。

结构：

- `value`: Variant，serialize_value() 产生的编码值或兼容输入。
- `return`: Variant，按 value_type 解码后的字段值。

<a id="member-gfnetworkfieldserializer-methods-duplicate_serializer"></a>

### `duplicate_serializer`

- API：`public`

```gdscript
func duplicate_serializer() -> GFNetworkFieldSerializer:
```

复制编码器配置。

返回：新编码器。
