# Decision 效用决策

Decision 扩展提供不依赖 LLM 的通用决策底座。它适合 NPC 行为选择、自动化系统调度、AI Director 节奏控制或项目内任意“多个候选按当前状态打分并选最优”的场景。

它只处理黑板、上下文、效用评分和候选选择，不规定行动执行、NPC 社交、人设、剧情生成或具体游戏业务规则。

## 核心模型

- `GFDecisionBlackboard` 保存项目定义的运行时键值，并提供变更信号与调试快照。
- `GFDecisionContext` 组合黑板、主体、目标和元数据，考虑项可从这些来源读取输入。
- `GFDecisionConsideration` 将一个输入值映射为 0 到 1 的分数，可使用 min/max、响应曲线、反转和权重。
- `GFDecisionOption` 表示一个候选决策，按乘法、加权平均、求和、最低分或最高分聚合考虑项。
- `GFDecisionSet` 对多个候选评分并选择分数最高且满足最低分的结果。
- `GFDecisionUtility` 在 GF 架构中注册决策集合，便于 System 或项目 Installer 统一调用。

## 最小流程

```gdscript
var context: GFDecisionContext = GFDecisionContext.new(GFDecisionBlackboard.new({
	&"pressure": 0.8,
	&"stability": 0.3,
}))

var pressure: GFDecisionConsideration = GFDecisionConsideration.new()
pressure.consideration_id = &"pressure"
pressure.input_key = &"pressure"
pressure.input_min = 0.0
pressure.input_max = 1.0

var stabilize: GFDecisionOption = GFDecisionOption.new()
stabilize.decision_id = &"stabilize"
stabilize.considerations = [pressure]

var decision_set: GFDecisionSet = GFDecisionSet.new()
decision_set.decision_set_id = &"director"
decision_set.decisions = [stabilize]

var best: GFDecisionScore = decision_set.select_best(context)
if best.accepted:
	print(best.decision_id)
```

## 与行为树和 Flow 的关系

Decision 负责“选什么”，BehaviorTree 和 Flow 更适合“选中后怎么推进”。项目可以在行为树叶子、Flow 节点或 System tick 中调用 `GFDecisionSet.select_best()`，再由项目代码执行对应动作。

这种拆分能避免行为树后期堆满优先级分支，也能让导演系统、NPC、模拟生态和 UI 自动化复用同一套评分报告。

## 输入契约

`GFDecisionContext` 的主体和目标读取遵循轻量约定：如果对象实现 `get_decision_value(key, fallback)`，Decision 会优先调用它；当该方法返回传入的 fallback 时，继续尝试读取同名属性。这样项目可以只暴露需要参与评分的值，也可以直接复用简单脚本属性。

`GFDecisionBlackboard.values`、`GFDecisionContext.metadata`、`GFDecisionOption.considerations` 和 `GFDecisionSet.decisions` 是可编辑集合。直接修改这些集合不会触发黑板变更信号，也不会执行添加、移除方法中的空值检查；需要信号或校验语义时使用对应方法。

`GFDecisionConsideration.default_input` 用于输入缺失或没有配置 `input_key` 的情况；`missing_score` 用于输入存在但不是数字的情况。项目要把“缺失就是低分”表达出来时，应把 `default_input` 设为对应低值。

## 使用边界

- 不要把具体玩法字段写进 GF 扩展；黑板键、候选 ID 和元数据都由项目定义。
- 不要把候选选择和动作执行绑死；`GFDecisionScore` 只报告结果，动作执行应留在项目 System、行为树节点、Flow 节点或其他运行时服务中。
- 不使用 LLM Agent、Prompt、向量数据库或外部记忆服务；需要生成式代理时应作为项目或独立插件能力，不写入 GF 内置扩展。
- 长期规划、HTN 和复杂导演策略可以基于 Decision 的上下文与评分报告继续扩展，但不应破坏当前候选评分 API。

## API Reference

完整类、方法和信号列表见 [Decision API Reference](../../reference/api/extensions-decision.md)。
