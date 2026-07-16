# 反馈采样

表现层如果需要相机抖动、UI 冲击、节点轻微扰动或任意按时间采样的反馈偏移，可以使用 `GFShakePreset` 描述曲线和轴权重，再由 `GFShakeUtility` 管理命名 channel 上的播放状态。

```gdscript
var shake := Gf.get_utility(GFShakeUtility) as GFShakeUtility

var preset := GFShakePreset.new()
preset.duration_seconds = 0.18
preset.frequency = 18.0
preset.sample_seed = 7
preset.position_axis = Vector3(6.0, 4.0, 0.0)
preset.rotation_axis_degrees = Vector3(0.0, 0.0, 1.2)

shake.play_shake(&"camera", preset, 1.0, { "source": "impact" })
var sample := shake.sample_channel(&"camera")
```

简单反馈可直接使用 `GFShakePreset` 上的单波形字段；需要把多段位移、旋转、缩放或不同波形组合在一起时，可添加 `GFShakeTrack`。轨道支持独立进度区间、包络曲线、波形曲线和混合模式，仍然只输出通用偏移采样，不绑定相机、角色、UI 或某个事件系统。

```gdscript
var track := GFShakeTrack.new()
track.start_progress = 0.0
track.end_progress = 0.35
track.position_axis = Vector3(4.0, 0.0, 0.0)
track.rotation_axis_degrees = Vector3.ZERO
preset.add_track(track)
```

## 查询与报告

`sample_channel()` / `sample_channels()` 返回运行时采样结果，适合直接叠加到相机、节点或项目自定义表现对象。`get_shake_info()` 与 `get_debug_snapshot()` 返回 JSON-safe 报告，metadata 中的 Object / Resource 会被转换为脱敏 marker，可直接交给诊断、日志、CLI 或 `JSON.stringify()`。
