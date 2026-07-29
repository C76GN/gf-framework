# GFAudioBackend

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/audio/gf_audio_backend.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.17.0`

GFAudioUtility 的可插拔音频后端协议。 默认实现不处理任何请求。项目或扩展可继承它，把部分音频事件转交给 外部中间件、平台接口或自定义混音系统；未声明可处理的请求会回退到 Godot 默认播放器。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`capabilities`](#member-gfaudiobackend-properties-capabilities) | `var capabilities: GFAudioBackendCapability = GFAudioBackendCapability.new()` |
| 方法 | [`dispose`](#member-gfaudiobackend-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`get_host`](#member-gfaudiobackend-methods-get_host) | `func get_host() -> Object:` |
| 方法 | [`get_capabilities`](#member-gfaudiobackend-methods-get_capabilities) | `func get_capabilities() -> GFAudioBackendCapability:` |
| 方法 | [`has_capability`](#member-gfaudiobackend-methods-has_capability) | `func has_capability(capability_id: StringName) -> bool:` |
| 方法 | [`can_handle_path`](#member-gfaudiobackend-methods-can_handle_path) | `func can_handle_path(_path: String, _channel: StringName, _context: Dictionary = {}) -> bool:` |
| 方法 | [`can_handle_clip`](#member-gfaudiobackend-methods-can_handle_clip) | `func can_handle_clip(_clip: GFAudioClip, _channel: StringName, _context: Dictionary = {}) -> bool:` |
| 方法 | [`evaluate_playback_region`](#member-gfaudiobackend-methods-evaluate_playback_region) | `func evaluate_playback_region( _clip: GFAudioClip, _channel: StringName, _region: GFAudioPlaybackRegion, _context: Dictionary = {} ) -> GFAudioPlaybackRegionResult:` |
| 方法 | [`play_bgm_path`](#member-gfaudiobackend-methods-play_bgm_path) | `func play_bgm_path(_path: String, _options: Dictionary = {}) -> bool:` |
| 方法 | [`play_bgm_clip`](#member-gfaudiobackend-methods-play_bgm_clip) | `func play_bgm_clip(_clip: GFAudioClip, _options: Dictionary = {}) -> bool:` |
| 方法 | [`stop_bgm`](#member-gfaudiobackend-methods-stop_bgm) | `func stop_bgm(_fade_seconds: float = 0.0) -> bool:` |
| 方法 | [`pause_bgm`](#member-gfaudiobackend-methods-pause_bgm) | `func pause_bgm(_fade_seconds: float = 0.0) -> bool:` |
| 方法 | [`resume_bgm`](#member-gfaudiobackend-methods-resume_bgm) | `func resume_bgm(_from_position: float = -1.0, _fade_seconds: float = 0.0) -> bool:` |
| 方法 | [`seek_bgm`](#member-gfaudiobackend-methods-seek_bgm) | `func seek_bgm(_position_seconds: float) -> bool:` |
| 方法 | [`get_bgm_playback_position`](#member-gfaudiobackend-methods-get_bgm_playback_position) | `func get_bgm_playback_position() -> float:` |
| 方法 | [`is_bgm_playing`](#member-gfaudiobackend-methods-is_bgm_playing) | `func is_bgm_playing() -> bool:` |
| 方法 | [`is_bgm_paused`](#member-gfaudiobackend-methods-is_bgm_paused) | `func is_bgm_paused() -> bool:` |
| 方法 | [`play_ambient_path`](#member-gfaudiobackend-methods-play_ambient_path) | `func play_ambient_path(_path: String, _channel: StringName = &"default", _options: Dictionary = {}) -> bool:` |
| 方法 | [`play_ambient_clip`](#member-gfaudiobackend-methods-play_ambient_clip) | `func play_ambient_clip(_clip: GFAudioClip, _channel: StringName = &"default", _options: Dictionary = {}) -> bool:` |
| 方法 | [`stop_ambient`](#member-gfaudiobackend-methods-stop_ambient) | `func stop_ambient(_channel: StringName = &"default", _fade_seconds: float = 0.0) -> bool:` |
| 方法 | [`stop_all_ambient`](#member-gfaudiobackend-methods-stop_all_ambient) | `func stop_all_ambient(_fade_seconds: float = 0.0) -> bool:` |
| 方法 | [`is_ambient_playing`](#member-gfaudiobackend-methods-is_ambient_playing) | `func is_ambient_playing(_channel: StringName = &"default") -> bool:` |
| 方法 | [`play_sfx_path`](#member-gfaudiobackend-methods-play_sfx_path) | `func play_sfx_path(_path: String, _options: Dictionary = {}) -> GFAudioEmitterHandle:` |
| 方法 | [`play_sfx_clip`](#member-gfaudiobackend-methods-play_sfx_clip) | `func play_sfx_clip(_clip: GFAudioClip, _options: Dictionary = {}) -> GFAudioEmitterHandle:` |
| 方法 | [`stop_all_sfx`](#member-gfaudiobackend-methods-stop_all_sfx) | `func stop_all_sfx(_fade_seconds: float = 0.0) -> bool:` |
| 方法 | [`play_spatial_sfx_clip`](#member-gfaudiobackend-methods-play_spatial_sfx_clip) | `func play_spatial_sfx_clip( _clip: GFAudioClip, _source: Node, _follow_source: bool = false, _options: Dictionary = {} ) -> GFAudioEmitterHandle:` |
| 方法 | [`can_handle_event`](#member-gfaudiobackend-methods-can_handle_event) | `func can_handle_event(_event: GFAudioEvent, _options: Dictionary = {}) -> bool:` |
| 方法 | [`post_event`](#member-gfaudiobackend-methods-post_event) | `func post_event(_event: GFAudioEvent, _options: Dictionary = {}) -> GFAudioEmitterHandle:` |
| 方法 | [`set_parameter`](#member-gfaudiobackend-methods-set_parameter) | `func set_parameter(_parameter: GFAudioParameter) -> bool:` |
| 方法 | [`set_state`](#member-gfaudiobackend-methods-set_state) | `func set_state(_state: GFAudioState) -> bool:` |
| 方法 | [`set_switch`](#member-gfaudiobackend-methods-set_switch) | `func set_switch(_switch: GFAudioSwitch) -> bool:` |
| 方法 | [`set_bus_volume`](#member-gfaudiobackend-methods-set_bus_volume) | `func set_bus_volume(_bus_name: String, _volume_linear: float) -> bool:` |
| 方法 | [`set_bus_volume_db`](#member-gfaudiobackend-methods-set_bus_volume_db) | `func set_bus_volume_db(_bus_name: String, _volume_db: float, _transition_seconds: float = 0.0) -> bool:` |
| 方法 | [`set_bus_mute`](#member-gfaudiobackend-methods-set_bus_mute) | `func set_bus_mute(_bus_name: String, _muted: bool) -> bool:` |
| 方法 | [`set_bus_effect_property`](#member-gfaudiobackend-methods-set_bus_effect_property) | `func set_bus_effect_property( _bus_name: String, _effect_ref: Variant, _property_name: StringName, _value: Variant, _transition_seconds: float = 0.0 ) -> bool:` |
| 方法 | [`apply_mix_snapshot`](#member-gfaudiobackend-methods-apply_mix_snapshot) | `func apply_mix_snapshot(_snapshot: Dictionary, _transition_seconds: float = 0.0) -> bool:` |
| 方法 | [`get_bus_volume`](#member-gfaudiobackend-methods-get_bus_volume) | `func get_bus_volume(_bus_name: String) -> float:` |
| 方法 | [`get_bus_mute`](#member-gfaudiobackend-methods-get_bus_mute) | `func get_bus_mute(_bus_name: String) -> Variant:` |
| 方法 | [`get_debug_snapshot`](#member-gfaudiobackend-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 属性

<a id="member-gfaudiobackend-properties-capabilities"></a>

### `capabilities`

- API：`public`

```gdscript
var capabilities: GFAudioBackendCapability = GFAudioBackendCapability.new()
```

后端能力声明。

## 方法

<a id="member-gfaudiobackend-methods-dispose"></a>

### `dispose`

- API：`public`

```gdscript
func dispose() -> void:
```

释放后端状态。

<a id="member-gfaudiobackend-methods-get_host"></a>

### `get_host`

- API：`public`

```gdscript
func get_host() -> Object:
```

获取宿主音频工具。

返回：宿主对象；不存在时返回 null。

<a id="member-gfaudiobackend-methods-get_capabilities"></a>

### `get_capabilities`

- API：`public`

```gdscript
func get_capabilities() -> GFAudioBackendCapability:
```

获取后端能力声明副本。

返回：后端能力声明。

<a id="member-gfaudiobackend-methods-has_capability"></a>

### `has_capability`

- API：`public`

```gdscript
func has_capability(capability_id: StringName) -> bool:
```

检查后端是否声明了指定能力。

参数：

| 名称 | 说明 |
|---|---|
| `capability_id` | 能力标识。 |

返回：支持返回 true。

<a id="member-gfaudiobackend-methods-can_handle_path"></a>

### `can_handle_path`

- API：`public`

```gdscript
func can_handle_path(_path: String, _channel: StringName, _context: Dictionary = {}) -> bool:
```

判断后端是否可处理指定资源路径。

参数：

| 名称 | 说明 |
|---|---|
| `_path` | 音频资源路径或后端事件路径。 |
| `_channel` | 通道标识，如 bgm、sfx、ambient。 |
| `_context` | 请求上下文。 |

返回：可处理时返回 true。

结构：

- `_context`: 请求上下文 Dictionary；键和值由 GFAudioUtility 或具体后端约定。

<a id="member-gfaudiobackend-methods-can_handle_clip"></a>

### `can_handle_clip`

- API：`public`

```gdscript
func can_handle_clip(_clip: GFAudioClip, _channel: StringName, _context: Dictionary = {}) -> bool:
```

判断后端是否可处理指定音频片段。

参数：

| 名称 | 说明 |
|---|---|
| `_clip` | 音频片段配置。 |
| `_channel` | 通道标识，如 bgm、sfx、ambient。 |
| `_context` | 请求上下文。 |

返回：可处理时返回 true。

结构：

- `_context`: 请求上下文 Dictionary；键和值由 GFAudioUtility 或具体后端约定。

<a id="member-gfaudiobackend-methods-evaluate_playback_region"></a>

### `evaluate_playback_region`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func evaluate_playback_region( _clip: GFAudioClip, _channel: StringName, _region: GFAudioPlaybackRegion, _context: Dictionary = {} ) -> GFAudioPlaybackRegionResult:
```

