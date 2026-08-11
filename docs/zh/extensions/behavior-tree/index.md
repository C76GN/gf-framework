# BehaviorTree 纯代码行为树

BehaviorTree 扩展提供轻量的纯代码行为树。它适合敌人、NPC 或自动化流程中比状态机更灵活的优先级决策，但不绑定编辑器树、业务类型、异步任务取消或黑板字段规范。

## 核心模型

- `BTNode` 是行为树节点基类，`tick(blackboard)` 返回 `FRESH`、`SUCCESS`、`FAILURE`、`RUNNING` 或 `ABORTED`。
- `Sequence`、`Selector`、`Parallel` 和随机组合节点负责编排子节点。
- `Inverter`、`AlwaysSucceed`、`Cooldown`、`TimeLimit`、`Repeat` 等装饰器只改变控制流，不解释业务语义。
- `Runner` 持有根节点、黑板和运行时副本，并提供 tick 统计和调试快照。

## 最小流程

```gdscript
var check_hp := GFBehaviorTree.Condition.new(func(bb): return bb.hp < 30)
var flee_act := GFBehaviorTree.Action.new(func(_bb): return GFBehaviorTree.Status.SUCCESS)
var attack_act := GFBehaviorTree.Action.new(func(_bb): return GFBehaviorTree.Status.SUCCESS)

var root := GFBehaviorTree.Selector.new([
	GFBehaviorTree.Sequence.new([check_hp, flee_act]),
	attack_act,
])

var runner := GFBehaviorTree.Runner.new(root)
runner.blackboard = {"hp": 100}
runner.tick()
```

## 运行态与调试

`Sequence` 和 `Selector` 会在子节点返回 `RUNNING` 时保留当前子节点索引，下次 `tick()` 从该位置继续；返回终态后重置索引。`RandomSelector`、`RandomSequence` 和 `Probability` 可传入 `RandomNumberGenerator`，便于固定种子测试、回放或模拟。

`Runner` 默认通过 `duplicate_runtime()` 复制运行树，让同一棵配置树可以安全交给多个 agent。自定义节点必须在需要复制运行树时重写 `duplicate_runtime()` 并返回保持相同动态脚本类型的新实例；这也适用于继承 `Sequence`、`Decorator` 等具体内置节点的子类。默认实现、返回自身或发生类型切片都会生成显式失败节点并记录错误。确实需要共享实例的高级场景，应显式使用 `GFBehaviorTree.Runner.new(root, false)`。

同一个 `Runner` 的 `tick()` 不支持同步重入。Action 回调或同步 Signal 链再次调用同一 Runner 时，内层调用会记录错误并返回 `ABORTED`，不会第二次推进根节点游标。`Cooldown` 从子节点返回终态并完成 `reset()` 后重新采样单调时钟，子节点自身耗时不会抵扣冷却窗口。

`BlackboardScope` 可通过 `set_parent()` 组合父级读取链。该入口会拒绝形成循环的父级关系，避免 `get_value()`、`has_value()` 或调试导出在错误黑板图中递归失控。构造、`set_value()`、`get_value()` 与 `to_dictionary()` 使用循环安全的集合副本；公开 `values` 字段则是当前作用域的 live mutable storage，直接写入会绕过这些复制边界。

`get_debug_snapshot()` 会输出根节点状态、tick 次数、耗时和黑板键；节点和 Runner 都可以清理调试状态，便于测试断言或运行时面板刷新。`GFBehaviorTree.build_debug_snapshot(node, options)` 可限制 `max_nodes`、`max_depth`、`max_children`、`max_blackboard_keys`、`max_text_length` 和 `max_total_bytes`。内建节点返回已持有的子节点集合后，节点数、深度和单节点子项会在递归前限流；Runner 的黑板键会在完整物化前限流。项目自定义 `_get_debug_children()` 必须自行保证 override 内部构造有界，GF 只能限制其返回后的遍历。节点快照通过 `child_count`、`captured_child_count`、`omitted_child_count`、`truncated` 和 `truncation_reason` 说明遗漏原因，顶层 `debug_budget` 汇总实际遍历节点数和结构截断原因；空子节点槽使用稳定原因 `null_child`。

整棵原始快照只在末端进入一次 `GFReportValueCodec`。因此 metadata 中的循环、Object、Callable、非 JSON Variant、文本、集合、节点数和总字节统一使用框架报告编码规则投影，不会保留 live Object / Callable；递归回边使用 `cycle`，已经完整展开过但不在当前递归栈中的同一行为树节点使用 `shared_reference`，不会再把共享引用误报为循环。编码预算耗尽时会返回报告 codec 的结构化 budget marker，而不是半编码 live 值。

Runner 的调试快照只迭代并输出受 `max_blackboard_keys` 限制的排序键样本，同时报告完整 `blackboard_key_count`；它从不读取或输出黑板值。这里的遍历期保证只适用于 `BTNode` 和 `Runner`。传入仅实现 `get_debug_snapshot()` 的通用 Object 时，对象方法必须先自行构造返回值，GF 只能对返回值执行有界 post-projection，无法约束第三方方法内部的工作量。

`TimeLimit(0)` 表示立即超时，不会先执行一次子节点。`UntilSuccess` / `UntilFail` 会把子节点的非目标终态视为一次完整尝试，并在下一次重试前 reset 子节点，避免上一次尝试的运行态泄漏到下一轮。

## 使用边界

BehaviorTree 只提供节点组合、运行态复制、随机控制和调试快照。具体 AI 感知、目标选择、技能释放、导航、动画、网络同步和长期状态仍应由项目系统、黑板数据或项目自定义节点负责。

`reset()` 是运行态重置通知，不是通用异步取消确认；内置 `Action` 也没有外部任务 owner/cancel 协议。项目若在节点外启动网络、导航、Timer、线程或信号等待，必须由项目自定义节点在自己的 `reset()` 中终止/隔离旧代际，或由外部系统明确持有其生命周期。`Decorator.set_child()` 会先 reset 被替换的旧 child，但框架不会把这个同步调用伪装成外部工作已经取消完成。

## API Reference

完整类、方法和信号列表见 [Behavior Tree API Reference](../../reference/api/extensions-behavior-tree.md)。
