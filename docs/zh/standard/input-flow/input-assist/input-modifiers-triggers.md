# 输入修饰器与触发器

这一页说明动作值如何通过修饰器做通用数值处理，以及动作活跃状态如何通过触发器做时序判断。

## 修饰器与触发器

动作值可通过 `GFInputModifier` 组合处理，例如死区、缩放、归一化和范围映射；动作活跃可通过 `GFInputTrigger` 延迟判断，例如按下、释放、短按、长按、周期脉冲、组合动作和动作序列。修饰器可以挂在 Binding 或 Mapping 上，触发器挂在 Mapping 上，运行时仍只暴露抽象动作状态，不把移动、攻击或 UI 选择规则写进输入层。同一 `action_id` 出现在多个已启用上下文时，动作定义、Mapping 级修饰器和触发器按实际处理顺序采用第一个定义；也就是高优先级上下文会覆盖低优先级上下文的动作语义，低优先级上下文不会反向改写这些定义。

内置修饰器各自只处理通用数值变换：`GFInputDeadzoneModifier` 处理摇杆死区并可重映射剩余范围，`GFInputScaleModifier` 调节或反转轴分量，`GFInputNormalizeModifier` 限制二维/三维向量长度，`GFInputMapRangeModifier` 把输入范围线性映射到目标范围，`GFInputCurveModifier` 按 `Curve` 采样灵敏度或压力响应，`GFInputSwizzleModifier` 重排二维/三维分量，`GFInputMagnitudeModifier` 把多轴输入投影成幅值，`GFInputSignClampModifier` 只保留正向或负向分量，`GFInputVirtualCursorModifier` 把抽象速度积分为一个受限位置。`GFInputModifier` 提供通用运行时状态协议：无状态修饰器默认 no-op，有状态修饰器可通过 `supports_runtime_state()`、`get_modifier_runtime_state()`、`restore_modifier_runtime_state()` 和 runtime delta 入口参与回放或多人实例隔离。虚拟光标修饰器只维护数值坐标，不读取 Viewport 或 Control；若要移动真实节点、焦点或 UI 光标，应由项目层消费输出位置。内置触发器各自只处理通用动作时序：`GFInputPressedTrigger` 只在按下瞬间触发，`GFInputReleasedTrigger` 只在释放瞬间触发，`GFInputTapTrigger` 识别短按，`GFInputHoldTrigger` 识别长按，`GFInputPulseTrigger` 在持续输入时周期触发，`GFInputChordTrigger` 要求另一个动作同时活跃，`GFInputSequenceTrigger` 要求动作按顺序完成。组合键和动作序列都基于抽象 action id，不绑定具体键位。

同一 Binding 或 Mapping 上的 modifier 严格按资源数组顺序执行，非交换变换不会被重排。运行时会为每个 binding/mapping 复制 modifier；虚拟光标等有状态 modifier 即使复用同一配置 Resource，也不会在两个动作之间共享 position/ticks。`GFInputDeadzoneModifier` 允许 lower 与 upper 相等并把它解释为硬阈值：低于共同阈值输出 0，达到或超过阈值时在 rescale 模式输出满幅。

简单序列可继续使用 `GFInputSequenceTrigger.required_action_ids`。需要多条可替代路径、单步最大间隔、按住时间或释放完成条件时，使用 `GFInputSequenceBranch` 和 `GFInputSequenceStep` 描述资源化序列：

```gdscript
var step := GFInputSequenceStep.new()
step.action_id = &"charge"
step.min_hold_seconds = 0.2
step.trigger_on_release = true

var branch := GFInputSequenceBranch.new()
branch.steps = [step]

var trigger := GFInputSequenceTrigger.new()
trigger.branches = [branch]
```