评估后端能否精确执行一次类型化播放区间请求。 该方法必须无副作用；只有返回 `GFAudioPlaybackRegionResult.Status.APPLIED` 时，`GFAudioUtility` 才会把带区间的播放请求交给后端。

参数：

| 名称 | 说明 |
|---|---|
| `_clip` | 请求使用的会话私有片段快照。 |
| `_channel` | 通道标识，如 bgm、sfx、ambient 或 spatial_sfx。 |
| `_region` | 会话私有播放区间快照。 |
| `_context` | 请求上下文。 |

返回：逐请求能力评估；默认显式返回 unsupported。

结构：

- `_context`: 请求上下文 Dictionary；键和值由 GFAudioUtility 或具体后端约定。

<a id="member-gfaudiobackend-methods-play_bgm_path"></a>

### `play_bgm_path`

- API：`public`
- 首次版本：`3.2.0`

```gdscript
func play_bgm_path(_path: String, _options: Dictionary = {}) -> bool:
```

播放 BGM 路径。

参数：

| 名称 | 说明 |
|---|---|
| `_path` | 音频资源路径或后端事件路径。 |
| `_options` | 请求选项。 |

返回：已处理返回 true。

结构：

- `_options`: 请求选项 Dictionary；常见字段包含 volume_db、pitch_scale、fade_seconds 和 metadata。

