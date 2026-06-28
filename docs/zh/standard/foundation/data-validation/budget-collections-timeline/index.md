# 预算、集合与时间线

本组页面说明通用预算账本、双端队列、值索引、查询签名、缓存诊断、文本检索评分、可观察集合资源、变更批次、时间段文本轨道和回放时间线。它们负责保存、查询、排序和归一化底层数据，不决定资源恢复策略、编辑器交互、字幕样式、事件执行或项目业务流程。

## 阅读入口

- [预算账本](budget-ledger.md)：`GFBudgetLedger` 的容量、可用量、消费结果和释放。
- [双端队列](deque.md)：`GFDeque` 的两端追加、裁剪和队列顺序导出。
- [优先队列](priority-queue.md)：`GFPriorityQueue` 的稳定 priority 排序、同级 front 插入和取消/调序。
- [值索引与变更批次](value-index-mutation-batch.md)：`GFValueIndex` 的多字段查询与 `GFMutationBatch` 的提交/回滚。
- [查询签名与缓存诊断](query-cache-helpers.md)：`GFQuerySignature` 的稳定查询 key 与 `GFCacheDiagnostics` 的缓存计数快照。
- [文本检索评分](text-search-scorer.md)：`GFTextSearchScorer` 的 token 匹配、字段权重和候选排序报告。
- [可观察集合资源](observable-resources.md)：`GFObservableArrayResource` 与 `GFObservableDictionaryResource` 的显式变更信号和批量报告。
- [时间段文本轨道](timed-text.md)：`GFTimedTextEntry`、`GFTimedTextTrack` 和 `GFTimedTextImporter`。
- [回放时间线](replay-timeline.md)：`GFReplayTimeline` 的通用事件记录、范围查询、合并和序列化。

## 使用边界

这些类型只维护通用数据结构和轻量解析结果。资源恢复规则、缓存失效策略、字幕渲染、编辑器工作流、业务事务、事件执行、队列调度和项目状态提交策略应由项目层或上层 Utility 负责。
