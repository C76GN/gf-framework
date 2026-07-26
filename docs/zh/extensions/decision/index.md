# Decision 效用决策

Decision 扩展提供不依赖 LLM 的通用决策底座。它适合 NPC 行为选择、自动化系统调度、AI Director 节奏控制或项目内任意“多个候选按当前状态打分并选最优”的场景。

它只处理黑板、上下文、效用评分和候选选择，不规定行动执行、NPC 社交、人设、剧情生成或具体游戏业务规则。

## 核心模型

- `GFDecisionBlackboard` 保存项目定义的运行时键值，并提供变更信号与调试快照。
- `GFDecisionContext` 组合黑板、主体、目标和元数据，考虑项可从这些来源读取输入。
- `GFDecisionConsideration` 将一个输入值映射为 0 到 1 的分数，可使用 min/max、响应曲线、反转和权重。
- `GFDecisionOption` 表示一个候选决策，按乘法、加权平均、求和、最低分或最高分聚合考虑项。
- `GFDecisionSet` 对多个候选评分并选择分数最高且满足最低分的结果。
- `GFDecisionEvaluation` 保存一次完整评估的候选分数、最佳结果和调试快照。
- `GFDecisionUtility` 在 GF 架构中注册决策集合，便于 System 或项目 Installer 统一调用。

评分边界统一收敛到有限的 0 到 1，权重必须有限且非负。加权平均会先按最大权重缩放再求和，极大但合法的权重不会形成 `INF / INF`；SUM 使用饱和贡献，非法或非有限输入不会进入排序器。候选分数只在数值完全相等时按原始顺序打破平局，近似相等但更高的分数仍然获胜。

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

需要同时拿到所有分数、最佳候选和调试快照时，使用 `evaluate()`，避免先 `score_all()` 再 `select_best()` 造成二次评分：

```gdscript
var evaluation: GFDecisionEvaluation = decision_set.evaluate(context)
if evaluation.best_score.accepted:
	print(evaluation.to_report_dictionary())
```

编辑器、CI 或资源导入流程应在运行前调用 `GFDecisionConsideration.get_validation_report()`、`GFDecisionOption.get_validation_report()` 或 `GFDecisionSet.get_validation_report()`。这些报告会捕获缺失/重复 ID、非法聚合模式和非有限数值配置；运行时归一化是最后防线，不应替代作者态校验。

## 与行为树和 Flow 的关系

Decision 负责“选什么”，BehaviorTree 和 Flow 更适合“选中后怎么推进”。项目可以在行为树叶子、Flow 节点或 System tick 中调用 `GFDecisionSet.select_best()`，再由项目代码执行对应动作。

这种拆分能避免行为树后期堆满优先级分支，也能让导演系统、NPC、模拟生态和 UI 自动化复用同一套评分报告。

## 输入契约

`GFDecisionContext` 在分配主体和目标时先捕获 `get_decision_snapshot()`、`get_decision_values()` 或可存储属性，形成本次评价的快照视图。缺失 key 才会调用 `get_decision_value(key, fallback)` 并写入当前上下文的有界懒缓存；返回 `null` 表示显式输入值，返回传入 sentinel 才表示缺失。这样同一次评价不会因重复读取而反复触发 provider 副作用。

默认主动快照最多 `DEFAULT_MAX_SNAPSHOT_ENTRIES` 条，反射捕获最多 `DEFAULT_MAX_REFLECTION_PROPERTIES` 条；构造 `GFDecisionContext` 时可通过第五个 `capture_options` 参数收紧预算。预算耗尽后不会继续调用懒 provider，`get_debug_snapshot().capture_diagnostics` 会报告来源、数量、限制和截断状态。调试快照的 `subject_values`、`target_values` 与 `capture_diagnostics` 保持可直接按字符串键遍历的固定 JSON object 外壳，叶值再由 `GFReportValueCodec` 编码；遇到非字符串键、键规范化冲突或集合预算超限时会失败闭合为保真 marker。上下文复制容器但保留嵌套 Object/Resource 身份，并只通过弱引用暴露主体和目标，因此它是稳定的评价视图，不是对象图序列化器。

`GFDecisionBlackboard.values`、`GFDecisionContext.metadata`、`GFDecisionOption.considerations` 和 `GFDecisionSet.decisions` 是可编辑集合。直接修改这些集合不会触发黑板变更信号，也不会执行添加、移除方法中的空值检查；需要信号或校验语义时使用对应方法。

`GFDecisionConsideration.default_input` 用于输入缺失或没有配置 `input_key` 的情况；`missing_score` 用于输入存在但不是数字的情况。项目要把“缺失就是低分”表达出来时，应把 `default_input` 设为对应低值。

`GFDecisionSet.get_debug_snapshot(context, scores)` 把 `scores = null` 解释为“现场评分”，把显式空数组解释为“调用方已经提供完整且为空的预计算结果”。需要避免 provider 再次执行时，应传 `GFDecisionEvaluation.scores`，不要用空数组代替缺省参数。

通过 `GFDecisionUtility.register_decision_set(decision_set_id, decision_set)` 注册集合时，外部 ID 必须和资源内 `decision_set.decision_set_id` 一致；如果资源内 ID 为空，则注册入口会写入该 ID。这条规则让资源文件、运行时注册表和报告中的集合身份保持一致。

## 使用边界

- 不要把具体玩法字段写进 GF 扩展；黑板键、候选 ID 和元数据都由项目定义。
- 不要把候选选择和动作执行绑死；`GFDecisionScore` 只报告结果，动作执行应留在项目 System、行为树节点、Flow 节点或其他运行时服务中。
- 不使用 LLM Agent、Prompt、向量数据库或外部记忆服务；需要生成式代理时应作为项目或独立插件能力，不写入 GF 内置扩展。
- 长期规划、HTN 和复杂导演策略可以基于 Decision 的上下文与评分报告继续扩展，但不应破坏当前候选评分 API。
- 报告、日志和调试面板应优先使用 `get_debug_snapshot()` 或 `GFDecisionEvaluation.to_report_dictionary()`；Decision 的公开调试快照会统一经过 `GFReportValueCodec`，而 `to_dictionary()` 仍是进程内原生数据通道。

## API Reference

完整类、方法和信号列表见 [Decision API Reference](../../reference/api/extensions-decision.md)。
