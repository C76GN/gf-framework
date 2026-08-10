# Feedback 反馈采样

Feedback 扩展提供通用反馈采样和可选场景接收器。它只输出 `position`、`rotation_degrees`、`scale` 这类通用偏移，不知道目标是 Camera、角色、Control 还是项目自定义对象。

## 阅读入口

- [反馈采样](shake-sampling.md)：`GFShakePreset`、`GFShakeUtility`、命名 channel、单波形和多轨道采样。
- [手柄震动反馈](haptic-feedback.md)：`GFHapticPreset`、`GFHapticUtility`、玩家/设备目标、channel 强度和输出回调。

## 使用边界

Feedback 不定义事件来源、视觉对象、音效、动画、表现队列或命中结果。项目可以直接读取采样值并应用到相机、UI、角色、shader 参数或自定义表现系统。

手柄震动只处理弱/强马达的采样、合成与设备路由。命中类型、技能来源、冷却、无障碍选项、平台差异和表现优先级仍应由项目侧决定。

## 接收器与表现队列

`GFShakeReceiver2D` 和 `GFShakeReceiver3D` 是可选场景桥接节点。它们记录目标节点的基础变换，并把某个 channel 的采样叠加到目标上。

接收器按“上一帧已应用偏移”做差量更新，因此正常采样期间的外部变换不会被下一次反馈覆盖。`target_path` 表达持续路径意图：目标暂时消失后，同一路径重新出现兼容节点时会自动重绑并重新建立基准。

恢复语义取决于 `capture_on_ready`：已捕获基准时，`reset_to_base()` 恢复完整基准快照；未捕获基准时，只减去接收器最后一次偏移。一个 transform 应只有一个负责完整基准恢复的 owner；多个 receiver 或绝对 transform writer 共用目标时，应在项目层使用父子节点分层或统一合成器，避免一个 owner 的恢复覆盖另一个贡献。

如果项目需要把反馈纳入表现队列，应在项目代码、外部扩展或独立插件中把 `GFShakeUtility.play_shake()` 包装成自己的队列动作。

## API Reference

完整类、方法和信号列表见 [Feedback API Reference](../../reference/api/extensions-feedback.md)。
