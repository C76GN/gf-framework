# GFInputPlayback

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/recording/gf_input_playback.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

抽象输入录制回放器。 按时间把 GFInputRecording 中的动作值写入 GFVirtualInputSource，适合测试、 复现、教程或 AI 控制桥接。它只回放抽象动作，不模拟具体键鼠或手柄事件。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`playback_started`](#member-gfinputplayback-signals-playback_started) | `signal playback_started(recording: GFInputRecording)` |
| 信号 | [`playback_stopped`](#member-gfinputplayback-signals-playback_stopped) | `signal playback_stopped` |
| 信号 | [`playback_finished`](#member-gfinputplayback-signals-playback_finished) | `signal playback_finished` |
| 信号 | [`event_applied`](#member-gfinputplayback-signals-event_applied) | `signal event_applied(event: Dictionary)` |
| 信号 | [`loop_catch_up_limited`](#member-gfinputplayback-signals-loop_catch_up_limited) | `signal loop_catch_up_limited(deferred_seconds: float, skipped_cycles: int)` |
| 枚举 | [`LoopCatchUpPolicy`](#member-gfinputplayback-enums-loopcatchuppolicy) | `enum LoopCatchUpPolicy` |
| 属性 | [`recording`](#member-gfinputplayback-properties-recording) | `var recording: GFInputRecording = null` |
| 属性 | [`source`](#member-gfinputplayback-properties-source) | `var source: GFVirtualInputSource = null` |
| 属性 | [`speed`](#member-gfinputplayback-properties-speed) | `var speed: float = 1.0` |
| 属性 | [`loop`](#member-gfinputplayback-properties-loop) | `var loop: bool = false` |
| 属性 | [`loop_catch_up_policy`](#member-gfinputplayback-properties-loop_catch_up_policy) | `var loop_catch_up_policy: LoopCatchUpPolicy = LoopCatchUpPolicy.DEFER_EXCESS` |
| 属性 | [`max_loop_cycles_per_tick`](#member-gfinputplayback-properties-max_loop_cycles_per_tick) | `var max_loop_cycles_per_tick: int = 64:` |
| 属性 | [`respect_recorded_player_index`](#member-gfinputplayback-properties-respect_recorded_player_index) | `var respect_recorded_player_index: bool = false` |
| 属性 | [`is_playing`](#member-gfinputplayback-properties-is_playing) | `var is_playing: bool = false` |
| 属性 | [`elapsed_seconds`](#member-gfinputplayback-properties-elapsed_seconds) | `var elapsed_seconds: float = 0.0` |
| 方法 | [`start`](#member-gfinputplayback-methods-start) | `func start( next_recording: GFInputRecording, next_source: GFVirtualInputSource, restart: bool = true ) -> bool:` |
| 方法 | [`stop`](#member-gfinputplayback-methods-stop) | `func stop(clear_source: bool = false) -> void:` |
| 方法 | [`reset`](#member-gfinputplayback-methods-reset) | `func reset() -> void:` |
| 方法 | [`tick`](#member-gfinputplayback-methods-tick) | `func tick(delta: float) -> int:` |
| 方法 | [`seek`](#member-gfinputplayback-methods-seek) | `func seek(time_seconds: float) -> void:` |
| 方法 | [`is_finished`](#member-gfinputplayback-methods-is_finished) | `func is_finished() -> bool:` |
| 方法 | [`get_debug_snapshot`](#member-gfinputplayback-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfinputplayback-signals-playback_started"></a>

### `playback_started`

- API：`public`

```gdscript
signal playback_started(recording: GFInputRecording)
```

回放开始。

参数：

| 名称 | 说明 |
|---|---|
| `recording` | 回放录制。 |

<a id="member-gfinputplayback-signals-playback_stopped"></a>

### `playback_stopped`

- API：`public`

```gdscript
signal playback_stopped
```

回放停止。

<a id="member-gfinputplayback-signals-playback_finished"></a>

### `playback_finished`

- API：`public`

```gdscript
signal playback_finished
```

回放自然完成。

<a id="member-gfinputplayback-signals-event_applied"></a>

### `event_applied`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
signal event_applied(event: Dictionary)
```

一个录制事件已被应用。事件索引会先提交再同步发出本信号；handler 可以调用 start/stop/reset/seek，旧 tick 会在 handler 返回后停止，不再推进新会话。

参数：

| 名称 | 说明 |
|---|---|
| `event` | 事件副本。 |

结构：

- `event`: Dictionary，包含 time_seconds、action_id、value、player_index、source_id 和 metadata。

<a id="member-gfinputplayback-signals-loop_catch_up_limited"></a>

### `loop_catch_up_limited`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
signal loop_catch_up_limited(deferred_seconds: float, skipped_cycles: int)
```

单帧循环追赶达到预算时发出。

参数：

| 名称 | 说明 |
|---|---|
| `deferred_seconds` | 留待后续 tick 无损处理的秒数。 |
| `skipped_cycles` | 按策略显式跳过的完整周期数。 |

## 枚举

<a id="member-gfinputplayback-enums-loopcatchuppolicy"></a>

### `LoopCatchUpPolicy`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
enum LoopCatchUpPolicy {
	## 保留剩余时间，在后续 tick 继续逐事件处理。
	DEFER_EXCESS,
	## 跳过超预算的完整周期，只重建最终周期状态。
	SKIP_EXCESS_CYCLES,
}
```

循环回放超出单帧周期预算时的处理策略。

## 属性

<a id="member-gfinputplayback-properties-recording"></a>

### `recording`

- API：`public`

```gdscript
var recording: GFInputRecording = null
```

当前录制。

<a id="member-gfinputplayback-properties-source"></a>

### `source`

- API：`public`

```gdscript
var source: GFVirtualInputSource = null
```

目标虚拟输入源。

<a id="member-gfinputplayback-properties-speed"></a>

### `speed`

- API：`public`

```gdscript
var speed: float = 1.0
```

回放速度倍率。

<a id="member-gfinputplayback-properties-loop"></a>

### `loop`

- API：`public`

```gdscript
var loop: bool = false
```

到达末尾后是否循环。

<a id="member-gfinputplayback-properties-loop_catch_up_policy"></a>

### `loop_catch_up_policy`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var loop_catch_up_policy: LoopCatchUpPolicy = LoopCatchUpPolicy.DEFER_EXCESS
```

循环追赶策略。默认无损延后，不静默丢弃事件。

<a id="member-gfinputplayback-properties-max_loop_cycles_per_tick"></a>

### `max_loop_cycles_per_tick`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var max_loop_cycles_per_tick: int = 64:
```

单次 tick 最多完整推进的循环周期数。

<a id="member-gfinputplayback-properties-respect_recorded_player_index"></a>

### `respect_recorded_player_index`

- API：`public`

```gdscript
var respect_recorded_player_index: bool = false
```

为 true 时，事件带 player_index 时会写入对应玩家。

<a id="member-gfinputplayback-properties-is_playing"></a>

### `is_playing`

- API：`public`

```gdscript
var is_playing: bool = false
```

当前是否正在播放。

<a id="member-gfinputplayback-properties-elapsed_seconds"></a>

### `elapsed_seconds`

- API：`public`

```gdscript
var elapsed_seconds: float = 0.0
```

当前回放时间，单位秒。

## 方法

<a id="member-gfinputplayback-methods-start"></a>

### `start`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func start( next_recording: GFInputRecording, next_source: GFVirtualInputSource, restart: bool = true ) -> bool:
```

开始回放。每次成功调用都会创建新的回放代际；同步回调中启动的新代际不会被 旧 tick 的索引、完成状态或后续事件覆盖。

参数：

| 名称 | 说明 |
|---|---|
| `next_recording` | 要回放的录制。 |
| `next_source` | 目标虚拟输入源。 |
| `restart` | 是否从头开始。 |

返回：成功开始时返回 true。

<a id="member-gfinputplayback-methods-stop"></a>

### `stop`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func stop(clear_source: bool = false) -> void:
```

停止回放。调用会先使当前代际失效，再按需清理 source 和发出停止信号。

参数：

| 名称 | 说明 |
|---|---|
| `clear_source` | 是否清空目标虚拟输入源。 |

<a id="member-gfinputplayback-methods-reset"></a>

### `reset`

- API：`public`

```gdscript
func reset() -> void:
```

重置到起点。

<a id="member-gfinputplayback-methods-tick"></a>

### `tick`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func tick(delta: float) -> int:
```

推进回放并应用到期事件。一次调用只向进入 tick 时绑定的 recording/source 提交；同步回调改变会话或 source 后，剩余到期事件留给新会话或后续显式操作。

参数：

| 名称 | 说明 |
|---|---|
| `delta` | 时间增量，单位秒。 |

返回：本次应用的事件数量。

<a id="member-gfinputplayback-methods-seek"></a>

### `seek`

- API：`public`

```gdscript
func seek(time_seconds: float) -> void:
```

跳转到指定时间。

参数：

| 名称 | 说明 |
|---|---|
| `time_seconds` | 目标时间，单位秒。 |

<a id="member-gfinputplayback-methods-is_finished"></a>

### `is_finished`

- API：`public`

```gdscript
func is_finished() -> bool:
```

检查是否已到达末尾。

返回：到达末尾时返回 true。

<a id="member-gfinputplayback-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：调试快照。

结构：

- `return`: Dictionary，包含 is_playing、elapsed_seconds、speed、loop、respect_recorded_player_index、next_event_index、event_count 和 source_id。
