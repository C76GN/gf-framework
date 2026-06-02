# GFNetworkChannel

[API Reference](../index.md) / [Network](../extensions-network.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/network/session/gf_network_channel.gd`
- 模块：`Network`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

网络发送通道描述。 描述一类消息的传输偏好，例如通道编号、可靠性和包体上限。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`channel_id`](#member-gfnetworkchannel-properties-channel_id) | `var channel_id: StringName = &""` |
| 属性 | [`display_name`](#member-gfnetworkchannel-properties-display_name) | `var display_name: String = ""` |
| 属性 | [`transfer_channel`](#member-gfnetworkchannel-properties-transfer_channel) | `var transfer_channel: int = 0` |
| 属性 | [`reliable`](#member-gfnetworkchannel-properties-reliable) | `var reliable: bool = true` |
| 属性 | [`max_packet_size`](#member-gfnetworkchannel-properties-max_packet_size) | `var max_packet_size: int = 0` |
| 属性 | [`metadata`](#member-gfnetworkchannel-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`get_display_name`](#member-gfnetworkchannel-methods-get_display_name) | `func get_display_name() -> String:` |
| 方法 | [`build_send_options`](#member-gfnetworkchannel-methods-build_send_options) | `func build_send_options(overrides: Dictionary = {}) -> Dictionary:` |
| 方法 | [`describe`](#member-gfnetworkchannel-methods-describe) | `func describe() -> Dictionary:` |

## 属性

<a id="member-gfnetworkchannel-properties-channel_id"></a>

### `channel_id`

- API：`public`

```gdscript
var channel_id: StringName = &""
```

通道稳定标识。

<a id="member-gfnetworkchannel-properties-display_name"></a>

### `display_name`

- API：`public`

```gdscript
var display_name: String = ""
```

编辑器展示名称。

<a id="member-gfnetworkchannel-properties-transfer_channel"></a>

### `transfer_channel`

- API：`public`

```gdscript
var transfer_channel: int = 0
```

后端传输通道编号。

<a id="member-gfnetworkchannel-properties-reliable"></a>

### `reliable`

- API：`public`

```gdscript
var reliable: bool = true
```

默认是否可靠传输。

<a id="member-gfnetworkchannel-properties-max_packet_size"></a>

### `max_packet_size`

- API：`public`

```gdscript
var max_packet_size: int = 0
```

最大包体大小。小于等于 0 表示不限制。

<a id="member-gfnetworkchannel-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

项目自定义元数据。框架不解释该字段。

结构：

- `metadata`: Dictionary，保存项目自定义通道元数据。

## 方法

<a id="member-gfnetworkchannel-methods-get_display_name"></a>

### `get_display_name`

- API：`public`

```gdscript
func get_display_name() -> String:
```

获取展示名称。

返回：展示名称。

<a id="member-gfnetworkchannel-methods-build_send_options"></a>

### `build_send_options`

- API：`public`

```gdscript
func build_send_options(overrides: Dictionary = {}) -> Dictionary:
```

构建后端发送选项。

参数：

| 名称 | 说明 |
|---|---|
| `overrides` | 项目层额外发送选项。 |

返回：后端选项字典。

结构：

- `overrides`: Dictionary，项目层发送选项；channel 和 reliable 缺失时由通道默认值补齐。
- `return`: Dictionary，后端发送选项，至少包含 channel 和 reliable。

<a id="member-gfnetworkchannel-methods-describe"></a>

### `describe`

- API：`public`

```gdscript
func describe() -> Dictionary:
```

描述通道。

返回：描述字典。

结构：

- `return`: Dictionary，包含 channel_id、display_name、transfer_channel、reliable、max_packet_size、metadata。
