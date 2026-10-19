# 多目标错峰动画

多个目标依次入场时，可以把每个目标的“等待再播放”组成并行动作组。第 `i` 项的计划等待为 `i * interval_seconds`；所有分支完成后，整组才结束。

```gdscript
var branches: Array = []
for index: int in range(targets.size()):
	branches.append(GFAction.sequence([
		GFAction.wait(float(index) * 0.08, host),
		GFAction.fade_to(targets[index], 1.0, 0.35),
	]))
var group: GFVisualActionGroup = GFAction.parallel(branches)
queue.enqueue(group)
```

`targets` 的顺序由调用方决定。渐显前由项目建立实际透明度初值，例如只把 `modulate.a` 设为 `0.0`，保留目标原有颜色。等待和分支启动遵循帧调度；这不是可任意定位的多轨道绝对时间轴。

## 运行与取消

队列拥有当前动作组。直接执行时，调用方持有动作组，并在页面退出或重播前调用 `cancel()`；暂停与恢复使用 `pause()`、`resume()`。取消不会启动尚在等待的后续目标；视觉恢复仍遵循具体动作的恢复策略，不能把取消当作自然播放成功。

需要保留中途姿态后重播时，应先取消旧组，再为新一轮建立初值和独立动作。不同项目对网格、距离、容器子节点或业务排序的规则应留在项目层。
