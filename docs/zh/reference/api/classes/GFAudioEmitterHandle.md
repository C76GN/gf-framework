# GFAudioEmitterHandle

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/audio/gf_audio_emitter_handle.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`3.17.0`

一次音频播放的轻量控制句柄。 句柄只包装底层 AudioStreamPlayer 节点的通用生命周期和播放属性， 不规定音频事件、混音策略或业务含义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`player_attached`](#member-gfaudioemitterhandle-signals-player_attached) | `signal player_attached(handle: GFAudioEmitterHandle, player: Node)` |
| 信号 | [`stopped`](#member-gfaudioemitterhandle-signals-stopped) | `signal stopped(handle: GFAudioEmitterHandle)` |
| 属性 | [`channel`](#member-gfaudioemitterhandle-properties-channel) | `var channel: StringName = &""` |
| 属性 | [`metadata`](#member-gfaudioemitterhandle-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`set_player`](#member-gfaudioemitterhandle-methods-set_player) | `func set_player(player: Node) -> void:` |
| 方法 | [`set_release_callback`](#member-gfaudioemitterhandle-methods-set_release_callback) | `func set_release_callback(release_callback: Callable) -> void:` |
| 方法 | [`bind_to_owner`](#member-gfaudioemitterhandle-methods-bind_to_owner) | `func bind_to_owner(owner: Node, fade_seconds: float = 0.0) -> void:` |
| 方法 | [`unbind_owner`](#member-gfaudioemitterhandle-methods-unbind_owner) | `func unbind_owner() -> void:` |
| 方法 | [`get_player`](#member-gfaudioemitterhandle-methods-get_player) | `func get_player() -> Node:` |
| 方法 | [`is_valid`](#member-gfaudioemitterhandle-methods-is_valid) | `func is_valid() -> bool:` |
| 方法 | [`is_stop_requested`](#member-gfaudioemitterhandle-methods-is_stop_requested) | `func is_stop_requested() -> bool:` |
| 方法 | [`is_playing`](#member-gfaudioemitterhandle-methods-is_playing) | `func is_playing() -> bool:` |
| 方法 | [`stop`](#member-gfaudioemitterhandle-methods-stop) | `func stop(fade_seconds: float = 0.0) -> void:` |
| 方法 | [`fade_to`](#member-gfaudioemitterhandle-methods-fade_to) | `func fade_to(volume_db: float, fade_seconds: float) -> void:` |
| 方法 | [`set_volume_db`](#member-gfaudioemitterhandle-methods-set_volume_db) | `func set_volume_db(volume_db: float) -> void:` |
| 方法 | [`get_volume_db`](#member-gfaudioemitterhandle-methods-get_volume_db) | `func get_volume_db() -> float:` |
| 方法 | [`set_pitch_scale`](#member-gfaudioemitterhandle-methods-set_pitch_scale) | `func set_pitch_scale(pitch_scale: float) -> void:` |
| 方法 | [`get_pitch_scale`](#member-gfaudioemitterhandle-methods-get_pitch_scale) | `func get_pitch_scale() -> float:` |
| 方法 | [`get_debug_snapshot`](#member-gfaudioemitterhandle-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfaudioemitterhandle-signals-player_attached"></a>

### `player_attached`

- API：`public`

```gdscript
signal player_attached(handle: GFAudioEmitterHandle, player: Node)
```

句柄绑定到底层播放器时发出。

参数：

| 名称 | 说明 |
|---|---|
| `handle` | 当前句柄。 |
| `player` | 绑定的播放器节点。 |

<a id="member-gfaudioemitterhandle-signals-stopped"></a>

### `stopped`

- API：`public`

```gdscript
signal stopped(handle: GFAudioEmitterHandle)
```

句柄主动停止并释放绑定时发出。

参数：

| 名称 | 说明 |
|---|---|
| `handle` | 当前句柄。 |

## 属性

<a id="member-gfaudioemitterhandle-properties-channel"></a>

### `channel`

- API：`public`

```gdscript
var channel: StringName = &""
```

可选通道标识。框架不解释该字段。

<a id="member-gfaudioemitterhandle-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

项目自定义元数据。框架不解释该字段。

结构：

- `metadata`: 句柄元数据 Dictionary；键和值由调用方或后端约定。

## 方法

<a id="member-gfaudioemitterhandle-methods-set_player"></a>

### `set_player`

- API：`public`

```gdscript
func set_player(player: Node) -> void:
```

绑定底层播放器。

参数：

| 名称 | 说明 |
|---|---|
| `player` | 要绑定的播放器节点。 |

<a id="member-gfaudioemitterhandle-methods-set_release_callback"></a>

### `set_release_callback`

- API：`public`

```gdscript
func set_release_callback(release_callback: Callable) -> void:
```

设置释放回调。

参数：

| 名称 | 说明 |
|---|---|
| `release_callback` | 停止完成时调用的释放回调。 |

<a id="member-gfaudioemitterhandle-methods-bind_to_owner"></a>

### `bind_to_owner`

- API：`public`

```gdscript
func bind_to_owner(owner: Node, fade_seconds: float = 0.0) -> void:
```

绑定一个拥有者节点，节点退出树时自动停止当前播放。

参数：

| 名称 | 说明 |
|---|---|
| `owner` | 生命周期拥有者。 |
| `fade_seconds` | 自动停止时使用的淡出秒数。 |

<a id="member-gfaudioemitterhandle-methods-unbind_owner"></a>

### `unbind_owner`

- API：`public`

```gdscript
func unbind_owner() -> void:
```

取消拥有者生命周期绑定。

<a id="member-gfaudioemitterhandle-methods-get_player"></a>

### `get_player`

- API：`public`

```gdscript
func get_player() -> Node:
```

获取底层播放器。

返回：播放器节点；不存在或已释放时返回 null。

<a id="member-gfaudioemitterhandle-methods-is_valid"></a>

### `is_valid`

- API：`public`

```gdscript
func is_valid() -> bool:
```

检查句柄是否仍绑定有效播放器。

返回：有效时返回 true。

<a id="member-gfaudioemitterhandle-methods-is_stop_requested"></a>

### `is_stop_requested`

- API：`public`

```gdscript
func is_stop_requested() -> bool:
```

检查该句柄是否已经收到停止请求。

返回：已请求停止时返回 true。

<a id="member-gfaudioemitterhandle-methods-is_playing"></a>

### `is_playing`

- API：`public`

```gdscript
func is_playing() -> bool:
```

检查播放器是否正在播放。

返回：正在播放时返回 true。

<a id="member-gfaudioemitterhandle-methods-stop"></a>

### `stop`

- API：`public`

```gdscript
func stop(fade_seconds: float = 0.0) -> void:
```

停止播放；传入淡出秒数时先淡出再释放。

参数：

| 名称 | 说明 |
|---|---|
| `fade_seconds` | 淡出秒数。 |

<a id="member-gfaudioemitterhandle-methods-fade_to"></a>

### `fade_to`

- API：`public`

```gdscript
func fade_to(volume_db: float, fade_seconds: float) -> void:
```

淡入淡出到指定音量。

参数：

| 名称 | 说明 |
|---|---|
| `volume_db` | 目标音量，单位 dB。 |
| `fade_seconds` | 淡入淡出秒数。 |

<a id="member-gfaudioemitterhandle-methods-set_volume_db"></a>

### `set_volume_db`

- API：`public`

```gdscript
func set_volume_db(volume_db: float) -> void:
```

设置当前音量。

参数：

| 名称 | 说明 |
|---|---|
| `volume_db` | 音量，单位 dB。 |

<a id="member-gfaudioemitterhandle-methods-get_volume_db"></a>

### `get_volume_db`

- API：`public`

```gdscript
func get_volume_db() -> float:
```

获取当前音量。

返回：音量，单位 dB；无播放器时返回 0。

<a id="member-gfaudioemitterhandle-methods-set_pitch_scale"></a>

### `set_pitch_scale`

- API：`public`

```gdscript
func set_pitch_scale(pitch_scale: float) -> void:
```

设置当前音高。

参数：

| 名称 | 说明 |
|---|---|
| `pitch_scale` | 音高缩放。 |

<a id="member-gfaudioemitterhandle-methods-get_pitch_scale"></a>

### `get_pitch_scale`

- API：`public`

```gdscript
func get_pitch_scale() -> float:
```

获取当前音高。

返回：音高缩放；无播放器时返回 1。

<a id="member-gfaudioemitterhandle-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：调试快照。

结构：

- `return`: 调试快照 Dictionary，包含 valid、playing、channel、volume_db、pitch_scale、owner_valid 和 metadata 字段。