<a id="member-gfaudiobackend-methods-play_bgm_clip"></a>

### `play_bgm_clip`

- API：`public`
- 首次版本：`3.2.0`

```gdscript
func play_bgm_clip(_clip: GFAudioClip, _options: Dictionary = {}) -> bool:
```

播放 BGM Clip。

参数：

| 名称 | 说明 |
|---|---|
| `_clip` | 音频片段配置。 |
| `_options` | 请求选项。 |

返回：已处理返回 true。

结构：

- `_options`: 请求选项 Dictionary；常见字段包含 volume_db、pitch_scale、fade_seconds、playback_region 和 metadata。

<a id="member-gfaudiobackend-methods-stop_bgm"></a>

### `stop_bgm`

- API：`public`

```gdscript
func stop_bgm(_fade_seconds: float = 0.0) -> bool:
```

停止 BGM。

参数：

| 名称 | 说明 |
|---|---|
| `_fade_seconds` | 淡出秒数。 |

返回：已处理返回 true。

<a id="member-gfaudiobackend-methods-pause_bgm"></a>

### `pause_bgm`

- API：`public`

```gdscript
func pause_bgm(_fade_seconds: float = 0.0) -> bool:
```

暂停 BGM。

参数：

| 名称 | 说明 |
|---|---|
| `_fade_seconds` | 淡出到暂停的秒数。 |

