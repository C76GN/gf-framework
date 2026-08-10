# GFAudioUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/audio/gf_audio_utility.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

全局音频管理器。 管理 BGM 和 SFX 的播放与音量。 注册 GFObjectPoolUtility 时会复用 AudioStreamPlayer，未注册时使用普通播放器。 支持通过 GFAssetUtility 异步加载音频资源。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`bgm_finished`](#member-gfaudioutility-signals-bgm_finished) | `signal bgm_finished(history_key: String)` |
| 信号 | [`playback_region_rejected`](#member-gfaudioutility-signals-playback_region_rejected) | `signal playback_region_rejected(channel: StringName, reason: StringName)` |
| 枚举 | [`SFXOverflowPolicy`](#member-gfaudioutility-enums-sfxoverflowpolicy) | `enum SFXOverflowPolicy` |
| 常量 | [`BGM_BUS_NAME`](#member-gfaudioutility-constants-bgm_bus_name) | `const BGM_BUS_NAME: String = "BGM"` |
| 常量 | [`SFX_BUS_NAME`](#member-gfaudioutility-constants-sfx_bus_name) | `const SFX_BUS_NAME: String = "SFX"` |
| 常量 | [`SILENCE_VOLUME_DB`](#member-gfaudioutility-constants-silence_volume_db) | `const SILENCE_VOLUME_DB: float = -80.0` |
| 属性 | [`max_sfx_players`](#member-gfaudioutility-properties-max_sfx_players) | `var max_sfx_players: int = 32` |
| 属性 | [`max_idle_ambient_players`](#member-gfaudioutility-properties-max_idle_ambient_players) | `var max_idle_ambient_players: int = 16:` |
| 属性 | [`sfx_overflow_policy`](#member-gfaudioutility-properties-sfx_overflow_policy) | `var sfx_overflow_policy: SFXOverflowPolicy = SFXOverflowPolicy.SKIP_NEW` |
| 属性 | [`bgm_crossfade_seconds`](#member-gfaudioutility-properties-bgm_crossfade_seconds) | `var bgm_crossfade_seconds: float = 0.0` |
| 属性 | [`max_bgm_history`](#member-gfaudioutility-properties-max_bgm_history) | `var max_bgm_history: int = 16` |
| 方法 | [`init`](#member-gfaudioutility-methods-init) | `func init() -> void:` |
| 方法 | [`dispose`](#member-gfaudioutility-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`play_bgm`](#member-gfaudioutility-methods-play_bgm) | `func play_bgm(path: String, crossfade_seconds: float = -1.0) -> void:` |
| 方法 | [`play_bgm_with_options`](#member-gfaudioutility-methods-play_bgm_with_options) | `func play_bgm_with_options(path: String, options: Dictionary = {}) -> void:` |
| 方法 | [`play_bgm_clip`](#member-gfaudioutility-methods-play_bgm_clip) | `func play_bgm_clip(clip: GFAudioClip, crossfade_seconds: float = -1.0) -> void:` |
| 方法 | [`play_bgm_from_bank`](#member-gfaudioutility-methods-play_bgm_from_bank) | `func play_bgm_from_bank(bank: GFAudioBank, clip_id: StringName, crossfade_seconds: float = -1.0) -> void:` |
| 方法 | [`play_bgm_event`](#member-gfaudioutility-methods-play_bgm_event) | `func play_bgm_event( event_id: StringName, bank_id: StringName = &"", crossfade_seconds: float = -1.0 ) -> void:` |
| 方法 | [`stop_bgm`](#member-gfaudioutility-methods-stop_bgm) | `func stop_bgm(fade_seconds: float = 0.0) -> void:` |
| 方法 | [`pause_bgm`](#member-gfaudioutility-methods-pause_bgm) | `func pause_bgm(fade_seconds: float = 0.0) -> bool:` |
| 方法 | [`resume_bgm`](#member-gfaudioutility-methods-resume_bgm) | `func resume_bgm(from_position: float = -1.0, fade_seconds: float = 0.0) -> bool:` |
| 方法 | [`seek_bgm`](#member-gfaudioutility-methods-seek_bgm) | `func seek_bgm(position_seconds: float) -> bool:` |
| 方法 | [`get_bgm_playback_position`](#member-gfaudioutility-methods-get_bgm_playback_position) | `func get_bgm_playback_position() -> float:` |
| 方法 | [`is_bgm_playing`](#member-gfaudioutility-methods-is_bgm_playing) | `func is_bgm_playing() -> bool:` |
| 方法 | [`is_bgm_paused`](#member-gfaudioutility-methods-is_bgm_paused) | `func is_bgm_paused() -> bool:` |
| 方法 | [`get_bgm_history`](#member-gfaudioutility-methods-get_bgm_history) | `func get_bgm_history() -> PackedStringArray:` |
| 方法 | [`get_current_bgm_key`](#member-gfaudioutility-methods-get_current_bgm_key) | `func get_current_bgm_key() -> String:` |
| 方法 | [`clear_bgm_history`](#member-gfaudioutility-methods-clear_bgm_history) | `func clear_bgm_history() -> void:` |
| 方法 | [`register_audio_bank`](#member-gfaudioutility-methods-register_audio_bank) | `func register_audio_bank(bank_id: StringName, bank: GFAudioBank) -> void:` |
| 方法 | [`unregister_audio_bank`](#member-gfaudioutility-methods-unregister_audio_bank) | `func unregister_audio_bank(bank_id: StringName) -> void:` |
| 方法 | [`clear_audio_banks`](#member-gfaudioutility-methods-clear_audio_banks) | `func clear_audio_banks() -> void:` |
| 方法 | [`mount_audio_bank`](#member-gfaudioutility-methods-mount_audio_bank) | `func mount_audio_bank( bank_id: StringName, bank: GFAudioBank, restore_previous_bank: bool = true ) -> int:` |
| 方法 | [`unmount_audio_bank`](#member-gfaudioutility-methods-unmount_audio_bank) | `func unmount_audio_bank(bank_id: StringName, mount_token: int) -> bool:` |
| 方法 | [`get_audio_bank`](#member-gfaudioutility-methods-get_audio_bank) | `func get_audio_bank(bank_id: StringName) -> GFAudioBank:` |
| 方法 | [`set_audio_backend`](#member-gfaudioutility-methods-set_audio_backend) | `func set_audio_backend(backend: GFAudioBackend) -> bool:` |
| 方法 | [`get_audio_backend`](#member-gfaudioutility-methods-get_audio_backend) | `func get_audio_backend() -> GFAudioBackend:` |
| 方法 | [`clear_audio_backend`](#member-gfaudioutility-methods-clear_audio_backend) | `func clear_audio_backend(dispose_backend: bool = true) -> bool:` |
| 方法 | [`post_audio_event`](#member-gfaudioutility-methods-post_audio_event) | `func post_audio_event(event: GFAudioEvent, options: Dictionary = {}) -> GFAudioEmitterHandle:` |
| 方法 | [`set_audio_parameter`](#member-gfaudioutility-methods-set_audio_parameter) | `func set_audio_parameter(parameter: GFAudioParameter) -> bool:` |
| 方法 | [`set_audio_state`](#member-gfaudioutility-methods-set_audio_state) | `func set_audio_state(state: GFAudioState) -> bool:` |
| 方法 | [`set_audio_switch`](#member-gfaudioutility-methods-set_audio_switch) | `func set_audio_switch(audio_switch: GFAudioSwitch) -> bool:` |
| 方法 | [`play_ambient`](#member-gfaudioutility-methods-play_ambient) | `func play_ambient(path: String, channel: StringName = &"default", fade_seconds: float = 0.0) -> void:` |
| 方法 | [`play_ambient_clip`](#member-gfaudioutility-methods-play_ambient_clip) | `func play_ambient_clip( clip: GFAudioClip, channel: StringName = &"default", fade_seconds: float = 0.0 ) -> void:` |
| 方法 | [`play_ambient_from_bank`](#member-gfaudioutility-methods-play_ambient_from_bank) | `func play_ambient_from_bank( bank: GFAudioBank, clip_id: StringName, channel: StringName = &"default", fade_seconds: float = 0.0 ) -> void:` |
| 方法 | [`play_ambient_event`](#member-gfaudioutility-methods-play_ambient_event) | `func play_ambient_event( event_id: StringName, channel: StringName = &"default", bank_id: StringName = &"", fade_seconds: float = 0.0 ) -> void:` |
| 方法 | [`stop_ambient`](#member-gfaudioutility-methods-stop_ambient) | `func stop_ambient(channel: StringName = &"default", fade_seconds: float = 0.0) -> void:` |
| 方法 | [`stop_all_ambient`](#member-gfaudioutility-methods-stop_all_ambient) | `func stop_all_ambient(fade_seconds: float = 0.0) -> void:` |
| 方法 | [`is_ambient_playing`](#member-gfaudioutility-methods-is_ambient_playing) | `func is_ambient_playing(channel: StringName = &"default") -> bool:` |
| 方法 | [`stop_all_sfx`](#member-gfaudioutility-methods-stop_all_sfx) | `func stop_all_sfx(fade_seconds: float = 0.0) -> void:` |
| 方法 | [`play_sfx`](#member-gfaudioutility-methods-play_sfx) | `func play_sfx(path: String) -> void:` |
| 方法 | [`play_sfx_handle`](#member-gfaudioutility-methods-play_sfx_handle) | `func play_sfx_handle(path: String) -> GFAudioEmitterHandle:` |
| 方法 | [`play_sfx_clip`](#member-gfaudioutility-methods-play_sfx_clip) | `func play_sfx_clip(clip: GFAudioClip) -> void:` |
| 方法 | [`play_sfx_clip_handle`](#member-gfaudioutility-methods-play_sfx_clip_handle) | `func play_sfx_clip_handle(clip: GFAudioClip) -> GFAudioEmitterHandle:` |
| 方法 | [`play_sfx_from_bank`](#member-gfaudioutility-methods-play_sfx_from_bank) | `func play_sfx_from_bank(bank: GFAudioBank, clip_id: StringName) -> void:` |
| 方法 | [`play_sfx_from_bank_handle`](#member-gfaudioutility-methods-play_sfx_from_bank_handle) | `func play_sfx_from_bank_handle(bank: GFAudioBank, clip_id: StringName) -> GFAudioEmitterHandle:` |
| 方法 | [`play_sfx_event`](#member-gfaudioutility-methods-play_sfx_event) | `func play_sfx_event(event_id: StringName, bank_id: StringName = &"") -> void:` |
| 方法 | [`play_sfx_event_handle`](#member-gfaudioutility-methods-play_sfx_event_handle) | `func play_sfx_event_handle(event_id: StringName, bank_id: StringName = &"") -> GFAudioEmitterHandle:` |
| 方法 | [`play_sfx_event_2d`](#member-gfaudioutility-methods-play_sfx_event_2d) | `func play_sfx_event_2d( event_id: StringName, source: Node2D, bank_id: StringName = &"", follow_source: bool = false ) -> AudioStreamPlayer2D:` |
| 方法 | [`play_sfx_event_2d_handle`](#member-gfaudioutility-methods-play_sfx_event_2d_handle) | `func play_sfx_event_2d_handle( event_id: StringName, source: Node2D, bank_id: StringName = &"", follow_source: bool = false ) -> GFAudioEmitterHandle:` |
| 方法 | [`play_sfx_event_3d`](#member-gfaudioutility-methods-play_sfx_event_3d) | `func play_sfx_event_3d( event_id: StringName, source: Node3D, bank_id: StringName = &"", follow_source: bool = false ) -> AudioStreamPlayer3D:` |
| 方法 | [`play_sfx_event_3d_handle`](#member-gfaudioutility-methods-play_sfx_event_3d_handle) | `func play_sfx_event_3d_handle( event_id: StringName, source: Node3D, bank_id: StringName = &"", follow_source: bool = false ) -> GFAudioEmitterHandle:` |
| 方法 | [`play_sfx_clip_2d`](#member-gfaudioutility-methods-play_sfx_clip_2d) | `func play_sfx_clip_2d( clip: GFAudioClip, source: Node2D, follow_source: bool = false ) -> AudioStreamPlayer2D:` |
| 方法 | [`play_sfx_clip_2d_handle`](#member-gfaudioutility-methods-play_sfx_clip_2d_handle) | `func play_sfx_clip_2d_handle( clip: GFAudioClip, source: Node2D, follow_source: bool = false ) -> GFAudioEmitterHandle:` |
| 方法 | [`play_sfx_clip_3d`](#member-gfaudioutility-methods-play_sfx_clip_3d) | `func play_sfx_clip_3d( clip: GFAudioClip, source: Node3D, follow_source: bool = false ) -> AudioStreamPlayer3D:` |
| 方法 | [`play_sfx_clip_3d_handle`](#member-gfaudioutility-methods-play_sfx_clip_3d_handle) | `func play_sfx_clip_3d_handle( clip: GFAudioClip, source: Node3D, follow_source: bool = false ) -> GFAudioEmitterHandle:` |
| 方法 | [`get_ambient_handle`](#member-gfaudioutility-methods-get_ambient_handle) | `func get_ambient_handle(channel: StringName = &"default") -> GFAudioEmitterHandle:` |
| 方法 | [`set_bus_volume_db`](#member-gfaudioutility-methods-set_bus_volume_db) | `func set_bus_volume_db(bus_name: String, volume_db: float, transition_seconds: float = 0.0) -> bool:` |
| 方法 | [`get_bus_volume_db`](#member-gfaudioutility-methods-get_bus_volume_db) | `func get_bus_volume_db(bus_name: String) -> float:` |
| 方法 | [`set_bus_mute`](#member-gfaudioutility-methods-set_bus_mute) | `func set_bus_mute(bus_name: String, muted: bool) -> bool:` |
| 方法 | [`set_bus_effect_property`](#member-gfaudioutility-methods-set_bus_effect_property) | `func set_bus_effect_property( bus_name: String, effect_ref: Variant, property_name: StringName, value: Variant, transition_seconds: float = 0.0 ) -> bool:` |
| 方法 | [`capture_mix_snapshot`](#member-gfaudioutility-methods-capture_mix_snapshot) | `func capture_mix_snapshot(bus_names: PackedStringArray = PackedStringArray()) -> Dictionary:` |
| 方法 | [`apply_mix_snapshot`](#member-gfaudioutility-methods-apply_mix_snapshot) | `func apply_mix_snapshot(snapshot: Dictionary, transition_seconds: float = 0.0) -> Dictionary:` |
| 方法 | [`duck_bus`](#member-gfaudioutility-methods-duck_bus) | `func duck_bus( bus_name: String = BGM_BUS_NAME, amount: float = 0.5, transition_seconds: float = 0.25, duck_id: StringName = &"default" ) -> bool:` |
| 方法 | [`restore_ducked_bus`](#member-gfaudioutility-methods-restore_ducked_bus) | `func restore_ducked_bus( bus_name: String = BGM_BUS_NAME, transition_seconds: float = 0.25, duck_id: StringName = &"default" ) -> bool:` |
| 方法 | [`set_bus_volume`](#member-gfaudioutility-methods-set_bus_volume) | `func set_bus_volume(bus_name: String, volume_linear: float) -> void:` |
| 方法 | [`get_bus_volume`](#member-gfaudioutility-methods-get_bus_volume) | `func get_bus_volume(bus_name: String) -> float:` |
| 方法 | [`get_debug_snapshot`](#member-gfaudioutility-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |
| 方法 | [`get_last_playback_region_rejection`](#member-gfaudioutility-methods-get_last_playback_region_rejection) | `func get_last_playback_region_rejection() -> Dictionary:` |

## 信号

<a id="member-gfaudioutility-signals-bgm_finished"></a>

### `bgm_finished`

- API：`public`

```gdscript
signal bgm_finished(history_key: String)
```

当前 BGM 自然播放结束时发出。

参数：

| 名称 | 说明 |
|---|---|
| `history_key` | 播放请求记录的 BGM key。 |

<a id="member-gfaudioutility-signals-playback_region_rejected"></a>

### `playback_region_rejected`

- API：`public`
- 首次版本：`unreleased`

```gdscript
signal playback_region_rejected(channel: StringName, reason: StringName)
```

类型化播放区间因请求非法或当前后端/音频流无法精确执行而被拒绝时发出。

参数：

| 名称 | 说明 |
|---|---|
| `channel` | 被拒绝请求的通道。 |
| `reason` | 稳定拒绝原因。 |

## 枚举

<a id="member-gfaudioutility-enums-sfxoverflowpolicy"></a>

### `SFXOverflowPolicy`

- API：`public`

```gdscript
enum SFXOverflowPolicy {
	## 跳过新的 SFX 请求。
	SKIP_NEW,
	## 停止最早播放的 SFX，并播放新的请求。
	STOP_OLDEST,
}
```

SFX 超出并发上限时的处理策略。

## 常量

<a id="member-gfaudioutility-constants-bgm_bus_name"></a>

### `BGM_BUS_NAME`

- API：`public`

```gdscript
const BGM_BUS_NAME: String = "BGM"
```

默认 BGM 音频总线名。

<a id="member-gfaudioutility-constants-sfx_bus_name"></a>

### `SFX_BUS_NAME`

- API：`public`

```gdscript
const SFX_BUS_NAME: String = "SFX"
```

默认 SFX 音频总线名。

<a id="member-gfaudioutility-constants-silence_volume_db"></a>

### `SILENCE_VOLUME_DB`

- API：`public`

```gdscript
const SILENCE_VOLUME_DB: float = -80.0
```

GF 默认视为静音下限的 dB 值。

## 属性

<a id="member-gfaudioutility-properties-max_sfx_players"></a>

### `max_sfx_players`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var max_sfx_players: int = 32
```

普通与空间 SFX 共用的并发播放数量上限；小于等于 0 表示不限制。

<a id="member-gfaudioutility-properties-max_idle_ambient_players"></a>

### `max_idle_ambient_players`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var max_idle_ambient_players: int = 16:
```

已停止环境音播放器的最大空闲缓存数量；0 表示停止后立即释放。 活动本地会话和 backend-owned 会话不计入此空闲缓存。

<a id="member-gfaudioutility-properties-sfx_overflow_policy"></a>

### `sfx_overflow_policy`

- API：`public`

```gdscript
var sfx_overflow_policy: SFXOverflowPolicy = SFXOverflowPolicy.SKIP_NEW
```

SFX 超出并发上限时采用的处理策略。

<a id="member-gfaudioutility-properties-bgm_crossfade_seconds"></a>

### `bgm_crossfade_seconds`

- API：`public`

```gdscript
var bgm_crossfade_seconds: float = 0.0
```

默认 BGM 淡入淡出秒数。单次播放传入负数时使用该值。

<a id="member-gfaudioutility-properties-max_bgm_history"></a>

### `max_bgm_history`

- API：`public`

```gdscript
var max_bgm_history: int = 16
```

BGM 历史记录最大数量。

## 方法

<a id="member-gfaudioutility-methods-init"></a>

### `init`

- API：`public`

```gdscript
func init() -> void:
```

初始化音频播放器、运行时状态和默认播放根节点。

<a id="member-gfaudioutility-methods-dispose"></a>

### `dispose`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func dispose() -> void:
```

释放播放器、后端、环境音和 SFX 运行时状态。 后端拒绝停止时会记录 warning，但生命周期仍会强制收敛为终态。

<a id="member-gfaudioutility-methods-play_bgm"></a>

### `play_bgm`

- API：`public`

```gdscript
func play_bgm(path: String, crossfade_seconds: float = -1.0) -> void:
```

播放 BGM（背景音乐）

参数：

| 名称 | 说明 |
|---|---|
| `path` | 音频资源的路径 |
| `crossfade_seconds` | 淡入淡出秒数；小于 0 时使用默认值。 |

<a id="member-gfaudioutility-methods-play_bgm_with_options"></a>

### `play_bgm_with_options`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func play_bgm_with_options(path: String, options: Dictionary = {}) -> void:
```

使用选项播放 BGM。每次请求创建新会话；异步加载、淡变与 finished 回调只可提交所属会话。 loop 与 playback_region 是保留键，必须通过 GFAudioClip.playback_region 表达。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 音频资源路径或后端事件路径。 |
| `options` | 支持 crossfade_seconds、history_key、bus_name、volume_db 和 pitch_scale； |

结构：

- `options`: Dictionary，可包含 crossfade_seconds、history_key、bus_name、volume_db 和 pitch_scale 字段；不得包含 loop 或 playback_region。

<a id="member-gfaudioutility-methods-play_bgm_clip"></a>

### `play_bgm_clip`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func play_bgm_clip(clip: GFAudioClip, crossfade_seconds: float = -1.0) -> void:
```

播放资源化 BGM 配置。后端与本地播放器按请求结果原子交接唯一通道所有权。

参数：

| 名称 | 说明 |
|---|---|
| `clip` | 音频片段配置。 |
| `crossfade_seconds` | 淡入淡出秒数；小于 0 时使用默认值。 |

<a id="member-gfaudioutility-methods-play_bgm_from_bank"></a>

### `play_bgm_from_bank`

- API：`public`

```gdscript
func play_bgm_from_bank(bank: GFAudioBank, clip_id: StringName, crossfade_seconds: float = -1.0) -> void:
```

从音频集合播放 BGM。

参数：

| 名称 | 说明 |
|---|---|
| `bank` | 音频集合。 |
| `clip_id` | 片段标识。 |
| `crossfade_seconds` | 淡入淡出秒数；小于 0 时使用默认值。 |

<a id="member-gfaudioutility-methods-play_bgm_event"></a>

### `play_bgm_event`

- API：`public`

```gdscript
func play_bgm_event( event_id: StringName, bank_id: StringName = &"", crossfade_seconds: float = -1.0 ) -> void:
```

按事件 ID 播放注册音频集合中的 BGM。

参数：

| 名称 | 说明 |
|---|---|
| `event_id` | 音频事件标识。 |
| `bank_id` | 音频集合标识；为空时搜索全部注册集合。 |
| `crossfade_seconds` | 淡入淡出秒数；小于 0 时使用默认值。 |

<a id="member-gfaudioutility-methods-stop_bgm"></a>

### `stop_bgm`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func stop_bgm(fade_seconds: float = 0.0) -> void:
```

停止当前 BGM。淡出只绑定当前会话，后续替换会使旧完成回调失效。

参数：

| 名称 | 说明 |
|---|---|
| `fade_seconds` | 淡出秒数。 |

<a id="member-gfaudioutility-methods-pause_bgm"></a>

### `pause_bgm`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func pause_bgm(fade_seconds: float = 0.0) -> bool:
```

暂停当前 BGM。仅 playing 状态可进入 pausing/paused，非法重复操作返回 false。

参数：

| 名称 | 说明 |
|---|---|
| `fade_seconds` | 淡出到暂停的秒数。 |

返回：成功暂停或后端已处理时返回 true。

<a id="member-gfaudioutility-methods-resume_bgm"></a>

### `resume_bgm`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func resume_bgm(from_position: float = -1.0, fade_seconds: float = 0.0) -> bool:
```

恢复当前 BGM。仅 paused 或尚未完成的 pausing 状态可恢复，已停止会话不会被复活。

参数：

| 名称 | 说明 |
|---|---|
| `from_position` | 大于等于 0 时从指定秒数恢复。 |
| `fade_seconds` | 淡入秒数。 |

返回：成功恢复或后端已处理时返回 true。

<a id="member-gfaudioutility-methods-seek_bgm"></a>

### `seek_bgm`

- API：`public`

```gdscript
func seek_bgm(position_seconds: float) -> bool:
```

跳转当前 BGM 播放位置。

参数：

| 名称 | 说明 |
|---|---|
| `position_seconds` | 目标秒数。 |

返回：成功跳转或后端已处理时返回 true。

<a id="member-gfaudioutility-methods-get_bgm_playback_position"></a>

### `get_bgm_playback_position`

- API：`public`

```gdscript
func get_bgm_playback_position() -> float:
```

获取当前 BGM 播放位置。

返回：当前播放秒数；无可查询播放器时返回 0。

<a id="member-gfaudioutility-methods-is_bgm_playing"></a>

### `is_bgm_playing`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func is_bgm_playing() -> bool:
```

查询当前 BGM session 是否仍存在。暂停中的 BGM 仍视为 playing。 backend-owned 会话会查询后端，并在稳定 identity 下提交自然结束终态。

返回：当前 BGM 正在播放、淡变或暂停时返回 true。

<a id="member-gfaudioutility-methods-is_bgm_paused"></a>

### `is_bgm_paused`

- API：`public`

```gdscript
func is_bgm_paused() -> bool:
```

查询当前 BGM 是否暂停。

返回：暂停时返回 true。

<a id="member-gfaudioutility-methods-get_bgm_history"></a>

### `get_bgm_history`

- API：`public`

```gdscript
func get_bgm_history() -> PackedStringArray:
```

获取 BGM 播放历史。

返回：从旧到新的历史 key。

<a id="member-gfaudioutility-methods-get_current_bgm_key"></a>

### `get_current_bgm_key`

- API：`public`

```gdscript
func get_current_bgm_key() -> String:
```

获取当前 BGM key。

返回：当前 BGM key；无播放时为空。

<a id="member-gfaudioutility-methods-clear_bgm_history"></a>

### `clear_bgm_history`

- API：`public`

```gdscript
func clear_bgm_history() -> void:
```

清空 BGM 历史。

<a id="member-gfaudioutility-methods-register_audio_bank"></a>

### `register_audio_bank`

- API：`public`

```gdscript
func register_audio_bank(bank_id: StringName, bank: GFAudioBank) -> void:
```

注册一个全局音频集合，供事件式播放接口使用。

参数：

| 名称 | 说明 |
|---|---|
| `bank_id` | 音频集合标识。 |
| `bank` | 音频集合。 |

<a id="member-gfaudioutility-methods-unregister_audio_bank"></a>

### `unregister_audio_bank`

- API：`public`

```gdscript
func unregister_audio_bank(bank_id: StringName) -> void:
```

移除一个全局音频集合。

参数：

| 名称 | 说明 |
|---|---|
| `bank_id` | 音频集合标识。 |

<a id="member-gfaudioutility-methods-clear_audio_banks"></a>

### `clear_audio_banks`

- API：`public`

```gdscript
func clear_audio_banks() -> void:
```

清空全局音频集合注册表。

<a id="member-gfaudioutility-methods-mount_audio_bank"></a>

### `mount_audio_bank`

- API：`public`

```gdscript
func mount_audio_bank( bank_id: StringName, bank: GFAudioBank, restore_previous_bank: bool = true ) -> int:
```

挂载一个临时音频集合，并返回用于卸载的挂载令牌。

参数：

| 名称 | 说明 |
|---|---|
| `bank_id` | 音频集合标识。 |
| `bank` | 音频集合。 |
| `restore_previous_bank` | 卸载顶层挂载时是否恢复同 ID 的上一层音频集合。 |

返回：挂载令牌；失败时返回 0。

<a id="member-gfaudioutility-methods-unmount_audio_bank"></a>

### `unmount_audio_bank`

- API：`public`

```gdscript
func unmount_audio_bank(bank_id: StringName, mount_token: int) -> bool:
```

卸载由 mount_audio_bank() 创建的临时音频集合。

参数：

| 名称 | 说明 |
|---|---|
| `bank_id` | 音频集合标识。 |
| `mount_token` | mount_audio_bank() 返回的挂载令牌。 |

返回：找到并卸载对应挂载时返回 true。

<a id="member-gfaudioutility-methods-get_audio_bank"></a>

### `get_audio_bank`

- API：`public`

```gdscript
func get_audio_bank(bank_id: StringName) -> GFAudioBank:
```

获取全局音频集合。

参数：

| 名称 | 说明 |
|---|---|
| `bank_id` | 音频集合标识。 |

返回：音频集合；不存在时返回 null。

<a id="member-gfaudioutility-methods-set_audio_backend"></a>

### `set_audio_backend`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func set_audio_backend(backend: GFAudioBackend) -> bool:
```

设置可插拔音频后端。传入 null 时恢复默认 Godot 播放路径；替换前会停止旧后端通道， 并按原 owner 恢复、清除所有活跃 duck 作用域。

参数：

| 名称 | 说明 |
|---|---|
| `backend` | 音频后端。 |

返回：后端已设置；旧通道停止、duck 基准恢复、dispose 或 setup 未完成时返回 false。

<a id="member-gfaudioutility-methods-get_audio_backend"></a>

### `get_audio_backend`

- API：`public`

```gdscript
func get_audio_backend() -> GFAudioBackend:
```

获取当前音频后端。

返回：音频后端；未设置时返回 null。

<a id="member-gfaudioutility-methods-clear_audio_backend"></a>

### `clear_audio_backend`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func clear_audio_backend(dispose_backend: bool = true) -> bool:
```

清除当前音频后端。清除前会停止由该后端拥有的 BGM 与环境音会话， 并恢复、清除绑定当前 local/backend owner 的活跃 duck 作用域。

参数：

| 名称 | 说明 |
|---|---|
| `dispose_backend` | 是否调用后端 dispose()。 |

返回：后端已清除；通道停止、duck 基准恢复或 backend dispose 未完成时返回 false。

<a id="member-gfaudioutility-methods-post_audio_event"></a>

### `post_audio_event`

- API：`public`
- 首次版本：`3.3.0`

```gdscript
func post_audio_event(event: GFAudioEvent, options: Dictionary = {}) -> GFAudioEmitterHandle:
```

发布资源化音频事件。

参数：

| 名称 | 说明 |
|---|---|
| `event` | 音频事件资源。 |
| `options` | 请求选项；loop 与 playback_region 是保留键。 |

返回：后端或 SFX 控制句柄；本地 BGM/环境音已发布或请求失败时返回 null。

结构：

- `options`: Dictionary，作为事件请求附加选项，会与 GFAudioEvent.to_request_options() 的结果合并；不得在 options 或事件 metadata 中包含 loop 或 playback_region。

<a id="member-gfaudioutility-methods-set_audio_parameter"></a>

### `set_audio_parameter`

- API：`public`

```gdscript
func set_audio_parameter(parameter: GFAudioParameter) -> bool:
```

写入音频参数。

参数：

| 名称 | 说明 |
|---|---|
| `parameter` | 参数请求。 |

返回：后端已处理返回 true。

<a id="member-gfaudioutility-methods-set_audio_state"></a>

### `set_audio_state`

- API：`public`

```gdscript
func set_audio_state(state: GFAudioState) -> bool:
```

写入音频状态。

参数：

| 名称 | 说明 |
|---|---|
| `state` | 状态请求。 |

返回：后端已处理返回 true。

<a id="member-gfaudioutility-methods-set_audio_switch"></a>

### `set_audio_switch`

- API：`public`

```gdscript
func set_audio_switch(audio_switch: GFAudioSwitch) -> bool:
```

写入音频开关。

参数：

| 名称 | 说明 |
|---|---|
| `audio_switch` | 开关请求。 |

返回：后端已处理返回 true。

<a id="member-gfaudioutility-methods-play_ambient"></a>

### `play_ambient`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func play_ambient(path: String, channel: StringName = &"default", fade_seconds: float = 0.0) -> void:
```

播放环境音。每次替换都会先递增通道 generation，使旧加载和淡变回调失效。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 音频资源路径。 |
| `channel` | 环境音通道。 |
| `fade_seconds` | 淡入秒数。 |

<a id="member-gfaudioutility-methods-play_ambient_clip"></a>

### `play_ambient_clip`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func play_ambient_clip( clip: GFAudioClip, channel: StringName = &"default", fade_seconds: float = 0.0 ) -> void:
```

播放资源化环境音配置。每个通道在本地播放器与后端之间只保留一个 owner。

参数：

| 名称 | 说明 |
|---|---|
| `clip` | 音频片段配置。 |
| `channel` | 环境音通道。 |
| `fade_seconds` | 淡入秒数。 |

<a id="member-gfaudioutility-methods-play_ambient_from_bank"></a>

### `play_ambient_from_bank`

- API：`public`

```gdscript
func play_ambient_from_bank( bank: GFAudioBank, clip_id: StringName, channel: StringName = &"default", fade_seconds: float = 0.0 ) -> void:
```

从音频集合播放环境音。

参数：

| 名称 | 说明 |
|---|---|
| `bank` | 音频集合。 |
| `clip_id` | 片段标识。 |
| `channel` | 环境音通道。 |
| `fade_seconds` | 淡入秒数。 |

<a id="member-gfaudioutility-methods-play_ambient_event"></a>

### `play_ambient_event`

- API：`public`

```gdscript
func play_ambient_event( event_id: StringName, channel: StringName = &"default", bank_id: StringName = &"", fade_seconds: float = 0.0 ) -> void:
```

按事件 ID 播放注册音频集合中的环境音。

参数：

| 名称 | 说明 |
|---|---|
| `event_id` | 音频事件标识。 |
| `channel` | 环境音通道。 |
| `bank_id` | 音频集合标识；为空时搜索全部注册集合。 |
| `fade_seconds` | 淡入秒数。 |

<a id="member-gfaudioutility-methods-stop_ambient"></a>

### `stop_ambient`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func stop_ambient(channel: StringName = &"default", fade_seconds: float = 0.0) -> void:
```

停止指定环境音通道。淡出完成只能终结调用时绑定的通道 generation。

参数：

| 名称 | 说明 |
|---|---|
| `channel` | 环境音通道。 |
| `fade_seconds` | 淡出秒数。 |

<a id="member-gfaudioutility-methods-stop_all_ambient"></a>

### `stop_all_ambient`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func stop_all_ambient(fade_seconds: float = 0.0) -> void:
```

停止所有环境音通道。后端拥有的通道优先批量停止，失败时逐通道回退。

参数：

| 名称 | 说明 |
|---|---|
| `fade_seconds` | 淡出秒数。 |

<a id="member-gfaudioutility-methods-is_ambient_playing"></a>

### `is_ambient_playing`

- API：`public`

```gdscript
func is_ambient_playing(channel: StringName = &"default") -> bool:
```

检查环境音通道是否正在播放。

参数：

| 名称 | 说明 |
|---|---|
| `channel` | 环境音通道。 |

返回：正在播放时返回 true。

<a id="member-gfaudioutility-methods-stop_all_sfx"></a>

### `stop_all_sfx`

- API：`public`

```gdscript
func stop_all_sfx(fade_seconds: float = 0.0) -> void:
```

停止全部普通 SFX 与空间 SFX。

参数：

| 名称 | 说明 |
|---|---|
| `fade_seconds` | 淡出秒数。 |

<a id="member-gfaudioutility-methods-play_sfx"></a>

### `play_sfx`

- API：`public`

```gdscript
func play_sfx(path: String) -> void:
```

播放 SFX（音效），自动从池中分配播放器

参数：

| 名称 | 说明 |
|---|---|
| `path` | 音频资源的路径 |

<a id="member-gfaudioutility-methods-play_sfx_handle"></a>

### `play_sfx_handle`

- API：`public`

```gdscript
func play_sfx_handle(path: String) -> GFAudioEmitterHandle:
```

播放 SFX 并返回控制句柄。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 音频资源的路径。 |

返回：控制句柄；路径为空时返回 null。

<a id="member-gfaudioutility-methods-play_sfx_clip"></a>

### `play_sfx_clip`

- API：`public`

```gdscript
func play_sfx_clip(clip: GFAudioClip) -> void:
```

播放资源化 SFX 配置。

参数：

| 名称 | 说明 |
|---|---|
| `clip` | 音频片段配置。 |

<a id="member-gfaudioutility-methods-play_sfx_clip_handle"></a>

### `play_sfx_clip_handle`

- API：`public`

```gdscript
func play_sfx_clip_handle(clip: GFAudioClip) -> GFAudioEmitterHandle:
```

播放资源化 SFX 配置并返回控制句柄。

参数：

| 名称 | 说明 |
|---|---|
| `clip` | 音频片段配置。 |

返回：控制句柄；片段无播放来源时返回 null。

<a id="member-gfaudioutility-methods-play_sfx_from_bank"></a>

### `play_sfx_from_bank`

- API：`public`

```gdscript
func play_sfx_from_bank(bank: GFAudioBank, clip_id: StringName) -> void:
```

从音频集合播放 SFX。

参数：

| 名称 | 说明 |
|---|---|
| `bank` | 音频集合。 |
| `clip_id` | 片段标识。 |

<a id="member-gfaudioutility-methods-play_sfx_from_bank_handle"></a>

### `play_sfx_from_bank_handle`

- API：`public`

```gdscript
func play_sfx_from_bank_handle(bank: GFAudioBank, clip_id: StringName) -> GFAudioEmitterHandle:
```

从音频集合播放 SFX 并返回控制句柄。

参数：

| 名称 | 说明 |
|---|---|
| `bank` | 音频集合。 |
| `clip_id` | 片段标识。 |

返回：控制句柄；无法播放时返回 null。

<a id="member-gfaudioutility-methods-play_sfx_event"></a>

### `play_sfx_event`

- API：`public`

```gdscript
func play_sfx_event(event_id: StringName, bank_id: StringName = &"") -> void:
```

按事件 ID 播放注册音频集合中的 SFX。

参数：

| 名称 | 说明 |
|---|---|
| `event_id` | 音频事件标识。 |
| `bank_id` | 音频集合标识；为空时搜索全部注册集合。 |

<a id="member-gfaudioutility-methods-play_sfx_event_handle"></a>

### `play_sfx_event_handle`

- API：`public`

```gdscript
func play_sfx_event_handle(event_id: StringName, bank_id: StringName = &"") -> GFAudioEmitterHandle:
```

按事件 ID 播放注册音频集合中的 SFX 并返回控制句柄。

参数：

| 名称 | 说明 |
|---|---|
| `event_id` | 音频事件标识。 |
| `bank_id` | 音频集合标识；为空时搜索全部注册集合。 |

返回：控制句柄；无法播放时返回 null。

<a id="member-gfaudioutility-methods-play_sfx_event_2d"></a>

### `play_sfx_event_2d`

- API：`public`

```gdscript
func play_sfx_event_2d( event_id: StringName, source: Node2D, bank_id: StringName = &"", follow_source: bool = false ) -> AudioStreamPlayer2D:
```

按事件 ID 在 2D 节点位置播放注册音频集合中的 SFX。

参数：

| 名称 | 说明 |
|---|---|
| `event_id` | 音频事件标识。 |
| `source` | 2D 声源节点。 |
| `bank_id` | 音频集合标识；为空时搜索全部注册集合。 |
| `follow_source` | 为 true 时播放器会作为 source 子节点跟随移动。 |

返回：创建的播放器；无法播放时返回 null。

<a id="member-gfaudioutility-methods-play_sfx_event_2d_handle"></a>

### `play_sfx_event_2d_handle`

- API：`public`

```gdscript
func play_sfx_event_2d_handle( event_id: StringName, source: Node2D, bank_id: StringName = &"", follow_source: bool = false ) -> GFAudioEmitterHandle:
```

按事件 ID 在 2D 节点位置播放注册音频集合中的 SFX，并返回控制句柄。

参数：

| 名称 | 说明 |
|---|---|
| `event_id` | 音频事件标识。 |
| `source` | 2D 声源节点。 |
| `bank_id` | 音频集合标识；为空时搜索全部注册集合。 |
| `follow_source` | 为 true 时播放器会作为 source 子节点跟随移动。 |

返回：控制句柄；无法播放时返回 null。

<a id="member-gfaudioutility-methods-play_sfx_event_3d"></a>

### `play_sfx_event_3d`

- API：`public`

```gdscript
func play_sfx_event_3d( event_id: StringName, source: Node3D, bank_id: StringName = &"", follow_source: bool = false ) -> AudioStreamPlayer3D:
```

按事件 ID 在 3D 节点位置播放注册音频集合中的 SFX。

参数：

| 名称 | 说明 |
|---|---|
| `event_id` | 音频事件标识。 |
| `source` | 3D 声源节点。 |
| `bank_id` | 音频集合标识；为空时搜索全部注册集合。 |
| `follow_source` | 为 true 时播放器会作为 source 子节点跟随移动。 |

返回：创建的播放器；无法播放时返回 null。

<a id="member-gfaudioutility-methods-play_sfx_event_3d_handle"></a>

### `play_sfx_event_3d_handle`

- API：`public`

```gdscript
func play_sfx_event_3d_handle( event_id: StringName, source: Node3D, bank_id: StringName = &"", follow_source: bool = false ) -> GFAudioEmitterHandle:
```

按事件 ID 在 3D 节点位置播放注册音频集合中的 SFX，并返回控制句柄。

参数：

| 名称 | 说明 |
|---|---|
| `event_id` | 音频事件标识。 |
| `source` | 3D 声源节点。 |
| `bank_id` | 音频集合标识；为空时搜索全部注册集合。 |
| `follow_source` | 为 true 时播放器会作为 source 子节点跟随移动。 |

返回：控制句柄；无法播放时返回 null。

<a id="member-gfaudioutility-methods-play_sfx_clip_2d"></a>

### `play_sfx_clip_2d`

- API：`public`

```gdscript
func play_sfx_clip_2d( clip: GFAudioClip, source: Node2D, follow_source: bool = false ) -> AudioStreamPlayer2D:
```

在 2D 节点位置播放资源化 SFX 配置。

参数：

| 名称 | 说明 |
|---|---|
| `clip` | 音频片段配置。 |
| `source` | 2D 声源节点。 |
| `follow_source` | 为 true 时播放器会作为 source 子节点跟随移动。 |

返回：创建的播放器；无法播放时返回 null。

<a id="member-gfaudioutility-methods-play_sfx_clip_2d_handle"></a>

### `play_sfx_clip_2d_handle`

- API：`public`

```gdscript
func play_sfx_clip_2d_handle( clip: GFAudioClip, source: Node2D, follow_source: bool = false ) -> GFAudioEmitterHandle:
```

在 2D 节点位置播放资源化 SFX 配置，并返回控制句柄。

参数：

| 名称 | 说明 |
|---|---|
| `clip` | 音频片段配置。 |
| `source` | 2D 声源节点。 |
| `follow_source` | 为 true 时播放器会作为 source 子节点跟随移动。 |

返回：控制句柄；无法播放时返回 null。

<a id="member-gfaudioutility-methods-play_sfx_clip_3d"></a>

### `play_sfx_clip_3d`

- API：`public`

```gdscript
func play_sfx_clip_3d( clip: GFAudioClip, source: Node3D, follow_source: bool = false ) -> AudioStreamPlayer3D:
```

在 3D 节点位置播放资源化 SFX 配置。

参数：

| 名称 | 说明 |
|---|---|
| `clip` | 音频片段配置。 |
| `source` | 3D 声源节点。 |
| `follow_source` | 为 true 时播放器会作为 source 子节点跟随移动。 |

返回：创建的播放器；无法播放时返回 null。

<a id="member-gfaudioutility-methods-play_sfx_clip_3d_handle"></a>

### `play_sfx_clip_3d_handle`

- API：`public`

```gdscript
func play_sfx_clip_3d_handle( clip: GFAudioClip, source: Node3D, follow_source: bool = false ) -> GFAudioEmitterHandle:
```

在 3D 节点位置播放资源化 SFX 配置，并返回控制句柄。

参数：

| 名称 | 说明 |
|---|---|
| `clip` | 音频片段配置。 |
| `source` | 3D 声源节点。 |
| `follow_source` | 为 true 时播放器会作为 source 子节点跟随移动。 |

返回：控制句柄；无法播放时返回 null。

<a id="member-gfaudioutility-methods-get_ambient_handle"></a>

### `get_ambient_handle`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_ambient_handle(channel: StringName = &"default") -> GFAudioEmitterHandle:
```

获取环境音通道的控制句柄。句柄绑定当前播放 session，通道替换后旧句柄自动终结。

参数：

| 名称 | 说明 |
|---|---|
| `channel` | 环境音通道。 |

返回：控制句柄；通道不存在时返回 null。

<a id="member-gfaudioutility-methods-set_bus_volume_db"></a>

### `set_bus_volume_db`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func set_bus_volume_db(bus_name: String, volume_db: float, transition_seconds: float = 0.0) -> bool:
```

设置音频总线 dB 音量。增益与静音作为同一代事务提交，后发操作会使旧 tween 失效。

参数：

| 名称 | 说明 |
|---|---|
| `bus_name` | 总线名称，如 "Master", "BGM", "SFX"。 |
| `volume_db` | 目标 dB 音量；小于等于 SILENCE_VOLUME_DB 时会静音该总线。 |
| `transition_seconds` | 平滑过渡秒数；小于等于 0 时立即应用。 |

返回：成功应用或已交给后端处理时返回 true。

<a id="member-gfaudioutility-methods-get_bus_volume_db"></a>

### `get_bus_volume_db`

- API：`public`

```gdscript
func get_bus_volume_db(bus_name: String) -> float:
```

获取音频总线 dB 音量。

参数：

| 名称 | 说明 |
|---|---|
| `bus_name` | 总线名称。 |

返回：dB 音量；总线不存在时返回 SILENCE_VOLUME_DB。

<a id="member-gfaudioutility-methods-set_bus_mute"></a>

### `set_bus_mute`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func set_bus_mute(bus_name: String, muted: bool) -> bool:
```

设置音频总线静音状态，并取消同一总线上尚未提交的旧增益事务。

参数：

| 名称 | 说明 |
|---|---|
| `bus_name` | 总线名称。 |
| `muted` | 是否静音。 |

返回：成功应用或已交给后端处理时返回 true。

<a id="member-gfaudioutility-methods-set_bus_effect_property"></a>

### `set_bus_effect_property`

- API：`public`

```gdscript
func set_bus_effect_property( bus_name: String, effect_ref: Variant, property_name: StringName, value: Variant, transition_seconds: float = 0.0 ) -> bool:
```

设置音频总线效果属性。

参数：

| 名称 | 说明 |
|---|---|
| `bus_name` | 总线名称。 |
| `effect_ref` | 效果索引、resource_name、类名或类名片段。 |
| `property_name` | 要写入的效果属性名。 |
| `value` | 目标属性值。 |
| `transition_seconds` | 平滑过渡秒数；小于等于 0 时立即应用。 |

返回：成功应用或已交给后端处理时返回 true。

结构：

- `effect_ref`: int 表示效果索引；String/StringName 会匹配效果 resource_name、get_class() 或类名片段。
- `value`: 目标属性值；数值属性可按 transition_seconds 平滑过渡，其他类型会立即应用。

<a id="member-gfaudioutility-methods-capture_mix_snapshot"></a>

### `capture_mix_snapshot`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func capture_mix_snapshot(bus_names: PackedStringArray = PackedStringArray()) -> Dictionary:
```

捕获当前总线混音快照。原始增益与静音状态独立保存，静音不会覆盖增益值。

参数：

| 名称 | 说明 |
|---|---|
| `bus_names` | 要捕获的总线名；为空时捕获全部 Godot 总线。 |

返回：混音快照。

结构：

- `return`: Dictionary，包含 buses 字典；每个总线条目包含 volume_db、volume_linear 和 muted。

<a id="member-gfaudioutility-methods-apply_mix_snapshot"></a>

### `apply_mix_snapshot`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func apply_mix_snapshot(snapshot: Dictionary, transition_seconds: float = 0.0) -> Dictionary:
```

应用混音快照。先尝试 backend bulk 接管；拒绝后按字段 backend-first， 仅把明确未处理的增益或静音字段作为单个 local generation 事务回退。

参数：

| 名称 | 说明 |
|---|---|
| `snapshot` | 混音快照。 |
| `transition_seconds` | 默认平滑过渡秒数；单个效果条目可覆盖。 |

返回：应用报告。

结构：

- `snapshot`: Dictionary，可包含 buses 字典和 effects 数组；buses 条目支持数值型 volume_db 简写，或包含 volume_db、volume_linear、muted 的字典；effects 条目支持 bus、effect、property、value、transition_seconds。
- `return`: Dictionary，包含 ok、applied、failed 和 warnings 字段；backend identity 漂移、字段无本地回退目标或输入无效会进入 failed。

<a id="member-gfaudioutility-methods-duck_bus"></a>

### `duck_bus`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func duck_bus( bus_name: String = BGM_BUS_NAME, amount: float = 0.5, transition_seconds: float = 0.25, duck_id: StringName = &"default" ) -> bool:
```

按比例压低总线音量。配置 backend 时优先捕获其同名总线，并把 owner/backend identity 固定到整个作用域生命周期；否则回退本地总线。每个总线采用活跃作用域中的最强衰减。

参数：

| 名称 | 说明 |
|---|---|
| `bus_name` | 总线名称。 |
| `amount` | 压低强度，0.0 不变化，1.0 最多压低 18 dB。 |
| `transition_seconds` | 平滑过渡秒数。 |
| `duck_id` | 同一总线上的压低作用域标识。 |

返回：成功应用时返回 true；backend 只暴露部分基准字段或 owner setter 拒绝时失败关闭。

<a id="member-gfaudioutility-methods-restore_ducked_bus"></a>

### `restore_ducked_bus`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func restore_ducked_bus( bus_name: String = BGM_BUS_NAME, transition_seconds: float = 0.25, duck_id: StringName = &"default" ) -> bool:
```

释放一个 duck_bus() 作用域，并根据剩余作用域重新计算；结果与释放顺序无关。

参数：

| 名称 | 说明 |
|---|---|
| `bus_name` | 总线名称。 |
| `transition_seconds` | 平滑过渡秒数。 |
| `duck_id` | 同一总线上的压低作用域标识。 |

返回：找到恢复基准并开始恢复时返回 true。

<a id="member-gfaudioutility-methods-set_bus_volume"></a>

### `set_bus_volume`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func set_bus_volume(bus_name: String, volume_linear: float) -> void:
```

设置音频总线线性音量，并以新事务取代同一总线上的未完成过渡。

参数：

| 名称 | 说明 |
|---|---|
| `bus_name` | 总线名称，如 "Master", "BGM", "SFX" |
| `volume_linear` | 线性音量 (0.0 到 1.0) |

<a id="member-gfaudioutility-methods-get_bus_volume"></a>

### `get_bus_volume`

- API：`public`

```gdscript
func get_bus_volume(bus_name: String) -> float:
```

获取音频总线音量

参数：

| 名称 | 说明 |
|---|---|
| `bus_name` | 总线名称 |

返回：线性音量 (0.0 到 1.0)

<a id="member-gfaudioutility-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取音频工具调试快照。

返回：调试快照。

结构：

- `return`: Dictionary，包含 backend、backend_snapshot、backend_capabilities、current_bgm_key、current_bgm_region、last_playback_region_rejection、bgm_state、bgm_owner、bgm_generation、bgm_playing、bgm_paused、bgm_position、bgm_history、active_sfx_count、active_spatial_sfx_count、max_sfx_players、ambient_channels、ambient_sessions、cached_ambient_player_count、idle_ambient_player_count、max_idle_ambient_players、audio_bank_count、ducked_bus_count 和 active_mix_tween_count 字段。

<a id="member-gfaudioutility-methods-get_last_playback_region_rejection"></a>

### `get_last_playback_region_rejection`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_last_playback_region_rejection() -> Dictionary:
```

获取最近一次播放区间拒绝报告。 报告不包含资源路径、流数据、后端私有元数据或项目自定义通道值； 非框架通道统一记为 custom，拒绝信号仍携带原始调用通道。

返回：最近拒绝报告；尚无拒绝时为空字典。

结构：

- `return`: Dictionary，可包含 channel、status 和 reason 字段。
