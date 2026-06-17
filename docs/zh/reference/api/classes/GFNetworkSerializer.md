# GFNetworkSerializer

[API Reference](../index.md) / [Network](../extensions-network.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/network/serialization/gf_network_serializer.gd`
- 模块：`Network`
- 继承：`RefCounted`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.17.0`

通用网络消息编码器。 提供 Variant 二进制与 JSON 两种编码方式，供不同网络后端复用。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`Format`](#member-gfnetworkserializer-enums-format) | `enum Format` |
| 属性 | [`format`](#member-gfnetworkserializer-properties-format) | `var format: Format = Format.BINARY` |
| 属性 | [`use_typed_json_codec`](#member-gfnetworkserializer-properties-use_typed_json_codec) | `var use_typed_json_codec: bool = false` |
| 属性 | [`json_codec_options`](#member-gfnetworkserializer-properties-json_codec_options) | `var json_codec_options: Dictionary = {}` |
| 方法 | [`serialize_message`](#member-gfnetworkserializer-methods-serialize_message) | `func serialize_message(message: GFNetworkMessage) -> PackedByteArray:` |
| 方法 | [`deserialize_message`](#member-gfnetworkserializer-methods-deserialize_message) | `func deserialize_message(bytes: PackedByteArray) -> GFNetworkMessage:` |
| 方法 | [`deserialize_message_result`](#member-gfnetworkserializer-methods-deserialize_message_result) | `func deserialize_message_result(bytes: PackedByteArray) -> Dictionary:` |
| 方法 | [`serialize_dictionary`](#member-gfnetworkserializer-methods-serialize_dictionary) | `func serialize_dictionary(data: Dictionary) -> PackedByteArray:` |
| 方法 | [`deserialize_dictionary_result`](#member-gfnetworkserializer-methods-deserialize_dictionary_result) | `func deserialize_dictionary_result(bytes: PackedByteArray) -> Dictionary:` |

## 枚举

<a id="member-gfnetworkserializer-enums-format"></a>

### `Format`

- API：`public`

```gdscript
enum Format {
	## Godot Variant 二进制编码。
	BINARY,
	## UTF-8 JSON 编码。
	JSON,
}
```

消息编码格式。

## 属性

<a id="member-gfnetworkserializer-properties-format"></a>

### `format`

- API：`public`

```gdscript
var format: Format = Format.BINARY
```

默认编码格式。

<a id="member-gfnetworkserializer-properties-use_typed_json_codec"></a>

### `use_typed_json_codec`

- API：`public`

```gdscript
var use_typed_json_codec: bool = false
```

JSON 格式下是否使用 GFVariantJsonCodec 的类型化 Godot Variant 编码。

<a id="member-gfnetworkserializer-properties-json_codec_options"></a>

### `json_codec_options`

- API：`public`

```gdscript
var json_codec_options: Dictionary = {}
```

传给 GFVariantJsonCodec JSON codec 的可选配置。

结构：

- `json_codec_options`: Dictionary，传给 GFVariantJsonCodec 的 JSON 编码/解码选项。

## 方法

<a id="member-gfnetworkserializer-methods-serialize_message"></a>

### `serialize_message`

- API：`public`

```gdscript
func serialize_message(message: GFNetworkMessage) -> PackedByteArray:
```

编码消息。

参数：

| 名称 | 说明 |
|---|---|
| `message` | 消息载体。 |

返回：字节数组。

<a id="member-gfnetworkserializer-methods-deserialize_message"></a>

### `deserialize_message`

- API：`public`

```gdscript
func deserialize_message(bytes: PackedByteArray) -> GFNetworkMessage:
```

解码消息。

参数：

| 名称 | 说明 |
|---|---|
| `bytes` | 源 bytes。 |

返回：消息载体；失败时返回 null。

<a id="member-gfnetworkserializer-methods-deserialize_message_result"></a>

### `deserialize_message_result`

- API：`public`

```gdscript
func deserialize_message_result(bytes: PackedByteArray) -> Dictionary:
```

解码消息并返回结果字典。

参数：

| 名称 | 说明 |
|---|---|
| `bytes` | 源 bytes。 |

返回：包含 ok、data、error 的结果字典。

结构：

- `return`: Dictionary，包含 ok、data、error；data 为 GFNetworkMessage 或空字典。

<a id="member-gfnetworkserializer-methods-serialize_dictionary"></a>

### `serialize_dictionary`

- API：`public`

```gdscript
func serialize_dictionary(data: Dictionary) -> PackedByteArray:
```

编码字典。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 字典。 |

返回：字节数组。

结构：

- `data`: Dictionary，待编码的消息或项目自定义字典。

<a id="member-gfnetworkserializer-methods-deserialize_dictionary_result"></a>

### `deserialize_dictionary_result`

- API：`public`

```gdscript
func deserialize_dictionary_result(bytes: PackedByteArray) -> Dictionary:
```

解码字典并返回结果字典。

参数：

| 名称 | 说明 |
|---|---|
| `bytes` | 源 bytes。 |

返回：包含 ok、data、error 的结果字典；合法空字典会返回 ok=true。

结构：

- `return`: Dictionary，包含 ok、data、error；data 为解码后的 Dictionary。
