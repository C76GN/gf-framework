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

`GFDecisionSet.select_best_from_scores()` 不要求调用方预先排序：它会扫描全部 accepted、有限且达到门槛的评分，选择数值最高项，同分再按 `decision_order` 稳定破平。`score_all()` 与单个 option 的评分会在调用开始时冻结候选/考虑项数组成员，项目 scorer 在回调中清空或重排 live exported 数组不会造成越界，也只影响下一次调用；上下文、Resource 字段和 scorer 的完整只读/重入政策仍需由项目明确，不能把这项成员快照误解为整个评价事务已经不可变。

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

`GFDecisionContext` 在分配主体和目标时先捕获无参数的 `get_decision_snapshot()`、`get_decision_values()` 或可存储属性，形成本次评价的快照视图。缺失 key 才会调用可接受两个参数的 `get_decision_value(key, fallback)`；签名不兼容的方法不会通过字符串反射调用。返回 `null` 表示显式输入值，返回传入 sentinel 才表示缺失。

默认主动快照最多 `DEFAULT_MAX_SNAPSHOT_ENTRIES` 条，反射捕获最多 `DEFAULT_MAX_REFLECTION_PROPERTIES` 条；构造 `GFDecisionContext` 时可通过第五个 `capture_options` 参数收紧预算。命中、miss 与正在执行的每个不同懒 key 都会先占用同一帧账本；miss 被负缓存，重复读取使用本次调用的 fallback 而不再执行 provider，不同 key 到达预算后也停止调用。重新绑定 subject/target 会原子清空对应账本。`get_debug_snapshot().capture_diagnostics` 以 `captured_count`、`attempted_count`、`limit` 和 `truncated` 区分成功捕获与已消费尝试。

调试快照的 `subject_values`、`target_values` 与 `capture_diagnostics` 保持可直接按字符串键遍历的固定 JSON object 外壳，叶值再由 `GFReportValueCodec` 编码；遇到非字符串键、键规范化冲突、循环集合或报告预算超限时会失败闭合为保真 marker。进程内黑板、上下文、评分与评价副本改用循环安全 Variant 复制，不会因项目 metadata 自引用而递归失败。

subject/target 顶层句柄是 `WeakRef`，但 `subject_values`、`target_values` 和 metadata 是公开的项目 Variant 图，其中的 Object/Resource 身份仍保持共享。provider 返回 `self`、把 `self` 放入嵌套集合，或调用方直接写入当前对象时，快照会形成强引用；因此当前保证是“顶层句柄弱引用”，不是任意可达对象图的深度弱所有权。需要严格释放时不要在值图中放入 subject/target；是否改为 data-only、自动 WeakRef 或显式强引用模式属于待定产品合同。

`GFDecisionBlackboard.values`、`GFDecisionContext.metadata`、`GFDecisionOption.considerations` 和 `GFDecisionSet.decisions` 是可编辑集合。直接修改这些集合不会触发黑板变更信号，也不会执行添加、移除方法中的空值检查；需要信号或校验语义时使用对应方法。

`GFDecisionConsideration.default_input` 用于输入缺失或没有配置 `input_key` 的情况；`missing_score` 用于输入存在但不是数字的情况。项目要把“缺失就是低分”表达出来时，应把 `default_input` 设为对应低值。

`GFDecisionSet.get_debug_snapshot(context, scores)` 把 `scores = null` 解释为“现场评分”，把显式空数组解释为“调用方已经提供完整且为空的预计算结果”。需要避免 provider 再次执行时，应传 `GFDecisionEvaluation.scores`，不要用空数组代替缺省参数。

`GFDecisionConsideration.get_debug_snapshot(context)` 同样是现场评分入口，会执行一次可重写的 `_score()`。已有正式分数时使用 `get_debug_snapshot_from_score(score_value)`；该入口只编码预计算值，不会因打开诊断面板或写日志再次推进随机数、计数器或项目状态。

通过 `GFDecisionUtility.register_decision_set(decision_set_id, decision_set)` 注册集合时，外部 ID 必须和资源内 `decision_set.decision_set_id` 一致；如果资源内 ID 为空，则注册入口会写入该 ID。registry key 在注册生命周期内是权威身份：同一 Resource 实例不能再次注册到另一个 key，外部热修改 ID 后，后续 Utility lookup/score/evaluate 会恢复原 key，评价与调试报告也继续使用该身份。若要改名，应先显式注销，再修改并用新 key 注册。

## Environment Query 组合配方

环境查询不需要新增一套平行运行时，可以把现有 Spatial、Physics、Decision、执行预算和诊断能力组合成项目 Pipeline：

1. 项目为本次请求分配 generation，冻结上下文、测试计划和有限候选集合。`GFSpatialQueryIndex2D` / `GFSpatialQueryIndex3D` 的记录可能包含实时 `entity` 引用；冻结层只复制稳定 identity、位置或 bounds，以及经过校验的有界 data-only metadata，不保留 Node 或 Resource。
2. 空间索引查询当前没有 `max_results` 或取消参数，一次调用属于不可抢占的原子工作。项目必须在调用前通过分区、半径、索引人口和调用频率限制查询规模；`GFExecutionBudget` 只能约束项目拥有的候选生成、物理测试、评分、输出和诊断循环，不能中断已经进入的索引查询。
3. 项目先完成有界物理测试与业务过滤，并把结果转换为有限、只读的 `GFDecisionContext` 输入。非法、非有限或产生副作用的测试结果应拒绝候选，不能依赖 Decision 的分数归一化把失败伪装成合法低分。
4. 每个冻结候选都通过同一只读 `GFDecisionOption` 评分，再把稳定候选 ID 和确定性原始顺序写入对应 `GFDecisionScore`；最终使用 `GFDecisionSet.select_best_from_scores()` 从预计算结果选择，避免为了查看最佳项再次执行 scorer。同分按稳定顺序裁决；项目若从 top-N 随机选择，必须注入并记录可复现 seed。
5. 显式 cancellation token 与 generation 检查决定唯一终态，过期 generation 的完成结果不得提交。`GFDiagnosticSnapshotProvider` 只复制已经计算的候选位置、过滤原因、评分、终态和预算证据，不能在诊断回调里重跑生成器、物理测试或 scorer。

至少测试空结果、全部过滤、非有限值、完全同分、执行期间候选变化、取消、重入、generation 替换、预算耗尽和重复读取诊断。只有多个项目反复出现无法由这条组合边界解决的共同生命周期问题时，才应评估新增 Environment Query Runtime。

## 使用边界

- 不要把具体玩法字段写进 GF 扩展；黑板键、候选 ID 和元数据都由项目定义。
- 不要把候选选择和动作执行绑死；`GFDecisionScore` 只报告结果，动作执行应留在项目 System、行为树节点、Flow 节点或其他运行时服务中。
- 不使用 LLM Agent、Prompt、向量数据库或外部记忆服务；需要生成式代理时应作为项目或独立插件能力，不写入 GF 内置扩展。
- 长期规划、HTN 和复杂导演策略可以基于 Decision 的上下文与评分报告继续扩展，但不应破坏当前候选评分 API。
- 报告、日志和调试面板应优先使用 `get_debug_snapshot()` 或 `GFDecisionEvaluation.to_report_dictionary()`；Decision 的公开调试快照会统一经过 `GFReportValueCodec`，而 `to_dictionary()` 仍是进程内原生数据通道。

## API Reference

完整类、方法和信号列表见 [Decision API Reference](../../reference/api/extensions-decision.md)。
