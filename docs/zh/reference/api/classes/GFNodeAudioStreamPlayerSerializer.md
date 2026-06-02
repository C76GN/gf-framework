# GFNodeAudioStreamPlayerSerializer

[API Reference](../index.md) / [Save](../extensions-save.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/save/serializers/gf_node_audio_stream_player_serializer.gd`
- 模块：`Save`
- 继承：`GFNodeSerializer`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

AudioStreamPlayer 通用播放状态序列化器。 支持 AudioStreamPlayer、AudioStreamPlayer2D 与 AudioStreamPlayer3D 的通用播放参数。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`supports_node`](#member-gfnodeaudiostreamplayerserializer-methods-supports_node) | `func supports_node(node: Node) -> bool:` |
| 方法 | [`gather`](#member-gfnodeaudiostreamplayerserializer-methods-gather) | `func gather(node: Node, _context: Dictionary = {}) -> Dictionary:` |
| 方法 | [`apply`](#member-gfnodeaudiostreamplayerserializer-methods-apply) | `func apply(node: Node, payload: Dictionary, _context: Dictionary = {}) -> Dictionary:` |

## 方法

<a id="member-gfnodeaudiostreamplayerserializer-methods-supports_node"></a>

### `supports_node`

- API：`public`

```gdscript
func supports_node(node: Node) -> bool:
```

判断序列化器是否支持指定节点。

参数：

| 名称 | 说明 |
|---|---|
| `node` | 目标节点。 |

返回：节点是否为 AudioStreamPlayer、AudioStreamPlayer2D 或 AudioStreamPlayer3D。

<a id="member-gfnodeaudiostreamplayerserializer-methods-gather"></a>

### `gather`

- API：`public`

```gdscript
func gather(node: Node, _context: Dictionary = {}) -> Dictionary:
```

采集节点的可保存状态。

参数：

| 名称 | 说明 |
|---|---|
| `node` | 目标节点。 |
| `_context` | 操作上下文字典，默认实现不直接使用。 |

返回：音频播放状态载荷。

结构：

- `_context`: Dictionary，调用方附加上下文；当前实现不读取。
- `return`: Dictionary，可包含 playing、playback_position、stream_paused、volume_db、pitch_scale、bus、max_distance 与 attenuation。

<a id="member-gfnodeaudiostreamplayerserializer-methods-apply"></a>

### `apply`

- API：`public`

```gdscript
func apply(node: Node, payload: Dictionary, _context: Dictionary = {}) -> Dictionary:
```

将序列化数据应用到节点。

参数：

| 名称 | 说明 |
|---|---|
| `node` | 目标节点。 |
| `payload` | 音频播放状态载荷。 |
| `_context` | 操作上下文字典，默认实现不直接使用。 |

返回：应用结果字典。

结构：

- `payload`: Dictionary，可包含 playing、playback_position、stream_paused、volume_db、pitch_scale、bus、max_distance 与 attenuation。
- `_context`: Dictionary，调用方附加上下文；当前实现不读取。
- `return`: Dictionary，包含 ok: bool 与 error: String。
