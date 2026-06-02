# GFAudioEvent

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/audio/gf_audio_event.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：事件契约 (`event_contract`)
- 首次版本：`3.17.0`

通用资源化音频事件。 描述一个可以交给 `GFAudioUtility` 或音频后端处理的事件请求。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`event_id`](#member-gfaudioevent-properties-event_id) | `var event_id: StringName = &""` |
| 属性 | [`channel`](#member-gfaudioevent-properties-channel) | `var channel: StringName = &"sfx"` |
| 属性 | [`bank_id`](#member-gfaudioevent-properties-bank_id) | `var bank_id: StringName = &""` |
| 属性 | [`path`](#member-gfaudioevent-properties-path) | `var path: String = ""` |
| 属性 | [`clip`](#member-gfaudioevent-properties-clip) | `var clip: GFAudioClip = null` |
| 属性 | [`ambient_channel`](#member-gfaudioevent-properties-ambient_channel) | `var ambient_channel: StringName = &"default"` |
| 属性 | [`metadata`](#member-gfaudioevent-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`has_request`](#member-gfaudioevent-methods-has_request) | `func has_request() -> bool:` |
| 方法 | [`to_request_options`](#member-gfaudioevent-methods-to_request_options) | `func to_request_options(extra_options: Dictionary = {}) -> Dictionary:` |

## 属性

<a id="member-gfaudioevent-properties-event_id"></a>

### `event_id`

- API：`public`

```gdscript
var event_id: StringName = &""
```

事件稳定标识。

<a id="member-gfaudioevent-properties-channel"></a>

### `channel`

- API：`public`

```gdscript
var channel: StringName = &"sfx"
```

事件通道，例如 bgm、sfx、ambient。

<a id="member-gfaudioevent-properties-bank_id"></a>

### `bank_id`

- API：`public`

```gdscript
var bank_id: StringName = &""
```

可选音频集合标识。

<a id="member-gfaudioevent-properties-path"></a>

### `path`

- API：`public`

```gdscript
var path: String = ""
```

可选资源路径或后端事件路径。

<a id="member-gfaudioevent-properties-clip"></a>

### `clip`

- API：`public`

```gdscript
var clip: GFAudioClip = null
```

可选音频片段。

<a id="member-gfaudioevent-properties-ambient_channel"></a>

### `ambient_channel`

- API：`public`

```gdscript
var ambient_channel: StringName = &"default"
```

可选环境音通道。

<a id="member-gfaudioevent-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

可选元数据。

结构：

- `metadata`: 音频事件元数据 Dictionary；键和值由后端或项目逻辑约定。

## 方法

<a id="member-gfaudioevent-methods-has_request"></a>

### `has_request`

- API：`public`

```gdscript
func has_request() -> bool:
```

检查事件是否有可请求内容。

返回：有事件 ID、路径或片段时返回 true。

<a id="member-gfaudioevent-methods-to_request_options"></a>

### `to_request_options`

- API：`public`

```gdscript
func to_request_options(extra_options: Dictionary = {}) -> Dictionary:
```

转换为请求选项。

参数：

| 名称 | 说明 |
|---|---|
| `extra_options` | 额外选项。 |

返回：请求选项字典。

结构：

- `extra_options`: 额外请求选项 Dictionary；键和值由后端或调用方约定，同名键会覆盖 metadata 中的值。
- `return`: 请求选项 Dictionary，包含 metadata 与 extra_options 合并后的字段，并追加 event_id、channel、bank_id、path 和 ambient_channel 字段。
