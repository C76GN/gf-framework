# 配置化 Tween 动作

如果表现动画需要被多个界面、实体或流程复用，可以把属性 Tween 抽成资源配置，再生成动作交给队列。

## 创建配置动作

```gdscript
var config := GFTweenActionConfig.new()
config.add_property_step(^"position", Vector2(400, 300), 0.25)
config.add_property_step(^"modulate", Color.WHITE, 0.12)

q_sys.enqueue(config.create_action(card_node))
```

`GFTweenActionConfig` 只描述属性路径、目标值、时长、缓动和并行关系。每一段属性变化由 `GFTweenActionStep` 保存，支持延迟、相对值、并行、transition、ease、可选 `easing_curve` 和 `marker_id`。

## 自定义缓动曲线

`GFTweenActionStep.easing_curve` 默认为 `null`，继续使用 `transition_type` 和 `ease_type`。设置原生 `Curve` 后，它会替代这两个预设：Godot Tween 先提供线性时间进度，再由 `Curve.sample_baked()` 得到属性插值进度，不叠加第二层预设缓动。

可以在 Inspector 的步骤资源中创建或指定 `Curve`，使用 Godot 自带曲线编辑器调整，也可以用代码创建：

```gdscript
var easing: Curve = Curve.new()
easing.bake_resolution = 128
var _start_index: int = easing.add_point(Vector2.ZERO)
var _middle_index: int = easing.add_point(Vector2(0.35, 0.15))
var _end_index: int = easing.add_point(Vector2.ONE)

var config: GFTweenActionConfig = GFTweenActionConfig.new()
var movement: GFTweenActionStep = config.add_property_step(
    ^"position", Vector2(240, 0), 0.6
)
movement.easing_curve = easing
```

这段配置让属性在前段缓慢变化，再到达目标值。曲线横轴表示 `0..1` 时间进度，纵轴表示插值进度；曲线可以回弹或超调，输出不会被截到 `0..1`。需要超调控制点时，先在原生曲线编辑器中扩大纵轴编辑范围。

| 约束 | 要求 |
| --- | --- |
| 资源 | 原生 `Curve`，不能附带脚本 |
| 横轴 | `min_domain = 0`、`max_domain = 1`；点的 x 严格递增 |
| 控制点 | 2–256 个；首尾必须精确为 `(0, 0)` 和 `(1, 1)` |
| 数值 | 控制点与左右切线有限；纵轴编辑范围有限、覆盖 `0..1`，并包含控制点的 y 值 |
| 烘焙 | `bake_resolution` 为 2–1000；实际使用的烘焙输出有限且绝对值不超过 16 |

输出限制针对 `sample_baked()` 使用的结果，不保证未烘焙曲线在任意位置的极值。每个属性 Tweener 持有独立的原生曲线副本；创建后修改源曲线不会改变该 Tweener 的求值。重新播放会采用修改后的曲线。

`duplicate_step()` 和 `duplicate_config()` 会深复制有效曲线；无效曲线会使复制返回 `null` 并给出警告，调用方应先校验并检查复制结果。`apply_instant()` 和强制 `finish()` 不沿曲线求中间值，仍按已有规则应用终点及恢复策略。

## 执行前校验

`GFTweenActionStep.can_apply_to(target)` 和 `get_validation_error(target)` 可在执行前检查目标属性是否存在、目标值类型是否兼容，以及缓动曲线是否有效。absolute 步骤接受相同 Variant 类型或 `int` / `float` 数值互转；relative 步骤当前支持数值、`Vector2`、`Vector3` 和 `Color` 的同类相加。`GFTweenActionConfig.get_validation_report(target)` 会把整组步骤整理成 `GFValidationReport`，便于 Inspector、CI 或项目工具统一展示。

运行时通过 Tween 执行步骤时，无效步骤会被跳过并给出警告；编辑器预览则拒绝整组配置并显示原因，避免把不完整的效果当成成功预览。直接应用终点不需要有效的缓动曲线，但目标属性和值仍须有效。

## 标记点与恢复

`create_action(target)` 会生成 `GFConfiguredTweenAction`，由它在执行时创建 Tween、追加步骤，并返回 `GFVisualAction` 的动作完成信号。

步骤设置 `marker_id` 后，动作会在对应步骤结束时发出 `marker_reached(marker_id, step_index, target)`。标记回调与对应属性 Tweener 位于同一调度组，不会让后续 `parallel = true` 步骤退化为串行。项目可以把它用于通用时间点通知，而不需要把动画资源绑定到具体业务回调。