`GFInputMappingUtility` 会同步记录动作的 just-started、just-completed 和最近一次完成前的持续时间，供释放型触发器或项目层读取。全局查询使用 `was_action_just_started(action_id)` / `was_action_just_completed(action_id)` / `get_last_completed_duration(action_id)`；本地多人使用对应的 `*_for_player()` 接口。一次性状态会保留到至少经过一次 GF System tick 的观察窗口后再清理：普通输入事件可在同帧 System 中消费，长按、短按或序列触发器在 Utility tick 中生成的动作可在下一次 System tick 中消费。持续时间只描述抽象动作状态，不包含具体按键、技能窗口或业务判定。

`player_scoped=true` 且 player index 有效时，Chord 要求 runtime 提供 `is_action_active_for_player()`，Sequence 要求完整的 player-specific active、just-started、just-completed 与 completed-duration 查询。缺少任一所需方法会 fail closed；框架不会把部分玩家查询与全局查询拼成一条混合时间线。`player_scoped=false` 或 player index 无效时才使用全局协议。

排查 `consume_action()` 没有触发时，先确认 `action_id` 与 `GFInputAction.action_id` 完全一致，包含大小写；确认对应 `GFInputContext` 已启用，且绑定的 `InputEvent` 类型与实际事件匹配；确认没有更高优先级上下文的动作通过 `block_lower_priority_actions` 阻断同一个输入；如果动作使用了 `Released`、`Tap`、`Hold`、`Pulse` 或 `Sequence` 触发器，还要按触发器语义检查它是在按下、释放、持续时间满足，还是序列完成时才会进入 just-started。

`GFInputAction.ValueType` 支持 `BOOL`、`AXIS_1D`、`AXIS_2D` 与 `AXIS_3D`。`GFInputBinding.ValueTarget.AUTO` 会按动作值类型自动产出贡献值，但二维/三维动作默认写入 X 分量；摇杆 Y、右摇杆、Z 轴或按钮方向应使用显式 `AXIS_2D_*` / `AXIS_3D_*` 目标。`get_action_vector()` / `get_action_vector_for_player()` 返回 `Vector2`；需要三维输入时使用 `get_action_vector3()` 或 `get_action_vector3_for_player()`。

## 周期脉冲的首次等待

`GFInputPulseTrigger.initial_delay_seconds` 将首次等待与后续 `interval_seconds` 分开设置。例如，按下时立即触发一次，持续输入 0.4 秒后开始每 0.08 秒重复：

```gdscript
var pulse := GFInputPulseTrigger.new()
pulse.trigger_immediately = true
pulse.initial_delay_seconds = 0.4
pulse.interval_seconds = 0.08
```

把触发器加入 Mapping 的 `triggers` 后，可用于菜单导航、数量调整或工具步进；具体动作、边界和循环规则由项目处理。计时状态按动作和玩家隔离，释放输入或重建上下文后重新开始首次等待。触发器配置 Resource 可以共享；修改首次等待会影响仍在等待的动作，已进入周期的动作在下次激活时采用新值。周期参数则在每次更新时读取。

`initial_delay_seconds` 默认为 `-1`，表示首次等待沿用 `interval_seconds`；所有有限负值都会归一为 `-1`，NaN/Infinity 赋值被拒绝并保留原值。`trigger_immediately=false` 时，首次脉冲也要等待该时长。首次等待为 `0` 时，激活当次只触发一个脉冲，无论 `trigger_immediately` 如何设置；之后仍等待正常间隔。

激活时若立即发出脉冲，则忽略当次 delta；若关闭立即触发且首次等待大于零，直接调用 `update()` 时，激活当次传入的 delta 也会计入等待，普通输入事件刷新则传入零。计时只使用有限正 delta，不读取墙钟；零值、负值或 NaN/Infinity delta 不推进计时。单次更新最多返回一个脉冲；跨过多个期限时仅保留有限的周期余数，不批量补发。

`action_started` 与 `consume_action()` 的一次性标记仍来自动作由不活跃变为活跃的转换。低帧率下连续更新都可能命中脉冲，因而不会为每个理论周期分别产生开始事件；这类周期输入不适合作为必须精确累计次数的计数器。
