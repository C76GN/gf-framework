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
