# 节点状态 Hook、资源片段与校验

这一组文档说明节点状态如何访问架构依赖、注册事件、组合条件与行为资源、分发状态事件，并在编辑器中执行结构校验。

## 阅读入口

- [依赖代理与事件注册](dependency-events.md)：`GFNodeState` 的架构代理和激活期事件监听。
- [条件与行为资源](conditions-behaviors.md)：`GFNodeStateCondition`、`GFNodeStateBehavior` 和脚本守卫。
- [编辑器模板与结构校验](editor-validation.md)：NodeState 模板、Inspector 初始状态选择和 `GFNodeStateMachineValidator`。

## 使用边界

这些资源基类只定义状态节点上下文和生命周期钩子，不规定动画命名、输入动作、AI 黑板字段或业务事件含义。

## 状态事件与快照

`GFNodeStateMachine.dispatch_state_event(event_id, payload, group_name)` 可以指定某个状态组，也可以在 `group_name` 为空时按已注册状态组顺序广播。单个 `GFNodeStateGroup` 会先交给当前状态，再交给暂停栈中的状态。状态脚本重写 `_handle_state_event()` 并返回 `true` 即表示事件已处理。

`get_state_snapshot()` 可返回各状态组当前状态、栈、历史、注册状态和黑板副本，适合调试面板或诊断命令消费。状态组和状态机快照都带 `schema_version = 1`；恢复入口只接受明确版本，不把任意调试字典当作恢复输入。

`restore_state_snapshot()` 会先校验所有目标状态、当前状态、暂停栈、历史上限和 blackboard，再进入恢复事务。恢复 hook 中触发的 transition、push、pop、增删状态、start/stop/reload 会被阻止并写入 `blocked_operations`；任一组恢复失败时，状态机按恢复前快照整体回滚。返回报告稳定包含 `report_schema_version`、`status`、`ok`、`restored`、`partial` 和 `rolled_back`。快照中多出的未注册 group 仍按 lenient policy 记入 `unrestored_group_snapshots` 与 `partial`，不会动态创建业务状态组。
