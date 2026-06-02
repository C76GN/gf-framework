# GFAudioBeatClock

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/audio/gf_audio_beat_clock.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`4.2.0`

通用音频节拍时钟。 将任意播放时间映射为 beat、measure 和进度快照，并在手动 update() 时发出越过的节拍边界。 它不持有播放器、不创建节点，也不规定节奏玩法、字幕或演出语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`position_updated`](#member-gfaudiobeatclock-signals-position_updated) | `signal position_updated(snapshot: Dictionary)` |
| 信号 | [`beat_reached`](#member-gfaudiobeatclock-signals-beat_reached) | `signal beat_reached(beat_index: int, beat_in_measure: int, position_seconds: float)` |
| 信号 | [`measure_reached`](#member-gfaudiobeatclock-signals-measure_reached) | `signal measure_reached(measure_index: int, beat_index: int, position_seconds: float)` |
| 枚举 | [`QuantizeMode`](#member-gfaudiobeatclock-enums-quantizemode) | `enum QuantizeMode` |
| 常量 | [`DEFAULT_BPM`](#member-gfaudiobeatclock-constants-default_bpm) | `const DEFAULT_BPM: float = 120.0` |
| 常量 | [`DEFAULT_BEATS_PER_MEASURE`](#member-gfaudiobeatclock-constants-default_beats_per_measure) | `const DEFAULT_BEATS_PER_MEASURE: int = 4` |
| 常量 | [`DEFAULT_MAX_EMITTED_STEPS_PER_UPDATE`](#member-gfaudiobeatclock-constants-default_max_emitted_steps_per_update) | `const DEFAULT_MAX_EMITTED_STEPS_PER_UPDATE: int = 64` |
| 属性 | [`bpm`](#member-gfaudiobeatclock-properties-bpm) | `var bpm: float = DEFAULT_BPM` |
| 属性 | [`beats_per_measure`](#member-gfaudiobeatclock-properties-beats_per_measure) | `var beats_per_measure: int = DEFAULT_BEATS_PER_MEASURE` |
| 属性 | [`offset_seconds`](#member-gfaudiobeatclock-properties-offset_seconds) | `var offset_seconds: float = 0.0` |
| 属性 | [`emit_initial_events`](#member-gfaudiobeatclock-properties-emit_initial_events) | `var emit_initial_events: bool = false` |
| 属性 | [`max_emitted_steps_per_update`](#member-gfaudiobeatclock-properties-max_emitted_steps_per_update) | `var max_emitted_steps_per_update: int = DEFAULT_MAX_EMITTED_STEPS_PER_UPDATE` |
| 属性 | [`position_source`](#member-gfaudiobeatclock-properties-position_source) | `var position_source: Callable = Callable()` |
| 属性 | [`metadata`](#member-gfaudiobeatclock-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`configure`](#member-gfaudiobeatclock-methods-configure) | `func configure( next_bpm: float, next_beats_per_measure: int = DEFAULT_BEATS_PER_MEASURE, next_offset_seconds: float = 0.0, should_reset: bool = true ) -> void:` |
| 方法 | [`set_position_source`](#member-gfaudiobeatclock-methods-set_position_source) | `func set_position_source(source: Callable) -> void:` |
| 方法 | [`clear`](#member-gfaudiobeatclock-methods-clear) | `func clear() -> void:` |
| 方法 | [`reset`](#member-gfaudiobeatclock-methods-reset) | `func reset(position_seconds: float = 0.0) -> Dictionary:` |
| 方法 | [`update_from_source`](#member-gfaudiobeatclock-methods-update_from_source) | `func update_from_source() -> Dictionary:` |
| 方法 | [`update`](#member-gfaudiobeatclock-methods-update) | `func update(position_seconds: float) -> Dictionary:` |
| 方法 | [`sample`](#member-gfaudiobeatclock-methods-sample) | `func sample(position_seconds: float) -> Dictionary:` |
| 方法 | [`get_bpm`](#member-gfaudiobeatclock-methods-get_bpm) | `func get_bpm() -> float:` |
| 方法 | [`get_beats_per_measure`](#member-gfaudiobeatclock-methods-get_beats_per_measure) | `func get_beats_per_measure() -> int:` |
| 方法 | [`get_seconds_per_beat`](#member-gfaudiobeatclock-methods-get_seconds_per_beat) | `func get_seconds_per_beat() -> float:` |
| 方法 | [`get_seconds_per_measure`](#member-gfaudiobeatclock-methods-get_seconds_per_measure) | `func get_seconds_per_measure() -> float:` |
| 方法 | [`seconds_to_beats`](#member-gfaudiobeatclock-methods-seconds_to_beats) | `func seconds_to_beats(duration_seconds: float) -> float:` |
| 方法 | [`beats_to_seconds`](#member-gfaudiobeatclock-methods-beats_to_seconds) | `func beats_to_seconds(beat_count: float) -> float:` |
| 方法 | [`position_to_beats`](#member-gfaudiobeatclock-methods-position_to_beats) | `func position_to_beats(position_seconds: float) -> float:` |
| 方法 | [`beat_to_position_seconds`](#member-gfaudiobeatclock-methods-beat_to_position_seconds) | `func beat_to_position_seconds(beat_index: int) -> float:` |
| 方法 | [`quantize_position`](#member-gfaudiobeatclock-methods-quantize_position) | `func quantize_position( position_seconds: float, subdivisions_per_beat: int = 1, mode: QuantizeMode = QuantizeMode.NEAREST ) -> float:` |
| 方法 | [`get_last_snapshot`](#member-gfaudiobeatclock-methods-get_last_snapshot) | `func get_last_snapshot() -> Dictionary:` |
| 方法 | [`get_last_position_seconds`](#member-gfaudiobeatclock-methods-get_last_position_seconds) | `func get_last_position_seconds() -> float:` |
| 方法 | [`has_last_position`](#member-gfaudiobeatclock-methods-has_last_position) | `func has_last_position() -> bool:` |

## 信号

<a id="member-gfaudiobeatclock-signals-position_updated"></a>

### `position_updated`

- API：`public`

```gdscript
signal position_updated(snapshot: Dictionary)
```

update() 采样时间并刷新快照后发出。

参数：

| 名称 | 说明 |
|---|---|
| `snapshot` | 当前节拍快照。 |

结构：

- `snapshot`: Dictionary，包含 position_seconds、adjusted_seconds、beat_index、measure_index、beat_progress 和 measure_progress 等字段。

<a id="member-gfaudiobeatclock-signals-beat_reached"></a>

### `beat_reached`

- API：`public`

```gdscript
signal beat_reached(beat_index: int, beat_in_measure: int, position_seconds: float)
```

update() 检测到新的 beat 边界后发出。

参数：

| 名称 | 说明 |
|---|---|
| `beat_index` | 从 0 开始的全局 beat 索引。 |
| `beat_in_measure` | 当前小节内的 beat 索引。 |
| `position_seconds` | 该 beat 边界对应的播放时间。 |

<a id="member-gfaudiobeatclock-signals-measure_reached"></a>

### `measure_reached`

- API：`public`

```gdscript
signal measure_reached(measure_index: int, beat_index: int, position_seconds: float)
```

update() 检测到新的 measure 边界后发出。

参数：

| 名称 | 说明 |
|---|---|
| `measure_index` | 从 0 开始的小节索引。 |
| `beat_index` | 该小节起点对应的全局 beat 索引。 |
| `position_seconds` | 该小节边界对应的播放时间。 |

## 枚举

<a id="member-gfaudiobeatclock-enums-quantizemode"></a>

### `QuantizeMode`

- API：`public`

```gdscript
enum QuantizeMode { ## 量化到最近的网格点。 NEAREST, ## 量化到不大于当前时间的网格点。 FLOOR, ## 量化到不小于当前时间的网格点。 CEIL, }
```

量化时间时使用的舍入方式。

## 常量

<a id="member-gfaudiobeatclock-constants-default_bpm"></a>

### `DEFAULT_BPM`

- API：`public`

```gdscript
const DEFAULT_BPM: float = 120.0
```

默认 BPM。

<a id="member-gfaudiobeatclock-constants-default_beats_per_measure"></a>

### `DEFAULT_BEATS_PER_MEASURE`

- API：`public`

```gdscript
const DEFAULT_BEATS_PER_MEASURE: int = 4
```

默认每小节 beat 数。

<a id="member-gfaudiobeatclock-constants-default_max_emitted_steps_per_update"></a>

### `DEFAULT_MAX_EMITTED_STEPS_PER_UPDATE`

- API：`public`

```gdscript
const DEFAULT_MAX_EMITTED_STEPS_PER_UPDATE: int = 64
```

每次 update() 默认最多补发的 beat 边界数量。

## 属性

<a id="member-gfaudiobeatclock-properties-bpm"></a>

### `bpm`

- API：`public`

```gdscript
var bpm: float = DEFAULT_BPM
```

当前 BPM。小于等于 0 时会按极小正数处理，避免除零。

<a id="member-gfaudiobeatclock-properties-beats_per_measure"></a>

### `beats_per_measure`

- API：`public`

```gdscript
var beats_per_measure: int = DEFAULT_BEATS_PER_MEASURE
```

每小节 beat 数。小于 1 时按 1 处理。

<a id="member-gfaudiobeatclock-properties-offset_seconds"></a>

### `offset_seconds`

- API：`public`

```gdscript
var offset_seconds: float = 0.0
```

时间偏移，单位秒。采样时使用 position_seconds + offset_seconds 计算节拍。

<a id="member-gfaudiobeatclock-properties-emit_initial_events"></a>

### `emit_initial_events`

- API：`public`

```gdscript
var emit_initial_events: bool = false
```

首次 update() 是否立刻发出当前 beat 和 measure 边界事件。

<a id="member-gfaudiobeatclock-properties-max_emitted_steps_per_update"></a>

### `max_emitted_steps_per_update`

- API：`public`

```gdscript
var max_emitted_steps_per_update: int = DEFAULT_MAX_EMITTED_STEPS_PER_UPDATE
```

每次 update() 最多补发的 beat 边界数量。小于等于 0 时不补发边界事件。

<a id="member-gfaudiobeatclock-properties-position_source"></a>

### `position_source`

- API：`public`

```gdscript
var position_source: Callable = Callable()
```

可选播放位置来源。update_from_source() 会调用它并期望得到秒数。

<a id="member-gfaudiobeatclock-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

项目自定义元数据。框架不解释该字段。

结构：

- `metadata`: Dictionary metadata for tooling or project-specific routing.

## 方法

<a id="member-gfaudiobeatclock-methods-configure"></a>

### `configure`

- API：`public`

```gdscript
func configure( next_bpm: float, next_beats_per_measure: int = DEFAULT_BEATS_PER_MEASURE, next_offset_seconds: float = 0.0, should_reset: bool = true ) -> void:
```

配置节拍参数。

参数：

| 名称 | 说明 |
|---|---|
| `next_bpm` | BPM。 |
| `next_beats_per_measure` | 每小节 beat 数。 |
| `next_offset_seconds` | 时间偏移，单位秒。 |
| `should_reset` | 为 true 时清除上一帧边界状态。 |

<a id="member-gfaudiobeatclock-methods-set_position_source"></a>

### `set_position_source`

- API：`public`

```gdscript
func set_position_source(source: Callable) -> void:
```

设置播放位置来源。

参数：

| 名称 | 说明 |
|---|---|
| `source` | 返回播放秒数的回调。 |

<a id="member-gfaudiobeatclock-methods-clear"></a>

### `clear`

- API：`public`

```gdscript
func clear() -> void:
```

清除上一帧状态。

<a id="member-gfaudiobeatclock-methods-reset"></a>

### `reset`

- API：`public`

```gdscript
func reset(position_seconds: float = 0.0) -> Dictionary:
```

将时钟状态重置到指定播放时间，不发出边界事件。

参数：

| 名称 | 说明 |
|---|---|
| `position_seconds` | 播放时间，单位秒。 |

返回：重置后的快照。

结构：

- `return`: Dictionary，结构同 sample()。

<a id="member-gfaudiobeatclock-methods-update_from_source"></a>

### `update_from_source`

- API：`public`

```gdscript
func update_from_source() -> Dictionary:
```

从 position_source 采样并更新时钟。

返回：当前节拍快照；来源无效或返回非数字时返回空字典。

结构：

- `return`: Dictionary，结构同 sample()。

<a id="member-gfaudiobeatclock-methods-update"></a>

### `update`

- API：`public`

```gdscript
func update(position_seconds: float) -> Dictionary:
```

采样指定播放时间、刷新状态并发出越过的边界事件。

参数：

| 名称 | 说明 |
|---|---|
| `position_seconds` | 播放时间，单位秒。 |

返回：当前节拍快照。

结构：

- `return`: Dictionary，包含 position_seconds、adjusted_seconds、bpm、seconds_per_beat、beats_per_measure、beat_float、beat_index、beat_in_measure、beat_progress、measure_index、measure_progress 和 measure_start_beat。

<a id="member-gfaudiobeatclock-methods-sample"></a>

### `sample`

- API：`public`

```gdscript
func sample(position_seconds: float) -> Dictionary:
```

采样指定播放时间但不修改时钟状态。

参数：

| 名称 | 说明 |
|---|---|
| `position_seconds` | 播放时间，单位秒。 |

返回：节拍快照。

结构：

- `return`: Dictionary，包含 position_seconds、adjusted_seconds、bpm、seconds_per_beat、beats_per_measure、beat_float、beat_index、beat_in_measure、beat_progress、measure_index、measure_progress 和 measure_start_beat。

<a id="member-gfaudiobeatclock-methods-get_bpm"></a>

### `get_bpm`

- API：`public`

```gdscript
func get_bpm() -> float:
```

获取经过安全收窄的 BPM。

返回：BPM。

<a id="member-gfaudiobeatclock-methods-get_beats_per_measure"></a>

### `get_beats_per_measure`

- API：`public`

```gdscript
func get_beats_per_measure() -> int:
```

获取经过安全收窄的每小节 beat 数。

返回：每小节 beat 数。

<a id="member-gfaudiobeatclock-methods-get_seconds_per_beat"></a>

### `get_seconds_per_beat`

- API：`public`

```gdscript
func get_seconds_per_beat() -> float:
```

获取每个 beat 的秒数。

返回：秒数。

<a id="member-gfaudiobeatclock-methods-get_seconds_per_measure"></a>

### `get_seconds_per_measure`

- API：`public`

```gdscript
func get_seconds_per_measure() -> float:
```

获取每小节的秒数。

返回：秒数。

<a id="member-gfaudiobeatclock-methods-seconds_to_beats"></a>

### `seconds_to_beats`

- API：`public`

```gdscript
func seconds_to_beats(duration_seconds: float) -> float:
```

将持续时间秒数转换为 beat 数，不应用 offset_seconds。

参数：

| 名称 | 说明 |
|---|---|
| `duration_seconds` | 持续时间，单位秒。 |

返回：beat 数。

<a id="member-gfaudiobeatclock-methods-beats_to_seconds"></a>

### `beats_to_seconds`

- API：`public`

```gdscript
func beats_to_seconds(beat_count: float) -> float:
```

将 beat 数转换为持续时间秒数，不应用 offset_seconds。

参数：

| 名称 | 说明 |
|---|---|
| `beat_count` | beat 数。 |

返回：持续时间秒数。

<a id="member-gfaudiobeatclock-methods-position_to_beats"></a>

### `position_to_beats`

- API：`public`

```gdscript
func position_to_beats(position_seconds: float) -> float:
```

将播放时间转换为 beat 数，会应用 offset_seconds。

参数：

| 名称 | 说明 |
|---|---|
| `position_seconds` | 播放时间，单位秒。 |

返回：beat 数。

<a id="member-gfaudiobeatclock-methods-beat_to_position_seconds"></a>

### `beat_to_position_seconds`

- API：`public`

```gdscript
func beat_to_position_seconds(beat_index: int) -> float:
```

获取指定 beat 边界对应的播放时间，会反向应用 offset_seconds。

参数：

| 名称 | 说明 |
|---|---|
| `beat_index` | beat 索引。 |

返回：播放时间，单位秒。

<a id="member-gfaudiobeatclock-methods-quantize_position"></a>

### `quantize_position`

- API：`public`

```gdscript
func quantize_position( position_seconds: float, subdivisions_per_beat: int = 1, mode: QuantizeMode = QuantizeMode.NEAREST ) -> float:
```

量化播放时间到 beat 网格。

参数：

| 名称 | 说明 |
|---|---|
| `position_seconds` | 播放时间，单位秒。 |
| `subdivisions_per_beat` | 每个 beat 的细分数量。 |
| `mode` | 量化方式。 |

返回：量化后的播放时间，单位秒。

<a id="member-gfaudiobeatclock-methods-get_last_snapshot"></a>

### `get_last_snapshot`

- API：`public`

```gdscript
func get_last_snapshot() -> Dictionary:
```

获取上一帧快照副本。

返回：快照副本。

结构：

- `return`: Dictionary，结构同 sample()；尚未 update/reset 时为空。

<a id="member-gfaudiobeatclock-methods-get_last_position_seconds"></a>

### `get_last_position_seconds`

- API：`public`

```gdscript
func get_last_position_seconds() -> float:
```

获取上一帧播放位置。

返回：播放时间，单位秒。

<a id="member-gfaudiobeatclock-methods-has_last_position"></a>

### `has_last_position`

- API：`public`

```gdscript
func has_last_position() -> bool:
```

检查时钟是否已经有上一帧状态。

返回：已有状态时返回 true。
