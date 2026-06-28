# GFNetworkMessage

[API Reference](../index.md) / [Network](../extensions-network.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/network/messages/gf_network_message.gd`
- 模块：`Network`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`3.17.0`

通用网络消息载体。 只描述传输元信息和字典载荷，不绑定具体协议、后端或业务消息类型。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`message_type`](#member-gfnetworkmessage-properties-message_type) | `var message_type: StringName = &""` |
| 属性 | [`sequence`](#member-gfnetworkmessage-properties-sequence) | `var sequence: int = 0` |
| 属性 | [`tick`](#member-gfnetworkmessage-properties-tick) | `var tick: int = 0` |
| 属性 | [`sender_id`](#member-gfnetworkmessage-properties-sender_id) | `var sender_id: int = -1` |
| 属性 | [`channel_id`](#member-gfnetworkmessage-properties-channel_id) | `var channel_id: StringName = &""` |
| 属性 | [`payload`](#member-gfnetworkmessage-properties-payload) | `var payload: Dictionary = {}` |
| 方法 | [`to_dict`](#member-gfnetworkmessage-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`from_dict`](#member-gfnetworkmessage-methods-from_dict) | `func from_dict(data: Dictionary) -> void:` |

## 属性

<a id="member-gfnetworkmessage-properties-message_type"></a>

### `message_type`

- API：`public`

```gdscript
var message_type: StringName = &""
```

消息类型标识。

<a id="member-gfnetworkmessage-properties-sequence"></a>

### `sequence`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var sequence: int = 0
```

发送端自增序号。 该字段只是项目层可序列化 metadata；GF Network 不基于它提供 ACK、重试或去重。

<a id="member-gfnetworkmessage-properties-tick"></a>

### `tick`

- API：`public`

```gdscript
var tick: int = 0
```

逻辑 tick 或帧号。

<a id="member-gfnetworkmessage-properties-sender_id"></a>

### `sender_id`

- API：`public`

```gdscript
var sender_id: int = -1
```

发送者标识。

<a id="member-gfnetworkmessage-properties-channel_id"></a>

### `channel_id`

- API：`public`

```gdscript
var channel_id: StringName = &""
```

逻辑网络通道标识。为空时入站侧可按 message_type 匹配同名通道。

<a id="member-gfnetworkmessage-properties-payload"></a>

### `payload`

- API：`public`

```gdscript
var payload: Dictionary = {}
```

消息载荷。

结构：

- `payload`: Dictionary[StringName|String, Variant]，保存消息业务载荷。

## 方法

<a id="member-gfnetworkmessage-methods-to_dict"></a>

### `to_dict`

- API：`public`

```gdscript
func to_dict() -> Dictionary:
```

转为可序列化字典。

返回：字典载荷。

结构：

- `return`: Dictionary，包含 type、sequence、tick、sender_id、channel_id、payload。

<a id="member-gfnetworkmessage-methods-from_dict"></a>

### `from_dict`

- API：`public`

```gdscript
func from_dict(data: Dictionary) -> void:
```

从字典恢复。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 字典载荷。 |

结构：

- `data`: Dictionary，包含 type、sequence、tick、sender_id、channel_id、payload。
