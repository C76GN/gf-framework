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

`tracks` 非空时始终选择轨道模式；只有空数组才读取兼容的单波形字段。`disabled`、`null` 或当前进度位于区间外的轨道不参与本次合成，因此“全部禁用”会得到零采样，不会意外回退到 legacy 波形。已经参与的轨道即使采样值恰好为零，仍按其 `blend_mode` 参与，这让显式 `OVERRIDE` 零值与“未参与”保持不同语义。

播放中的 preset 是共享 Resource。若运行时把持续时间改为 0、负数或非有限值，`GFShakeUtility` 会在下一次 `tick()` 终止该实例，不把非法时长解释为无限反馈。

## 场景接收器

`GFShakeReceiver2D` / `GFShakeReceiver3D` 可把 channel 采样叠加到场景节点。配置 `target_path` 后，目标节点暂时删除不会让路径绑定永久失效；同一路径重新创建兼容节点时，receiver 会自动重绑、清除旧目标偏移记录，并按 `capture_on_ready` 为新目标捕获基准。

正常采样使用差量偏移，可保留两帧之间的外部 transform 变化；但已捕获基准的 `reset_to_base()` 会恢复完整快照。多个 transform producer 应通过父子节点或项目合成器分层，不要让多个 receiver 同时拥有同一节点的完整基准恢复权。

## 查询与报告

`sample_channel()` / `sample_channels()` 返回运行时采样结果，适合直接叠加到相机、节点或项目自定义表现对象。`get_shake_info()` 与 `get_debug_snapshot()` 返回 JSON-safe 报告，metadata 中的 Object / Resource 会被转换为脱敏 marker，可直接交给诊断、日志、CLI 或 `JSON.stringify()`。
