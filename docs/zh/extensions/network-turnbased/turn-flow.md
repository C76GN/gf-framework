# TurnBased 通用回合流程

这一页说明 `GFTurnFlowSystem` 如何推进阶段、收集行动并按优先级解析。具体参与者、目标规则和行动效果由项目层定义。

## 通用回合流程 (`GFTurnFlowSystem`)

`GFTurnFlowSystem` 提供阶段推进、行动入队和优先级解析。它适合承载“先收集行动，再按排序规则解析”的通用流程，但不定义参与者字段、目标规则或行动效果。

`GFTurnPhase` 是可扩展的阶段协议，每次运行态归属当前 context；`GFTurnAction` 是一次性行动请求，首次入队后配置冻结，离队后保持 sealed，重试需要创建新实例。

```gdscript
class_name ResolvePhase
extends GFTurnPhase


func execute(context: GFTurnContext) -> Variant:
	var flow := Gf.get_system(GFTurnFlowSystem) as GFTurnFlowSystem
	flow.resolve_actions()
	return null
```

```gdscript
var flow := GFTurnFlowSystem.new()
flow.set_phases([
	ResolvePhase.new(),
])

flow.start()
flow.enqueue_action(GFTurnAction.new(actor_a, [target_b], { "value": 10 }, 1, 20.0))
flow.advance_phase()
```

默认排序规则是 `priority` 降序，然后 `sort_value` 降序。需要项目自定义排序时，可向 `resolve_actions(order_resolver)` 传入比较回调。阶段和行动如果返回 Signal，系统会通过 `signal_timeout_seconds` 和当前流程 serial 做安全等待；`stop()` 或超时后不会继续调用旧阶段的 `exit()`，也不会把旧行动标记为 resolved。`resolve_actions()` 在上一批行动仍等待时会拒绝重入，避免同一批行动被重复解析。

参与者对象可能在流程中被释放。`GFTurnContext.cleanup_invalid_actors()` 可显式移除失效参与者并清空失效的 `current_actor`，`GFTurnFlowSystem` 在推进和解析边界也会同步清理当前上下文。项目仍然应在行动效果层处理目标失效、死亡、离场或替换这类业务语义；TurnBased 只负责不让无效 Object 引用继续驱动通用流程。

## 与权威状态和表现队列的组合边界

需要同时支持回合排序、撤销重做和有序表现时，应由项目自己的 Coordinator 或 Installer 组合三种机制。GF 内置扩展不会互相探测，也不会把这套可选组合固化成新的跨扩展类型。

| 机制 | 在组合中的职责 | 不应承担的职责 |
| --- | --- | --- |
| `GFTurnAction` | 保存一次性行动请求，参与入队、排序、取消和解析时机调度 | 直接充当权威状态、撤销快照或表现队列 |
| 项目自有 `GFUndoableCommand` | 校验业务前置条件，在修改前保存纯数据快照，并原子修改或恢复权威 Model | 决定回合排序，或用 Tween、节点状态代替权威数据 |
| `GFActionQueueSystem` | 在权威命令成功提交后，按顺序、并行组或命名流播放视觉、音频和等待动作 | 提交玩法状态、决定命令是否成功，或充当撤销栈 |

推荐的项目侧顺序是：

1. `GFTurnFlowSystem` 选择并解析一个 `GFTurnAction`；项目行动只把稳定输入交给 Coordinator。
2. Coordinator 创建新的项目 `GFUndoableCommand`，通过 `GFCommandHistoryUtility` 的同步或异步入口提交权威状态。命令失败时由项目保留失败结果，不把表现完成误当成业务成功。
3. 命令成功后，Coordinator 从已提交结果构建 `GFVisualAction`，再交给 `GFActionQueueSystem`。表现动作读取结果快照或当前只读状态，不回写权威 Model。
4. 撤销或重做仍只经过命令历史；界面和场景表现根据恢复后的权威状态重新同步，或由项目追加补偿表现。反向播放 Tween 不能替代状态恢复。

参见[可撤销命令历史](../../standard/input-flow/command-sequence/undo-history.md)和[视觉动作与入队](../action-queue/visual-actions/index.md)。如果项目不需要撤销或演出，只使用对应机制即可，不要为了统一形态创建空命令、空行动或空表现步骤。
