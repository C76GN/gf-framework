# 配置化 Tween 动作

如果表现动画需要被多个界面、实体或流程复用，可以把属性 Tween 抽成资源配置，再生成动作交给队列。

## 创建配置动作

```gdscript
var config := GFTweenActionConfig.new()
config.add_property_step(^"position", Vector2(400, 300), 0.25)
config.add_property_step(^"modulate", Color.WHITE, 0.12)

q_sys.enqueue(config.create_action(card_node))
```

`GFTweenActionConfig` 只描述属性路径、目标值、时长、缓动和并行关系。每一段属性变化由 `GFTweenActionStep` 保存，支持延迟、相对值、并行、transition、ease 和可选 `marker_id`。

## 执行前校验

`GFTweenActionStep.can_apply_to(target)` 和 `get_validation_error(target)` 可在执行前检查目标属性是否存在、目标值类型是否兼容。absolute 步骤接受相同 Variant 类型或 `int` / `float` 数值互转；relative 步骤当前支持数值、`Vector2`、`Vector3` 和 `Color` 的同类相加。`GFTweenActionConfig.get_validation_report(target)` 会把整组步骤整理成 `GFValidationReport`，便于 Inspector、CI 或项目工具统一展示。

无效步骤会被跳过并给出警告，避免把拼写错误推迟到 Tween 执行时才暴露。

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
| 停止 | 终止本次预览，保留当前画面；再次播放从初值开始 |
| 复位 | 终止本次预览并恢复样机初值 |

修改配置后需要重新播放。当前播放使用启动时的快照；切换配置、切换样机、隐藏预览或关闭 Inspector 会终止旧预览。正常完成遵循 `restore_initial_values_on_finish`；停止与复位使用上表中的工具操作语义。

样机支持以下属性，以及向量的 `x` / `y` / `z`、颜色的 `r` / `g` / `b` / `a` 分量路径，例如 `position:x`、`modulate:a`。

| 样机 | 属性 |
| --- | --- |
| 2D | `position`、`rotation`、`rotation_degrees`、`scale`、`modulate`、`self_modulate` |
| UI | 2D 属性，加上 `size`、`pivot_offset` |
| 3D | `position`、`rotation`、`rotation_degrees`、`scale` |

2D 与 UI 位置以画布中心为原点，3D 使用独立相机。属性读数可以辅助观察移出画面的目标。预览使用工具自己创建的节点，不操作当前场景，不执行项目脚本或步骤标记通知，也不产生撤销记录。它采用独立的编辑器时钟，运行时的 `process_mode`、`pause_mode` 和 `ignore_time_scale` 不参与预览调度。

预览只接受原生 `GFTweenActionConfig` 和 `GFTweenActionStep` 资源，暂不执行自定义子类、对象目标值或任意嵌套资源属性。目标值及样机初值须为类型匹配的有限数值、`Vector2`、`Vector3` 或 `Color`，各数值分量绝对值不超过 1,000,000。单次预览最多 128 个步骤、32 次有限循环；按全部步骤的缩放后时长与延迟之和乘循环次数计算，上限为 120 秒。无限循环与超出范围的配置会在播放前显示原因。这些范围只约束编辑器预览，不改变运行时的配置合同。
