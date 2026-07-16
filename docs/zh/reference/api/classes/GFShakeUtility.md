# GFShakeUtility

[API Reference](../index.md) / [Feedback](../extensions-feedback.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/feedback/runtime/gf_shake_utility.gd`
- 模块：`Feedback`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

通用反馈播放与采样工具。 管理命名 channel 上的 `GFShakePreset` 播放状态，项目可按需把采样结果应用到 Camera、Node2D、Node3D、Control 或任意自定义表现对象。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`shake_started`](#member-gfshakeutility-signals-shake_started) | `signal shake_started(shake_id: int, channel: StringName)` |
| 信号 | [`shake_finished`](#member-gfshakeutility-signals-shake_finished) | `signal shake_finished(shake_id: int, channel: StringName)` |
| 信号 | [`shake_stopped`](#member-gfshakeutility-signals-shake_stopped) | `signal shake_stopped(shake_id: int, channel: StringName)` |
| 枚举 | [`OverflowPolicy`](#member-gfshakeutility-enums-overflowpolicy) | `enum OverflowPolicy` |
| 属性 | [`default_channel`](#member-gfshakeutility-properties-default_channel) | `var default_channel: StringName = &"default"` |
| 属性 | [`max_active_shakes`](#member-gfshakeutility-properties-max_active_shakes) | `var max_active_shakes: int = 64` |
| 属性 | [`overflow_policy`](#member-gfshakeutility-properties-overflow_policy) | `var overflow_policy: OverflowPolicy = OverflowPolicy.STOP_OLDEST` |
| 属性 | [`randomize_phase`](#member-gfshakeutility-properties-randomize_phase) | `var randomize_phase: bool = true` |
| 方法 | [`init`](#member-gfshakeutility-methods-init) | `func init() -> void:` |
| 方法 | [`dispose`](#member-gfshakeutility-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`tick`](#member-gfshakeutility-methods-tick) | `func tick(delta: float) -> void:` |
| 方法 | [`play_shake`](#member-gfshakeutility-methods-play_shake) | `func play_shake( channel: StringName, preset: GFShakePreset, strength: float = 1.0, metadata: Dictionary = {} ) -> int:` |
| 方法 | [`stop_shake`](#member-gfshakeutility-methods-stop_shake) | `func stop_shake(shake_id: int, emit_stopped: bool = true) -> bool:` |
| 方法 | [`stop_channel`](#member-gfshakeutility-methods-stop_channel) | `func stop_channel(channel: StringName) -> int:` |
| 方法 | [`clear`](#member-gfshakeutility-methods-clear) | `func clear() -> void:` |
| 方法 | [`is_shake_active`](#member-gfshakeutility-methods-is_shake_active) | `func is_shake_active(shake_id: int) -> bool:` |
| 方法 | [`get_active_shake_count`](#member-gfshakeutility-methods-get_active_shake_count) | `func get_active_shake_count(channel: StringName = &"") -> int:` |
| 方法 | [`sample_channel`](#member-gfshakeutility-methods-sample_channel) | `func sample_channel(channel: StringName = &"") -> Dictionary:` |
| 方法 | [`sample_channels`](#member-gfshakeutility-methods-sample_channels) | `func sample_channels(channels: PackedStringArray) -> Dictionary:` |
| 方法 | [`get_shake_info`](#member-gfshakeutility-methods-get_shake_info) | `func get_shake_info(shake_id: int) -> Dictionary:` |
| 方法 | [`get_debug_snapshot`](#member-gfshakeutility-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfshakeutility-signals-shake_started"></a>

### `shake_started`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
signal shake_started(shake_id: int, channel: StringName)
```

反馈播放开始时发出。

参数：

| 名称 | 说明 |
|---|---|
| `shake_id` | 播放实例 ID。 |
| `channel` | 反馈 channel。 |

<a id="member-gfshakeutility-signals-shake_finished"></a>

### `shake_finished`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
signal shake_finished(shake_id: int, channel: StringName)
```

反馈播放结束时发出。

参数：

| 名称 | 说明 |
|---|---|
| `shake_id` | 播放实例 ID。 |
| `channel` | 反馈 channel。 |

<a id="member-gfshakeutility-signals-shake_stopped"></a>

### `shake_stopped`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
signal shake_stopped(shake_id: int, channel: StringName)
```

反馈播放被停止时发出。

参数：

| 名称 | 说明 |
|---|---|
| `shake_id` | 播放实例 ID。 |
| `channel` | 反馈 channel。 |

## 枚举

<a id="member-gfshakeutility-enums-overflowpolicy"></a>

### `OverflowPolicy`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
enum OverflowPolicy {
	## 跳过新的播放请求。
	SKIP_NEW,
	## 停止最早的播放实例。
	STOP_OLDEST,
}
```

活跃反馈达到上限时的处理方式。

## 属性

<a id="member-gfshakeutility-properties-default_channel"></a>

### `default_channel`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var default_channel: StringName = &"default"
```

默认 channel。

<a id="member-gfshakeutility-properties-max_active_shakes"></a>

### `max_active_shakes`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var max_active_shakes: int = 64
```

最大活跃反馈数量；小于等于 0 表示不限制。

<a id="member-gfshakeutility-properties-overflow_policy"></a>

### `overflow_policy`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var overflow_policy: OverflowPolicy = OverflowPolicy.STOP_OLDEST
```

达到上限时的处理方式。

<a id="member-gfshakeutility-properties-randomize_phase"></a>

### `randomize_phase`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var randomize_phase: bool = true
```

是否为每次播放随机化相位。

## 方法

<a id="member-gfshakeutility-methods-init"></a>

### `init`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func init() -> void:
```

初始化反馈运行时状态和随机源。

<a id="member-gfshakeutility-methods-dispose"></a>

### `dispose`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func dispose() -> void:
```

释放全部反馈播放状态。

<a id="member-gfshakeutility-methods-tick"></a>

### `tick`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func tick(delta: float) -> void:
```

推进反馈播放状态。

参数：

| 名称 | 说明 |
|---|---|
| `delta` | 本帧时间增量。 |

<a id="member-gfshakeutility-methods-play_shake"></a>

### `play_shake`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func play_shake( channel: StringName, preset: GFShakePreset, strength: float = 1.0, metadata: Dictionary = {} ) -> int:
```

播放一个反馈预设。

参数：

| 名称 | 说明 |
|---|---|
| `channel` | 反馈 channel；为空时使用 default_channel。 |
| `preset` | 反馈预设。 |
| `strength` | 播放强度倍率。 |
| `metadata` | 项目自定义元数据。 |

返回：播放实例 ID；无法播放时返回 -1。

结构：

- `metadata`: Dictionary，播放实例自定义元数据，会在 get_shake_info() JSON-safe 快照中复制返回。

<a id="member-gfshakeutility-methods-stop_shake"></a>

### `stop_shake`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func stop_shake(shake_id: int, emit_stopped: bool = true) -> bool:
```

停止指定反馈实例。

参数：

| 名称 | 说明 |
|---|---|
| `shake_id` | 播放实例 ID。 |
| `emit_stopped` | 是否发出停止信号。 |

返回：成功停止返回 true。

<a id="member-gfshakeutility-methods-stop_channel"></a>

### `stop_channel`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func stop_channel(channel: StringName) -> int:
```

停止指定 channel 上的全部反馈实例。

参数：

| 名称 | 说明 |
|---|---|
| `channel` | 反馈 channel；为空时使用 default_channel。 |

返回：停止数量。

<a id="member-gfshakeutility-methods-clear"></a>

### `clear`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func clear() -> void:
```

清空全部反馈实例。

<a id="member-gfshakeutility-methods-is_shake_active"></a>

### `is_shake_active`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func is_shake_active(shake_id: int) -> bool:
```

检查反馈实例是否仍在播放。

参数：

| 名称 | 说明 |
|---|---|
| `shake_id` | 播放实例 ID。 |

返回：正在播放返回 true。

<a id="member-gfshakeutility-methods-get_active_shake_count"></a>

### `get_active_shake_count`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func get_active_shake_count(channel: StringName = &"") -> int:
```

获取活跃反馈数量。

参数：

| 名称 | 说明 |
|---|---|
| `channel` | 可选 channel；为空时统计全部。 |

返回：活跃反馈数量。

<a id="member-gfshakeutility-methods-sample_channel"></a>

### `sample_channel`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func sample_channel(channel: StringName = &"") -> Dictionary:
```

采样指定 channel 当前的合成反馈。

参数：

| 名称 | 说明 |
|---|---|
| `channel` | 反馈 channel；为空时使用 default_channel。 |

返回：合成采样结果。

结构：

- `return`: Dictionary，包含 position: Vector3、rotation_degrees: Vector3、scale: Vector3、intensity: float 与 progress: float。

<a id="member-gfshakeutility-methods-sample_channels"></a>

### `sample_channels`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func sample_channels(channels: PackedStringArray) -> Dictionary:
```

采样多个 channel 当前的合成反馈。

参数：

| 名称 | 说明 |
|---|---|
| `channels` | 反馈 channel 列表。 |

返回：合成采样结果。

结构：

- `return`: Dictionary，包含 position: Vector3、rotation_degrees: Vector3、scale: Vector3、intensity: float 与 progress: float。

<a id="member-gfshakeutility-methods-get_shake_info"></a>

### `get_shake_info`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func get_shake_info(shake_id: int) -> Dictionary:
```

获取指定反馈实例的只读快照。

参数：

| 名称 | 说明 |
|---|---|
| `shake_id` | 播放实例 ID。 |

返回：播放实例快照。

结构：

- `return`: JSON-safe Dictionary，包含 id、channel、elapsed_seconds、duration_seconds、strength 与 metadata；实例不存在时为空。

<a id="member-gfshakeutility-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取反馈系统调试快照。

返回：调试快照。

结构：

- `return`: JSON-safe Dictionary，包含 active_count、max_active_shakes、channels 与 play_order。
