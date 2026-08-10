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
