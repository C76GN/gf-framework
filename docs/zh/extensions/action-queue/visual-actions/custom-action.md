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

等待 Signal 的动作默认有 30 秒超时，`with_signal_timeout(seconds, respect_time_scale)` 可调整超时时间，并默认跟随 `GFTimeUtility` 的暂停与 `time_scale`。

当前 timeout 只解除队列等待并继续后续动作，不会自动调用超时动作的 `cancel()`。因此仍可能运行的外部任务必须自行实现超时终止，或在调用方明确管理其 detached 生命周期。

Signal 可以带任意载荷参数，动作队列只把发射本身视为等待完成，不解释参数内容。
