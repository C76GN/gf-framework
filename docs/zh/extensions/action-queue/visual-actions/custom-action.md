# 自定义 Action

耗时动作应在 `execute()` 中返回可等待的 `Signal`；立即完成或 fire-and-forget 动作可以返回 `null`。

```gdscript
class_name PlayCardVisualAction
extends GFVisualAction

var target_card: CardNode

func execute() -> Variant:
	var tween := target_card.create_tween()
	tween.tween_property(target_card, "position", Vector2(400, 300), 2.0)
	return tween.finished
```

自定义动作如果持有 Tween、Timer、临时信号连接或外部任务，应重写 `cancel()` 清理这些副作用，并释放正在等待该动作完成的调用点。

基础 `GFVisualAction.cancel()` 不知道项目动作内部资源，默认不做处理。

队列在委托 `cancel()`、`pause()`、`resume()` 或 `finish()` 时会阻止同一控制回调同步反调协调器，以保证一次控制转换有界。自定义 hook 仍应保持幂等，并避免把新的业务流程塞进控制回调；需要启动下一段流程时应在回调返回后调度。

duck-typed 动作可以实现 `should_wait_for_result(result)`，但返回 `true` 时 `execute()` 的结果必须是 `Signal`。违反该契约会产生受控错误，当前结果按不可等待处理，队列不会把任意 `Variant` 强制转换成 `Signal`。

等待 Signal 的动作默认有 30 秒超时，`with_signal_timeout(seconds, respect_time_scale)` 可调整超时时间，并默认跟随 `GFTimeUtility` 的暂停与 `time_scale`。有限且小于等于零的值会归零并禁用超时；`NaN` 和正负无穷不会覆盖已有设置。

当前 timeout 只解除队列等待并继续后续动作，不会自动调用超时动作的 `cancel()`。因此仍可能运行的外部任务必须自行实现超时终止，或在调用方明确管理其 detached 生命周期。

Signal 可以带任意载荷参数，动作队列只把发射本身视为等待完成，不解释参数内容。

## 结束等待与自然成功

表现动作的完成信号用于释放等待者。内置动作在取消、强制完成或被替换时，也可能发出这类通知；单凭信号不能判断动画是否自然播完。`GFWaitAction` 的取消则不发出 `wait_completed`，由动作组或队列结束自己的等待。业务成功应由项目的明确状态或事件表达，不应从表现完成信号推断。

`GFAsyncWaitUtility` 的取消令牌只结束该次等待，不会停止被等待的 Tween、动作或外部任务。需要停止任务时，调用方还应使用任务自身的取消入口，并清理自己持有的连接。直接执行动作时，调用方负责这个生命周期；入队后则由所属队列管理当前动作。重播或页面退出前，先撤销旧回调，再取消旧动作，避免旧结束通知更新新一轮界面。
