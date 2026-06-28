# GFVariantJsonCodec

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/variant/gf_variant_json_codec.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

Godot Variant 的 JSON 兼容编码器。 负责在 JSON.stringify() 可编码的数据和常见 Godot Variant 类型之间往返转换。 该类不负责集合复制或默认值合并；这类数据操作由 GFVariantData 提供。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`variant_to_json_compatible`](#member-gfvariantjsoncodec-methods-variant_to_json_compatible) | `static func variant_to_json_compatible(value: Variant, options: Dictionary = {}) -> Variant:` |
| 方法 | [`json_compatible_to_variant`](#member-gfvariantjsoncodec-methods-json_compatible_to_variant) | `static func json_compatible_to_variant(value: Variant, options: Dictionary = {}) -> Variant:` |
| 方法 | [`parse_json_text`](#member-gfvariantjsoncodec-methods-parse_json_text) | `static func parse_json_text(text: String, fallback: Variant = null) -> Variant:` |
| 方法 | [`format_json_text`](#member-gfvariantjsoncodec-methods-format_json_text) | `static func format_json_text( text: String, indent: String = "\t", sort_keys: bool = false, fallback: String = "" ) -> String:` |
| 方法 | [`compact_json_text`](#member-gfvariantjsoncodec-methods-compact_json_text) | `static func compact_json_text(text: String, sort_keys: bool = false, fallback: String = "") -> String:` |
| 方法 | [`vector2_to_array`](#member-gfvariantjsoncodec-methods-vector2_to_array) | `static func vector2_to_array(value: Vector2) -> Array:` |
| 方法 | [`array_to_vector2`](#member-gfvariantjsoncodec-methods-array_to_vector2) | `static func array_to_vector2(value: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:` |
| 方法 | [`vector3_to_array`](#member-gfvariantjsoncodec-methods-vector3_to_array) | `static func vector3_to_array(value: Vector3) -> Array:` |
| 方法 | [`array_to_vector3`](#member-gfvariantjsoncodec-methods-array_to_vector3) | `static func array_to_vector3(value: Variant, fallback: Vector3 = Vector3.ZERO) -> Vector3:` |
| 方法 | [`color_to_array`](#member-gfvariantjsoncodec-methods-color_to_array) | `static func color_to_array(value: Color) -> Array:` |
| 方法 | [`array_to_color`](#member-gfvariantjsoncodec-methods-array_to_color) | `static func array_to_color(value: Variant, fallback: Color = Color.WHITE) -> Color:` |

## 方法

<a id="member-gfvariantjsoncodec-methods-variant_to_json_compatible"></a>

### `variant_to_json_compatible`

- API：`public`

```gdscript
static func variant_to_json_compatible(value: Variant, options: Dictionary = {}) -> Variant:
```

将 Variant 转为 JSON.stringify() 可安全编码的值。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 待转换的 Variant。 |
| `options` | 可选项；encode_dictionary_keys 为 true 时会保留非字符串字典键；encode_unsafe_ints 为 false 时不标记超出 JSON 安全范围的整数。 |

返回：JSON 兼容值；Godot 专有类型会带类型标记。

结构：

- `value`: Variant value to encode.
- `options`: Dictionary with encode_dictionary_keys, encode_unsafe_ints, unsupported, and circular_reference options.
- `return`: Variant made only from JSON-compatible values and typed marker dictionaries.

<a id="member-gfvariantjsoncodec-methods-json_compatible_to_variant"></a>

### `json_compatible_to_variant`

- API：`public`

```gdscript
static func json_compatible_to_variant(value: Variant, options: Dictionary = {}) -> Variant:
```

从 variant_to_json_compatible() 生成的值恢复 Godot Variant。

参数：

| 名称 | 说明 |
|---|---|
| `value` | JSON.parse_string() 后的值。 |
| `options` | 可选项；decode_typed_markers 为 false 时只递归恢复集合。 |

返回：恢复后的 Variant。

结构：

- `value`: Variant parsed from JSON-compatible data.
- `options`: Dictionary with decode_typed_markers and key decoding options.
- `return`: Variant restored from JSON-compatible data.

<a id="member-gfvariantjsoncodec-methods-parse_json_text"></a>

### `parse_json_text`

- API：`public`

```gdscript
static func parse_json_text(text: String, fallback: Variant = null) -> Variant:
```

解析 JSON 文本，失败时返回 fallback。

参数：

| 名称 | 说明 |
|---|---|
| `text` | JSON 文本。 |
| `fallback` | 解析失败时返回的值。 |

返回：解析后的 JSON 值，或 fallback。

结构：

- `fallback`: Variant returned unchanged when JSON parsing fails.
- `return`: Variant parsed by Godot JSON, or fallback on parse error.

<a id="member-gfvariantjsoncodec-methods-format_json_text"></a>

### `format_json_text`

- API：`public`

```gdscript
static func format_json_text( text: String, indent: String = "\t", sort_keys: bool = false, fallback: String = "" ) -> String:
```

格式化 JSON 文本，失败时返回 fallback。

参数：

| 名称 | 说明 |
|---|---|
| `text` | JSON 文本。 |
| `indent` | 缩进字符串；默认使用 Tab。 |
| `sort_keys` | 是否按键名排序 Dictionary。 |
| `fallback` | 解析失败时返回的文本。 |

返回：格式化后的 JSON 文本，或 fallback。

<a id="member-gfvariantjsoncodec-methods-compact_json_text"></a>

### `compact_json_text`

- API：`public`

```gdscript
static func compact_json_text(text: String, sort_keys: bool = false, fallback: String = "") -> String:
```

压缩 JSON 文本，失败时返回 fallback。

参数：

| 名称 | 说明 |
|---|---|
| `text` | JSON 文本。 |
| `sort_keys` | 是否按键名排序 Dictionary。 |
| `fallback` | 解析失败时返回的文本。 |

返回：去除非必要空白后的 JSON 文本，或 fallback。

<a id="member-gfvariantjsoncodec-methods-vector2_to_array"></a>

### `vector2_to_array`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
static func vector2_to_array(value: Vector2) -> Array:
```

将 Vector2 转成 JSON 友好的数组，非有限分量使用 Float typed marker。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 待转换的 Vector2。 |

返回：[x, y] 数组。

结构：

- `return`: Array with two JSON-compatible float values; non-finite components use Float typed markers.

<a id="member-gfvariantjsoncodec-methods-array_to_vector2"></a>

### `array_to_vector2`

- API：`public`

```gdscript
static func array_to_vector2(value: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
```

从数组读取 Vector2，失败时返回 fallback。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 输入值。 |
| `fallback` | 转换失败时返回的值。 |

返回：Vector2 值。

结构：

- `value`: Variant expected to be an Array with at least two numeric values.

<a id="member-gfvariantjsoncodec-methods-vector3_to_array"></a>

### `vector3_to_array`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
static func vector3_to_array(value: Vector3) -> Array:
```

将 Vector3 转成 JSON 友好的数组，非有限分量使用 Float typed marker。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 待转换的 Vector3。 |

返回：[x, y, z] 数组。

结构：

- `return`: Array with three JSON-compatible float values; non-finite components use Float typed markers.

<a id="member-gfvariantjsoncodec-methods-array_to_vector3"></a>

### `array_to_vector3`

- API：`public`

```gdscript
static func array_to_vector3(value: Variant, fallback: Vector3 = Vector3.ZERO) -> Vector3:
```

从数组读取 Vector3，失败时返回 fallback。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 输入值。 |
| `fallback` | 转换失败时返回的值。 |

返回：Vector3 值。

结构：

- `value`: Variant expected to be an Array with at least three numeric values.

<a id="member-gfvariantjsoncodec-methods-color_to_array"></a>

### `color_to_array`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
static func color_to_array(value: Color) -> Array:
```

将 Color 转成 JSON 友好的数组，非有限通道使用 Float typed marker。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 待转换的 Color。 |

返回：[r, g, b, a] 数组。

结构：

- `return`: Array with four JSON-compatible float values; non-finite components use Float typed markers.

<a id="member-gfvariantjsoncodec-methods-array_to_color"></a>

### `array_to_color`

- API：`public`

```gdscript
static func array_to_color(value: Variant, fallback: Color = Color.WHITE) -> Color:
```

从数组读取 Color，失败时返回 fallback。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 输入值。 |
| `fallback` | 转换失败时返回的值。 |

返回：Color 值。

结构：

- `value`: Variant expected to be an Array with at least four numeric values.
