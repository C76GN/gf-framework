# GFHapticUtility

[API Reference](../index.md) / [Feedback](../extensions-feedback.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/feedback/runtime/gf_haptic_utility.gd`
- 模块：`Feedback`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`7.0.0`

通用手柄震动播放工具。 管理命名 channel 上的 `GFHapticPreset` 播放状态，并把合成后的弱/强马达强度 路由到玩家席位或手柄设备。项目仍然决定何时播放、如何分组以及玩法语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`haptic_started`](#member-gfhapticutility-signals-haptic_started) | `signal haptic_started(haptic_id: int, channel: StringName, target_type: int, target_id: int)` |
| 信号 | [`haptic_finished`](#member-gfhapticutility-signals-haptic_finished) | `signal haptic_finished(haptic_id: int, channel: StringName, target_type: int, target_id: int)` |
| 信号 | [`haptic_stopped`](#member-gfhapticutility-signals-haptic_stopped) | `signal haptic_stopped(haptic_id: int, channel: StringName, target_type: int, target_id: int)` |
| 枚举 | [`TargetType`](#member-gfhapticutility-enums-targettype) | `enum TargetType` |
| 枚举 | [`OverflowPolicy`](#member-gfhapticutility-enums-overflowpolicy) | `enum OverflowPolicy` |
| 常量 | [`DEFAULT_OUTPUT_REFRESH_SECONDS`](#member-gfhapticutility-constants-default_output_refresh_seconds) | `const DEFAULT_OUTPUT_REFRESH_SECONDS: float = 0.05` |
| 常量 | [`MIN_OUTPUT_DURATION_SECONDS`](#member-gfhapticutility-constants-min_output_duration_seconds) | `const MIN_OUTPUT_DURATION_SECONDS: float = 0.001` |
| 属性 | [`default_channel`](#member-gfhapticutility-properties-default_channel) | `var default_channel: StringName = &"default"` |
| 属性 | [`default_player_index`](#member-gfhapticutility-properties-default_player_index) | `var default_player_index: int = 0` |
| 属性 | [`master_strength`](#member-gfhapticutility-properties-master_strength) | `var master_strength: float = 1.0:` |
| 属性 | [`max_active_haptics`](#member-gfhapticutility-properties-max_active_haptics) | `var max_active_haptics: int = 64` |
| 属性 | [`overflow_policy`](#member-gfhapticutility-properties-overflow_policy) | `var overflow_policy: OverflowPolicy = OverflowPolicy.STOP_OLDEST` |
| 属性 | [`auto_apply_on_tick`](#member-gfhapticutility-properties-auto_apply_on_tick) | `var auto_apply_on_tick: bool = true` |
| 属性 | [`output_refresh_seconds`](#member-gfhapticutility-properties-output_refresh_seconds) | `var output_refresh_seconds: float = DEFAULT_OUTPUT_REFRESH_SECONDS:` |
| 属性 | [`input_device_utility`](#member-gfhapticutility-properties-input_device_utility) | `var input_device_utility: GFInputDeviceUtility = null` |
| 属性 | [`haptic_backend`](#member-gfhapticutility-properties-haptic_backend) | `var haptic_backend: Object = null` |
| 属性 | [`output_handler`](#member-gfhapticutility-properties-output_handler) | `var output_handler: Callable = Callable()` |
| 属性 | [`stop_handler`](#member-gfhapticutility-properties-stop_handler) | `var stop_handler: Callable = Callable()` |
| 方法 | [`init`](#member-gfhapticutility-methods-init) | `func init() -> void:` |
| 方法 | [`ready`](#member-gfhapticutility-methods-ready) | `func ready() -> void:` |
| 方法 | [`dispose`](#member-gfhapticutility-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`tick`](#member-gfhapticutility-methods-tick) | `func tick(delta: float) -> void:` |
| 方法 | [`play_haptic`](#member-gfhapticutility-methods-play_haptic) | `func play_haptic( channel: StringName, preset: GFHapticPreset, player_index: int = -1, strength: float = 1.0, metadata: Dictionary = {} ) -> int:` |
| 方法 | [`play_haptic_for_device`](#member-gfhapticutility-methods-play_haptic_for_device) | `func play_haptic_for_device( channel: StringName, preset: GFHapticPreset, device_id: int, strength: float = 1.0, metadata: Dictionary = {} ) -> int:` |
| 方法 | [`stop_haptic`](#member-gfhapticutility-methods-stop_haptic) | `func stop_haptic(haptic_id: int, emit_stopped: bool = true) -> bool:` |
| 方法 | [`stop_channel`](#member-gfhapticutility-methods-stop_channel) | `func stop_channel(channel: StringName) -> int:` |
| 方法 | [`stop_player`](#member-gfhapticutility-methods-stop_player) | `func stop_player(player_index: int) -> int:` |
| 方法 | [`stop_device`](#member-gfhapticutility-methods-stop_device) | `func stop_device(device_id: int) -> int:` |
| 方法 | [`clear`](#member-gfhapticutility-methods-clear) | `func clear() -> void:` |
| 方法 | [`is_haptic_active`](#member-gfhapticutility-methods-is_haptic_active) | `func is_haptic_active(haptic_id: int) -> bool:` |
| 方法 | [`get_active_haptic_count`](#member-gfhapticutility-methods-get_active_haptic_count) | `func get_active_haptic_count(channel: StringName = &"") -> int:` |
| 方法 | [`set_channel_strength`](#member-gfhapticutility-methods-set_channel_strength) | `func set_channel_strength(channel: StringName, strength: float) -> void:` |
| 方法 | [`get_channel_strength`](#member-gfhapticutility-methods-get_channel_strength) | `func get_channel_strength(channel: StringName) -> float:` |
| 方法 | [`clear_channel_strengths`](#member-gfhapticutility-methods-clear_channel_strengths) | `func clear_channel_strengths() -> void:` |
| 方法 | [`sample_player`](#member-gfhapticutility-methods-sample_player) | `func sample_player(player_index: int, channel: StringName = &"") -> Dictionary:` |
| 方法 | [`sample_device`](#member-gfhapticutility-methods-sample_device) | `func sample_device(device_id: int, channel: StringName = &"") -> Dictionary:` |
| 方法 | [`apply_current_outputs`](#member-gfhapticutility-methods-apply_current_outputs) | `func apply_current_outputs(duration_seconds: float = -1.0) -> Dictionary:` |
| 方法 | [`get_haptic_info`](#member-gfhapticutility-methods-get_haptic_info) | `func get_haptic_info(haptic_id: int) -> Dictionary:` |
| 方法 | [`get_last_output_report`](#member-gfhapticutility-methods-get_last_output_report) | `func get_last_output_report() -> Dictionary:` |
| 方法 | [`get_debug_snapshot`](#member-gfhapticutility-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfhapticutility-signals-haptic_started"></a>

### `haptic_started`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
signal haptic_started(haptic_id: int, channel: StringName, target_type: int, target_id: int)
```

震动播放开始时发出。

参数：

| 名称 | 说明 |
|---|---|
| `haptic_id` | 播放实例 ID。 |
| `channel` | 震动 channel。 |
| `target_type` | 目标类型，见 TargetType。 |
| `target_id` | 玩家索引或设备 ID。 |

<a id="member-gfhapticutility-signals-haptic_finished"></a>

### `haptic_finished`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
signal haptic_finished(haptic_id: int, channel: StringName, target_type: int, target_id: int)
```

震动播放结束时发出。

参数：

| 名称 | 说明 |
|---|---|
| `haptic_id` | 播放实例 ID。 |
| `channel` | 震动 channel。 |
| `target_type` | 目标类型，见 TargetType。 |
| `target_id` | 玩家索引或设备 ID。 |

<a id="member-gfhapticutility-signals-haptic_stopped"></a>

### `haptic_stopped`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
signal haptic_stopped(haptic_id: int, channel: StringName, target_type: int, target_id: int)
```

震动播放被停止时发出。

参数：

| 名称 | 说明 |
|---|---|
| `haptic_id` | 播放实例 ID。 |
| `channel` | 震动 channel。 |
| `target_type` | 目标类型，见 TargetType。 |
| `target_id` | 玩家索引或设备 ID。 |

## 枚举

<a id="member-gfhapticutility-enums-targettype"></a>

### `TargetType`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
enum TargetType {
	## 目标是本地玩家索引，通过 GFInputDeviceUtility 解析到手柄设备。
	PLAYER,
	## 目标是 Godot 手柄设备 ID。
	DEVICE,
}
```

震动输出目标类型。

<a id="member-gfhapticutility-enums-overflowpolicy"></a>

### `OverflowPolicy`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
enum OverflowPolicy {
	## 跳过新的播放请求。
	SKIP_NEW,
	## 停止最早的播放实例。
	STOP_OLDEST,
}
```

活跃震动达到上限时的处理方式。

## 常量

<a id="member-gfhapticutility-constants-default_output_refresh_seconds"></a>

### `DEFAULT_OUTPUT_REFRESH_SECONDS`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const DEFAULT_OUTPUT_REFRESH_SECONDS: float = 0.05
```

默认向输入系统刷新合成震动输出的间隔（秒）。

<a id="member-gfhapticutility-constants-min_output_duration_seconds"></a>

### `MIN_OUTPUT_DURATION_SECONDS`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const MIN_OUTPUT_DURATION_SECONDS: float = 0.001
```

允许提交到底层输出的最短震动时长（秒）。

## 属性

<a id="member-gfhapticutility-properties-default_channel"></a>

### `default_channel`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var default_channel: StringName = &"default"
```

默认 channel。

<a id="member-gfhapticutility-properties-default_player_index"></a>

### `default_player_index`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var default_player_index: int = 0
```

默认玩家索引。play_haptic() 传入负数时使用该值。

<a id="member-gfhapticutility-properties-master_strength"></a>

### `master_strength`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var master_strength: float = 1.0:
```

全局震动强度倍率。

<a id="member-gfhapticutility-properties-max_active_haptics"></a>

### `max_active_haptics`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var max_active_haptics: int = 64
```

最大活跃震动数量；小于等于 0 表示不限制。

<a id="member-gfhapticutility-properties-overflow_policy"></a>

### `overflow_policy`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var overflow_policy: OverflowPolicy = OverflowPolicy.STOP_OLDEST
```

达到上限时的处理方式。

<a id="member-gfhapticutility-properties-auto_apply_on_tick"></a>

### `auto_apply_on_tick`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var auto_apply_on_tick: bool = true
```

tick() 后是否自动把当前采样输出到设备。该开关只控制 tick()；显式 stop 与 clear 仍会立即撤销已输出目标。关闭时，调用方必须在 tick() 后自行调用 apply_current_outputs()。

<a id="member-gfhapticutility-properties-output_refresh_seconds"></a>

### `output_refresh_seconds`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var output_refresh_seconds: float = DEFAULT_OUTPUT_REFRESH_SECONDS:
```

每次输出请求的刷新持续时间，单位秒。值始终收束为有限正数；非有限值回退到默认值， 小于最小输出时长的值按最小值处理，避免平台把 0 解释为无限震动。

<a id="member-gfhapticutility-properties-input_device_utility"></a>

### `input_device_utility`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var input_device_utility: GFInputDeviceUtility = null
```

可选输入设备工具。为空时 ready() 会尝试从架构中获取。

<a id="member-gfhapticutility-properties-haptic_backend"></a>

### `haptic_backend`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var haptic_backend: Object = null
```

可选震动输出后端。必须同时实现 start_output() 与 stop_output()；有效时优先于 output_handler 和默认 Input 路由。一次成功输出会持续绑定其启动后端，直至停止。

<a id="member-gfhapticutility-properties-output_handler"></a>

### `output_handler`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var output_handler: Callable = Callable()
```

可选输出回调。必须与有效 stop_handler 成对配置；有效时替代默认 Input/GFInputDeviceUtility 路由。

结构：

- `output_handler`: Callable(target_type: int, target_id: int, weak_magnitude: float, strong_magnitude: float, duration_seconds: float, metadata: Dictionary) -> bool。

<a id="member-gfhapticutility-properties-stop_handler"></a>

### `stop_handler`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var stop_handler: Callable = Callable()
```

可选停止回调。必须与有效 output_handler 成对配置；成功输出后的停止会使用启动时 捕获的回调，而不是随后替换的公开字段。

结构：

- `stop_handler`: Callable(target_type: int, target_id: int, metadata: Dictionary) -> bool。

## 方法

<a id="member-gfhapticutility-methods-init"></a>

### `init`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func init() -> void:
```

初始化震动运行时状态。

<a id="member-gfhapticutility-methods-ready"></a>

### `ready`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func ready() -> void:
```

在架构 ready 后补全输入设备工具引用。

<a id="member-gfhapticutility-methods-dispose"></a>

### `dispose`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func dispose() -> void:
```

停止全部震动并释放状态。最终停止失败会保留在 get_last_output_report()，但不会在 provider 已释放后留下伪可重试目标。

<a id="member-gfhapticutility-methods-tick"></a>

### `tick`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func tick(delta: float) -> void:
```

推进震动播放状态。

参数：

| 名称 | 说明 |
|---|---|
| `delta` | 本帧时间增量。 |

<a id="member-gfhapticutility-methods-play_haptic"></a>

### `play_haptic`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func play_haptic( channel: StringName, preset: GFHapticPreset, player_index: int = -1, strength: float = 1.0, metadata: Dictionary = {} ) -> int:
```

播放一个玩家震动预设。 apply_current_outputs() 或 get_last_output_report()。

参数：

| 名称 | 说明 |
|---|---|
| `channel` | 震动 channel；为空时使用 default_channel。 |
| `preset` | 震动预设。 |
| `player_index` | 玩家索引；小于 0 时使用 default_player_index。 |
| `strength` | 播放强度倍率。 |
| `metadata` | 项目自定义元数据。 |

返回：逻辑排程实例 ID；参数或容量拒绝时返回 -1。物理输出是否被接受请读取

结构：

- `metadata`: Dictionary，播放实例自定义元数据，会在 get_haptic_info() JSON-safe 快照中复制返回。

<a id="member-gfhapticutility-methods-play_haptic_for_device"></a>

### `play_haptic_for_device`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func play_haptic_for_device( channel: StringName, preset: GFHapticPreset, device_id: int, strength: float = 1.0, metadata: Dictionary = {} ) -> int:
```

播放一个设备震动预设。 apply_current_outputs() 或 get_last_output_report()。

参数：

| 名称 | 说明 |
|---|---|
| `channel` | 震动 channel；为空时使用 default_channel。 |
| `preset` | 震动预设。 |
| `device_id` | Godot 手柄设备 ID。 |
| `strength` | 播放强度倍率。 |
| `metadata` | 项目自定义元数据。 |

返回：逻辑排程实例 ID；参数或容量拒绝时返回 -1。物理输出是否被接受请读取

结构：

- `metadata`: Dictionary，播放实例自定义元数据，会在 get_haptic_info() JSON-safe 快照中复制返回。

<a id="member-gfhapticutility-methods-stop_haptic"></a>

### `stop_haptic`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func stop_haptic(haptic_id: int, emit_stopped: bool = true) -> bool:
```

停止指定震动实例。

参数：

| 名称 | 说明 |
|---|---|
| `haptic_id` | 播放实例 ID。 |
| `emit_stopped` | 是否发出停止信号。 |

返回：成功停止返回 true。

<a id="member-gfhapticutility-methods-stop_channel"></a>

### `stop_channel`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func stop_channel(channel: StringName) -> int:
```

停止指定 channel 上的全部震动实例。

参数：

| 名称 | 说明 |
|---|---|
| `channel` | 震动 channel；为空时使用 default_channel。 |

返回：停止数量。

<a id="member-gfhapticutility-methods-stop_player"></a>

### `stop_player`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func stop_player(player_index: int) -> int:
```

停止指定玩家的全部震动实例。

参数：

| 名称 | 说明 |
|---|---|
| `player_index` | 玩家索引。 |

返回：停止数量。

<a id="member-gfhapticutility-methods-stop_device"></a>

### `stop_device`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func stop_device(device_id: int) -> int:
```

停止指定设备的全部震动实例。

参数：

| 名称 | 说明 |
|---|---|
| `device_id` | Godot 手柄设备 ID。 |

返回：停止数量。

<a id="member-gfhapticutility-methods-clear"></a>

### `clear`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func clear() -> void:
```

清空全部震动实例并停止上次输出过的目标。

<a id="member-gfhapticutility-methods-is_haptic_active"></a>

### `is_haptic_active`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func is_haptic_active(haptic_id: int) -> bool:
```

检查震动实例是否仍在播放。

参数：

| 名称 | 说明 |
|---|---|
| `haptic_id` | 播放实例 ID。 |

返回：正在播放返回 true。

<a id="member-gfhapticutility-methods-get_active_haptic_count"></a>

### `get_active_haptic_count`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_active_haptic_count(channel: StringName = &"") -> int:
```

获取活跃震动数量。

参数：

| 名称 | 说明 |
|---|---|
| `channel` | 可选 channel；为空时统计全部。 |

返回：活跃震动数量。

<a id="member-gfhapticutility-methods-set_channel_strength"></a>

### `set_channel_strength`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func set_channel_strength(channel: StringName, strength: float) -> void:
```

设置 channel 强度倍率。

参数：

| 名称 | 说明 |
|---|---|
| `channel` | 震动 channel；为空时使用 default_channel。 |
| `strength` | 强度倍率；小于 0 时按 0 处理。 |

<a id="member-gfhapticutility-methods-get_channel_strength"></a>

### `get_channel_strength`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_channel_strength(channel: StringName) -> float:
```

获取 channel 强度倍率。

参数：

| 名称 | 说明 |
|---|---|
| `channel` | 震动 channel；为空时使用 default_channel。 |

返回：强度倍率。

<a id="member-gfhapticutility-methods-clear_channel_strengths"></a>

### `clear_channel_strengths`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func clear_channel_strengths() -> void:
```

清空全部 channel 强度覆盖。

<a id="member-gfhapticutility-methods-sample_player"></a>

### `sample_player`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func sample_player(player_index: int, channel: StringName = &"") -> Dictionary:
```

采样指定玩家当前的合成震动。 返回玩家最终路由到的物理输出视图；映射到设备后会与该设备的直接震动合并。

参数：

| 名称 | 说明 |
|---|---|
| `player_index` | 玩家索引。 |
| `channel` | 可选 channel；为空时合成该玩家全部 channel。 |

返回：合成震动采样。

结构：

- `return`: Dictionary，包含 weak_magnitude、strong_magnitude、intensity 与 progress。

<a id="member-gfhapticutility-methods-sample_device"></a>

### `sample_device`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func sample_device(device_id: int, channel: StringName = &"") -> Dictionary:
```

采样指定设备当前的合成震动。 返回设备最终物理输出视图，包含映射到该设备的玩家震动。

参数：

| 名称 | 说明 |
|---|---|
| `device_id` | Godot 手柄设备 ID。 |
| `channel` | 可选 channel；为空时合成该设备全部 channel。 |

返回：合成震动采样。

结构：

- `return`: Dictionary，包含 weak_magnitude、strong_magnitude、intensity 与 progress。

<a id="member-gfhapticutility-methods-apply_current_outputs"></a>

### `apply_current_outputs`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func apply_current_outputs(duration_seconds: float = -1.0) -> Dictionary:
```

把当前采样输出到所有活跃目标。 output_refresh_seconds，传给 provider 的值始终为有限正数。

参数：

| 名称 | 说明 |
|---|---|
| `duration_seconds` | 输出请求持续时间；小于等于 0 或非有限值使用 |

返回：输出报告。

结构：

- `return`: JSON-safe Dictionary，包含 applied_count、stopped_count、failed_stop_count、rejected_count、applied、stopped、failed_stops 与 rejected。

<a id="member-gfhapticutility-methods-get_haptic_info"></a>

### `get_haptic_info`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_haptic_info(haptic_id: int) -> Dictionary:
```

获取指定震动实例的只读快照。

参数：

| 名称 | 说明 |
|---|---|
| `haptic_id` | 播放实例 ID。 |

返回：播放实例快照。

结构：

- `return`: JSON-safe Dictionary，包含 id、channel、target_type、target_id、elapsed_seconds、duration_seconds、strength 与 metadata；实例不存在时为空。

<a id="member-gfhapticutility-methods-get_last_output_report"></a>

### `get_last_output_report`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_last_output_report() -> Dictionary:
```

获取最近一次包含实际输出、停止或拒绝明细的报告。后续无活动空刷新不会覆盖该报告。

返回：最近输出活动报告；尚无输出活动时返回计数和明细均为空的完整报告。

结构：

- `return`: JSON-safe Dictionary，包含 applied_count、stopped_count、failed_stop_count、rejected_count、applied、stopped、failed_stops 与 rejected。

<a id="member-gfhapticutility-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取震动系统调试快照。

返回：调试快照。

结构：

- `return`: JSON-safe Dictionary，包含 active_count、max_active_haptics、channels、targets、play_order、last_output_targets 与 last_output_report。
