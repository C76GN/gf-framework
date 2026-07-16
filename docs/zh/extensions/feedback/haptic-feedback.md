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
haptics.play_haptic(&"impact", preset, 0, 1.0, { "source": "hit" })
```

`play_haptic()` 使用玩家索引，并通过 `GFInputDeviceUtility` 找到玩家当前手柄。`play_haptic_for_device()` 可直接指定 Godot 手柄设备 ID，适合设置页面测试设备反馈。

## 采样与输出

`GFHapticPreset.sample()` 返回 `weak_magnitude`、`strong_magnitude`、`intensity` 和 `progress`。`GFHapticUtility.tick()` 默认会在推进播放状态后自动调用 `apply_current_outputs()`，按目标合成全部活跃 channel，并刷新设备震动。

项目需要接入自定义平台 SDK、远程设备或测试替身时，优先实现 `GFHapticBackend` 并赋给 `haptic_backend`。backend 通过 `start_output()` 和 `stop_output()` 接收目标类型、目标 ID、强度、持续时间和 metadata，可以把输出转发给平台 SDK、外设插件或项目输入系统；返回 `false` 表示后端拒绝或未处理本次输出。

只需要临时桥接时，也可以设置 `output_handler` 和 `stop_handler`。回调适合简单测试或单项目适配；backend 更适合长期维护的跨平台适配器，因为它有明确的协议类和可重写钩子。

`apply_current_outputs()`、`get_haptic_info()` 和 `get_debug_snapshot()` 返回 JSON-safe 报告。停止输出失败会保留在 `failed_stop_count` / `failed_stops` 中；同一物理手柄同时被玩家目标和设备目标命中时，只会输出一次合成结果。

## 注意事项

`GFHapticUtility` 不保存业务事件队列，也不会规定 channel 名称。建议把全局震动开关、无障碍强度倍率、平台能力检测和冷却节流放在项目表现层，再把最终强度传给 GF。

停止 channel、玩家或设备时，工具会清理播放实例，并在下一次输出刷新时停止上一帧仍在震动的目标。若关闭 `auto_apply_on_tick`，调用方需要在 `tick()` 或停止操作后显式调用 `apply_current_outputs()`，否则 GF 不会隐式刷新设备输出。
