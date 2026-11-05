# Pipeline Trace

需要审计采集或应用流程时，可以按需开启 trace，或显式传入 `GFSavePipelineContext` 在外部读取事件。

```gdscript
var payload_with_trace := save_graph.gather_scope(%SaveScope, {
	"include_pipeline_trace": true,
})

var pipeline_context := save_graph.create_pipeline_context(&"apply", %SaveScope)
save_graph.apply_scope(%SaveScope, payload, {
	"pipeline_context": pipeline_context,
})
print(pipeline_context.to_dict())
```

`GFSavePipelineContext` 只是流程事件日志，不是要保存的游戏数据。保存时应写入 `gather_scope()` 返回的 payload；`pipeline_context.to_dict()` 只适合写日志、测试断言或编辑器诊断面板。

trace 中的单条记录由 `GFSavePipelineEvent` 表示，包含阶段、严重级别、Scope key、Source key、节点路径、调试消息和附加载荷。导出 trace 时，`shared` 和事件 `payload` 会被转换为 JSON-safe 报告值，Object、Resource、循环集合和非有限数不会直接泄漏到日志。业务字段仍应放在项目自己的 payload 中，或由自定义 `GFSaveSource` 写入 SaveGraph payload。

需要把多个外部步骤纳入一次应用事务时，可以实现 `GFSaveTransactionParticipant` 并注册到 `GFSavePipelineContext`。参与者只暴露 `prepare()`、`commit()` 和 `rollback()` 三段协议，适合让项目侧缓存写入、动态实体恢复或外部存储适配器在 SaveGraph 应用失败时一起回滚；它不定义项目的存档模块、业务字段或冲突解决策略。

`apply_scope()` 的事务身份由 Utility 私有 operation state 持有，调用方 context 中同名 `_gf_save_graph_*` 键不会参与所有权判断；同一个 Utility 的同步递归 `apply_scope()` 会以稳定 reentrant error 失败关闭。默认结果始终包含 `rollback_failures` 与 `atomicity_restored`：前者记录 participant 或 Source snapshot 的回滚失败，后者只有在没有回滚失败证据时才为 `true`。这两个字段不依赖 `include_pipeline_trace`；trace 仍只承担详细诊断。

## 应用完成后的观察与迁移

`GFSavePipelineStep._after_apply_scope()` 在外层提交或回滚尝试结束后调用。各个仍然有效的 Scope 按子 Scope 在先、根 Scope 最后的顺序接受观察。子 Scope 的 `ok` 描述该 Scope 的局部应用，整次读档以根结果为准。每个步骤在收到通知时取得单独的结果和载荷字典副本，其中的项目 Object 仍按引用传递。要为诊断面板记录收尾问题，可以调用传入的 `GFSavePipelineContext.add_warning()`，由外部 Context 或返回的可选 trace 读取。

原先通过返回字典或原地修改 `ok`、`errors`、`applied` 的步骤应按用途迁移。只在成功读档后刷新的界面可以使用 Scope 或 Source 的 `_after_load()`。必须否决读档的业务校验应在外层 `prepare` 之前登记事务参与者，由其 `prepare` 或 `commit` 返回失败。此时 Source 可能已暂时写入运行状态。默认事务会逆序调用参与者的 `rollback` 并尝试恢复 Source 快照；项目负责补偿自己的外部副作用，并检查 `rollback_failures`。显式关闭 `transactional_apply` 的调用不执行这套回滚。
