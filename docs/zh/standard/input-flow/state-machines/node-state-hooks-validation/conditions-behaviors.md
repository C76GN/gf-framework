# 条件与行为资源

状态脚本可重写 `_can_enter()` 与 `_can_exit()` 作为进入/退出守卫。状态组会在守卫拒绝时发出 `transition_blocked`，并保持当前状态不变。守卫应优先保持无副作用；若守卫或 enter/pause/resume hook 同步发起新的状态操作，新事务优先，外层过时计划不会再写入历史或发出状态变化信号。

需要把可复用条件和行为放到资源里时，可以继承 `GFNodeStateCondition` 或 `GFNodeStateBehavior`，再挂到状态的 `enter_conditions`、`exit_conditions` 或 `behaviors` 数组上。

多个条件需要复用同一组 ALL / ANY / NONE 组合规则时，可以使用 `GFNodeStateConditionGroup` 包装子条件资源。条件组允许多个分支共享同一个无环子组；递归环、超过 64 层的嵌套或单次超过 4096 个已评估条件会失败关闭为 `false`，即使问题节点设置了 `invert` 也不会把结构错误反转为通过。`GFNodeStateMachineValidator` 会在运行前报告可静态发现的 `cyclic_condition_group` 与 `condition_group_depth_exceeded`。条件只依赖其他状态是否激活时，可以使用 `GFNodeStateActiveCondition` 读取同组状态名或 `Group/State` 路径；它不会解释具体业务状态含义。

条件会和脚本守卫一起决定是否允许切换。行为会在状态自己的 `_initialize()`、`_enter()`、`_exit()`、`_pause()`、`_resume()` 或 `_handle_state_event()` 之后运行，适合复用动画播放、音效、输入门禁、调试标记等横切逻辑。

```gdscript
class_name HasTargetCondition
extends GFNodeStateCondition


func _evaluate(state: GFNodeState, _phase: StringName, _peer_state: StringName = &"", _args: Dictionary = {}) -> bool:
	return state.get_blackboard().has("target")
```

```gdscript
class_name PlayStateAudioBehavior
extends GFNodeStateBehavior


func _enter(state: GFNodeState, _previous_state: StringName = &"", _args: Dictionary = {}) -> void:
	var host := state.get_host()
	if host != null and host.has_method("play_state_audio"):
		host.call("play_state_audio", state.get_state_name())
```

复杂状态仍应继续写成 `GFNodeState` 子类。Resource 钩子适合抽出可组合、可在 Inspector 复用的通用片段。

需要在同一状态组内共享少量运行时上下文时，可使用 `GFNodeStateGroup.blackboard` 或状态内的 `get_blackboard()`；字段含义仍由项目层决定。
