# GFNetworkMessageValidator

[API Reference](../index.md) / [Network](../extensions-network.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/network/messages/gf_network_message_validator.gd`
- 模块：`Network`
- 继承：`RefCounted`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.17.0`

通用网络消息校验器。 校验消息类型、包体大小和可选必需载荷字段，避免后端收到明显无效数据。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`DEFAULT_MAX_PACKET_SIZE`](#member-gfnetworkmessagevalidator-constants-default_max_packet_size) | `const DEFAULT_MAX_PACKET_SIZE: int = 64 * 1024` |
| 属性 | [`allow_empty_message_type`](#member-gfnetworkmessagevalidator-properties-allow_empty_message_type) | `var allow_empty_message_type: bool = false` |
| 属性 | [`min_packet_size`](#member-gfnetworkmessagevalidator-properties-min_packet_size) | `var min_packet_size: int = 1` |
| 属性 | [`max_packet_size`](#member-gfnetworkmessagevalidator-properties-max_packet_size) | `var max_packet_size: int = DEFAULT_MAX_PACKET_SIZE` |
| 属性 | [`required_payload_keys`](#member-gfnetworkmessagevalidator-properties-required_payload_keys) | `var required_payload_keys: PackedStringArray = PackedStringArray()` |
| 方法 | [`validate_message`](#member-gfnetworkmessagevalidator-methods-validate_message) | `func validate_message(message: GFNetworkMessage) -> Dictionary:` |
| 方法 | [`validate_bytes`](#member-gfnetworkmessagevalidator-methods-validate_bytes) | `func validate_bytes(bytes: PackedByteArray, channel: GFNetworkChannel = null) -> Dictionary:` |
| 方法 | [`get_debug_snapshot`](#member-gfnetworkmessagevalidator-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 常量

<a id="member-gfnetworkmessagevalidator-constants-default_max_packet_size"></a>

### `DEFAULT_MAX_PACKET_SIZE`

- API：`public`

```gdscript
const DEFAULT_MAX_PACKET_SIZE: int = 64 * 1024
```

默认全局最大包体大小，单位 bytes。

## 属性

<a id="member-gfnetworkmessagevalidator-properties-allow_empty_message_type"></a>

### `allow_empty_message_type`

- API：`public`

```gdscript
var allow_empty_message_type: bool = false
```

是否允许空 message_type。

<a id="member-gfnetworkmessagevalidator-properties-min_packet_size"></a>

### `min_packet_size`

- API：`public`

```gdscript
var min_packet_size: int = 1
```

最小包体大小。小于等于 0 表示不限制。

<a id="member-gfnetworkmessagevalidator-properties-max_packet_size"></a>

### `max_packet_size`

- API：`public`

```gdscript
var max_packet_size: int = DEFAULT_MAX_PACKET_SIZE
```

最大包体大小。小于等于 0 表示不限制。

<a id="member-gfnetworkmessagevalidator-properties-required_payload_keys"></a>

### `required_payload_keys`

- API：`public`

```gdscript
var required_payload_keys: PackedStringArray = PackedStringArray()
```

所有消息都必须包含的 payload key。

## 方法

<a id="member-gfnetworkmessagevalidator-methods-validate_message"></a>

### `validate_message`

- API：`public`

```gdscript
func validate_message(message: GFNetworkMessage) -> Dictionary:
```

校验消息对象。

参数：

| 名称 | 说明 |
|---|---|
| `message` | 消息。 |

返回：统一校验报告。

结构：

- `return`: Dictionary，包含 ok 和 errors。

<a id="member-gfnetworkmessagevalidator-methods-validate_bytes"></a>

### `validate_bytes`

- API：`public`

```gdscript
func validate_bytes(bytes: PackedByteArray, channel: GFNetworkChannel = null) -> Dictionary:
```

校验原始包体。

参数：

| 名称 | 说明 |
|---|---|
| `bytes` | 包体。 |
| `channel` | 可选通道描述。 |

返回：统一校验报告。

结构：

- `return`: Dictionary，包含 ok 和 errors。

<a id="member-gfnetworkmessagevalidator-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：校验器状态。

结构：

- `return`: Dictionary，包含 allow_empty_message_type、min_packet_size、max_packet_size、required_payload_keys。
