# TurnBased 通用回合流程

这一页说明 `GFTurnFlowSystem` 如何推进阶段、收集行动并按优先级解析。具体参与者、目标规则和行动效果由项目层定义。

## 通用回合流程 (`GFTurnFlowSystem`)

`GFTurnFlowSystem` 提供阶段推进、行动入队和优先级解析。它适合承载“先收集行动，再按排序规则解析”的通用流程，但不定义参与者字段、目标规则或行动效果。

`GFTurnPhase` 是可扩展的阶段协议，每次运行态归属当前 context；`GFTurnAction` 是一次性行动请求，首次入队后配置冻结，离队后保持 sealed，重试需要创建新实例。

```gdscript
class_name ResolvePhase
extends GFTurnPhase


func _execute(
	context: GFTurnContext,
	_completion: GFTurnPhaseCompletionHandle
) -> Variant:
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

默认排序规则是 `priority` 降序，然后按有限 `sort_value` 降序；NaN 与正负 Infinity 统一排在有限值之后，并按入队顺序保持稳定。自定义 `order_resolver` 必须是无副作用、确定且满足严格弱序的 `func(a, b) -> bool`，并自行定义 non-finite 与平局规则。若比较器使当前 lease 失效，框架会停止后续比较器调用，并按排序前快照恢复或封存原始入队顺序；框架不会把非传递比较器改造成可重放顺序。

阶段和行动如果返回 Signal，系统会通过 `signal_timeout_seconds` 和当前流程 serial 做安全等待；`stop()` 或超时后不会继续调用旧阶段的 `_exit()`，也不会把旧行动标记为 resolved。`resolve_actions()` 在上一批行动仍等待时会拒绝同类重入，避免同一批行动被重复解析。`stop(true)` 的清理策略与停止通知分离：流程已经 stopped 时仍会幂等清空并封存队列，`stop(false)` 保留的在途行动也可由后续 `stop(true)` 升级为丢弃；重复调用不会重复发送 `flow_stopped`。

`auto_finish=false` 的手工阶段必须保存本次 `_execute()` 收到的精确 completion handle；timer、动画、网络或自定义 Signal 回调只调用这个句柄：

```gdscript
class_name AnimationPhase
extends GFTurnPhase


@export var animation_player: AnimationPlayer


func _init() -> void:
	auto_finish = false


func _execute(
	_context: GFTurnContext,
	completion: GFTurnPhaseCompletionHandle
) -> Variant:
	var connection_error: Error = animation_player.animation_finished.connect(
		func(_animation_name: StringName) -> void:
			if completion.try_complete():
				print("本次阶段已提交完成")
		,
		CONNECT_ONE_SHOT
	)
	if connection_error != OK:
		var _completed_after_connection_failure: bool = completion.try_complete()
		return null
	animation_player.play(&"resolve")
	return null
```

`GFTurnPhaseCompletionHandle.try_complete()` 只有在句柄仍对应当前精确 phase operation、且是首次提交时才返回 `true`。`stop()`、timeout、`dispose()`、正常收尾或同一 Context 上的后续 restart 都会让旧句柄返回 `false`，旧回调不会完成新代次。项目仍应断开不再需要的回调以释放自身资源，但正确性不再依赖按 Context 查找当前 runtime。

可变 `GFTurnContext` 由 operation-scoped claim 保护。不同 `GFTurnFlowSystem` 对同一 Context 的 `start()`、阶段推进或行动解析会在 round、phase、actor、队列和信号变化前失败关闭；最后一张 claim 释放后，另一个 system 可以顺序接管。相同 system 与相同 flow serial 可以同时持有精确 phase/action claim，因此阶段 `_execute()` 内调用同一 system 的 `resolve_actions()` 仍是受支持路径，且必须等两条 operation 都收尾后才释放 Context。不同 Context 可并行使用。这个合同只约束 GF Flow operation，不是线程锁，也不会拦截项目直接调用 Context 的公开 mutation API。

如果本 system 的 `flow_started` 同步观察者调用 `stop()`，随后的 `flow_stopped` 观察者又调用 `start(reset_indices)`，系统会保留首个重启请求，等外层 `flow_started` 通知展开完成且旧 claim 释放后同步重放；请求中的 `reset_indices` 会原样保留。重放前再次调用 `stop()` 或 `dispose()` 会取消它。这个特例只服务于同一 system 的该次通知链；foreign system 和普通在途 operation 不会被自动排队。

参与者对象可能在流程中被释放。`GFTurnContext.cleanup_invalid_actors()` 可显式移除失效参与者并清空失效的 `current_actor`，`GFTurnFlowSystem` 在推进和解析边界也会同步清理当前上下文。Context 对 RefCounted participant 采用强所有权，项目必须调用 `remove_actor()` 或释放 Context 才会释放该引用；Node 被 `free()` 后仍可由 cleanup 移除。`get_actor_value()` 只调用参数数量与类型兼容的 `get_turn_value(key, fallback)`，不兼容的同名方法会回退到属性读取；GDScript 无法捕获项目方法内部错误，项目实现仍须保证该回调安全返回。项目也应在行动效果层处理目标失效、死亡、离场或替换这类业务语义；TurnBased 只负责不让无效 Object 引用继续驱动通用流程。

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
