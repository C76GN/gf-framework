# GFAudioClip

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/audio/gf_audio_clip.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

可资源化的音频播放配置。 支持直接引用 `AudioStream`，也支持提供资源路径交给 `GFAudioUtility` 按需加载。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`path`](#member-gfaudioclip-properties-path) | `var path: String = ""` |
| 属性 | [`stream`](#member-gfaudioclip-properties-stream) | `var stream: AudioStream` |
| 属性 | [`bus_name`](#member-gfaudioclip-properties-bus_name) | `var bus_name: String = ""` |
| 属性 | [`volume_db`](#member-gfaudioclip-properties-volume_db) | `var volume_db: float = 0.0` |
| 属性 | [`pitch_scale`](#member-gfaudioclip-properties-pitch_scale) | `var pitch_scale: float = 1.0` |
| 属性 | [`weight`](#member-gfaudioclip-properties-weight) | `var weight: float = 1.0` |
| 属性 | [`pitch_random_min`](#member-gfaudioclip-properties-pitch_random_min) | `var pitch_random_min: float = 1.0` |
| 属性 | [`pitch_random_max`](#member-gfaudioclip-properties-pitch_random_max) | `var pitch_random_max: float = 1.0` |
| 属性 | [`spatial_settings`](#member-gfaudioclip-properties-spatial_settings) | `var spatial_settings: Resource = null` |
| 属性 | [`playback_region`](#member-gfaudioclip-properties-playback_region) | `var playback_region: GFAudioPlaybackRegion = null` |
| 属性 | [`metadata`](#member-gfaudioclip-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`has_source`](#member-gfaudioclip-methods-has_source) | `func has_source() -> bool:` |
| 方法 | [`resolve_bus`](#member-gfaudioclip-methods-resolve_bus) | `func resolve_bus(default_bus: String) -> String:` |
| 方法 | [`resolve_pitch`](#member-gfaudioclip-methods-resolve_pitch) | `func resolve_pitch(rng: RandomNumberGenerator = null) -> float:` |
| 方法 | [`has_metadata_value`](#member-gfaudioclip-methods-has_metadata_value) | `func has_metadata_value(key: Variant) -> bool:` |
| 方法 | [`set_metadata_value`](#member-gfaudioclip-methods-set_metadata_value) | `func set_metadata_value(key: Variant, value: Variant) -> void:` |
| 方法 | [`get_metadata_value`](#member-gfaudioclip-methods-get_metadata_value) | `func get_metadata_value(key: Variant, default_value: Variant = null) -> Variant:` |
| 方法 | [`duplicate_metadata`](#member-gfaudioclip-methods-duplicate_metadata) | `func duplicate_metadata() -> Dictionary:` |

## 属性

<a id="member-gfaudioclip-properties-path"></a>

### `path`

- API：`public`

```gdscript
var path: String = ""
```

音频资源路径。`stream` 为空时使用该路径加载。

<a id="member-gfaudioclip-properties-stream"></a>

### `stream`

- API：`public`

```gdscript
var stream: AudioStream
```

音频流资源。

<a id="member-gfaudioclip-properties-bus_name"></a>

### `bus_name`

- API：`public`

```gdscript
var bus_name: String = ""
```

音频总线。为空时由播放方法使用默认 BGM/SFX 总线。

<a id="member-gfaudioclip-properties-volume_db"></a>

### `volume_db`

- API：`public`

```gdscript
var volume_db: float = 0.0
```

播放音量，单位 dB。

<a id="member-gfaudioclip-properties-pitch_scale"></a>

### `pitch_scale`

- API：`public`

```gdscript
var pitch_scale: float = 1.0
```

播放音高。

<a id="member-gfaudioclip-properties-weight"></a>

### `weight`

- API：`public`

```gdscript
var weight: float = 1.0
```

在同一片段 ID 存在多个候选时的抽取权重；小于等于 0 表示不参与随机抽取。

<a id="member-gfaudioclip-properties-pitch_random_min"></a>

### `pitch_random_min`

- API：`public`

```gdscript
var pitch_random_min: float = 1.0
```

播放音高随机下限，会乘到 pitch_scale 上。

<a id="member-gfaudioclip-properties-pitch_random_max"></a>

### `pitch_random_max`

- API：`public`

```gdscript
var pitch_random_max: float = 1.0
```

播放音高随机上限，会乘到 pitch_scale 上。

<a id="member-gfaudioclip-properties-spatial_settings"></a>

### `spatial_settings`

- API：`public`
- 首次版本：`3.19.0`

```gdscript
var spatial_settings: Resource = null
```

可选空间播放设置。为空时空间 SFX 使用 GF 默认空间参数，并保留区域掩码 layer 1。

结构：

- `spatial_settings`: GFAudioSpatialSettings or compatible Resource with apply_to_2d/apply_to_3d methods.

<a id="member-gfaudioclip-properties-playback_region"></a>

### `playback_region`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
var playback_region: GFAudioPlaybackRegion = null
```

可选类型化播放区间。为空时按音频流原始设置从头播放。 区间会在每次播放请求开始时复制；本地播放器只接受 Godot 音频流能够原生、 精确表达的起点和循环点，不用帧轮询模拟有限终点。

<a id="member-gfaudioclip-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`5.1.0`

```gdscript
var metadata: Dictionary = {}
```

可选音频元数据，供导入器、编辑器或项目层扩展使用。

结构：

- `metadata`: Dictionary，保存项目或工具附加到片段的通用元数据；GF 不解释具体键。

## 方法

<a id="member-gfaudioclip-methods-has_source"></a>

### `has_source`

- API：`public`

```gdscript
func has_source() -> bool:
```

检查该配置是否有可播放来源。

返回：有 stream 或 path 时返回 true。

<a id="member-gfaudioclip-methods-resolve_bus"></a>

### `resolve_bus`

- API：`public`

```gdscript
func resolve_bus(default_bus: String) -> String:
```

解析实际总线名称。

参数：

| 名称 | 说明 |
|---|---|
| `default_bus` | 默认总线。 |

返回：实际总线名称。

<a id="member-gfaudioclip-methods-resolve_pitch"></a>

### `resolve_pitch`

- API：`public`

```gdscript
func resolve_pitch(rng: RandomNumberGenerator = null) -> float:
```

解析本次播放使用的实际音高。

参数：

| 名称 | 说明 |
|---|---|
| `rng` | 可选随机数生成器；为空时使用确定性的 pitch_scale。 |

返回：实际播放音高。

<a id="member-gfaudioclip-methods-has_metadata_value"></a>

### `has_metadata_value`

- API：`public`
- 首次版本：`5.1.0`

```gdscript
func has_metadata_value(key: Variant) -> bool:
```

检查指定元数据键是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 元数据键。 |

返回：存在返回 true。

结构：

- `key`: Variant，推荐使用 String 或 StringName。

<a id="member-gfaudioclip-methods-set_metadata_value"></a>

### `set_metadata_value`

- API：`public`
- 首次版本：`5.1.0`

```gdscript
func set_metadata_value(key: Variant, value: Variant) -> void:
```

设置元数据项。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 元数据键。 |
| `value` | 元数据值。 |

结构：

- `key`: Variant，推荐使用 String 或 StringName。
- `value`: Variant，推荐使用可序列化的标量、Array、Dictionary 或 Resource 引用。

<a id="member-gfaudioclip-methods-get_metadata_value"></a>

### `get_metadata_value`

- API：`public`
- 首次版本：`5.1.0`

```gdscript
func get_metadata_value(key: Variant, default_value: Variant = null) -> Variant:
```

获取元数据项。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 元数据键。 |
| `default_value` | 缺少键时返回的默认值。 |

返回：元数据值或默认值。

结构：

- `key`: Variant，推荐使用 String 或 StringName。
- `default_value`: Variant 默认值。
- `return`: Variant 元数据值。

<a id="member-gfaudioclip-methods-duplicate_metadata"></a>

### `duplicate_metadata`

- API：`public`
- 首次版本：`5.1.0`

```gdscript
func duplicate_metadata() -> Dictionary:
```

创建元数据深拷贝。

返回：元数据副本。

结构：

- `return`: Dictionary 元数据副本。
