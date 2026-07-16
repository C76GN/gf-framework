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
| 属性 | [`allowed_message_types`](#member-gfnetworkmessagevalidator-properties-allowed_message_types) | `var allowed_message_types: PackedStringArray = PackedStringArray()` |
| 属性 | [`blocked_message_types`](#member-gfnetworkmessagevalidator-properties-blocked_message_types) | `var blocked_message_types: PackedStringArray = PackedStringArray()` |
| 属性 | [`contract`](#member-gfnetworkmessagevalidator-properties-contract) | `var contract: GFNetworkContract = null` |
| 属性 | [`require_contract_message`](#member-gfnetworkmessagevalidator-properties-require_contract_message) | `var require_contract_message: bool = false` |
| 属性 | [`known_channel_ids`](#member-gfnetworkmessagevalidator-properties-known_channel_ids) | `var known_channel_ids: PackedStringArray = PackedStringArray()` |
| 属性 | [`enforce_sender_id_matches_peer`](#member-gfnetworkmessagevalidator-properties-enforce_sender_id_matches_peer) | `var enforce_sender_id_matches_peer: bool = false` |
| 属性 | [`require_sender_id`](#member-gfnetworkmessagevalidator-properties-require_sender_id) | `var require_sender_id: bool = false` |
| 属性 | [`min_sequence`](#member-gfnetworkmessagevalidator-properties-min_sequence) | `var min_sequence: int = -1` |
| 属性 | [`max_sequence`](#member-gfnetworkmessagevalidator-properties-max_sequence) | `var max_sequence: int = -1` |
| 属性 | [`min_tick`](#member-gfnetworkmessagevalidator-properties-min_tick) | `var min_tick: int = -1` |
| 属性 | [`max_tick`](#member-gfnetworkmessagevalidator-properties-max_tick) | `var max_tick: int = -1` |
| 方法 | [`validate_message`](#member-gfnetworkmessagevalidator-methods-validate_message) | `func validate_message(message: GFNetworkMessage) -> Dictionary:` |
| 方法 | [`validate_message_for_peer`](#member-gfnetworkmessagevalidator-methods-validate_message_for_peer) | `func validate_message_for_peer(message: GFNetworkMessage, peer_id: int) -> Dictionary:` |
| 方法 | [`allow_message_type`](#member-gfnetworkmessagevalidator-methods-allow_message_type) | `func allow_message_type(message_type: StringName) -> bool:` |
| 方法 | [`register_known_channel`](#member-gfnetworkmessagevalidator-methods-register_known_channel) | `func register_known_channel(channel_id: StringName) -> bool:` |
| 方法 | [`configure_from_contract`](#member-gfnetworkmessagevalidator-methods-configure_from_contract) | `func configure_from_contract(network_contract: GFNetworkContract, options: Dictionary = {}) -> void:` |
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

<a id="member-gfnetworkmessagevalidator-properties-allowed_message_types"></a>

### `allowed_message_types`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var allowed_message_types: PackedStringArray = PackedStringArray()
```

允许的 message_type 列表。为空时不限制。

<a id="member-gfnetworkmessagevalidator-properties-blocked_message_types"></a>

### `blocked_message_types`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var blocked_message_types: PackedStringArray = PackedStringArray()
```

显式拒绝的 message_type 列表。

<a id="member-gfnetworkmessagevalidator-properties-contract"></a>

### `contract`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var contract: GFNetworkContract = null
```

可选网络契约。设置后可用字段契约校验消息 payload。

<a id="member-gfnetworkmessagevalidator-properties-require_contract_message"></a>

### `require_contract_message`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var require_contract_message: bool = false
```

是否要求 message_type 必须存在于 contract 中。

<a id="member-gfnetworkmessagevalidator-properties-known_channel_ids"></a>

### `known_channel_ids`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var known_channel_ids: PackedStringArray = PackedStringArray()
```

已知逻辑 channel_id 列表。为空时不限制。

<a id="member-gfnetworkmessagevalidator-properties-enforce_sender_id_matches_peer"></a>

### `enforce_sender_id_matches_peer`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var enforce_sender_id_matches_peer: bool = false
```

通过 validate_message_for_peer() 校验时，是否要求 sender_id 与实际 peer_id 一致。

<a id="member-gfnetworkmessagevalidator-properties-require_sender_id"></a>

### `require_sender_id`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var require_sender_id: bool = false
```

是否要求消息显式携带 sender_id。

<a id="member-gfnetworkmessagevalidator-properties-min_sequence"></a>

### `min_sequence`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var min_sequence: int = -1
```

最小允许 sequence。小于 0 表示不限制。

<a id="member-gfnetworkmessagevalidator-properties-max_sequence"></a>

### `max_sequence`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var max_sequence: int = -1
```

最大允许 sequence。小于 0 表示不限制。

<a id="member-gfnetworkmessagevalidator-properties-min_tick"></a>

### `min_tick`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var min_tick: int = -1
```

最小允许 tick。小于 0 表示不限制。

<a id="member-gfnetworkmessagevalidator-properties-max_tick"></a>

### `max_tick`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var max_tick: int = -1
```

最大允许 tick。小于 0 表示不限制。

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

<a id="member-gfnetworkmessagevalidator-methods-validate_message_for_peer"></a>

### `validate_message_for_peer`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func validate_message_for_peer(message: GFNetworkMessage, peer_id: int) -> Dictionary:
```

按实际 peer 上下文校验消息对象。

参数：

| 名称 | 说明 |
|---|---|
| `message` | 消息。 |
| `peer_id` | 实际传输 peer 标识。 |

返回：统一校验报告。

结构：

- `return`: Dictionary，包含 ok 和 errors。

<a id="member-gfnetworkmessagevalidator-methods-allow_message_type"></a>

### `allow_message_type`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func allow_message_type(message_type: StringName) -> bool:
```

添加允许的 message_type。

参数：

| 名称 | 说明 |
|---|---|
| `message_type` | 消息类型。 |

返回：成功添加或已存在时返回 true。

<a id="member-gfnetworkmessagevalidator-methods-register_known_channel"></a>

### `register_known_channel`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func register_known_channel(channel_id: StringName) -> bool:
```

添加已知 channel_id。

参数：

| 名称 | 说明 |
|---|---|
| `channel_id` | 通道标识。 |

返回：成功添加或已存在时返回 true。

<a id="member-gfnetworkmessagevalidator-methods-configure_from_contract"></a>

### `configure_from_contract`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func configure_from_contract(network_contract: GFNetworkContract, options: Dictionary = {}) -> void:
```

从网络契约同步允许消息和已知通道。

参数：

| 名称 | 说明 |
|---|---|
| `network_contract` | 网络契约。 |
| `options` | 同步选项，支持 include_channels。 |

结构：

- `options`: Dictionary sync options.

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
- 首次版本：`3.17.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：校验器状态。

结构：

- `return`: Dictionary，包含 allow_empty_message_type、min_packet_size、max_packet_size、required_payload_keys、allowed_message_types、blocked_message_types、require_contract_message、known_channel_ids、enforce_sender_id_matches_peer、require_sender_id、min_sequence、max_sequence、min_tick 和 max_tick。
