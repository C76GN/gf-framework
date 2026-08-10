# 手柄震动反馈

`GFHapticPreset` 描述弱/强马达的时间采样，`GFHapticUtility` 管理命名 channel 上的播放实例，并把合成结果输出到玩家席位或手柄设备。

## 定位

手柄震动属于表现反馈机制，不承载玩法含义。项目负责决定何时播放、强度如何与设置项结合、哪些平台禁用；GF 只负责预设采样、channel 混合、生命周期和设备路由。

## 典型流程

```gdscript
var haptics: GFHapticUtility = Gf.get_utility(GFHapticUtility) as GFHapticUtility

var preset: GFHapticPreset = GFHapticPreset.new()
preset.duration_seconds = 0.16
preset.weak_magnitude = 0.45
preset.strong_magnitude = 0.9

haptics.set_channel_strength(&"impact", 0.7)
var haptic_id := haptics.play_haptic(&"impact", preset, 0, 1.0, { "source": "hit" })
if haptic_id < 0:
	push_warning("震动请求未能进入逻辑播放队列")
```

`play_haptic()` 使用玩家索引，并通过 `GFInputDeviceUtility` 找到玩家当前手柄。`play_haptic_for_device()` 可直接指定 Godot 手柄设备 ID，适合设置页面测试设备反馈。正播放 ID 只表示请求已进入逻辑播放队列，不表示物理设备已经接受；参数、目标或容量拒绝才直接返回 `-1`。

## 采样与输出

`GFHapticPreset.sample()` 返回 `weak_magnitude`、`strong_magnitude`、`intensity` 和 `progress`。非有限时长、强度、进度与曲线结果都会在进入状态或 provider 前收束；preset 的非法时长按 0 处理并拒绝播放。输出刷新持续时间始终是有限正数，0 不会被透传为平台的“无限震动”。

`GFHapticUtility.tick()` 默认会在推进播放状态后自动调用 `apply_current_outputs()`，以一次线性分组按物理目标合成全部活跃 channel，并刷新设备震动。`auto_apply_on_tick=false` 只关闭 tick 的隐式刷新；`stop_haptic()`、`stop_channel()`、`stop_player()`、`stop_device()` 与 `clear()` 仍会立即尝试撤销已经输出的目标。

项目需要接入自定义平台 SDK、远程设备或测试替身时，优先实现 `GFHapticBackend` 并赋给 `haptic_backend`。backend 必须成对实现 `start_output()` 和 `stop_output()`；只有 start 返回 `true` 才表示物理接受。一次成功 start 会把该物理目标绑定到启动它的 backend，后续 refresh、stop 与失败重试不会因公开 provider 字段被替换而转发给另一个 owner。

只需要临时桥接时，也可以成对设置 `output_handler` 和 `stop_handler`。只配置其中之一会整体拒绝输出，避免启动无法配对停止的副作用。回调适合简单测试或单项目适配；backend 更适合长期维护的跨平台适配器，因为它有明确的协议类和可重写钩子。

`apply_current_outputs()` 返回 JSON-safe 输出报告：成功输出在 `applied`，成功停止在 `stopped`，停止失败在 `failed_stops`，路由不可用或 provider 拒绝在 `rejected`。自动 tick 无法把返回值交给调用方时，可读取 `get_last_output_report()`；后续无活动空刷新不会抹掉最近一次拒绝或终止失败。`get_haptic_info()` 与 `get_debug_snapshot()` 也保持 JSON-safe。

普通停止失败会保留原 owner 和 pending target，供下一次 apply 重试。`dispose()` 会通过原 owner 做最后一次停止尝试，然后释放 provider；若仍失败，`get_last_output_report()` 保留 terminal `failed_stops`，但不会留下已经失去 owner 的伪可重试目标。同一物理手柄同时被玩家目标和设备目标命中时，只会输出一次合成结果。

## 注意事项

`GFHapticUtility` 不保存业务事件队列，也不会规定 channel 名称。建议把全局震动开关、无障碍强度倍率、平台能力检测和冷却节流放在项目表现层，再把最终强度传给 GF。

把 `max_active_haptics` 设为小于等于 0 会取消逻辑实例上限；GF 不替项目选择绝对实例数、metadata 图、报告条目或平台持续时间预算。来自网络、Mod 或其他不可信来源的请求，应先在项目入口执行容量、深度、持续时间与 metadata 白名单检查。
