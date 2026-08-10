# 通用指令序列

`GFCommandSequence` 用于把一组步骤、命令对象或 callable 串行执行。它只处理顺序、等待和架构注入，不绑定任何项目规则。步骤可以继承 `GFSequenceStep`，也可以是实现了 `execute()` / `resolve()` 的普通对象。

`GFSequenceContext` 为一次序列执行保存开放但受控的共享值；`GFWaitSequenceStep` 是内置的纯等待步骤，用于在不引入项目节点或业务状态的情况下表达时间间隔。

## 自定义步骤

```gdscript
class_name WaitForTweenStep
extends GFSequenceStep

var target: Node2D


func execute(_context: GFSequenceContext) -> Variant:
	var tween := target.create_tween()
	tween.tween_property(target, "modulate:a", 0.0, 0.2)
	return tween.finished
```

## 运行序列

```gdscript
var context := GFSequenceContext.new()
var wait_step := GFWaitSequenceStep.new()
wait_step.duration = 0.2

var sequence := GFCommandSequence.new([
	WaitForTweenStep.new(),
	wait_step,
	func() -> void:
		print("sequence finished")
], context)

sequence.run()
```

## 使用边界

`step_started` 表示“即将执行”，不是副作用已经提交。它的同步监听器可以调用
`sequence.cancel()`；序列会在进入 `execute()` 前形成取消 cut，尚未执行的步骤也不会收到
`cancel()` hook。步骤已经进入 `execute()` 或正在等待 Signal 后再取消时，当前步骤才会收到
取消通知。

如果步骤返回 `Signal`，默认会等待。Signal 发出的第一个参数会作为该步骤结果继续进入失败策略判断；多个参数会以数组形式保留。因此异步步骤可以 `completed.emit({ "ok": false, "error": "..." })`，序列会像同步返回失败字典一样处理。

`GFWaitSequenceStep.duration` 和序列的 Signal timeout 只接受有限数值；非有限赋值会保留最近一次
有效值。取消正在等待的 `GFWaitSequenceStep` 时，步骤会把自己创建的 `SceneTreeTimer` 收敛到
下一帧终态，避免长时间计时器继续驻留到原始超时点。

`GFSequenceStep.wait_for_result = false` 可把某个步骤声明为不阻塞序列。需要取消、超时或失败回滚时，继续阅读 [取消、超时与失败策略](failure-cancel.md)。
