# GFAudioPlaybackRegion

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/audio/gf_audio_playback_region.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`11.0.0`

类型化音频播放区间与循环点。 使用秒数描述播放起点、自然或显式终点以及循环模式。流准备始终复制源 `AudioStream`，只在副本上写入 Godot 原生循环属性，并对无法精确表达的组合 返回 UNSUPPORTED，避免静默播放错误区间。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`LoopMode`](#member-gfaudioplaybackregion-enums-loopmode) | `enum LoopMode` |
| 属性 | [`start_seconds`](#member-gfaudioplaybackregion-properties-start_seconds) | `var start_seconds: float = 0.0` |
| 属性 | [`end_seconds`](#member-gfaudioplaybackregion-properties-end_seconds) | `var end_seconds: float = -1.0` |
| 属性 | [`loop_mode`](#member-gfaudioplaybackregion-properties-loop_mode) | `var loop_mode: LoopMode = LoopMode.DISABLED` |
| 属性 | [`loop_start_seconds`](#member-gfaudioplaybackregion-properties-loop_start_seconds) | `var loop_start_seconds: float = -1.0` |
| 方法 | [`validate`](#member-gfaudioplaybackregion-methods-validate) | `func validate(stream_length_seconds: float = -1.0) -> GFAudioPlaybackRegionResult:` |
| 方法 | [`prepare_stream`](#member-gfaudioplaybackregion-methods-prepare_stream) | `func prepare_stream(stream: AudioStream) -> GFAudioPlaybackRegionResult:` |
| 方法 | [`duplicate_region`](#member-gfaudioplaybackregion-methods-duplicate_region) | `func duplicate_region() -> GFAudioPlaybackRegion:` |
| 方法 | [`to_dictionary`](#member-gfaudioplaybackregion-methods-to_dictionary) | `func to_dictionary() -> Dictionary:` |

## 枚举

<a id="member-gfaudioplaybackregion-enums-loopmode"></a>

### `LoopMode`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
enum LoopMode {
	## 不循环。
	DISABLED,
	## 从循环起点正向循环到区间终点。
	FORWARD,
	## 在循环起点与区间终点之间往返循环。
	PING_PONG,
	## 从区间终点反向循环到循环起点。
	BACKWARD,
}
```

音频循环模式。

## 属性

<a id="member-gfaudioplaybackregion-properties-start_seconds"></a>

### `start_seconds`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
var start_seconds: float = 0.0
```

播放起点，单位为秒。

<a id="member-gfaudioplaybackregion-properties-end_seconds"></a>

### `end_seconds`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
var end_seconds: float = -1.0
```

播放或循环终点，单位为秒；-1 表示音频流自然结尾。

<a id="member-gfaudioplaybackregion-properties-loop_mode"></a>

### `loop_mode`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
var loop_mode: LoopMode = LoopMode.DISABLED
```

循环模式。

<a id="member-gfaudioplaybackregion-properties-loop_start_seconds"></a>

### `loop_start_seconds`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
var loop_start_seconds: float = -1.0
```

循环起点，单位为秒；-1 表示使用 start_seconds。

## 方法

<a id="member-gfaudioplaybackregion-methods-validate"></a>

### `validate`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func validate(stream_length_seconds: float = -1.0) -> GFAudioPlaybackRegionResult:
```

验证区间结构并解析已知的自然结尾。

参数：

| 名称 | 说明 |
|---|---|
| `stream_length_seconds` | 音频流长度；-1 表示长度未知。 |

返回：验证结果；成功时状态为 VALID，字段包含规范化后的有效区间。

<a id="member-gfaudioplaybackregion-methods-prepare_stream"></a>

### `prepare_stream`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func prepare_stream(stream: AudioStream) -> GFAudioPlaybackRegionResult:
```

为当前音频流准备 session 私有副本。 WAV 支持帧级 forward / ping-pong 循环点；IMA ADPCM WAV 仅接受从 0 秒开始的正向循环。Godot 原生 backward 无法保持本契约的初始播放位置， 因此本地路径显式返回 UNSUPPORTED。 Ogg Vorbis 与 MP3 仅接受正向循环到自然结尾；AudioStreamPlaylist 仅接受 全流正向循环。其他流必须由显式后端能力协议处理。

参数：

| 名称 | 说明 |
|---|---|
| `stream` | 要准备的源音频流；不会被修改。 |

返回：流准备结果；成功时状态为 APPLIED 且包含 session 私有副本。

<a id="member-gfaudioplaybackregion-methods-duplicate_region"></a>

### `duplicate_region`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func duplicate_region() -> GFAudioPlaybackRegion:
```

创建相同字段的独立区间资源。

返回：独立的播放区间资源。

<a id="member-gfaudioplaybackregion-methods-to_dictionary"></a>

### `to_dictionary`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func to_dictionary() -> Dictionary:
```

转换为字典。

返回：播放区间字典。

结构：

- `return`: Dictionary with start_seconds, end_seconds, loop_mode, and loop_start_seconds fields.