`restore_initial_values_on_cancel` 和 `restore_initial_values_on_finish` 可让动作在取消或完成时恢复播放前捕获的属性值，适合编辑器预览或可回滚表现；它只恢复被步骤引用的属性，不隐藏、释放或重排节点。

取消或强制完成会唤醒队列等待，但不会手动伪造 Godot `Tween.finished`，因此外部监听者不会把取消误判为 Tween 自然播放结束。具体节点含义、动画命名和业务时机仍由项目层决定。

## 在 Inspector 中预览

启用 `gf.action_queue` 扩展后，选中 `GFTweenActionConfig` 资源，Inspector 顶部会出现 **Tween 预览**。选择与配置匹配的 2D、UI 或 3D 样机，即可查看串行、并行、延迟、相对值和缓动的效果。展开 **样机初值** 可以调整本次预览的起点；这些值不会写回配置。

| 操作 | 行为 |
| --- | --- |
| 播放 | 从样机初值开始，读取当前配置的快照 |
| 暂停 / 继续 | 冻结画面，再从暂停的位置继续同一次预览 |
| 时间滑条 / 秒数输入 / 定位 | 定位到已捕获时间轴中的时刻并暂停；定位按钮可重复检查同一时刻 |
| 停止 | 终止播放，保留画面和可定位的快照；再次播放从初值读取最新配置 |
| 复位 | 终止本次预览、丢弃定位快照并恢复样机初值 |

先点击一次播放以捕获配置，时间控件才会启用。定位始终使用该次捕获的步骤、曲线纯值快照和样机初值，不会读取之后修改的配置。要查看最新配置或曲线，请停止后重新播放。定位会暂停画面，点击继续从所选时刻向前播放；时间滑条显示串行组与并行组形成的实际时长，包含延迟、时长缩放和有限循环，而非所有步骤时长简单相加。

定位到时间轴末端时会保留动画终值，方便检查最后姿态；此时点击继续才执行正常完成策略。正常播放完成遵循 `restore_initial_values_on_finish`，完成后仍能定位检查同一快照。全零时长配置仅应用一轮瞬时步骤；点击定位按钮检查其唯一的 `0` 秒位置，可查看这一轮的终值，不累计多次相对偏移。

改变样机初值、切换配置、切换样机、隐藏预览或关闭 Inspector 会丢弃旧定位快照，必须重新播放后才能定位。定位与重放只作用于独立样机，不提供运行时动作倒放或业务回调回滚。

样机支持以下属性，以及向量的 `x` / `y` / `z`、颜色的 `r` / `g` / `b` / `a` 分量路径，例如 `position:x`、`modulate:a`。

| 样机 | 属性 |
| --- | --- |
| 2D | `position`、`rotation`、`rotation_degrees`、`scale`、`modulate`、`self_modulate` |
| UI | 2D 属性，加上 `size`、`pivot_offset` |
| 3D | `position`、`rotation`、`rotation_degrees`、`scale` |

2D 与 UI 位置以画布中心为原点，3D 使用独立相机。属性读数可以辅助观察移出画面的目标。预览使用工具自己创建的节点，不操作当前场景，不执行项目脚本或步骤标记通知，也不产生撤销记录。它采用独立的编辑器时钟，运行时的 `process_mode`、`pause_mode` 和 `ignore_time_scale` 不参与预览调度。

预览只接受原生 `GFTweenActionConfig` 和 `GFTweenActionStep` 资源，暂不执行自定义子类、对象目标值或任意嵌套资源属性。目标值及样机初值须为类型匹配的有限数值、`Vector2`、`Vector3` 或 `Color`，各数值分量绝对值不超过 1,000,000。单次预览最多 128 个步骤、32 次有限循环；按全部步骤的缩放后时长与延迟之和乘循环次数计算，保守预算上限为 120 秒，时间轴实际时长可以更短。自定义曲线除满足前述单条约束外，整组累计最多 65,536 个烘焙样本和 4,096 个控制点。

定位通过从初值与快照重建原生 Tween 并向前求值完成，不逐帧追赶，也不更换插值算法。无限循环、无效曲线与超出预算的配置会在播放前显示原因。步骤数、循环数、总时长及整组曲线预算只约束编辑器预览，不限制运行时的组规模。
