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

`Runner` 默认通过 `duplicate_runtime()` 复制运行树，让同一棵配置树可以安全交给多个 agent。自定义节点必须在需要复制运行树时重写 `duplicate_runtime()` 并返回自身类型的新实例；默认实现会生成显式失败节点并记录错误，避免多个 agent 意外共享同一个自定义节点实例。确实需要共享实例的高级场景，应显式使用 `GFBehaviorTree.Runner.new(root, false)`。

`BlackboardScope` 可通过 `set_parent()` 组合父级读取链。该入口会拒绝形成循环的父级关系，避免 `get_value()`、`has_value()` 或调试导出在错误黑板图中递归失控。

`get_debug_snapshot()` 会输出根节点状态、tick 次数、耗时和黑板键；节点和 Runner 都可以清理调试状态，便于测试断言或运行时面板刷新。调试快照会对 metadata 做 JSON-safe 转换，并在遇到循环节点时输出循环标记，而不是继续递归。

`TimeLimit(0)` 表示立即超时，不会先执行一次子节点。`UntilSuccess` / `UntilFail` 会把子节点的非目标终态视为一次完整尝试，并在下一次重试前 reset 子节点，避免上一次尝试的运行态泄漏到下一轮。

## 使用边界

BehaviorTree 只提供节点组合、运行态复制、随机控制和调试快照。具体 AI 感知、目标选择、技能释放、导航、动画、网络同步和长期状态仍应由项目系统、黑板数据或项目自定义节点负责。

## API Reference

完整类、方法和信号列表见 [Behavior Tree API Reference](../../reference/api/extensions-behavior-tree.md)。