返回：已处理返回 true。

<a id="member-gfaudiobackend-methods-resume_bgm"></a>

### `resume_bgm`

- API：`public`

```gdscript
func resume_bgm(_from_position: float = -1.0, _fade_seconds: float = 0.0) -> bool:
```

恢复 BGM。

参数：

| 名称 | 说明 |
|---|---|
| `_from_position` | 大于等于 0 时从指定秒数恢复。 |
| `_fade_seconds` | 淡入秒数。 |

返回：已处理返回 true。

<a id="member-gfaudiobackend-methods-seek_bgm"></a>

### `seek_bgm`

- API：`public`

```gdscript
func seek_bgm(_position_seconds: float) -> bool:
```

跳转当前 BGM 播放位置。

参数：

| 名称 | 说明 |
|---|---|
| `_position_seconds` | 目标秒数。 |

返回：已处理返回 true。

<a id="member-gfaudiobackend-methods-get_bgm_playback_position"></a>

### `get_bgm_playback_position`

- API：`public`

```gdscript
func get_bgm_playback_position() -> float:
```

获取当前 BGM 播放位置。

返回：播放秒数；负数表示后端不处理该查询。

<a id="member-gfaudiobackend-methods-is_bgm_playing"></a>

### `is_bgm_playing`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func is_bgm_playing() -> bool:
```

查询 BGM session 是否仍存在。 暂停中的 BGM 仍应返回 true；接管 BGM 的项目后端必须覆写该方法。

返回：BGM 正在播放或暂停时返回 true；默认 fail closed 返回 false。

<a id="member-gfaudiobackend-methods-is_bgm_paused"></a>

### `is_bgm_paused`

- API：`public`

```gdscript
func is_bgm_paused() -> bool:
```

查询 BGM 是否暂停。

返回：已暂停返回 true。

<a id="member-gfaudiobackend-methods-play_ambient_path"></a>

### `play_ambient_path`

- API：`public`

```gdscript
func play_ambient_path(_path: String, _channel: StringName = &"default", _options: Dictionary = {}) -> bool:
```

播放环境音路径。

参数：

| 名称 | 说明 |
|---|---|
| `_path` | 音频资源路径或后端事件路径。 |
| `_channel` | 环境音通道。 |
| `_options` | 请求选项。 |

返回：已处理返回 true。

结构：

- `_options`: 请求选项 Dictionary；常见字段包含 volume_db、pitch_scale、fade_seconds 和 metadata。

<a id="member-gfaudiobackend-methods-play_ambient_clip"></a>

### `play_ambient_clip`

- API：`public`
- 首次版本：`3.2.0`

```gdscript
func play_ambient_clip(_clip: GFAudioClip, _channel: StringName = &"default", _options: Dictionary = {}) -> bool:
```

播放环境音 Clip。

参数：

| 名称 | 说明 |
|---|---|
| `_clip` | 音频片段配置。 |
| `_channel` | 环境音通道。 |
| `_options` | 请求选项。 |

返回：已处理返回 true。

结构：

- `_options`: 请求选项 Dictionary；常见字段包含 volume_db、pitch_scale、fade_seconds、playback_region 和 metadata。

<a id="member-gfaudiobackend-methods-stop_ambient"></a>

### `stop_ambient`

- API：`public`

```gdscript
func stop_ambient(_channel: StringName = &"default", _fade_seconds: float = 0.0) -> bool:
```

停止环境音通道。

参数：

| 名称 | 说明 |
|---|---|
| `_channel` | 环境音通道。 |
| `_fade_seconds` | 淡出秒数。 |

返回：已处理返回 true。

<a id="member-gfaudiobackend-methods-stop_all_ambient"></a>

### `stop_all_ambient`

- API：`public`

```gdscript
func stop_all_ambient(_fade_seconds: float = 0.0) -> bool:
```

停止全部环境音。

参数：

| 名称 | 说明 |
|---|---|
| `_fade_seconds` | 淡出秒数。 |

返回：已处理返回 true。

<a id="member-gfaudiobackend-methods-is_ambient_playing"></a>

### `is_ambient_playing`

- API：`public`

```gdscript
func is_ambient_playing(_channel: StringName = &"default") -> bool:
```

查询环境音通道是否播放中。

参数：

| 名称 | 说明 |
|---|---|
| `_channel` | 环境音通道。 |

返回：后端通道正在播放时返回 true。

<a id="member-gfaudiobackend-methods-play_sfx_path"></a>

### `play_sfx_path`

- API：`public`

```gdscript
func play_sfx_path(_path: String, _options: Dictionary = {}) -> GFAudioEmitterHandle:
```

播放 SFX 路径。

参数：

| 名称 | 说明 |
|---|---|
| `_path` | 音频资源路径或后端事件路径。 |
| `_options` | 请求选项。 |

返回：控制句柄；未处理返回 null。

结构：

- `_options`: 请求选项 Dictionary；常见字段包含 volume_db、pitch_scale、owner、channel 和 metadata。

<a id="member-gfaudiobackend-methods-play_sfx_clip"></a>

### `play_sfx_clip`

- API：`public`
- 首次版本：`3.2.0`

```gdscript
func play_sfx_clip(_clip: GFAudioClip, _options: Dictionary = {}) -> GFAudioEmitterHandle:
```

播放 SFX Clip。

参数：

| 名称 | 说明 |
|---|---|
| `_clip` | 音频片段配置。 |
| `_options` | 请求选项。 |

返回：控制句柄；未处理返回 null。

结构：

- `_options`: 请求选项 Dictionary；常见字段包含 volume_db、pitch_scale、owner、channel、playback_region 和 metadata。

<a id="member-gfaudiobackend-methods-stop_all_sfx"></a>

### `stop_all_sfx`

- API：`public`

```gdscript
func stop_all_sfx(_fade_seconds: float = 0.0) -> bool:
```

停止全部 SFX。

参数：

| 名称 | 说明 |
|---|---|
| `_fade_seconds` | 淡出秒数。 |

返回：已处理返回 true。

<a id="member-gfaudiobackend-methods-play_spatial_sfx_clip"></a>

### `play_spatial_sfx_clip`

- API：`public`
- 首次版本：`3.2.0`

```gdscript
func play_spatial_sfx_clip( _clip: GFAudioClip, _source: Node, _follow_source: bool = false, _options: Dictionary = {} ) -> GFAudioEmitterHandle:
```

播放空间 SFX Clip。

参数：

| 名称 | 说明 |
|---|---|
| `_clip` | 音频片段配置。 |
| `_source` | 2D 或 3D 声源节点。 |
| `_follow_source` | 是否跟随声源。 |
| `_options` | 请求选项。 |

返回：控制句柄；未处理返回 null。

结构：

- `_options`: 请求选项 Dictionary；常见字段包含 volume_db、pitch_scale、owner、channel、follow_source、spatial_settings、playback_region 和 metadata。

<a id="member-gfaudiobackend-methods-can_handle_event"></a>

### `can_handle_event`

- API：`public`

```gdscript
func can_handle_event(_event: GFAudioEvent, _options: Dictionary = {}) -> bool:
```

判断后端是否可处理资源化音频事件。

参数：

| 名称 | 说明 |
|---|---|
| `_event` | 音频事件。 |
| `_options` | 请求选项。 |

返回：可处理时返回 true。

结构：

- `_options`: 请求选项 Dictionary；键和值由 GFAudioUtility 或具体后端约定。

<a id="member-gfaudiobackend-methods-post_event"></a>

### `post_event`

- API：`public`
- 首次版本：`3.3.0`

```gdscript
func post_event(_event: GFAudioEvent, _options: Dictionary = {}) -> GFAudioEmitterHandle:
```

发布资源化音频事件。

参数：

| 名称 | 说明 |
|---|---|
| `_event` | 音频事件。 |
| `_options` | 请求选项。 |

返回：控制句柄；未处理返回 null，GFAudioUtility 会继续本地回退。已处理但不暴露原生播放器时仍须返回非 null 句柄。

结构：

- `_options`: 请求选项 Dictionary；键和值由 GFAudioUtility 或具体后端约定。

<a id="member-gfaudiobackend-methods-set_parameter"></a>

### `set_parameter`

- API：`public`

```gdscript
func set_parameter(_parameter: GFAudioParameter) -> bool:
```

设置音频参数。

参数：

| 名称 | 说明 |
|---|---|
| `_parameter` | 参数请求。 |

返回：已处理返回 true。

<a id="member-gfaudiobackend-methods-set_state"></a>

### `set_state`

- API：`public`

```gdscript
func set_state(_state: GFAudioState) -> bool:
```

设置音频状态。

参数：

| 名称 | 说明 |
|---|---|
| `_state` | 状态请求。 |

返回：已处理返回 true。

<a id="member-gfaudiobackend-methods-set_switch"></a>

### `set_switch`

- API：`public`

```gdscript
func set_switch(_switch: GFAudioSwitch) -> bool:
```

设置音频开关。

参数：

| 名称 | 说明 |
|---|---|
| `_switch` | 开关请求。 |

返回：已处理返回 true。

<a id="member-gfaudiobackend-methods-set_bus_volume"></a>

### `set_bus_volume`

- API：`public`

```gdscript
func set_bus_volume(_bus_name: String, _volume_linear: float) -> bool:
```

设置总线音量。

参数：

| 名称 | 说明 |
|---|---|
| `_bus_name` | 总线名或后端通道名。 |
| `_volume_linear` | 线性音量。 |

返回：已处理返回 true。

<a id="member-gfaudiobackend-methods-set_bus_volume_db"></a>

### `set_bus_volume_db`

- API：`public`

```gdscript
func set_bus_volume_db(_bus_name: String, _volume_db: float, _transition_seconds: float = 0.0) -> bool:
```

设置总线 dB 音量。

参数：

| 名称 | 说明 |
|---|---|
| `_bus_name` | 总线名或后端通道名。 |
| `_volume_db` | dB 音量。 |
| `_transition_seconds` | 平滑过渡秒数。 |

返回：已处理返回 true。

<a id="member-gfaudiobackend-methods-set_bus_mute"></a>

### `set_bus_mute`

- API：`public`

```gdscript
func set_bus_mute(_bus_name: String, _muted: bool) -> bool:
```

设置总线静音状态。

参数：

| 名称 | 说明 |
|---|---|
| `_bus_name` | 总线名或后端通道名。 |
| `_muted` | 是否静音。 |

返回：已处理返回 true。

<a id="member-gfaudiobackend-methods-set_bus_effect_property"></a>

### `set_bus_effect_property`

- API：`public`

```gdscript
func set_bus_effect_property( _bus_name: String, _effect_ref: Variant, _property_name: StringName, _value: Variant, _transition_seconds: float = 0.0 ) -> bool:
```

设置总线效果属性。

参数：

| 名称 | 说明 |
|---|---|
| `_bus_name` | 总线名或后端通道名。 |
| `_effect_ref` | 效果索引、名称或后端自定义效果引用。 |
| `_property_name` | 效果属性名。 |
| `_value` | 属性值。 |
| `_transition_seconds` | 平滑过渡秒数。 |

返回：已处理返回 true。

结构：

- `_effect_ref`: int/String/StringName 或后端自定义引用。
- `_value`: 属性值 Variant；键和值由后端或 GFAudioUtility 约定。

<a id="member-gfaudiobackend-methods-apply_mix_snapshot"></a>

### `apply_mix_snapshot`

- API：`public`

```gdscript
func apply_mix_snapshot(_snapshot: Dictionary, _transition_seconds: float = 0.0) -> bool:
```

应用混音快照。

参数：

| 名称 | 说明 |
|---|---|
| `_snapshot` | 混音快照。 |
| `_transition_seconds` | 默认平滑过渡秒数。 |

返回：已处理返回 true。

结构：

- `_snapshot`: Dictionary，可包含 buses 和 effects 字段，或后端自定义字段。

<a id="member-gfaudiobackend-methods-get_bus_volume"></a>

### `get_bus_volume`

- API：`public`

```gdscript
func get_bus_volume(_bus_name: String) -> float:
```

获取总线音量。返回负数表示未处理。

参数：

| 名称 | 说明 |
|---|---|
| `_bus_name` | 总线名或后端通道名。 |

返回：线性音量；负数表示后端不处理该总线。

<a id="member-gfaudiobackend-methods-get_bus_mute"></a>

### `get_bus_mute`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_bus_mute(_bus_name: String) -> Variant:
```

获取总线静音状态。

参数：

| 名称 | 说明 |
|---|---|
| `_bus_name` | 总线名或后端通道名。 |

返回：已处理时返回 bool；无法观测该总线时返回 null。

结构：

- `return`: bool 或 null；null 表示后端不处理该总线的静音查询。

<a id="member-gfaudiobackend-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取后端调试快照。

返回：调试数据。

结构：

- `return`: 调试快照 Dictionary；键和值由具体后端约定。
